#include "isci.h"
#include "dil.h"

#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QVariantMap>
#include <QtCore/QMap>
#include <QtCore/QRegExp>
#include <QtCore/QTextCodec>

static QString yolNorm(const QString &p) { QString s = QDir::fromNativeSeparators(p); while (s.length() > 3 && s.endsWith('/')) s.chop(1); return s; }

Isci::Isci(QObject *parent)
    : QThread(parent), m_iptal(false), m_bitti(0), m_toplam(0), m_adet(0), m_toplamAdet(0), m_ok(false), m_parolaSorunu(false)
{
    connect(this, SIGNAL(finished()), this, SLOT(onBitti()));
}

QString Isci::benzersiz(const QString &klasor, const QString &ad) const
{
    const QString k = yolNorm(klasor);
    const QString sep = k.endsWith('/') ? "" : "/";
    QString p = k + sep + ad;
    if (!QFileInfo(p).exists()) return p;
    QString kok = ad, uz;
    const int nokta = ad.lastIndexOf('.');
    if (nokta > 0 && !QFileInfo(p).isDir()) { kok = ad.left(nokta); uz = ad.mid(nokta); }
    for (int i = 2; i < 1000; ++i) {
        p = k + sep + kok + " (" + QString::number(i) + ")" + uz;
        if (!QFileInfo(p).exists()) return p;
    }
    return p;
}

bool Isci::baslat(const QString &tur, const QStringList &kaynaklar, const QString &hedef, const QStringList &secili)
{
    if (isRunning() || kaynaklar.isEmpty()) return false;
    m_tur = tur;
    m_kaynaklar.clear();
    foreach (const QString &k, kaynaklar) m_kaynaklar << yolNorm(k);
    m_hedef = yolNorm(hedef);
    m_secili = secili;
    m_iptal = false;
    m_bitti = m_toplam = 0;
    m_adet = m_toplamAdet = 0;
    m_ok = false;
    m_parolaSorunu = false;
    m_mesaj.clear(); m_sonuc.clear(); m_ad.clear();
    start(QThread::LowPriority);
    emit durumDegisti();
    return true;
}

void Isci::onBitti()
{
    emit ilerleme(double(m_bitti), double(m_toplam), m_ad, m_adet, m_toplamAdet);
    emit durumDegisti();
    emit bitti(m_ok, m_mesaj, m_sonuc);
}

void Isci::bildir(const QString &ad, bool zorla)
{
    m_ad = ad;
    if (!zorla && m_saat.isValid() && m_saat.elapsed() < 150) return;
    m_saat.start();
    emit ilerleme(double(m_bitti), double(m_toplam), ad, m_adet, m_toplamAdet);
}

bool Isci::zipIlerleme(qint64 bayt)
{
    m_bitti += bayt;
    bildir(m_ad);
    return !m_iptal;
}

void Isci::topla(const QString &yol, const QString &goreli, QList<Is> *liste)
{
    QFileInfo fi(yol);
    Is is;
    is.yol = yol; is.goreli = goreli; is.klasor = fi.isDir(); is.boyut = is.klasor ? 0 : fi.size();
    liste->append(is);
    if (!is.klasor) { m_toplam += is.boyut; ++m_toplamAdet; return; }
    QDir d(yol);
    foreach (const QFileInfo &c, d.entryInfoList(QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System, QDir::Name)) {
        if (m_iptal) return;
        topla(yolNorm(c.absoluteFilePath()), goreli + "/" + c.fileName(), liste);
    }
}

bool Isci::dosyaKopyala(const QString &a, const QString &b)
{
    QFile in(a), out(b);
    if (!in.open(QIODevice::ReadOnly)) { m_hata = Dil::t("Okunamadı: ") + a; return false; }
    if (!out.open(QIODevice::WriteOnly)) { m_hata = Dil::t("Yazılamadı: ") + b; return false; }
    QByteArray tampon(65536, 0);
    for (;;) {
        const qint64 n = in.read(tampon.data(), tampon.size());
        if (n < 0) { m_hata = Dil::t("Okuma hatası: ") + a; out.close(); QFile::remove(b); return false; }
        if (n == 0) break;
        if (out.write(tampon.constData(), n) != n) { m_hata = Dil::t("Yer kalmadı ya da yazılamadı: ") + b; out.close(); QFile::remove(b); return false; }
        m_bitti += n;
        bildir(m_ad);
        if (m_iptal) { out.close(); QFile::remove(b); m_hata = Dil::t("İptal edildi"); return false; }
    }
    return true;
}

