#include "depo.h"
#include "dil.h"

#include <QtCore/QCoreApplication>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QHash>
#include <QtCore/QSettings>
#include <QtCore/QVariantMap>

#ifdef Q_OS_SYMBIAN
#include <e32std.h>
#include <f32file.h>
#endif

Depo *Depo::s_tek = 0;

static const qint64 KEnAzBos = 2 * 1024 * 1024;

#define L1(s) QString::fromLatin1(s)

// Surucu bilgisi (Symbian: RFs; masaustu: yalniz ev klasoru)
struct SurucuBilgi { bool var; bool cikarilabilir; bool saltOkunur; qint64 bos; };

static SurucuBilgi bilgi(const QString &harf)
{
    SurucuBilgi b = { false, false, false, 0 };
#ifdef Q_OS_SYMBIAN
    if (harf.size() != 1) return b;
    const int no = harf.at(0).toUpper().unicode() - 'A';
    if (no < 0 || no > 25) return b;
    RFs fs;
    if (fs.Connect() != KErrNone) return b;
    TDriveInfo di;
    if (fs.Drive(di, no) == KErrNone && di.iType != EMediaNotPresent && di.iType != EMediaRom && di.iType != EMediaRam
        && !(di.iDriveAtt & (KDriveAttRom | KDriveAttSubsted | KDriveAttRemote))) {
        b.var = true;
        // Gercek hafiza karti: cikarilabilir AMA "mantiksal cikarilabilir" (0x200) degil. E6'nin dahili E: bellegi
        // de cikarilabilir isaretlidir (suruAtt 0x321), harici kart F: 0x121 (depo_tani.txt ile goruldu, 19.11.2026).
        b.cikarilabilir = (di.iDriveAtt & KDriveAttRemovable) != 0 && (di.iDriveAtt & 0x200) == 0;
        b.saltOkunur = (di.iMediaAtt & (KMediaAttWriteProtected | KMediaAttLocked)) != 0;
        TVolumeInfo vi;
        if (fs.Volume(vi, no) == KErrNone) b.bos = vi.iFree; else b.var = false;
    }
    fs.Close();
#else
    Q_UNUSED(harf);
#endif
    return b;
}

static QString kokYolu(const QString &harf)
{
#ifdef Q_OS_SYMBIAN
    if (harf.compare(L1("C"), Qt::CaseInsensitive) == 0) return L1("C:/Data/");
    return harf.toUpper() + L1(":/");
#else
    Q_UNUSED(harf);
    return QDir::homePath() + L1("/");
#endif
}

// Deneme dosyasi yazip geri okur; sonuc oturum boyunca saklanir
bool Depo::saglam(const QString &harf)
{
    static QHash<QString, bool> onbellek;
    const QString h = harf.toUpper();
    if (onbellek.contains(h)) return onbellek.value(h);
    bool ok = false;
#ifdef Q_OS_SYMBIAN
    const SurucuBilgi b = bilgi(h);
    if (b.var && !b.saltOkunur && b.bos >= KEnAzBos) {
        const QString kok = kokYolu(h);
        QDir().mkpath(kok);
        const QString dosya = kok + L1(".belle_depo_deneme");
        const QByteArray veri("belle-depo-deneme-1234567890");
        QFile f(dosya);
        if (f.open(QIODevice::WriteOnly) && f.write(veri) == veri.size()) {
            f.close();
            if (f.open(QIODevice::ReadOnly)) { ok = f.readAll() == veri; f.close(); }
        }
        QFile::remove(dosya);
    }
#else
    ok = true;
#endif
    onbellek.insert(h, ok);
    return ok;
}

QString Depo::kurulumSurucusu()
{
#ifdef Q_OS_SYMBIAN
    const TFileName ad = RProcess().FileName();
    if (ad.Length() > 0) return QString(QChar(ad[0])).toUpper();
#endif
    return L1("C");
}

// C ve Z disindaki suruculer: once cikarilabilir (hafiza karti), sonra dahili (E: yigin bellek ...)
QStringList Depo::adaylar()
{
    QStringList kart, dahili;
#ifdef Q_OS_SYMBIAN
    for (char c = 'D'; c <= 'Y'; ++c) {
        const QString h = QString(QChar(c));
        const SurucuBilgi b = bilgi(h);
        if (!b.var) continue;
        (b.cikarilabilir ? kart : dahili) << h;
    }
#endif
    return kart + dahili;
}

QString Depo::surucuAdi(const QString &harf)
{
    const QString h = harf.toUpper();
#ifdef Q_OS_SYMBIAN
    if (h == L1("C")) return Dil::t("Sistem belleği (C:)");
    const SurucuBilgi b = bilgi(h);
    if (b.cikarilabilir) return Dil::t("Harici kart") + L1(" (") + h + L1(":)");
    return Dil::t("Dahili hafıza") + L1(" (") + h + L1(":)");
#else
    Q_UNUSED(h);
    return Dil::t("Ev klasörü");
#endif
}

QString Depo::ayarDosyasi() { return L1("C:/Data/E6/depo.ini"); }

Depo::Depo(const QString &uygulama, QObject *parent) : QObject(parent), m_uygulama(uygulama)
{
    QSettings s(ayarDosyasi(), QSettings::IniFormat);
    m_secim = s.value(m_uygulama, L1("auto")).toString();
    m_etkin = hesapla();
    taniYaz();
}

