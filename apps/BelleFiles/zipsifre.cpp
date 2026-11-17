#include "zipsifre.h"
#include "zip.h"

#include <string.h>

namespace ZipSifre {

// ---------------- ZipCrypto ----------------

static quint32 crcBayt(quint32 crc, uchar c)
{
    // Zip::crc32 tum diziyi ters cevirerek isler; burada ham CRC guncellemesi gerekir
    static quint32 t[256];
    static bool hazir = false;
    if (!hazir) {
        for (quint32 i = 0; i < 256; ++i) {
            quint32 x = i;
            for (int k = 0; k < 8; ++k) x = (x & 1) ? 0xEDB88320u ^ (x >> 1) : x >> 1;
            t[i] = x;
        }
        hazir = true;
    }
    return t[(crc ^ c) & 0xff] ^ (crc >> 8);
}

void ZipCrypto::guncelle(uchar c)
{
    m_k0 = crcBayt(m_k0, c);
    m_k1 = (m_k1 + (m_k0 & 0xff)) * 134775813u + 1;
    m_k2 = crcBayt(m_k2, uchar(m_k1 >> 24));
}

void ZipCrypto::kur(const QByteArray &parola)
{
    m_k0 = 0x12345678u; m_k1 = 0x23456789u; m_k2 = 0x34567890u;
    for (int i = 0; i < parola.size(); ++i) guncelle(uchar(parola.at(i)));
}

void ZipCrypto::coz(char *p, qint64 n)
{
    for (qint64 i = 0; i < n; ++i) {
        const quint16 t = quint16(m_k2 | 2);
        const uchar c = uchar(p[i]) ^ uchar((t * (t ^ 1)) >> 8);
        guncelle(c);
        p[i] = char(c);
    }
}

// ---------------- SHA-1 ----------------

static inline quint32 rol(quint32 x, int n) { return (x << n) | (x >> (32 - n)); }

void Sha1::sifirla()
{
    m_h[0] = 0x67452301u; m_h[1] = 0xEFCDAB89u; m_h[2] = 0x98BADCFEu; m_h[3] = 0x10325476u; m_h[4] = 0xC3D2E1F0u;
    m_len = 0; m_toplam = 0;
}

void Sha1::blok(const uchar *b)
{
    quint32 w[80];
    for (int i = 0; i < 16; ++i) w[i] = (quint32(b[i * 4]) << 24) | (quint32(b[i * 4 + 1]) << 16) | (quint32(b[i * 4 + 2]) << 8) | b[i * 4 + 3];
    for (int i = 16; i < 80; ++i) w[i] = rol(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
    quint32 a = m_h[0], bb = m_h[1], c = m_h[2], d = m_h[3], e = m_h[4];
    for (int i = 0; i < 80; ++i) {
        quint32 f, k;
        if (i < 20) { f = (bb & c) | (~bb & d); k = 0x5A827999u; }
        else if (i < 40) { f = bb ^ c ^ d; k = 0x6ED9EBA1u; }
        else if (i < 60) { f = (bb & c) | (bb & d) | (c & d); k = 0x8F1BBCDCu; }
        else { f = bb ^ c ^ d; k = 0xCA62C1D6u; }
        const quint32 t = rol(a, 5) + f + e + k + w[i];
        e = d; d = c; c = rol(bb, 30); bb = a; a = t;
    }
    m_h[0] += a; m_h[1] += bb; m_h[2] += c; m_h[3] += d; m_h[4] += e;
}

void Sha1::ekle(const char *p, qint64 n)
{
    m_toplam += quint64(n);
    while (n > 0) {
        const int al = int(qMin<qint64>(64 - m_len, n));
        memcpy(m_buf + m_len, p, al);
        m_len += al; p += al; n -= al;
        if (m_len == 64) { blok(m_buf); m_len = 0; }
    }
}

QByteArray Sha1::bitir()
{
    const quint64 bit = m_toplam * 8;
    const char bir = char(0x80), sifir = 0;
    ekle(&bir, 1);
    while (m_len != 56) ekle(&sifir, 1);
    char uz[8];
    for (int i = 0; i < 8; ++i) uz[i] = char(bit >> (56 - 8 * i));
    ekle(uz, 8);
    QByteArray o(20, 0);
    for (int i = 0; i < 5; ++i) {
        o[i * 4] = char(m_h[i] >> 24); o[i * 4 + 1] = char(m_h[i] >> 16);
        o[i * 4 + 2] = char(m_h[i] >> 8); o[i * 4 + 3] = char(m_h[i]);
    }
    return o;
}

// ---------------- HMAC-SHA1 / PBKDF2 ----------------

void HmacSha1::kur(const QByteArray &anahtar)
{
    QByteArray k = anahtar;
    if (k.size() > 64) { Sha1 s; s.ekle(k.constData(), k.size()); k = s.bitir(); }
    k.append(QByteArray(64 - k.size(), 0));
    QByteArray ic(64, 0);
    m_dis = QByteArray(64, 0);
    for (int i = 0; i < 64; ++i) { ic[i] = char(k.at(i) ^ 0x36); m_dis[i] = char(k.at(i) ^ 0x5c); }
    m_ic.sifirla();
    m_ic.ekle(ic.constData(), 64);
}

QByteArray HmacSha1::bitir()
{
    const QByteArray icSonuc = m_ic.bitir();
    Sha1 s;
    s.ekle(m_dis.constData(), 64);
    s.ekle(icSonuc.constData(), icSonuc.size());
    return s.bitir();
}

QByteArray pbkdf2Sha1(const QByteArray &parola, const QByteArray &tuz, int tur, int uzunluk)
{
    QByteArray sonuc;
    for (quint32 blokNo = 1; sonuc.size() < uzunluk; ++blokNo) {
        QByteArray s = tuz;
        s.append(char(blokNo >> 24)); s.append(char(blokNo >> 16)); s.append(char(blokNo >> 8)); s.append(char(blokNo));
        HmacSha1 h; h.kur(parola); h.ekle(s.constData(), s.size());
        QByteArray u = h.bitir(), t = u;
        for (int i = 1; i < tur; ++i) {
            HmacSha1 h2; h2.kur(parola); h2.ekle(u.constData(), u.size());
            u = h2.bitir();
            for (int j = 0; j < 20; ++j) t[j] = char(t.at(j) ^ u.at(j));
        }
        sonuc.append(t);
    }
    return sonuc.left(uzunluk);
}

// ---------------- AES (yalniz sifreleme yonu: CTR icin yeterli) ----------------

static uchar KSbox[256];
static bool KSboxHazir = false;

static inline uchar xtime(uchar x) { return uchar((x << 1) ^ ((x & 0x80) ? 0x1b : 0)); }

static void sboxKur()
{
    if (KSboxHazir) return;
    // GF(2^8) ters + afin donusum
    uchar p = 1, q = 1;
    do {
        p = uchar(p ^ (p << 1) ^ ((p & 0x80) ? 0x1b : 0));      // p *= 3
        q ^= uchar(q << 1); q ^= uchar(q << 2); q ^= uchar(q << 4);   // q /= 3
        if (q & 0x80) q ^= 0x09;
        const uchar x = uchar(q ^ ((q << 1) | (q >> 7)) ^ ((q << 2) | (q >> 6)) ^ ((q << 3) | (q >> 5)) ^ ((q << 4) | (q >> 4)));
        KSbox[p] = uchar(x ^ 0x63);
    } while (p != 1);
    KSbox[0] = 0x63;
    KSboxHazir = true;
}

bool Aes::kur(const QByteArray &anahtar)
{
    sboxKur();
    const int nk = anahtar.size() / 4;
    if (nk != 4 && nk != 6 && nk != 8) return false;
    m_nr = nk + 6;
    const uchar *k = (const uchar *)anahtar.constData();
    for (int i = 0; i < nk; ++i) m_rk[i] = (quint32(k[4 * i]) << 24) | (quint32(k[4 * i + 1]) << 16) | (quint32(k[4 * i + 2]) << 8) | k[4 * i + 3];
    uchar rcon = 1;
    for (int i = nk; i < 4 * (m_nr + 1); ++i) {
        quint32 t = m_rk[i - 1];
        if (i % nk == 0) {
            t = (t << 8) | (t >> 24);
            t = (quint32(KSbox[t >> 24]) << 24) | (quint32(KSbox[(t >> 16) & 0xff]) << 16) | (quint32(KSbox[(t >> 8) & 0xff]) << 8) | KSbox[t & 0xff];
            t ^= quint32(rcon) << 24;
            rcon = xtime(rcon);
        } else if (nk > 6 && i % nk == 4) {
            t = (quint32(KSbox[t >> 24]) << 24) | (quint32(KSbox[(t >> 16) & 0xff]) << 16) | (quint32(KSbox[(t >> 8) & 0xff]) << 8) | KSbox[t & 0xff];
        }
        m_rk[i] = m_rk[i - nk] ^ t;
    }
    return true;
}

void Aes::sifrele(const uchar in[16], uchar out[16]) const
{
    uchar s[16];
    for (int c = 0; c < 4; ++c)
        for (int r = 0; r < 4; ++r) s[c * 4 + r] = uchar(in[c * 4 + r] ^ (m_rk[c] >> (24 - 8 * r)));
    for (int tur = 1; tur <= m_nr; ++tur) {
        uchar t[16];
        // SubBytes + ShiftRows
        for (int c = 0; c < 4; ++c)
            for (int r = 0; r < 4; ++r) t[c * 4 + r] = KSbox[s[((c + r) & 3) * 4 + r]];
        // MixColumns (son turda yok)
        if (tur != m_nr) {
            for (int c = 0; c < 4; ++c) {
                const uchar a0 = t[c * 4], a1 = t[c * 4 + 1], a2 = t[c * 4 + 2], a3 = t[c * 4 + 3];
                const uchar h = uchar(a0 ^ a1 ^ a2 ^ a3);
                t[c * 4]     = uchar(a0 ^ h ^ xtime(uchar(a0 ^ a1)));
                t[c * 4 + 1] = uchar(a1 ^ h ^ xtime(uchar(a1 ^ a2)));
                t[c * 4 + 2] = uchar(a2 ^ h ^ xtime(uchar(a2 ^ a3)));
                t[c * 4 + 3] = uchar(a3 ^ h ^ xtime(uchar(a3 ^ a0)));
            }
        }
        for (int c = 0; c < 4; ++c)
            for (int r = 0; r < 4; ++r) s[c * 4 + r] = uchar(t[c * 4 + r] ^ (m_rk[tur * 4 + c] >> (24 - 8 * r)));
    }
    memcpy(out, s, 16);
}

bool AesCtr::kur(const QByteArray &anahtar)
{
    memset(m_sayac, 0, 16);
    m_kul = 16;
    return m_aes.kur(anahtar);
}

void AesCtr::coz(char *p, qint64 n)
{
    for (qint64 i = 0; i < n; ++i) {
        if (m_kul == 16) {
            for (int j = 0; j < 16; ++j) if (++m_sayac[j] != 0) break;   // kucuk-uclu artir
            m_aes.sifrele(m_sayac, m_akis);
            m_kul = 0;
        }
        p[i] = char(uchar(p[i]) ^ m_akis[m_kul++]);
    }
}

}
