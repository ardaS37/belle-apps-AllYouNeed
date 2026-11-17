# Sunucu kurulumu

Sunucu (`server/`) tek bir Node.js sürecidir. Tüm telefon uygulamalarına düz HTTP üzerinden hizmet verir;
ağır oturumları (başsız Chrome'da WhatsApp Web, IMAP, Google API'leri, video dönüştürme) kendi tarafında tutar.

> English: [SERVER_SETUP.md](SERVER_SETUP.md)

## 1. Gereksinimler

| | En az | Önerilen |
|---|---|---|
| İşletim sistemi | Ubuntu 22.04 / 24.04 ya da Debian 12, x86_64 | Ubuntu 22.04 LTS |
| İşlemci / RAM | 1 vCPU / 1 GB (+2 GB takas alanı, otomatik açılır) | 2 vCPU / 2–4 GB |
| Disk | 10 GB | 20 GB (BelleTube videoları önbelleğe alır, varsayılan sınır 4 GB) |
| Ağ | herkese açık IPv4 adresi, TCP **80** portu açık | |

Herhangi bir sanal sunucu olur (Google Cloud e2-small, Hetzner CX22, Oracle ücretsiz x86, Chromium ile
Raspberry Pi 4/5, port yönlendirmeli evdeki eski bir PC…). Bir WhatsApp hesabı Chrome'da ~300–500 MB RAM kullanır.

> **Neden HTTPS değil de HTTP?** Yamasız Symbian Belle modern TLS kuramaz. Her istek sunucu parolasını taşır
> (`X-Api-Key` başlığı ya da `?key=`); bu yüzden uzun bir parola seçin ve sunucuyu kişisel kullanın.
> [TLS yamalarını](TLS_PATCH.md) kurarsanız ileride önüne HTTPS koyabilirsiniz. Bkz. [SECURITY.md](../SECURITY.md).

## 2. Kurulum

```bash
# kendi bilgisayarınızda
scp -r server/ kullanici@sunucunuz:~/belle-server
# sunucuda
cd ~/belle-server
bash install.sh
```

`install.sh` tekrar çalıştırılabilir; her adımda önce ne kurulu olduğuna bakar:

