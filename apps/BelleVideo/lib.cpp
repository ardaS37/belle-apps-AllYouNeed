#include "lib.h"
#include "dil.h"
#include "serveconn.h"
#include "audioextract.h"

#include <QtCore/QDir>
#include <QtCore/QFileInfo>
#include <QtCore/QSettings>
#include <QtCore/QDateTime>
#include <QtCore/QUrl>
#include <QtCore/QTextStream>
#include <QtCore/QRegExp>
#include <QtCore/QtAlgorithms>
#include <QtCore/QVariantMap>
#include <QtGui/QDesktopServices>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkRequest>
#include <QtNetwork/QNetworkReply>
#include <QtNetwork/QTcpServer>
#include <QtNetwork/QTcpSocket>
#include <QtNetwork/QHostAddress>

#ifdef Q_OS_SYMBIAN
#include <apgtask.h>
#include <coemain.h>
#include <w32std.h>
#endif

static const char *KUserAgent = "Mozilla/5.0 (SymbianOS/9.4; Series60/5.0 NokiaE6) BelleVideo/1.0";

static QStringList videoExts()
{
    static QStringList l = QString("mp4 m4v 3gp 3g2 3gpp mov avi wmv asf mkv flv f4v mpg mpeg rm rmvb divx webm").split(' ');
    return l;
}
static QStringList audioExts()
{
    static QStringList l = QString("mp3 m4a aac wav amr awb wma ogg flac").split(' ');
    return l;
}
static QString extOf(const QString &path)
{
    QString p = path;
    const int q = p.indexOf('?');
    if (q >= 0) p = p.left(q);
    const int slash = p.lastIndexOf('/');
    const int dot = p.lastIndexOf('.');
    if (dot < 0 || dot < slash) return QString();
    return p.mid(dot + 1).toLower();
}
static QString norm(const QString &p)
{
    QString s = QDir::fromNativeSeparators(p);
    if (s.length() > 3 && s.endsWith('/')) s.chop(1);
    return s;
}

Lib::Lib(QObject *parent)
    : QObject(parent), m_scanning(false), m_libVersion(0), m_server(new QTcpServer(this)), m_nextId(1),
      m_nam(new QNetworkAccessManager(this)), m_reply(0), m_redirects(0), m_cancelled(false), m_logLoaded(false)
{
#if defined(Q_OS_SYMBIAN)
    m_dataDir = "C:/Data/E6Video";
    m_dlDir = QDir("E:/").exists() ? "E:/Videos/E6Video" : "C:/Data/Videos/E6Video";
#else
    m_dataDir = QDesktopServices::storageLocation(QDesktopServices::TempLocation) + "/E6Video";
    m_dlDir = m_dataDir + "/indirilen";
#endif
    QDir().mkpath(m_dataDir);
    // Cikarilan ses izleri: kartta yer varsa oraya (nokta ile baslayan klasor taramaya girmez)
    m_audioDir = QDir("E:/").exists() ? "E:/Videos/E6Video/.ses" : m_dataDir + "/ses";
#if !defined(Q_OS_SYMBIAN)
    m_audioDir = m_dataDir + "/ses";
#endif
    QDir().mkpath(m_audioDir);
    m_extract = new AudioExtract(this);
    connect(m_extract, SIGNAL(finished(QString,QString,bool,QString)), this, SLOT(onAudioFinished(QString,QString,bool,QString)));

    m_scanTimer.setInterval(25);
    connect(&m_scanTimer, SIGNAL(timeout()), this, SLOT(scanStep()));
    loadCache();

    connect(m_server, SIGNAL(newConnection()), this, SLOT(onNewConnection()));
    if (!m_server->listen(QHostAddress::LocalHost, 0)) log("yerel sunucu acilamadi: " + m_server->errorString());
}

// ================= Tarama =================

static bool newestFirst(const QVariant &a, const QVariant &b)
{
    return a.toMap().value("time").toUInt() > b.toMap().value("time").toUInt();
}

bool Lib::skipDir(const QString &name)
{
    const QString n = name.toLower();
    return n.startsWith('.') || n == "private" || n == "sys" || n == "resource" || n == "system"
            || n == "shared" || n == "cache" || n == "thumbnails" || n == "_pagedtemp";
}

void Lib::rescan()
{
    if (m_scanning) return;
    m_found.clear();
    m_queue.clear();
    m_depth.clear();
    QStringList roots;
#if defined(Q_OS_SYMBIAN)
    roots << "E:/" << "F:/" << "C:/Data";
#else
    roots << QDir::homePath() + "/Videos" << m_dlDir;
#endif
    foreach (const QString &r, roots) {
        if (QDir(r).exists()) { m_queue << r; m_depth.insert(r, 0); }
    }
    m_scanning = true;
    emit scanningChanged();
    emit scanProgress();
    m_scanTimer.start();
    log("tarama basladi");
}

