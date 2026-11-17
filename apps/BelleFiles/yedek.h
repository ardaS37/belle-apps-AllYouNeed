#ifndef YEDEK_H
#define YEDEK_H

// Belle Files - Yedekler: tum yedekler hafiza kartinda E:/BelleYedek altinda toplanir (ROM yuklenince C: silinir).
//   Rehber/       rehber_yyyyMMdd_HHmm.vcf   (vCard 3.0; bos alanlar temiz, FN var)
//   SMS/          sms_yyyyMMdd_HHmm.xml      (Android "SMS Backup & Restore" bicimi; oraya da aktarilabilir)
//   Uygulamalar/  <Uygulama>/...             (uygulamalarin kendileri yazar: kutuphane/ayna)
//   Telefon ayarlari: ucuncu parti uygulamalara kapali (C:/Private). Belle'nin kendi yedegi E:/Backup'a yazar;
//   bu sinif onu yalnizca bulur ve gosterir (Drive'a yuklenecekler arasina katilir).

#include <QtCore/QObject>
#include <QtCore/QVariantList>
#include <QtCore/QVariantMap>
#include <QtCore/QStringList>

class Yedek : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString kok READ kok CONSTANT)
    Q_PROPERTY(bool calisiyor READ calisiyor NOTIFY degisti)
    Q_PROPERTY(QString durum READ durum NOTIFY degisti)

public:
    explicit Yedek(QObject *parent = 0);

    QString kok() const { return m_kok; }
    bool calisiyor() const { return m_calisiyor; }
    QString durum() const { return m_durum; }

    Q_INVOKABLE QVariantMap ozet();                         // ekran ozeti
    Q_INVOKABLE QVariantList dosyalar(const QString &tur);  // "Rehber" | "SMS": yedek dosyalari (yeniden eskiye)
    Q_INVOKABLE QVariantList uygulamalar();                 // Uygulamalar/<ad>/bilgi.txt
    Q_INVOKABLE int rehberKisi();                           // rehberdeki kisi sayisi (-1: okunamadi)
    Q_INVOKABLE int smsSayisi();                            // telefondaki SMS sayisi (-1: okunamadi)

    Q_INVOKABLE void rehberYedekle();
    Q_INVOKABLE void rehberGeriYukle(const QString &dosya);
    Q_INVOKABLE void smsYedekle();
    Q_INVOKABLE void smsGeriYukle(const QString &dosya);
    Q_INVOKABLE void tamYedek();                            // rehber + SMS (uygulama aynalari zaten guncel)
    Q_INVOKABLE bool sil(const QString &dosya);
    Q_INVOKABLE QString onizle(const QString &dosya, int enFazla);
    Q_INVOKABLE QString gunluk() const;
    void log(const QString &s);

signals:
    void degisti();
    void bitti(bool ok, const QString &mesaj, const QString &tur);

private slots:
    void isle();

private:
    void durumYaz(const QString &s);
    bool rehberYedekleIs(QString *mesaj);
    bool rehberGeriYukleIs(const QString &dosya, QString *mesaj);
    bool smsYedekleIs(QString *mesaj);
    bool smsGeriYukleIs(const QString &dosya, QString *mesaj);
    QString m_kok;
    bool m_calisiyor;
    QString m_durum;
    QStringList m_kuyruk;          // "rehber", "sms", "rehberGeri:<dosya>", "smsGeri:<dosya>"
    QStringList m_sonuclar;
    bool m_hepsiOk;
};

#endif
