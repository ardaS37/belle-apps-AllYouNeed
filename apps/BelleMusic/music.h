#ifndef MUSIC_H
#define MUSIC_H

#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QStringList>
#include <QtCore/QHash>
#include <QtCore/QFile>
#include <QtCore/QTime>
#include <QtCore/QList>
#include <QtCore/QPointer>

#include <QtNetwork/QNetworkReply>

class QTcpServer;
class QNetworkAccessManager;

// Uygulamanin C++ yardimcisi (QML'de "music"):
//  - Yerel aktarici: oynaticiya 127.0.0.1 adresi verir, istegi (Range dahil, yonlendirmeleri
//    izleyerek) uzak MP3'e ya da telefondaki dosyaya iletir. E6'nin oynaticisi yerel adreste
//    en kararli calisiyor (E6Tube deneyimi).
//  - Indirme kuyrugu: MP3'leri E:/Muzik altina kaydeder.
//  - Gunluk (son 30 satir), pano.
class Music : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString musicDir READ musicDir CONSTANT)
    Q_PROPERTY(bool downloading READ downloading NOTIFY queueChanged)
    Q_PROPERTY(int queueCount READ queueCount NOTIFY queueChanged)
    Q_PROPERTY(QString currentKey READ currentKey NOTIFY queueChanged)
public:
    explicit Music(QObject *parent = 0);

    QString musicDir() const { return m_dir; }
    bool downloading() const { return m_reply != 0; }
    int queueCount() const { return m_jobs.size() + (m_reply ? 1 : 0); }
    QString currentKey() const { return m_cur.key; }

    // Oynatici icin adres: uzak URL ya da yerel dosya yolu -> http://127.0.0.1:port/s/N.mp3
    Q_INVOKABLE QString streamUrl(const QString &source);
    Q_INVOKABLE QString fileUrl(const QString &path) const;

    // Indirme: ayni anahtar zaten kuyruktaysa yok sayilir
    Q_INVOKABLE void download(const QString &key, const QString &url, const QString &fileName);
    Q_INVOKABLE void cancel(const QString &key);
    Q_INVOKABLE void cancelAll();
    Q_INVOKABLE bool isQueued(const QString &key) const;
    Q_INVOKABLE bool fileExists(const QString &path) const;
    Q_INVOKABLE bool removeFile(const QString &path);
    Q_INVOKABLE QString sizeText(double bytes) const;
    Q_INVOKABLE double fileSize(const QString &path) const;

    Q_INVOKABLE void log(const QString &line);
    Q_INVOKABLE QString logText() const;
    Q_INVOKABLE void clearLog();
    Q_INVOKABLE void copyText(const QString &text) const;

    // RelayConn icin
    QString sourceFor(const QString &id) const { return m_sources.value(id); }
    QNetworkAccessManager *nam() const { return m_nam; }
    static QByteArray userAgent();

signals:
    void queueChanged();
    void progress(const QString &key, double received, double total);
    void finished(const QString &key, bool ok, const QString &path, const QString &message);

private slots:
    void onNewConnection();
    void onReadyRead();
    void onProgress(qint64 received, qint64 total);
    void onFinished();

private:
    struct Job { QString key, url, path; };
    void startNext();
    void request(const QUrl &url);

    QString m_dir;
    QTcpServer *m_server;
    QHash<QString, QString> m_sources;
    QStringList m_order;
    int m_seq;

    QNetworkAccessManager *m_nam;
    QList<Job> m_jobs;
    Job m_cur;
    QPointer<QNetworkReply> m_reply;
    QFile m_file;
    int m_redirects;
    bool m_cancelled;

    QStringList m_log;
    bool m_logLoaded;
};

#endif
