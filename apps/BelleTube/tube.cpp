#include "tube.h"
#include "depo.h"
#include "belleadres.h"
#include "dil.h"
#include "proxyconn.h"

#include <QtCore/QDir>
#include <QtCore/QDebug>
#include <QtCore/QFileInfo>
#include <QtCore/QSettings>
#include <QtCore/QDateTime>
#include <QtCore/QUrl>
#include <QtCore/QList>
#include <QtCore/QtAlgorithms>
#include <QtCore/QVariantMap>
#include <QtGui/QDesktopServices>
#include <QtGui/QApplication>
#include <QtGui/QClipboard>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkRequest>
#include <QtNetwork/QNetworkReply>
#include <QtNetwork/QTcpServer>
#include <QtNetwork/QTcpSocket>
#include <QtNetwork/QHostAddress>

Tube::Tube(QObject *parent)
    : QObject(parent), m_server(new QTcpServer(this)), m_written(0), m_total(0),
      m_logLoaded(false), m_nam(new QNetworkAccessManager(this)), m_reply(0), m_cancelled(false)
{
#if defined(Q_OS_SYMBIAN)
    // Yigin bellek (E:) varsa oraya, yoksa telefon bellegine
    m_dir = Depo::yol("Videos/E6Tube");
#else
    m_dir = QDesktopServices::storageLocation(QDesktopServices::TempLocation) + "/E6Tube";
#endif
    QDir().mkpath(m_dir);

    // Eski surumlerin m4a ses dosyalari telefonda calmiyordu (artik MP3 indiriliyor): temizle
    foreach (const QString &f, QDir(m_dir).entryList(QStringList() << "*_audio.m4a", QDir::Files)) {
        const QString base = f.left(f.length() - 4);           // <id>_audio
        QFile::remove(m_dir + "/" + f);
        if (!QFile::exists(m_dir + "/" + base + ".mp3")) QFile::remove(m_dir + "/" + base + ".ini");
    }

    // Oynatici icin yerel sunucu (yalnizca telefonun kendisinden erisilir)
    connect(m_server, SIGNAL(newConnection()), this, SLOT(onNewConnection()));
    m_server->listen(QHostAddress::LocalHost, 0);
}

QString Tube::pathFor(const QString &id, const QString &kind) const
{
    return m_dir + "/" + id + "_" + kind + (kind == "audio" ? ".mp3" : ".mp4");
}

QString Tube::metaPath(const QString &id, const QString &kind) const
{
    return m_dir + "/" + id + "_" + kind + ".ini";
}

QString Tube::fileUrl(const QString &path) const
{
    return QUrl::fromLocalFile(path).toString();
}

bool Tube::isComplete(const QString &id, const QString &kind) const
{
    if (!QFile::exists(pathFor(id, kind))) return false;
    QSettings s(metaPath(id, kind), QSettings::IniFormat);
    return s.value("complete", false).toBool();
}

qint64 Tube::fileBytes(const QString &path) const
{
    return QFileInfo(path).size();
}

QString Tube::sizeText(qint64 b) const
{
    if (b >= 1024LL * 1024 * 1024) return QString::number(b / (1024.0 * 1024 * 1024), 'f', 2) + " GB";
    if (b >= 1024 * 1024) return QString::number(b / (1024.0 * 1024), 'f', 1) + " MB";
    return QString::number((b + 1023) / 1024) + " KB";
}

// ---------------- Indirme ----------------