// Her adimda birkac klasor: arayuz donmaz, oynatma sirasinda da sorun cikarmaz
void Lib::scanStep()
{
    for (int n = 0; n < 3 && !m_queue.isEmpty(); ++n) {
        const QString dir = m_queue.takeFirst();
        const int depth = m_depth.value(dir, 0);
        QDir d(dir);
        const QFileInfoList list = d.entryInfoList(QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot, QDir::Name);
        foreach (const QFileInfo &fi, list) {
            if (fi.isDir()) {
                if (depth < 7 && !skipDir(fi.fileName())) {
                    const QString p = norm(fi.absoluteFilePath());
                    m_queue << p;
                    m_depth.insert(p, depth + 1);
                }
                continue;
            }
            const QString ext = fi.suffix().toLower();
            if (!videoExts().contains(ext)) continue;
            if (fi.size() < 16 * 1024) continue;            // bozuk/bos dosyalar
            QVariantMap m;
            const QString path = norm(fi.absoluteFilePath());
            QString name = fi.completeBaseName();
            // BelleTube indirmeleri: <id>_<tur>.mp4 yaninda basligi tutan .ini var
            const QString ini = fi.absolutePath() + "/" + fi.completeBaseName() + ".ini";
            if (QFile::exists(ini)) {
                QSettings s(ini, QSettings::IniFormat);
                const QString t = s.value("title").toString();
                if (!t.isEmpty()) name = t;
            }
            m["path"] = path;
            m["name"] = name;
            m["folder"] = fi.absoluteDir().dirName();
            m["size"] = fi.size();
            m["time"] = fi.lastModified().toTime_t();
            m_found << m;
        }
    }
    emit scanProgress();
    if (!m_queue.isEmpty()) return;

    m_scanTimer.stop();
    m_depth.clear();
    qSort(m_found.begin(), m_found.end(), newestFirst);     // yeniden eskiye
    m_videos = m_found;
    m_found.clear();
    m_scanning = false;
    saveCache();
    m_libVersion++;
    log(QString("tarama bitti: %1 video").arg(m_videos.size()));
    emit scanningChanged();
    emit libraryChanged();
}

void Lib::loadCache()
{
    QFile f(m_dataDir + "/videolar.txt");
    if (!f.open(QIODevice::ReadOnly)) return;
    QTextStream in(&f);
    in.setCodec("UTF-8");
    while (!in.atEnd()) {
        const QStringList p = in.readLine().split('\t');
        if (p.size() < 5) continue;
        QVariantMap m;
        m["path"] = p[0];
        m["name"] = p[1];
        m["folder"] = p[2];
        m["size"] = p[3].toLongLong();
        m["time"] = p[4].toUInt();
        m_videos << m;
    }
    m_libVersion++;
}

void Lib::saveCache()
{
    QFile f(m_dataDir + "/videolar.txt");
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) return;
    QTextStream out(&f);
    out.setCodec("UTF-8");
    foreach (const QVariant &v, m_videos) {
        const QVariantMap m = v.toMap();
        QString name = m.value("name").toString();
        name.replace('\t', ' ').replace('\n', ' ');
        out << m.value("path").toString() << '\t' << name << '\t' << m.value("folder").toString() << '\t'
            << m.value("size").toLongLong() << '\t' << m.value("time").toUInt() << '\n';
    }
}

// ================= Klasor gezgini =================

QVariantList Lib::listDir(const QString &pathIn) const
{
    QVariantList out;
    const QString path = norm(pathIn);
    if (path.isEmpty()) {
        struct R { const char *p; const char *n; };
#if defined(Q_OS_SYMBIAN)
        const R roots[] = { { "E:/Videos", "Videolar (hafıza kartı)" }, { "E:/", "Hafıza kartı (E:)" },
                            { "F:/", "Yığın bellek (F:)" }, { "C:/Data/Videos", "Videolar (telefon)" },
                            { "C:/Data", "Telefon belleği (C:)" } };
#else
        const R roots[] = { { "/", "Kök" } };
#endif
        for (unsigned i = 0; i < sizeof(roots) / sizeof(roots[0]); ++i) {
            if (!QDir(roots[i].p).exists()) continue;
            QVariantMap m;
            m["name"] = QString::fromUtf8(roots[i].n);
            m["path"] = norm(roots[i].p);
            m["dir"] = true;
            m["kind"] = "dir";
            m["size"] = 0;
            m["time"] = 0;
            out << m;
        }
        if (QDir(m_dlDir).exists()) {
            QVariantMap m;
            m["name"] = Dil::t("İndirilenler");
            m["path"] = m_dlDir;
            m["dir"] = true;
            m["kind"] = "dir";
            m["size"] = 0;
            m["time"] = 0;
            out << m;
        }
        return out;
    }

    QDir d(path);
    const bool driveRoot = path.length() <= 3;
    QVariantList files;
    foreach (const QFileInfo &fi, d.entryInfoList(QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot,
                                                  QDir::Name | QDir::IgnoreCase | QDir::DirsFirst)) {
        QVariantMap m;
        m["name"] = fi.fileName();
        m["path"] = norm(fi.absoluteFilePath());
        m["time"] = fi.lastModified().toTime_t();
        if (fi.isDir()) {
            if (driveRoot && skipDir(fi.fileName())) continue;
            if (fi.fileName().startsWith('.')) continue;
            m["dir"] = true;
            m["kind"] = "dir";
            m["size"] = 0;
            out << m;
        } else {
            const QString ext = fi.suffix().toLower();
            QString kind;
            if (videoExts().contains(ext)) kind = "video";
            else if (audioExts().contains(ext)) kind = "audio";
            else continue;
            m["dir"] = false;
            m["kind"] = kind;
            m["size"] = fi.size();
            files << m;
        }
    }
    out << files;
    return out;
}

