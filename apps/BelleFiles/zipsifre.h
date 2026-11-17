#ifndef BELLE_ZIPSIFRE_H
#define BELLE_ZIPSIFRE_H

// Sifreli zip cozme (dis kutuphane yok):
//  - ZipCrypto: klasik PKWARE sifresi (Windows "parola ile sikistir", eski WinZip/WinRAR zip)
//  - WinZip AES (AE-1 / AE-2, yontem 99): 7-Zip, WinRAR, WinZip "AES-256" zip'leri
//    PBKDF2-HMAC-SHA1 (1000 tur) + AES-CTR (kucuk-uclu sayac) + HMAC-SHA1 dogrulama

#include <QtCore/QByteArray>

namespace ZipSifre {

class ZipCrypto
{
public:
    void kur(const QByteArray &parola);
    void coz(char *p, qint64 n);
private:
    void guncelle(uchar c);
    quint32 m_k0, m_k1, m_k2;
};

class Sha1
{
public:
    Sha1() { sifirla(); }
    void sifirla();
    void ekle(const char *p, qint64 n);
    QByteArray bitir();                 // 20 bayt
private:
    void blok(const uchar *b);
    quint32 m_h[5];
    uchar m_buf[64];
    int m_len;
    quint64 m_toplam;
};

class HmacSha1
{
public:
    void kur(const QByteArray &anahtar);
    void ekle(const char *p, qint64 n) { m_ic.ekle(p, n); }
    QByteArray bitir();
private:
    Sha1 m_ic;
    QByteArray m_dis;                   // 64 baytlik anahtar ^ 0x5c
};

QByteArray pbkdf2Sha1(const QByteArray &parola, const QByteArray &tuz, int tur, int uzunluk);

class Aes
{
public:
    bool kur(const QByteArray &anahtar);   // 16 / 24 / 32 bayt
    void sifrele(const uchar in[16], uchar out[16]) const;
private:
    quint32 m_rk[60];
    int m_nr;
};

// WinZip AES-CTR: sayac 1'den baslar, 16 baytlik kucuk-uclu tamsayi
class AesCtr
{
public:
    bool kur(const QByteArray &anahtar);
    void coz(char *p, qint64 n);
private:
    Aes m_aes;
    uchar m_sayac[16];
    uchar m_akis[16];
    int m_kul;                          // akis bloğunda kullanilan bayt
};

}

#endif
