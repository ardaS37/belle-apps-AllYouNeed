#ifndef AYNA_H
#define AYNA_H

// Ayar aynasi: uygulamanin kendi ozel klasorunu (C:/Private/<UID>: QML LocalStorage veritabanlari, QSettings
// dosyalari) ve verdigi ek klasorleri (C:/Data/<Uygulama> gibi) hafiza kartina kopyalar:
//     E:/BelleYedek/Uygulamalar/<Ad>/ozel/...   ve   .../ek0/, ek1/ ...
// Telefon sifirlanir / ROM yuklenir / uygulama silinip yeniden kurulursa ozel klasor bos gelir; o zaman
// ayarlar karttaki aynadan otomatik geri yuklenir. Ozel klasore baska hicbir uygulama (CODA bile) erisemedigi
// icin bu isi uygulamanin kendisi yapmak zorunda.
// Ne zaman: acilista (QML yuklenmeden once), uygulama arka plana gecince (en sik 2 dakikada bir) ve kapanirken.
// Kullanim (main.cpp, QApplication olusturulduktan hemen sonra):
//     Ayna::baslat("WhatsE6", QStringList() << "C:/Data/WhatsE6");
// .pro:  include($$PWD/../kutuphane/ayna/ayna.pri)

#include <QtCore/QObject>
#include <QtCore/QStringList>
#include <QtCore/QDateTime>

class Ayna : public QObject
{
    Q_OBJECT
public:
    static void baslat(const QString &ad, const QStringList &ekKlasorler = QStringList());
    static QString kok();                       // E:/BelleYedek/Uygulamalar (E: yoksa C:/Data/BelleYedek/Uygulamalar)
    static QString ozelKlasor();                // bu uygulamanin C:/Private/<UID>
    bool eventFilter(QObject *o, QEvent *e);

public slots:
    void yedekle();

private:
    Ayna(const QString &ad, const QStringList &ek);
    void yaz(const QString &s);
    QString m_ad;
    QStringList m_ek;
    QDateTime m_son;
};

#endif