void Tube::download(const QString &url, const QString &key, const QString &id, const QString &kind,
                    const QString &title, const QString &channel, int seconds)
{
    const QString k = id + "_" + kind;
    if (m_reply && m_key == k) return;          // zaten iniyor
    if (m_reply) cancel();                      // baska video inerken yenisi istendi

    if (isComplete(id, kind)) {
        emit finished(id, kind, true, pathFor(id, kind), Dil::t("Telefonda kayıtlı"));
        return;
    }

    {
        QSettings s(metaPath(id, kind), QSettings::IniFormat);
        s.setValue("id", id);
        s.setValue("kind", kind);
        s.setValue("title", title);
        s.setValue("channel", channel);
        s.setValue("seconds", seconds);
        s.setValue("complete", false);
        s.setValue("time", QDateTime::currentDateTime().toTime_t());
        s.sync();
    }

    m_file.setFileName(pathFor(id, kind));
    // ReadWrite: yerel sunucu inen kismi ayni dosya tutamacindan okur
    if (!m_file.open(QIODevice::ReadWrite | QIODevice::Truncate)) {
        emit finished(id, kind, false, QString(), Dil::t("Dosya yazılamadı: ") + m_file.errorString());
        return;
    }
    m_id = id;
    m_kind = kind;
    m_key = k;
    m_cancelled = false;
    m_written = 0;
    m_total = 0;
    m_started.start();

    QNetworkRequest req((QUrl(url)));
    if (!key.isEmpty()) req.setRawHeader("X-Api-Key", key.toUtf8()); req.setRawHeader("X-Lang", Dil::kodu());
    m_reply = m_nam->get(req);
    m_reply->setReadBufferSize(256 * 1024);
    connect(m_reply, SIGNAL(readyRead()), this, SLOT(onReadyRead()));
    connect(m_reply, SIGNAL(downloadProgress(qint64,qint64)), this, SLOT(onProgress(qint64,qint64)));
    connect(m_reply, SIGNAL(finished()), this, SLOT(onFinished()));
    emit downloadingChanged();
    emit progress(m_id, m_kind, 0, 0, 0);
}

void Tube::onReadyRead()
{
    if (!m_reply) return;
    const QByteArray d = m_reply->readAll();
    if (d.isEmpty()) return;
    m_file.seek(m_written);
    m_written += m_file.write(d);
    m_file.flush();
    emit dataWritten();
}

void Tube::onProgress(qint64 received, qint64 total)
{
    if (total > 0) m_total = total;
    const int ms = qMax(1, m_started.elapsed());
    emit progress(m_id, m_kind, received, total, int(received / ms));   // bayt/ms ~= KB/s
}

void Tube::cancel()
{
    if (!m_reply) return;
    m_cancelled = true;
    m_reply->abort();
}

void Tube::onFinished()
{
    QNetworkReply *r = m_reply;
    if (!r) return;
    const QByteArray rest = r->readAll();
    if (!rest.isEmpty()) { m_file.seek(m_written); m_written += m_file.write(rest); }
    m_file.close();
    const int status = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const bool ok = !m_cancelled && r->error() == QNetworkReply::NoError && status >= 200 && status < 300;
    QString msg;
    if (ok) {
        QSettings s(metaPath(m_id, m_kind), QSettings::IniFormat);
        s.setValue("complete", true);
        s.setValue("size", QFileInfo(m_file.fileName()).size());
        s.sync();
        msg = Dil::t("İndirildi");
    } else {
        if (m_cancelled) msg = Dil::t("İptal edildi");
        else if (status == 403) msg = Dil::t("Sunucu parolası hatalı");
        else if (status == 0) msg = Dil::t("Bağlantı koptu");
        else {
            const QByteArray d = r->readAll();
            const int i = d.indexOf("\"error\":\"");
            msg = i >= 0 ? QString::fromUtf8(d.mid(i + 9, d.indexOf('"', i + 9) - i - 9))
                         : Dil::t("İndirilemedi (") + QString::number(status) + ")";
        }
        QFile::remove(m_file.fileName());
        QFile::remove(metaPath(m_id, m_kind));
    }
    const QString id = m_id, kind = m_kind, path = m_file.fileName();
    m_reply = 0;
    m_key.clear();
    r->deleteLater();
    emit downloadingChanged();
    emit finished(id, kind, ok, ok ? path : QString(), msg);
    emit dataWritten();     // bekleyen yerel baglantilar tamamlanmis dosyadan devam etsin
}

// ---------------- Kitaplik ----------------

