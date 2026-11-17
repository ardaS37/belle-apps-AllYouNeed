// BelleGram buyuk sayi: isaretsiz, 32 bitlik basamaklar (kucukten buyuge). RSA ve Diffie-Hellman icin
// yalnizca gereken islemler: karsilastirma, cikarma, carpma, mod, modlu us alma.
#ifndef TG_BUYUKSAYI_H
#define TG_BUYUKSAYI_H

#include <QtCore/QByteArray>
#include <QtCore/QVector>

class BuyukSayi
{
public:
    BuyukSayi() {}
    explicit BuyukSayi(quint32 v) { if (v) b.append(v); }
    static BuyukSayi baytlardan(const QByteArray &buyukSonlu);   // buyuk sonlu (big-endian) bayt dizisi
    QByteArray baytlar(int uzunluk = 0) const;                   // buyuk sonlu; uzunluk verilirse basa 0 eklenir

    bool sifir() const { return b.isEmpty(); }
    int bitSayisi() const;
    bool bit(int i) const { return i / 32 < b.size() && (b[i / 32] >> (i % 32)) & 1; }

    static int karsilastir(const BuyukSayi &x, const BuyukSayi &y);
    static BuyukSayi topla(const BuyukSayi &x, const BuyukSayi &y);
    static BuyukSayi cikar(const BuyukSayi &x, const BuyukSayi &y);     // x >= y olmali
    static BuyukSayi carp(const BuyukSayi &x, const BuyukSayi &y);
    static BuyukSayi mod(const BuyukSayi &x, const BuyukSayi &m);
    static BuyukSayi usMod(const BuyukSayi &taban, const BuyukSayi &us, const BuyukSayi &m);

    bool operator<(const BuyukSayi &o) const { return karsilastir(*this, o) < 0; }
    bool operator>=(const BuyukSayi &o) const { return karsilastir(*this, o) >= 0; }
    bool operator==(const BuyukSayi &o) const { return karsilastir(*this, o) == 0; }

private:
    void kirp() { while (!b.isEmpty() && b.last() == 0) b.pop_back(); }
    QVector<quint32> b;
};

#endif
