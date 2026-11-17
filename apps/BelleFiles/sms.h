#ifndef BELLE_SMS_H
#define BELLE_SMS_H

// SMS yedegi: Symbian mesaj sunucusu (CMsvSession) ile Gelen / Gonderilen / Taslaklar / Giden / Klasorlerim.
// Bicim: Android "SMS Backup & Restore" XML'i (<smses><sms address date type body read .../></smses>).
//   type: 1 gelen, 2 gonderilen, 3 taslak, 4 giden.  date: 1970'ten beri milisaniye (UTC).
// Geri yukleme: ayni numara + ayni zaman (saniye) + ayni metin varsa atlanir; giden kutusundakiler
// gonderilmesin diye Taslaklar'a yazilir. Yetki: ReadUserData (okuma), WriteUserData (geri yukleme).

#include <QtCore/QString>

class QObject;

namespace Sms {
    int say(QString *hata);
    bool yedekle(const QString &xmlYolu, int *adet, QString *hata);
    bool geriYukle(const QString &xmlYolu, int *eklenen, int *atlanan, int *hatali, QString *hata);
}

#endif
