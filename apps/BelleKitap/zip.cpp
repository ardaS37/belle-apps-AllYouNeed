#include "zip.h"
#include "zipsifre.h"
#include "dil.h"

#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QDir>
#include <QtCore/QDateTime>
#include <QtCore/QTextCodec>
#include <QtCore/QVector>
#include <string.h>

// ---------------- yardimcilar ----------------

static quint32 KCrcTablo[256];
static bool KCrcHazir = false;

quint32 Zip::crc32(quint32 crc, const char *p, qint64 n)
{
    if (!KCrcHazir) {
        for (quint32 i = 0; i < 256; ++i) {
            quint32 c = i;
            for (int k = 0; k < 8; ++k) c = (c & 1) ? 0xEDB88320u ^ (c >> 1) : c >> 1;
            KCrcTablo[i] = c;
        }
        KCrcHazir = true;
    }
    crc = ~crc;
    for (qint64 i = 0; i < n; ++i) crc = KCrcTablo[(crc ^ (uchar)p[i]) & 0xff] ^ (crc >> 8);
    return ~crc;
}

static inline quint16 u16(const uchar *p) { return quint16(p[0] | (p[1] << 8)); }
static inline quint32 u32(const uchar *p) { return quint32(p[0]) | (quint32(p[1]) << 8) | (quint32(p[2]) << 16) | (quint32(p[3]) << 24); }
static inline void w16(QByteArray &b, quint16 v) { b.append(char(v & 0xff)); b.append(char(v >> 8)); }
static inline void w32(QByteArray &b, quint32 v) { w16(b, quint16(v & 0xffff)); w16(b, quint16(v >> 16)); }

static uint dosToTime(quint16 t, quint16 d)
{
    QDate dt(1980 + (d >> 9), (d >> 5) & 15, d & 31);
    QTime tm((t >> 11) & 31, (t >> 5) & 63, (t & 31) * 2);
    if (!dt.isValid()) return 0;
    return QDateTime(dt, tm.isValid() ? tm : QTime(0, 0)).toTime_t();
}
static void timeToDos(uint tt, quint16 *t, quint16 *d)
{
    QDateTime x = QDateTime::fromTime_t(tt ? tt : QDateTime::currentDateTime().toTime_t());
    if (x.date().year() < 1980) x = QDateTime(QDate(1980, 1, 1), QTime(0, 0));
    *t = quint16((x.time().hour() << 11) | (x.time().minute() << 5) | (x.time().second() / 2));
    *d = quint16(((x.date().year() - 1980) << 9) | (x.date().month() << 5) | x.date().day());
}

// Windows'ta yapilan Turkce zip'ler CP857 kullanir; IBM 850'den 6 harf farkli
static QString adCoz(const QByteArray &b, int bayrak)
{
    if (bayrak & 0x800) return QString::fromUtf8(b);
    bool ascii = true;
    for (int i = 0; i < b.size(); ++i) if ((uchar)b.at(i) >= 0x80) { ascii = false; break; }
    if (ascii) return QString::fromLatin1(b);
    const QString u = QString::fromUtf8(b);
    if (!u.contains(QChar(0xFFFD))) return u;
    QTextCodec *c = QTextCodec::codecForName("IBM 850");
    QString o;
    for (int i = 0; i < b.size(); ++i) {
        const uchar ch = (uchar)b.at(i);
        switch (ch) {
        case 0x8D: o += QChar(0x0131); break;   // i (noktasiz)
        case 0x98: o += QChar(0x0130); break;   // I (noktali)
        case 0x9E: o += QChar(0x015E); break;   // S cedilla
        case 0x9F: o += QChar(0x015F); break;
        case 0xA6: o += QChar(0x011E); break;   // G breve
        case 0xA7: o += QChar(0x011F); break;
        default:
            if (ch < 0x80 || !c) o += QChar(ch);
            else o += c->toUnicode(b.mid(i, 1));
        }
    }
    return o;
}

// ---------------- listeleme ----------------

