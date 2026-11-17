#ifndef GUNLUK_H
#define GUNLUK_H

// Belle Maps gunlugu: QML uyarilari / console.log / bellek izleri E:/BelleMaps/gunluk.txt'ye yazilir.
//  - Mesaj siniri yok (eskiden 300 mesajdan sonra duruyordu); dosya 256 KB'yi asinca gunluk_eski.txt'ye devredilir
//  - Tekrarlayan gurultu (sertifika / DNS uyarilari) ozetlenir
//  - Cokme algilama: acilista "acik.isaret" yazilir, duzgun cikista silinir. Sonraki acilista isaret duruyorsa
//    onceki calisma coktu demektir -> rapor sunucuya (/api/report) gonderilir; parola yoksa kartta bekler.
#include <QtCore/QObject>
#include <QtCore/QTimer>
#include <QtCore/QString>

class QNetworkAccessManager;

class Gunluk : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool raporBekliyor READ raporBekliyor NOTIFY raporDegisti)
public:
    explicit Gunluk(const QString &klasor, const QString &surum, QObject *parent = 0);
    static void kur(const QString &klasor);          // mesaj yakalayicisini kurar (QApplication'dan hemen sonra)

    bool raporBekliyor() const;
    Q_INVOKABLE bool oncekiCokme() const { return m_cokme; }
    Q_INVOKABLE QString oncekiBaslangic() const { return m_oncekiBas; }
    // Raporu gonderir (not: kullanicinin notu). Sonuc: raporSonucu(ok, mesaj)
    Q_INVOKABLE void gonder(const QString &sunucu, const QString &anahtar, const QString &not_);
    Q_INVOKABLE QString klasor() const { return m_klasor; }

signals:
    void raporDegisti();
    void raporSonucu(bool ok, const QString &mesaj);

public slots:
    void temizCikis();

private slots:
    void bellekYaz();
    void gonderildi();

private:
    QString metin() const;
    QString m_klasor, m_surum, m_oncekiBas;
    bool m_cokme;
    QTimer m_bellek;
    QNetworkAccessManager *m_nam;
};

#endif
