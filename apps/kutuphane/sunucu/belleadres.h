#ifndef BELLEADRES_H
#define BELLEADRES_H

// Belle uygulamalarinin sunucu adresi ve HTTPS hazirligi (ortak).
//  - Varsayilan sunucu: https://e6.msahincelen.xyz (TLS 1.2, Let's Encrypt RSA sertifikasi)
//  - Eski IP adresi (http://YOUR-SERVER) kayitliysa kendiliginden yeni adrese tasinir.
//  - Telefonun kok sertifika deposu eski: guncel kokler (ISRG Root X1 vb.) eklenir; dogrulama KAPATILMAZ.
//  - Telefonun yerlesik oynaticisi (MMF) TLS 1.2 bilmez: ona verilecek sunucu adresleri belleDuzHttp() ile
//    duz HTTP'ye cevrilir (sunucu e6 adresinde HTTP'yi de yonlendirmesiz acik tutar).
// Kullanim: .pro'ya  include(../kutuphane/sunucu/sunucu.pri)  ve main()'de  belleKokSertifikalariYukle();

#include <QtCore/QString>
#include <QtCore/QFile>
#include <QtNetwork/QSslSocket>
#include <QtNetwork/QSslCertificate>

inline QString belleVarsayilanSunucu() { return QString("https://e6.msahincelen.xyz"); }

// Bos ya da eski IP adresi -> yeni adres; sondaki "/" atilir, semasiz adrese http:// eklenir
inline QString belleSunucuTasi(const QString &in)
{
    QString s = in.trimmed();
    while (s.endsWith('/')) s.chop(1);
    if (s.isEmpty() || s.contains(QLatin1String("203.0.113.10"))) return belleVarsayilanSunucu();
    if (!s.contains(QLatin1String("://"))) s = QLatin1String("http://") + s;
    return s;
}

// Yerlesik oynatici icin: https://<bizim sunucu> -> http://<bizim sunucu>
inline QString belleDuzHttp(const QString &url)
{
    if (url.startsWith(QLatin1String("https://e6.msahincelen.xyz"))) return QLatin1String("http://") + url.mid(8);
    return url;
}

inline void belleKokSertifikalariYukle()
{
    QFile pem(":/sunucu/roots.pem");
    if (pem.open(QIODevice::ReadOnly)) {
        const QList<QSslCertificate> kokler = QSslCertificate::fromData(pem.readAll(), QSsl::Pem);
        if (!kokler.isEmpty()) QSslSocket::addDefaultCaCertificates(kokler);
    }
}

#endif