bool Zip::listele(const QString &arsiv, QList<ZipOge> *ogeler, QString *hata)
{
    ogeler->clear();
    QFile f(arsiv);
    if (!f.open(QIODevice::ReadOnly)) { *hata = Dil::t("Arşiv açılamadı"); return false; }
    const qint64 boy = f.size();
    if (boy < 22) { *hata = Dil::t("Geçerli bir zip değil"); return false; }
    const qint64 okunacak = qMin<qint64>(boy, 65557);
    f.seek(boy - okunacak);
    const QByteArray son = f.read(okunacak);
    const uchar *s = (const uchar *)son.constData();
    int e = -1;
    for (int i = son.size() - 22; i >= 0; --i)
        if (s[i] == 'P' && s[i + 1] == 'K' && s[i + 2] == 5 && s[i + 3] == 6) { e = i; break; }
    if (e < 0) { *hata = Dil::t("Zip dizini bulunamadı (bozuk ya da zip değil)"); return false; }
    const int adet = u16(s + e + 10);
    const quint32 cdBoy = u32(s + e + 12), cdOfs = u32(s + e + 16);
    if (cdOfs == 0xFFFFFFFFu || adet == 0xFFFF) { *hata = Dil::t("ZIP64 arşivleri desteklenmiyor"); return false; }
    if (qint64(cdOfs) + cdBoy > boy) { *hata = Dil::t("Zip dizini bozuk"); return false; }
    f.seek(cdOfs);
    const QByteArray cd = f.read(cdBoy);
    const uchar *p = (const uchar *)cd.constData();
    int k = 0;
    for (int n = 0; n < adet; ++n) {
        if (k + 46 > cd.size() || u32(p + k) != 0x02014b50u) break;
        ZipOge o;
        o.bayrak = u16(p + k + 8);
        o.yontem = u16(p + k + 10);
        o.zaman = dosToTime(u16(p + k + 12), u16(p + k + 14));
        o.crc = u32(p + k + 16);
        o.sBoyut = u32(p + k + 20);
        o.boyut = u32(p + k + 24);
        const int nl = u16(p + k + 28), xl = u16(p + k + 30), cl = u16(p + k + 32);
        o.yerelOfset = u32(p + k + 42);
        if (k + 46 + nl > cd.size()) break;
        o.ad = adCoz(cd.mid(k + 46, nl), o.bayrak);
        // WinZip AES ek alani (0x9901): surum, "AE", guc, asil yontem
        if (k + 46 + nl + xl <= cd.size()) {
            const uchar *x = p + k + 46 + nl;
            int j = 0;
            while (j + 4 <= xl) {
                const int id = u16(x + j), ln = u16(x + j + 2);
                if (j + 4 + ln > xl) break;
                if (id == 0x9901 && ln >= 7) { o.aesSurum = u16(x + j + 4); o.aesGuc = x[j + 8]; o.aesYontem = u16(x + j + 9); }
                j += 4 + ln;
            }
        }
        o.ad.replace('\\', '/');
        while (o.ad.startsWith('/')) o.ad.remove(0, 1);
        if (!o.ad.isEmpty() && !o.ad.contains("../")) ogeler->append(o);
        k += 46 + nl + xl + cl;
    }
    return true;
}

// ---------------- inflate (akisli) ----------------

namespace {

struct Huff { short count[16]; short symbol[288]; };

static const short KLBase[29] = { 3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258 };
static const short KLExt[29] = { 0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0 };
static const short KDBase[30] = { 1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577 };
static const short KDExt[30] = { 0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13 };

// Sikistirilmis veri akisi: dosyadan en fazla n bayt okur; sifreliyse okurken cozer
class Girdi
{
public:
    Girdi(QFile &f, qint64 n) : m_f(f), m_kalan(n), m_tur(0) {}
    void zipCrypto(const ZipSifre::ZipCrypto &z) { m_zc = z; m_tur = 1; }
    void aes(const ZipSifre::AesCtr &c, const QByteArray &dogrulamaAnahtari) { m_ctr = c; m_hmac.kur(dogrulamaAnahtari); m_tur = 2; }
    qint64 oku(char *buf, qint64 en)
    {
        if (m_kalan <= 0) return 0;
        const qint64 n = m_f.read(buf, qMin(en, m_kalan));
        if (n <= 0) return n;
        m_kalan -= n;
        if (m_tur == 1) m_zc.coz(buf, n);
        else if (m_tur == 2) { m_hmac.ekle(buf, n); m_ctr.coz(buf, n); }   // HMAC sifreli veri uzerinden
        return n;
    }
    qint64 kalan() const { return m_kalan; }
    QByteArray hmac() { return m_hmac.bitir(); }
    // inflate bitince kalan (okunmamis) sifreli baytlari da HMAC'e kat
    bool tuket()
    {
        char t[4096];
        while (m_kalan > 0) { if (oku(t, sizeof(t)) <= 0) return false; }
        return true;
    }
private:
    QFile &m_f;
    qint64 m_kalan;
    int m_tur;
    ZipSifre::ZipCrypto m_zc;
    ZipSifre::AesCtr m_ctr;
    ZipSifre::HmacSha1 m_hmac;
};

class Inflater
{
public:
    Inflater(Girdi &in, QFile &out, ZipIzleyici *iz)
        : m_in(in), m_ipos(0), m_ilen(0), m_out(out), m_wpos(0), m_opos(0),
          m_crc(0), m_yazilan(0), m_iz(iz), m_bitbuf(0), m_bitcnt(0), m_hata(false), m_iptal(false) {}

