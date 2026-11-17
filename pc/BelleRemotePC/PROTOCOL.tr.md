# BelleRemote protokolü (sürüm 1)

Kendi bilgisayarını kendi telefonundan kullanmak için kişisel uzak masaüstü. PC tarafı **BelleRemote PC** (Windows),
istemciler **BelleRemote** (Nokia E6, Qt/QML) ve ileride Android. Bu belge iki istemcinin de uyacağı tek protokoldür.

## 1. Bağlantı yolları

Uygulama protokolü iki yolda da **aynıdır**; yalnızca bağlantının kurulması farklıdır.

### 1a. Yerel ağ (LAN) — en hızlı
İstemci doğrudan `PC_IP:5680` (TCP) adresine bağlanır ve hemen `H` (merhaba) çerçevesini gönderir.

### 1b. Sunucu üzerinden (aktarıcı) — her yerden
Sunucu: `http://YOUR-SERVER` (80. port, Caddy → Node `uzak.js`). İstemci TCP açıp ham HTTP isteği yazar:

```
GET /uzak/baglan?rol=tel&hedef=<pc adı> HTTP/1.1
Host: 203.0.113.10
Connection: Upgrade
Upgrade: e6uzak
X-Api-Key: <sunucu parolası>
```

- Yanıt `HTTP/1.1 101 Switching Protocols` ise başlıklardan (`\r\n\r\n`) sonrası **ham protokol**dür.
- `404` → o adda bekleyen PC yok. `403` → parola hatalı.
- PC aynı isteği `rol=pc&ad=<pc adı>&lan=<ip:port>` ile yapar ve **bekler**. Beklerken aktarıcı her 25 sn
  bir `P` çerçevesi yollar (PC bununla bağlantının canlı olduğunu anlar; 70 sn gelmezse yeniden bağlanır).
  Bir telefon eşleşince aktarıcı iki soketi birbirine bağlar; PC'ye ilk gelen çerçeve telefonun `H`'sidir.
  Oturum bitince iki soket de kapanır; PC hemen yeniden bekleme bağlantısı açar.
- Çevrimiçi PC'ler: `GET /uzak/liste` (X-Api-Key) → `{"pcler":[{"ad":"MY-PC","lan":"192.168.1.20:5680","sure":123}]}`.
  İstemci önce `lan` adresini dener (aynı ağdaysa hızlı), olmazsa aktarıcıyı kullanır.

Kimlik doğrulama her iki yolda da **sunucu parolası** ile yapılır (WhatsBelle ile aynı parola).

### 1c. PC'den PC'ye (BelleRemote PC 1.1)
BelleRemote PC'nin kendisi de istemci olabilir: ana penceredeki **Başka PC'ye bağlan** (ya da `BelleRemotePC.exe /izle`).
Liste `/uzak/liste`'den gelir; otomatik kipte hedefin `lan` adresi aynı /24 ağdaysa önce doğrudan LAN (2,5 sn), olmazsa
`rol=tel&hedef=<ad>` ile aktarıcı. Elle yazılan `IP[:port]` yalnız LAN'dır. `H`: `istemci=pc kip=akis`, LAN'da 15 fps / kalite 60,
sunucuda 8 fps / kalite 42; genişlik izleyici penceresinin genişliği (pencere büyüyünce `A genislik=` gönderilir).
İki PC'de aynı sunucu parolası olmalı (karşı PC `H`'deki anahtarı kendi parolasıyla karşılaştırır).

## 2. Çerçeve biçimi

```
1 bayt tür | 4 bayt uzunluk (big-endian, işaretsiz) | veri
```
Metin verileri UTF-8'dir; satırlar `\n` ile ayrılır, satırda alanlar tek boşlukla ayrılır.
Koordinatlar **onbinde bir** (0..10000) cinsindendir ve her zaman **seçili kaynağın tamamına** göredir
(yakınlaştırma istemcide yapılır; istemci görüntü koordinatını kaynak koordinatına çevirir).

## 3. İstemci → PC

| Tür | Veri | Anlamı |
|---|---|---|
| `H` | `anahtar=..` `istemci=nokia\|android` `kip=paket\|akis` `genislik=640` `kalite=40` `fps=1` `ad=..` (satır satır) | Merhaba. PC `O` ya da `N` ile yanıtlar. |
| `L` | – | Pencere listesi iste. |
| `S` | `masaustu` \| `ekran:<n>` \| `pencere:<indeks>` | Kaynak seç (paylaşılan alan). |
| `Z` | `x y g y2` (onbinde bir; `0 0 10000 10000` = tamamı) | Yalnızca bu bölgeyi gönder (yakınlaştırma; bant genişliği kazanır). |
| `I` | girdi satırları (aşağıda) | Girdi paketi. `kip=paket` iken istemci 1 sn bekleyip toplu yollar; PC uygular ve **hemen** bir kare gönderir. `kip=akis` iken olay olur olmaz yollanır. |
| `Y` | düz metin | Metni yaz (Unicode; `\n` = Enter). |
| `G` | – | Son kareyi aldım (akış denetimi). |
| `F` | – | Hemen tam kare gönder. |
| `A` | `fps=2` `kalite=50` `genislik=800` `kip=akis` | Ayarları oturum sırasında değiştir. |
| `P` | zaman damgası (metin) | Ping; PC aynı veriyle `P` döner. |

### Girdi satırları (`I`)
```
M x y            fareyi oraya götür
C L|R|M x y      tıkla (sol / sağ / orta)
D L|R x y        bas (sürükleme başlangıcı)
U L|R x y        bırak
W n              tekerlek (+ yukarı, − aşağı; 1 = bir çentik)
X n              yatay tekerlek (+ sağa, − sola)
K tuş            tuş / kısayol: enter esc tab backspace delete home end pgup pgdn up down left right
                 win space f1..f12 volup voldown mute play next prev ctrl+c ctrl+v ctrl+z ctrl+a ctrl+s
                 alt+tab alt+f4 win+d win+l win+e ctrl+shift+esc ... (artı ile birleşik)
```

## 4. PC → istemci

| Tür | Veri | Anlamı |
|---|---|---|
| `O` | `ad=..` `ekranlar=n` `surum=1` | Merhaba kabul. |
| `N` | gerekçe | Parola hatalı; bağlantı kapanır. |
| `L` | `indeks\tbaşlık` satırları | Pencere listesi. |
| `K` | `x y gorunur` (onbinde bir; görünmezse `-1 -1 0`) | Gerçek imleç konumu (her kareden önce). |
| `J` | JPEG | Kare (seçili kaynak, `Z` bölgesi, `genislik`e küçültülmüş). |
| `T` | `1` \| `0` | Bilgisayarda yazı imleci (metin kutusu) etkin / değil. İstemci yazı penceresi açar. |
| `M` | metin | Durum / bilgi. |
| `P` | ping verisi | Pong. |

## 5. Akış denetimi (iki hızın tek motoru)
PC bir kare gönderir ve istemcinin `G` onayını bekler; aynı anda en fazla **2** onaylanmamış kare olur.
Böylece yavaş bağlantıda kareler birikmez (gecikme artmaz), hızlı bağlantıda kare hızı `fps` sınırına çıkar.
Değişmeyen kare (aynı içerik) gönderilmez. `I` (paket kipinde) ve `F` bekleyen sırayı atlayıp hemen kare ister.

Önerilen değerler:
- **Nokia E6:** `kip=paket fps=1 genislik=640 kalite=35`
- **Android / LAN:** `kip=akis fps=15 genislik=1280 kalite=55`
