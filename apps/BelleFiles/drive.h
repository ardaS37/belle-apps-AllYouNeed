#ifndef DRIVE_H
#define DRIVE_H

#include <QtCore/QObject>
#include <QtCore/QPointer>
#include <QtCore/QFile>
#include <QtCore/QHash>
#include <QtCore/QStringList>
#include <QtCore/QVariant>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkReply>
#include <QtDeclarative/QDeclarativeNetworkAccessManagerFactory>

// Belle Files'in Drive sekmesi. Iki mod:
//  - "sunucu": kendi sunucumuz (/drive/api, X-Api-Key) — eski Drive uygulamasiyla ayni
//  - "google": telefondan dogrudan Google Drive (gdrive.h: GAuth + yerel kopru 127.0.0.1)
// QML her iki modda da driveServer() adresine konusur.
QString driveServer();
QString driveKey();
QString driveMod();

// QML'in tum istekleri (XMLHttpRequest, Image) sunucuya giderken parola basligini ekler
class KeyedNam : public QNetworkAccessManager
{
public:
    explicit KeyedNam(QObject *parent = 0) : QNetworkAccessManager(parent) {}
protected:
    QNetworkReply *createRequest(Operation op, const QNetworkRequest &req, QIODevice *data);
};

class KeyedNamFactory : public QDeclarativeNetworkAccessManagerFactory
{
public:
    QNetworkAccessManager *create(QObject *parent) { return new KeyedNam(parent); }
};

