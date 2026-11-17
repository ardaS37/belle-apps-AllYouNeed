#include "ayna.h"

#include <QtCore/QCoreApplication>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QTextStream>
#include <QtCore/QEvent>


#ifdef Q_OS_SYMBIAN
#include <e32std.h>
#endif

static const qint64 KEnBuyuk = 8 * 1024 * 1024;     // daha buyuk dosyalar (onbellek vb.) aynalanmaz

static bool atla(const QString &ad)
{
    const QString k = ad.toLower();
    return k == "onbellek" || k == "cache" || k == "tmp" || k == "temp" || k == "thumbs" || k.endsWith(".tmp") || k.endsWith("-journal");
}

// Klasoru (alt klasorlerle) kopyalar; hedefte ayni boyut+tarihli dosyayi yeniden yazmaz. Kopyalanan dosya sayisi.
static int kopyala(const QString &kaynak, const QString &hedef)
{
    QDir k(kaynak);
    if (kaynak.isEmpty() || !k.exists()) return 0;
    // hedef kaynagin icindeyse (ya da tersi) sonsuz dongu olur
    const QString ka = QDir::cleanPath(k.absolutePath()).toLower() + "/", ha = QDir::cleanPath(QDir(hedef).absolutePath()).toLower() + "/";
    if (ha.startsWith(ka) || ka.startsWith(ha)) return 0;
    QDir().mkpath(hedef);
    int n = 0;
    foreach (const QFileInfo &fi, k.entryInfoList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System)) {
        if (atla(fi.fileName())) continue;
        const QString h = hedef + "/" + fi.fileName();
        if (fi.isDir()) { n += kopyala(fi.absoluteFilePath(), h); continue; }
        if (fi.size() > KEnBuyuk) continue;
        QFileInfo hi(h);
        if (hi.exists() && hi.size() == fi.size() && hi.lastModified() >= fi.lastModified()) continue;
        QFile::remove(h);
        if (QFile::copy(fi.absoluteFilePath(), h)) ++n;
    }
    return n;
}

// Yalnizca hedefte OLMAYAN dosyalari geri koyar (sonradan olusmus yeni ayarlari ezmez)
static int eksikleriKoy(const QString &kaynak, const QString &hedef)
{
    QDir k(kaynak);
    if (!k.exists()) return 0;
    int n = 0;
    foreach (const QFileInfo &fi, k.entryInfoList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System)) {
        const QString h = hedef + "/" + fi.fileName();
        if (fi.isDir()) { n += eksikleriKoy(fi.absoluteFilePath(), h); continue; }
        if (QFileInfo(h).exists()) continue;
        QDir().mkpath(hedef);
        if (QFile::copy(fi.absoluteFilePath(), h)) ++n;
    }
    return n;
}

// QSettings (Symbian): tum uygulamalarin ayar dosyalari herkese acik C:/Data/.config altinda (ROM ile silinir)
static QString ortakConfig() { return "C:/Data/.config"; }

static int dosyaSayisi(const QString &yol)
{
    QDir d(yol);
    if (!d.exists()) return 0;
    int n = 0;
    foreach (const QFileInfo &fi, d.entryInfoList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System)) {
        if (fi.isDir()) n += dosyaSayisi(fi.absoluteFilePath());
        else ++n;
    }
    return n;
}

QString Ayna::kok()
{
#ifdef Q_OS_SYMBIAN
    if (QDir("E:/").exists()) return "E:/BelleYedek/Uygulamalar";
    return "C:/Data/BelleYedek/Uygulamalar";
#else
    return QDir::homePath() + "/BelleYedek/Uygulamalar";
#endif
}

QString Ayna::ozelKlasor()
{
#ifdef Q_OS_SYMBIAN
    // Uygulamanin kendi guvenli kimligi (UID3) -> C:/Private/<uid>
    const TUint32 sid = RProcess().SecureId().iId;
    return QString("C:/Private/%1").arg(sid, 8, 16, QLatin1Char('0'));
#else
    // Masaustu/Simulator: yalnizca arayuz denemesi; gercek ozel klasor yok, kucuk bir deneme klasoru kullanilir
    return QDir::homePath() + "/BelleYedekDeneme/ozel_" + QCoreApplication::applicationName();
#endif
}

