#include "kitap.h"
#include "zip.h"

#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QDateTime>
#include <QtCore/QTextCodec>
#include <QtCore/QRegExp>
#include <QtCore/QUrl>
#include <QtCore/QXmlStreamReader>
#include <QtCore/QHash>
#include <QtCore/QTime>
#include <QtGui/QImageReader>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkRequest>
#include <QtNetwork/QNetworkReply>

#define L1(s) QString::fromLatin1(s)

static QString temiz(const QString &p) { return QDir::cleanPath(QDir::fromNativeSeparators(p)); }

Kitap::Kitap(const QString &veri, QObject *parent)
    : QObject(parent), m_veri(veri), m_taraniyor(false), m_ustVeriSira(0), m_acikTxt(false),
      m_nam(new QNetworkAccessManager(this)), m_indirme(0), m_indirDosya(0), m_indirYon(0), m_iptal(false)
{
    QDir().mkpath(m_veri);
#if defined(Q_OS_SYMBIAN)
    m_onbellek = QDir(L1("E:/")).exists() ? L1("E:/BelleKitap/.onbellek") : m_veri + L1("/onbellek");
#else
    m_onbellek = m_veri + L1("/onbellek");
#endif
    QDir().mkpath(m_onbellek + L1("/kapak"));
    QFile g(m_veri + L1("/gunluk.txt"));
    if (g.open(QIODevice::ReadOnly)) {
        m_gunluk = QString::fromUtf8(g.readAll()).split('\n', QString::SkipEmptyParts);
        while (m_gunluk.size() > 150) m_gunluk.removeFirst();
    }
    // kutuphane onbellegi: satir basina yol \t baslik \t yazar \t kapak \t boyut \t tur
    QFile k(m_veri + L1("/kutuphane.tsv"));
    if (k.open(QIODevice::ReadOnly)) {
        foreach (const QString &s, QString::fromUtf8(k.readAll()).split('\n', QString::SkipEmptyParts)) {
            const QStringList p = s.split('\t');
            if (p.size() < 6 || !QFileInfo(p.at(0)).exists()) continue;
            QVariantMap m;
            m["yol"] = p.at(0); m["baslik"] = p.at(1); m["yazar"] = p.at(2); m["kapak"] = p.at(3); m["boyut"] = p.at(4).toDouble(); m["tur"] = p.at(5);
            m_kutuphane << m;
        }
    }
    m_tarama.setInterval(15);
    connect(&m_tarama, SIGNAL(timeout()), this, SLOT(taramaAdimi()));
}

void Kitap::kaydet()
{
    QFile k(m_veri + L1("/kutuphane.tsv"));
    if (!k.open(QIODevice::WriteOnly | QIODevice::Truncate)) return;
    foreach (const QVariant &v, m_kutuphane) {
        const QVariantMap m = v.toMap();
        QStringList p;
        p << m.value("yol").toString() << m.value("baslik").toString().replace('\t', ' ') << m.value("yazar").toString().replace('\t', ' ')
          << m.value("kapak").toString() << QString::number(m.value("boyut").toDouble(), 'f', 0) << m.value("tur").toString();
        k.write((p.join(L1("\t")) + L1("\n")).toUtf8());
    }
}

// ---------------- tarama ----------------

void Kitap::tara()
{
    if (m_taraniyor) return;
    m_taraniyor = true;
    m_kuyruk.clear();
    m_bulunan.clear();
    m_ustVeriSira = -1;
#if defined(Q_OS_SYMBIAN)
    if (QDir(L1("E:/Kitaplar")).exists()) m_kuyruk << L1("E:/Kitaplar");     // once kitap klasoru
    if (QDir(L1("E:/")).exists()) m_kuyruk << L1("E:/");
    if (QDir(L1("F:/")).exists()) m_kuyruk << L1("F:/");
    m_kuyruk << L1("C:/Data");
#else
    m_kuyruk << QDir::homePath();
#endif
    kayit(L1("tarama basladi"));
    emit taramaDegisti();
    m_tarama.start();
}

static bool atla(const QString &ad)
{
    const QString n = ad.toLower();
    return n.startsWith('.') || n == L1("private") || n == L1("sys") || n == L1("resource") || n == L1("system") || n == L1("shared")
        || n == L1("cache") || n == L1("thumbnails") || n == L1("_pagedtemp") || n == L1("images") || n == L1("videos") || n == L1("sounds")
        || n == L1("dcim") || n == L1("whatse6") || n == L1("podcasts") || n == L1("radyo kayitlari");
}

