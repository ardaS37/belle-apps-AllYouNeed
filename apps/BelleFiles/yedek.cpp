#include "yedek.h"
#include "depo.h"
#include "dil.h"
#include "sms.h"

#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QDateTime>
#include <QtCore/QTimer>
#include <QtCore/QSet>
#include <QtCore/QRegExp>
#include <QtCore/QTextStream>
#include <QtCore/QCoreApplication>

#ifdef BELLE_MOBILITY_REHBER
#include <qcontactmanager.h>
#include <qcontact.h>
#include <qcontactphonenumber.h>
#include <qcontactname.h>
#include <qcontactdisplaylabel.h>
#include <qcontactfetchhint.h>
#include <qversitcontactexporter.h>
#include <qversitcontactimporter.h>
#include <qversitwriter.h>
#include <qversitreader.h>
#include <qversitdocument.h>
QTM_USE_NAMESPACE
#endif

static QString gunlukYolu() { return QDir("C:/Data").exists() ? "C:/Data/BelleFiles/yedek_gunluk.txt" : QDir::tempPath() + "/bellefiles_yedek_gunluk.txt"; }

static QString boyutMetni(qint64 b)
{
    if (b < 1024) return QString::number(b) + " B";
    if (b < 1024 * 1024) return QString::number((b + 512) / 1024) + " KB";
    return QString::number(b / 1048576.0, 'f', 1) + " MB";
}

static qint64 klasorBoyutu(const QString &yol, int *adet, QDateTime *son)
{
    QDir d(yol);
    qint64 t = 0;
    foreach (const QFileInfo &fi, d.entryInfoList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System)) {
        if (fi.isDir()) t += klasorBoyutu(fi.absoluteFilePath(), adet, son);
        else {
            t += fi.size();
            if (adet) ++*adet;
            if (son && fi.lastModified() > *son) *son = fi.lastModified();
        }
    }
    return t;
}

Yedek::Yedek(QObject *parent) : QObject(parent), m_calisiyor(false), m_hepsiOk(true)
{
#ifdef Q_OS_SYMBIAN
    m_kok = QFileInfo(Depo::yedekKoku()).path();   // .../BelleYedek (ayar aynasiyla ayni surucu)
#else
    m_kok = QDir::homePath() + "/BelleYedek";
#endif
    QDir().mkpath(m_kok + "/Rehber");
    QDir().mkpath(m_kok + "/SMS");
    QDir().mkpath(m_kok + "/Uygulamalar");
    QDir().mkpath(QFileInfo(gunlukYolu()).absolutePath());
}

void Yedek::log(const QString &s)
{
    QFile f(gunlukYolu());
    if (f.size() > 64 * 1024) f.remove();
    if (f.open(QIODevice::Append | QIODevice::Text)) {
        QTextStream t(&f);
        t.setCodec("UTF-8");
        t << QDateTime::currentDateTime().toString("dd.MM HH:mm:ss ") << s << "\n";
    }
}

QString Yedek::gunluk() const
{
    QFile f(gunlukYolu());
    if (!f.open(QIODevice::ReadOnly)) return QString();
    QByteArray b = f.readAll();
    if (b.size() > 8000) b = b.right(8000);
    return QString::fromUtf8(b);
}

void Yedek::durumYaz(const QString &s)
{
    m_durum = s;
    emit degisti();
    QCoreApplication::processEvents();
}

// ---------------- Ozet / listeler ----------------
QVariantList Yedek::dosyalar(const QString &tur)
{
    QVariantList l;
    const bool sms = tur == "SMS";
    QDir d(m_kok + "/" + tur);
    foreach (const QFileInfo &fi, d.entryInfoList(QStringList() << (sms ? "*.xml" : "*.vcf"), QDir::Files, QDir::Time)) {
        QVariantMap m;
        m["dosya"] = fi.absoluteFilePath();
        m["ad"] = fi.fileName();
        m["tarih"] = fi.lastModified().toString("dd.MM.yyyy HH:mm");
        m["boyut"] = boyutMetni(fi.size());
        int n = 0;
        QFile f(fi.absoluteFilePath());
        if (f.open(QIODevice::ReadOnly)) {
            const QByteArray b = f.readAll();
            n = sms ? b.count("<sms ") : b.toUpper().count("BEGIN:VCARD");
        }
        m["adet"] = n;
        l << m;
    }
    return l;
}