QString Lib::parentDir(const QString &pathIn) const
{
    const QString path = norm(pathIn);
    if (path.isEmpty() || path.length() <= 3) return QString();
    if (path.compare("C:/Data", Qt::CaseInsensitive) == 0) return QString();
    QString p = QFileInfo(path).absolutePath();
    return norm(p);
}

QStringList Lib::mediaInDir(const QString &path) const
{
    QStringList out;
    foreach (const QVariant &v, listDir(path)) {
        const QVariantMap m = v.toMap();
        if (!m.value("dir").toBool()) out << m.value("path").toString();
    }
    return out;
}

bool Lib::isVideo(const QString &path) const { return videoExts().contains(extOf(path)); }
bool Lib::isAudio(const QString &path) const { return audioExts().contains(extOf(path)); }
bool Lib::isRemote(const QString &path) const { return path.contains("://") && !path.startsWith("file:"); }
bool Lib::exists(const QString &path) const { return isRemote(path) || QFile::exists(path); }
qint64 Lib::fileSize(const QString &path) const { return QFileInfo(path).size(); }

bool Lib::removeFile(const QString &path)
{
    const bool ok = QFile::remove(path);
    if (ok) {
        for (int i = 0; i < m_videos.size(); ++i) {
            if (m_videos.at(i).toMap().value("path").toString() == path) { m_videos.removeAt(i); break; }
        }
        clearPosition(path);
        forgetRecent(path);
        saveCache();
        m_libVersion++;
        emit libraryChanged();
    }
    return ok;
}

QString Lib::baseName(const QString &path) const
{
    if (isRemote(path)) {
        const QUrl u(path);
        QString f = QFileInfo(u.path()).fileName();
        return f.isEmpty() ? u.host() : QUrl::fromPercentEncoding(f.toUtf8());
    }
    return QFileInfo(path).completeBaseName();
}

QString Lib::folderName(const QString &path) const
{
    if (isRemote(path)) return QUrl(path).host();
    return QFileInfo(path).absoluteDir().dirName();
}

QString Lib::sizeText(qint64 b) const
{
    if (b >= 1024LL * 1024 * 1024) return QString::number(b / (1024.0 * 1024 * 1024), 'f', 2) + " GB";
    if (b >= 1024 * 1024) return QString::number(b / (1024.0 * 1024), 'f', 1) + " MB";
    return QString::number((b + 1023) / 1024) + " KB";
}

// ================= Oynatma adresleri =================

QString Lib::videoUrl(const QString &p, bool direct)
{
    if (isRemote(p)) {
        const QString scheme = QUrl(p).scheme().toLower();
        if (direct || (scheme != "http" && scheme != "https") || !m_server->isListening()) return p;
        int id = m_urlId.value(p, 0);
        if (!id) { id = m_nextId++; m_urlId.insert(p, id); m_idUrl.insert(id, p); }
        QString ext = extOf(QUrl(p).path());
        if (ext.isEmpty() || ext.length() > 5) ext = "mp4";
        return QString("http://127.0.0.1:%1/r/%2.%3").arg(m_server->serverPort()).arg(id).arg(ext);
    }
    const QString path = norm(p);
    if (direct || !m_server->isListening()) return QUrl::fromLocalFile(path).toString();
    int id = m_pathId.value(path, 0);
    if (!id) { id = m_nextId++; m_pathId.insert(path, id); m_idPath.insert(id, path); }
    QString ext = extOf(path);
    if (ext.isEmpty()) ext = "mp4";
    return QString("http://127.0.0.1:%1/f/%2.%3").arg(m_server->serverPort()).arg(id).arg(ext);
}

