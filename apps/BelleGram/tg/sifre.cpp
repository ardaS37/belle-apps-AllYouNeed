#include "sifre.h"
#include <QtCore/QCryptographicHash>
#include <QtCore/QDateTime>
#include <QtCore/QTime>
#include <string.h>
#include <stdlib.h>
#ifdef Q_OS_SYMBIAN
#include <e32std.h>
#include <e32math.h>
#endif

// ======================================================================= SHA
QByteArray Sifre::sha1(const QByteArray &veri)
{
    return QCryptographicHash::hash(veri, QCryptographicHash::Sha1);
}

static const quint32 K256[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2 };

static inline quint32 rotr(quint32 x, int n) { return (x >> n) | (x << (32 - n)); }

QByteArray Sifre::sha256(const QByteArray &veri)
{
    quint32 h[8] = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 };
    QByteArray m = veri;
    const quint64 bitLen = quint64(veri.size()) * 8;
    m.append(char(0x80));
    while (m.size() % 64 != 56) m.append(char(0));
    for (int i = 7; i >= 0; --i) m.append(char((bitLen >> (i * 8)) & 0xff));
    const uchar *p = reinterpret_cast<const uchar *>(m.constData());
    quint32 w[64];
    for (int blok = 0; blok < m.size(); blok += 64) {
        for (int i = 0; i < 16; ++i)
            w[i] = (quint32(p[blok + i * 4]) << 24) | (quint32(p[blok + i * 4 + 1]) << 16)
                 | (quint32(p[blok + i * 4 + 2]) << 8) | quint32(p[blok + i * 4 + 3]);
        for (int i = 16; i < 64; ++i) {
            const quint32 s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
            const quint32 s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
            w[i] = w[i - 16] + s0 + w[i - 7] + s1;
        }
        quint32 a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
        for (int i = 0; i < 64; ++i) {
            const quint32 S1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
            const quint32 ch = (e & f) ^ (~e & g);
            const quint32 t1 = hh + S1 + ch + K256[i] + w[i];
            const quint32 S0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
            const quint32 maj = (a & b) ^ (a & c) ^ (b & c);
            const quint32 t2 = S0 + maj;
            hh = g; g = f; f = e; e = d + t1; d = c; c = b; b = a; a = t1 + t2;
        }
        h[0] += a; h[1] += b; h[2] += c; h[3] += d; h[4] += e; h[5] += f; h[6] += g; h[7] += hh;
    }
    QByteArray out(32, 0);
    for (int i = 0; i < 8; ++i) {
        out[i * 4] = char(h[i] >> 24); out[i * 4 + 1] = char(h[i] >> 16);
        out[i * 4 + 2] = char(h[i] >> 8); out[i * 4 + 3] = char(h[i]);
    }
    return out;
}

// ======================================================================= AES-256
static uchar sSbox[256], sInv[256];
static bool sAesHazir = false;

static inline uchar xt(uchar x) { return uchar((x << 1) ^ ((x & 0x80) ? 0x1b : 0)); }
static uchar gmul(uchar a, uchar b)
{
    uchar r = 0;
    while (b) { if (b & 1) r ^= a; a = xt(a); b >>= 1; }
    return r;
}

static void aesKur()
{
    if (sAesHazir) return;
    // S-kutusu: GF(2^8) tersi + afin donusum (tablo elle yazilmaz, hesaplanir)
    for (int i = 0; i < 256; ++i) {
        uchar inv = 0;
        if (i) { for (int j = 1; j < 256; ++j) if (gmul(uchar(i), uchar(j)) == 1) { inv = uchar(j); break; } }
        uchar s = inv, x = inv;
        for (int k = 0; k < 4; ++k) { x = uchar((x << 1) | (x >> 7)); s ^= x; }
        s ^= 0x63;
        sSbox[i] = s;
        sInv[s] = uchar(i);
    }
    sAesHazir = true;
}