    bool calistir()
    {
        int son;
        do {
            son = bits(1);
            const int tur = bits(2);
            if (m_hata) break;
            if (tur == 0) stored();
            else if (tur == 1) sabit();
            else if (tur == 2) dinamik();
            else m_hata = true;
        } while (!son && !m_hata && !m_iptal);
        bosalt();
        return !m_hata && !m_iptal;
    }
    quint32 crc() const { return m_crc; }
    bool iptal() const { return m_iptal; }

private:
    int bayt()
    {
        if (m_ipos == m_ilen) {
            const qint64 n = m_in.oku(m_ibuf, sizeof(m_ibuf));
            if (n <= 0) { m_hata = true; return 0; }
            m_ilen = int(n); m_ipos = 0;
        }
        return (uchar)m_ibuf[m_ipos++];
    }
    int bits(int n)
    {
        quint32 v = m_bitbuf;
        while (m_bitcnt < n) {
            if (m_hata) return 0;
            v |= quint32(bayt()) << m_bitcnt;
            m_bitcnt += 8;
        }
        m_bitbuf = v >> n;
        m_bitcnt -= n;
        return int(v & ((1u << n) - 1));
    }
    inline void koy(uchar c)
    {
        m_win[m_wpos & 32767] = c;
        ++m_wpos;
        m_obuf[m_opos++] = char(c);
        if (m_opos == int(sizeof(m_obuf))) bosalt();
    }
    void bosalt()
    {
        if (!m_opos) return;
        if (m_out.write(m_obuf, m_opos) != m_opos) m_hata = true;
        m_crc = Zip::crc32(m_crc, m_obuf, m_opos);
        m_yazilan += m_opos;
        if (m_iz && !m_iz->zipIlerleme(m_opos)) m_iptal = true;
        m_opos = 0;
    }
    int coz(const Huff &h)
    {
        int code = 0, first = 0, index = 0;
        for (int len = 1; len < 16; ++len) {
            code |= bits(1);
            const int count = h.count[len];
            if (code - count < first) return h.symbol[index + (code - first)];
            index += count;
            first += count;
            first <<= 1;
            code <<= 1;
            if (m_hata) return -1;
        }
        return -1;
    }
    static int kur(Huff &h, const short *uzunluk, int n)
    {
        short offs[16];
        for (int i = 0; i < 16; ++i) h.count[i] = 0;
        for (int s = 0; s < n; ++s) h.count[uzunluk[s]]++;
        if (h.count[0] == n) return 0;
        int left = 1;
        for (int len = 1; len < 16; ++len) { left <<= 1; left -= h.count[len]; if (left < 0) return left; }
        offs[1] = 0;
        for (int len = 1; len < 15; ++len) offs[len + 1] = offs[len] + h.count[len];
        for (int s = 0; s < n; ++s) if (uzunluk[s]) h.symbol[offs[uzunluk[s]]++] = short(s);
        return left;
    }
    void stored()
    {
        m_bitbuf = 0; m_bitcnt = 0;
        const int a = bayt(), b = bayt(), c = bayt(), d = bayt();
        const int len = a | (b << 8), nlen = c | (d << 8);
        if (m_hata || len != (~nlen & 0xffff)) { m_hata = true; return; }
        for (int i = 0; i < len && !m_hata; ++i) koy(uchar(bayt()));
    }
    void kodlar(const Huff &lc, const Huff &dc)
    {
        for (;;) {
            int sym = coz(lc);
            if (sym < 0 || m_hata) { m_hata = true; return; }
            if (sym < 256) koy(uchar(sym));
            else if (sym == 256) return;
            else {
                sym -= 257;
                if (sym >= 29) { m_hata = true; return; }
                const int len = KLBase[sym] + bits(KLExt[sym]);
                const int ds = coz(dc);
                if (ds < 0 || ds >= 30) { m_hata = true; return; }
                const quint32 dist = quint32(KDBase[ds] + bits(KDExt[ds]));
                if (dist > m_wpos) { m_hata = true; return; }
                for (int i = 0; i < len; ++i) koy(m_win[(m_wpos - dist) & 32767]);
            }
            if (m_iptal) return;
        }
    }
    void sabit()
    {
        static bool hazir = false;
        static Huff lc, dc;
        if (!hazir) {
            short l[288];
            int s = 0;
            for (; s < 144; ++s) l[s] = 8;
            for (; s < 256; ++s) l[s] = 9;
            for (; s < 280; ++s) l[s] = 7;
            for (; s < 288; ++s) l[s] = 8;
            kur(lc, l, 288);
            for (s = 0; s < 30; ++s) l[s] = 5;
            kur(dc, l, 30);
            hazir = true;
        }
        kodlar(lc, dc);
    }
    void dinamik()
    {
        static const short sira[19] = { 16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15 };
        short l[320];
        const int nlen = bits(5) + 257, ndist = bits(5) + 1, ncode = bits(4) + 4;
        if (m_hata || nlen > 286 || ndist > 30) { m_hata = true; return; }
        int i = 0;
        for (; i < ncode; ++i) l[sira[i]] = short(bits(3));
        for (; i < 19; ++i) l[sira[i]] = 0;
        Huff lc, dc;
        if (kur(lc, l, 19) != 0) { m_hata = true; return; }
        i = 0;
        while (i < nlen + ndist) {
            int sym = coz(lc);
            if (sym < 0 || m_hata) { m_hata = true; return; }
            if (sym < 16) l[i++] = short(sym);
            else {
                short len = 0;
                int tekrar;
                if (sym == 16) { if (i == 0) { m_hata = true; return; } len = l[i - 1]; tekrar = 3 + bits(2); }
                else if (sym == 17) tekrar = 3 + bits(3);
                else tekrar = 11 + bits(7);
                if (i + tekrar > nlen + ndist) { m_hata = true; return; }
                while (tekrar--) l[i++] = len;
            }
        }
        if (l[256] == 0) { m_hata = true; return; }
        int r = kur(lc, l, nlen);
        if (r < 0 || (r > 0 && nlen - lc.count[0] != 1)) { m_hata = true; return; }
        r = kur(dc, l + nlen, ndist);
        if (r < 0 || (r > 0 && ndist - dc.count[0] != 1)) { m_hata = true; return; }
        kodlar(lc, dc);
    }