QVariantList Yedek::uygulamalar()
{
    QVariantList l;
    QDir d(m_kok + "/Uygulamalar");
    foreach (const QFileInfo &fi, d.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name | QDir::IgnoreCase)) {
        QVariantMap m;
        m["ad"] = fi.fileName() == "_ortak" ? Dil::t("Ortak ayarlar (C:\\Data\\.config: Mail, Drive, Belle Browser…)") : fi.fileName();
        m["yol"] = fi.absoluteFilePath();
        int adet = 0; QDateTime son;
        const qint64 b = klasorBoyutu(fi.absoluteFilePath(), &adet, &son);
        QString tarih;
        QFile f(fi.absoluteFilePath() + "/bilgi.txt");
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            foreach (const QString &s, QString::fromUtf8(f.readAll()).split('\n'))
                if (s.startsWith("tarih=")) tarih = s.mid(6).trimmed();
        }
        const QDateTime dt = QDateTime::fromString(tarih, "yyyy-MM-dd HH:mm:ss");
        m["tarih"] = dt.isValid() ? dt.toString("dd.MM.yyyy HH:mm") : (son.isValid() ? son.toString("dd.MM.yyyy HH:mm") : QString("-"));
        m["boyut"] = boyutMetni(b);
        m["adet"] = adet;
        l << m;
    }
    return l;
}

QVariantMap Yedek::ozet()
{
    QVariantMap m;
    const QVariantList r = dosyalar("Rehber"), s = dosyalar("SMS"), u = uygulamalar();
    m["rehberSon"] = r.isEmpty() ? QString() : r.first().toMap().value("tarih");
    m["rehberAdet"] = r.size();
    m["smsSon"] = s.isEmpty() ? QString() : s.first().toMap().value("tarih");
    m["smsAdet"] = s.size();
    m["uygulamaAdet"] = u.size();
    // Belle'nin kendi telefon yedegi (Dosya yoneticisi > Telefon hafizasini yedekle)
    // E6: E: dahili yigin bellek, F: hafiza karti. Yedek hangisine alindiysa orada "Backup" klasoru olur
    // (gizli/sistem olabilir, adin buyuk-kucuk harfi degisebilir). Birden fazlaysa en yenisi.
    QString sistemYol; QDateTime sistemSon; QStringList tum;
    foreach (const QString &surucu, QStringList() << "E:/" << "F:/" << "D:/" << "G:/") {
        QDir kd(surucu);
        if (!kd.exists()) continue;
        foreach (const QFileInfo &fi, kd.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System)) {
            const QString ad = fi.fileName().toLower();
            if (!(ad == "backup" || ad.startsWith("backup") || ad == "yedekleme")) continue;
            int adet = 0; QDateTime son;
            klasorBoyutu(fi.absoluteFilePath(), &adet, &son);
            if (adet == 0) continue;
            tum << fi.absoluteFilePath();
            if (sistemYol.isEmpty() || (son.isValid() && son > sistemSon)) { sistemYol = fi.absoluteFilePath(); sistemSon = son; }
        }
    }
    m["sistemTum"] = tum;
    if (!sistemYol.isEmpty()) {
        int adet = 0; QDateTime son;
        const qint64 b = klasorBoyutu(sistemYol, &adet, &son);
        m["sistemYol"] = sistemYol;
        m["sistemBoyut"] = boyutMetni(b);
        m["sistemTarih"] = son.isValid() ? son.toString("dd.MM.yyyy HH:mm") : QString();
        m["sistemAdet"] = adet;
    }
    int cAdet = 0;
    m["cDataBoyut"] = boyutMetni(klasorBoyutu("C:/Data", &cAdet, 0));
    int tAdet = 0;
    m["toplamBoyut"] = boyutMetni(klasorBoyutu(m_kok, &tAdet, 0));
    return m;
}

int Yedek::rehberKisi()
{
#ifdef BELLE_MOBILITY_REHBER
    QContactManager mgr;
    return mgr.contactIds().count();
#else
    return -1;
#endif
}

