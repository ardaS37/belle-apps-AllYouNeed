#include "device.h"
#include "dil.h"

#include <QtCore/QDir>
#include <QtCore/QDirIterator>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QDateTime>
#include <QtCore/QTimer>
#include <QtCore/QUrl>
#include <QtCore/QList>
#include <QtCore/QtAlgorithms>
#include <QtCore/QElapsedTimer>
#include <QtCore/QPair>
#include <QtCore/QCoreApplication>
#include <QtGui/QDesktopServices>
#include <QtGui/QApplication>
#include <QtGui/QClipboard>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkRequest>
#include <QtNetwork/QNetworkReply>

#include <qmediarecorder.h>
#include <qaudiocapturesource.h>
#include <qmediaencodersettings.h>

static const qint64 MAX_UPLOAD = 15 * 1024 * 1024;

Device::Device(QObject *parent)
    : QObject(parent),
      m_nam(new QNetworkAccessManager(this)),
      m_reply(0),
      m_source(0),
      m_recorder(0),
      m_tick(new QTimer(this)),
      m_recording(false)
{
    m_tick->setInterval(500);
    connect(m_tick, SIGNAL(timeout()), this, SLOT(onRecordTick()));
}

// ---------------- Galeri ----------------
// Klasor adlari telefondan telefona degistigi icin (Images, DCIM, Camera, 201111A0 ...)
// tum kullanici surucuelerini taranir; sistem / gizli klasorler atlanir.

QStringList Device::searchRoots() const
{
    QStringList roots;
#if defined(Q_OS_SYMBIAN)
    foreach (const QFileInfo &d, QDir::drives()) {
        QString p = d.absolutePath();              // "C:/", "E:/", "F:/", "Z:/" ...
        if (p.startsWith("Z", Qt::CaseInsensitive) || p.startsWith("D", Qt::CaseInsensitive)) continue;   // ROM / RAM disk
        if (p.startsWith("C", Qt::CaseInsensitive)) p = "C:/Data";
        if (QDir(p).exists()) roots << p;
    }
    if (roots.isEmpty()) roots << "C:/Data" << "E:/" << "F:/";
#else
    roots << QDesktopServices::storageLocation(QDesktopServices::PicturesLocation)
          << QDesktopServices::storageLocation(QDesktopServices::MoviesLocation)
          << QDesktopServices::storageLocation(QDesktopServices::MusicLocation);
#endif
    return roots;
}

static bool newerFirst(const QFileInfo &a, const QFileInfo &b)
{
    return a.lastModified() > b.lastModified();
}

static bool skipDir(const QString &name)
{
    const QString n = name.toLower();
    return n.startsWith(".") || n.startsWith("_") || n == "private" || n == "sys" || n == "resource"
        || n == "system" || n == "logs" || n == "cache" || n == "thumbnails" || n == "installs"
        || n == "nokia" || n == "predic" || n == "widgets" || n == "games" || n == "mail" || n == "messages";
}

QStringList Device::mediaFiles(const QString &kind, int limit)
{
    QStringList exts;
    if (kind == "image") exts << "jpg" << "jpeg" << "png";
    else if (kind == "video") exts << "mp4" << "3gp" << "3g2" << "m4v";
    else exts << "amr" << "mp3" << "wav" << "aac" << "m4a" << "awb";

    QElapsedTimer timer;
    timer.start();
    QList<QFileInfo> found;
    QStringList report;
    int dirsVisited = 0;

    foreach (const QString &root, searchRoots()) {
        int before = found.size();
        // Genislik oncelikli tarama, en fazla 6 seviye derinlik
        QList<QPair<QString, int> > queue;
        queue.append(qMakePair(root, 0));
        while (!queue.isEmpty() && timer.elapsed() < 6000 && dirsVisited < 4000) {
            const QPair<QString, int> cur = queue.takeFirst();
            QDir dir(cur.first);
            ++dirsVisited;
            const QFileInfoList entries = dir.entryInfoList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot | QDir::Readable);
            foreach (const QFileInfo &fi, entries) {
                if (fi.isDir()) {
                    if (cur.second < 6 && !skipDir(fi.fileName())) queue.append(qMakePair(fi.absoluteFilePath(), cur.second + 1));
                } else if (exts.contains(fi.suffix().toLower()) && fi.size() > 0) {
                    found.append(fi);
                }
            }
        }
        report << root + ": " + QString::number(found.size() - before);
    }
    qSort(found.begin(), found.end(), newerFirst);

    QStringList out;
    for (int i = 0; i < found.size() && out.size() < limit; ++i) {
        const QString p = found.at(i).absoluteFilePath();
        if (!out.contains(p)) out << p;
    }
    m_scanInfo = Dil::t("Taranan: ") + report.join(", ")
                 + Dil::t(" | klasör: ") + QString::number(dirsVisited)
                 + Dil::t(" | süre: ") + QString::number(timer.elapsed() / 1000.0, 'f', 1) + " sn";
    return out;
}