static bool newestFirst(const QVariant &a, const QVariant &b)
{
    return a.toMap().value("time").toUInt() > b.toMap().value("time").toUInt();
}

QVariantList Tube::library() const
{
    QVariantList out;
    QDir d(m_dir);
    foreach (const QString &f, d.entryList(QStringList() << "*.ini", QDir::Files)) {
        QSettings s(m_dir + "/" + f, QSettings::IniFormat);
        if (!s.value("complete", false).toBool()) continue;
        const QString id = s.value("id").toString();
        const QString kind = s.value("kind").toString();
        const QString p = pathFor(id, kind);
        if (!QFile::exists(p)) continue;
        QVariantMap m;
        m["id"] = id;
        m["kind"] = kind;
        m["title"] = s.value("title").toString();
        m["channel"] = s.value("channel").toString();
        m["seconds"] = s.value("seconds").toInt();
        m["time"] = s.value("time").toUInt();
        m["size"] = QFileInfo(p).size();
        m["path"] = p;
        out << m;
    }
    qSort(out.begin(), out.end(), newestFirst);
    return out;
}

void Tube::removeItem(const QString &id, const QString &kind)
{
    if (m_reply && m_key == id + "_" + kind) cancel();
    QFile::remove(pathFor(id, kind));
    QFile::remove(metaPath(id, kind));
}

qint64 Tube::totalBytes() const
{
    qint64 t = 0;
    QDir d(m_dir);
    foreach (const QFileInfo &fi, d.entryInfoList(QStringList() << "*.mp4" << "*.m4a" << "*.mp3", QDir::Files)) t += fi.size();
    return t;
}

void Tube::enforceLimit(qint64 maxBytes, const QString &keepId)
{
    QVariantList items = library();      // yeniden eskiye
    qint64 total = totalBytes();
    for (int i = items.size() - 1; i >= 0 && total > maxBytes; --i) {
        const QVariantMap m = items.at(i).toMap();
        if (m.value("id").toString() == keepId) continue;
        total -= m.value("size").toLongLong();
        removeItem(m.value("id").toString(), m.value("kind").toString());
    }
}

// ---------------- Yerel sunucu (inerken oynatma) ----------------

QString Tube::pathForKey(const QString &key) const
{
    const int i = key.lastIndexOf('_');            // video kimliginde de '_' olabilir
    if (i <= 0) return QString();
    return pathFor(key.left(i), key.mid(i + 1));
}

QString Tube::streamUrl(const QString &id, const QString &kind) const
{
    if (!m_server->isListening()) return fileUrl(pathFor(id, kind));
    return QString("http://127.0.0.1:%1/%2_%3%4").arg(m_server->serverPort()).arg(id).arg(kind)
            .arg(kind == "audio" ? ".mp3" : ".mp4");
}

QString Tube::relayUrl(const QString &id, const QString &kind) const
{
    if (!m_server->isListening() || m_remote.isEmpty()) return belleDuzHttp(remoteUrlFor(id + "_" + kind));   // yerlesik oynatici: duz HTTP
    return QString("http://127.0.0.1:%1/r/%2_%3%4").arg(m_server->serverPort()).arg(id).arg(kind)
            .arg(kind == "audio" ? ".mp3" : ".mp4");
}

QString Tube::remoteUrlFor(const QString &key) const
{
    const int i = key.lastIndexOf('_');
    if (i <= 0) return QString();
    const QString id = key.left(i), kind = key.mid(i + 1);
    if (kind == "audio") return m_remote + "/yt/audio/" + id + ".mp3";
    return m_remote + "/yt/stream/" + id + ".mp4?q=" + kind;
}

bool Tube::openExternally(const QString &path) const
{
    return QDesktopServices::openUrl(QUrl::fromLocalFile(path));
}

qint64 Tube::availableBytes(const QString &key) const
{
    if (m_reply && key == m_key) return m_written;
    const int i = key.lastIndexOf('_');
    if (i > 0 && isComplete(key.left(i), key.mid(i + 1))) return QFileInfo(pathForKey(key)).size();
    return -1;
}