void Kitap::taramaAdimi()
{
    // 1) klasorler: her adimda ~40 ms boyunca toplu
    if (!m_kuyruk.isEmpty()) {
        QTime saat;
        saat.start();
        while (!m_kuyruk.isEmpty() && saat.elapsed() < 40) {
            const QString d = m_kuyruk.takeFirst();
            const bool kitapKlasoru = d.toLower().contains(L1("kitap")) || d.toLower().contains(L1("book"));
            QDir dir(d);
            foreach (const QFileInfo &fi, dir.entryInfoList(QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot)) {
                if (fi.isDir()) {
                    const QString alt = temiz(fi.absoluteFilePath());
                    if (!atla(fi.fileName()) && d.count('/') < 7 && alt.compare(L1("E:/Kitaplar"), Qt::CaseInsensitive) != 0) m_kuyruk << alt;
                    continue;
                }
                const QString uz = fi.suffix().toLower();
                const QString y = temiz(fi.absoluteFilePath());
                if ((uz == L1("epub") || (uz == L1("txt") && kitapKlasoru && fi.size() > 2048)) && !m_bulunan.contains(y)) m_bulunan << y;
            }
        }
        emit taramaIlerleme(m_bulunan.size());
        return;
    }
    // 2) ust veri (yeni kitaplar icin), adim basina bir kitap
    if (m_ustVeriSira < 0) {
        // var olanlari koru, silinmisleri at
        QVariantList yeni;
        QStringList bilinen;
        foreach (const QVariant &v, m_kutuphane) { const QString y = v.toMap().value("yol").toString(); if (m_bulunan.contains(y)) { yeni << v; bilinen << y; } }
        m_kutuphane = yeni;
        QStringList kalan;
        foreach (const QString &y, m_bulunan) if (!bilinen.contains(y)) kalan << y;
        m_bulunan = kalan;
        m_ustVeriSira = 0;
    }
    if (m_ustVeriSira < m_bulunan.size()) {
        m_kutuphane << ustVeri(m_bulunan.at(m_ustVeriSira++));
        emit taramaIlerleme(m_kutuphane.size());
        return;
    }
    m_tarama.stop();
    m_taraniyor = false;
    kaydet();
    kayit(QString(L1("tarama bitti: %1 kitap")).arg(m_kutuphane.size()));
    emit taramaDegisti();
    emit taramaBitti();
}

QByteArray Kitap::girdiOku(const QString &epub, const QString &ad)
{
    QList<ZipOge> l;
    QString h;
    if (!Zip::listele(epub, &l, &h)) return QByteArray();
    QFile f(epub);
    if (!f.open(QIODevice::ReadOnly)) return QByteArray();
    foreach (const ZipOge &o, l) {
        if (o.ad.compare(ad, Qt::CaseInsensitive) != 0) continue;
        const QString gecici = m_veri + L1("/gecici.bin");
        if (!Zip::ac(f, o, gecici, 0, &h)) return QByteArray();
        QFile g(gecici);
        QByteArray b;
        if (g.open(QIODevice::ReadOnly)) { b = g.readAll(); g.close(); }
        QFile::remove(gecici);
        return b;
    }
    return QByteArray();
}

static QString opfYolu(const QByteArray &container)
{
    QRegExp r(L1("full-path\\s*=\\s*[\"']([^\"']+)[\"']"));
    return r.indexIn(QString::fromUtf8(container)) >= 0 ? r.cap(1) : QString();
}

static QString hrefCoz(const QString &taban, const QString &href)
{
    QString h = QUrl::fromPercentEncoding(href.section('#', 0, 0).toUtf8());
    return temiz(taban.isEmpty() ? h : taban + L1("/") + h);
}