QString Lib::audioUrl(const QString &p) const
{
    if (isRemote(p)) return p;
    if (isVideo(p) && audioReady(p)) return QUrl::fromLocalFile(audioCachePath(p)).toString();
    return QUrl::fromLocalFile(norm(p)).toString();
}

// ================= Videonun ses izi =================

bool Lib::canExtractAudio(const QString &path) const
{
    if (isRemote(path)) return false;
    const QString e = extOf(path);
    return e == "mp4" || e == "m4v" || e == "3gp" || e == "3gpp" || e == "3g2" || e == "mov" || e == "f4v";
}

QString Lib::audioCachePath(const QString &path) const
{
    const QFileInfo fi(path);
    return m_audioDir + "/" + QString::number(qHash(norm(path) + QString::number(fi.size())), 16) + ".m4a";
}

bool Lib::audioReady(const QString &path) const { return canExtractAudio(path) && QFile::exists(audioCachePath(path)); }
bool Lib::audioPreparing(const QString &path) const { return m_extract->busy() && m_extract->source() == norm(path); }
int Lib::audioProgress() const { return m_extract->progress(); }

void Lib::prepareAudio(const QString &path)
{
    if (!canExtractAudio(path) || audioReady(path) || audioPreparing(path)) return;
    // Onbellek kucuk kalsin: en yeni 6 dosya tutulur
    QDir d(m_audioDir);
    const QFileInfoList old = d.entryInfoList(QStringList() << "*.m4a", QDir::Files, QDir::Time);
    for (int i = 6; i < old.size(); ++i) QFile::remove(old.at(i).absoluteFilePath());
    foreach (const QFileInfo &fi, d.entryInfoList(QStringList() << "*.part", QDir::Files)) QFile::remove(fi.absoluteFilePath());
    log("ses izi cikariliyor: " + baseName(path));
    if (m_extract->start(norm(path), audioCachePath(path))) emit audioPrepared(path, true, QString());
}

void Lib::onAudioFinished(const QString &src, const QString &, bool ok, const QString &message)
{
    log(QString("ses izi %1: %2").arg(ok ? "hazir" : "yok").arg(message));
    emit audioPrepared(src, ok, message);
}

QByteArray Lib::mimeFor(const QString &path)
{
    const QString e = extOf(path);
    if (e == "mp4" || e == "m4v" || e == "f4v") return "video/mp4";
    if (e == "3gp" || e == "3gpp") return "video/3gpp";
    if (e == "3g2") return "video/3gpp2";
    if (e == "mov") return "video/quicktime";
    if (e == "avi" || e == "divx") return "video/x-msvideo";
    if (e == "wmv") return "video/x-ms-wmv";
    if (e == "asf") return "video/x-ms-asf";
    if (e == "mkv") return "video/x-matroska";
    if (e == "flv") return "video/x-flv";
    if (e == "mpg" || e == "mpeg") return "video/mpeg";
    if (e == "rm" || e == "rmvb") return "application/vnd.rn-realmedia";
    if (e == "webm") return "video/webm";
    if (e == "mp3") return "audio/mpeg";
    if (e == "m4a" || e == "aac") return "audio/mp4";
    if (e == "wav") return "audio/wav";
    if (e == "amr") return "audio/amr";
    if (e == "wma") return "audio/x-ms-wma";
    return "application/octet-stream";
}

void Lib::onNewConnection()
{
    while (m_server->hasPendingConnections()) {
        QTcpSocket *s = m_server->nextPendingConnection();
        if (s) new ServeConn(s, this);
    }
}

// ================= Kaldigi yer =================

QString Lib::settingsPath() const { return m_dataDir + "/konum.ini"; }
QString Lib::keyFor(const QString &path) const { return "p" + QString::number(qHash(norm(path))); }

int Lib::savedPosition(const QString &path) const
{
    QSettings s(settingsPath(), QSettings::IniFormat);
    return s.value("pos/" + keyFor(path)).toString().section('|', 0, 0).toInt();
}

int Lib::savedDuration(const QString &path) const
{
    QSettings s(settingsPath(), QSettings::IniFormat);
    return s.value("pos/" + keyFor(path)).toString().section('|', 1, 1).toInt();
}

void Lib::savePosition(const QString &path, int ms, int durationMs)
{
    if (path.isEmpty()) return;
    QSettings s(settingsPath(), QSettings::IniFormat);
    s.setValue("pos/" + keyFor(path), QString("%1|%2").arg(ms).arg(durationMs));
    QStringList r = s.value("recent").toStringList();
    r.removeAll(path);
    r.prepend(path);
    while (r.size() > 12) r.removeLast();
    s.setValue("recent", r);
}

void Lib::clearPosition(const QString &path)
{
    QSettings s(settingsPath(), QSettings::IniFormat);
    s.remove("pos/" + keyFor(path));
}

