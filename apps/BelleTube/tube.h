#ifndef TUBE_H
#define TUBE_H

#include <QtCore/QObject>
#include <QtCore/QFile>
#include <QtCore/QVariantList>
#include <QtCore/QTime>
#include <QtCore/QStringList>

class QNetworkAccessManager;
class QNetworkReply;
class QTcpServer;

// QML'e "tube" adiyla acilir: videolari telefona indirir, inenleri kitaplik olarak yonetir.
// Her video tek bir dosyaya iner (E:/Videos/BelleTube/<id>_<tur>.mp4); sarma bu dosyadan yapilir.
class Tube : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool downloading READ downloading NOTIFY downloadingChanged)
    Q_PROPERTY(QString currentKey READ currentKey NOTIFY downloadingChanged)

public:
    explicit Tube(QObject *parent = 0);

    Q_INVOKABLE QString cacheDir() const { return m_dir; }
    Q_INVOKABLE QString pathFor(const QString &id, const QString &kind) const;
    Q_INVOKABLE QString fileUrl(const QString &path) const;
    Q_INVOKABLE bool isComplete(const QString &id, const QString &kind) const;
    Q_INVOKABLE qint64 fileBytes(const QString &path) const;

    // Oynatici icin yerel adres (http://127.0.0.1:port/<id>_<tur>): inmekte olan dosyayi
    // indirmeyle es zamanli verir; sarma istekleri telefondaki dosyadan karsilanir.
    // Yerel sunucu acilamazsa dosya adresini dondurur.
    Q_INVOKABLE QString streamUrl(const QString &id, const QString &kind) const;
    // Izleme (akis): yerel sunucu uzerinden uzak sunucuya aktarma adresi; dosyaya yazilmaz
    Q_INVOKABLE QString relayUrl(const QString &id, const QString &kind) const;
    Q_INVOKABLE void setRemote(const QString &server, const QString &key) { m_remote = server; m_remoteKey = key; }
    QString remoteUrlFor(const QString &key) const;      // "id_tur" -> uzak adres
    QString remoteKey() const { return m_remoteKey; }
    QNetworkAccessManager *nam() const { return m_nam; }
    Q_INVOKABLE bool openExternally(const QString &path) const;

    // Oynatici gunlugu (telefonda dosya; Ayarlar'dan gorulur)
    Q_INVOKABLE void log(const QString &line);
    Q_INVOKABLE QString logText() const;
    Q_INVOKABLE void clearLog();
    Q_INVOKABLE void copyText(const QString &text) const;   // panoya kopyala

    // Yerel sunucu icin (ProxyConn kullanir)
    qint64 availableBytes(const QString &key) const;   // -1: yok / iptal
    qint64 totalBytesFor(const QString &key) const;    // 0: henuz bilinmiyor, -1: yok
    QByteArray readChunk(const QString &key, qint64 pos, qint64 len);

    // kind: "360", "480" veya "audio"
    Q_INVOKABLE void download(const QString &url, const QString &key, const QString &id, const QString &kind,
                              const QString &title, const QString &channel, int seconds);
    Q_INVOKABLE void cancel();

    Q_INVOKABLE QVariantList library() const;
    Q_INVOKABLE void removeItem(const QString &id, const QString &kind);
    Q_INVOKABLE qint64 totalBytes() const;
    Q_INVOKABLE void enforceLimit(qint64 maxBytes, const QString &keepId);
    Q_INVOKABLE QString sizeText(qint64 bytes) const;

    bool downloading() const { return m_reply != 0; }
    QString currentKey() const { return m_key; }

signals:
    void progress(const QString &videoId, const QString &kind, qint64 received, qint64 total, int speedKBs);
    void finished(const QString &videoId, const QString &kind, bool ok, const QString &path, const QString &message);
    void downloadingChanged();
    void dataWritten();

private slots:
    void onNewConnection();
    void onReadyRead();
    void onProgress(qint64 received, qint64 total);
    void onFinished();

private:
    QString metaPath(const QString &id, const QString &kind) const;
    QString pathForKey(const QString &key) const;

    QTcpServer *m_server;
    qint64 m_written, m_total;

    QString m_dir;
    QString m_remote, m_remoteKey;
    QStringList m_log;
    bool m_logLoaded;
    QNetworkAccessManager *m_nam;
    QNetworkReply *m_reply;
    QFile m_file;
    QString m_id, m_kind, m_key;
    QTime m_started;
    bool m_cancelled;
};

#endif
