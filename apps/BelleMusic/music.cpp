#include "music.h"
#include "dil.h"
#include "relayconn.h"

#include <QtCore/QDir>
#include <QtCore/QDebug>
#include <QtCore/QFileInfo>
#include <QtCore/QDateTime>
#include <QtCore/QUrl>
#include <QtCore/QRegExp>
#include <QtGui/QApplication>
#include <QtGui/QClipboard>
#include <QtGui/QDesktopServices>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkRequest>
#include <QtNetwork/QNetworkReply>
#include <QtNetwork/QTcpServer>
#include <QtNetwork/QTcpSocket>
#include <QtNetwork/QHostAddress>

static const int KMaxSources = 60;      // aktaricida hatirlanan kaynak sayisi
static const int KMaxRedirects = 6;
static const int KLogLines = 30;

QByteArray Music::userAgent()
{
    // MIDPlay'in gonderdigi bicim; sunucu bazi uclarda tarayici disi istemci bekliyor
    return "NokiaE6-00/1.0 (MIDP-2.0; CLDC-1.1)";
}

static bool isRedirect(int s) { return s == 301 || s == 302 || s == 303 || s == 307 || s == 308; }

Music::Music(QObject *parent)
    : QObject(parent), m_server(new QTcpServer(this)), m_seq(0), m_nam(new QNetworkAccessManager(this)),
      m_redirects(0), m_cancelled(false), m_logLoaded(false)
{
#if defined(Q_OS_SYMBIAN)
    m_dir = QDir("E:/").exists() ? "E:/Muzik" : "C:/Data/Muzik";
#else
    m_dir = QDesktopServices::storageLocation(QDesktopServices::MusicLocation) + "/E6Muzik";
#endif
    QDir().mkpath(m_dir);
    connect(m_server, SIGNAL(newConnection()), this, SLOT(onNewConnection()));
    m_server->listen(QHostAddress::LocalHost, 0);
}

// ---------------- Yerel aktarici ----------------

QString Music::streamUrl(const QString &source)
{
    if (source.isEmpty()) return QString();
    const bool remote = source.startsWith("http://") || source.startsWith("https://");
    if (!m_server->isListening()) return remote ? source : fileUrl(source);
    // Ayni kaynak icin ayni adres (oynatici sararken yeni baglanti acar)
    QString id;
    foreach (const QString &k, m_order) if (m_sources.value(k) == source) { id = k; break; }
    if (id.isEmpty()) {
        id = QString::number(++m_seq);
        m_sources.insert(id, source);
        m_order << id;
        while (m_order.size() > KMaxSources) m_sources.remove(m_order.takeFirst());
    }
    return QString("http://127.0.0.1:%1/s/%2.mp3").arg(m_server->serverPort()).arg(id);
}

QString Music::fileUrl(const QString &path) const
{
    return QUrl::fromLocalFile(path).toString();
}

void Music::onNewConnection()
{
    while (m_server->hasPendingConnections()) {
        QTcpSocket *s = m_server->nextPendingConnection();
        if (s) new RelayConn(s, this);
    }
}

// ---------------- Indirme kuyrugu ----------------

bool Music::isQueued(const QString &key) const
{
    if (m_reply && m_cur.key == key) return true;
    foreach (const Job &j, m_jobs) if (j.key == key) return true;
    return false;
}

void Music::download(const QString &key, const QString &url, const QString &fileName)
{
    if (key.isEmpty() || url.isEmpty() || isQueued(key)) return;
    QString n = fileName;
    n.replace(QRegExp("[\\\\/:*?\"<>|\\r\\n\\t]"), "_");
    n = n.trimmed();
    if (n.isEmpty()) n = "muzik";
    if (n.length() > 120) n = n.left(120);
    Job j;
    j.key = key;
    j.url = url;
    j.path = m_dir + "/" + n + ".mp3";
    m_jobs << j;
    emit queueChanged();
    if (!m_reply) startNext();
}

void Music::startNext()
{
    if (m_reply || m_jobs.isEmpty()) return;
    m_cur = m_jobs.takeFirst();
    m_file.setFileName(m_cur.path + ".part");
    if (!m_file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        const Job j = m_cur;
        m_cur = Job();
        emit finished(j.key, false, QString(), Dil::t("Dosya yazılamadı"));
        emit queueChanged();
        startNext();
        return;
    }
    m_cancelled = false;
    m_redirects = 0;
    request(QUrl::fromEncoded(m_cur.url.toUtf8()));
    emit queueChanged();
    emit progress(m_cur.key, 0, 0);
}

