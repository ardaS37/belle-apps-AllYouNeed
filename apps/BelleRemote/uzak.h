#ifndef UZAK_H
#define UZAK_H

#include <QtCore/QObject>
#include <QtCore/QStringList>
#include <QtCore/QVariantList>
#include <QtCore/QTimer>
#include <QtCore/QTime>
#include <QtCore/QFile>
#include <QtGui/QImage>
#include <QtNetwork/QTcpSocket>
#include <QtNetwork/QNetworkSession>
#include <QtNetwork/QNetworkConfigurationManager>
#include <QtDeclarative/QDeclarativeImageProvider>

class QNetworkAccessManager;
class QNetworkReply;

// BelleRemote (Nokia): kendi bilgisayarını telefondan kullanmak için istemci. Protokol: PROTOKOL.md
// Yollar: LAN (doğrudan PC_IP:5680) ya da sunucu aktarıcısı (/uzak/baglan, HTTP Upgrade: e6uzak).
// Nokia için "paket" kipi: girdiler biriktirilir, son girdiden 1 sn sonra toplu gönderilir; PC uygular ve kare döner.
// Koordinatlar onbinde bir (0..10000), seçili kaynağın tamamına göre.
class Uzak : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int durum READ durum NOTIFY durumChanged)              // 0 kapalı, 1 bağlanıyor, 2 bağlı
    Q_PROPERTY(QString durumMetni READ durumMetni NOTIFY durumChanged)
    Q_PROPERTY(QString pcAdi READ pcAdi NOTIFY durumChanged)
    Q_PROPERTY(QString yol READ yol NOTIFY durumChanged)              // "LAN" | "Sunucu"
    Q_PROPERTY(int kareNo READ kareNo NOTIFY kareGeldi)
    Q_PROPERTY(int kareG READ kareG NOTIFY kareGeldi)
    Q_PROPERTY(int kareY READ kareY NOTIFY kareGeldi)
    Q_PROPERTY(int imlecX READ imlecX NOTIFY imlecChanged)            // telefondaki sanal imleç
    Q_PROPERTY(int imlecY READ imlecY NOTIFY imlecChanged)
    Q_PROPERTY(int pcImlecX READ pcImlecX NOTIFY kareGeldi)           // PC'deki gerçek imleç
    Q_PROPERTY(int pcImlecY READ pcImlecY NOTIFY kareGeldi)
    Q_PROPERTY(int zx1 READ zx1 NOTIFY zoomChanged)
    Q_PROPERTY(int zy1 READ zy1 NOTIFY zoomChanged)
    Q_PROPERTY(int zx2 READ zx2 NOTIFY zoomChanged)
    Q_PROPERTY(int zy2 READ zy2 NOTIFY zoomChanged)
    Q_PROPERTY(double zoom READ zoom NOTIFY zoomChanged)
    Q_PROPERTY(bool genel READ genel NOTIFY zoomChanged)      // genel bakis acik: tum ekran kucuk geliyor
    Q_PROPERTY(int bekleyen READ bekleyen NOTIFY bekleyenChanged)     // gönderilmeyi bekleyen girdi sayısı
    Q_PROPERTY(bool gonderiliyor READ gonderiliyor NOTIFY bekleyenChanged)
    Q_PROPERTY(bool yaziAlani READ yaziAlani NOTIFY yaziAlaniChanged)
    Q_PROPERTY(QString kip READ kip NOTIFY ayarChanged)
    Q_PROPERTY(int fps READ fps NOTIFY ayarChanged)
    Q_PROPERTY(int kalite READ kalite NOTIFY ayarChanged)
    Q_PROPERTY(int genislik READ genislik NOTIFY ayarChanged)
    Q_PROPERTY(int ping READ ping NOTIFY istatistik)
    Q_PROPERTY(double kbps READ kbps NOTIFY istatistik)
    Q_PROPERTY(QString kaynakAdi READ kaynakAdi NOTIFY durumChanged)
    Q_PROPERTY(QString sunucu READ sunucu NOTIFY ayarChanged)
    Q_PROPERTY(bool parolaVar READ parolaVar NOTIFY ayarChanged)
    Q_PROPERTY(QString telefonAdi READ telefonAdi NOTIFY ayarChanged)
    Q_PROPERTY(bool otoYazi READ otoYazi NOTIFY ayarChanged)
    // Sunucu tarayicisi (hedef=tarayici)
    Q_PROPERTY(bool tarayici READ tarayici NOTIFY durumChanged)
    Q_PROPERTY(QString adres READ adres NOTIFY adresChanged)
    Q_PROPERTY(QString baslik READ baslik NOTIFY adresChanged)
    Q_PROPERTY(bool geriVar READ geriVar NOTIFY adresChanged)
    Q_PROPERTY(bool ileriVar READ ileriVar NOTIFY adresChanged)
    Q_PROPERTY(bool yukleniyor READ yukleniyor NOTIFY adresChanged)
    Q_PROPERTY(int indirmeYuzde READ indirmeYuzde NOTIFY indirmeChanged)   // -1: indirme yok
    Q_PROPERTY(QString indirmeAd READ indirmeAd NOTIFY indirmeChanged)
    Q_PROPERTY(double gorunumOlcek READ gorunumOlcek NOTIFY ayarChanged)   // tarayici penceresi = ekran alani x olcek