QVariantMap Kitap::ustVeri(const QString &yol)
{
    QVariantMap m;
    m["yol"] = yol;
    m["boyut"] = double(QFileInfo(yol).size());
    m["baslik"] = QFileInfo(yol).completeBaseName();
    m["yazar"] = QString();
    m["kapak"] = QString();
    m["tur"] = QFileInfo(yol).suffix().toLower();
    if (m["tur"] != L1("epub")) return m;
    const QString opf = opfYolu(girdiOku(yol, L1("META-INF/container.xml")));
    if (opf.isEmpty()) return m;
    const QByteArray x = girdiOku(yol, opf);
    const QString taban = QFileInfo(opf).path() == L1(".") ? QString() : QFileInfo(opf).path();
    QXmlStreamReader r(x);
    QString kapakId, kapakHref;
    QHash<QString, QString> idHref;
    while (!r.atEnd()) {
        r.readNext();
        if (!r.isStartElement()) continue;
        const QString ad = r.name().toString().toLower();
        if (ad == L1("title") && m["baslik"].toString() == QFileInfo(yol).completeBaseName()) { const QString t = r.readElementText().simplified(); if (!t.isEmpty()) m["baslik"] = t; }
        else if (ad == L1("creator") && m["yazar"].toString().isEmpty()) m["yazar"] = r.readElementText().simplified();
        else if (ad == L1("meta") && r.attributes().value(L1("name")).toString() == L1("cover")) kapakId = r.attributes().value(L1("content")).toString();
        else if (ad == L1("item")) {
            const QString id = r.attributes().value(L1("id")).toString(), href = r.attributes().value(L1("href")).toString();
            idHref.insert(id, href);
            if (r.attributes().value(L1("properties")).toString().contains(L1("cover-image"))) kapakHref = href;
        }
    }
    if (kapakHref.isEmpty() && !kapakId.isEmpty()) kapakHref = idHref.value(kapakId);
    if (!kapakHref.isEmpty()) {
        const QString giris = hrefCoz(taban, kapakHref);
        const QByteArray img = girdiOku(yol, giris);
        if (!img.isEmpty()) {
            const QString hedef = m_onbellek + L1("/kapak/") + QString::number(qHash(yol), 16) + L1(".") + (QFileInfo(giris).suffix().isEmpty() ? L1("jpg") : QFileInfo(giris).suffix().toLower());
            QFile f(hedef);
            if (f.open(QIODevice::WriteOnly)) { f.write(img); f.close(); m["kapak"] = hedef; }
        }
    }
    return m;
}

// ---------------- acma ----------------

QString Kitap::onbellekIcin(const QString &yol) const { return m_onbellek + L1("/k") + QString::number(qHash(yol + QString::number(QFileInfo(yol).size())), 16); }

bool Kitap::tamAc(const QString &epub, const QString &hedef, QString *hata)
{
    if (QFile::exists(hedef + L1("/.tamam"))) return true;
    QList<ZipOge> l;
    if (!Zip::listele(epub, &l, hata)) return false;
    QFile f(epub);
    if (!f.open(QIODevice::ReadOnly)) { *hata = QString::fromUtf8("Dosya açılamadı"); return false; }
    foreach (const ZipOge &o, l) {
        if (o.sifreli()) { *hata = QString::fromUtf8("Şifreli (DRM'li) EPUB açılamaz"); return false; }
        if (!Zip::ac(f, o, hedef + L1("/") + o.ad, 0, hata)) { if (!o.ad.toLower().endsWith(L1(".ttf")) && !o.ad.toLower().endsWith(L1(".otf"))) return false; hata->clear(); }
    }
    QFile t(hedef + L1("/.tamam"));
    t.open(QIODevice::WriteOnly);
    // onbellek kucuk kalsin: en yeni 6 kitap
    QDir d(m_onbellek);
    const QFileInfoList kl = d.entryInfoList(QStringList() << L1("k*"), QDir::Dirs | QDir::NoDotAndDotDot, QDir::Time);
    for (int i = 6; i < kl.size(); ++i) {
        QDir eski(kl.at(i).absoluteFilePath());
        foreach (const QFileInfo &fi, eski.entryInfoList(QDir::Files | QDir::Hidden | QDir::System)) QFile::remove(fi.absoluteFilePath());
        // alt klasorler: basit ozyinelemesiz temizlik (EPUB'lar en cok 3-4 duzey)
        QStringList yigin; yigin << eski.absolutePath();
        QStringList hepsi;
        while (!yigin.isEmpty()) { const QString y = yigin.takeFirst(); hepsi.prepend(y); foreach (const QFileInfo &a, QDir(y).entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot)) yigin << a.absoluteFilePath(); }
        foreach (const QString &y, hepsi) { foreach (const QFileInfo &fi, QDir(y).entryInfoList(QDir::Files | QDir::Hidden | QDir::System)) QFile::remove(fi.absoluteFilePath()); QDir().rmdir(y); }
    }
    return true;
}