    Girdi &m_in;
    char m_ibuf[16384];
    int m_ipos, m_ilen;
    QFile &m_out;
    uchar m_win[32768];
    quint32 m_wpos;
    char m_obuf[65536];
    int m_opos;
    quint32 m_crc;
    qint64 m_yazilan;
    ZipIzleyici *m_iz;
    quint32 m_bitbuf;
    int m_bitcnt;
    bool m_hata, m_iptal;
};

// ---------------- deflate (bellekte, sabit Huffman + LZ77) ----------------

class BitYaz
{
public:
    BitYaz() : m_buf(0), m_cnt(0) {}
    void koy(quint32 v, int n)
    {
        m_buf |= v << m_cnt;
        m_cnt += n;
        while (m_cnt >= 8) { out.append(char(m_buf & 0xff)); m_buf >>= 8; m_cnt -= 8; }
    }
    void bitir() { if (m_cnt > 0) out.append(char(m_buf & 0xff)); m_buf = 0; m_cnt = 0; }
    QByteArray out;
private:
    quint32 m_buf;
    int m_cnt;
};

static inline quint32 ters(quint32 code, int len)
{
    quint32 r = 0;
    for (int i = 0; i < len; ++i) { r = (r << 1) | (code & 1); code >>= 1; }
    return r;
}
static inline void harf(BitYaz &b, int v)
{
    if (v < 144) b.koy(ters(0x30 + v, 8), 8);
    else if (v < 256) b.koy(ters(0x190 + (v - 144), 9), 9);
    else if (v < 280) b.koy(ters(v - 256, 7), 7);
    else b.koy(ters(0xC0 + (v - 280), 8), 8);
}

static QByteArray sikistir(const QByteArray &veri)
{
    const uchar *d = (const uchar *)veri.constData();
    const int n = veri.size();
    BitYaz b;
    b.koy(1, 1);   // BFINAL
    b.koy(1, 2);   // BTYPE = sabit Huffman
    QVector<int> bas(65536, -1), onceki(32768, -1);
    int i = 0;
    while (i < n) {
        int enIyi = 0, mesafe = 0;
        if (i + 2 < n) {
            const int h = ((d[i] << 10) ^ (d[i + 1] << 5) ^ d[i + 2]) & 0xffff;
            int aday = bas[h], derinlik = 0;
            const int sinir = qMin(258, n - i);
            while (aday >= 0 && i - aday <= 32768 && derinlik < 24) {
                if (d[aday + enIyi] == d[i + enIyi]) {
                    int l = 0;
                    while (l < sinir && d[aday + l] == d[i + l]) ++l;
                    if (l > enIyi) { enIyi = l; mesafe = i - aday; if (l == sinir) break; }
                }
                const int sonraki = onceki[aday & 32767];
                if (sonraki >= aday) break;
                aday = sonraki;
                ++derinlik;
            }
            onceki[i & 32767] = bas[h];
            bas[h] = i;
        }
        if (enIyi >= 3) {
            int k = 0;
            while (k < 28 && KLBase[k + 1] <= enIyi) ++k;
            harf(b, 257 + k);
            if (KLExt[k]) b.koy(quint32(enIyi - KLBase[k]), KLExt[k]);
            int j = 0;
            while (j < 29 && KDBase[j + 1] <= mesafe) ++j;
            b.koy(ters(quint32(j), 5), 5);
            if (KDExt[j]) b.koy(quint32(mesafe - KDBase[j]), KDExt[j]);
            for (int t = 1; t < enIyi; ++t) {
                const int p = i + t;
                if (p + 2 < n) {
                    const int h2 = ((d[p] << 10) ^ (d[p + 1] << 5) ^ d[p + 2]) & 0xffff;
                    onceki[p & 32767] = bas[h2];
                    bas[h2] = p;
                }
            }
            i += enIyi;
        } else {
            harf(b, d[i]);
            ++i;
        }
    }
    harf(b, 256);
    b.bitir();
    return b.out;
}

} // namespace