QString Depo::hesapla() const
{
#ifdef Q_OS_SYMBIAN
    QStringList sira;
    if (m_secim != L1("auto")) sira << m_secim.toUpper();
    const QString kur = kurulumSurucusu();
    if (kur != L1("C")) sira << kur;
    sira << adaylar();
    foreach (const QString &h, sira)
        if (h != L1("C") && h != L1("Z") && saglam(h)) return h;
    return L1("C");
#else
    return L1("C");
#endif
}

Depo *Depo::kur(const QString &uygulama)
{
    if (!s_tek) s_tek = new Depo(uygulama, qApp);
    return s_tek;
}

QString Depo::kok()
{
    if (s_tek) return kokYolu(s_tek->m_etkin);
    // kur() cagrilmamissa uygulama secimi olmadan otomatik sira
#ifdef Q_OS_SYMBIAN
    const QString kur = kurulumSurucusu();
    if (kur != L1("C") && saglam(kur)) return kokYolu(kur);
    foreach (const QString &h, adaylar()) if (saglam(h)) return kokYolu(h);
#endif
    return kokYolu(L1("C"));
}

QString Depo::yol(const QString &alt, const QString &cYolu)
{
    const QString k = kok();
#ifdef Q_OS_SYMBIAN
    if (!cYolu.isEmpty() && k == L1("C:/Data/")) return cYolu;
#else
    Q_UNUSED(cYolu);
#endif
    return k + alt;
}

QString Depo::yedekKoku()
{
#ifdef Q_OS_SYMBIAN
    // Daha once yedek alinmis saglam bir surucu varsa onu kullan (geri yukleme ayni yerden okusun)
    const QStringList aday = adaylar();
    foreach (const QString &h, aday)
        if (QDir(kokYolu(h) + L1("BelleYedek/Uygulamalar")).exists() && saglam(h)) return kokYolu(h) + L1("BelleYedek/Uygulamalar");
    foreach (const QString &h, aday)
        if (saglam(h)) return kokYolu(h) + L1("BelleYedek/Uygulamalar");
    return L1("C:/Data/BelleYedek/Uygulamalar");
#else
    return QDir::homePath() + L1("/BelleYedek/Uygulamalar");
#endif
}

bool Depo::yenidenBaslat() const
{
    if (m_secim == L1("auto")) return hesapla() != m_etkin;
    return m_secim.toUpper() != m_etkin;
}

QVariantList Depo::suruculer() const
{
    QVariantList l;
    QStringList harfler = adaylar();
    harfler << L1("C");
    foreach (const QString &h, harfler) {
        QVariantMap m;
        m.insert(L1("harf"), h);
        m.insert(L1("ad"), surucuAdi(h));
        m.insert(L1("saglam"), saglam(h));
        const SurucuBilgi b = bilgi(h);
        m.insert(L1("bosMB"), int(b.bos / (1024 * 1024)));
        l << m;
    }
    return l;
}

QString Depo::ad(const QString &secim) const
{
    if (secim == L1("auto")) return Dil::t("Otomatik") + L1(": ") + surucuAdi(hesapla());
    return surucuAdi(secim);
}

// Otomatik -> her saglam surucu -> Otomatik
QString Depo::sonraki() const
{
    QStringList dongu;
    dongu << L1("auto");
    foreach (const QString &h, adaylar()) if (saglam(h)) dongu << h;
    dongu << L1("C");
    int i = dongu.indexOf(m_secim.toUpper() == L1("AUTO") ? L1("auto") : m_secim.toUpper());
    return dongu.at((i + 1) % dongu.size());
}

void Depo::sec(const QString &secim)
{
    const QString yeni = secim == L1("auto") ? secim : secim.toUpper();
    if (yeni == m_secim) return;
    m_secim = yeni;
    QDir().mkpath(L1("C:/Data/E6"));
    QSettings s(ayarDosyasi(), QSettings::IniFormat);
    s.setValue(m_uygulama, m_secim);
    s.sync();
    emit degisti();
}

// Sorun giderme: her acilista suruculerin durumu ve secim (kucuk dosya, uzerine yazilir)
void Depo::taniYaz() const
{
#ifdef Q_OS_SYMBIAN
    QDir().mkpath(L1("C:/Data/E6"));
    QFile f(L1("C:/Data/E6/depo_tani.txt"));
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text)) return;
    QString t = m_uygulama + L1(" kurulum=") + kurulumSurucusu() + L1(" secim=") + m_secim + L1(" etkin=") + m_etkin + L1("\n");
    for (char c = 'C'; c <= 'Z'; ++c) {
        const QString h = QString(QChar(c));
        const int no = c - 'A';
        RFs fs;
        if (fs.Connect() != KErrNone) break;
        TDriveInfo di;
        const TInt e = fs.Drive(di, no);
        TVolumeInfo vi;
        const TInt ev = fs.Volume(vi, no);
        fs.Close();
        if (e != KErrNone || di.iType == EMediaNotPresent) continue;
        t += h + QString::fromLatin1(": tur=%1 suruAtt=0x%2 ortamAtt=0x%3 hacim=%4 bosMB=%5 aday=%6 saglam=%7\n")
                 .arg(int(di.iType)).arg(uint(di.iDriveAtt), 0, 16).arg(uint(di.iMediaAtt), 0, 16).arg(int(ev))
                 .arg(ev == KErrNone ? int(vi.iFree / (1024 * 1024)) : -1)
                 .arg(bilgi(h).var ? 1 : 0).arg((c != 'Z' && bilgi(h).var) ? (saglam(h) ? 1 : 0) : 0);
    }
    f.write(t.toUtf8());
#endif
}