int Yedek::smsSayisi() { return Sms::say(0); }

bool Yedek::sil(const QString &dosya)
{
    if (!dosya.startsWith(m_kok) || !(dosya.endsWith(".vcf") || dosya.endsWith(".xml"))) return false;
    const bool ok = QFile::remove(dosya);
    log("sil " + QFileInfo(dosya).fileName() + (ok ? " tamam" : " HATA"));
    emit degisti();
    return ok;
}

QString Yedek::onizle(const QString &dosya, int enFazla)
{
    QFile f(dosya);
    if (!f.open(QIODevice::ReadOnly)) return QString();
    QStringList satirlar;
    int toplam = 0;
    if (dosya.endsWith(".xml")) {
        const QString t = QString::fromUtf8(f.readAll());
        QRegExp rx("<sms [^>]*address=\"([^\"]*)\"[^>]*type=\"(\\d)\"[^>]*body=\"([^\"]*)\"[^>]*readable_date=\"([^\"]*)\"");
        int p = 0;
        while ((p = rx.indexIn(t, p)) >= 0) {
            ++toplam;
            if (satirlar.size() < enFazla) {
                QString g = rx.cap(3).replace("&#10;", " ").replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&apos;", "'");
                if (g.length() > 50) g = g.left(50) + Dil::t("…");
                satirlar << rx.cap(4).left(16) + (rx.cap(2) == "1" ? QString::fromUtf8("  ← ") : QString::fromUtf8("  → ")) + rx.cap(1) + ": " + g;
            }
            p += rx.matchedLength();
        }
    } else {
        while (!f.atEnd()) {
            const QByteArray s = f.readLine().trimmed();
            if (s.toUpper().startsWith("FN:") || s.toUpper().startsWith("FN;")) {
                ++toplam;
                if (satirlar.size() < enFazla) satirlar << QString::fromUtf8(s.mid(s.indexOf(':') + 1)).replace("\\,", ",").replace("\\;", ";");
            }
        }
    }
    QString t = satirlar.join("\n");
    if (toplam > satirlar.size()) t += Dil::t("\n… ve ") + QString::number(toplam - satirlar.size()) + Dil::t(" tane daha");
    return t;
}

// ---------------- Is kuyrugu (arayuz "calisiyor" gostersin diye olay dongusunden) ----------------
void Yedek::rehberYedekle() { if (m_calisiyor) return; m_kuyruk = QStringList() << "rehber"; m_sonuclar.clear(); m_hepsiOk = true; m_calisiyor = true; durumYaz(Dil::t("Rehber okunuyor…")); QTimer::singleShot(50, this, SLOT(isle())); }
void Yedek::smsYedekle() { if (m_calisiyor) return; m_kuyruk = QStringList() << "sms"; m_sonuclar.clear(); m_hepsiOk = true; m_calisiyor = true; durumYaz(Dil::t("Mesajlar okunuyor…")); QTimer::singleShot(50, this, SLOT(isle())); }
void Yedek::tamYedek() { if (m_calisiyor) return; m_kuyruk = QStringList() << "rehber" << "sms"; m_sonuclar.clear(); m_hepsiOk = true; m_calisiyor = true; durumYaz(Dil::t("Tam yedek başlıyor…")); QTimer::singleShot(50, this, SLOT(isle())); }
void Yedek::rehberGeriYukle(const QString &dosya) { if (m_calisiyor) return; m_kuyruk = QStringList() << "rehberGeri:" + dosya; m_sonuclar.clear(); m_hepsiOk = true; m_calisiyor = true; durumYaz(Dil::t("Rehber yedeği okunuyor…")); QTimer::singleShot(50, this, SLOT(isle())); }
void Yedek::smsGeriYukle(const QString &dosya) { if (m_calisiyor) return; m_kuyruk = QStringList() << "smsGeri:" + dosya; m_sonuclar.clear(); m_hepsiOk = true; m_calisiyor = true; durumYaz(Dil::t("SMS yedeği okunuyor…")); QTimer::singleShot(50, this, SLOT(isle())); }