bool Kitap::epubCoz(const QString &epub, const QString &kok, QVariantMap *bilgi, QStringList *spine, QVariantList *icindekiler, QString *hata)
{
    QFile c(kok + L1("/META-INF/container.xml"));
    if (!c.open(QIODevice::ReadOnly)) { *hata = QString::fromUtf8("container.xml yok (EPUB değil mi?)"); return false; }
    const QString opf = opfYolu(c.readAll());
    QFile o(kok + L1("/") + opf);
    if (opf.isEmpty() || !o.open(QIODevice::ReadOnly)) { *hata = QString::fromUtf8("OPF bulunamadı"); return false; }
    const QString taban = QFileInfo(kok + L1("/") + opf).absolutePath();
    QXmlStreamReader r(o.readAll());
    QHash<QString, QString> idHref, idTur, idOz;
    QStringList sira;
    QString ncxId, baslik, yazar;
    while (!r.atEnd()) {
        r.readNext();
        if (!r.isStartElement()) continue;
        const QString ad = r.name().toString().toLower();
        const QXmlStreamAttributes a = r.attributes();
        if (ad == L1("title") && baslik.isEmpty()) baslik = r.readElementText().simplified();
        else if (ad == L1("creator") && yazar.isEmpty()) yazar = r.readElementText().simplified();
        else if (ad == L1("item")) { const QString id = a.value(L1("id")).toString(); idHref.insert(id, a.value(L1("href")).toString()); idTur.insert(id, a.value(L1("media-type")).toString()); idOz.insert(id, a.value(L1("properties")).toString()); }
        else if (ad == L1("spine")) ncxId = a.value(L1("toc")).toString();
        else if (ad == L1("itemref") && a.value(L1("linear")).toString() != L1("no")) sira << a.value(L1("idref")).toString();
    }
    spine->clear();
    foreach (const QString &id, sira) if (idHref.contains(id)) *spine << hrefCoz(taban, idHref.value(id));
    if (spine->isEmpty()) { *hata = QString::fromUtf8("Kitapta okunacak bölüm yok"); return false; }
    (*bilgi)["baslik"] = baslik.isEmpty() ? QFileInfo(epub).completeBaseName() : baslik;
    (*bilgi)["yazar"] = yazar;

    // icindekiler: once EPUB3 nav, yoksa NCX
    icindekiler->clear();
    QString navHref, ncxHref = idHref.value(ncxId);
    for (QHash<QString, QString>::const_iterator it = idOz.constBegin(); it != idOz.constEnd(); ++it) if (it.value().contains(L1("nav"))) navHref = idHref.value(it.key());
    if (ncxHref.isEmpty()) for (QHash<QString, QString>::const_iterator it = idTur.constBegin(); it != idTur.constEnd(); ++it) if (it.value().contains(L1("ncx"))) ncxHref = idHref.value(it.key());
    QHash<QString, int> dosyaSira;
    for (int i = 0; i < spine->size(); ++i) dosyaSira.insert(spine->at(i).toLower(), i);
    if (!ncxHref.isEmpty()) {
        const QString ncx = hrefCoz(taban, ncxHref);
        QFile f(ncx);
        if (f.open(QIODevice::ReadOnly)) {
            const QString ncxTaban = QFileInfo(ncx).absolutePath();
            QXmlStreamReader n(f.readAll());
            int derinlik = 0;
            QString etiket;
            while (!n.atEnd()) {
                n.readNext();
                const QString ad = n.name().toString().toLower();
                if (n.isStartElement() && ad == L1("navpoint")) { ++derinlik; etiket.clear(); }
                else if (n.isEndElement() && ad == L1("navpoint")) --derinlik;
                else if (n.isStartElement() && ad == L1("text") && etiket.isEmpty()) etiket = n.readElementText().simplified();
                else if (n.isStartElement() && ad == L1("content")) {
                    const QString src = hrefCoz(ncxTaban, n.attributes().value(L1("src")).toString()).toLower();
                    if (!dosyaSira.contains(src) || etiket.isEmpty()) continue;
                    QVariantMap m; m["baslik"] = etiket; m["bolum"] = dosyaSira.value(src); m["derinlik"] = qMax(0, derinlik - 1);
                    *icindekiler << m;
                }
            }
        }
    }
    if (icindekiler->isEmpty() && !navHref.isEmpty()) {
        const QString nav = hrefCoz(taban, navHref);
        QFile f(nav);
        if (f.open(QIODevice::ReadOnly)) {
            const QString navTaban = QFileInfo(nav).absolutePath();
            QXmlStreamReader n(f.readAll());
            int derinlik = 0;
            bool tocta = false;
            while (!n.atEnd()) {
                n.readNext();
                const QString ad = n.name().toString().toLower();
                if (n.isStartElement() && ad == L1("nav")) tocta = n.attributes().value(L1("http://www.idpf.org/2007/ops"), L1("type")).toString() == L1("toc") || n.attributes().value(L1("epub:type")).toString() == L1("toc");
                else if (n.isEndElement() && ad == L1("nav")) tocta = false;
                else if (!tocta) continue;
                else if (n.isStartElement() && ad == L1("ol")) ++derinlik;
                else if (n.isEndElement() && ad == L1("ol")) --derinlik;
                else if (n.isStartElement() && ad == L1("a")) {
                    const QString src = hrefCoz(navTaban, n.attributes().value(L1("href")).toString()).toLower();
                    const QString etiket = n.readElementText(QXmlStreamReader::IncludeChildElements).simplified();
                    if (!dosyaSira.contains(src) || etiket.isEmpty()) continue;
                    QVariantMap m; m["baslik"] = etiket; m["bolum"] = dosyaSira.value(src); m["derinlik"] = qMax(0, derinlik - 1);
                    *icindekiler << m;
                }
            }
        }
    }
    return true;
}