struct AesAnahtar { uchar rk[240]; };

static void aesGenislet(const uchar *key, AesAnahtar &a)
{
    aesKur();
    memcpy(a.rk, key, 32);
    uchar rcon = 1;
    for (int i = 32; i < 240; i += 4) {
        uchar t[4] = { a.rk[i - 4], a.rk[i - 3], a.rk[i - 2], a.rk[i - 1] };
        if (i % 32 == 0) {
            const uchar u = t[0];
            t[0] = uchar(sSbox[t[1]] ^ rcon); t[1] = sSbox[t[2]]; t[2] = sSbox[t[3]]; t[3] = sSbox[u];
            rcon = xt(rcon);
        } else if (i % 32 == 16) {
            for (int k = 0; k < 4; ++k) t[k] = sSbox[t[k]];
        }
        for (int k = 0; k < 4; ++k) a.rk[i + k] = uchar(a.rk[i - 32 + k] ^ t[k]);
    }
}

static void aesBlokSifrele(const AesAnahtar &a, uchar *s)
{
    for (int i = 0; i < 16; ++i) s[i] ^= a.rk[i];
    for (int r = 1; r <= 14; ++r) {
        uchar t[16];
        for (int i = 0; i < 16; ++i) t[i] = sSbox[s[i]];
        // ShiftRows (sutun ana sira: s[c*4 + satir])
        uchar u[16];
        for (int c = 0; c < 4; ++c)
            for (int row = 0; row < 4; ++row) u[c * 4 + row] = t[((c + row) % 4) * 4 + row];
        if (r != 14) {
            for (int c = 0; c < 4; ++c) {
                uchar *k = u + c * 4;
                const uchar a0 = k[0], a1 = k[1], a2 = k[2], a3 = k[3];
                k[0] = uchar(xt(a0) ^ (xt(a1) ^ a1) ^ a2 ^ a3);
                k[1] = uchar(a0 ^ xt(a1) ^ (xt(a2) ^ a2) ^ a3);
                k[2] = uchar(a0 ^ a1 ^ xt(a2) ^ (xt(a3) ^ a3));
                k[3] = uchar((xt(a0) ^ a0) ^ a1 ^ a2 ^ xt(a3));
            }
        }
        for (int i = 0; i < 16; ++i) s[i] = uchar(u[i] ^ a.rk[r * 16 + i]);
    }
}

static void aesBlokCoz(const AesAnahtar &a, uchar *s)
{
    for (int i = 0; i < 16; ++i) s[i] ^= a.rk[14 * 16 + i];
    for (int r = 13; r >= 0; --r) {
        uchar u[16];
        // InvShiftRows + InvSubBytes
        for (int c = 0; c < 4; ++c)
            for (int row = 0; row < 4; ++row) u[((c + row) % 4) * 4 + row] = sInv[s[c * 4 + row]];
        for (int i = 0; i < 16; ++i) u[i] ^= a.rk[r * 16 + i];
        if (r != 0) {
            for (int c = 0; c < 4; ++c) {
                uchar *k = u + c * 4;
                const uchar a0 = k[0], a1 = k[1], a2 = k[2], a3 = k[3];
                k[0] = uchar(gmul(a0, 14) ^ gmul(a1, 11) ^ gmul(a2, 13) ^ gmul(a3, 9));
                k[1] = uchar(gmul(a0, 9) ^ gmul(a1, 14) ^ gmul(a2, 11) ^ gmul(a3, 13));
                k[2] = uchar(gmul(a0, 13) ^ gmul(a1, 9) ^ gmul(a2, 14) ^ gmul(a3, 11));
                k[3] = uchar(gmul(a0, 11) ^ gmul(a1, 13) ^ gmul(a2, 9) ^ gmul(a3, 14));
            }
        }
        memcpy(s, u, 16);
    }
}

