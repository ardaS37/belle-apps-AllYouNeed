#include "tl.h"
#include "sifre.h"
#include <QtCore/QFile>
#include <QtCore/QStringList>
#include <QtCore/QDebug>
#include <string.h>

static const quint32 KVektor = 0x1cb5c415;
static const quint32 KBoolDogru = 0x997275b5;
static const quint32 KBoolYanlis = 0xbc799737;
static const quint32 KGzip = 0x3072cfa1;

// ======================================================================= yazici / okuyucu
void TlYazici::bayt(const QByteArray &b)
{
    const int n = b.size();
    int bas;
    if (n < 254) { veri.append(char(n)); bas = 1; }
    else { veri.append(char(254)); veri.append(char(n & 0xff)); veri.append(char((n >> 8) & 0xff)); veri.append(char((n >> 16) & 0xff)); bas = 4; }
    veri.append(b);
    const int top = bas + n;
    if (top % 4) veri.append(QByteArray(4 - top % 4, 0));
}

qint32 TlOkuyucu::int32()
{
    if (konum + 4 > veri.size()) { hata = true; konum = veri.size(); return 0; }
    qint32 v;
    memcpy(&v, veri.constData() + konum, 4);
    konum += 4;
    return v;
}

qint64 TlOkuyucu::int64()
{
    if (konum + 8 > veri.size()) { hata = true; konum = veri.size(); return 0; }
    qint64 v;
    memcpy(&v, veri.constData() + konum, 8);
    konum += 8;
    return v;
}

double TlOkuyucu::cift()
{
    if (konum + 8 > veri.size()) { hata = true; konum = veri.size(); return 0; }
    double v;
    memcpy(&v, veri.constData() + konum, 8);
    konum += 8;
    return v;
}

QByteArray TlOkuyucu::ham(int n)
{
    if (n < 0 || konum + n > veri.size()) { hata = true; konum = veri.size(); return QByteArray(); }
    const QByteArray r = veri.mid(konum, n);
    konum += n;
    return r;
}

QByteArray TlOkuyucu::bayt()
{
    if (konum >= veri.size()) { hata = true; return QByteArray(); }
    int n = uchar(veri.at(konum));
    int bas = 1;
    if (n == 254) {
        if (konum + 4 > veri.size()) { hata = true; return QByteArray(); }
        n = uchar(veri.at(konum + 1)) | (uchar(veri.at(konum + 2)) << 8) | (uchar(veri.at(konum + 3)) << 16);
        bas = 4;
    }
    konum += bas;
    const QByteArray r = ham(n);
    const int top = bas + n;
    if (top % 4) konum += 4 - top % 4;
    if (konum > veri.size()) { hata = true; konum = veri.size(); }
    return r;
}

// ======================================================================= sema
TlSema &TlSema::tek()
{
    static TlSema s;
    return s;
}

TlSema::TlSema() : m_katman(0)
{
    yukle();
}

QByteArray TlSema::ic(const QByteArray &s)
{
    QHash<QByteArray, QByteArray>::const_iterator it = m_ic.constFind(s);
    if (it != m_ic.constEnd()) return it.value();
    m_ic.insert(s, s);
    return s;
}

void TlSema::yukle()
{
    QFile f(QString::fromLatin1(":/tl/sema.txt"));
    if (!f.open(QIODevice::ReadOnly)) { sonHata = QString::fromLatin1("sema.txt acilamadi"); return; }
    const QByteArray tum = f.readAll();
    int bas = 0;
    while (bas < tum.size()) {
        int son = tum.indexOf('\n', bas);
        if (son < 0) son = tum.size();
        const QByteArray satir = tum.mid(bas, son - bas).trimmed();
        bas = son + 1;
        if (satir.isEmpty()) continue;
        if (satir.startsWith("LAYER ")) { m_katman = satir.mid(6).toInt(); continue; }
        const QList<QByteArray> p = satir.split(' ');
        if (p.size() < 5) continue;
        bool ok = false;
        Tanim *t = new Tanim;
        t->id = p[0].toUInt(&ok, 16);
        t->ad = p[1];
        t->fonk = p[2] == "f";
        t->tur = ic(p[4]);
        if (p[3] != "-") {
            const QList<QByteArray> ps = p[3].split(';');
            for (int i = 0; i < ps.size(); ++i) {
                const int iki = ps[i].indexOf(':');
                if (iki < 0) continue;
                Param pr;
                pr.ad = ic(ps[i].left(iki));
                QByteArray tr = ps[i].mid(iki + 1);
                pr.flagAlan = -1; pr.flagBit = 0;
                const int soru = tr.indexOf('?');
                if (soru > 0) {
                    const QByteArray kosul = tr.left(soru);      // flags.3 / flags2.0
                    tr = tr.mid(soru + 1);
                    const int nokta = kosul.indexOf('.');
                    const QByteArray alan = kosul.left(nokta);
                    pr.flagBit = kosul.mid(nokta + 1).toInt();
                    for (int k = 0; k < t->par.size(); ++k) if (t->par[k].ad == alan) { pr.flagAlan = k; break; }
                }
                pr.tur = ic(tr);
                t->par.append(pr);
            }
        }
        // ayni kimlik iki kez olabilir (mtproto.tl'de resPQ): ilki kalsin
        if (!t->fonk && !m_id.contains(t->id)) m_id.insert(t->id, t);
        if (t->fonk && !m_id.contains(t->id)) m_id.insert(t->id, t);
        if (!m_ad.contains(t->ad)) m_ad.insert(t->ad, t);
    }
    m_ic.clear();
}

