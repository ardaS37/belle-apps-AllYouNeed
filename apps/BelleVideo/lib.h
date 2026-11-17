#ifndef LIB_H
#define LIB_H

#include <QtCore/QObject>
#include <QtCore/QFile>
#include <QtCore/QHash>
#include <QtCore/QStringList>
#include <QtCore/QTime>
#include <QtCore/QTimer>
#include <QtCore/QVariantList>
#include <QtCore/QUrl>

class QNetworkAccessManager;
class QNetworkReply;
class QTcpServer;
class AudioExtract;

// QML'e "lib" adiyla acilir. Videolarin bulunmasi, klasor gezme, oynatici icin yerel sunucu,
// akis indirme, kaldigi yeri hatirlama ve gunluk burada.
//
// Neden yerel sunucu: E6'da yerel video penceresine dosya yolu ya da uzak adres verilince
// yalnizca ses geliyor, goruntu gelmiyor (BelleTube'da denendi). Ayni dosya telefonun kendi
// icindeki bir HTTP sunucusundan (127.0.0.1) verilince goruntu de geliyor.
class Lib : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
    Q_PROPERTY(int scanFound READ scanFound NOTIFY scanProgress)
    Q_PROPERTY(int libraryVersion READ libraryVersion NOTIFY libraryChanged)
    Q_PROPERTY(bool downloading READ downloading NOTIFY downloadingChanged)
    Q_PROPERTY(QString downloadName READ downloadName NOTIFY downloadingChanged)

public:
    explicit Lib(QObject *parent = 0);

    // ---- Video kitapligi (E: ve C:/Data taranir, sonuc onbellege yazilir) ----
    // [{ path, name, folder, size, time }] yeniden eskiye
    Q_INVOKABLE QVariantList videos() const { return m_videos; }
    Q_INVOKABLE void rescan();
    bool scanning() const { return m_scanning; }
    int scanFound() const { return m_found.size(); }
    int libraryVersion() const { return m_libVersion; }

    // ---- Klasor gezgini ----
    // path bos: kokler (E:, C:/Data ...). [{ name, path, dir, kind: "dir"|"video"|"audio", size, time }]
    Q_INVOKABLE QVariantList listDir(const QString &path) const;
    Q_INVOKABLE QString parentDir(const QString &path) const;
    Q_INVOKABLE QStringList mediaInDir(const QString &path) const;   // klasordeki oynatilabilir dosyalar
    Q_INVOKABLE bool isVideo(const QString &path) const;
    Q_INVOKABLE bool isAudio(const QString &path) const;
    Q_INVOKABLE bool isRemote(const QString &path) const;
    Q_INVOKABLE bool exists(const QString &path) const;
    Q_INVOKABLE bool removeFile(const QString &path);
    Q_INVOKABLE QString baseName(const QString &path) const;
    Q_INVOKABLE QString folderName(const QString &path) const;
    Q_INVOKABLE QString sizeText(qint64 bytes) const;
    Q_INVOKABLE qint64 fileSize(const QString &path) const;

    // ---- Oynatma adresleri ----
    // Yerel dosya -> http://127.0.0.1:port/f/<n>.<uzanti>; http(s) adresi -> yerel sunucu uzerinden aktarma;
    // rtsp vb. -> oldugu gibi. direct=true: sunucuyu atla (dosya adresi / uzak adres).
    Q_INVOKABLE QString videoUrl(const QString &pathOrUrl, bool direct);
    // Ses icin: yerel ses dosyasi -> file:///; video dosyasinin ses izi cikarildiysa o .m4a;
    // uzak adres -> oldugu gibi
    Q_INVOKABLE QString audioUrl(const QString &pathOrUrl) const;

    // ---- Videonun ses izi (kilit/arka plan icin ayri .m4a) ----
    Q_INVOKABLE bool canExtractAudio(const QString &path) const;   // mp4/m4v/3gp/mov
    Q_INVOKABLE bool audioReady(const QString &path) const;
    Q_INVOKABLE bool audioPreparing(const QString &path) const;
    Q_INVOKABLE void prepareAudio(const QString &path);          // gerekiyorsa arka planda cikarir
    Q_INVOKABLE int audioProgress() const;
    QString audioCachePath(const QString &path) const;

    // ---- Kaldigi yer ve son izlenenler ----
    Q_INVOKABLE int savedPosition(const QString &path) const;
    Q_INVOKABLE int savedDuration(const QString &path) const;
    Q_INVOKABLE void savePosition(const QString &path, int ms, int durationMs);
    Q_INVOKABLE void clearPosition(const QString &path);
    Q_INVOKABLE QStringList recent() const;            // en yeni once (en fazla 12)
    Q_INVOKABLE void forgetRecent(const QString &path);

    // ---- Indirme (akislar icin) ----
    Q_INVOKABLE QString downloadDir() const { return m_dlDir; }
    Q_INVOKABLE void download(const QString &url, const QString &name);
    Q_INVOKABLE void cancelDownload();
    Q_INVOKABLE QVariantList downloads() const;        // indirme klasorundeki dosyalar
    bool downloading() const { return m_reply != 0; }
    QString downloadName() const { return m_dlName; }

    // ---- Sistem ----
    Q_INVOKABLE void sendToBackground();
    Q_INVOKABLE bool openExternally(const QString &path) const;

    // ---- Gunluk (Ayarlar'da gorunur) ----
    Q_INVOKABLE void log(const QString &line);
    Q_INVOKABLE QString logText() const;
    Q_INVOKABLE void clearLog();

    // Yerel sunucu baglantilari icin
    QString pathForId(int id) const { return m_idPath.value(id); }
    QString urlForId(int id) const { return m_idUrl.value(id); }
    QNetworkAccessManager *nam() const { return m_nam; }
    static QByteArray mimeFor(const QString &path);