qint64 Tube::totalBytesFor(const QString &key) const
{
    if (m_reply && key == m_key) return m_total;
    return availableBytes(key);
}

QByteArray Tube::readChunk(const QString &key, qint64 pos, qint64 len)
{
    if (m_reply && key == m_key && m_file.isOpen()) {
        m_file.seek(pos);
        const QByteArray d = m_file.read(len);
        m_file.seek(m_written);
        return d;
    }
    QFile f(pathForKey(key));
    if (!f.open(QIODevice::ReadOnly)) return QByteArray();
    f.seek(pos);
    return f.read(len);
}

void Tube::onNewConnection()
{
    while (m_server->hasPendingConnections()) {
        QTcpSocket *s = m_server->nextPendingConnection();
        if (s) new ProxyConn(s, this);
    }
}

// ---------------- ProxyConn ----------------

static const qint64 KChunk = 64 * 1024;
static const qint64 KMaxQueued = 192 * 1024;

ProxyConn::ProxyConn(QTcpSocket *sock, Tube *tube)
    : QObject(tube), m_relay(false), m_upHeaderSent(false), m_upDone(false), m_isHead(false),
      m_sock(sock), m_tube(tube), m_pos(0), m_end(-1), m_rangeStart(0), m_rangeEnd(-1),
      m_hasRange(false), m_headerDone(false), m_streaming(false), m_closing(false), m_waitTicks(0)
{
    m_wait.setSingleShot(true);
    connect(&m_wait, SIGNAL(timeout()), this, SLOT(onWaitTick()));
    connect(m_sock, SIGNAL(readyRead()), this, SLOT(onReadyRead()));
    connect(m_sock, SIGNAL(bytesWritten(qint64)), this, SLOT(pump()));
    connect(m_sock, SIGNAL(disconnected()), this, SLOT(onDisconnected()));
    connect(m_tube, SIGNAL(dataWritten()), this, SLOT(pump()));
}

// Oynatici baglantiyi kapatti (sarma, sayfadan cikis...): bu baglanti artik hicbir sey yazmaz
void ProxyConn::onDisconnected()
{
    m_closing = true;
    m_streaming = false;
    m_wait.stop();
    if (m_up) { disconnect(m_up, 0, this, 0); m_up->abort(); m_up->deleteLater(); }
    disconnect(m_tube, 0, this, 0);
    if (m_sock) m_sock->deleteLater();
    deleteLater();
}

void ProxyConn::fail(const char *status)
{
    if (!m_sock) return;
    m_closing = true;
    m_sock->write(QByteArray("HTTP/1.1 ") + status + "\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");
    m_sock->disconnectFromHost();
}

void ProxyConn::onReadyRead()
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
    QByteArray path = req[1];
    const int q = path.indexOf('?');
    if (q >= 0) path = path.left(q);
    while (path.startsWith('/')) path = path.mid(1);
    const int dot = path.lastIndexOf('.');
    if (dot > 0) path = path.left(dot);
    m_key = QString::fromLatin1(path);
    const bool head = (req[0] == "HEAD");
    if (m_key.startsWith("r/")) { m_relay = true; m_key = m_key.mid(2); }
    else m_closing = head;
    m_tube->log(QString("yerel sunucu: %1 %2%3").arg(QString::fromLatin1(req[0])).arg(m_relay ? "aktar " : "").arg(m_key));

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
        m_tube->log(QString("  aralik %1-%2").arg(m_rangeStart).arg(m_rangeEnd));
        break;
    }
    if (m_relay) startRelay(head);
    else startResponse();
}

// ---------------- Aktarma (uzak sunucudan akis) ----------------