Ayna::Ayna(const QString &ad, const QStringList &ek) : QObject(qApp), m_ad(ad), m_ek(ek) { }

void Ayna::yaz(const QString &s)
{
    const QString d = kok() + "/" + m_ad;
    QDir().mkpath(d);
    QFile f(d + "/ayna.txt");
    if (f.size() > 32 * 1024) f.remove();
    if (f.open(QIODevice::Append | QIODevice::Text)) {
        QTextStream t(&f);
        t.setCodec("UTF-8");
        t << QDateTime::currentDateTime().toString("dd.MM.yyyy HH:mm:ss ") << s << "\n";
    }
}

void Ayna::baslat(const QString &ad, const QStringList &ekKlasorler)
{
    Ayna *a = new Ayna(ad, ekKlasorler);
    const QString hedef = kok() + "/" + ad;
    const QString ozel = ozelKlasor();
    // Ozel klasor bos ama aynada veri var: telefon sifirlanmis / uygulama yeniden kurulmus -> geri yukle
    // (C:/Data altindaki ek klasorler de bossa onlar da geri gelir)
    const bool ozelBos = dosyaSayisi(ozel) == 0;
    if (ozelBos && dosyaSayisi(hedef + "/ozel") > 0) {
        const int n = kopyala(hedef + "/ozel", ozel);
        a->yaz(QString("GERI YUKLENDI ozel klasor: %1 dosya -> %2").arg(n).arg(ozel));
    }
    for (int i = 0; i < ekKlasorler.size(); ++i) {
        const QString h = hedef + "/ek" + QString::number(i);
        if (dosyaSayisi(ekKlasorler.at(i)) == 0 && dosyaSayisi(h) > 0) {
            const int n = kopyala(h, ekKlasorler.at(i));
            a->yaz(QString("GERI YUKLENDI %1: %2 dosya").arg(ekKlasorler.at(i)).arg(n));
        }
    }
#ifdef Q_OS_SYMBIAN
    {
        const int n = eksikleriKoy(kok() + "/_ortak/config", ortakConfig());
        if (n > 0) a->yaz(QString("GERI YUKLENDI C:/Data/.config: %1 eksik ayar dosyasi").arg(n));
    }
#endif
    a->yedekle();
    qApp->installEventFilter(a);
    QObject::connect(qApp, SIGNAL(aboutToQuit()), a, SLOT(yedekle()));
}

void Ayna::yedekle()
{
    const QString hedef = kok() + "/" + m_ad;
    int n = kopyala(ozelKlasor(), hedef + "/ozel");
    for (int i = 0; i < m_ek.size(); ++i) n += kopyala(m_ek.at(i), hedef + "/ek" + QString::number(i));
#ifdef Q_OS_SYMBIAN
    n += kopyala(ortakConfig(), kok() + "/_ortak/config");
#endif
    m_son = QDateTime::currentDateTime();
    // Bilgi dosyasi: Belle Files'in Yedekler sayfasi okur
    QFile f(hedef + "/bilgi.txt");
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        QTextStream t(&f);
        t.setCodec("UTF-8");
        t << "ad=" << m_ad << "\n" << "ozel=" << ozelKlasor() << "\n" << "ek=" << m_ek.join(";") << "\n"
          << "tarih=" << m_son.toString("yyyy-MM-dd HH:mm:ss") << "\n" << "surum=" << QCoreApplication::applicationVersion() << "\n";
    }
    if (n > 0) yaz(QString("aynalandi: %1 dosya degisti").arg(n));
}

bool Ayna::eventFilter(QObject *o, QEvent *e)
{
    if (e->type() == QEvent::ApplicationDeactivate && (m_son.isNull() || m_son.secsTo(QDateTime::currentDateTime()) > 120))
        yedekle();
    return QObject::eventFilter(o, e);
}