QByteArray Sifre::igeSifrele(const QByteArray &veri, const QByteArray &anahtar, const QByteArray &iv)
{
    if (veri.size() % 16 || anahtar.size() != 32 || iv.size() != 32) return QByteArray();
    AesAnahtar a;
    aesGenislet(reinterpret_cast<const uchar *>(anahtar.constData()), a);
    QByteArray out(veri.size(), 0);
    uchar oncekiC[16], oncekiP[16];
    memcpy(oncekiC, iv.constData(), 16);
    memcpy(oncekiP, iv.constData() + 16, 16);
    const uchar *in = reinterpret_cast<const uchar *>(veri.constData());
    uchar *o = reinterpret_cast<uchar *>(out.data());
    for (int i = 0; i < veri.size(); i += 16) {
        uchar b[16];
        for (int k = 0; k < 16; ++k) b[k] = uchar(in[i + k] ^ oncekiC[k]);
        aesBlokSifrele(a, b);
        for (int k = 0; k < 16; ++k) b[k] ^= oncekiP[k];
        memcpy(o + i, b, 16);
        memcpy(oncekiP, in + i, 16);
        memcpy(oncekiC, b, 16);
    }
    return out;
}

QByteArray Sifre::igeCoz(const QByteArray &veri, const QByteArray &anahtar, const QByteArray &iv)
{
    if (veri.size() % 16 || anahtar.size() != 32 || iv.size() != 32) return QByteArray();
    AesAnahtar a;
    aesGenislet(reinterpret_cast<const uchar *>(anahtar.constData()), a);
    QByteArray out(veri.size(), 0);
    uchar oncekiC[16], oncekiP[16];
    memcpy(oncekiC, iv.constData(), 16);
    memcpy(oncekiP, iv.constData() + 16, 16);
    const uchar *in = reinterpret_cast<const uchar *>(veri.constData());
    uchar *o = reinterpret_cast<uchar *>(out.data());
    for (int i = 0; i < veri.size(); i += 16) {
        uchar b[16];
        for (int k = 0; k < 16; ++k) b[k] = uchar(in[i + k] ^ oncekiP[k]);
        aesBlokCoz(a, b);
        for (int k = 0; k < 16; ++k) b[k] ^= oncekiC[k];
        memcpy(o + i, b, 16);
        memcpy(oncekiC, in + i, 16);
        memcpy(oncekiP, b, 16);
    }
    return out;
}

// ======================================================================= rastgele
static QByteArray sDurum;
static quint32 sSayac = 0;

static QByteArray entropi()
{
    QByteArray e;
    const qint64 ms = QDateTime::currentDateTime().toMSecsSinceEpoch();
    e.append(reinterpret_cast<const char *>(&ms), sizeof(ms));
    const int el = QTime::currentTime().msec();
    e.append(reinterpret_cast<const char *>(&el), sizeof(el));
    const int r = qrand();
    e.append(reinterpret_cast<const char *>(&r), sizeof(r));
    int yigin = 0;
    const void *adres = &yigin;
    e.append(reinterpret_cast<const char *>(&adres), sizeof(adres));
#ifdef Q_OS_SYMBIAN
    const TUint32 fc = User::FastCounter();
    e.append(reinterpret_cast<const char *>(&fc), sizeof(fc));
    const TUint32 mr = Math::Random();
    e.append(reinterpret_cast<const char *>(&mr), sizeof(mr));
    TTime t; t.UniversalTime();
    const TInt64 tv = t.Int64();
    e.append(reinterpret_cast<const char *>(&tv), sizeof(tv));
#else
    const int r2 = rand();
    e.append(reinterpret_cast<const char *>(&r2), sizeof(r2));
#endif
    return e;
}