QVariantMap Kitap::ac(const QString &yol)
{
    QVariantMap s;
    s["ok"] = false;
    if (!QFileInfo(yol).exists()) { s["hata"] = QString::fromUtf8("Dosya bulunamadı"); return s; }
    m_acikYol = yol;
    m_spine.clear();
    m_bolumAdlari.clear();
    QVariantList icindekiler;
    m_acikTxt = QFileInfo(yol).suffix().toLower() == L1("txt");
    if (m_acikTxt) {
        m_spine << yol;
        s["baslik"] = QFileInfo(yol).completeBaseName();
        s["yazar"] = QString();
        QVariantMap m; m["baslik"] = s["baslik"]; m["bolum"] = 0; m["derinlik"] = 0;
        icindekiler << m;
    } else {
        QString hata;
        m_acikKok = onbellekIcin(yol);
        QDir().mkpath(m_acikKok);
        if (!tamAc(yol, m_acikKok, &hata)) { s["hata"] = hata; kayit("acilamadi " + yol + ": " + hata); return s; }
        QVariantMap bilgi;
        if (!epubCoz(yol, m_acikKok, &bilgi, &m_spine, &icindekiler, &hata)) { s["hata"] = hata; kayit("cozulemedi " + yol + ": " + hata); return s; }
        s["baslik"] = bilgi.value("baslik");
        s["yazar"] = bilgi.value("yazar");
    }
    // bolum adlari: icindekilerden (her bolum icin ilk girdi), yoksa "Bolum N"
    for (int i = 0; i < m_spine.size(); ++i) m_bolumAdlari << QString();
    foreach (const QVariant &v, icindekiler) { const QVariantMap m = v.toMap(); const int b = m.value("bolum").toInt(); if (b >= 0 && b < m_bolumAdlari.size() && m_bolumAdlari.at(b).isEmpty()) m_bolumAdlari[b] = m.value("baslik").toString(); }
    if (icindekiler.isEmpty()) for (int i = 0; i < m_spine.size(); ++i) { QVariantMap m; m["baslik"] = QString::fromUtf8("Bölüm %1").arg(i + 1); m["bolum"] = i; m["derinlik"] = 0; icindekiler << m; }
    s["ok"] = true;
    s["bolumSayisi"] = m_spine.size();
    s["icindekiler"] = icindekiler;
    kayit(QString(L1("acildi: %1 (%2 bolum, %3 icindekiler)")).arg(s["baslik"].toString()).arg(m_spine.size()).arg(icindekiler.size()));
    return s;
}

QString Kitap::bolumBasligi(int i) const { return i >= 0 && i < m_bolumAdlari.size() ? m_bolumAdlari.at(i) : QString(); }

// ---------------- bolumu sade HTML'e cevir ----------------