void ProxyConn::startRelay(bool head)
{
    m_isHead = head;
    const QString url = m_tube->remoteUrlFor(m_key);
    if (url.isEmpty()) { fail("404 Not Found"); return; }
    QNetworkRequest req((QUrl(url)));
    if (!m_tube->remoteKey().isEmpty()) req.setRawHeader("X-Api-Key", m_tube->remoteKey().toUtf8()); req.setRawHeader("X-Lang", Dil::kodu());
    if (m_hasRange) {
        QByteArray r = "bytes=" + QByteArray::number(m_rangeStart) + "-";
        if (m_rangeEnd >= 0) r += QByteArray::number(m_rangeEnd);
        req.setRawHeader("Range", r);
    }
    m_up = head ? m_tube->nam()->head(req) : m_tube->nam()->get(req);
    m_up->setReadBufferSize(256 * 1024);       // oynatici yavas okursa uzak sunucudan da yavas cekilir
    connect(m_up, SIGNAL(metaDataChanged()), this, SLOT(relayPump()));
    connect(m_up, SIGNAL(readyRead()), this, SLOT(relayPump()));
    connect(m_up, SIGNAL(finished()), this, SLOT(relayFinished()));
}

// Uzak yanitin basliklarini oynaticiya gonderir (bir kez)
bool ProxyConn::relayHeader()
{
    if (m_upHeaderSent) return true;
    if (!m_up || !m_sock) return false;
    const int status = m_up->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (status == 0) return false;            // basliklar henuz gelmedi
    m_upHeaderSent = true;
    QByteArray h = "HTTP/1.1 " + QByteArray::number(status) + " "
            + m_up->attribute(QNetworkRequest::HttpReasonPhraseAttribute).toByteArray() + "\r\n";
    const char *keep[] = { "Content-Type", "Content-Length", "Content-Range", "Last-Modified", "ETag" };
    for (unsigned i = 0; i < sizeof(keep) / sizeof(keep[0]); ++i)
        if (m_up->hasRawHeader(keep[i])) h += QByteArray(keep[i]) + ": " + m_up->rawHeader(keep[i]) + "\r\n";
    h += "Accept-Ranges: bytes\r\nConnection: close\r\n\r\n";
    m_sock->write(h);
    m_tube->log(QString("  aktarma yaniti %1 %2").arg(status).arg(QString::fromLatin1(m_up->rawHeader("Content-Length"))));
    return true;
}

void ProxyConn::relayPump()
{
    if (m_closing || !m_sock || !m_up) return;
    if (m_sock->state() != QAbstractSocket::ConnectedState) return;
    if (!relayHeader()) return;
    if (m_isHead) { m_closing = true; m_up->abort(); m_sock->disconnectFromHost(); return; }
    while (m_sock->bytesToWrite() < KMaxQueued && m_up->bytesAvailable() > 0)
        m_sock->write(m_up->read(KChunk));
    if (m_upDone && m_up->bytesAvailable() == 0) {
        m_closing = true;
        m_sock->disconnectFromHost();          // kalan veri gonderildikten sonra kapanir
    }
}

void ProxyConn::relayFinished()
{
    if (!m_up) return;
    m_upDone = true;
    if (!m_upHeaderSent && m_up->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt() == 0) {
        m_tube->log("  aktarma hatasi: " + m_up->errorString());
        fail("502 Bad Gateway");
        return;
    }
    relayPump();
}