bool Isci::klasorSil(const QString &yol)
{
    QFileInfo fi(yol);
    if (!fi.isDir() || fi.isSymLink()) {
        QFile f(yol);
        f.setPermissions(QFile::ReadOwner | QFile::WriteOwner);
        const bool ok = QFile::remove(yol);
        if (ok) { ++m_adet; m_bitti += 1; bildir(fi.fileName()); }
        else m_hata = Dil::t("Silinemedi: ") + yol;
        return ok;
    }
    QDir d(yol);
    bool ok = true;
    foreach (const QFileInfo &c, d.entryInfoList(QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System)) {
        if (m_iptal) return false;
        if (!klasorSil(yolNorm(c.absoluteFilePath()))) ok = false;
    }
    if (ok && !QDir().rmdir(yol)) { m_hata = Dil::t("Klasör silinemedi: ") + yol; ok = false; }
    return ok;
}

void Isci::run()
{
    m_hata.clear();
    m_saat = QTime();
    if (m_tur == "kopyala") kopyalaTasi(false);
    else if (m_tur == "tasi") kopyalaTasi(true);
    else if (m_tur == "sil") sil();
    else if (m_tur == "zip" || m_tur == "zipsakla" || m_tur == "zipsurucu") zipYap();
    else if (m_tur == "zipekle") zipEkle();
    else if (m_tur == "zipac" || m_tur == "zipacsurucu") zipAc();
    else { m_ok = false; m_mesaj = Dil::t("Bilinmeyen iş"); }
}

void Isci::kopyalaTasi(bool tasi)
{
    QDir().mkpath(m_hedef);
    // ayni surucude tasima: aninda yeniden adlandir
    QStringList kalan;
    int hizli = 0;
    foreach (const QString &k, m_kaynaklar) {
        const QString ad = QFileInfo(k).fileName();
        if ((m_hedef + "/").startsWith(k + "/", Qt::CaseInsensitive)) { m_hata = Dil::t("Klasör kendi içine kopyalanamaz: ") + ad; continue; }
        if (yolNorm(QFileInfo(k).absolutePath()).compare(m_hedef, Qt::CaseInsensitive) == 0 && tasi) continue;   // zaten orada
        if (tasi && k.left(2).compare(m_hedef.left(2), Qt::CaseInsensitive) == 0) {
            const QString h = benzersiz(m_hedef, ad);
            if (QDir().rename(k, h)) { ++hizli; m_sonuc = h; continue; }
        }
        kalan << k;
    }
    QList<Is> liste;
    foreach (const QString &k, kalan) topla(k, QFileInfo(k).fileName(), &liste);
    m_adet = 0;
    bildir(QString(), true);
    // kok ogeler icin benzersiz ad: "goreli"nin ilk parcasi degistirilir
    QMap<QString, QString> kokAd;
    foreach (const QString &k, kalan) {
        const QString ad = QFileInfo(k).fileName();
        kokAd[ad] = QFileInfo(benzersiz(m_hedef, ad)).fileName();
    }
    bool ok = true;
    foreach (const Is &is, liste) {
        if (m_iptal) { ok = false; m_hata = Dil::t("İptal edildi"); break; }
        QString g = is.goreli;
        const int bol = g.indexOf('/');
        const QString kok = bol < 0 ? g : g.left(bol);
        g = kokAd.value(kok, kok) + (bol < 0 ? QString() : g.mid(bol));
        const QString h = m_hedef + "/" + g;
        if (bol < 0) m_sonuc = h;
        m_ad = QFileInfo(is.yol).fileName();
        if (is.klasor) { if (!QDir().mkpath(h)) { ok = false; m_hata = Dil::t("Klasör oluşturulamadı: ") + h; break; } continue; }
        if (!dosyaKopyala(is.yol, h)) { ok = false; break; }
        ++m_adet;
    }
    if (ok && tasi) foreach (const QString &k, kalan) klasorSil(k);
    const int n = m_adet + hizli;
    m_ok = ok && m_hata.isEmpty();
    m_mesaj = (ok ? QString::number(n) + QString::fromUtf8(tasi ? " dosya taşındı" : " dosya kopyalandı")
                  : QString::fromUtf8(tasi ? "Taşıma yarıda kaldı: " : "Kopyalama yarıda kaldı: ") + m_hata);
    if (ok && !m_hata.isEmpty()) m_mesaj += QString::fromUtf8(" • ") + m_hata;
}

void Isci::sil()
{
    QList<Is> liste;
    foreach (const QString &k, m_kaynaklar) topla(k, QFileInfo(k).fileName(), &liste);
    m_toplam = m_toplamAdet;   // silmede ilerleme dosya sayisiyla
    bool ok = true;
    foreach (const QString &k, m_kaynaklar) { if (m_iptal) break; if (!klasorSil(k)) ok = false; }
    m_ok = ok && !m_iptal;
    m_mesaj = m_ok ? QString::number(m_adet) + Dil::t(" dosya silindi") : (m_iptal ? Dil::t("Silme durduruldu") : m_hata);
}