bool Zip::ac(QFile &arsiv, const ZipOge &o, const QString &hedefDosya, ZipIzleyici *iz, QString *hata,
             const QByteArray &parola, bool *parolaSorunu)
{
    if (parolaSorunu) *parolaSorunu = false;
    if (o.klasor()) { QDir().mkpath(hedefDosya); return true; }
    const bool aes = o.sifreli() && o.yontem == 99;
    const int yontem = aes ? o.aesYontem : o.yontem;
    if (aes && (o.aesGuc < 1 || o.aesGuc > 3)) { *hata = Dil::t("Desteklenmeyen AES şifresi: ") + o.ad; return false; }
    if (yontem != 0 && yontem != 8) { *hata = Dil::t("Desteklenmeyen sıkıştırma (") + QString::number(yontem) + "): " + o.ad; return false; }
    if (o.sifreli() && parola.isEmpty()) { if (parolaSorunu) *parolaSorunu = true; *hata = Dil::t("Parola gerekli: ") + o.ad; return false; }
    if (!arsiv.seek(o.yerelOfset)) { *hata = Dil::t("Arşiv okunamadı"); return false; }
    const QByteArray lh = arsiv.read(30);
    const uchar *p = (const uchar *)lh.constData();
    if (lh.size() < 30 || u32(p) != 0x04034b50u) { *hata = Dil::t("Yerel başlık bozuk: ") + o.ad; return false; }
    arsiv.seek(o.yerelOfset + 30 + u16(p + 26) + u16(p + 28));

    // sifre cozme hazirligi: veri boyutu baslik/dogrulama baytlari kadar kisalir
    qint64 veriBoy = o.sBoyut;
    Girdi *girdi = 0;
    QByteArray dogrulamaAnahtari;
    if (o.sifreli() && !aes) {
        if (veriBoy < 12) { *hata = Dil::t("Şifreli veri bozuk: ") + o.ad; return false; }
        ZipSifre::ZipCrypto zc;
        zc.kur(parola);
        char bas[12];
        if (arsiv.read(bas, 12) != 12) { *hata = Dil::t("Arşiv okunamadı"); return false; }
        zc.coz(bas, 12);
        // son bayt: CRC'nin ust bayti; veri tanimlayicili (bit 3) zip'lerde degistirilme saatinin ust bayti
        const uchar kontrol = uchar(bas[11]);
        const bool uyar = kontrol == uchar(o.crc >> 24) || ((o.bayrak & 8) && kontrol == uchar(u16(p + 10) >> 8));
        if (!uyar) { if (parolaSorunu) *parolaSorunu = true; *hata = Dil::t("Parola yanlış: ") + o.ad; return false; }
        veriBoy -= 12;
        girdi = new Girdi(arsiv, veriBoy);
        girdi->zipCrypto(zc);
    } else if (aes) {
        const int anahtarBoy = 8 + 8 * o.aesGuc;          // 16 / 24 / 32
        const int tuzBoy = 4 + 4 * o.aesGuc;              // 8 / 12 / 16
        if (veriBoy < tuzBoy + 2 + 10) { *hata = Dil::t("Şifreli veri bozuk: ") + o.ad; return false; }
        const QByteArray tuz = arsiv.read(tuzBoy);
        const QByteArray pv = arsiv.read(2);
        if (tuz.size() != tuzBoy || pv.size() != 2) { *hata = Dil::t("Arşiv okunamadı"); return false; }
        if (iz) iz->zipIlerleme(0);
        const QByteArray tureyen = ZipSifre::pbkdf2Sha1(parola, tuz, 1000, 2 * anahtarBoy + 2);
        if (tureyen.mid(2 * anahtarBoy, 2) != pv) { if (parolaSorunu) *parolaSorunu = true; *hata = Dil::t("Parola yanlış: ") + o.ad; return false; }
        ZipSifre::AesCtr ctr;
        ctr.kur(tureyen.left(anahtarBoy));
        dogrulamaAnahtari = tureyen.mid(anahtarBoy, anahtarBoy);
        veriBoy -= tuzBoy + 2 + 10;
        girdi = new Girdi(arsiv, veriBoy);
        girdi->aes(ctr, dogrulamaAnahtari);
    } else {
        girdi = new Girdi(arsiv, veriBoy);
    }

    QDir().mkpath(QFileInfo(hedefDosya).absolutePath());
    QFile out(hedefDosya);
    if (out.exists()) out.setPermissions(out.permissions() | QFile::WriteOwner | QFile::WriteUser);   // salt okunur eski dosya
    if (!out.open(QIODevice::WriteOnly)) { delete girdi; *hata = Dil::t("Yazılamadı: ") + hedefDosya; return false; }
    bool ok = true;
    quint32 crc = 0;
    if (yontem == 0) {
        QByteArray tampon(65536, 0); char *buf = tampon.data();
        while (girdi->kalan() > 0) {
            const qint64 nn = girdi->oku(buf, 65536);
            if (nn <= 0 || out.write(buf, nn) != nn) { ok = false; break; }
            crc = crc32(crc, buf, nn);
            if (iz && !iz->zipIlerleme(nn)) { ok = false; *hata = Dil::t("İptal edildi"); break; }
        }
        if (ok && girdi->kalan() > 0) ok = false;
    } else {
        Inflater *inf = new Inflater(*girdi, out, iz);   // ~130 KB: yigin yerine heap
        ok = inf->calistir();
        crc = inf->crc();
        if (inf->iptal()) *hata = Dil::t("İptal edildi");
        delete inf;
    }
    out.close();
    if (aes && hata->isEmpty()) {
        // HMAC-SHA1 (ilk 10 bayt) sifreli verinin sonunda: dogrulama
        if (!girdi->tuket()) { ok = false; }
        else {
            const QByteArray beklenen = arsiv.read(10);
            if (girdi->hmac().left(10) != beklenen) { ok = false; if (parolaSorunu) *parolaSorunu = true; *hata = Dil::t("Parola yanlış ya da veri bozuk: ") + o.ad; }
        }
    }
    delete girdi;
    const bool crcVar = !(aes && o.aesSurum == 2);       // AE-2'de CRC alani bos
    if (ok && crcVar && crc != o.crc) {
        ok = false;
        if (o.sifreli() && parolaSorunu) *parolaSorunu = true;
        *hata = o.sifreli() ? Dil::t("Parola yanlış ya da veri bozuk: ") + o.ad : Dil::t("CRC hatası (bozuk veri): ") + o.ad;
    }
    if (!ok) {
        if (hata->isEmpty()) {
            if (o.sifreli()) { if (parolaSorunu) *parolaSorunu = true; *hata = Dil::t("Parola yanlış ya da veri bozuk: ") + o.ad; }
            else *hata = Dil::t("Açılamadı (bozuk veri): ") + o.ad;
        }
        QFile::remove(hedefDosya);
    }
    return ok;
}