void Device::setClipboard(const QString &text) { QApplication::clipboard()->setText(text); }

QString Device::fileName(const QString &path) const
{
    return QFileInfo(path).fileName();
}

QString Device::fileSizeText(const QString &path) const
{
    const qint64 s = QFileInfo(path).size();
    if (s >= 1024 * 1024) return QString::number(s / (1024.0 * 1024.0), 'f', 1) + " MB";
    return QString::number((s + 1023) / 1024) + " KB";
}

QString Device::fileUrl(const QString &path) const
{
    return QUrl::fromLocalFile(path).toString();
}

// ---------------- Yukleme (multipart/form-data) ----------------

static void addField(QByteArray &body, const QByteArray &boundary, const QByteArray &name, const QByteArray &value)
{
    body += "--" + boundary + "\r\n";
    body += "Content-Disposition: form-data; name=\"" + name + "\"\r\n\r\n";
    body += value + "\r\n";
}

static QByteArray mimeFor(const QString &path)
{
    const QString e = QFileInfo(path).suffix().toLower();
    if (e == "jpg" || e == "jpeg") return "image/jpeg";
    if (e == "png") return "image/png";
    if (e == "mp4") return "video/mp4";
    if (e == "3gp") return "video/3gpp";
    if (e == "amr") return "audio/amr";
    if (e == "mp3") return "audio/mpeg";
    if (e == "wav") return "audio/wav";
    if (e == "aac" || e == "m4a") return "audio/aac";
    return "application/octet-stream";
}

void Device::upload(const QString &url, const QString &key,
                    const QString &sender, const QString &receiver,
                    const QString &filePath)
{
    if (m_reply) {
        emit uploadFinished(false, Dil::t("Önceki gönderim sürüyor"));
        return;
    }
    QFile f(filePath);
    if (!f.open(QIODevice::ReadOnly)) {
        emit uploadFinished(false, Dil::t("Dosya açılamadı"));
        return;
    }
    if (f.size() > MAX_UPLOAD) {
        emit uploadFinished(false, Dil::t("Dosya çok büyük (en fazla 15 MB)"));
        return;
    }

    const QByteArray boundary = "----WhatsBelle" + QByteArray::number(QDateTime::currentDateTime().toTime_t())
                                + QByteArray::number(qrand());
    QByteArray body;
    addField(body, boundary, "sender", sender.toUtf8());
    addField(body, boundary, "receiver", receiver.toUtf8());
    body += "--" + boundary + "\r\n";
    body += "Content-Disposition: form-data; name=\"media\"; filename=\""
            + QFileInfo(filePath).fileName().toUtf8() + "\"\r\n";
    body += "Content-Type: " + mimeFor(filePath) + "\r\n\r\n";
    body += f.readAll();
    body += "\r\n--" + boundary + "--\r\n";
    f.close();

    QNetworkRequest req((QUrl(url)));
    req.setHeader(QNetworkRequest::ContentTypeHeader, "multipart/form-data; boundary=" + boundary);
    if (!key.isEmpty()) req.setRawHeader("X-Api-Key", key.toUtf8()); req.setRawHeader("X-Lang", Dil::kodu());

    m_reply = m_nam->post(req, body);
    connect(m_reply, SIGNAL(finished()), this, SLOT(onReplyFinished()));
    connect(m_reply, SIGNAL(uploadProgress(qint64,qint64)), this, SLOT(onUploadProgress(qint64,qint64)));
    emit uploadingChanged();
    emit uploadProgress(0);
}

void Device::cancelUpload()
{
    if (m_reply) m_reply->abort();
}

void Device::onUploadProgress(qint64 sent, qint64 total)
{
    if (total > 0) emit uploadProgress(int(sent * 100 / total));
}

void Device::onReplyFinished()
{
    QNetworkReply *r = m_reply;
    m_reply = 0;
    const int status = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray data = r->readAll();
    const bool ok = (r->error() == QNetworkReply::NoError) && status >= 200 && status < 300;
    QString msg;
    if (ok) {
        msg = Dil::t("Gönderildi");
    } else if (status == 403) {
        msg = Dil::t("Sunucu parolası hatalı");
    } else if (status == 0) {
        msg = Dil::t("Sunucuya bağlanılamadı");
    } else {
        // {"statusDesc":"..."} icinden mesaji cek
        const int i = data.indexOf("\"statusDesc\":\"");
        if (i >= 0) {
            const int s = i + 14;
            const int e = data.indexOf('"', s);
            msg = QString::fromUtf8(data.mid(s, e - s));
        } else {
            msg = Dil::t("Gönderilemedi (") + QString::number(status) + ")";
        }
    }
    r->deleteLater();
    emit uploadingChanged();
    emit uploadFinished(ok, msg);
}

