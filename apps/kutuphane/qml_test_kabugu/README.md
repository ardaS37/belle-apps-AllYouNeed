# QML test kabuğu (telefonsuz arayüz testi)

Uygulamanın QML arayüzünü, telefona SIS kurmadan, sanal makinedeki (win7) masaüstü **qmlviewer** ile açmaya yarar. Qt Simulator gerekmez, CODA gerekmez.

İlk kez 2026-11-09'da BelleVideo için yazıldı. Bulduğu hatalar:
- Ayarlar'daki nesnelerde `on:` anahtarı (QML'de ayrılmış kelime, sayfa hiç açılmıyordu)
- Başlıkta genişlik döngüsü (başlık yazısı görünmüyordu)
- Seçenek menüsünde ilk satırın yukarı kayması
- Seçili satır vurgusunun görünmemesi

## Nasıl çalışır

Telefon uygulamaları C++ nesnelerini QML'e verir (BelleVideo'da `lib`, `keys`, `sys`) ve kendi QML türlerini kaydeder (`NativeVideo`). Masaüstü qmlviewer'da bunlar yoktur. Kabuk iki yolla bunları taklit eder:

1. **`Harness.qml`**
   - `lib`, `keys`, `sys` adlı `QtObject`'ler tanımlar. İçlerinde aynı adlı özellikler, sinyaller ve örnek veri döndüren fonksiyonlar vardır.
   - Ardından gerçek `main.qml`'i bir `Loader` ile yükler.
   - QML'de üst bileşendeki id'ler yüklenen dosyanın içinden görünür. Bu yüzden `main.qml` içindeki `lib.videos()` gibi çağrılar taklitlere gider.
2. **Taklit modüller (`-I` ile verilir)**
   - `BelleVideo/` klasöründe `NativeVideo` var: yerel video penceresinin yerine gri bir dikdörtgen.
   - `QtMultimediaKit/` klasöründe `Audio` var: sesin yerine çalmayan bir taklit.
   - `import BelleVideo 1.0` ve `import QtMultimediaKit 1.1` satırları bunlara çözülür.

## Kullanım (VM)

1. Uygulama klasörünü `D:\WM\paylasim\<Uygulama>` altına kopyala. Bu klasörü de `D:\WM\paylasim\qmltest` olarak koy (VM'de `Z:\qmltest` olur).
2. VM'de `calistir_vm.bat` dosyasını çalıştır. Betik uygulamayı `C:\BelleVideo`'ya kopyalar ve şu komutu çalıştırır:

   ```
   C:\QtSDK\Desktop\Qt\4.7.4\mingw\bin\qmlviewer.exe -I Z:\qmltest Z:\qmltest\Harness.qml
   ```

   Telefondaki QML 1.1 ile aynı sürüm olduğu için masaüstü Qt **4.7.4** seçildi. VM'de 4.8.1 ve Simulator qmlviewer'ları da var.
3. Hataları görmek için qmlviewer menüsünden **Debugging > Show Warnings**'i aç.
   - Sözdizimi hataları, `ReferenceError`'lar ve "Binding loop" uyarıları burada görünür.
   - `lib.log()` taklidi her satırı `LOG ...` olarak buraya yazar.
4. Arayüzü klavyeyle gez (yön tuşları, Enter, Boşluk), telefondaki gibi.

## Başka uygulamada kullanmak

- `Harness.qml` içindeki `Loader` satırında `source` yolunu değiştir. Şu an `file:///C:/BelleVideo/qml/main.qml` yazıyor.
- Taklit nesneleri o uygulamanın C++ nesnelerine göre yeniden yaz. Örnekler:
  - WhatsBelle: `device`, `notify`, `keys`
  - BelleTube: `tube`, `volumeKeys`, `sys`
- Kural: QML'in çağırdığı her fonksiyon ve okuduğu her özellik taklitte bulunmalı.
- **Dikkat:** bir özellik ekleyince QML onun `xxxChanged` sinyalini kendisi üretir. Aynı adlı sinyali ayrıca yazarsan "duplicate signal" hatası alırsın. `scanning` özelliği ile `scanningChanged` sinyali bu yüzden çakışmıştı.
- Uygulama kendi QML türü kaydediyorsa (`qmlRegisterType`), o modül için `qmldir` dosyası ve taklit bir `.qml` ekle.

## Sınırlar

- Gerçek oynatma, ağ, dosya sistemi, ses tuşları ve Symbian'a özgü davranışlar test edilmez. Bunlar için telefon gerekir.
- `Audio.Loaded` gibi enum değerleri taklitte tanımsızdır, o satırlar sessizce çalışmaz.
- VM'de bazen fare girişi takılıyor (tıklamalar konuğa gitmiyor). Klavye çalışır:
  - VM ekranının gri kenarına tıkla.
  - Gerekirse Ctrl+Alt+Del için sağ Ctrl + Delete'e bas, sonra Esc.
  - Başlat menüsü için Ctrl+Esc'e bas, `Z:\betik.bat` yazıp Enter'a bas.
