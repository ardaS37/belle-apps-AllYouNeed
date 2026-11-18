# Belle Apps — modern apps for the Nokia E6 (Symbian Belle)

A family of Qt Quick apps that bring WhatsApp, e-mail, Google Drive, YouTube, AI chat, a modern web
browser, maps, remote desktop and more to the **Nokia E6** (Symbian Anna/Belle, 640×480 keyboard phone),
plus the small **Node.js server** most of them talk to.

> 🇹🇷 Türkçe açıklama: [README.tr.md](README.tr.md)

Every app speaks **English and Turkish** (follows the phone language; switch in each app's settings under
*Dil / Language*). Nothing in this repository points to a particular server: you run your own.

## Why a server?

Symbian Belle ships with an old TLS stack and Qt 4.8, so most modern services (WhatsApp Web, Gmail,
Google Drive, YouTube, AI APIs) cannot be reached directly. The server does the heavy lifting — it keeps a
headless Chrome session for WhatsApp Web, talks IMAP/SMTP, converts video, shrinks web pages — and gives the
phone a light HTTP API protected by a password. Apps that do not need it are marked below — BelleMail,
BelleGram, BelleCast, BelleCeviri and BelleKitap talk to the internet directly (Qt's TLS 1.2 with an
up-to-date root certificate bundle).

## Apps

| App | Folder | What it does | Server |
|---|---|---|---|
| **WhatsBelle** | `apps/WhatsBelle` | WhatsApp client: chats, groups, photos, voice notes, location, reactions, QR login from the phone, two accounts (W²), status-bar notifications via [Pigler](docs/PIGLER.md) | required |
| **BelleMail** | `apps/BelleMail` | E-mail straight from the phone over TLS (IMAP + SMTP): Gmail, Yandex, Yahoo, iCloud or any IMAP account; all folders and labels, search, attachments, reply/forward, new-mail notifications while running in the background. Needs an *app password* — see [Accounts](docs/ACCOUNTS.md) | not used |
| **BelleGram** | `apps/BelleGram` | Telegram client written from scratch (MTProto 2.0, no server): chats, groups, channels, photos, files, voice notes, location, replies, reactions, notifications. You enter your own Telegram `api_id`/`api_hash` on first start — see [Accounts](docs/ACCOUNTS.md) | not used |
| **Belle Files** | `apps/BelleFiles` | Notepad + file manager + zip + backups (contacts, SMS, app settings) + Google Drive (through the server or directly with your own Google OAuth client) | optional |
| **BelleTube** | `apps/BelleTube` | YouTube: search, channels, subscriptions, comments; videos converted for the E6 | required |
| **ApiLauncher** | `apps/ApiLauncher` | Chat with GPT, Claude, Gemini and Grok; photos, image generation | optional |
| **Belle Browser** | `apps/BelleBrowser` | QtWebKit browser with tabs, reading mode, ad blocker, server-side compression for heavy HTTPS sites | optional |
| **Belle Remote** | `apps/BelleRemote` | Remote desktop for your Windows PC (LAN or through the server) + a full Chrome running on the server | required for PC-over-internet |
| **Belle Maps** | `apps/BelleMaps` | OpenStreetMap / Esri maps, search, turn-by-turn routing (OSRM), offline areas, saved places | optional |
| **BelleVideo** | `apps/BelleVideo` | Local video player with resume, playlists, audio-only mode | not used |
| **BelleWidgets** | `apps/BelleWidgets` | Home-screen widgets: battery, weather, RAM/CPU | not used |
| **BelleMiddleKey** | `apps/BelleMiddleKey` | Assign any shortcut to any key (middle key, volume keys, one-touch keys…): press, press 2–3 times or press and hold → open an app, silent ↔ previous profile, close open apps, main menu, task switcher. Built-in test screen; a tiny Qt-free background service starts with the phone. *Needs the Install Server patch (SwEvent capability), see [INSTALLING](docs/INSTALLING.md)* | not used |
| **BelleCast** | `apps/BelleCast` | Internet radio (worldwide search by country, favourites, prev/next station, recorder), podcasts and RSS news with a reader view. Streams (ICY, HTTPS, HLS) are relayed inside the phone, no server | not used |
| **BelleCeviri** | `apps/BelleCeviri` | Translator + dictionary in one app: Google (unofficial, keyless), MyMemory, DeepL, Gemini, Groq, Mistral, OpenAI, Claude; turn each provider on/off, 85 languages, Wiktionary/TDK dictionary, history. Your own API keys are entered on the phone, never built in | not used |
| **BelleMusic** | `apps/BelleMusic` | Music player for the s60tube music service used by MIDPlay (YouTube Music, NhacCuaTui, Spotify, SoundCloud): discover, search, playlists, favourites, downloads, queue, sleep timer, headset keys | not used |
| **BelleKitap** | `apps/BelleKitap` | E-book reader for EPUB and TXT: themes, fonts, table of contents, bookmarks, resume. Search and download free books from Project Gutenberg (EPUB, many languages) and Turkish Wikisource | not used |

