# Belle Apps — Nokia E6 (Symbian Belle) için modern uygulamalar

**Nokia E6**'ya (Symbian Anna/Belle, 640×480 klavyeli telefon) WhatsApp, e-posta, Google Drive, YouTube,
yapay zekâ sohbeti, modern tarayıcı, harita, uzak masaüstü ve daha fazlasını getiren Qt Quick uygulamaları
ile çoğunun bağlandığı küçük **Node.js sunucusu**.

> 🇬🇧 English: [README.md](README.md)

Tüm uygulamalar **Türkçe ve İngilizce** konuşur: telefonun dilini izler, her uygulamanın ayarlarındaki
*Dil / Language* satırından değiştirilebilir. Bu depoda hiçbir sunucu adresi yoktur; herkes kendi sunucusunu kurar.

## Neden sunucu?

Symbian Belle eski bir TLS altyapısı ve Qt 4.8 ile gelir; WhatsApp Web, Gmail, Google Drive, YouTube ve
yapay zekâ servislerine doğrudan bağlanamaz. Sunucu ağır işi yapar: WhatsApp Web için başsız Chrome oturumu
tutar, IMAP/SMTP konuşur, videoyu dönüştürür, web sayfalarını küçültür. Telefona da parolayla korunan hafif
bir HTTP arayüzü sunar. Sunucu gerektirmeyen uygulamalar tabloda belirtilmiştir: BelleMail, BelleGram,
BelleCast, BelleCeviri ve BelleKitap internete doğrudan bağlanır (Qt'nin TLS 1.2'si ve güncel kök sertifikalar).

## Uygulamalar

| Uygulama | Klasör | Ne yapar | Sunucu |
|---|---|---|---|
| **WhatsBelle** | `apps/WhatsBelle` | WhatsApp: sohbetler, gruplar, fotoğraf, sesli mesaj, konum, ifade, telefondan QR ile giriş, iki hesap (W²), [Pigler](docs/PIGLER.md) ile durum çubuğu bildirimleri | gerekli |
| **BelleMail** | `apps/BelleMail` | Telefondan doğrudan, TLS ile e-posta (IMAP + SMTP): Gmail, Yandex, Yahoo, iCloud ya da herhangi bir IMAP hesabı; tüm klasörler ve etiketler, arama, ekler, yanıtla/ilet, arka planda açıkken yeni posta bildirimi. *Uygulama şifresi* gerekir — bkz. [Hesaplar](docs/HESAPLAR.md) | kullanılmaz |
| **BelleGram** | `apps/BelleGram` | Sıfırdan yazılmış Telegram istemcisi (MTProto 2.0, sunucusuz): sohbetler, gruplar, kanallar, fotoğraf, dosya, sesli mesaj, konum, yanıt, ifade, bildirim. İlk açılışta kendi Telegram `api_id` / `api_hash` değerlerinizi girersiniz — bkz. [Hesaplar](docs/HESAPLAR.md) | kullanılmaz |
| **Belle Files** | `apps/BelleFiles` | Not defteri + dosya yöneticisi + zip + yedekleme (rehber, SMS, uygulama ayarları) + Google Drive (sunucu üzerinden ya da kendi Google OAuth istemcinizle doğrudan) | isteğe bağlı |
| **BelleTube** | `apps/BelleTube` | YouTube: arama, kanallar, abonelikler, yorumlar; videolar E6 için dönüştürülür | gerekli |
| **ApiLauncher** | `apps/ApiLauncher` | GPT, Claude, Gemini ve Grok ile sohbet; fotoğraf, resim çizme | isteğe bağlı |
| **Belle Browser** | `apps/BelleBrowser` | Sekmeli QtWebKit tarayıcı, okuma modu, reklam engelleyici, ağır HTTPS siteler için sunucu tarafında sıkıştırma | isteğe bağlı |
| **Belle Remote** | `apps/BelleRemote` | Windows PC'niz için uzak masaüstü (yerel ağ ya da sunucu üzerinden) + sunucuda çalışan tam bir Chrome | internetten PC için gerekli |
| **Belle Maps** | `apps/BelleMaps` | OpenStreetMap / Esri haritaları, arama, adım adım yol tarifi (OSRM), çevrimdışı bölgeler, kayıtlı yerler | isteğe bağlı |
| **BelleVideo** | `apps/BelleVideo` | Kaldığı yerden devam, listeler ve yalnızca ses kipiyle yerel video oynatıcı | kullanılmaz |
| **BelleWidgets** | `apps/BelleWidgets` | Ana ekran widget'ları: pil, hava durumu, RAM/CPU | kullanılmaz |
| **BelleMiddleKey** | `apps/BelleMiddleKey` | İstediğin tuşa istediğin kısayol (orta tuş, ses tuşları, tek dokunuş tuşları…): bas-çek, peş peşe 2–3 kez ya da basılı tut → uygulama aç, sessiz ↔ önceki profil, açık uygulamaları kapat, ana menü, görev değiştirici. Test ekranı var; Qt'siz küçük bir arka plan servisi telefonla birlikte başlar. *Install Server yaması gerekir (SwEvent yetkisi), bkz. [INSTALLING](docs/INSTALLING.md)* | kullanılmaz |
| **BelleCast** | `apps/BelleCast` | İnternet radyosu (ülkeye göre dünya çapında arama, favoriler, önceki/sonraki istasyon, kayıt), podcast ve okuma görünümlü RSS haberleri. Yayınlar (ICY, HTTPS, HLS) telefonun içinde aktarılır, sunucu yok | kullanılmaz |
| **BelleCeviri** | `apps/BelleCeviri` | Tek uygulamada çeviri + sözlük: Google (resmi olmayan, anahtarsız), MyMemory, DeepL, Gemini, Groq, Mistral, OpenAI, Claude; her servis açılıp kapatılır, 85 dil, Vikisözlük/TDK sözlüğü, geçmiş. API anahtarlarınızı telefonda girersiniz, uygulamaya gömülmez | kullanılmaz |
| **BelleMusic** | `apps/BelleMusic` | MIDPlay'in kullandığı s60tube müzik servisi için müzik çalar (YouTube Music, NhacCuaTui, Spotify, SoundCloud): keşfet, arama, listeler, favoriler, indirme, sıra, uyku zamanlayıcısı, kulaklık tuşları | kullanılmaz |
| **BelleKitap** | `apps/BelleKitap` | EPUB ve TXT e-kitap okuyucu: temalar, yazı tipi, içindekiler, yer imleri, kaldığın yerden devam. Project Gutenberg (EPUB, birçok dil) ve Vikikaynak'tan ücretsiz kitap arama ve indirme | kullanılmaz |