QByteArray Sifre::rastgele(int n)
{
    if (sDurum.isEmpty()) {
        qsrand(uint(QDateTime::currentDateTime().toMSecsSinceEpoch()) ^ uint(quintptr(&sDurum)));
        sDurum = sha256(entropi() + entropi());
    }
    QByteArray out;
    while (out.size() < n) {
        ++sSayac;
        QByteArray s = sDurum;
        s.append(reinterpret_cast<const char *>(&sSayac), sizeof(sSayac));
        s.append(entropi());
        out.append(sha256(s + "cikti"));
        sDurum = sha256(s + "durum");
    }
    return out.left(n);
}

// ======================================================================= inflate (puff algoritmasi)
namespace {
struct Huff { short count[16]; short symbol[320]; };
struct Inf {
    const uchar *in; int len; int pos; quint32 buf; int cnt; bool hata; QByteArray out;
    int bits(int n)
    {
        quint32 v = buf;
        while (cnt < n) {
            if (pos >= len) { hata = true; return 0; }
            v |= quint32(in[pos++]) << cnt;
            cnt += 8;
        }
        buf = v >> n;
        cnt -= n;
        return int(v & ((1u << n) - 1));
    }
    int decode(const Huff &h)
    {
        int code = 0, first = 0, index = 0;
        for (int l = 1; l < 16; ++l) {
            code |= bits(1);
            if (hata) return -1;
            const int count = h.count[l];
            if (code - count < first) return h.symbol[index + (code - first)];
            index += count; first += count; first <<= 1; code <<= 1;
        }
        hata = true;
        return -1;
    }
};
int kur(Huff &h, const short *length, int n)
{
    short offs[16];
    for (int l = 0; l < 16; ++l) h.count[l] = 0;
    for (int s = 0; s < n; ++s) h.count[length[s]]++;
    if (h.count[0] == n) return 0;
    int left = 1;
    for (int l = 1; l < 16; ++l) { left <<= 1; left -= h.count[l]; if (left < 0) return left; }
    offs[1] = 0;
    for (int l = 1; l < 15; ++l) offs[l + 1] = short(offs[l] + h.count[l]);
    for (int s = 0; s < n; ++s) if (length[s]) h.symbol[offs[length[s]]++] = short(s);
    return left;
}
const short kLBase[29] = { 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258 };
const short kLExt[29] = { 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0 };
const short kDBase[30] = { 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577 };
const short kDExt[30] = { 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13 };

bool kodlar(Inf &s, const Huff &lenc, const Huff &distc)
{
    for (;;) {
        int sym = s.decode(lenc);
        if (s.hata || sym < 0) return false;
        if (sym < 256) { s.out.append(char(sym)); continue; }
        if (sym == 256) return true;
        sym -= 257;
        if (sym >= 29) return false;
        const int len = kLBase[sym] + s.bits(kLExt[sym]);
        const int ds = s.decode(distc);
        if (s.hata || ds < 0 || ds >= 30) return false;
        const int dist = kDBase[ds] + s.bits(kDExt[ds]);
        if (s.hata || dist > s.out.size()) return false;
        const int bas = s.out.size() - dist;
        for (int i = 0; i < len; ++i) s.out.append(s.out.at(bas + i));
    }
}
}

