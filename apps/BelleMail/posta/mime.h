// E-posta kodlama yardimcilari: RFC 2047 basliklar, base64 / quoted-printable govdeler,
// karakter kumeleri, IMAP klasor adlari (degistirilmis UTF-7), HTML'den duz metin (onizleme).
#ifndef POSTA_MIME_H
#define POSTA_MIME_H

#include <QtCore/QByteArray>
#include <QtCore/QString>
#include <QtCore/QDateTime>

namespace Mime {
    // "=?UTF-8?B?...?=" / "=?iso-8859-9?Q?...?=" parcalarini cozer; kodlanmamis kisim UTF-8 (yoksa Latin-1) sayilir
    QString baslikCoz(const QByteArray &s);
    // RFC 2231: utf-8''G%C3%B6r%C3%BCnt%C3%BC.jpg
    QString rfc2231Coz(const QByteArray &s);
    // Content-Transfer-Encoding cozumu (base64 yarim kalmissa kirpilir)
    QByteArray aktarimCoz(const QByteArray &veri, const QByteArray &kodlama);
    // bayt -> metin (karakter kumesi bilinmiyorsa/gecersizse UTF-8, o da bozuksa Windows-1254)
    QString metne(const QByteArray &veri, const QByteArray &charset);
    // IMAP klasor adi (RFC 3501 5.1.3)
    QString utf7Coz(const QByteArray &s);
    // HTML -> tek satirlik duz metin (liste onizlemesi icin)
    QString htmldenMetin(const QString &html);
    // ASCII disi karakter varsa =?UTF-8?B?...?=
    QByteArray baslikKodla(const QString &s);
    // RFC 2822 tarihi -> UTC zamani (gecersizse bos)
    QDateTime tarihCoz(const QByteArray &s);
    // RFC 2822 bicimli simdiki zaman ("Wed, 18 Nov 2026 10:22:33 +0300")
    QByteArray simdi();
}

#endif