static QString metinCoz(const QByteArray &b)
{
    QRegExp enc(L1("encoding\\s*=\\s*[\"']([A-Za-z0-9_\\-]+)[\"']"));
    QRegExp cs(L1("charset\\s*=\\s*[\"']?([A-Za-z0-9_\\-]+)"));
    const QString bas = QString::fromLatin1(b.left(1024));
    QByteArray ad;
    if (enc.indexIn(bas) >= 0) ad = enc.cap(1).toLatin1(); else if (cs.indexIn(bas) >= 0) ad = cs.cap(1).toLatin1();
    QTextCodec *c = ad.isEmpty() ? 0 : QTextCodec::codecForName(ad);
    if (c && ad.toLower() != "utf-8") return c->toUnicode(b);
    const QString u = QString::fromUtf8(b);
    if (!u.contains(QChar(0xFFFD))) return u;
    QTextCodec *tr = QTextCodec::codecForName("windows-1254");
    return tr ? tr->toUnicode(b) : QString::fromLatin1(b);
}

static QString kacis(const QString &s) { QString t = s; t.replace('&', L1("&amp;")).replace('<', L1("&lt;")).replace('>', L1("&gt;")); return t; }

static QStringList parcala(const QString &html, int sinir)
{
    QStringList out;
    int bas = 0;
    while (bas < html.length()) {
        if (html.length() - bas <= sinir) { out << html.mid(bas); break; }
        // paragraf ya da blok sonunda kes (bit: kesimin bittigi yer, haric)
        const int kp = html.indexOf(L1("</p>"), bas + sinir), kd = html.indexOf(L1("</div>"), bas + sinir);
        int bit;
        if (kp >= 0 && (kd < 0 || kp <= kd) && kp - bas <= sinir * 2) bit = kp + 4;
        else if (kd >= 0 && kd - bas <= sinir * 2) bit = kd + 6;
        else { const int k = html.indexOf('>', bas + sinir); bit = k < 0 ? html.length() : k + 1; }
        out << html.mid(bas, bit - bas);
        bas = bit;
    }
    if (out.isEmpty()) out << QString();
    return out;
}

QStringList Kitap::bolum(int i, int genislik)
{
    if (i < 0 || i >= m_spine.size()) return QStringList() << QString();
    QFile f(m_spine.at(i));
    if (!f.open(QIODevice::ReadOnly)) return QStringList() << QString::fromUtf8("<p>Bölüm okunamadı.</p>");
    QString h = metinCoz(f.readAll());
    if (m_acikTxt) {
        // duz metin: bos satirla ayrilmis paragraflar
        h.replace(L1("\r\n"), L1("\n"));
        QStringList pl = h.split(QRegExp(L1("\\n\\s*\\n")), QString::SkipEmptyParts);
        QString out;
        foreach (const QString &p, pl) out += L1("<p>") + kacis(p.trimmed()).replace('\n', L1("<br>")) + L1("</p>");
        return parcala(out, 24000);
    }
    const QString klasor = QFileInfo(m_spine.at(i)).absolutePath();
    // govde
    QRegExp govde(L1("<body[^>]*>(.*)</body>"), Qt::CaseInsensitive);
    if (govde.indexIn(h) >= 0) h = govde.cap(1);
    QRegExp sil(L1("<(script|style|head)[^>]*>.*</\\1>"), Qt::CaseInsensitive);
    sil.setMinimal(true);
    h.remove(sil);
    QRegExp yorum(L1("<!--.*-->"));
    yorum.setMinimal(true);
    h.remove(yorum);
    // etiketleri sadelestir
    static QStringList koru;
    if (koru.isEmpty()) koru << L1("p") << L1("br") << L1("h1") << L1("h2") << L1("h3") << L1("h4") << L1("h5") << L1("h6") << L1("b") << L1("strong")
                             << L1("i") << L1("em") << L1("u") << L1("sub") << L1("sup") << L1("ul") << L1("ol") << L1("li") << L1("blockquote")
                             << L1("pre") << L1("code") << L1("table") << L1("tr") << L1("td") << L1("th") << L1("hr") << L1("small") << L1("big") << L1("center") << L1("dl") << L1("dt") << L1("dd");
    static QStringList blok;
    if (blok.isEmpty()) blok << L1("div") << L1("section") << L1("article") << L1("figure") << L1("figcaption") << L1("aside") << L1("header") << L1("footer") << L1("main") << L1("nav");
    QRegExp etiket(L1("<(/?)([a-zA-Z][a-zA-Z0-9:]*)([^>]*)>"));
    QRegExp src(L1("(?:src|xlink:href|href)\\s*=\\s*[\"']([^\"']+)[\"']"), Qt::CaseInsensitive);
    QString out;
    out.reserve(h.length());
    int p = 0, son = 0;
    while ((p = etiket.indexIn(h, p)) >= 0) {
        out += h.mid(son, p - son);
        const bool kapa = !etiket.cap(1).isEmpty();
        QString ad = etiket.cap(2).toLower();
        const int ik = ad.indexOf(':');
        if (ik >= 0) ad = ad.mid(ik + 1);
        const QString nit = etiket.cap(3);
        if (koru.contains(ad)) out += L1("<") + (kapa ? L1("/") : QString()) + ad + L1(">");
        else if (blok.contains(ad)) out += kapa ? L1("</div>") : L1("<div>");
        else if ((ad == L1("img") || ad == L1("image")) && !kapa && src.indexIn(nit) >= 0) {
            const QString yol = temiz(klasor + L1("/") + QUrl::fromPercentEncoding(src.cap(1).toUtf8()));
            QSize boy = QImageReader(yol).size();
            if (boy.isValid() && boy.width() > 0) {
                if (boy.width() > genislik) boy = QSize(genislik, boy.height() * genislik / boy.width());
                out += QString(L1("<p align=\"center\"><img src=\"%1\" width=\"%2\" height=\"%3\"></p>")).arg(QUrl::fromLocalFile(yol).toString()).arg(boy.width()).arg(boy.height());
            }
        }
        son = p + etiket.matchedLength();
        p = son;
    }
    out += h.mid(son);
    // bos bloklari ve fazla bosluklari sadelestir
    out.replace(QRegExp(L1("(<div>\\s*</div>)+")), QString());
    out.replace(QRegExp(L1("\\s{2,}")), L1(" "));
    return parcala(out, 24000);
}