QByteArray Sifre::gzipAc(const QByteArray &gz)
{
    const uchar *p = reinterpret_cast<const uchar *>(gz.constData());
    int bas = 0;
    if (gz.size() >= 10 && p[0] == 0x1f && p[1] == 0x8b) {
        const uchar flg = p[3];
        bas = 10;
        if (flg & 4) { if (bas + 2 > gz.size()) return QByteArray(); bas += 2 + (p[bas] | (p[bas + 1] << 8)); }
        if (flg & 8) { while (bas < gz.size() && p[bas]) ++bas; ++bas; }
        if (flg & 16) { while (bas < gz.size() && p[bas]) ++bas; ++bas; }
        if (flg & 2) bas += 2;
        if (bas >= gz.size()) return QByteArray();
    }
    Inf s;
    s.in = p + bas; s.len = gz.size() - bas; s.pos = 0; s.buf = 0; s.cnt = 0; s.hata = false;
    s.out.reserve(gz.size() * 4);
    int son;
    do {
        son = s.bits(1);
        const int tur = s.bits(2);
        if (s.hata) return QByteArray();
        if (tur == 0) {
            s.buf = 0; s.cnt = 0;
            if (s.pos + 4 > s.len) return QByteArray();
            const int n = s.in[s.pos] | (s.in[s.pos + 1] << 8);
            s.pos += 4;
            if (s.pos + n > s.len) return QByteArray();
            s.out.append(reinterpret_cast<const char *>(s.in + s.pos), n);
            s.pos += n;
        } else if (tur == 1) {
            static Huff lenc, distc;
            static bool hazir = false;
            if (!hazir) {
                short l[288];
                int i = 0;
                for (; i < 144; ++i) l[i] = 8;
                for (; i < 256; ++i) l[i] = 9;
                for (; i < 280; ++i) l[i] = 7;
                for (; i < 288; ++i) l[i] = 8;
                kur(lenc, l, 288);
                for (i = 0; i < 30; ++i) l[i] = 5;
                kur(distc, l, 30);
                hazir = true;
            }
            if (!kodlar(s, lenc, distc)) return QByteArray();
        } else if (tur == 2) {
            static const short sira[19] = { 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };
            short lengths[320];
            const int nlen = s.bits(5) + 257, ndist = s.bits(5) + 1, ncode = s.bits(4) + 4;
            if (s.hata || nlen > 286 || ndist > 30) return QByteArray();
            int i;
            for (i = 0; i < ncode; ++i) lengths[sira[i]] = short(s.bits(3));
            for (; i < 19; ++i) lengths[sira[i]] = 0;
            Huff lenc, distc;
            if (kur(lenc, lengths, 19) != 0) return QByteArray();
            i = 0;
            while (i < nlen + ndist) {
                int sym = s.decode(lenc);
                if (s.hata || sym < 0) return QByteArray();
                if (sym < 16) { lengths[i++] = short(sym); continue; }
                int len = 0, tekrar;
                if (sym == 16) { if (!i) return QByteArray(); len = lengths[i - 1]; tekrar = 3 + s.bits(2); }
                else if (sym == 17) tekrar = 3 + s.bits(3);
                else tekrar = 11 + s.bits(7);
                if (i + tekrar > nlen + ndist) return QByteArray();
                while (tekrar--) lengths[i++] = short(len);
            }
            const int e1 = kur(lenc, lengths, nlen);
            if (e1 < 0 || (e1 > 0 && nlen - lenc.count[0] != 1)) return QByteArray();
            const int e2 = kur(distc, lengths + nlen, ndist);
            if (e2 < 0 || (e2 > 0 && ndist - distc.count[0] != 1)) return QByteArray();
            if (!kodlar(s, lenc, distc)) return QByteArray();
        } else {
            return QByteArray();
        }
    } while (!son);
    return s.out;
}

// ======================================================================= pq carpanlama
static quint64 mulmod(quint64 a, quint64 b, quint64 m)
{
    quint64 r = 0;
    a %= m;
    while (b) {
        if (b & 1) { r += a; if (r >= m) r -= m; }
        a <<= 1; if (a >= m) a -= m;
        b >>= 1;
    }
    return r;
}

static quint64 ebob(quint64 a, quint64 b) { while (b) { const quint64 t = a % b; a = b; b = t; } return a; }