// ======================================================================= okuma
static bool kucukHarf(const QByteArray &t) { return !t.isEmpty() && t.at(0) >= 'a' && t.at(0) <= 'z'; }

QVariant TlSema::oku(TlOkuyucu &r, const QByteArray &tur) const
{
    if (r.hata) return QVariant();
    if (tur == "int") return r.int32();
    if (tur == "long") return qlonglong(r.int64());
    if (tur == "string") return r.dize();
    if (tur == "bytes") return r.bayt();
    if (tur == "double") return r.cift();
    if (tur == "int128") return r.ham(16);
    if (tur == "int256") return r.ham(32);
    if (tur == "#") return uint(r.uint32());
    if (tur == "true") return true;
    if (tur == "Bool") {
        const quint32 id = r.uint32();
        if (id == KBoolDogru) return true;
        if (id == KBoolYanlis) return false;
        r.hata = true;
        return QVariant();
    }
    if (tur.startsWith("Vector<") || tur.startsWith("vector<")) {
        const bool kutulu = tur.at(0) == 'V';
        QByteArray ic = tur.mid(7, tur.size() - 8);
        if (kutulu) {
            const quint32 id = r.uint32();
            if (id == KGzip) {
                TlOkuyucu z(Sifre::gzipAc(r.bayt()));
                z.konum = 0;
                // gzip icindeki vektor: kimligi yeniden oku
                const QVariant v = oku(z, tur);
                if (z.hata) r.hata = true;
                return v;
            }
            if (id != KVektor) { r.hata = true; return QVariant(); }
        }
        const qint32 n = r.int32();
        if (n < 0 || n > 1000000) { r.hata = true; return QVariant(); }
        QVariantList l;
        // bare oge: "%Tur" ya da kucuk harfli constructor adi (future_salt)
        const Tanim *bare = 0;
        if (ic.startsWith('%')) ic = ic.mid(1);
        if (kucukHarf(ic) && ic != "int" && ic != "long" && ic != "string" && ic != "bytes" && ic != "double"
            && ic != "int128" && ic != "int256") bare = adIle(ic);
        for (qint32 i = 0; i < n && !r.hata; ++i) l.append(bare ? govdeOku(r, bare) : oku(r, ic));
        return l;
    }
    // kutulu nesne (Object, User, messages.Dialogs ...) ya da genel X
    return nesneOku(r);
}

QVariant TlSema::nesneOku(TlOkuyucu &r) const
{
    const quint32 id = r.uint32();
    if (r.hata) return QVariant();
    if (id == KBoolDogru) return true;
    if (id == KBoolYanlis) return false;
    if (id == KGzip) {
        TlOkuyucu z(Sifre::gzipAc(r.bayt()));
        if (z.veri.isEmpty()) { r.hata = true; return QVariant(); }
        const QVariant v = nesneOku(z);
        if (z.hata) r.hata = true;
        return v;
    }
    if (id == KVektor) {
        // turu bilinmeyen vektor (Object icinde): ogeler kutulu nesne kabul edilir
        const qint32 n = r.int32();
        if (n < 0 || n > 1000000) { r.hata = true; return QVariant(); }
        QVariantList l;
        for (qint32 i = 0; i < n && !r.hata; ++i) l.append(nesneOku(r));
        return l;
    }
    const Tanim *t = idIle(id);
    if (!t) {
        r.hata = true;
        const_cast<TlSema *>(this)->sonHata = QString::fromLatin1("bilinmeyen kimlik 0x%1").arg(id, 8, 16, QLatin1Char('0'));
        return QVariant();
    }
    return govdeOku(r, t);
}

QVariant TlSema::govdeOku(TlOkuyucu &r, const Tanim *t) const
{
    QVariantMap m;
    m.insert(QString::fromLatin1("_"), QString::fromLatin1(t->ad));
    QVector<quint32> bayrak(t->par.size(), 0);
    for (int i = 0; i < t->par.size() && !r.hata; ++i) {
        const Param &p = t->par[i];
        if (p.flagAlan >= 0) {
            if (!((bayrak[p.flagAlan] >> p.flagBit) & 1)) continue;
            if (p.tur == "true") { m.insert(QString::fromLatin1(p.ad), true); continue; }
        }
        if (p.tur == "#") {
            bayrak[i] = r.uint32();
            m.insert(QString::fromLatin1(p.ad), uint(bayrak[i]));
            continue;
        }
        m.insert(QString::fromLatin1(p.ad), oku(r, p.tur));
    }
    return m;
}