// ---------------- cevrimici ----------------

static const char *KAjan = "Mozilla/5.0 (Symbian/3; NokiaE6-00) BelleKitap/0.2";

QString Kitap::kitapKlasoru() const
{
#if defined(Q_OS_SYMBIAN)
    return QDir(L1("E:/")).exists() ? L1("E:/Kitaplar") : L1("C:/Data/Kitaplar");
#else
    return m_veri + L1("/Kitaplar");
#endif
}

QString Kitap::guvenliAd(const QString &ad) const
{
    QString s = ad;
    s.replace(QRegExp(L1("[\\\\/:*?\"<>|\\r\\n\\t]")), L1(" "));
    s = s.simplified();
    if (s.length() > 70) s = s.left(70).trimmed();
    return s.isEmpty() ? L1("kitap") : s;
}

void Kitap::getir(const QString &id, const QString &url) { getirAt(QUrl::fromEncoded(url.toUtf8()), id, 0); }

void Kitap::getirAt(const QUrl &u, const QString &id, int yon)
{
    QNetworkRequest r(u);
    r.setRawHeader("User-Agent", KAjan);
    QNetworkReply *rep = m_nam->get(r);
    rep->setProperty("id", id);
    rep->setProperty("yon", yon);
    connect(rep, SIGNAL(finished()), this, SLOT(getirBitti()));
}

void Kitap::getirBitti()
{
    QNetworkReply *r = qobject_cast<QNetworkReply *>(sender());
    if (!r) return;
    r->deleteLater();
    const int kod = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QUrl yon = r->attribute(QNetworkRequest::RedirectionTargetAttribute).toUrl();
    if (!yon.isEmpty() && r->property("yon").toInt() < 6) { getirAt(r->url().resolved(yon), r->property("id").toString(), r->property("yon").toInt() + 1); return; }
    QString hata;
    if (r->error() != QNetworkReply::NoError || kod >= 400) hata = kod >= 400 ? QString(L1("HTTP %1")).arg(kod) : r->errorString();
    emit metinGeldi(r->property("id").toString(), hata.isEmpty() ? QString::fromUtf8(r->readAll()) : QString(), hata);
}

bool Kitap::indir(const QString &url, const QString &yol)
{
    if (m_indirme) return false;
    QDir().mkpath(QFileInfo(yol).absolutePath());
    m_indirYol = yol;
    m_indirDosya = new QFile(yol + L1(".part"), this);
    if (!m_indirDosya->open(QIODevice::WriteOnly | QIODevice::Truncate)) { delete m_indirDosya; m_indirDosya = 0; emit indirmeBitti(false, yol, QString::fromUtf8("Dosya yazılamadı")); return false; }
    m_indirYon = 0;
    m_iptal = false;
    indirAt(QUrl::fromEncoded(url.toUtf8()));
    emit indirmeDegisti();
    kayit(L1("indirme: ") + yol);
    return true;
}

