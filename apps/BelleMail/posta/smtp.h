// SMTP gonderimi: 465 (dogrudan TLS) ya da 587 (STARTTLS), AUTH PLAIN/LOGIN, duz metin UTF-8 posta.
#ifndef POSTA_SMTP_H
#define POSTA_SMTP_H

#include <QtCore/QObject>
#include <QtCore/QStringList>
#include <QtCore/QTimer>

class QSslSocket;

class Smtp : public QObject
{
    Q_OBJECT
public:
    struct Posta {
        QString kimdenAd, kimden, konu, metin, yanitlanan;
        QStringList kime, bilgi;
    };
    explicit Smtp(QObject *parent = 0);
    void gonder(const QString &sunucu, int port, const QString &kullanici, const QString &parola, const Posta &p);
    bool mesgul() const { return m_s != 0; }
    static QByteArray iletiOlustur(const Posta &p, QByteArray *mesajKimligi = 0);

signals:
    void bitti(bool ok, const QString &mesaj);

private slots:
    void baglandi();
    void sifreli();
    void okunabilir();
    void hata();
    void zamanAsimi();

private:
    enum Adim { Selam, Ehlo, StartTls, Ehlo2, Auth, AuthKul, AuthPar, MailFrom, RcptTo, Data, Govde, Quit };
    void yaz(const QByteArray &s);
    void ilerle(int kod, const QByteArray &metin);
    void bitir(bool ok, const QString &m);

    QSslSocket *m_s;
    QByteArray m_tampon, m_ileti, m_cokSatir;
    QString m_kullanici, m_parola;
    QStringList m_alicilar;
    QString m_kimden;
    int m_adim, m_alici, m_port;
    bool m_plainVar, m_loginVar, m_tlsVar;
    QTimer m_zaman;
};

#endif