void Music::request(const QUrl &url)
{
    QNetworkRequest req(url);
    req.setRawHeader("User-Agent", userAgent());
    m_reply = m_nam->get(req);
    m_reply->setReadBufferSize(128 * 1024);
    connect(m_reply, SIGNAL(readyRead()), this, SLOT(onReadyRead()));
    connect(m_reply, SIGNAL(downloadProgress(qint64,qint64)), this, SLOT(onProgress(qint64,qint64)));
    connect(m_reply, SIGNAL(finished()), this, SLOT(onFinished()));
}

void Music::onReadyRead()
{
    if (!m_reply) return;
    if (isRedirect(m_reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt())) return;
    m_file.write(m_reply->readAll());
}

void Music::onProgress(qint64 received, qint64 total)
{
    if (!m_reply || isRedirect(m_reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt())) return;
    emit progress(m_cur.key, double(received), double(total));
}

void Music::cancel(const QString &key)
{
    for (int i = m_jobs.size() - 1; i >= 0; --i) {
        if (m_jobs.at(i).key == key) {
            m_jobs.removeAt(i);
            emit finished(key, false, QString(), Dil::t("İptal edildi"));
        }
    }
    if (m_reply && m_cur.key == key) { m_cancelled = true; m_reply->abort(); }
    emit queueChanged();
}

void Music::cancelAll()
{
    while (!m_jobs.isEmpty()) {
        const Job j = m_jobs.takeFirst();
        emit finished(j.key, false, QString(), Dil::t("İptal edildi"));
    }
    if (m_reply) { m_cancelled = true; m_reply->abort(); }
    emit queueChanged();
}

void Music::onFinished()
{
    QNetworkReply *r = m_reply;
    if (!r) return;
    const int status = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (!m_cancelled && isRedirect(status) && m_redirects < KMaxRedirects) {
        const QUrl next = r->url().resolved(r->attribute(QNetworkRequest::RedirectionTargetAttribute).toUrl());
        r->deleteLater();
        m_reply = 0;
        ++m_redirects;
        request(next);
        return;
    }
    m_file.write(r->readAll());
    m_file.close();
    const bool ok = !m_cancelled && r->error() == QNetworkReply::NoError && status >= 200 && status < 300
                    && QFileInfo(m_file.fileName()).size() > 10 * 1024;
    QString msg;
    QString path;
    if (ok) {
        QFile::remove(m_cur.path);
        QFile::rename(m_file.fileName(), m_cur.path);
        path = m_cur.path;
        msg = Dil::t("İndirildi");
    } else {
        QFile::remove(m_file.fileName());
        if (m_cancelled) msg = Dil::t("İptal edildi");
        else if (status == 0) msg = Dil::t("Bağlantı koptu");
        else msg = Dil::t("İndirilemedi (") + QString::number(status) + ")";
        log("indirme hata " + QString::number(status) + " " + r->errorString());
    }
    const QString key = m_cur.key;
    m_cur = Job();
    m_reply = 0;
    r->deleteLater();
    emit finished(key, ok, path, msg);
    emit queueChanged();
    startNext();
}

bool Music::fileExists(const QString &path) const { return !path.isEmpty() && QFile::exists(path); }
bool Music::removeFile(const QString &path) { return QFile::remove(path); }
double Music::fileSize(const QString &path) const { return double(QFileInfo(path).size()); }

QString Music::sizeText(double b) const
{
    if (b >= 1024.0 * 1024 * 1024) return QString::number(b / (1024.0 * 1024 * 1024), 'f', 2) + " GB";
    if (b >= 1024.0 * 1024) return QString::number(b / (1024.0 * 1024), 'f', 1) + " MB";
    return QString::number(qint64((b + 1023) / 1024)) + " KB";
}

// ---------------- Gunluk ----------------

// Gunluk: C:/Data/E6Muzik/gunluk.txt (E6Merkez "Rapor gonder" bu dosyayi ekler)
static QString logPath()
{
#if defined(Q_OS_SYMBIAN)
    static const QString p = "C:/Data/E6Muzik/gunluk.txt";
#else
    static const QString p = QDir::homePath() + "/E6Muzik/gunluk.txt";
#endif
    return p;
}

void Music::log(const QString &line)
{
    if (!m_logLoaded) {
        m_logLoaded = true;
        QDir().mkpath(QFileInfo(logPath()).absolutePath());
        QFile in(logPath());
        if (in.open(QIODevice::ReadOnly)) {
            m_log = QString::fromUtf8(in.readAll().right(6000)).split('\n', QString::SkipEmptyParts);
            while (m_log.size() > KLogLines) m_log.removeFirst();
        }
    }
    m_log << QDateTime::currentDateTime().toString("HH:mm:ss ") + line;
    qDebug("E6M %s", qPrintable(line));       // CODA ile bagliyken Qt Creator'da canli gorunur
    while (m_log.size() > KLogLines) m_log.removeFirst();
    QFile f(logPath());
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        f.write(m_log.join("\n").toUtf8());
        f.close();
    }
}