// ======================================================================= yazma
bool TlSema::yaz(TlYazici &w, const QVariant &v, const QByteArray &tur) const
{
    if (tur == "int") { w.int32(v.toInt()); return true; }
    if (tur == "long") { w.int64(v.toLongLong()); return true; }
    if (tur == "double") { w.cift(v.toDouble()); return true; }
    if (tur == "string") {
        if (v.type() == QVariant::ByteArray) w.bayt(v.toByteArray()); else w.dize(v.toString());
        return true;
    }
    if (tur == "bytes") {
        if (v.type() == QVariant::String) w.bayt(v.toString().toUtf8()); else w.bayt(v.toByteArray());
        return true;
    }
    if (tur == "int128" || tur == "int256") {
        const int n = tur == "int128" ? 16 : 32;
        QByteArray b = v.toByteArray();
        if (b.size() < n) b.append(QByteArray(n - b.size(), 0));
        w.ham(b.left(n));
        return true;
    }
    if (tur == "true") return true;
    if (tur == "Bool") { w.uint32(v.toBool() ? KBoolDogru : KBoolYanlis); return true; }
    if (tur == "!X") { w.ham(v.toByteArray()); return true; }
    if (tur.startsWith("Vector<") || tur.startsWith("vector<")) {
        if (tur.at(0) == 'V') w.uint32(KVektor);
        const QByteArray ic = tur.mid(7, tur.size() - 8);
        const QVariantList l = v.toList();
        w.int32(l.size());
        for (int i = 0; i < l.size(); ++i) if (!yaz(w, l[i], ic)) return false;
        return true;
    }
    if (v.type() == QVariant::ByteArray) { w.ham(v.toByteArray()); return true; }   // onceden serilestirilmis
    return nesneYaz(w, v.toMap());
}

bool TlSema::nesneYaz(TlYazici &w, const QVariantMap &m) const
{
    const QByteArray ad = m.value(QString::fromLatin1("_")).toString().toLatin1();
    const Tanim *t = adIle(ad);
    if (!t) { const_cast<TlSema *>(this)->sonHata = QString::fromLatin1("bilinmeyen ad: ") + QString::fromLatin1(ad); return false; }
    w.uint32(t->id);
    QVector<quint32> bayrak(t->par.size(), 0);
    for (int i = 0; i < t->par.size(); ++i) {
        const Param &p = t->par[i];
        if (p.flagAlan < 0) continue;
        const QVariant d = m.value(QString::fromLatin1(p.ad));
        const bool var = p.tur == "true" ? d.toBool() : (d.isValid() && !d.isNull());
        if (var) bayrak[p.flagAlan] |= (1u << p.flagBit);
    }
    for (int i = 0; i < t->par.size(); ++i) {
        const Param &p = t->par[i];
        if (p.tur == "#") { w.uint32(bayrak[i] | m.value(QString::fromLatin1(p.ad)).toUInt()); continue; }
        if (p.flagAlan >= 0 && !((bayrak[p.flagAlan] >> p.flagBit) & 1)) continue;
        if (!yaz(w, m.value(QString::fromLatin1(p.ad)), p.tur)) return false;
    }
    return true;
}

QByteArray TlSema::cagri(const QString &ad, const QVariantMap &param, QByteArray *sonucTuru) const
{
    QVariantMap m = param;
    m.insert(QString::fromLatin1("_"), ad);
    TlYazici w;
    if (!nesneYaz(w, m)) return QByteArray();
    if (sonucTuru) {
        const Tanim *t = adIle(ad.toLatin1());
        *sonucTuru = t ? t->tur : QByteArray("Object");
    }
    return w.veri;
}

// ======================================================================= metin
QString tlMetin(const QVariant &v, int d)
{
    const QString girinti(d * 2, QLatin1Char(' '));
    if (v.type() == QVariant::Map) {
        const QVariantMap m = v.toMap();
        QString s = m.value(QString::fromLatin1("_")).toString() + QString::fromLatin1(" {\n");
        for (QVariantMap::const_iterator it = m.constBegin(); it != m.constEnd(); ++it) {
            if (it.key() == QString::fromLatin1("_")) continue;
            s += girinti + QString::fromLatin1("  ") + it.key() + QString::fromLatin1(": ") + tlMetin(it.value(), d + 1) + QLatin1Char('\n');
        }
        return s + girinti + QLatin1Char('}');
    }
    if (v.type() == QVariant::List) {
        const QVariantList l = v.toList();
        QString s = QString::fromLatin1("[%1]").arg(l.size());
        for (int i = 0; i < l.size() && i < 8; ++i) s += QLatin1Char('\n') + girinti + QString::fromLatin1("  - ") + tlMetin(l[i], d + 1);
        if (l.size() > 8) s += QLatin1Char('\n') + girinti + QString::fromLatin1("  ...");
        return s;
    }
    if (v.type() == QVariant::ByteArray) return QString::fromLatin1("<%1 bayt>").arg(v.toByteArray().size());
    return v.toString();
}