// ---------------- yazici ----------------

Zip::Yazici::Yazici(QFile *f) : m_f(f), m_sakla(false), m_eskiCdOfs(-1), m_eskiAdet(0) {}

bool Zip::Yazici::eklemeyeAc(QString *hata)
{
    const qint64 boy = m_f->size();
    if (boy < 22) { *hata = Dil::t("Geçerli bir zip değil"); return false; }
    const qint64 okunacak = qMin<qint64>(boy, 65557);
    m_f->seek(boy - okunacak);
    const QByteArray son = m_f->read(okunacak);
    const uchar *s = (const uchar *)son.constData();
    int e = -1;
    for (int i = son.size() - 22; i >= 0; --i)
        if (s[i] == 'P' && s[i + 1] == 'K' && s[i + 2] == 5 && s[i + 3] == 6) { e = i; break; }
    if (e < 0) { *hata = Dil::t("Zip dizini bulunamadı (bozuk ya da zip değil)"); return false; }
    const int adet = u16(s + e + 10);
    const quint32 cdBoy = u32(s + e + 12), cdOfs = u32(s + e + 16);
    if (cdOfs == 0xFFFFFFFFu || adet == 0xFFFF) { *hata = Dil::t("ZIP64 arşivlerine eklenemez"); return false; }
    if (qint64(cdOfs) + cdBoy > boy) { *hata = Dil::t("Zip dizini bozuk"); return false; }
    m_f->seek(cdOfs);
    m_eskiCD = m_f->read(cdBoy);
    m_eskiSon = son.mid(e);
    m_eskiCdOfs = cdOfs;
    m_eskiAdet = adet;
    // arsivdeki adlar (ayni dosya ikinci kez eklenmesin): eski dizinden
    m_adlar.clear();
    const uchar *p = (const uchar *)m_eskiCD.constData();
    int k = 0;
    for (int n = 0; n < adet && k + 46 <= m_eskiCD.size() && u32(p + k) == 0x02014b50u; ++n) {
        const int nl = u16(p + k + 28), xl = u16(p + k + 30), cl = u16(p + k + 32);
        if (k + 46 + nl > m_eskiCD.size()) break;
        QString ad = adCoz(m_eskiCD.mid(k + 46, nl), u16(p + k + 8));
        ad.replace('\\', '/');
        m_adlar << ad;
        k += 46 + nl + xl + cl;
    }
    m_f->seek(cdOfs);               // yeni ogeler eski dizinin yerine yazilir
    return true;
}