signals:
    void scanningChanged();
    void scanProgress();
    void libraryChanged();
    void downloadingChanged();
    void downloadProgress(qint64 received, qint64 total, int speedKBs);
    void downloadFinished(bool ok, const QString &path, const QString &message);
    void audioPrepared(const QString &path, bool ok, const QString &message);

private slots:
    void scanStep();
    void onNewConnection();
    void onDlMeta();
    void onDlReadyRead();
    void onDlProgress(qint64 received, qint64 total);
    void onDlFinished();
    void onAudioFinished(const QString &src, const QString &dst, bool ok, const QString &message);

private:
    void loadCache();
    void saveCache();
    QString settingsPath() const;
    QString keyFor(const QString &path) const;
    void startGet(const QUrl &url);
    QString uniquePath(const QString &name) const;
    static bool skipDir(const QString &name);

    QString m_dataDir;     // C:/Data/BelleVideo (ayarlar, onbellek, gunluk)
    QString m_dlDir;       // E:/Videos/BelleVideo
    QString m_audioDir;    // cikarilan ses izleri
    AudioExtract *m_extract;

    // tarama
    QVariantList m_videos;
    QVariantList m_found;
    QStringList m_queue;
    QHash<QString, int> m_depth;
    QTimer m_scanTimer;
    bool m_scanning;
    int m_libVersion;

    // yerel sunucu
    QTcpServer *m_server;
    QHash<int, QString> m_idPath;
    QHash<QString, int> m_pathId;
    QHash<int, QString> m_idUrl;
    QHash<QString, int> m_urlId;
    int m_nextId;

    // indirme
    QNetworkAccessManager *m_nam;
    QNetworkReply *m_reply;
    QFile m_file;
    QString m_dlName;
    QString m_dlPath;
    int m_redirects;
    bool m_cancelled;
    QTime m_dlStarted;

    QStringList m_log;
    bool m_logLoaded;
};

#endif
