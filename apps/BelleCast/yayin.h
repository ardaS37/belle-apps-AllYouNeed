#ifndef YAYIN_H
#define YAYIN_H

// BelleCast cekirdegi: QML'e "yayin" adiyla acilir.
//  - Telefon ici aktarma sunucusu (127.0.0.1): internet radyosu ve podcast akislarini kendisi ceker,
//    oynaticiya (QtMultimediaKit Audio) sade "HTTP/1.0 200" olarak verir. Boylece:
//      * eski Shoutcast "ICY 200 OK" yanitlari, HTTPS (Qt TLS yamasi), yonlendirmeler, chunked
//        aktarim oynaticiya dert olmaz,
//      * ICY ara verileri (StreamTitle) ayiklanir: calan sarki adi baslikDegisti ile gelir.
//  - Indirme (podcast bolumleri), gunluk, kucuk dosya yardimcilari.

#include <QtCore/QObject>
#include <QtCore/QHash>
#include <QtCore/QPointer>
#include <QtCore/QStringList>
#include <QtCore/QVariantMap>
#include <QtCore/QFile>
#include <QtCore/QTime>
#include <QtCore/QTimer>
#include <QtCore/QUrl>
#include <QtNetwork/QTcpSocket>

class QTcpServer;
class QNetworkAccessManager;
class QNetworkReply;
class Yayin;

// Oynaticidan gelen tek baglanti + uzak yayina kendi HTTP istemcisi
class YayinBaglanti : public QObject
{
    Q_OBJECT
public:
    YayinBaglanti(QTcpSocket *oyn, Yayin *y);
    ~YayinBaglanti();

private slots:
    void oynaticiOku();
    void oynaticiKoptu();
    void uzakBaglandi();
    void uzakOku();
    void uzakKoptu();
    void uzakHata();
    void pompala();

private:
    void baglan(const QUrl &u);
    void basliklariIsle();
    void govdeIsle(const QByteArray &d);
    void sesYaz(const QByteArray &d);
    void bitir(const QByteArray &durum);

    QPointer<QTcpSocket> m_oyn;
    QPointer<QTcpSocket> m_uzak;
    Yayin *m_y;
    QByteArray m_istek;
    bool m_istekTamam;
    int m_id;
    QUrl m_url;
    int m_yonlendirme;
    // uzak yanit cozumleme
    QByteArray m_ham;             // baslik bitene kadar
    bool m_baslikTamam;
    bool m_chunked;
    qint64 m_chunkKalan;          // -1: boyut satiri bekleniyor
    QByteArray m_chunkTampon;
    int m_metaAralik;             // icy-metaint (0: yok)
    int m_metaSay;                // sonraki ara veriye kalan ses bayti
    int m_metaBoy;                // okunmakta olan ara veri boyutu (-1: boyut bayti bekleniyor)
    QByteArray m_meta;
    QByteArray m_tur;             // Content-Type
    bool m_oynBaslikGitti;
    qint64 m_aktarilan;
};

// HLS (m3u8) radyo: listeyi yeniler, parcalari sirayla ceker, tek kesintisiz AAC/MP3 akisi yapar.
// Parca bicimleri: ADTS .aac (basinda ID3 etiketi olabilir, atilir), MPEG-TS .ts (ses PES'i ayiklanir).
class HlsAkis : public QObject
{
    Q_OBJECT
public:
    HlsAkis(QTcpSocket *oyn, Yayin *y, int id, const QUrl &liste);
    ~HlsAkis();

private slots:
    void listeGeldi();
    void parcaGeldi();
    void listeYenile();
    void oynaticiKoptu();
    void devam();

private:
    void listeIste(const QUrl &u);
    void listeIsle(const QByteArray &m, const QUrl &taban);
    void sonrakiParca();
    void parcaYaz(QByteArray d);
    QByteArray tsSes(const QByteArray &ts);
    void yaz(const QByteArray &d);

    QPointer<QTcpSocket> m_oyn;
    Yayin *m_y;
    int m_id;
    QUrl m_liste;                 // medya listesi (varyant secildikten sonra)
    QPointer<QNetworkReply> m_listeIstek, m_parcaIstek;
    QList<QUrl> m_kuyruk;
    qint64 m_sonSira;             // son kuyruga alinan parca sirasi
    int m_hedefSure;              // EXT-X-TARGETDURATION
    bool m_bitti;                 // EXT-X-ENDLIST
    bool m_baslikGitti;
    QByteArray m_tur;
    QTimer m_yenile;
    int m_tsSesPid;
    int m_hata;
    qint64 m_aktarilan;
};

class Yayin : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool kayitta READ kayitta NOTIFY kayitDegisti)
    Q_PROPERTY(double kayitBoyut READ kayitBoyut NOTIFY kayitDegisti)
    Q_PROPERTY(int kayitSure READ kayitSure NOTIFY kayitDegisti)
    Q_PROPERTY(QString kayitYolu READ kayitYolu NOTIFY kayitDegisti)
    Q_PROPERTY(bool indiriyor READ indiriyor NOTIFY indirmeDegisti)
    Q_PROPERTY(QString indirilenAd READ indirilenAd NOTIFY indirmeDegisti)