void Zip::Yazici::geriAl()
{
    if (m_eskiCdOfs < 0) return;
    m_f->seek(m_eskiCdOfs);
    m_f->write(m_eskiCD);
    m_f->write(m_eskiSon);
    m_f->resize(m_f->pos());
}

static QByteArray yerelBaslik(const ZipOge &o, const QByteArray &ad)
{
    quint16 t, d;
    timeToDos(o.zaman, &t, &d);
    QByteArray h;
    w32(h, 0x04034b50u); w16(h, 20); w16(h, 0x0800); w16(h, quint16(o.yontem)); w16(h, t); w16(h, d);
    w32(h, o.crc); w32(h, quint32(o.sBoyut)); w32(h, quint32(o.boyut)); w16(h, quint16(ad.size())); w16(h, 0);
    h.append(ad);
    return h;
}

bool Zip::Yazici::klasorEkle(const QString &arsivAdi, uint zaman)
{
    ZipOge o;
    o.ad = arsivAdi.endsWith('/') ? arsivAdi : arsivAdi + "/";
    o.crc = 0; o.boyut = 0; o.sBoyut = 0; o.yontem = 0; o.bayrak = 0x800; o.zaman = zaman;
    o.yerelOfset = m_f->pos();
    if (m_f->write(yerelBaslik(o, o.ad.toUtf8())) < 0) return false;
    m_ogeler << o;
    return true;
}

