# Hesaplar: Telegram API kimliği ve e-posta uygulama şifresi

> 🇬🇧 English: [ACCOUNTS.md](ACCOUNTS.md)

BelleGram ve BelleMail **sunucusuz** çalışır: telefon Telegram'a ve posta sağlayıcınıza doğrudan
bağlanır. Uygulamalara hiçbir bilgi gömülü değildir; kendi bilgilerinizi bir kez girersiniz ve bunlar
yalnızca telefonda, uygulamanın özel klasöründe saklanır.

## BelleGram: Telegram `api_id` ve `api_hash`

Her Telegram istemcisinin bir uygulama kimliği olması gerekir. BelleGram hazır kimlikle gelmez
(herkese açık yayınlanan kimliği Telegram engeller); kendi kimliğinizi alırsınız. Ücretsizdir ve iki
dakika sürer; bilgisayardan yapın:

1. **https://my.telegram.org** adresini açın, telefon numaranızla (ülke koduyla, ör. `+905321234567`)
   giriş yapın. Giriş kodu SMS ile değil, **Telegram uygulamanıza mesaj olarak** gelir.
2. **API development tools** bağlantısına tıklayın.
3. Formu doldurun (yalnızca ilk iki alan önemli):
   - *App title*: `BelleGram`
   - *Short name*: `bellegram` (5–32 harf/rakam)
   - *Platform*: **Other** (ya da Desktop)
   - URL ve açıklama boş kalabilir.
4. **Create application**'a basın. Sayfada şunlar görünür:
   - **App api_id** — bir sayı, ör. `12345678`
   - **App api_hash** — 32 karakter (0-9, a-f)
5. Telefonda BelleGram'ı açın. İlk ekran bu iki değeri ister; yazın (Ctrl+V ile yapıştırabilirsiniz),
   **Kaydet ve devam et**'e basın, sonra her zamanki gibi telefon numaranızla giriş yapın.

`api_hash`'i kimseyle paylaşmayın, internette yayınlamayın. Sonradan BelleGram → Ayarlar →
*API bilgilerini değiştir* ile değiştirebilirsiniz (çıkış yapar).

"Create application" yalnızca *ERROR* gösterirse bir süre sonra ya da başka tarayıcı/ağdan yeniden
deneyin; reklam engelleyici ya da VPN çoğu zaman buna yol açar.

## BelleMail: uygulama şifresi

BelleMail IMAP/SMTP ile giriş yapar. Büyük sağlayıcılar burada normal şifrenizi kabul etmez;
**uygulama şifresi** ister: yalnızca bu uygulama için ayrı, 16 karakterlik ve istediğiniz an iptal
edebileceğiniz bir şifre.

### Gmail

1. Google hesabınızda **2 adımlı doğrulama** açık olmalı:
   https://myaccount.google.com/signinoptions/twosv
2. **https://myaccount.google.com/apppasswords** adresini açın (isterse yeniden giriş yapın).
3. Bir ad yazın, ör. `BelleMail`, **Oluştur**'a basın.
4. Google 16 harfli bir şifre gösterir (`abcd efgh ijkl mnop`). Bunu BelleMail → *Uygulama şifresi*
   kutusuna yazın (boşluklar şart değil). Google şifreyi bir daha göstermez; kaybederseniz yenisini oluşturun.

Gmail'de IMAP artık her zaman açıktır; ek ayar gerekmez.

### Yandex
id.yandex.com → **Güvenlik** → **Uygulama şifreleri** → *Posta*. Ayrıca Yandex Posta → Ayarlar →
*E-posta istemcileri* bölümünden IMAP'ı açın.

### Yahoo
Hesap güvenliği → **Uygulama şifresi oluştur**.

### iCloud
https://appleid.apple.com → **Oturum açma ve güvenlik** → **Uygulamaya özel parolalar**.

### Diğer sağlayıcılar / kendi alan adınız
*Diğer*'i seçip IMAP sunucusunu (port 993, TLS) ve SMTP sunucusunu (465 TLS ya da 587 STARTTLS) girin.
Genellikle normal posta şifreniz çalışır.

**Outlook / Hotmail** 2024'ten beri yalnızca OAuth ile giriş kabul ettiği için şimdilik desteklenmiyor.

## Bildirimler

BelleMail açıkken 5 dakikada bir yeni posta olup olmadığına bakar (Menü → *Yeni posta denetimi*:
2/5/15/30 dk ya da kapalı). Uygulamayı kapatmak yerine gelen kutusunda **Geri**'ye basın (ya da
Menü → *Arka plana al*); yeni postalar durum çubuğu çekmecesinde ([Pigler](PIGLER.md)) ve köşe
bildirimi olarak görünür.
