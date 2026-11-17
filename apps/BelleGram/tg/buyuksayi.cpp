#include "buyuksayi.h"

BuyukSayi BuyukSayi::baytlardan(const QByteArray &v)
{
    BuyukSayi r;
    const int n = v.size();
    r.b.fill(0, (n + 3) / 4);
    for (int i = 0; i < n; ++i) {
        const quint32 bayt = uchar(v.at(n - 1 - i));
        r.b[i / 4] |= bayt << ((i % 4) * 8);
    }
    r.kirp();
    return r;
}

QByteArray BuyukSayi::baytlar(int uzunluk) const
{
    QByteArray out;
    for (int i = b.size() - 1; i >= 0; --i)
        for (int k = 3; k >= 0; --k) out.append(char((b[i] >> (k * 8)) & 0xff));
    int bas = 0;
    while (bas < out.size() && out.at(bas) == 0) ++bas;
    out = out.mid(bas);
    if (uzunluk > out.size()) out.prepend(QByteArray(uzunluk - out.size(), 0));
    return out;
}

int BuyukSayi::bitSayisi() const
{
    if (b.isEmpty()) return 0;
    int n = (b.size() - 1) * 32;
    quint32 son = b.last();
    while (son) { ++n; son >>= 1; }
    return n;
}

int BuyukSayi::karsilastir(const BuyukSayi &x, const BuyukSayi &y)
{
    if (x.b.size() != y.b.size()) return x.b.size() < y.b.size() ? -1 : 1;
    for (int i = x.b.size() - 1; i >= 0; --i)
        if (x.b[i] != y.b[i]) return x.b[i] < y.b[i] ? -1 : 1;
    return 0;
}

BuyukSayi BuyukSayi::topla(const BuyukSayi &x, const BuyukSayi &y)
{
    BuyukSayi r;
    const int n = qMax(x.b.size(), y.b.size());
    r.b.resize(n + 1);
    quint64 elde = 0;
    for (int i = 0; i < n; ++i) {
        const quint64 t = quint64(i < x.b.size() ? x.b[i] : 0) + (i < y.b.size() ? y.b[i] : 0) + elde;
        r.b[i] = quint32(t);
        elde = t >> 32;
    }
    r.b[n] = quint32(elde);
    r.kirp();
    return r;
}

BuyukSayi BuyukSayi::cikar(const BuyukSayi &x, const BuyukSayi &y)
{
    BuyukSayi r = x;
    quint64 odunc = 0;
    for (int i = 0; i < r.b.size(); ++i) {
        const quint64 yi = (i < y.b.size() ? y.b[i] : 0) + odunc;
        if (quint64(r.b[i]) >= yi) { r.b[i] = quint32(quint64(r.b[i]) - yi); odunc = 0; }
        else { r.b[i] = quint32((quint64(1) << 32) + r.b[i] - yi); odunc = 1; }
    }
    r.kirp();
    return r;
}

BuyukSayi BuyukSayi::carp(const BuyukSayi &x, const BuyukSayi &y)
{
    BuyukSayi r;
    if (x.sifir() || y.sifir()) return r;
    r.b.fill(0, x.b.size() + y.b.size());
    for (int i = 0; i < x.b.size(); ++i) {
        quint64 elde = 0;
        const quint64 xi = x.b[i];
        for (int j = 0; j < y.b.size(); ++j) {
            const quint64 t = xi * y.b[j] + r.b[i + j] + elde;
            r.b[i + j] = quint32(t);
            elde = t >> 32;
        }
        int k = i + y.b.size();
        while (elde) {
            const quint64 t = quint64(r.b[k]) + elde;
            r.b[k] = quint32(t);
            elde = t >> 32;
            ++k;
        }
    }
    r.kirp();
    return r;
}

// Knuth, Algoritma D (TAOCP 4.3.1): yalnizca kalan
BuyukSayi BuyukSayi::mod(const BuyukSayi &x, const BuyukSayi &m)
{
    if (m.sifir()) return BuyukSayi();
    if (karsilastir(x, m) < 0) return x;
    const int n = m.b.size();
    if (n == 1) {
        quint64 kalan = 0;
        for (int i = x.b.size() - 1; i >= 0; --i) kalan = ((kalan << 32) | x.b[i]) % m.b[0];
        return BuyukSayi(quint32(kalan));
    }
    // normallestir: bolenin en yuksek basamaginin ust biti 1 olsun
    int s = 0;
    quint32 ust = m.b[n - 1];
    while (!(ust & 0x80000000u)) { ust <<= 1; ++s; }
    QVector<quint32> v(n), u(x.b.size() + 1);
    for (int i = n - 1; i > 0; --i) v[i] = (m.b[i] << s) | (s ? quint32(quint64(m.b[i - 1]) >> (32 - s)) : 0);
    v[0] = m.b[0] << s;
    u[x.b.size()] = s ? quint32(quint64(x.b[x.b.size() - 1]) >> (32 - s)) : 0;
    for (int i = x.b.size() - 1; i > 0; --i) u[i] = (x.b[i] << s) | (s ? quint32(quint64(x.b[i - 1]) >> (32 - s)) : 0);
    u[0] = x.b[0] << s;

    const quint64 B = quint64(1) << 32;
    for (int j = x.b.size() - n; j >= 0; --j) {
        const quint64 ust2 = (quint64(u[j + n]) << 32) | u[j + n - 1];
        quint64 qhat = ust2 / v[n - 1];
        quint64 rhat = ust2 % v[n - 1];
        while (qhat >= B || qhat * v[n - 2] > ((rhat << 32) | u[j + n - 2])) {
            --qhat;
            rhat += v[n - 1];
            if (rhat >= B) break;
        }
        // u[j..j+n] -= qhat * v
        qint64 odunc = 0;
        quint64 elde = 0;
        for (int i = 0; i < n; ++i) {
            const quint64 p = qhat * v[i] + elde;
            elde = p >> 32;
            const qint64 t = qint64(u[i + j]) - qint64(p & 0xffffffffu) - odunc;
            u[i + j] = quint32(t);
            odunc = t < 0 ? 1 : 0;
        }
        const qint64 t = qint64(u[j + n]) - qint64(elde) - odunc;
        u[j + n] = quint32(t);
        if (t < 0) {
            // fazla cikarildi: bir kez geri ekle
            quint64 c = 0;
            for (int i = 0; i < n; ++i) {
                const quint64 sum = quint64(u[i + j]) + v[i] + c;
                u[i + j] = quint32(sum);
                c = sum >> 32;
            }
            u[j + n] = quint32(quint64(u[j + n]) + c);
        }
    }
    // kalan = u[0..n-1] >> s
    BuyukSayi r;
    r.b.resize(n);
    for (int i = 0; i < n - 1; ++i) r.b[i] = (u[i] >> s) | (s ? quint32(quint64(u[i + 1]) << (32 - s)) : 0);
    r.b[n - 1] = u[n - 1] >> s;
    r.kirp();
    return r;
}

BuyukSayi BuyukSayi::usMod(const BuyukSayi &taban, const BuyukSayi &us, const BuyukSayi &m)
{
    BuyukSayi sonuc(1);
    BuyukSayi t = mod(taban, m);
    const int nb = us.bitSayisi();
    for (int i = nb - 1; i >= 0; --i) {
        sonuc = mod(carp(sonuc, sonuc), m);
        if (us.bit(i)) sonuc = mod(carp(sonuc, t), m);
    }
    return mod(sonuc, m);
}
