# Ortak kütüphane (Nokia E6 uygulamaları)

## pigler/ — durum çubuğu çekmecesi bildirimleri

Kaynak: https://github.com/piglerorg/pigler (master, 2026-11-09 indirildi, değiştirilmedi).
Lisans: **GPL-3.0**. Bunu kullanan uygulama dağıtılırsa o uygulamanın kaynağı da GPL ile açılmalı.

### Nasıl çalışır
- Telefona bir kez **Pigler eklentisi** (`piglerplugin.dll`, ECom gösterge eklentisi) kurulur.
  Sistem süreci içinde çalışır ve `CAPABILITY All -Tcb` ister. Bu yetki ancak hack'li telefona,
  kendi imzamızla kurulabilir. Kurulduktan sonra telefon yeniden başlatılmalı.
- Uygulamalar küçük istemci kütüphanesiyle eklentiye bağlanır. Bağlantı bir oturum üzerinden
  kurulur (sunucu adı `PiglerHandler_<uygulama adı>`) ve uygulamaya dokunma olayı geri gelir.

### Hazır eklenti paketi
`pigler/sis_hazir/Pigler.sis` (1.4.1, UID 0x20292B69). Kullanıcı 2026-11-09'da indirdi; içindeki paket
tanımı depodaki `plugin/sis/Pigler.pkg` ile aynı, DLL'ler `All -Tcb` yetkili. `PiglerJavaAPI.sis` ise
J2ME uygulamaları içindir.

**Uygulamanın SIS'ine gömmek** (tek kurulum; WhatsBelle böyle yapıyor):
```
pigler_embed.pkg_postrules = "@\"$$PWD/../kutuphane/pigler/sis_hazir/Pigler.sis\",(0x20292B69)"
DEPLOYMENT += pigler_embed
```

### Bir uygulamaya eklemek (Qt .pro)
```
symbian {
    include($$PWD/../kutuphane/pigler/qt-library/pigler.pri)   # QPiglerAPI + istemci, -lrandom -laknnotify
}
```
VM'de klasör düzeni aynı olmalı: `C:\<Uygulama>` ve `C:\kutuphane` (paylaşımdan xcopy).

```cpp
#include "QPiglerAPI.h"
QPiglerAPI *p = new QPiglerAPI(this);
p->setAppId(0xE39CF226);              // dokununca açılacak uygulamanın UID3'ü (init'ten ÖNCE)
qint32 r = p->init("WhatsE6");        // <0: eklenti yok; >0: uygulama bu bildirime dokunularak açıldı
connect(p, SIGNAL(handleTap(qint32)), this, SLOT(onTap(qint32)));
qint32 id = p->createNotification("Başlık", "Metin");   // her biri en fazla 63 karakter, 2 satır
p->updateNotification(id, "Başlık", "Yeni metin");
p->setNotificationIcon(id, QImage(":/images/ikon.png")); // 52 px'e küçültülür
p->setLaunchAppOnTap(id, false);      // uygulama açıkken ikinci kopya açılmasın (bkz. not)
p->removeNotification(id);  /  p->removeAllNotifications();
```
Örnek kullanım: `WhatsBelle/notify.cpp` içindeki `initPigler()`, `postKind()`, `onPiglerTap()` ve `clearPosted()`.
Eklenti yoksa WhatsBelle eski yönteme döner: köşe bildirimi ve sistemin "yeni sohbet mesajı" notu.

### Yetenekler (Belle)
- Çekmecede kendi metnimiz görünür: 2 satır, satır başına 63 karakter.
- Simge eklenebilir (68×68 alanda en fazla 52 px).
- Dokunulunca uygulamaya haber gelir (`handleTap`). İstenirse uygulama kapalıyken açılır.
- Dokununca bildirim kendiliğinden silinir (`setRemoveOnTap`).
- Uygulama başına en fazla 10, toplamda 100 bildirim.
- Uygulama kapalıyken dokunulan bildirim, sonraki `init()` dönüş değeriyle bildirilir.

### İyi yanları
- Belle'nin resmi SDK'sında olmayan çekmece bildirimini sağlar.
- Kendi metnimizi gösterir ve tıklanınca kendi uygulamamızı açar.
- Açık kaynaktır ve küçüktür. İstemci tarafı sıradan bir oturumdur; uygulamaya özel yetki istemez.
- Qt ve Java (J2ME) istemcisi var: MIDlet'ler de kullanabilir.

### Kötü yanları / riskler
- Eklenti, sistem sürecinde `All -Tcb` yetkisiyle çalışır. İçindeki bir hata telefonu
  kilitleyebilir ya da yeniden başlatabilir. Kurmadan önce yedek almak iyi olur.
- Kilit ekranında gösterilmez. Titreşim ve ses yoktur; bunları uygulama kendisi yapar.
- `setLaunchAppOnTap(true)` uygulama çalışırken ikinci kopyasını başlatabilir. Bu yüzden
  uygulama açıkken `false` kullanılır, kapanırken `true` yapılır.
- Kurulum ve kaldırmadan sonra yeniden başlatma gerekir.
- Eklenti yalnızca **Belle SDK** ile derlenir. Belle'ye özgü `CAknIndicatorPlugin::AddStatusPanelItemL`
  bizim Symbian3Qt474 SDK'mızda yok; istemci kütüphanesi ise bizim SDK'yla derlenir.
- GPL-3.0 lisanslıdır (yukarıya bakın).