void ProxyConn::startResponse()
{
    if (!m_sock || m_closing) return;
    const qint64 total = m_tube->totalBytesFor(m_key);
    if (total < 0) { fail("404 Not Found"); return; }
    if (total == 0) {                          // boyut henuz belli degil: biraz bekle
        if (++m_waitTicks > 150) { fail("503 Service Unavailable"); return; }
        m_wait.start(200);
        return;
    }
    const qint64 start = m_hasRange ? m_rangeStart : 0;
    if (start >= total) {
        m_closing = true;
        m_sock->write(QByteArray("HTTP/1.1 416 Requested Range Not Satisfiable\r\nContent-Range: bytes */")
                      + QByteArray::number(total) + "\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");
        m_sock->disconnectFromHost();
        return;
    }
    const qint64 end = (m_hasRange && m_rangeEnd >= 0) ? qMin(m_rangeEnd, total - 1) : total - 1;
    const bool audio = m_key.endsWith("_audio");

    QByteArray h;
    if (m_hasRange) {
        h = "HTTP/1.1 206 Partial Content\r\nContent-Range: bytes " + QByteArray::number(start) + "-"
            + QByteArray::number(end) + "/" + QByteArray::number(total) + "\r\n";
    } else {
        h = "HTTP/1.1 200 OK\r\n";
    }
    h += QByteArray("Content-Type: ") + (audio ? "audio/mpeg" : "video/mp4") + "\r\n";
    h += "Content-Length: " + QByteArray::number(end - start + 1) + "\r\n";
    h += "Accept-Ranges: bytes\r\nConnection: close\r\n\r\n";
    m_sock->write(h);

    if (m_closing) { m_sock->disconnectFromHost(); return; }   // HEAD
    m_pos = start;
    m_end = end;
    m_streaming = true;
    pump();
}

void ProxyConn::pump()
{
    if (m_relay) { relayPump(); return; }
    if (!m_streaming || m_closing || !m_sock) return;
    if (m_sock->state() != QAbstractSocket::ConnectedState) return;
    while (m_sock->bytesToWrite() < KMaxQueued && m_pos <= m_end) {
        const qint64 avail = m_tube->availableBytes(m_key);
        if (avail < 0) { m_closing = true; m_sock->disconnectFromHost(); return; }   // indirme iptal
        const qint64 limit = qMin(avail, m_end + 1);
        if (m_pos >= limit) { if (!m_wait.isActive()) m_wait.start(250); return; }  // veri bekleniyor
        const QByteArray d = m_tube->readChunk(m_key, m_pos, qMin(KChunk, limit - m_pos));
        if (d.isEmpty()) { if (!m_wait.isActive()) m_wait.start(250); return; }
        m_sock->write(d);
        m_pos += d.size();
    }
    if (m_pos > m_end) {
        m_closing = true;
        m_sock->disconnectFromHost();      // kalan veri gonderildikten sonra kapanir
    }
}

void ProxyConn::onWaitTick()
{
    if (!m_sock || m_closing) return;
    if (!m_streaming) startResponse();
    else pump();
}

// ---------------- Gunluk ----------------

// Yalnizca son 20 kayit tutulur (bellekte); cokme sonrasi da okunabilsin diye kucuk bir dosyaya
// yazilir. Dosya her seferinde bastan yazilir ama en fazla 20 satir oldugu icin yavaslatmaz.
static const int KLogLines = 20;

void Tube::log(const QString &line)
{
    if (m_logLoaded == false) {               // ilk kayitta onceki oturumun son satirlarini al
        m_logLoaded = true;
        QFile in(m_dir + "/e6tube.log");
        if (in.open(QIODevice::ReadOnly)) {
            m_log = QString::fromUtf8(in.readAll().right(4096)).split('\n', QString::SkipEmptyParts);
            while (m_log.size() > KLogLines) m_log.removeFirst();
        }
    }
    m_log << QDateTime::currentDateTime().toString("HH:mm:ss ") + line;
    qDebug("E6T %s", qPrintable(line));       // CODA ile bagliyken Qt Creator'da canli gorunur
    while (m_log.size() > KLogLines) m_log.removeFirst();
    QFile f(m_dir + "/e6tube.log");
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        f.write(m_log.join("\n").toUtf8());
        f.close();
    }
}

QString Tube::logText() const
{
    if (!m_logLoaded) {
        QFile in(m_dir + "/e6tube.log");
        if (in.open(QIODevice::ReadOnly)) return QString::fromUtf8(in.readAll().right(4096));
    }
    return m_log.isEmpty() ? Dil::t("(günlük boş)") : m_log.join("\n");
}

void Tube::clearLog()
{
    m_log.clear();
    m_logLoaded = true;
    QFile::remove(m_dir + "/e6tube.log");
}

void Tube::copyText(const QString &text) const
{
    QApplication::clipboard()->setText(text);
}