void Yedek::isle()
{
    if (m_kuyruk.isEmpty()) {
        m_calisiyor = false;
        const QString mesaj = m_sonuclar.join("\n");
        durumYaz(m_hepsiOk ? Dil::t("Tamamlandı") : m_sonuclar.value(0).split('\n').first());
        emit bitti(m_hepsiOk, mesaj, "");
        return;
    }
    const QString is = m_kuyruk.takeFirst();
    QString mesaj;
    bool ok;
    if (is == "rehber") ok = rehberYedekleIs(&mesaj);
    else if (is == "sms") ok = smsYedekleIs(&mesaj);
    else if (is.startsWith("rehberGeri:")) ok = rehberGeriYukleIs(is.mid(11), &mesaj);
    else ok = smsGeriYukleIs(is.mid(8), &mesaj);
    log(is.left(40) + (ok ? " tamam: " : " HATA: ") + mesaj.simplified());
    m_sonuclar << mesaj;
    if (!ok) m_hepsiOk = false;
    QTimer::singleShot(30, this, SLOT(isle()));
}

// ---------------- SMS ----------------
bool Yedek::smsYedekleIs(QString *mesaj)
{
    durumYaz(Dil::t("Mesajlar okunuyor…"));
    const QString ad = m_kok + "/SMS/sms_" + QDateTime::currentDateTime().toString("yyyyMMdd_HHmm") + ".xml";
    const QString gecici = ad + ".yaziliyor";
    int adet = 0; QString hata;
    if (!Sms::yedekle(gecici, &adet, &hata)) { QFile::remove(gecici); *mesaj = "SMS: " + hata; return false; }
    QFile::remove(ad);
    QFile::rename(gecici, ad);
    *mesaj = Dil::t("SMS: ") + QString::number(adet) + Dil::t(" mesaj yedeklendi (") + QFileInfo(ad).fileName() + ")";
    return true;
}

bool Yedek::smsGeriYukleIs(const QString &dosya, QString *mesaj)
{
    durumYaz(Dil::t("Mesajlar karşılaştırılıyor ve ekleniyor…"));
    int e = 0, a = 0, h = 0; QString hata;
    const bool ok = Sms::geriYukle(dosya, &e, &a, &h, &hata);
    if (!ok && e == 0) { *mesaj = "SMS: " + hata; return false; }
    *mesaj = Dil::t("SMS: %1 mesaj eklendi, %2 mesaj zaten olduğu için atlandı.").arg(e).arg(a);
    if (h) *mesaj += Dil::t(" %1 mesaj eklenemedi.").arg(h);
    if (!hata.isEmpty()) *mesaj += "\n" + hata;
    return h == 0;
}

// ---------------- Rehber (Belle Rehber 1.0.1 ile ayni) ----------------
static bool bosDeger(const QString &satir)
{
    const int i = satir.indexOf(QLatin1Char(':'));
    if (i < 0) return false;
    QString v = satir.mid(i + 1);
    const QString ad = satir.left(i).section(QLatin1Char(';'), 0, 0).toUpper();
    if (ad == "GEO" && (v == "-1;-1" || v == "-1,-1")) return true;
    v.remove(QLatin1Char(';')).remove(QLatin1Char(',')).remove(QLatin1Char(' '));
    return v.isEmpty();
}
static QString nDenFn(const QString &nSatiri)
{
    const QStringList p = nSatiri.mid(nSatiri.indexOf(QLatin1Char(':')) + 1).split(QLatin1Char(';'));
    QStringList s;
    const int sira[5] = { 3, 1, 2, 0, 4 };
    for (int i = 0; i < 5; ++i) if (p.size() > sira[i] && !p.at(sira[i]).isEmpty()) s << p.at(sira[i]);
    return s.join(" ");
}
static int vcfTemizle(const QString &yol)
{
    QFile f(yol);
    if (!f.open(QIODevice::ReadOnly)) return -1;
    const QString metin = QString::fromUtf8(f.readAll());
    f.close();
    QStringList satirlar;
    foreach (const QString &s, metin.split(QRegExp("\\r?\\n"))) {
        if ((s.startsWith(QLatin1Char(' ')) || s.startsWith(QLatin1Char('\t'))) && !satirlar.isEmpty()) satirlar.last() += s.mid(1);
        else satirlar << s;
    }
    QStringList cikti, kart;
    int atilan = 0;
    bool fnVar = false;
    QString nSatiri;
    foreach (const QString &s, satirlar) {
        const QString u = s.toUpper();
        if (u == "BEGIN:VCARD") { kart.clear(); fnVar = false; nSatiri.clear(); kart << s; continue; }
        if (u == "END:VCARD") {
            if (!fnVar && !nSatiri.isEmpty()) {
                const QString fn = nDenFn(nSatiri);
                if (!fn.isEmpty()) { const int k = kart.indexOf(nSatiri); kart.insert(k >= 0 ? k + 1 : kart.size(), "FN:" + fn); }
            }
            kart << s;
            cikti += kart;
            kart.clear();
            continue;
        }
        if (s.isEmpty()) continue;
        if (u.startsWith("FN:") || u.startsWith("FN;")) { if (bosDeger(s)) { ++atilan; continue; } fnVar = true; }
        if (u.startsWith("N:") || u.startsWith("N;")) nSatiri = s;
        if (!u.startsWith("BEGIN") && !u.startsWith("VERSION") && !u.startsWith("N:") && !u.startsWith("N;") && bosDeger(s)) { ++atilan; continue; }
        kart << s;
    }
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) return -1;
    f.write((cikti.join("\r\n") + "\r\n").toUtf8());
    f.close();
    return atilan;
}