public:
    explicit Yayin(const QString &veriKlasoru, QObject *parent = 0);

    // Uzak akis adresini aktarma adresine cevirir (http://127.0.0.1:port/y/<n>.<uzanti>)
    Q_INVOKABLE QString aktarma(const QString &url);
    Q_INVOKABLE QString yerelUrl(const QString &yol) const;     // file:/// adres
    Q_INVOKABLE QString sonBaslik(const QString &url) const { return m_baslik.value(url); }

    // ---- radyo kaydi: aktarmadan gecen ses (yeniden kodlamadan) dosyaya yazilir ----
    // Kayit yalnizca yayin aktarma uzerinden caliyorsa ilerler (QML bunu saglar).
    Q_INVOKABLE void kayitBaslat(const QString &url, const QString &istasyon);
    Q_INVOKABLE void kayitDurdur();
    Q_INVOKABLE QString kayitKlasoru() const { return m_kayitKlasor; }
    Q_INVOKABLE QVariantList kayitlar() const;                 // [{yol, ad, boyut, zaman}] yeniden eskiye
    bool kayitta() const { return !m_kayitUrl.isEmpty(); }
    double kayitBoyut() const { return double(m_kayitBoy); }
    int kayitSure() const { return m_kayitUrl.isEmpty() ? 0 : m_kayitSaat.elapsed() / 1000; }
    QString kayitYolu() const { return m_kayitYol; }
    void kayitYaz(int id, const QByteArray &d, const QByteArray &tur);   // aktarma baglantilarindan

    // ---- indirme (podcast bolumu) ----
    Q_INVOKABLE QString indirmeKlasoru() const { return m_indirKlasor; }
    Q_INVOKABLE bool indir(const QString &url, const QString &dosyaAdi);   // sirada biri varsa false
    Q_INVOKABLE void indirmeIptal();
    bool indiriyor() const { return m_indirme != 0; }
    QString indirilenAd() const { return m_indirAd; }

    // ---- dosya ----
    Q_INVOKABLE bool dosyaVar(const QString &yol) const;
    Q_INVOKABLE bool dosyaSil(const QString &yol);
    Q_INVOKABLE double dosyaBoyutu(const QString &yol) const;
    Q_INVOKABLE QString guvenliAd(const QString &ad) const;
    Q_INVOKABLE QString metinOku(const QString &yol) const;
    Q_INVOKABLE bool metinYaz(const QString &yol, const QString &metin);
    Q_INVOKABLE QString veriKlasoru() const { return m_veri; }

    // ---- beslemeler (RSS 2.0 / RDF / Atom, podcast) ----
    // Sonuc akisHazir(istekId, kanal, ogeler) ile gelir. kanal: {baslik, resim, yazar, link}
    // oge: {baslik, link, guid, zaman (ms), ozet (duz metin), ses (enclosure url), sesTur, boy, sure (sn), resim}
    Q_INVOKABLE void akisCek(const QString &istekId, const QString &url);
    // Haber sayfasinin okunur metni (paragraflar); sonuc metinHazir(url, metin, hata)
    Q_INVOKABLE void metinCek(const QString &url);
    // Genel JSON/metin istegi (radyo arama, podcast arama): sonuc metinGeldi(istekId, govde, hata)
    Q_INVOKABLE void getir(const QString &istekId, const QString &url);
    Q_INVOKABLE bool disaridaAc(const QString &url);

    // ---- zamanlayici (QML Timer ekran kapaliyken/arka planda durur; bu durmaz) ----
    Q_INVOKABLE void zamanla(const QString &ad, int ms);       // ms sonra zamanDoldu(ad); ayni ad yeniden kurar
    Q_INVOKABLE void zamanIptal(const QString &ad);
    Q_INVOKABLE int zamanKalan(const QString &ad) const;       // sn, yoksa -1

    // ---- gunluk ----
    Q_INVOKABLE void kayit(const QString &s);
    Q_INVOKABLE QString gunluk() const;

    // aktarma baglantilari icin
    QString urlIcin(int id) const { return m_idUrl.value(id); }
    void baslikBildir(int id, const QString &baslik);
    QNetworkAccessManager *nam() const { return m_nam; }

signals:
    void baslikDegisti(const QString &url, const QString &baslik);
    void indirmeDegisti();
    void indirmeIlerleme(double alinan, double toplam, int hizKBs);
    void indirmeBitti(bool ok, const QString &yol, const QString &mesaj);
    void zamanDoldu(const QString &ad);
    void kayitDegisti();
    void kayitBitti(const QString &yol, double boyut);
    void akisHazir(const QString &istekId, const QVariantMap &kanal, const QVariantList &ogeler, const QString &hata);
    void metinHazir(const QString &url, const QString &metin, const QString &hata);
    void metinGeldi(const QString &istekId, const QString &govde, const QString &hata);

private slots:
    void yeniBaglanti();
    void indirOku();
    void indirIlerle(qint64 a, qint64 t);
    void indirBitti();
    void zamanTik();
    void istekBitti();

private:
    void istekAt(const QUrl &u, const QString &tur, const QString &id, int yon);
    QVariantMap kanalCoz(const QByteArray &xml, QVariantList *ogeler, QString *hata) const;
    QString sayfaMetni(const QByteArray &html) const;
    QString m_kayitKlasor, m_kayitUrl, m_kayitAd, m_kayitYol;
    QFile m_kayit;
    qint64 m_kayitBoy;
    QTime m_kayitSaat;
    int m_kayitBildirim;            // son kayitDegisti saniyesi (saniyede bir bildir)
    QHash<QString, QTimer *> m_zaman;
    QHash<QString, QTime> m_zamanBas;
    void indirBaslat(const QUrl &u);
    QString m_veri, m_indirKlasor;
    QTcpServer *m_sunucu;
    QHash<int, QString> m_idUrl;
    QHash<QString, int> m_urlId;
    QHash<QString, QString> m_baslik;
    int m_sonId;
    QNetworkAccessManager *m_nam;
    QNetworkReply *m_indirme;
    QFile m_indirDosya;
    QString m_indirAd, m_indirYol;
    int m_indirYon;
    bool m_iptal;
    QTime m_indirSaat;
    QStringList m_gunluk;
};

#endif