QString Music::logText() const
{
    if (!m_logLoaded) {
        QFile in(logPath());
        if (in.open(QIODevice::ReadOnly)) return QString::fromUtf8(in.readAll().right(6000));
    }
    return m_log.isEmpty() ? Dil::t("(günlük boş)") : m_log.join("\n");
}

void Music::clearLog()
{
    m_log.clear();
    m_logLoaded = true;
    QFile::remove(logPath());
}

void Music::copyText(const QString &text) const
{
    QApplication::clipboard()->setText(text);
}

// ---------------- RelayConn ----------------

static const qint64 KChunk = 32 * 1024;
static const qint64 KMaxQueued = 128 * 1024;

RelayConn::RelayConn(QTcpSocket *sock, Music *music)
    : QObject(music), m_music(music), m_sock(sock), m_headerDone(false), m_isHead(false), m_hasRange(false),
      m_upHeaderSent(false), m_upDone(false), m_closing(false), m_rangeStart(0), m_rangeEnd(-1),
      m_pos(0), m_end(-1), m_redirects(0)
{
    connect(m_sock, SIGNAL(readyRead()), this, SLOT(onReadyRead()));
    connect(m_sock, SIGNAL(disconnected()), this, SLOT(onDisconnected()));
}

void RelayConn::onDisconnected()
{
    m_closing = true;
    if (m_up) { disconnect(m_up, 0, this, 0); m_up->abort(); m_up->deleteLater(); }
    if (m_file.isOpen()) m_file.close();
    if (m_sock) m_sock->deleteLater();
    deleteLater();
}

void RelayConn::fail(const char *status)
{
    if (!m_sock) return;
    m_closing = true;
    m_sock->write(QByteArray("HTTP/1.1 ") + status + "\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");
    m_sock->disconnectFromHost();
}

void RelayConn::onReadyRead()
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
    m_isHead = req[0] == "HEAD";
    QByteArray path = req[1];
    const int q = path.indexOf('?');
    if (q >= 0) path = path.left(q);
    if (!path.startsWith("/s/")) { fail("404 Not Found"); return; }
    path = path.mid(3);
    const int dot = path.lastIndexOf('.');
    if (dot > 0) path = path.left(dot);
    const QString source = m_music->sourceFor(QString::fromLatin1(path));
    if (source.isEmpty()) { fail("404 Not Found"); return; }

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
    if (source.startsWith("http://") || source.startsWith("https://")) startRemote(QUrl::fromEncoded(source.toUtf8()));
    else startFile(source);
}

// ---- Telefondaki dosya ----
void RelayConn::startFile(const QString &path)
{
    m_file.setFileName(path);
    if (!m_file.open(QIODevice::ReadOnly)) { fail("404 Not Found"); return; }
    const qint64 total = m_file.size();
    const qint64 start = m_hasRange ? m_rangeStart : 0;
    if (start >= total) {
        m_closing = true;
        m_sock->write(QByteArray("HTTP/1.1 416 Requested Range Not Satisfiable\r\nContent-Range: bytes */")
                      + QByteArray::number(total) + "\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");
        m_sock->disconnectFromHost();
        return;
    }
    const qint64 last = (m_hasRange && m_rangeEnd >= 0) ? qMin(m_rangeEnd, total - 1) : total - 1;
    QByteArray h = m_hasRange
        ? "HTTP/1.1 206 Partial Content\r\nContent-Range: bytes " + QByteArray::number(start) + "-" + QByteArray::number(last) + "/" + QByteArray::number(total) + "\r\n"
        : QByteArray("HTTP/1.1 200 OK\r\n");
    h += "Content-Type: audio/mpeg\r\nContent-Length: " + QByteArray::number(last - start + 1) + "\r\nAccept-Ranges: bytes\r\nConnection: close\r\n\r\n";
    m_sock->write(h);
    if (m_isHead) { m_closing = true; m_sock->disconnectFromHost(); return; }
    m_pos = start;
    m_end = last;
    m_file.seek(start);
    connect(m_sock, SIGNAL(bytesWritten(qint64)), this, SLOT(filePump()));
    filePump();
}