public:
    explicit Uzak(QObject *parent = 0);
    ~Uzak();

    int durum() const { return m_durum; }
    QString durumMetni() const { return m_durumMetni; }
    QString pcAdi() const { return m_pcAdi; }
    QString yol() const { return m_yol; }
    int kareNo() const { return m_kareNo; }
    int kareG() const { return m_kare.width(); }
    int kareY() const { return m_kare.height(); }
    int imlecX() const { return m_ix; }
    int imlecY() const { return m_iy; }
    int pcImlecX() const { return m_pcx; }
    int pcImlecY() const { return m_pcy; }
    int zx1() const { return m_z[0]; }
    int zy1() const { return m_z[1]; }
    int zx2() const { return m_z[2]; }
    int zy2() const { return m_z[3]; }
    double zoom() const { return m_zoom; }
    bool genel() const { return m_genel; }
    int bekleyen() const { return m_bekleyen.size(); }
    bool gonderiliyor() const { return m_gonderiliyor; }
    bool yaziAlani() const { return m_yaziAlani; }
    QString kip() const { return m_kip; }
    int fps() const { return m_fps; }
    int kalite() const { return m_kalite; }
    int genislik() const { return m_genislik; }
    int ping() const { return m_ping; }
    double kbps() const { return m_kbps; }
    QString kaynakAdi() const { return m_kaynakAdi; }
    QString sunucu() const { return m_sunucu; }
    bool parolaVar() const { return !m_anahtar.isEmpty(); }
    QString telefonAdi() const { return m_telAdi; }
    bool otoYazi() const { return m_otoYazi; }
    bool tarayici() const { return m_tarayici; }
    QString adres() const { return m_adres; }
    QString baslik() const { return m_baslik; }
    bool geriVar() const { return m_geri; }
    bool ileriVar() const { return m_ileri; }
    bool yukleniyor() const { return m_yuk; }
    int indirmeYuzde() const { return m_dlYuzde; }
    QString indirmeAd() const { return m_dlAd; }
    double gorunumOlcek() const { return m_gorunumOlcek; }
    Q_INVOKABLE void setAlan(int g, int y);                           // QML: goruntu alaninin boyutu
    Q_INVOKABLE void setGorunumOlcek(double o);                       // 1 mobil, 1.25 normal, 1.6 genis

    // ---- Sunucu tarayicisi ----
    Q_INVOKABLE void baglanTarayici();
    Q_INVOKABLE void git(const QString &adresYaDaArama);
    Q_INVOKABLE void tarayiciKomut(const QString &k);                 // geri | ileri | yenile | dur | ana
    Q_INVOKABLE void indirmeIslem(const QString &id, const QString &islem);   // drive | sil
    Q_INVOKABLE void telefonaIndir(const QString &id, const QString &ad);
    Q_INVOKABLE void indirmeIptal();
    // Sik kullanilanlar (tarayici): [{adres, baslik}]
    Q_INVOKABLE QVariantList favoriler() const;
    Q_INVOKABLE bool favoriEkle(const QString &adres, const QString &baslik);
    Q_INVOKABLE void favoriSil(int i);
    QImage kare() const { return m_kare; }
    bool eventFilter(QObject *o, QEvent *e);                          // uygulama arka plana geçince kare akışını durdur

    // ---- Bağlantı ----
    Q_INVOKABLE void baglanLan(const QString &adres);                // "192.168.1.20:5680"
    Q_INVOKABLE void baglanSunucu(const QString &pcAdi);
    Q_INVOKABLE void baglanProfil(int i);                            // önce LAN dener, olmazsa sunucu
    Q_INVOKABLE void baglanIkili(const QString &lan, const QString &ad);
    Q_INVOKABLE void kes();
    Q_INVOKABLE void pcListesiIste();                                 // sunucudaki çevrimiçi PC'ler -> pcListesi
    Q_INVOKABLE QVariantList profiller() const;
    Q_INVOKABLE void profilSil(int i);
    Q_INVOKABLE QString telefonIp() const;
    Q_INVOKABLE QString acilacakAdres();                             // Belle Browser'in biraktigi adres (okununca silinir)

    // ---- Oturum ----
    Q_INVOKABLE void pencereListesiIste();
    Q_INVOKABLE void kaynakSec(const QString &s);                    // "masaustu" | "ekran:1" | "pencere:3"
    Q_INVOKABLE void tasi(int dx, int dy);                            // görünüm onbinde biri cinsinden
    Q_INVOKABLE void imlecGorunumde(double vx, double vy);            // dokunma: görünümde 0..1
    Q_INVOKABLE void tikla(const QString &dugme);                     // "L" | "R" | "M" (imleçte)
    Q_INVOKABLE void tekerlek(int n);
    Q_INVOKABLE void yatay(int n);                                    // yatay kaydırma (+ sağa)
    Q_INVOKABLE void zoomDongu();                                     // 1x <-> 1,5x
    Q_INVOKABLE void kaydir(int dx, int dy);                          // yakınlaştırmada görünen bölgeyi kaydır
    Q_INVOKABLE void tus(const QString &kombo);
    Q_INVOKABLE void yaz(const QString &metin, bool enterBas);
    Q_INVOKABLE void yakinlas(int yon);                               // +1 / -1 / 0 (sıfırla)
    // Genel bakis (C tusu): tum ekran gecici olarak dusuk cozunurlukte gelir; dokunulan / suruklenen yere
    // yakinlastirma bolgesi isinlanir (bitir=true: bolge gonderilir, genel bakis kapanir)
    Q_INVOKABLE void genelAc();
    Q_INVOKABLE void genelSec(double vx, double vy, bool bitir);
    Q_INVOKABLE void genelKapat();
    Q_INVOKABLE void yenile();                                        // hemen kare
    Q_INVOKABLE void simdiGonder();                                   // bekleyen paketi beklemeden gönder
    Q_INVOKABLE void arkaPlan(bool arka);                             // arka planda kare akışını durdur
    Q_INVOKABLE void arkaPlanaAl();

    // ---- Ayarlar ----
    Q_INVOKABLE void setSunucu(const QString &s);
    Q_INVOKABLE void setAnahtar(const QString &k);
    Q_INVOKABLE void setTelefonAdi(const QString &s);
    Q_INVOKABLE void setKip(const QString &k);
    Q_INVOKABLE void setFps(int f);
    Q_INVOKABLE void setKalite(int q);
    Q_INVOKABLE void setGenislik(int w);
    Q_INVOKABLE void setOtoYazi(bool b);
    Q_INVOKABLE QString panoMetni() const;
    Q_INVOKABLE void logla(const QString &s) { log(s); }
    Q_INVOKABLE void raporGonder();
    Q_INVOKABLE QString gunlukMetni() const;