void Isci::zipYap()
{
    // zipsurucu: ogeler surucu harfiyle saklanir ("E/BelleYedek/...", "F/Backup/..."); zipacsurucu yerlerine geri acar
    const bool surucu = m_tur == "zipsurucu";
    QList<Is> liste;
    foreach (const QString &k, m_kaynaklar)
        topla(k, (surucu && k.length() > 1 && k.at(1) == ':' ? k.left(1).toUpper() + "/" : QString()) + QFileInfo(k).fileName(), &liste);
    bildir(QString(), true);
    QDir().mkpath(QFileInfo(m_hedef).absolutePath());
    QFile f(m_hedef + ".part");
    if (!f.open(QIODevice::WriteOnly)) { m_ok = false; m_mesaj = Dil::t("Zip oluşturulamadı: ") + m_hedef; return; }
    Zip::Yazici y(&f);
    const bool sakla = m_tur == "zipsakla" || surucu;     // sikistirmasiz paket (yedekler: hizli)
    y.sadeceSakla(sakla);
    bool ok = true;
    foreach (const Is &is, liste) {
        if (m_iptal) { ok = false; m_hata = Dil::t("İptal edildi"); break; }
        if ((is.yol + "/").startsWith(m_hedef)) continue;
        m_ad = QFileInfo(is.yol).fileName();
        if (is.klasor) { y.klasorEkle(is.goreli, QFileInfo(is.yol).lastModified().toTime_t()); continue; }
        if (!y.dosyaEkle(is.yol, is.goreli, this, &m_hata)) { ok = false; break; }
        ++m_adet;
    }
    if (ok) ok = y.bitir(&m_hata);
    f.close();
    if (ok) { QFile::remove(m_hedef); ok = f.rename(m_hedef); if (!ok) m_hata = Dil::t("Ad verilemedi"); }
    if (!ok) f.remove();
    m_ok = ok;
    m_sonuc = ok ? m_hedef : QString();
    const qint64 boy = ok ? QFileInfo(m_hedef).size() : 0;
    m_mesaj = ok ? QString::number(m_adet) + QString::fromUtf8(sakla ? " dosya paketlendi (sıkıştırmasız) • " : " dosya sıkıştırıldı • ") + QString::number((boy + 1023) / 1024) + " KB"
                 : Dil::t("Zip yapılamadı: ") + m_hata;
}

// Var olan arsive sikistirmasiz ekleme (hedef: .zip yolu). Ayni adli oge varsa atlanir.
// Yarida kalirsa arsiv eski haline dondurulur.
void Isci::zipEkle()
{
    QList<Is> liste;
    foreach (const QString &k, m_kaynaklar) topla(k, QFileInfo(k).fileName(), &liste);
    bildir(QString(), true);
    QFile f(m_hedef);
    if (!f.open(QIODevice::ReadWrite)) { m_ok = false; m_mesaj = Dil::t("Arşiv açılamadı: ") + m_hedef; return; }
    Zip::Yazici y(&f);
    if (!y.eklemeyeAc(&m_hata)) { f.close(); m_ok = false; m_mesaj = Dil::t("Arşive eklenemedi: ") + m_hata; return; }
    y.sadeceSakla(true);
    bool ok = true;
    int atlanan = 0;
    foreach (const Is &is, liste) {
        if (m_iptal) { ok = false; m_hata = Dil::t("İptal edildi"); break; }
        if (is.yol == m_hedef) continue;
        m_ad = QFileInfo(is.yol).fileName();
        const QString ad = is.klasor ? is.goreli + "/" : is.goreli;
        if (y.varMi(ad)) { if (!is.klasor) { ++atlanan; m_bitti += is.boyut; } continue; }
        if (is.klasor) { y.klasorEkle(is.goreli, QFileInfo(is.yol).lastModified().toTime_t()); continue; }
        if (!y.dosyaEkle(is.yol, is.goreli, this, &m_hata)) { ok = false; break; }
        ++m_adet;
    }
    if (ok) ok = y.bitir(&m_hata);
    if (!ok) y.geriAl();
    f.close();
    m_ok = ok;
    m_sonuc = ok ? m_hedef : QString();
    m_mesaj = ok ? QString::number(m_adet) + Dil::t(" dosya arşive eklendi (sıkıştırmasız)") + (atlanan ? QString::fromUtf8(" • ") + QString::number(atlanan) + Dil::t(" zaten vardı, atlandı") : QString())
                 : Dil::t("Arşive eklenemedi: ") + m_hata;
}