class Drive : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString server READ server NOTIFY serverChanged)
    Q_PROPERTY(QString mod READ mod NOTIFY serverChanged)
    Q_PROPERTY(QString downloadDir READ downloadDir NOTIFY serverChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(bool hazir READ hazir NOTIFY serverChanged)          // secilen mod kullanima hazir mi
    Q_PROPERTY(bool isAktif READ isAktif NOTIFY isDurum)            // klasor yedekleme / not esitleme suruyor
public:
    explicit Drive(QObject *parent = 0);
    QString server() const { return driveServer(); }
    QString mod() const { return driveMod(); }
    QString downloadDir() const;
    bool busy() const { return !m_reply.isNull(); }
    bool hazir() const;
    bool isAktif() const { return m_isAktif; }

    // ---- Klasor yedekleme / esitleme ----
    // dir klasorunu Drive'da hedefYol ("Belle Files Yedek/Foto" gibi, Drive'im altinda) klasorune alt klasorleriyle yukler.
    // Ayni adli dosyalarin uzerine yazar (yeni surum). degisenler: daha once ayni haliyle yuklenenleri atlar.
    Q_INVOKABLE bool klasorYedekle(const QString &dir, const QString &hedefYol, bool degisenler);
    // Birden cok klasor/dosya: her biri hedefYol altina (dosyalar dogrudan, klasorler kendi adiyla)
    Q_INVOKABLE bool cokluYedekle(const QStringList &yollar, const QString &hedefYol, bool degisenler);
    // Ters yon: Drive'daki driveYol ("Nokia E6 Yedek/Backup") klasorunu alt klasorleriyle yerel klasore indirir
    // (ayni adli dosyalarin uzerine yazar, digerlerine dokunmaz). Ilerleme/sonuc: isIlerleme / isBitti.
    Q_INVOKABLE bool klasorIndir(const QString &driveYol, const QString &yerel);
    // Tek dosya: driveYol "Nokia E6 Yedek/Yedek.zip" -> yerelDosya (tam yol). Ilerleme/sonuc: isIlerleme / isBitti.
    Q_INVOKABLE bool dosyaIndir(const QString &driveYol, const QString &yerelDosya);
    Q_INVOKABLE void isIptal();
    Q_INVOKABLE void setDownloadDir(const QString &dir);              // "" varsayilan (kart varsa E:/Drive)

    Q_INVOKABLE QString pickFile();
    Q_INVOKABLE bool upload(const QString &path, const QString &folder);
    // Yedek: Drive'im altindaki klasorName klasorune; ayni adli dosya varsa uzerine yazar (yeni surum)
    Q_INVOKABLE bool uploadYedek(const QString &path, const QString &klasorAdi);
    Q_INVOKABLE QString localPath(const QString &name) const;
    Q_INVOKABLE bool download(const QString &id, const QString &name);
    Q_INVOKABLE void cancel();
    Q_INVOKABLE bool openFile(const QString &path);
    Q_INVOKABLE bool fileExists(const QString &path) const;
    Q_INVOKABLE qint64 fileSize(const QString &path) const;
    Q_INVOKABLE double fileTime(const QString &path) const;
    Q_INVOKABLE QString baseName(const QString &path) const;
    Q_INVOKABLE void openWeb();
    Q_INVOKABLE void forgetKey();
    Q_INVOKABLE bool changeServer();

    // ---- Baglanti ayarlari ----
    Q_INVOKABLE void setMod(const QString &m);                       // "sunucu" | "google"
    Q_INVOKABLE bool hasKey() const;
    Q_INVOKABLE int setKey(const QString &key);                      // 1 dogru, 0 hatali, -1 ulasilamadi
    Q_INVOKABLE QString googleClientId() const;
    Q_INVOKABLE bool googleHasSecret() const;
    Q_INVOKABLE void setGoogleClient(const QString &id, const QString &secret);
    Q_INVOKABLE bool googleBagli() const;
    Q_INVOKABLE QString googleEmail() const;
    Q_INVOKABLE QString googleIzinAdresi();                          // panoya da kopyalar
    Q_INVOKABLE QString googleKodGir(const QString &yapistirilan);    // "" basarili
    Q_INVOKABLE void googleCikis();
    Q_INVOKABLE void openUrl(const QString &url);

signals:
    void serverChanged();
    void busyChanged();
    void progress(double done, double total);
    void uploadFinished(bool ok, const QString &message, const QString &json);
    void downloadFinished(bool ok, const QString &message, const QString &path);
    void isDurum();
    void isIlerleme(int bitti, int toplam, const QString &ad);
    void isBitti(bool ok, int yuklenen, int atlanan, const QString &mesaj);

private slots:
    void onUploadProgress(qint64 done, qint64 total);
    void onDownloadProgress(qint64 done, qint64 total);
    void onReadyRead();
    void onFinished();
    void isSonraki();
    void indirHazirla();

private:
    bool uploadIc(const QString &path, const QString &folder, const QString &klasorAdi, bool replace);
    bool uploadGoogle(const QString &path, const QString &folder, const QString &klasorAdi, bool replace);
    QNetworkAccessManager m_nam;
    QPointer<QNetworkReply> m_reply;
    QFile *m_file;
    bool m_uploading;
    bool m_canceled;
    QString m_path;
    // google yuklemesi sonrasi: yeni dosyaysa ad + klasor ayari
    bool m_gYeni;
    QString m_gKlasor;
    // klasor isi
    struct IsDosya { QString yol; QString klasorYolu; QString anahtar; QString iz; };
    QString klasorBulYap(const QString &ust, const QString &ad, QString *hata);
    QString yolKlasoru(const QString &yol, QString *hata);
    void isTopla(const QString &dir, const QString &hedefYol, bool degisenler);
    void isSonu(bool ok, const QString &mesaj);
    void yukSonuc(bool ok, const QString &mesaj, const QString &json);
    bool cokluIc(const QStringList &yollar, const QString &hedefYol, bool degisenler, bool icerik);
    // klasor indirme (Drive -> telefon)
    QVariantList listeTum(const QString &klasorId, QString *hata);
    bool indirTopla(const QString &klasorId, const QString &yerel, int derinlik, QString *hata);
    bool indirIc(const QString &id, const QString &hedef);
    bool m_isIndir;
    QString m_indirKok, m_indirYerel, m_tekAd;
    bool m_isAktif, m_isIptal;
    QList<IsDosya> m_isListe;
    QHash<QString, QString> m_isKlasor;   // "Belle Files Yedek/Foto" -> Drive id
    int m_isToplam, m_isYuklenen, m_isAtlanan, m_isHata;
    QString m_isSonHata, m_isAnahtar, m_isIz;
};

#endif
