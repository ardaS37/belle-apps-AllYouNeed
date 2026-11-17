// BelleMail cekirdegi (sunucusuz): posta kutusuna telefondan dogrudan IMAP (TLS 993) ile baglanir,
// SMTP (465/587) ile gonderir. QML'e "mail" adiyla acilir.
//  istek(tur, p) -> numara; sonuc yanit(numara, ok, veri, hata) sinyaliyle gelir.
//   tur: "liste" {f, s, q} | "mesaj" {f, uid, okundu} | "islem" {f, uid, a} | "klasorler" {} | "gonder" {to, cc, subject, body, ref}
//  f: inbox | starred | sent | spam | trash | all | drafts | "k:<ham klasor adi>"
// Hesap ozel klasorde (hesap.ini; parola karistirilarak). Yeni posta denetimi: kontrolDakika'da bir.
#ifndef POSTA_POSTA_H
#define POSTA_POSTA_H

#include <QtCore/QObject>
#include <QtCore/QVariant>
#include <QtCore/QHash>
#include <QtCore/QTimer>
#include <QtCore/QStringList>

class Imap;
class Smtp;
class QNetworkSession;

class Posta : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool hesapVar READ hesapVar NOTIFY hesapDegisti)
    Q_PROPERTY(QString kullanici READ kullanici NOTIFY hesapDegisti)
    Q_PROPERTY(QString downloadDir READ downloadDir CONSTANT)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(int kontrolDakika READ kontrolDakika WRITE setKontrolDakika NOTIFY ayarDegisti)
    Q_PROPERTY(int okunmamis READ okunmamis NOTIFY okunmamisDegisti)
public:
    Posta(const QString &ozelKlasor, const QString &gunlukDosyasi, QObject *parent = 0);
    ~Posta();

    bool hesapVar() const { return !m_kul.isEmpty() && !m_parola.isEmpty(); }
    QString kullanici() const { return m_kul; }
    QString downloadDir() const;
    bool busy() const { return m_ekSuruyor; }
    int kontrolDakika() const { return m_kontrolDk; }
    void setKontrolDakika(int dk);
    int okunmamis() const { return m_okunmamis; }

    Q_INVOKABLE int istek(const QString &tur, const QVariantMap &p);
    // h: {imap, imapPort, smtp, smtpPort, user, pass, name, preset}. Giris denenir, basariliysa kaydedilir.
    Q_INVOKABLE void hesapDene(const QVariantMap &h);
    Q_INVOKABLE QVariantMap hesap() const;
    Q_INVOKABLE void hesapSil();
    Q_INVOKABLE bool downloadAttachment(const QString &folder, int uid, const QString &part, const QString &name);
    Q_INVOKABLE void cancel();
    Q_INVOKABLE bool openFile(const QString &path);
    Q_INVOKABLE QString pano() const;
    Q_INVOKABLE void girisiTamamla() const;
    Q_INVOKABLE void simdiKontrol();
    Q_INVOKABLE QString gunluk() const;

signals:
    void yanit(int id, bool ok, const QVariant &veri, const QString &hata);
    void hesapSonuc(bool ok, const QString &mesaj);
    void yeniPosta(int adet, const QString &kimden, const QString &konu);
    void progress(double done, double total);
    void downloadFinished(bool ok, const QString &message, const QString &path);
    void busyChanged();
    void hesapDegisti();
    void ayarDegisti();
    void okunmamisDegisti();

private slots:
    void imapBitti(int no, bool ok, const QString &durum, const QVariantList &y);
    void imapIlerleme(qint64 alinan, qint64 toplam);
    void imapKoptu(const QString &neden);
    void denemeBitti(int no, bool ok, const QString &durum, const QVariantList &y);
    void denemeGirisHatasi(const QString &m);
    void smtpBitti(bool ok, const QString &mesaj);
    void kontrolZamani();
    void agAcildi();

private:
    enum IsTuru { IsListe, IsMesaj, IsIslem, IsKlasorler, IsEk, IsKontrol };
    struct Is {
        Is() : id(0), tur(IsListe), adim(0), sonraki(0), sanalYildiz(false), toplam(0), daha(false), uid(0), okunmamisti(false) {}
        int id, tur, adim, sonraki;
        QVariantMap p;
        QByteArray kutu;
        bool sanalYildiz;
        QList<qint64> uidler;
        QVariantList ogeler;
        QVariantMap veri;
        QList<QPair<QByteArray, QList<qint64> > > onizleme;   // parca -> uid'ler
        int toplam;
        bool daha;
        qint64 uid;
        bool okunmamisti;
    };
    struct Klasor { QByteArray ham; QString ad; QString ozel; bool secilemez; };

    void kayit(const QString &s) const;
    void hesapOku();
    void hesapYaz(const QVariantMap &h);
    void kuyrugaEkle(const Is &is);
    void siradaki();
    void adim(const QVariantList &y);
    void komut(const QByteArray &k);
    void bitir(bool ok, const QVariant &veri, const QString &hata = QString());
    bool sec(const QByteArray &kutu, int sonraki, bool zorla);
    QByteArray kutuYolu(const QString &f, bool *sanal, QString *hata) const;
    void klasorleriAl(const QVariantList &y);
    QVariantList klasorListesi() const;
    QVariantMap ozet(const QVariantMap &fetch, bool giden) const;
    void tasi(const QByteArray &hedef);
    void sil();
    QVariantMap zarf(const QVariant &env) const;
    static void yapiGez(const QVariant &v, const QString &onek, QVariantList &parcalar);
    static QVariantMap fetchHaritasi(const QVariant &yanit, qint64 *seq);
    static QVariant govdeBul(const QVariantMap &m, const QByteArray &parca);
    QString hataMetni(const QString &sunucu) const;

    QString m_ozel, m_gunluk;
    QString m_imapSunucu, m_smtpSunucu, m_kul, m_parola, m_ad, m_hazirAyar;
    int m_imapPort, m_smtpPort;
    Imap *m_imap;
    Imap *m_deneme;
    QVariantMap m_denemeHesap;
    Smtp *m_smtp;
    int m_smtpIs;
    QNetworkSession *m_ag;
    bool m_agHazir;
    QList<Is> m_kuyruk;
    Is m_is;
    bool m_isVar;
    int m_beklenen;
    int m_sayac;
    QByteArray m_secili;
    qint64 m_exists, m_uidGecerlilik;
    bool m_klasorHazir;
    QList<Klasor> m_klasorler;
    QHash<QString, QByteArray> m_ozelKutu;              // sent/trash/spam/all/drafts/starred -> ham ad
    QHash<QString, QString> m_onizlemeOnbellek;         // kutu:gecerlilik:uid -> metin
    QHash<QString, QVariantMap> m_parcaBilgi;           // uid:parca -> {kodlama, charset}
    bool m_ekSuruyor;
    QString m_ekAd;
    int m_kontrolDk;
    QTimer m_kontrol;
    qint64 m_sonUidNext;
    int m_okunmamis;
};

#endif