// ---------------- Gelen sesli mesajlar ----------------
// Uygulamanin ozel klasorune indirilir: Muzik uygulamasinda gorunmez, ikinci dinleyiste internet gerekmez.
// En yeni 40 dosya tutulur.

static bool validAudioName(const QString &name)
{
    if (!name.endsWith(".mp3") || name.length() < 5 || name.length() > 40) return false;
    for (int i = 0; i < name.length() - 4; ++i) if (!name.at(i).isDigit()) return false;
    return true;
}

QString Device::audioDir() const
{
#if defined(Q_OS_SYMBIAN)
    const QString dir = QCoreApplication::applicationDirPath() + "/sesler";    // C:/private/<uid>/sesler
#else
    const QString dir = QDir::tempPath() + "/WhatsE6_sesler";
#endif
    QDir().mkpath(dir);
    return dir;
}

QString Device::cachedAudio(const QString &name) const
{
    if (!validAudioName(name)) return QString();
    const QString p = audioDir() + "/" + name;
    return QFileInfo(p).size() > 0 ? p : QString();
}

void Device::fetchAudio(const QString &url, const QString &name)
{
    if (!validAudioName(name)) { emit audioFailed(name, Dil::t("Geçersiz dosya")); return; }
    const QString have = cachedAudio(name);
    if (!have.isEmpty()) { emit audioReady(name, have); return; }
    foreach (const QString &n, m_audioJobs) if (n == name) return;      // zaten iniyor

    QNetworkRequest req((QUrl(url)));
    QNetworkReply *r = m_nam->get(req);
    m_audioJobs.insert(r, name);
    connect(r, SIGNAL(finished()), this, SLOT(onAudioFinished()));
}

void Device::onAudioFinished()
{
    QNetworkReply *r = qobject_cast<QNetworkReply *>(sender());
    if (!r) return;
    const QString name = m_audioJobs.take(r);
    const int status = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray data = r->readAll();
    const bool ok = r->error() == QNetworkReply::NoError && status >= 200 && status < 300 && data.size() > 0;
    r->deleteLater();
    if (!ok) {
        QString msg;
        if (status == 0) msg = Dil::t("Sunucuya bağlanılamadı");
        else if (status == 404) msg = Dil::t("Ses dosyası sunucuda yok");
        else if (status == 403) msg = Dil::t("Sunucu parolası hatalı");
        else msg = Dil::t("Ses indirilemedi (") + QString::number(status) + ")";
        emit audioFailed(name, msg);
        return;
    }
    const QString dir = audioDir();
    const QString path = dir + "/" + name;
    QFile f(path + ".part");
    if (!f.open(QIODevice::WriteOnly) || f.write(data) != data.size()) {
        f.close();
        QFile::remove(path + ".part");
        emit audioFailed(name, Dil::t("Ses kaydedilemedi"));
        return;
    }
    f.close();
    QFile::remove(path);
    QFile::rename(path + ".part", path);

    // Onbellegi sinirla
    QFileInfoList all = QDir(dir).entryInfoList(QStringList() << "*.mp3", QDir::Files, QDir::Time);
    for (int i = 40; i < all.size(); ++i) QFile::remove(all.at(i).absoluteFilePath());

    emit audioReady(name, path);
}

// ---------------- Ses kaydi ----------------
// Kayit uygulamanin kendi klasorune yapilir (her zaman var ve yazilabilir).
// Bicim telefona sorulur: AMR varsa AMR (kucuk), yoksa desteklenen ilk bicim.

static QString pickCodec(const QStringList &codecs)
{
    foreach (const QString &c, codecs) if (c.contains("amr", Qt::CaseInsensitive)) return c;
    foreach (const QString &c, codecs) if (c.contains("aac", Qt::CaseInsensitive)) return c;
    foreach (const QString &c, codecs) if (c.contains("pcm", Qt::CaseInsensitive)) return c;
    return codecs.isEmpty() ? QString() : codecs.first();
}