bool Yedek::rehberYedekleIs(QString *mesaj)
{
    const QString ad = m_kok + "/Rehber/rehber_" + QDateTime::currentDateTime().toString("yyyyMMdd_HHmm") + ".vcf";
    const QString gecici = ad + ".yaziliyor";
#ifdef BELLE_MOBILITY_REHBER
    durumYaz(Dil::t("Rehber okunuyor…"));
    QContactManager mgr;
    QList<QContact> kisiler = mgr.contacts();
    if (mgr.error() != QContactManager::NoError && kisiler.isEmpty()) { *mesaj = Dil::t("Rehber okunamadı (hata %1)").arg(mgr.error()); return false; }
    QList<QContact> sadece;
    foreach (const QContact &c, kisiler) if (c.type() == QContactType::TypeContact) sadece << c;
    durumYaz(QString::number(sadece.count()) + Dil::t(" kişi vCard'a çevriliyor…"));
    QVersitContactExporter exp;
    exp.exportContacts(sadece, QVersitDocument::VCard30Type);
    if (exp.documents().isEmpty()) { *mesaj = Dil::t("Rehber: vCard'a çevrilemedi"); return false; }
    QFile f(gecici);
    if (!f.open(QIODevice::WriteOnly)) { *mesaj = Dil::t("Dosya açılamadı: ") + ad; return false; }
    QVersitWriter w(&f);
    w.startWriting(exp.documents());
    w.waitForFinished();
    f.close();
    if (w.error() != QVersitWriter::NoError) { QFile::remove(gecici); *mesaj = Dil::t("Rehber: yazma hatası %1").arg(w.error()); return false; }
    const int n = exp.documents().count();
#else
    QFile f(gecici);
    if (!f.open(QIODevice::WriteOnly)) { *mesaj = "Dosya acilamadi"; return false; }
    f.write("BEGIN:VCARD\r\nVERSION:3.0\r\nN:Kisi;Deneme;;;\r\nTEL;TYPE=HOME:\r\nTEL;TYPE=CELL:+905550000000\r\nGEO:-1;-1\r\nEND:VCARD\r\n");
    f.close();
    const int n = 1;
#endif
    const int atilan = vcfTemizle(gecici);
    QFile::remove(ad);
    QFile::rename(gecici, ad);
    log(QString("rehber: %1 kisi, %2 bos satir atildi").arg(n).arg(atilan));
    *mesaj = Dil::t("Rehber: ") + QString::number(n) + Dil::t(" kişi yedeklendi (") + QFileInfo(ad).fileName() + ")";
    return true;
}

