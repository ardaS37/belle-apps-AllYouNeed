#ifndef KATMAN_H
#define KATMAN_H

// Belle Browser ag katmani.
// Mod:
//   "dogrudan"  : telefon siteye kendisi baglanir (eski TLS / sertifikalar yuzunden bazi HTTPS siteleri acilmaz)
//   "akilli"    : HTTPS istekleri sunucu katmanindan (/tb/g) gecer, HTTP dogrudan. Telefon sitenin kendisiyle
//                 konusuyor sanir (VekilYanit adresi asil adres gosterir; cerezler asil siteye kaydedilir).
//   "sikistir"  : tum istekler sunucudan; resimler kucultulur (veri tasarrufu, hizli acilis)
// Reklam alanlari (kucuk yerlesik liste) her modda engellenir; sunucu modunda sunucudaki buyuk liste de devrede.

#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkReply>
#include <QtNetwork/QNetworkCookieJar>
#include <QtNetwork/QNetworkRequest>
#include <QtDeclarative/QDeclarativeNetworkAccessManagerFactory>
#include <QtCore/QPointer>
#include <QtCore/QMutex>

struct KatmanAyar {
    QString sunucu;          // https://e6.msahincelen.xyz
    QString anahtar;         // sunucu parolasi
    QString mod;             // dogrudan | akilli | sikistir
    QString ua;              // mobil | masa | modern
    int resimW, resimQ;      // sikistir modunda resim genisligi / ffmpeg kalitesi (2 iyi .. 20 kotu)
    bool reklam;             // yerlesik reklam engeli
    bool sertifikaYoksay;    // dogrudan modda sertifika hatalarini yok say
    qint64 orijinal, giden;  // tasarruf istatistigi
    static KatmanAyar &al();
    void yukle();
    void kaydet() const;
    QString uaMetni() const;
};

class KaliciCerez : public QNetworkCookieJar
{
public:
    explicit KaliciCerez(QObject *parent = 0);
    ~KaliciCerez();
    bool setCookiesFromUrl(const QList<QNetworkCookie> &cookies, const QUrl &url);
    void kaydet();
    void temizle();
    static KaliciCerez *ortak();
private:
    QString dosya() const;
    int m_degisen;
};

class KatmanNam : public QNetworkAccessManager
{
    Q_OBJECT
public:
    explicit KatmanNam(QObject *parent = 0);
    static bool reklamMi(const QString &host);
protected:
    QNetworkReply *createRequest(Operation op, const QNetworkRequest &req, QIODevice *data);
private slots:
    void sslHata(QNetworkReply *r, const QList<QSslError> &e);
};

// Sunucudan gelen yaniti asil adresle sunar (WebKit icin seffaf vekil)
class VekilYanit : public QNetworkReply
{
    Q_OBJECT
public:
    VekilYanit(QNetworkReply *ic, const QNetworkRequest &asil, QNetworkAccessManager::Operation op, QNetworkAccessManager *nam);
    ~VekilYanit();
    void abort();
    qint64 bytesAvailable() const;
    bool isSequential() const { return true; }
protected:
    qint64 readData(char *data, qint64 maxlen);
private slots:
    void meta();
    void hazir();
    void bitti();
    void hata(QNetworkReply::NetworkError e);
    void inis(qint64 a, qint64 b) { emit downloadProgress(a, b); }
    void yukleme(qint64 a, qint64 b) { emit uploadProgress(a, b); }
private:
    QPointer<QNetworkReply> m_ic;
    QNetworkAccessManager *m_nam;
    bool m_meta;
};

// Engellenen istek: bos ve hemen biten yanit
class BosYanit : public QNetworkReply
{
    Q_OBJECT
public:
    BosYanit(const QNetworkRequest &req, QNetworkAccessManager::Operation op, QObject *parent);
    void abort() {}
    qint64 bytesAvailable() const { return 0; }
protected:
    qint64 readData(char *, qint64) { return -1; }
private slots:
    void bitir();
};

class KatmanNamFactory : public QDeclarativeNetworkAccessManagerFactory
{
public:
    QNetworkAccessManager *create(QObject *parent);
};

#endif