void RelayConn::filePump()
{
    if (m_closing || !m_sock || !m_file.isOpen()) return;
    while (m_sock->bytesToWrite() < KMaxQueued && m_pos <= m_end) {
        const QByteArray d = m_file.read(qMin(KChunk, m_end + 1 - m_pos));
        if (d.isEmpty()) break;
        m_sock->write(d);
        m_pos += d.size();
    }
    if (m_pos > m_end) { m_closing = true; m_file.close(); m_sock->disconnectFromHost(); }
}

// ---- Uzak kaynak ----
void RelayConn::startRemote(const QUrl &url)
{
    QNetworkRequest req(url);
    req.setRawHeader("User-Agent", Music::userAgent());
    if (m_hasRange) {
        QByteArray r = "bytes=" + QByteArray::number(m_rangeStart) + "-";
        if (m_rangeEnd >= 0) r += QByteArray::number(m_rangeEnd);
        req.setRawHeader("Range", r);
    }
    m_upHeaderSent = false;
    m_upDone = false;
    m_up = m_isHead ? m_music->nam()->head(req) : m_music->nam()->get(req);
    m_up->setReadBufferSize(192 * 1024);        // oynatici yavas okursa uzak sunucudan da yavas cekilir
    connect(m_up, SIGNAL(metaDataChanged()), this, SLOT(upMeta()));
    connect(m_up, SIGNAL(readyRead()), this, SLOT(upPump()));
    connect(m_up, SIGNAL(finished()), this, SLOT(upFinished()));
    connect(m_sock, SIGNAL(bytesWritten(qint64)), this, SLOT(upPump()));
}

void RelayConn::upMeta()
{
    if (!m_up) return;
    const int status = m_up->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (isRedirect(status)) return;            // upFinished yonlendirmeyi izler
    upPump();
}

bool RelayConn::sendUpHeader()
{
    if (m_upHeaderSent) return true;
    if (!m_up || !m_sock) return false;
    const int status = m_up->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (status == 0 || isRedirect(status)) return false;
    m_upHeaderSent = true;
    QByteArray h = "HTTP/1.1 " + QByteArray::number(status) + " "
            + m_up->attribute(QNetworkRequest::HttpReasonPhraseAttribute).toByteArray() + "\r\n";
    QByteArray ctype = m_up->rawHeader("Content-Type");
    if (ctype.isEmpty() || ctype.startsWith("application/octet") || ctype.startsWith("binary/")) ctype = "audio/mpeg";
    h += "Content-Type: " + ctype + "\r\n";
    const char *keep[] = { "Content-Length", "Content-Range", "Last-Modified", "ETag" };
    for (unsigned i = 0; i < sizeof(keep) / sizeof(keep[0]); ++i)
        if (m_up->hasRawHeader(keep[i])) h += QByteArray(keep[i]) + ": " + m_up->rawHeader(keep[i]) + "\r\n";
    h += "Accept-Ranges: bytes\r\nConnection: close\r\n\r\n";
    m_sock->write(h);
    if (status >= 400) m_music->log(QString("aktarma: sunucu %1").arg(status));
    return true;
}

void RelayConn::upPump()
{
    if (m_closing || !m_sock || !m_up) return;
    if (m_sock->state() != QAbstractSocket::ConnectedState) return;
    if (!sendUpHeader()) return;
    if (m_isHead) { m_closing = true; m_up->abort(); m_sock->disconnectFromHost(); return; }
    while (m_sock->bytesToWrite() < KMaxQueued && m_up->bytesAvailable() > 0)
        m_sock->write(m_up->read(KChunk));
    if (m_upDone && m_up->bytesAvailable() == 0) {
        m_closing = true;
        m_sock->disconnectFromHost();          // kalan veri gonderildikten sonra kapanir
    }
}

void RelayConn::upFinished()
{
    if (!m_up || m_closing) return;
    const int status = m_up->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (isRedirect(status) && !m_upHeaderSent) {
        if (++m_redirects > KMaxRedirects) { fail("508 Loop Detected"); return; }
        const QUrl next = m_up->url().resolved(m_up->attribute(QNetworkRequest::RedirectionTargetAttribute).toUrl());
        disconnect(m_sock, SIGNAL(bytesWritten(qint64)), this, SLOT(upPump()));
        QNetworkReply *old = m_up;
        disconnect(old, 0, this, 0);
        old->deleteLater();
        startRemote(next);
        return;
    }
    m_upDone = true;
    if (!m_upHeaderSent && status == 0) {
        m_music->log("aktarma hatasi: " + m_up->errorString());
        fail("502 Bad Gateway");
        return;
    }
    upPump();
}
