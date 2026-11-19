#ifndef DEPO_H
#define DEPO_H

// Depolama yeri secimi (onbellek, indirmeler, buyuk veriler) - tum Belle uygulamalarinda ortak.
//
// Otomatik sira:
//   1. Uygulamanin KURULDUGU surucu (C: degilse)
//   2. Hafiza karti (cikarilabilir surucu)
//   3. Diger dahili suruculer (E: yigin bellek ...)
//   4. C: (telefon bellegi; kucuk oldugu icin en son)
// Ayarlardan bir surucu elle secilebilir. Secilen ya da sirasi gelen surucu SAGLAM degilse
// (yok, salt okunur, deneme dosyasi yazilamiyor ya da 2 MB'den az bos yer) siradakine gecilir.
// Ölmeye baslayan kartlar gorunur kalip yazma hatasi verdigi icin yalnizca "var mi" diye bakilmaz.
//
// Secim uygulama basina C:/Data/E6/depo.ini dosyasinda (anahtar = uygulama adi; deger auto|C|E|F...).
// Yollar uygulama acilisinda hesaplanir; degisiklik uygulama yeniden acilinca gecerli olur.
//
// main.cpp:
//   Depo *depo = Depo::kur("BelleMusic");           // yollari kullanan nesnelerden ONCE
//   view.rootContext()->setContextProperty("depo", depo);
// C++:   Depo::yol("Muzik")                          -> "F:/Muzik" | "E:/Muzik" | "C:/Data/Muzik"
//        Depo::yol("BelleGram", "C:/Data/BelleGram/Dosyalar")   (C: icin ayri yol)
// QML:   DepoSatiri { ... }  (ayarlar sayfasina; kutuphane/depo/DepoSatiri.qml)

#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QStringList>
#include <QtCore/QVariant>

class Depo : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString secim READ secim NOTIFY degisti)            // kayitli secim: "auto" | "C" | "E" | "F" ...
    Q_PROPERTY(QString etkin READ etkin CONSTANT)                   // bu oturumda kullanilan surucu harfi
    Q_PROPERTY(QString etkinAd READ etkinAd CONSTANT)               // "Hafıza kartı (F:)"
    Q_PROPERTY(bool yenidenBaslat READ yenidenBaslat NOTIFY degisti)
    Q_PROPERTY(QString hedefAd READ hedefAd NOTIFY degisti)         // yeniden acinca kullanilacak surucu
public:
    static Depo *kur(const QString &uygulama);
    static Depo *tek() { return s_tek; }

    // Etkin kok: "F:/" ya da "C:/Data/"
    static QString kok();
    static QString yol(const QString &alt, const QString &cYolu = QString());
    // Ayar yedegi (kutuphane/ayna) icin uygulama secimine bakmayan sabit sira: kart -> diger -> C
    static QString yedekKoku();
    static bool saglam(const QString &harf);
    static QString surucuAdi(const QString &harf);

    QString secim() const { return m_secim; }
    QString etkin() const { return m_etkin; }
    QString etkinAd() const { return surucuAdi(m_etkin); }
    bool yenidenBaslat() const;
    QString hedefAd() const { return surucuAdi(hesapla()); }

    // [{harf, ad, bos, saglam}] - ayarlar listesi icin
    Q_INVOKABLE QVariantList suruculer() const;
    Q_INVOKABLE void sec(const QString &secim);           // "auto" | "C" | "E" ...
    Q_INVOKABLE QString sonraki() const;                    // DepoSatiri'nda dokununca gecilecek secim
    Q_INVOKABLE QString yolu(const QString &alt) const { return yol(alt); }
    Q_INVOKABLE QString ad(const QString &secim) const;

signals:
    void degisti();

private:
    explicit Depo(const QString &uygulama, QObject *parent = 0);
    QString hesapla() const;
    static QStringList adaylar();          // varlik sirasiyla C disindaki yazilabilir suruculer
    static QString kurulumSurucusu();
    static QString ayarDosyasi();
    void taniYaz() const;                  // C:/Data/E6/depo_tani.txt: suruculer ve secim (sorun giderme)
    static Depo *s_tek;
    QString m_uygulama, m_secim, m_etkin;
};

#endif
