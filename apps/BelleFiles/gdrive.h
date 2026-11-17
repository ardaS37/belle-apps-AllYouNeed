#ifndef GDRIVE_H
#define GDRIVE_H

// Belle Files — Google Drive'a telefondan DOGRUDAN baglanti (sunucusuz).
// - GAuth: OAuth 2.0 "masaustu uygulamasi" istemcisi + PKCE. Kullanici izin adresini (bir bilgisayarda ya da
//   telefonun tarayicisinda) acar, Google 127.0.0.1 adresine yonlendirir; o adres uygulamaya yapistirilir.
//   Client ID / Client secret ayarlardan girilir (koda gomulmez; GitHub'da paylasilabilir).
// - GKopru: telefonda 127.0.0.1 uzerinde kucuk bir HTTP sunucusu. Drive sekmesinin kullandigi sunucu uclarini
//   (/drive/api/list, /file, /text, /star, /trash, /mkdir, /folder, /exists, /status, /drive/dl, /drive/img)
//   Google Drive v3 API'siyle birebir taklit eder; boylece Drive ekrani iki modda da ayni calisir.

#include <QtCore/QObject>
#include <QtCore/QVariantMap>
#include <QtNetwork/QTcpServer>

class QNetworkAccessManager;
class QTcpSocket;

class GAuth : public QObject
{
    Q_OBJECT
public:
    static GAuth *ins();
    QString clientId() const;
    QString clientSecret() const;
    void setClient(const QString &id, const QString &secret);
    bool bagli() const;                       // yenileme anahtari var mi
    QString email() const;
    QString izinAdresi();                     // yeni PKCE ile izin adresi
    QString kodGir(const QString &yapistirilan);  // "" basarili, degilse hata metni
    void cikis();
    QString erisimAnahtari(QString *hata = 0);    // gerekirse yeniler (bekleyerek)
    QNetworkAccessManager *nam() const { return m_nam; }

    // Bekleyen (senkron) istek: durum kodu, govde
    int istek(const QByteArray &yontem, const QString &url, const QByteArray &govde, const QByteArray &tur,
              QByteArray *cevap, int zamanMs = 60000);
private:
    explicit GAuth(QObject *parent = 0);
    QString ayarDosya() const;
    QNetworkAccessManager *m_nam;
    QString m_verifier;
    QString m_access;
    qint64 m_bitis;
};

class GKopru : public QTcpServer
{
    Q_OBJECT
public:
    explicit GKopru(QObject *parent = 0);
    QString adres() const;                    // http://127.0.0.1:PORT
protected:
    void incomingConnection(int handle);
private slots:
    void onOku();
private:
    void isle(QTcpSocket *s, const QByteArray &yontem, const QString &yol, const QVariantMap &sorgu);
    void yanit(QTcpSocket *s, int kod, const QByteArray &tur, const QByteArray &govde);
    void jsonHata(QTcpSocket *s, int kod, const QString &mesaj, bool kurulum = false);
    void indir(QTcpSocket *s, const QString &id);
    void resim(QTcpSocket *s, const QString &id, int w);
};

// Google'dan gelen indirmeyi yerel sokete akitir (/drive/dl): basliklar gelince HTTP basligini yazar
class QNetworkReply;
class GAktar : public QObject
{
    Q_OBJECT
public:
    GAktar(QNetworkReply *r, QTcpSocket *s, const QByteArray &ad, QObject *parent = 0);
    bool baslikYazildi;
public slots:
    void baslik();
    void veri();
private:
    QNetworkReply *m_r;
    QTcpSocket *m_s;
    QByteArray m_ad;
};

// JSON yardimcilari (Qt 4.7'de JSON yok: QtScript ile cozulur, elle yazilir)
QVariant jsonCoz(const QByteArray &b);
QByteArray jsonYaz(const QVariant &v);
QVariantMap gdriveOge(const QVariantMap &f);   // Google dosya kaydi -> Drive ekraninin oge bicimi

#endif