static QString pickContainer(const QStringList &containers, const QString &codec)
{
    const QString c = codec.toLower();
    foreach (const QString &k, containers) {
        const QString kl = k.toLower();
        if (c.contains("amr") && kl.contains("amr")) return k;
        if (c.contains("aac") && (kl.contains("mp4") || kl.contains("aac") || kl.contains("m4a"))) return k;
        if (c.contains("pcm") && (kl.contains("wav") || kl.contains("x-wav"))) return k;
    }
    return containers.isEmpty() ? QString() : containers.first();
}

static QString extFor(const QString &container, const QString &codec)
{
    const QString k = (container + " " + codec).toLower();
    if (k.contains("amr")) return ".amr";
    if (k.contains("mp4") || k.contains("aac") || k.contains("m4a")) return ".m4a";
    if (k.contains("wav") || k.contains("pcm")) return ".wav";
    return ".amr";
}

bool Device::startRecording()
{
    if (m_recording) return true;
    if (!m_source) {
        m_source = new QAudioCaptureSource(this);
        m_recorder = new QMediaRecorder(m_source, this);
        connect(m_recorder, SIGNAL(error(QMediaRecorder::Error)), this, SLOT(onRecorderError(QMediaRecorder::Error)));
    }
    if (!m_source->isAvailable()) {
        emit recordError(Dil::t("Mikrofon kullanılamıyor (izin verilmemiş olabilir)"));
        return false;
    }

    const QStringList codecs = m_recorder->supportedAudioCodecs();
    const QStringList containers = m_recorder->supportedContainers();
    const QString codec = pickCodec(codecs);
    const QString container = pickContainer(containers, codec);
    m_recordInfo = "codec=" + codec + " container=" + container
                   + " | destek: " + codecs.join(",") + " / " + containers.join(",");

#if defined(Q_OS_SYMBIAN)
    QString dir = "C:/Data/Sounds/WhatsE6";
#else
    QString dir = QDir::tempPath();
#endif
    QDir().mkpath(dir);
    m_recPath = dir + "/kayit_" + QDateTime::currentDateTime().toString("yyyyMMdd_hhmmss") + extFor(container, codec);
    QFile::remove(m_recPath);

    QAudioEncoderSettings s;
    if (!codec.isEmpty()) s.setCodec(codec);
#if defined(Q_OS_SYMBIAN)
    // Symbian arka ucu konumu url.toString() ile okuyup dosya yoluna ceviriyor;
    // "file:///C:/..." verilirse gecersiz ad hatasi (-28) olusuyor. Duz "C:/..." ver.
    m_recorder->setOutputLocation(QUrl(m_recPath));
#else
    m_recorder->setOutputLocation(QUrl::fromLocalFile(m_recPath));
#endif
    m_recorder->setEncodingSettings(s, QVideoEncoderSettings(), container);
    m_recorder->record();

    if (m_recorder->error() != QMediaRecorder::NoError) {
        emit recordError(m_recorder->errorString() + " [" + m_recordInfo + "]");
        return false;
    }
    m_recording = true;
    m_recStart.start();
    m_tick->start();
    emit recordingChanged();
    emit recordSeconds(0);
    return true;
}

void Device::onRecorderError(QMediaRecorder::Error)
{
    const QString msg = m_recorder ? m_recorder->errorString() : QString();
    if (m_recording) {
        m_recorder->stop();
        m_tick->stop();
        m_recording = false;
        emit recordingChanged();
    }
    emit recordError(msg + " [" + m_recordInfo + "]");
}

QString Device::stopRecording()
{
    if (!m_recording) return QString();
    m_recorder->stop();
    m_tick->stop();
    m_recording = false;
    emit recordingChanged();
    // Arka uc uzantiyi bicime gore degistirebilir; ayni adla baska uzantili dosyayi da kabul et
    if (!QFile::exists(m_recPath)) {
        const QFileInfo fi(m_recPath);
        const QStringList alts = QDir(fi.absolutePath()).entryList(QStringList() << fi.completeBaseName() + ".*", QDir::Files);
        if (!alts.isEmpty()) m_recPath = fi.absolutePath() + "/" + alts.first();
    }
    return m_recPath;
}

void Device::cancelRecording()
{
    const QString p = stopRecording();
    m_recPath = p;
    if (!p.isEmpty()) QTimer::singleShot(800, this, SLOT(onRecordTick()));   // dosya kapandiktan sonra sil
}

void Device::onRecordTick()
{
    if (m_recording) {
        emit recordSeconds(m_recStart.elapsed() / 1000);
    } else if (!m_recPath.isEmpty() && m_recPath.contains("kayit_")) {
        QFile::remove(m_recPath);   // iptal edilen kaydi temizle
        m_recPath.clear();
    }
}
