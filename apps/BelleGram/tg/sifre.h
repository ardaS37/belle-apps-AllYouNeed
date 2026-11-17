// BelleGram sifreleme yardimcilari: SHA-1 (Qt), SHA-256, AES-256 (IGE kipi), rastgele bayt, gzip acma.
// MTProto 2.0 icin gereken her sey; dis kutuphane yok (Qt 4.7.4, Symbian GCCE ve masaustu MinGW).
#ifndef TG_SIFRE_H
#define TG_SIFRE_H

#include <QtCore/QByteArray>

namespace Sifre {

QByteArray sha1(const QByteArray &veri);
QByteArray sha256(const QByteArray &veri);
QByteArray sha512(const QByteArray &veri);
// PBKDF2-HMAC-SHA512 (iki adimli dogrulama / SRP)
QByteArray pbkdf2Sha512(const QByteArray &parola, const QByteArray &tuz, int tur, int uzunluk = 64);

// AES-256-IGE: anahtar 32 bayt, iv 32 bayt (iv1 = ilk 16, iv2 = son 16), veri 16'nin kati
QByteArray igeSifrele(const QByteArray &veri, const QByteArray &anahtar, const QByteArray &iv);
QByteArray igeCoz(const QByteArray &veri, const QByteArray &anahtar, const QByteArray &iv);

// Kriptografik olarak yeterli rastgele baytlar (SHA-256 tabanli uretec, saat + sistem entropisiyle beslenir)
QByteArray rastgele(int n);

// gzip_packed icin: gzip (RFC 1952) ya da ham deflate verisini acar; hata olursa bos doner
QByteArray gzipAc(const QByteArray &gz);

// 64 bitlik pq'yu iki asal carpana ayirir (Pollard rho, Brent). p < q
bool carpanla(quint64 pq, quint64 &p, quint64 &q);

}

#endif
