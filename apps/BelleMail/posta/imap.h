// IMAP4rev1 baglantisi (TLS, port 993): giris, sirali komutlar, yanit ayristirma.
// Yanitlar agac olarak doner: atom/dize -> QByteArray, NIL -> gecersiz QVariant, (liste) -> QVariantList.
// Ayni anda tek komut yolda; digerleri kuyrukta bekler.
#ifndef POSTA_IMAP_H
#define POSTA_IMAP_H

#include <QtCore/QObject>
#include <QtCore/QStringList>
#include <QtCore/QVariant>
#include <QtCore/QTimer>

class QSslSocket;

class Imap : public QObject
{
    Q_OBJECT
public:
    explicit Imap(QObject *parent = 0);
    ~Imap();

    void ayarla(const QString &sunucu, int port, const QString &kullanici, const QString &parola);
    // hazir degilse baglanir; komut giristen sonra gider. Donen sayi bitti() sinyalinde gelir.
    int komut(const QByteArray &metin);
    void kapat();
    bool hazir() const { return m_durum == Hazir; }
    bool yetenek(const char *ad) const { return m_yetenek.contains(QByteArray(ad)); }

    // IMAP dizesi: "..." (gerekirse kacisli)
    static QByteArray dize(const QByteArray &s);
    // yardimcilar
    static QByteArray bayt(const QVariant &v) { return v.toByteArray(); }
    static QVariantList liste(const QVariant &v) { return v.toList(); }

signals:
    // yanitlar: komut suresince gelen etiketsiz yanitlar ("* ..." satirlarinin agaclari)
    void bitti(int no, bool ok, const QString &durum, const QVariantList &yanitlar);
    void girisHatasi(const QString &mesaj);
    void koptu(const QString &neden);
    void ilerleme(qint64 alinan, qint64 toplam);

private slots:
    void sifreliHazir();
    void okunabilir();
    void soketHatasi();
    void sslHatalari();
    void zamanAsimi();

private:
    enum Durum { Kapali, Baglaniyor, Giris, Yetenek, Hazir };
    void baglan();
    void gonderSiradaki();
    void yanitIsle(const QByteArray &y);
    void hepsiniBitir(const QString &neden);
    static QVariantList ayristir(const QByteArray &s, int bas);
    static QVariant deger(const QByteArray &s, int &i);

    QSslSocket *m_s;
    Durum m_durum;
    QString m_sunucu, m_kullanici, m_parola;
    int m_port;
    QByteArray m_tampon;
    QList<QPair<int, QByteArray> > m_kuyruk;
    int m_sayac;
    int m_yolda;            // yoldaki komutun numarasi (0: yok)
    QVariantList m_toplanan;
    QList<QByteArray> m_yetenek;
    QTimer m_zaman;
};

#endif