1. RAM 2 GB'tan azsa 2 GB takas alanı açar
2. ffmpeg, derleme araçları ve emoji yazı tiplerini kurar
3. Node.js 20'yi kurar (NodeSource)
4. Google Chrome'u (x86_64) ya da Chromium'u (ARM) kurar
5. **yt-dlp**'yi `~/bin`'e indirir (BelleTube için)
6. `npm install` çalıştırır (Puppeteer'in kendi Chrome indirmesi atlanır, sistemdeki Chrome kullanılır)
7. `.bellekey` dosyasına rastgele bir parola üretir (600 izinli)
8. `ecosystem.config.js` yazar ve servisi **pm2** ile başlatır (açılışta otomatik)
9. **Caddy**'yi ters vekil olarak kurar: 80. port → `127.0.0.1:3000`

Sonunda şunu yazar:

```
Server address : http://203.0.113.10
Password       : xxxxxxxxxxxxxxxxxxxx
Web panel      : http://203.0.113.10/panel
```

Seçenekler: `--port 3100` (iç Node portu), `--no-caddy` (kendi vekilinizi kullanırsınız; Node yalnızca 127.0.0.1'i dinler).

Bulut sağlayıcınızın güvenlik duvarında **80. portu açın** (Google Cloud: VPC güvenlik duvarı kuralı `tcp:80`;
Oracle: security list + `iptables`; AWS: security group).

## 3. Telefon uygulamalarını bağlama

Her uygulamada *Ayarlar*'ı açıp şunları girin:

- **Sunucu adresi**: `http://203.0.113.10` (IP'niz ya da alan adınız, sonda `/` olmadan)
- **Sunucu parolası**: `install.sh`'ın yazdığı değer (`~/belle-server/.bellekey` dosyasında da var)

BelleMail, Belle Files ve Belle Browser telefonda ortak bir adres dosyası kullanır (`C:\Data\E6\sunucu.ini`): birinde
girince üçünde de geçerli olur.

## 4. Servis ayarları

### WhatsApp (WhatsBelle)
WhatsBelle'i açın, numaranızı ülke koduyla yazın (örn. `905321234567`), **Devam**'a basın. Numaranın sunucuda
oturumu yoksa sunucu bir oturum başlatır ve telefonda QR kodu çıkar. WhatsApp yüklü telefondan okutun:
*Ayarlar → Bağlı cihazlar → Cihaz bağla*. Bilgisayardaki tarayıcıdan `http://sunucunuz/login` adresini de
açabilirsiniz. Oturumlar yeniden başlatmada korunur (`.wwebjs_auth/`).

İkinci bir WhatsApp numarası *Ayarlar → Hesaplar → 2. hesabı ekle* ile eklenir (W²).

Varsayılan olarak tüm gruplar listelenir. Yalnızca adında belli bir kelime geçen grupları göstermek için
`GROUP_FILTER` değişkenini ayarlayın (aşağıda).

### E-posta (BelleMail, WhatsBelle posta sekmesi)
`http://sunucunuz/mail/setup` adresini açın (tarayıcı parola sorar; kullanıcı adı herhangi bir şey olabilir).
Gmail / Outlook / Yandex / Yahoo / iCloud ya da özel IMAP/SMTP seçin. Gmail için **uygulama şifresi**
oluşturun (Google Hesabı → Güvenlik → 2 Adımlı Doğrulama → Uygulama şifreleri). `data/mail.json`'da saklanır.

### Google Drive (Belle Files)
1. [Google Cloud Console](https://console.cloud.google.com/)'da bir proje açın, **Google Drive API**'yi etkinleştirin.
2. *API'ler ve Hizmetler → Kimlik bilgileri → Kimlik bilgisi oluştur → OAuth istemci kimliği*, tür: **Masaüstü uygulaması**.
3. `http://sunucunuz/drive/setup` adresini açın, istemci kimliğini ve gizli anahtarı yapıştırıp *Bağla*'ya basın.
   Google sizi açılmayan bir `http://127.0.0.1:8765/…` adresine yönlendirir; adres çubuğundaki bu adresin
   tamamını kopyalayıp kurulum sayfasına geri yapıştırın. Belirteçler `data/` altında saklanır.
4. OAuth izin ekranı *Test* modundayken Google hesabınızı test kullanıcısı olarak ekleyin.

### YouTube hesabı (BelleTube abonelikleri, isteğe bağlı)
BelleTube hesapsız çalışır. Aboneliklerinizi almak için **TV ve Sınırlı Giriş cihazları** türünde bir OAuth
istemcisi açın (YouTube Data API v3 etkin), `http://sunucunuz/yt/setup`'a girin; sonra telefonda
*BelleTube → Ayarlar → Google hesabını bağla* deyip çıkan kodu `google.com/device` adresine yazın.

### Yapay zekâ anahtarları (ApiLauncher, isteğe bağlı)
ApiLauncher, OpenAI / Anthropic / Google / xAI'ye doğrudan (TLS yaması gerekir) ya da sunucu üzerinden
bağlanabilir. Sunucu modu için anahtarları uygulamaya girip *Anahtarları sunucuya kaydet*'e basın;
`data/ai_keys.json`'da saklanır ve telefona hiç geri gönderilmez.

### Uzak masaüstü (Belle Remote + Belle Remote PC)
Sunucuda ayar gerekmez, aktarıcı yerleşiktir (`/uzak/…`). PC'de *Belle Remote PC*'yi açın, sunucu adresini ve
parolayı girin, *Sunucu üzerinden her yerden erişilebilir ol* kutusunu işaretleyin.

## 5. Ayarlar (ortam değişkenleri)

`ecosystem.config.js` dosyasını düzenleyip `pm2 restart belle-server --update-env` çalıştırın.

| Değişken | Varsayılan | Anlamı |
|---|---|---|
| `BELLE_KEY` | `.bellekey`'den okunur | sunucu parolası (zorunlu) |
| `PORT` | `3000` | iç port (Node yalnızca 127.0.0.1'i dinler) |
| `CHROME_PATH` | `/usr/bin/google-chrome` | WhatsApp Web, sunucu tarayıcısı ve okuma modu için tarayıcı |
| `YTDLP_PATH` | `~/bin/yt-dlp` | BelleTube için yt-dlp |
| `YT_CACHE_MAX_MB` | `4000` | BelleTube video önbelleği sınırı |
| `CHAT_LIMIT` | `10` | telefona sayfa başına gönderilen sohbet |
| `MSG_LIMIT` | `50` | sohbet başına mesaj |
| `KEEP_PER_CHAT` | `20` | sunucu veritabanında sohbet başına saklanan mesaj |
| `GROUP_FILTER` | `""` | yalnızca adında bu kelime geçen grupları listele (`""` = hepsi) |
| `AVATAR_SIZE` | `40` | profil resmi boyutu (piksel) |

İsteğe bağlı ikinci bir parola `.bellekey2` dosyasına yazılabilir (örneğin bir aile bireyine erişim verip sonra geri almak için).

## 6. İşletme

```bash
pm2 logs belle-server          # canlı günlük
pm2 restart belle-server       # yeniden başlat
cd ~/belle-server && git pull && npm install --omit=dev && pm2 restart belle-server   # güncelle
~/bin/yt-dlp -U            # BelleTube çalışmazsa yt-dlp'yi güncelle
```

Hesapları ve oturumları korumak için `data/`, `.wwebjs_auth/` ve `.bellekey`'i yedekleyin.
Uygulamalardan gönderilen hata raporları (*Rapor gönder*) `data/reports/` altına düşer.

## 7. Sorun giderme

| Belirti | Çözüm |
|---|---|
| Uygulamalar *bağlanılamadı* diyor | bulut güvenlik duvarında 80. port kapalı; dışarıdan `curl -I http://ip-adresiniz/panel/giris` |
| *Sunucu parolası hatalı* | `.bellekey` ile karşılaştırın; boşluk olmasın; düzenledikten sonra yeniden başlatın |
| QR kodu hiç gelmiyor | Chrome yok ya da bellek yetmiyor: `pm2 logs`; takas alanına ve `CHROME_PATH`'e bakın |
| WhatsApp bir süre sonra duruyor | sunucu takılan oturumu kendisi yeniden kurar; ana telefondan çıkış yapıldıysa QR'ı yeniden okutun |
| BelleTube videoları açılmıyor | `~/bin/yt-dlp -U` |
| Posta boş | `/mail/setup`'a bakın; Gmail için uygulama şifresi ve IMAP gerekir |