bool Sifre::carpanla(quint64 pq, quint64 &p, quint64 &q)
{
    if (pq < 4) return false;
    if (!(pq & 1)) { p = 2; q = pq / 2; return true; }
    for (quint64 c = 1; c < 50; ++c) {
        quint64 y = 2 + c, x = y, g = 1, ys = y, rr = 1, k;
        const quint64 m = 128;
        quint64 qq = 1;
        while (g == 1) {
            x = y;
            for (quint64 i = 0; i < rr; ++i) y = (mulmod(y, y, pq) + c) % pq;
            k = 0;
            while (k < rr && g == 1) {
                ys = y;
                const quint64 lim = (m < rr - k) ? m : (rr - k);
                for (quint64 i = 0; i < lim; ++i) {
                    y = (mulmod(y, y, pq) + c) % pq;
                    qq = mulmod(qq, (x > y ? x - y : y - x), pq);
                }
                g = ebob(qq, pq);
                k += m;
            }
            rr <<= 1;
            if (rr > (quint64(1) << 40)) break;
        }
        if (g == pq) {
            do { ys = (mulmod(ys, ys, pq) + c) % pq; g = ebob(x > ys ? x - ys : ys - x, pq); } while (g == 1);
        }
        if (g != pq && g > 1) {
            p = g; q = pq / g;
            if (p > q) { const quint64 t = p; p = q; q = t; }
            return true;
        }
    }
    return false;
}

// ======================================================================= SHA-512 / PBKDF2
static const quint64 K512[80] = {
    Q_UINT64_C(0x428a2f98d728ae22), Q_UINT64_C(0x7137449123ef65cd), Q_UINT64_C(0xb5c0fbcfec4d3b2f), Q_UINT64_C(0xe9b5dba58189dbbc),
    Q_UINT64_C(0x3956c25bf348b538), Q_UINT64_C(0x59f111f1b605d019), Q_UINT64_C(0x923f82a4af194f9b), Q_UINT64_C(0xab1c5ed5da6d8118),
    Q_UINT64_C(0xd807aa98a3030242), Q_UINT64_C(0x12835b0145706fbe), Q_UINT64_C(0x243185be4ee4b28c), Q_UINT64_C(0x550c7dc3d5ffb4e2),
    Q_UINT64_C(0x72be5d74f27b896f), Q_UINT64_C(0x80deb1fe3b1696b1), Q_UINT64_C(0x9bdc06a725c71235), Q_UINT64_C(0xc19bf174cf692694),
    Q_UINT64_C(0xe49b69c19ef14ad2), Q_UINT64_C(0xefbe4786384f25e3), Q_UINT64_C(0x0fc19dc68b8cd5b5), Q_UINT64_C(0x240ca1cc77ac9c65),
    Q_UINT64_C(0x2de92c6f592b0275), Q_UINT64_C(0x4a7484aa6ea6e483), Q_UINT64_C(0x5cb0a9dcbd41fbd4), Q_UINT64_C(0x76f988da831153b5),
    Q_UINT64_C(0x983e5152ee66dfab), Q_UINT64_C(0xa831c66d2db43210), Q_UINT64_C(0xb00327c898fb213f), Q_UINT64_C(0xbf597fc7beef0ee4),
    Q_UINT64_C(0xc6e00bf33da88fc2), Q_UINT64_C(0xd5a79147930aa725), Q_UINT64_C(0x06ca6351e003826f), Q_UINT64_C(0x142929670a0e6e70),
    Q_UINT64_C(0x27b70a8546d22ffc), Q_UINT64_C(0x2e1b21385c26c926), Q_UINT64_C(0x4d2c6dfc5ac42aed), Q_UINT64_C(0x53380d139d95b3df),
    Q_UINT64_C(0x650a73548baf63de), Q_UINT64_C(0x766a0abb3c77b2a8), Q_UINT64_C(0x81c2c92e47edaee6), Q_UINT64_C(0x92722c851482353b),
    Q_UINT64_C(0xa2bfe8a14cf10364), Q_UINT64_C(0xa81a664bbc423001), Q_UINT64_C(0xc24b8b70d0f89791), Q_UINT64_C(0xc76c51a30654be30),
    Q_UINT64_C(0xd192e819d6ef5218), Q_UINT64_C(0xd69906245565a910), Q_UINT64_C(0xf40e35855771202a), Q_UINT64_C(0x106aa07032bbd1b8),
    Q_UINT64_C(0x19a4c116b8d2d0c8), Q_UINT64_C(0x1e376c085141ab53), Q_UINT64_C(0x2748774cdf8eeb99), Q_UINT64_C(0x34b0bcb5e19b48a8),
    Q_UINT64_C(0x391c0cb3c5c95a63), Q_UINT64_C(0x4ed8aa4ae3418acb), Q_UINT64_C(0x5b9cca4f7763e373), Q_UINT64_C(0x682e6ff3d6b2b8a3),
    Q_UINT64_C(0x748f82ee5defb2fc), Q_UINT64_C(0x78a5636f43172f60), Q_UINT64_C(0x84c87814a1f0ab72), Q_UINT64_C(0x8cc702081a6439ec),
    Q_UINT64_C(0x90befffa23631e28), Q_UINT64_C(0xa4506cebde82bde9), Q_UINT64_C(0xbef9a3f7b2c67915), Q_UINT64_C(0xc67178f2e372532b),
    Q_UINT64_C(0xca273eceea26619c), Q_UINT64_C(0xd186b8c721c0c207), Q_UINT64_C(0xeada7dd6cde0eb1e), Q_UINT64_C(0xf57d4f7fee6ed178),
    Q_UINT64_C(0x06f067aa72176fba), Q_UINT64_C(0x0a637dc5a2c898a6), Q_UINT64_C(0x113f9804bef90dae), Q_UINT64_C(0x1b710b35131c471b),
    Q_UINT64_C(0x28db77f523047d84), Q_UINT64_C(0x32caab7b40c72493), Q_UINT64_C(0x3c9ebe0a15c9bebc), Q_UINT64_C(0x431d67c49c100d4c),
    Q_UINT64_C(0x4cc5d4becb3e42b6), Q_UINT64_C(0x597f299cfc657e2a), Q_UINT64_C(0x5fcb6fab3ad6faec), Q_UINT64_C(0x6c44198c4a475817) };

