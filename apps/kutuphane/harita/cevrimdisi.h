#ifndef CEVRIMDISI_H
#define CEVRIMDISI_H

// Cevrimdisi harita: secilen alanin karolari (belirli yakinlik araliginda) karta dosya olarak indirilir
// (E:/BelleMaps/cevrimdisi/<sunucu>/<yol>). HaritaNam karo isterken once bu dosyalara bakar: varsa internete
// hic gidilmez; internet yokken de indirilen alan acilir. Onbellekten farki: silinmez, boyut sinirina girmez.

#include <QtCore/QObject>
#include <QtCore/QStringList>
#include <QtCore/QList>
#include <QtCore/QUrl>
#include <QtNetwork/QNetworkAccessManager>

class QNetworkReply;

class Cevrimdisi : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool calisiyor READ calisiyor NOTIFY durumDegisti)
    Q_PROPERTY(int toplam READ toplam NOTIFY durumDegisti)
    Q_PROPERTY(int biten READ biten NOTIFY ilerledi)
    Q_PROPERTY(int hatali READ hatali NOTIFY ilerledi)
public:
    explicit Cevrimdisi(QObject *parent = 0);
    bool calisiyor() const { return m_calisiyor; }
    int toplam() const { return m_toplam; }
    int biten() const { return m_biten; }
    int hatali() const { return m_hatali; }

    static QString kok();
    static QString dosyaYolu(const QUrl &u);      // karo adresinin karttaki yeri

    // Alan: (lat1,lng1) kuzeybati, (lat2,lng2) guneydogu; z1..z2 dahil
    Q_INVOKABLE int say(double lat1, double lng1, double lat2, double lng2, int z1, int z2) const;
    Q_INVOKABLE bool baslat(const QString &sablon, const QStringList &altlar, double lat1, double lng1, double lat2, double lng2, int z1, int z2);
    Q_INVOKABLE void iptal();
    Q_INVOKABLE QString boyutMetni() const;
    Q_INVOKABLE int dosyaSayisi() const;
    Q_INVOKABLE void hepsiniSil();

signals:
    void durumDegisti();
    void ilerledi();
    void bitti(bool ok, const QString &mesaj);

private slots:
    void sonraki();
    void indi();

private:
    struct Karo { int z, x, y; };
    QString adres(const Karo &k) const;
    QNetworkAccessManager m_nam;
    QList<Karo> m_kuyruk;
    QString m_sablon;
    QStringList m_altlar;
    bool m_calisiyor, m_iptal;
    int m_toplam, m_biten, m_hatali, m_aktif;
};

#endif