void Isci::zipAc()
{
    QList<ZipOge> ogeler;
    if (!Zip::listele(m_kaynaklar.first(), &ogeler, &m_hata)) { m_ok = false; m_mesaj = m_hata; return; }
    QList<ZipOge> secilen;
    foreach (const ZipOge &o, ogeler) {
        bool al = m_secili.isEmpty();
        foreach (const QString &s, m_secili) if (o.ad == s || (s.endsWith('/') && o.ad.startsWith(s))) { al = true; break; }
        if (al) { secilen << o; if (!o.klasor()) { m_toplam += o.boyut; ++m_toplamAdet; } }
    }
    QFile f(m_kaynaklar.first());
    if (!f.open(QIODevice::ReadOnly)) { m_ok = false; m_mesaj = Dil::t("Arşiv açılamadı"); return; }
    QDir().mkpath(m_hedef);
    bildir(QString(), true);
    // tek klasor secildiyse o klasorun adi korunur; ust klasor parcasi atilmaz (arsivdeki yapi aynen)
    bool ok = true;
    const bool surucu = m_tur == "zipacsurucu";
    // parola bayt adaylari: UTF-8 (7-Zip AES, yeni WinZip), Windows Turkce (1254), DOS Turkce (857)
    QList<QByteArray> adaylar;
    adaylar << m_parola.toUtf8();
    const char *kodlar[] = { "windows-1254", "IBM 857", "IBM 850" };
    for (int i = 0; i < 3; ++i) {
        QTextCodec *c = QTextCodec::codecForName(kodlar[i]);
        if (!c) continue;
        const QByteArray b = c->fromUnicode(m_parola);
        if (!adaylar.contains(b)) adaylar << b;
    }
    int aday = 0;
    foreach (const ZipOge &o, secilen) {
        if (m_iptal) { ok = false; m_hata = Dil::t("İptal edildi"); break; }
        QString ad = o.ad;
        ad.replace(QRegExp("[:*?\"<>|]"), "_");
        if (ad.endsWith('/')) ad.chop(1);
        QString h = m_hedef + "/" + ad;
        if (surucu) {
            // "F/Backup/x" -> "F:/Backup/x"; o surucu yoksa hedef klasore
            const int b = ad.indexOf('/');
            if (b < 0) continue;                       // yalnizca surucu klasoru ("F")
            const QString kok = ad.left(b) + ":/";
            h = (b == 1 && QDir(kok).exists() ? kok.left(2) : m_hedef) + "/" + ad.mid(b + 1);
        }
        m_ad = QFileInfo(h).fileName();
        bool ps = false;
        bool acildi = Zip::ac(f, o, h, this, &m_hata, adaylar.value(aday), &ps);
        // parola Turkce harf iceriyorsa zip'i yapan program baska kodlama kullanmis olabilir: sirayla dene
        while (!acildi && ps && o.sifreli() && aday + 1 < adaylar.size()) {
            ++aday;
            m_hata.clear();
            acildi = Zip::ac(f, o, h, this, &m_hata, adaylar.at(aday), &ps);
        }
        if (!acildi) { ok = false; m_parolaSorunu = ps; break; }
        if (!o.klasor()) { ++m_adet; m_sonuc = h; }
    }
    m_ok = ok;
    if (secilen.size() != 1) m_sonuc = m_hedef;
    m_mesaj = ok ? QString::number(m_adet) + Dil::t(" dosya çıkarıldı") : Dil::t("Açılamadı: ") + m_hata;
}

bool Isci::zipSifreli(const QString &arsiv, const QStringList &secili)
{
    QList<ZipOge> ogeler;
    QString h;
    if (!Zip::listele(arsiv, &ogeler, &h)) return false;
    foreach (const ZipOge &o, ogeler) {
        if (!o.sifreli() || o.klasor()) continue;
        if (secili.isEmpty()) return true;
        foreach (const QString &s, secili) if (o.ad == s || (s.endsWith('/') && o.ad.startsWith(s))) return true;
    }
    return false;
}

QVariantList Isci::zipListe(const QString &arsiv)
{
    QVariantList out;
    QList<ZipOge> ogeler;
    m_hata.clear();
    if (!Zip::listele(arsiv, &ogeler, &m_hata)) return out;
    foreach (const ZipOge &o, ogeler) {
        QVariantMap m;
        m["ad"] = o.ad;
        m["boyut"] = double(o.boyut);
        m["sBoyut"] = double(o.sBoyut);
        m["zaman"] = double(o.zaman);
        m["klasor"] = o.klasor();
        m["sifreli"] = o.sifreli();
        out << m;
    }
    return out;
}