static inline quint64 rotr64(quint64 x, int n) { return (x >> n) | (x << (64 - n)); }

static void sha512Blok(quint64 *h, const uchar *p)
{
    quint64 w[80];
    for (int i = 0; i < 16; ++i) {
        quint64 v = 0;
        for (int k = 0; k < 8; ++k) v = (v << 8) | p[i * 8 + k];
        w[i] = v;
    }
    for (int i = 16; i < 80; ++i) {
        const quint64 s0 = rotr64(w[i - 15], 1) ^ rotr64(w[i - 15], 8) ^ (w[i - 15] >> 7);
        const quint64 s1 = rotr64(w[i - 2], 19) ^ rotr64(w[i - 2], 61) ^ (w[i - 2] >> 6);
        w[i] = w[i - 16] + s0 + w[i - 7] + s1;
    }
    quint64 a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
    for (int i = 0; i < 80; ++i) {
        const quint64 S1 = rotr64(e, 14) ^ rotr64(e, 18) ^ rotr64(e, 41);
        const quint64 ch = (e & f) ^ (~e & g);
        const quint64 t1 = hh + S1 + ch + K512[i] + w[i];
        const quint64 S0 = rotr64(a, 28) ^ rotr64(a, 34) ^ rotr64(a, 39);
        const quint64 maj = (a & b) ^ (a & c) ^ (b & c);
        const quint64 t2 = S0 + maj;
        hh = g; g = f; f = e; e = d + t1; d = c; c = b; b = a; a = t1 + t2;
    }
    h[0] += a; h[1] += b; h[2] += c; h[3] += d; h[4] += e; h[5] += f; h[6] += g; h[7] += hh;
}