PC tarafı (Windows, .NET 4): **Belle Remote PC** (`pc/BelleRemotePC`, telefonun bağlandığı masaüstü).

Her uygulamanın ekran görüntüleri: `screenshots/<Uygulama>/`.

## Gereklilikler

- Nokia E6 ya da Qt 4.7.4+ yüklü başka bir Symbian^3 / Anna / Belle telefon (Belle'de Qt 4.8 hazır gelir).
- **Tavsiye edilen:** topluluğun **TLS 1.2 yaması** — <https://github.com/shinovon/symbian-tls>
  (Qt uygulamaları için: <https://github.com/shinovon/qt-patches>; indirme: <https://nnproject.cc/tls/>).
  Ayrıntı: [docs/TLS_PATCH.md](docs/TLS_PATCH.md).

## Hızlı başlangıç

1. **Sunucu** – herhangi bir küçük Ubuntu/Debian sunucuda `server/` klasörünü kopyalayıp `bash install.sh`
   çalıştırın. Sonda sunucu adresi ve parola yazılır. Ayrıntı: [docs/SUNUCU_KURULUMU.md](docs/SUNUCU_KURULUMU.md).
2. **Telefon** – Releases sayfasındaki `.sis` dosyalarını kurun (kendinden imzalı; bkz.
   [docs/INSTALLING.md](docs/INSTALLING.md)). Uygulamayı açın → Ayarlar → sunucu adresini
   (`http://sunucu-ip-adresi`) ve parolayı girin.
3. **WhatsApp** – WhatsBelle'i açın, numaranızı yazın, çıkan QR kodu WhatsApp yüklü telefondan okutun
   (*Bağlı cihazlar → Cihaz bağla*).

Web sitesi ve indirmeler: **https://msahincelen.xyz** (telefondaki BelleAppCenter uygulamaları buradan
kurar ve günceller).

## Belgeler

[Hesaplar: Telegram API, Gmail uygulama şifresi](docs/HESAPLAR.md) · [Sunucu kurulumu](docs/SUNUCU_KURULUMU.md) · [Kurulum](docs/INSTALLING.md) · [Derleme](docs/BUILDING.md) ·
[TLS yaması](docs/TLS_PATCH.md) · [Pigler](docs/PIGLER.md) · [Çeviri](docs/TRANSLATING.md) ·
[Güvenlik](SECURITY.md) · [Üçüncü taraf bileşenler](THIRD_PARTY.md)

## Geliştirme, hata bildirimi ve destek

Belle Apps **sürekli geliştirilmektedir**: yeni uygulamalar, düzeltmeler ve özellikler gelmeye devam ediyor;
güncellemeler Releases sayfasında, https://msahincelen.xyz adresinde ve telefondaki BelleAppCenter'da yayınlanır.

**Bir hata mı buldunuz ya da öneriniz mi var?** Lütfen bildirin:
<https://github.com/msahincelen/belle-apps-AllYouNeed/issues> — uygulamanın adını ve sürümünü, ne yaptığınızı ve
ne olduğunu yazın (ekran görüntüsü ya da uygulamanın günlüğü çok yardımcı olur).

**Projeye destek olun** — bu uygulamalar işinize yarıyorsa bağışınız geliştirmenin sürmesine yardım eder:

| | |
|---|---|
| Ad Soyad | Mevlüd Şahin Çelen |
| IBAN | `TR74 0010 3000 0000 0057 9149 79` |

## Durum

Kişisel proje; Belle Refresh (111.140.0058) yüklü Nokia E6-00'da geliştirilip denendi. Qt 4.7.4+ olan
diğer Symbian^3/Anna/Belle telefonlarda da çalışması beklenir, ancak ekranlar 640×480 için tasarlandı.

Bu uygulamaların WhatsApp, Google, YouTube, OpenAI, Anthropic, xAI ya da Nokia ile **resmi bir bağlantısı
yoktur**. Resmi olmayan istemci kullanmak servislerin kullanım koşullarına aykırı olabilir; sorumluluk kullanıcıdadır.

## Lisans

GPL-3.0 — [LICENSE](LICENSE). WhatsBelle, GPL-3.0 lisanslı Pigler istemci kütüphanesini kullandığı için
deponun tamamı GPL-3.0 ile yayınlanır.