PC side (Windows, .NET 4): **Belle Remote PC** (`pc/BelleRemotePC`, the desktop the phone connects to).

Screenshots of each app: `screenshots/<App>/`.

## Requirements

- Nokia E6 or another Symbian^3 / Anna / Belle phone with Qt 4.7.4+ (Belle ships Qt 4.8).
- **Recommended:** the community **TLS 1.2 patch** — <https://github.com/shinovon/symbian-tls>
  (Qt apps: <https://github.com/shinovon/qt-patches>; downloads at <https://nnproject.cc/tls/>).
  Details in [docs/TLS_PATCH.md](docs/TLS_PATCH.md).

## Quick start

1. **Server** – on any small Ubuntu/Debian VPS: copy `server/` and run `bash install.sh`.
   It prints your server address and password. Details: [docs/SERVER_SETUP.md](docs/SERVER_SETUP.md).
2. **Phone** – install the `.sis` files from the Releases page (self-signed; see
   [docs/INSTALLING.md](docs/INSTALLING.md)). Open an app → Settings → enter the server address
   (`http://your-server-ip`) and the password.
3. **WhatsApp** – open WhatsBelle, type your number, scan the QR code with the phone that has WhatsApp
   (*Linked devices → Link a device*).

Website and app downloads: **https://msahincelen.xyz** (BelleAppCenter on the phone installs and updates
the apps from there).

## Documentation

- [Accounts: Telegram API ID, Gmail app password](docs/ACCOUNTS.md) · [Hesaplar (TR)](docs/HESAPLAR.md)
- [Server setup](docs/SERVER_SETUP.md) · [Sunucu kurulumu (TR)](docs/SUNUCU_KURULUMU.md)
- [Installing the apps](docs/INSTALLING.md)
- [Building from source](docs/BUILDING.md)
- [TLS 1.2 / 1.3 patches for Symbian](docs/TLS_PATCH.md)
- [Pigler notifications plugin](docs/PIGLER.md)
- [Translating](docs/TRANSLATING.md)
- [Security notes](SECURITY.md)
- [Third-party components](THIRD_PARTY.md)

## Development, bug reports and support

Belle Apps is **actively and continuously developed**: new apps, fixes and features keep coming, and
updates appear on the Releases page, on https://msahincelen.xyz and in BelleAppCenter on the phone.

**Found a bug or have an idea?** Report it on the bug report page: **<https://msahincelen.xyz/hata/>** — tick
the apps that have a problem, write what you did and what happened next to each one, and send them all at once.

**Support the project** — if these apps are useful to you, a donation helps keep them going:

| | |
|---|---|
| Name | Mevlüd Şahin Çelen |
| IBAN | `TR74 0010 3000 0000 0057 9149 79` |

## Status

Personal project, developed and tested on a Nokia E6-00 with Belle Refresh (111.140.0058). Other
Symbian^3/Anna/Belle phones with Qt 4.7.4+ should work, but the layouts target 640×480.

These apps are **not affiliated** with WhatsApp, Google, YouTube, OpenAI, Anthropic, xAI or Nokia.
Using unofficial clients may violate a service's terms; use at your own risk.

## License

GPL-3.0 — see [LICENSE](LICENSE) (WhatsBelle links the GPL-3.0 Pigler client library). BelleWidgets ships
Nokia's prebuilt `HSWidgetPlugin.dll`, see [THIRD_PARTY.md](THIRD_PARTY.md).
