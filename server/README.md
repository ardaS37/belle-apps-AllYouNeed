# Belle apps server

Node.js server for the Nokia E6 / Symbian Belle apps in this repository (WhatsBelle, BelleMail, Belle Files, BelleTube, ApiLauncher,
Belle Browser, Belle Remote, BelleAppCenter, Belle Files). It keeps the heavy sessions — WhatsApp Web in headless
Chrome, IMAP/SMTP, Google APIs, video conversion — and gives the phones a light HTTP API protected by a password.

> Türkçe kurulum: [../docs/SUNUCU_KURULUMU.md](../docs/SUNUCU_KURULUMU.md)

## Install

```bash
bash install.sh
```

Full guide (requirements, Google/e-mail setup, environment variables, troubleshooting):
[../docs/SERVER_SETUP.md](../docs/SERVER_SETUP.md).

## Modules

| File | Serves | Used by |
|---|---|---|
| `server.js` | password check, routing | all |
| `WhatsappClient.js`, `messageRouter.js`, `connect.js` | WhatsApp sessions, chats, media, notifications (`/api/...`, `/login`, `/qr/...`) | WhatsBelle |
| `mail.js` | IMAP/SMTP, `/mail/...`, `/mail/setup` | BelleMail, WhatsBelle |
| `drive.js` | Google Drive, `/drive/...`, `/drive/setup` | Belle Files, BelleAppCenter |
| `youtube.js`, `google.js` | search, streams, comments, subscriptions, `/yt/...` | BelleTube |
| `ai.js` | OpenAI / Anthropic / Google / xAI proxy, `/ai/...` | ApiLauncher |
| `katman.js`, `okuyucu.js` | compression proxy, image shrinking, reading mode, `/tb/...` | Belle Browser |
| `uzak.js`, `tarayici.js` | phone ↔ PC remote-desktop relay, server-side Chrome, `/uzak/...` | Belle Remote, Belle Remote PC |
| `panel.js`, `panel_uyg.js`, `panel_uzak.js` | web panel `/panel` (apps + remote desktop in a desktop browser) | browser |
| `anahtar.js` | main password (`BELLE_KEY` / `.bellekey`) + optional second password (`.bellekey2`) | |

## Main WhatsApp endpoints

| Endpoint | Purpose |
|---|---|
| `GET /TR/:number/start` | start a session for a number (QR when needed) |
| `GET /login-status/:number` | is the session ready, is a QR available |
| `GET /qr/:number.png` | QR image |
| `GET /api/login/:number` | session info (401 if none) |
| `GET /api/chats/:number` | chat list |
| `GET /api/messages/:number/:chat` | messages |
| `POST /api/messages`, `/api/upload`, `/api/location`, `/api/react` | send |
| `GET /api/notify/:number?since=` | notification queue |

Several numbers can be connected at the same time; each has its own Chrome profile in `.wwebjs_auth/session-<number>`.
Every request needs the `X-Api-Key` header or `?key=`.