#ifdef BELLE_MOBILITY_REHBER
static QString numaraAnahtari(const QString &n)
{
    QString d;
    for (int i = 0; i < n.size(); ++i) if (n.at(i).isDigit()) d += n.at(i);
    return d.length() > 9 ? d.right(9) : d;
}
static QString adAnahtari(const QContact &c)
{
    QContactName n = c.detail<QContactName>();
    QString s = (n.firstName() + " " + n.middleName() + " " + n.lastName()).simplified();
    if (s.isEmpty()) s = n.customLabel().simplified();
    if (s.isEmpty()) s = c.displayLabel().simplified();
    return s.toLower();
}
#endif

bool Yedek::rehberGeriYukleIs(const QString &dosya, QString *mesaj)
{
#ifdef BELLE_MOBILITY_REHBER
    QFile f(dosya);
    if (!f.open(QIODevice::ReadOnly)) { *mesaj = Dil::t("Rehber: yedek dosyası açılamadı"); return false; }
    QVersitReader r(&f);
    r.startReading();
    r.waitForFinished();
    const QList<QVersitDocument> belgeler = r.results();
    f.close();
    QVersitContactImporter imp;
    imp.importDocuments(belgeler);
    QList<QContact> yeni = imp.contacts();
    if (yeni.isEmpty()) { *mesaj = Dil::t("Rehber: yedekte kişi yok"); return false; }
    durumYaz(Dil::t("Rehberdeki kişilerle karşılaştırılıyor…"));
    QContactManager mgr;
    QSet<QString> numaralar, adlar;
    QContactFetchHint ipucu;
    ipucu.setDetailDefinitionsHint(QStringList() << QContactPhoneNumber::DefinitionName << QContactName::DefinitionName << QContactDisplayLabel::DefinitionName);
    foreach (const QContact &c, mgr.contacts(QContactFilter(), QList<QContactSortOrder>(), ipucu)) {
        foreach (const QContactPhoneNumber &p, c.details<QContactPhoneNumber>()) { const QString k = numaraAnahtari(p.number()); if (k.length() >= 5) numaralar.insert(k); }
        const QString a = adAnahtari(c);
        if (!a.isEmpty()) adlar.insert(a);
    }
    QList<QContact> eklenecek;
    int atlanan = 0;
    foreach (QContact c, yeni) {
        foreach (QContactDetail d, c.details()) {
            bool dolu = false;
            foreach (const QVariant &v, d.variantValues()) { const QString s = v.toString().trimmed(); if (!s.isEmpty() && s != "-1") { dolu = true; break; } }
            if (!dolu && d.definitionName() != QContactDisplayLabel::DefinitionName && d.definitionName() != QContactType::DefinitionName) c.removeDetail(&d);
        }
        bool var = false;
        const QList<QContactPhoneNumber> nl = c.details<QContactPhoneNumber>();
        foreach (const QContactPhoneNumber &p, nl) if (numaralar.contains(numaraAnahtari(p.number()))) { var = true; break; }
        if (!var && nl.isEmpty()) var = adlar.contains(adAnahtari(c));
        if (var) { ++atlanan; continue; }
        c.setId(QContactId());
        eklenecek << c;
        foreach (const QContactPhoneNumber &p, nl) numaralar.insert(numaraAnahtari(p.number()));
    }
    int eklenen = 0, hatali = 0;
    for (int i = 0; i < eklenecek.count(); i += 25) {
        QList<QContact> parca = eklenecek.mid(i, 25);
        QMap<int, QContactManager::Error> hatalar;
        mgr.saveContacts(&parca, &hatalar);
        hatali += hatalar.count();
        eklenen += parca.count() - hatalar.count();
        durumYaz(Dil::t("Ekleniyor: %1 / %2").arg(qMin(i + 25, eklenecek.count())).arg(eklenecek.count()));
    }
    *mesaj = Dil::t("Rehber: %1 kişi eklendi, %2 kişi zaten olduğu için atlandı.").arg(eklenen).arg(atlanan);
    if (hatali) *mesaj += Dil::t(" %1 kişi kaydedilemedi.").arg(hatali);
    return hatali == 0;
#else
    Q_UNUSED(dosya);
    *mesaj = Dil::t("Rehber: geri yükleme yalnızca telefonda");
    return false;
#endif
}