static const quint64 H512[8] = {
    Q_UINT64_C(0x6a09e667f3bcc908), Q_UINT64_C(0xbb67ae8584caa73b), Q_UINT64_C(0x3c6ef372fe94f82b), Q_UINT64_C(0xa54ff53a5f1d36f1),
    Q_UINT64_C(0x510e527fade682d1), Q_UINT64_C(0x9b05688c2b3e6c1f), Q_UINT64_C(0x1f83d9abfb41bd6b), Q_UINT64_C(0x5be0cd19137e2179) };

static QByteArray sha512Bitir(quint64 *h, const QByteArray &kalan, quint64 toplamBayt)
{
    QByteArray m = kalan;
    m.append(char(0x80));
    while (m.size() % 128 != 112) m.append(char(0));
    m.append(QByteArray(8, 0));
    const quint64 bit = toplamBayt * 8;
    for (int i = 7; i >= 0; --i) m.append(char((bit >> (i * 8)) & 0xff));
    for (int i = 0; i < m.size(); i += 128) sha512Blok(h, reinterpret_cast<const uchar *>(m.constData()) + i);
    QByteArray out(64, 0);
    for (int i = 0; i < 8; ++i) for (int k = 0; k < 8; ++k) out[i * 8 + k] = char((h[i] >> (56 - k * 8)) & 0xff);
    return out;
}

QByteArray Sifre::sha512(const QByteArray &veri)
{
    quint64 h[8];
    memcpy(h, H512, sizeof(h));
    const int tam = veri.size() / 128 * 128;
    for (int i = 0; i < tam; i += 128) sha512Blok(h, reinterpret_cast<const uchar *>(veri.constData()) + i);
    return sha512Bitir(h, veri.mid(tam), quint64(veri.size()));
}

// HMAC-SHA512, ic/dis durumlar bir kez hesaplanir: 100.000 tur PBKDF2 icin onemli
QByteArray Sifre::pbkdf2Sha512(const QByteArray &parola, const QByteArray &tuz, int tur, int uzunluk)
{
    QByteArray anahtar = parola.size() > 128 ? sha512(parola) : parola;
    anahtar.append(QByteArray(128 - anahtar.size(), 0));
    QByteArray ipad(128, 0), opad(128, 0);
    for (int i = 0; i < 128; ++i) { ipad[i] = char(anahtar.at(i) ^ 0x36); opad[i] = char(anahtar.at(i) ^ 0x5c); }
    quint64 icDurum[8], disDurum[8];
    memcpy(icDurum, H512, sizeof(icDurum));
    memcpy(disDurum, H512, sizeof(disDurum));
    sha512Blok(icDurum, reinterpret_cast<const uchar *>(ipad.constData()));
    sha512Blok(disDurum, reinterpret_cast<const uchar *>(opad.constData()));

    QByteArray sonuc;
    for (quint32 blok = 1; sonuc.size() < uzunluk; ++blok) {
        QByteArray u = tuz;
        u.append(char(blok >> 24)); u.append(char(blok >> 16)); u.append(char(blok >> 8)); u.append(char(blok));
        // U1 = HMAC(parola, tuz || blok)
        quint64 h[8];
        memcpy(h, icDurum, sizeof(h));
        {
            const int tam = u.size() / 128 * 128;
            for (int i = 0; i < tam; i += 128) sha512Blok(h, reinterpret_cast<const uchar *>(u.constData()) + i);
            u = sha512Bitir(h, u.mid(tam), 128 + quint64(u.size()));
        }
        memcpy(h, disDurum, sizeof(h));
        u = sha512Bitir(h, u, 128 + 64);
        QByteArray t = u;
        for (int i = 1; i < tur; ++i) {
            memcpy(h, icDurum, sizeof(h));
            u = sha512Bitir(h, u, 128 + 64);
            memcpy(h, disDurum, sizeof(h));
            u = sha512Bitir(h, u, 128 + 64);
            for (int k = 0; k < 64; ++k) t[k] = char(t.at(k) ^ u.at(k));
        }
        sonuc.append(t);
    }
    return sonuc.left(uzunluk);
}