QStringList Lib::recent() const
{
    QSettings s(settingsPath(), QSettings::IniFormat);
    QStringList out;
    foreach (const QString &p, s.value("recent").toStringList())
        if (exists(p)) out << p;
    return out;
}

void Lib::forgetRecent(const QString &path)
{
    QSettings s(settingsPath(), QSettings::IniFormat);
    QStringList r = s.value("recent").toStringList();
    r.removeAll(path);
    s.setValue("recent", r);
}

// ================= Indirme =================

QString Lib::uniquePath(const QString &nameIn) const
{
    QString name = nameIn;
    name.replace(QRegExp("[\\\\/:*?\"<>|]"), "_");
    if (name.isEmpty()) name = "video.mp4";
    if (extOf(name).isEmpty()) name += ".mp4";
    const QString base = QFileInfo(name).completeBaseName(), ext = QFileInfo(name).suffix();
    QString p = m_dlDir + "/" + name;
    for (int i = 2; QFile::exists(p) || QFile::exists(p + ".part"); ++i)
        p = m_dlDir + "/" + base + " (" + QString::number(i) + ")." + ext;
    return p;
}

void Lib::download(const QString &url, const QString &name)
{
    if (m_reply) { emit downloadFinished(false, QString(), Dil::t("Başka bir indirme sürüyor")); return; }
    const QUrl u = QUrl::fromUserInput(url.trimmed());
    if (!u.isValid() || (u.scheme() != "http" && u.scheme() != "https")) {
        emit downloadFinished(false, QString(), Dil::t("Yalnızca http/https adresleri indirilebilir"));
        return;
    }
    QDir().mkpath(m_dlDir);
    m_dlName = name.trimmed();
    m_dlPath.clear();
    m_redirects = 0;
    m_cancelled = false;
    m_dlStarted.start();
    log("indir: " + u.toString());
    startGet(u);
    emit downloadingChanged();
    emit downloadProgress(0, 0, 0);
}

void Lib::startGet(const QUrl &url)
{
    QNetworkRequest req(url);
    req.setRawHeader("User-Agent", KUserAgent);
    m_reply = m_nam->get(req);
    m_reply->setReadBufferSize(256 * 1024);
    connect(m_reply, SIGNAL(metaDataChanged()), this, SLOT(onDlMeta()));
    connect(m_reply, SIGNAL(readyRead()), this, SLOT(onDlReadyRead()));
    connect(m_reply, SIGNAL(downloadProgress(qint64,qint64)), this, SLOT(onDlProgress(qint64,qint64)));
    connect(m_reply, SIGNAL(finished()), this, SLOT(onDlFinished()));
}

void Lib::onDlMeta()
{
    if (!m_reply || m_file.isOpen()) return;
    const int status = m_reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (status < 200 || status >= 300) return;          // yonlendirme ya da hata: dosya acilmaz
    QString name = m_dlName;
    if (name.isEmpty()) {
        const QByteArray cd = m_reply->rawHeader("Content-Disposition");
        const int i = cd.indexOf("filename=");
        if (i >= 0) name = QString::fromUtf8(cd.mid(i + 9)).remove('"').section(';', 0, 0).trimmed();
    }
    if (name.isEmpty()) name = baseName(m_reply->url().toString()) + (extOf(m_reply->url().path()).isEmpty() ? "" : "." + extOf(m_reply->url().path()));
    else if (extOf(name).isEmpty()) {
        QString ext = extOf(m_reply->url().path());
        if (ext.isEmpty()) {
            const QByteArray ct = m_reply->header(QNetworkRequest::ContentTypeHeader).toByteArray();
            ext = ct.contains("3gp") ? "3gp" : (ct.contains("mpeg") && ct.startsWith("audio") ? "mp3" : "mp4");
        }
        name += "." + ext;
    }
    m_dlPath = uniquePath(name);
    m_dlName = QFileInfo(m_dlPath).fileName();
    m_file.setFileName(m_dlPath + ".part");
    if (!m_file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        log("indirme dosyasi acilamadi: " + m_file.errorString());
        m_cancelled = true;
        m_reply->abort();
        return;
    }
    emit downloadingChanged();
}

void Lib::onDlReadyRead()
{
    if (!m_reply) return;
    if (!m_file.isOpen()) onDlMeta();
    const QByteArray d = m_reply->readAll();
    if (m_file.isOpen() && !d.isEmpty()) m_file.write(d);
}

void Lib::onDlProgress(qint64 received, qint64 total)
{
    if (!m_reply || !m_file.isOpen()) return;
    const int ms = qMax(1, m_dlStarted.elapsed());
    emit downloadProgress(received, total, int(received / ms));
}

void Lib::cancelDownload()
{
    if (!m_reply) return;
    m_cancelled = true;
    m_reply->abort();
}

