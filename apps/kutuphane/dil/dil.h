#ifndef DIL_H
#define DIL_H

// Dil destegi (Turkce / English) - tum Belle uygulamalarinda ortak.
//
// Kaynak metinler Turkcedir. Ingilizce secildiginde uygulamanin ":/dil/en.txt" sozlugu yuklenir:
//   - QML:  qsTr("Ayarlar")                      -> "Settings"
//           ListElement { label: QT_TR_NOOP("Sohbetler") }  +  text: qsTr(label)
//           qsTr("%1 yeni mesaj").arg(n)
//   - C++:  Dil::t("Kaydedildi")                  (UTF-8 kaynak metin)
//
// Secim tum uygulamalarda ortaktir: C:/Data/E6/dil.ini  (dil=auto|tr|en). "auto": telefon dili Turkce ise
// Turkce, degilse Ingilizce. Degisiklik uygulama yeniden acilinca gecerli olur.
//
// Sozluk bicimi (UTF-8): her satir  Turkce<TAB>English . "\n" ve "\t" kacislari desteklenir, # ile baslayan
// satir yorumdur. Bulunamayan metin oldugu gibi (Turkce) gosterilir.
//
// main.cpp:
//   QApplication app(argc, argv);
//   Dil *dil = Dil::kur(&app);                      // QML yuklenmeden ONCE
//   view.rootContext()->setContextProperty("dil", dil);
// QML (ayarlar):  dil.secim ("auto"/"tr"/"en"), dil.kod ("tr"/"en"), dil.sec("en"), dil.yenidenBaslat

#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QHash>
#include <QtCore/QTranslator>

class QCoreApplication;

class SozlukCevirmen : public QTranslator
{
public:
    explicit SozlukCevirmen(QObject *parent = 0) : QTranslator(parent) {}
    bool yukle(const QString &dosya);
    QString bul(const QString &tr) const { return m_s.value(tr); }
    int boyut() const { return m_s.size(); }
    virtual QString translate(const char *context, const char *sourceText, const char *disambiguation = 0) const;
    virtual bool isEmpty() const { return m_s.isEmpty(); }
private:
    QHash<QString, QString> m_s;
};

class Dil : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString kod READ kod CONSTANT)                       // bu oturumda etkin dil: "tr" | "en"
    Q_PROPERTY(QString secim READ secim NOTIFY degisti)             // kayitli secim: "auto" | "tr" | "en"
    Q_PROPERTY(bool yenidenBaslat READ yenidenBaslat NOTIFY degisti) // secim etkin dilden farkli: yeniden ac
    Q_PROPERTY(bool ingilizce READ ingilizce CONSTANT)
public:
    static Dil *kur(QCoreApplication *app, const QString &sozluk = QString(":/dil/en.txt"));
    static Dil *tek() { return s_tek; }
    // C++ metinleri icin: UTF-8 Turkce kaynak -> etkin dildeki metin
    static QString t(const char *utf8);
    static QString t(const QString &tr);
    // Sunucuya giden isteklere: req.setRawHeader("X-Lang", Dil::kodu());  (sunucu hata mesajlarini bu dilde dondurur)
    static QByteArray kodu() { return s_tek ? s_tek->m_kod.toLatin1() : QByteArray("tr"); }

    QString kod() const { return m_kod; }
    QString secim() const { return m_secim; }
    bool yenidenBaslat() const;
    bool ingilizce() const { return m_kod == "en"; }

    Q_INVOKABLE void sec(const QString &secim);        // "auto" | "tr" | "en"
    Q_INVOKABLE QString ceviri(const QString &tr) const { return t(tr); }

signals:
    void degisti();

private:
    explicit Dil(QObject *parent = 0);
    static QString ayarDosyasi();
    static QString otomatikKod();
    static Dil *s_tek;
    QString m_kod, m_secim;
    SozlukCevirmen *m_cev;
};

#endif