void Kitap::indirAt(const QUrl &u)
{
    QNetworkRequest r(u);
    r.setRawHeader("User-Agent", KAjan);
    m_indirme = m_nam->get(r);
    connect(m_indirme, SIGNAL(readyRead()), this, SLOT(indirOku()));
    connect(m_indirme, SIGNAL(downloadProgress(qint64,qint64)), this, SLOT(indirIlerle(qint64,qint64)));
    connect(m_indirme, SIGNAL(finished()), this, SLOT(indirBitti()));
}

void Kitap::indirOku()
{
    if (!m_indirme || !m_indirDosya) return;
    const int kod = m_indirme->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (kod >= 300 && kod < 400) { m_indirme->readAll(); return; }
    m_indirDosya->write(m_indirme->readAll());
}

void Kitap::indirIlerle(qint64 a, qint64 t) { emit indirmeIlerleme(double(a), double(t)); }

void Kitap::indirmeIptal() { if (m_indirme) { m_iptal = true; m_indirme->abort(); } }

void Kitap::indirBitti()
{
    QNetworkReply *r = m_indirme;
    if (!r) return;
    r->deleteLater();
    const int kod = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QUrl yon = r->attribute(QNetworkRequest::RedirectionTargetAttribute).toUrl();
    if (!m_iptal && !yon.isEmpty() && ++m_indirYon <= 8) { m_indirDosya->resize(0); m_indirDosya->seek(0); indirAt(r->url().resolved(yon)); return; }
    m_indirme = 0;
    m_indirDosya->close();
    const bool ok = !m_iptal && r->error() == QNetworkReply::NoError && kod >= 200 && kod < 300 && m_indirDosya->size() > 512;
    QString hata;
    if (ok) { QFile::remove(m_indirYol); QFile::rename(m_indirYol + L1(".part"), m_indirYol); }
    else { m_indirDosya->remove(); hata = m_iptal ? QString::fromUtf8("İptal edildi") : (kod ? QString(L1("HTTP %1")).arg(kod) : r->errorString()); }
    delete m_indirDosya;
    m_indirDosya = 0;
    kayit(QString(L1("indirme %1: %2 %3")).arg(ok ? L1("tamam") : L1("olmadi")).arg(m_indirYol).arg(hata));
    emit indirmeDegisti();
    emit indirmeBitti(ok, m_indirYol, hata);
}

bool Kitap::metinKaydet(const QString &yol, const QString &metin)
{
    QDir().mkpath(QFileInfo(yol).absolutePath());
    QFile f(yol);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) return false;
    f.write(metin.toUtf8());
    return true;
}

QVariantMap Kitap::kitapEkle(const QString &yol)
{
    for (int i = 0; i < m_kutuphane.size(); ++i) if (m_kutuphane.at(i).toMap().value("yol").toString() == yol) m_kutuphane.removeAt(i--);
    const QVariantMap m = ustVeri(temiz(yol));
    m_kutuphane.prepend(m);
    kaydet();
    return m;
}

// ---------------- yardimcilar ----------------

bool Kitap::dosyaVar(const QString &yol) const { return QFileInfo(yol).exists(); }
bool Kitap::dosyaSil(const QString &yol) { return QFile::remove(yol); }

void Kitap::kayit(const QString &s)
{
    m_gunluk << QDateTime::currentDateTime().toString(L1("dd.MM HH:mm:ss ")) + s;
    while (m_gunluk.size() > 150) m_gunluk.removeFirst();
    QFile g(m_veri + L1("/gunluk.txt"));
    if (g.open(QIODevice::WriteOnly | QIODevice::Truncate)) g.write((m_gunluk.join(L1("\n")) + L1("\n")).toUtf8());
}

QString Kitap::gunluk() const { return m_gunluk.join(L1("\n")); }

void Kitap::zamanla(const QString &ad, int ms)
{
    QTimer *t = new QTimer(this);
    t->setSingleShot(true);
    t->setObjectName(ad);
    connect(t, SIGNAL(timeout()), this, SLOT(zamanTik()));
    t->start(qMax(1, ms));
}

void Kitap::zamanTik()
{
    QTimer *t = qobject_cast<QTimer *>(sender());
    if (!t) return;
    const QString ad = t->objectName();
    t->deleteLater();
    emit zamanDoldu(ad);
}