void Lib::onDlFinished()
{
    QNetworkReply *r = m_reply;
    if (!r) return;
    const int status = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QUrl redirect = r->attribute(QNetworkRequest::RedirectionTargetAttribute).toUrl();
    if (!m_cancelled && !redirect.isEmpty() && m_redirects < 6 && !m_file.isOpen()) {
        m_redirects++;
        r->deleteLater();
        startGet(r->url().resolved(redirect));
        return;
    }
    if (m_file.isOpen()) { m_file.write(r->readAll()); m_file.close(); }
    const bool ok = !m_cancelled && r->error() == QNetworkReply::NoError && status >= 200 && status < 300 && !m_dlPath.isEmpty();
    QString msg;
    if (ok) {
        QFile::rename(m_dlPath + ".part", m_dlPath);
        msg = Dil::t("İndirildi: ") + m_dlName;
        // kitapliga hemen ekle
        QFileInfo fi(m_dlPath);
        if (videoExts().contains(fi.suffix().toLower())) {
            QVariantMap m;
            m["path"] = norm(m_dlPath);
            m["name"] = fi.completeBaseName();
            m["folder"] = fi.absoluteDir().dirName();
            m["size"] = fi.size();
            m["time"] = fi.lastModified().toTime_t();
            m_videos.prepend(m);
            saveCache();
            m_libVersion++;
            emit libraryChanged();
        }
    } else {
        if (!m_dlPath.isEmpty()) QFile::remove(m_dlPath + ".part");
        if (m_cancelled) msg = Dil::t("İndirme iptal edildi");
        else if (status >= 400) msg = Dil::t("Sunucu hatası (") + QString::number(status) + ")";
        else msg = Dil::t("İndirilemedi: ") + r->errorString();
    }
    log(QString("indirme bitti ok=%1 %2").arg(ok).arg(msg));
    const QString path = ok ? m_dlPath : QString();
    m_reply = 0;
    r->deleteLater();
    if (!ok) m_dlName.clear();
    emit downloadingChanged();
    emit downloadFinished(ok, path, msg);
}

QVariantList Lib::downloads() const
{
    QVariantList out;
    QDir d(m_dlDir);
    foreach (const QFileInfo &fi, d.entryInfoList(QDir::Files, QDir::Time)) {
        if (fi.suffix().toLower() == "part") continue;
        QVariantMap m;
        m["path"] = norm(fi.absoluteFilePath());
        m["name"] = fi.fileName();
        m["size"] = fi.size();
        m["time"] = fi.lastModified().toTime_t();
        out << m;
    }
    return out;
}

// ================= Sistem =================

void Lib::sendToBackground()
{
#ifdef Q_OS_SYMBIAN
    TApaTask t(CCoeEnv::Static()->WsSession());
    t.SetWgId(CCoeEnv::Static()->RootWin().Identifier());
    t.SendToBackground();
#endif
}

bool Lib::openExternally(const QString &path) const
{
    if (isRemote(path)) return QDesktopServices::openUrl(QUrl(path));
    return QDesktopServices::openUrl(QUrl::fromLocalFile(path));
}

// ================= Gunluk =================

static const int KLogLines = 40;

void Lib::log(const QString &line)
{
    if (!m_logLoaded) {
        m_logLoaded = true;
        QFile in(m_dataDir + "/gunluk.txt");
        if (in.open(QIODevice::ReadOnly)) {
            m_log = QString::fromUtf8(in.readAll().right(6000)).split('\n', QString::SkipEmptyParts);
            while (m_log.size() > KLogLines) m_log.removeFirst();
        }
    }
    m_log << QDateTime::currentDateTime().toString("HH:mm:ss ") + line;
    qDebug("E6V %s", qPrintable(line));
    while (m_log.size() > KLogLines) m_log.removeFirst();
    QFile f(m_dataDir + "/gunluk.txt");
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        f.write(m_log.join("\n").toUtf8());
        f.close();
    }
}

QString Lib::logText() const
{
    if (!m_logLoaded) {
        QFile in(m_dataDir + "/gunluk.txt");
        if (in.open(QIODevice::ReadOnly)) return QString::fromUtf8(in.readAll().right(6000));
    }
    return m_log.isEmpty() ? Dil::t("(günlük boş)") : m_log.join("\n");
}

void Lib::clearLog()
{
    m_log.clear();
    m_logLoaded = true;
    QFile::remove(m_dataDir + "/gunluk.txt");
}

// ================= ServeConn =================

static const qint64 KChunk = 64 * 1024;
static const qint64 KMaxQueued = 192 * 1024;

ServeConn::ServeConn(QTcpSocket *sock, Lib *lib)
    : QObject(lib), m_sock(sock), m_lib(lib), m_headerDone(false), m_closing(false), m_hasRange(false),
      m_rangeStart(0), m_rangeEnd(-1), m_pos(0), m_end(-1), m_streaming(false), m_isHead(false),
      m_upHeaderSent(false), m_upDone(false), m_redirects(0)
{
    connect(m_sock, SIGNAL(readyRead()), this, SLOT(onReadyRead()));
    connect(m_sock, SIGNAL(bytesWritten(qint64)), this, SLOT(pumpFile()));
    connect(m_sock, SIGNAL(disconnected()), this, SLOT(onDisconnected()));
}