bool Zip::Yazici::dosyaEkle(const QString &yerel, const QString &arsivAdi, ZipIzleyici *iz, QString *hata)
{
    QFile src(yerel);
    if (!src.open(QIODevice::ReadOnly)) { *hata = Dil::t("Okunamadı: ") + yerel; return false; }
    ZipOge o;
    o.ad = arsivAdi;
    o.bayrak = 0x800;
    o.zaman = QFileInfo(yerel).lastModified().toTime_t();
    o.boyut = src.size();
    o.yerelOfset = m_f->pos();
    const QByteArray ad = arsivAdi.toUtf8();
    if (o.boyut > 0xFFFFFFF0LL) { *hata = Dil::t("4 GB üstü dosya zip'e eklenemez"); return false; }
    if (!m_sakla && o.boyut > 0 && o.boyut <= 16 * 1024 * 1024) {
        const QByteArray veri = src.readAll();
        o.crc = crc32(0, veri.constData(), veri.size());
        QByteArray s = sikistir(veri);
        const bool sik = s.size() < veri.size();
        o.yontem = sik ? 8 : 0;
        o.sBoyut = sik ? s.size() : veri.size();
        if (m_f->write(yerelBaslik(o, ad)) < 0 || m_f->write(sik ? s : veri) != o.sBoyut) { *hata = Dil::t("Zip yazılamadı (yer kalmadı mı?)"); return false; }
        if (iz && !iz->zipIlerleme(o.boyut)) { *hata = Dil::t("İptal edildi"); return false; }
    } else {
        // buyuk dosya: sikistirmasiz, akisla; crc sonra basliga yazilir
        o.yontem = 0; o.crc = 0; o.sBoyut = o.boyut;
        if (m_f->write(yerelBaslik(o, ad)) < 0) { *hata = Dil::t("Zip yazılamadı"); return false; }
        QByteArray tampon(65536, 0); char *buf = tampon.data();
        quint32 crc = 0;
        for (;;) {
            const qint64 nn = src.read(buf, 65536);
            if (nn <= 0) break;
            if (m_f->write(buf, nn) != nn) { *hata = Dil::t("Zip yazılamadı (yer kalmadı mı?)"); return false; }
            crc = crc32(crc, buf, nn);
            if (iz && !iz->zipIlerleme(nn)) { *hata = Dil::t("İptal edildi"); return false; }
        }
        o.crc = crc;
        const qint64 son = m_f->pos();
        m_f->seek(o.yerelOfset + 14);
        QByteArray c; w32(c, crc);
        m_f->write(c);
        m_f->seek(son);
    }
    m_ogeler << o;
    return true;
}

bool Zip::Yazici::bitir(QString *hata)
{
    const qint64 cdOfs = m_f->pos();
    QByteArray cd;
    foreach (const ZipOge &o, m_ogeler) {
        quint16 t, d;
        timeToDos(o.zaman, &t, &d);
        const QByteArray ad = o.ad.toUtf8();
        w32(cd, 0x02014b50u); w16(cd, 20); w16(cd, 20); w16(cd, 0x0800); w16(cd, quint16(o.yontem)); w16(cd, t); w16(cd, d);
        w32(cd, o.crc); w32(cd, quint32(o.sBoyut)); w32(cd, quint32(o.boyut));
        w16(cd, quint16(ad.size())); w16(cd, 0); w16(cd, 0); w16(cd, 0); w16(cd, 0);
        w32(cd, o.klasor() ? 0x10 : 0x20); w32(cd, quint32(o.yerelOfset));
        cd.append(ad);
    }
    if (m_eskiCdOfs >= 0) cd.prepend(m_eskiCD);      // ekleme kipi: eski kayitlar aynen korunur
    const int toplam = m_ogeler.size() + (m_eskiCdOfs >= 0 ? m_eskiAdet : 0);
    if (toplam > 0xFFFE) { *hata = Dil::t("Arşivde çok fazla dosya (65535 sınırı)"); return false; }
    QByteArray e;
    w32(e, 0x06054b50u); w16(e, 0); w16(e, 0); w16(e, quint16(toplam)); w16(e, quint16(toplam));
    w32(e, quint32(cd.size())); w32(e, quint32(cdOfs)); w16(e, 0);
    if (m_f->write(cd) != cd.size() || m_f->write(e) != e.size()) { *hata = Dil::t("Zip dizini yazılamadı"); return false; }
    m_f->resize(m_f->pos());                          // eski dizinden artan bayt kalmasin
    return true;
}