signals:
    void durumChanged();
    void kareGeldi();
    void imlecChanged();
    void zoomChanged();
    void bekleyenChanged();
    void yaziAlaniChanged();
    void ayarChanged();
    void istatistik();
    void pencereListesi(const QStringList &satirlar);
    void pcListesi(const QVariantList &pcler, const QString &hata);
    void mesaj(const QString &m);
    void adresChanged();
    void indirmeHazir(const QString &id, const QString &ad, double boyut);
    void indirmeChanged();
    void indirmeBitti(bool ok, const QString &mesaj);

private slots:
    void onBaglandi();
    void onVeri();
    void onHata(QAbstractSocket::SocketError);
    void onKapandi();
    void paketGonder();
    void onLanZamanAsimi();
    void onPcListesi();
    void onAgAcildi();
    void onIndirmeVeri();
    void onIndirmeIlerleme(qint64 r, qint64 t);
    void onIndirmeSon();
    void onAgHata(QNetworkSession::SessionError);
    void onRapor();
    void saniyelik();

private:
    void log(const QString &s);
    void ayarYukle();
    void ayarKaydet();
    void durumYap(int d, const QString &m);
    void baslat(const QString &host, int port, bool sunucuYolu, const QString &pc);
    void merhaba();
    void cerceve(char tur, const QByteArray &veri);
    void isle(char tur, const QByteArray &veri);
    void girdiEkle(const QString &satir);
    void zoomGonder();
    void imleciGorunumdeTut();
    void profilKaydet();
    void agHazirla();
    void isYap();
    bool ayniAg(const QString &lan) const;
    void lanBaslat(const QString &adres, const QString &yedekPc);
    void sunucuBaslat(const QString &pc);

    QNetworkConfigurationManager *m_agYon;
    QNetworkSession *m_ag;
    int m_isTur;                      // bekleyen bağlantı işi: 1 LAN, 2 sunucu, 3 önce LAN sonra sunucu, 4 kayıtlı PC
    QString m_isLan, m_isPc;
    bool m_profilSorgu;
    bool m_tarayici, m_geri, m_ileri, m_yuk;
    QString m_adres, m_baslik;
    QNetworkReply *m_dl;
    QFile *m_dlDosya;
    QString m_dlAd, m_dlYol;
    int m_dlYuzde;
    int m_alanG, m_alanY;
    double m_gorunumOlcek;
    QString gorunumMetni() const;

    QTcpSocket *m_sock;
    QNetworkAccessManager *m_nam;
    QByteArray m_buf;
    bool m_upgradeBekliyor;           // sunucu yolunda 101 yanıtı bekleniyor
    int m_durum;
    QString m_durumMetni, m_pcAdi, m_yol, m_hedefPc, m_host, m_kaynakAdi;
    int m_port;
    QString m_lanYedek;               // profil bağlantısında LAN olmazsa sunucuya geç
    QTimer m_lanSure;

    QImage m_kare;
    int m_kareNo;
    int m_ix, m_iy, m_pcx, m_pcy;
    int m_z[4];
    double m_zoom;
    bool m_genel;
    QStringList m_bekleyen;
    QTimer m_paket;                   // paket kipinde 1 sn bekleme
    bool m_gonderiliyor;
    bool m_yaziAlani;

    // ayarlar
    QString m_sunucu, m_anahtar, m_telAdi, m_kip;
    int m_fps, m_kalite, m_genislik;
    bool m_otoYazi, m_arka;
    QString m_ayarDosya, m_dataDir;

    // istatistik
    QTimer m_saniye;
    qint64 m_alinan, m_sonAlinan;
    double m_kbps;
    int m_ping;
    QTime m_pingSaat;
    QStringList m_log;
};

class EkranSaglayici : public QDeclarativeImageProvider
{
public:
    explicit EkranSaglayici(Uzak *u) : QDeclarativeImageProvider(QDeclarativeImageProvider::Image), m_u(u) {}
    QImage requestImage(const QString &, QSize *size, const QSize &)
    {
        const QImage img = m_u->kare();
        if (size) *size = img.size();
        return img;
    }
private:
    Uzak *m_u;
};

#endif
