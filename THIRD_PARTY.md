# Third-party components and credits

| Component | Used by | License | Notes |
|---|---|---|---|
| [Pigler](https://github.com/piglerorg/pigler) | WhatsBelle (status-bar notifications) | GPL-3.0 | full copy in `apps/kutuphane/pigler/`, prebuilt `Pigler.sis` 1.4.1 embedded in WhatsBelle |
| [Telegram API schema](https://core.telegram.org/schema) (TL) | BelleGram | — | `tl/sema.txt`, generated from the public api.tl / mtproto.tl |
| [s60-maps](https://github.com/artem78/s60-maps) by artem78 | Belle Maps | GPL-3.0 | ideas and map logic (tile layers, search, routing) adapted and rewritten in QML |
| Star Player (Paul Wallace / Allstar Software) | BelleVideo | MIT | feature set used as inspiration; code written from scratch |
| [Twemoji](https://github.com/twitter/twemoji) | WhatsBelle emoji images | CC-BY 4.0 (graphics) | © Twitter, Inc. and other contributors |
| [whatsapp-web.js](https://github.com/pedroslopez/whatsapp-web.js) | server (WhatsApp Web bridge) | Apache-2.0 | npm dependency |
| [Puppeteer](https://github.com/puppeteer/puppeteer) | server browser, reading mode | Apache-2.0 | npm dependency |
| [Express](https://expressjs.com/), compression, express-fileupload | server | MIT | npm dependencies |
| [ImapFlow](https://github.com/postalsys/imapflow), [Nodemailer](https://nodemailer.com/) | server (BelleMail) | MIT / MIT-0 | npm dependencies |
| [@mozilla/readability](https://github.com/mozilla/readability), [linkedom](https://github.com/WebReflection/linkedom) | server (reading mode) | Apache-2.0 / ISC | npm dependencies |
| google-libphonenumber, qr-image, sqlite3, fluent-ffmpeg | server | Apache-2.0 / MIT / BSD-3 / MIT | npm dependencies |
| [yt-dlp](https://github.com/yt-dlp/yt-dlp) | server (BelleTube) | Unlicense | downloaded by `install.sh` |
| [FFmpeg](https://ffmpeg.org/) | server | LGPL/GPL | system package |
| [Caddy](https://caddyserver.com/) | server reverse proxy | Apache-2.0 | system package |
| OpenStreetMap data and tiles, Esri, OpenTopoMap, Photon (komoot), OSRM | Belle Maps | ODbL / provider terms | follow each provider's usage policy; tiles are requested with an identifying User-Agent |
| Open-Meteo | BelleWidgets weather | CC-BY 4.0 | |
| HSWidgetPlugin.dll (Nokia) | BelleWidgets | proprietary | **not included**; obtain it from the *Symbian-HomeScreen-Widget-QML* template |
| Qt 4.7 / 4.8, QtMobility | all apps | LGPL-2.1 | runtime on the phone |

Community TLS patches for Symbian (nnproject, shinovon's symbian-tls) are **not** included; see
[docs/TLS_PATCH.md](docs/TLS_PATCH.md) for where to get them.