void ServeConn::onDisconnected()
{
    m_closing = true;
    m_streaming = false;
    if (m_up) { disconnect(m_up, 0, this, 0); m_up->abort(); m_up->deleteLater(); }
    if (m_file.isOpen()) m_file.close();
    if (m_sock) m_sock->deleteLater();
    deleteLater();
}

void ServeConn::fail(const char *status)
{
    if (!m_sock) return;
    m_closing = true;
    m_sock->write(QByteArray("HTTP/1.1 ") + status + "\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");
    m_sock->disconnectFromHost();
}

void ServeConn::onReadyRead()
{
    if (!m_sock) return;
    if (m_headerDone) { m_sock->readAll(); return; }
    m_head += m_sock->readAll();
    if (m_head.size() > 16 * 1024) { fail("400 Bad Request"); return; }
    const int end = m_head.indexOf("\r\n\r\n");
    if (end < 0) return;
    m_headerDone = true;

    const QList<QByteArray> lines = m_head.left(end).split('\n');
    const QList<QByteArray> req = lines.value(0).trimmed().split(' ');
    if (req.size() < 2 || (req[0] != "GET" && req[0] != "HEAD")) { fail("405 Method Not Allowed"); return; }
    const bool head = req[0] == "HEAD";
    QByteArray path = req[1];
    const int q = path.indexOf('?');
    if (q >= 0) path = path.left(q);
    // /f/<n>.<uzanti> ya da /r/<n>.<uzanti>
    const QList<QByteArray> parts = path.split('/');
    if (parts.size() < 3) { fail("404 Not Found"); return; }
    const QByteArray kind = parts.at(1);
    const int id = parts.at(2).split('.').value(0).toInt();

    for (int i = 1; i < lines.size(); ++i) {
        const QByteArray l = lines[i].trimmed();
        if (!l.toLower().startsWith("range:")) continue;
        const int eq = l.indexOf('=');
        const int dash = l.indexOf('-', eq);
        if (eq < 0 || dash < 0) break;
        bool ok1 = false, ok2 = false;
        m_rangeStart = l.mid(eq + 1, dash - eq - 1).trimmed().toLongLong(&ok1);
        const QByteArray e = l.mid(dash + 1).trimmed();
        m_rangeEnd = e.isEmpty() ? -1 : e.toLongLong(&ok2);
        if (!ok1) { m_rangeStart = 0; m_rangeEnd = -1; break; }
        if (!e.isEmpty() && !ok2) m_rangeEnd = -1;
        m_hasRange = true;
        break;
    }

    if (kind == "f") {
        const QString p = m_lib->pathForId(id);
        if (p.isEmpty()) { fail("404 Not Found"); return; }
        startFile(p, head);
    } else if (kind == "r") {
        const QString u = m_lib->urlForId(id);
        if (u.isEmpty()) { fail("404 Not Found"); return; }
        m_lib->log(QString("aktarma %1%2").arg(head ? "HEAD " : "").arg(m_hasRange ? QString("aralik %1-").arg(m_rangeStart) : QString()));
        startRelay(QUrl(u), head);
    } else {
        fail("404 Not Found");
    }
}

// ---- Dosya ----

void ServeConn::startFile(const QString &path, bool head)
{
    m_file.setFileName(path);
    if (!m_file.open(QIODevice::ReadOnly)) { fail("404 Not Found"); return; }
    const qint64 total = m_file.size();
    const qint64 start = m_hasRange ? m_rangeStart : 0;
    if (total <= 0 || start >= total) {
        m_closing = true;
        m_sock->write(QByteArray("HTTP/1.1 416 Requested Range Not Satisfiable\r\nContent-Range: bytes */")
                      + QByteArray::number(total) + "\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");
        m_sock->disconnectFromHost();
        return;
    }
    const qint64 end = (m_hasRange && m_rangeEnd >= 0) ? qMin(m_rangeEnd, total - 1) : total - 1;
    QByteArray h;
    if (m_hasRange)
        h = "HTTP/1.1 206 Partial Content\r\nContent-Range: bytes " + QByteArray::number(start) + "-"
            + QByteArray::number(end) + "/" + QByteArray::number(total) + "\r\n";
    else
        h = "HTTP/1.1 200 OK\r\n";
    h += "Content-Type: " + Lib::mimeFor(path) + "\r\n";
    h += "Content-Length: " + QByteArray::number(end - start + 1) + "\r\n";
    h += "Accept-Ranges: bytes\r\nConnection: close\r\n\r\n";
    m_sock->write(h);
    if (head) { m_closing = true; m_sock->disconnectFromHost(); return; }
    m_pos = start;
    m_end = end;
    m_file.seek(start);
    m_streaming = true;
    pumpFile();
}

void ServeConn::pumpFile()
{
    if (m_up) { relayPump(); return; }
    if (!m_streaming || m_closing || !m_sock) return;
    if (m_sock->state() != QAbstractSocket::ConnectedState) return;
    while (m_sock->bytesToWrite() < KMaxQueued && m_pos <= m_end) {
        const QByteArray d = m_file.read(qMin(KChunk, m_end + 1 - m_pos));
        if (d.isEmpty()) break;
        m_sock->write(d);
        m_pos += d.size();
    }
    if (m_pos > m_end || m_file.atEnd()) {
        m_closing = true;
        m_streaming = false;
        m_file.close();
        m_sock->disconnectFromHost();      // kalan veri gonderildikten sonra kapanir
    }
}

// ---- Aktarma ----

void ServeConn::startRelay(const QUrl &url, bool head)
{
    m_isHead = head;
    m_upHeaderSent = false;
    m_upDone = false;
    QNetworkRequest req(url);
    req.setRawHeader("User-Agent", KUserAgent);
    if (m_hasRange) {
        QByteArray r = "bytes=" + QByteArray::number(m_rangeStart) + "-";
        if (m_rangeEnd >= 0) r += QByteArray::number(m_rangeEnd);
        req.setRawHeader("Range", r);
    }
    m_up = head ? m_lib->nam()->head(req) : m_lib->nam()->get(req);
    m_up->setReadBufferSize(256 * 1024);       // oynatici yavas okursa uzak sunucudan da yavas cekilir
    connect(m_up, SIGNAL(metaDataChanged()), this, SLOT(relayMeta()));
    connect(m_up, SIGNAL(readyRead()), this, SLOT(relayPump()));
    connect(m_up, SIGNAL(finished()), this, SLOT(relayFinished()));
}

// Yonlendirme gelirse yeni adrese gidilir; oynaticiya yalnizca son yanit gonderilir
void ServeConn::relayMeta()
{
    if (!m_up || m_upHeaderSent || !m_sock) return;
    const int status = m_up->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (status == 0) return;
    const QUrl redirect = m_up->attribute(QNetworkRequest::RedirectionTargetAttribute).toUrl();
    if (status >= 300 && status < 400 && !redirect.isEmpty()) {
        if (++m_redirects > 6) { disconnect(m_up, 0, this, 0); m_up->abort(); m_up->deleteLater(); m_up = 0; fail("502 Bad Gateway"); return; }
        const QUrl next = m_up->url().resolved(redirect);
        disconnect(m_up, 0, this, 0);
        m_up->abort();
        m_up->deleteLater();
        m_up = 0;
        startRelay(next, m_isHead);
        return;
    }
    m_upHeaderSent = true;
    QByteArray h = "HTTP/1.1 " + QByteArray::number(status) + " "
            + m_up->attribute(QNetworkRequest::HttpReasonPhraseAttribute).toByteArray() + "\r\n";
    const char *keep[] = { "Content-Type", "Content-Length", "Content-Range", "Last-Modified", "ETag" };
    for (unsigned i = 0; i < sizeof(keep) / sizeof(keep[0]); ++i)
        if (m_up->hasRawHeader(keep[i])) h += QByteArray(keep[i]) + ": " + m_up->rawHeader(keep[i]) + "\r\n";
    h += "Accept-Ranges: bytes\r\nConnection: close\r\n\r\n";
    m_sock->write(h);
    relayPump();
}

void ServeConn::relayPump()
{
    if (m_closing || !m_sock || !m_up) return;
    if (m_sock->state() != QAbstractSocket::ConnectedState) return;
    if (!m_upHeaderSent) { relayMeta(); if (!m_upHeaderSent) return; }
    if (m_isHead) { m_closing = true; m_up->abort(); m_sock->disconnectFromHost(); return; }
    while (m_sock->bytesToWrite() < KMaxQueued && m_up->bytesAvailable() > 0)
        m_sock->write(m_up->read(KChunk));
    if (m_upDone && m_up->bytesAvailable() == 0) {
        m_closing = true;
        m_sock->disconnectFromHost();
    }
}

void ServeConn::relayFinished()
{
    if (!m_up) return;
    m_upDone = true;
    if (!m_upHeaderSent) {
        QNetworkReply *before = m_up;
        relayMeta();
        if (!m_up || m_up != before) return;       // yonlendirildi ya da hata yazildi
        if (!m_upHeaderSent) {
            m_lib->log("aktarma hatasi: " + m_up->errorString());
            fail("502 Bad Gateway");
            return;
        }
    }
    relayPump();
}
