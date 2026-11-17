# Server setup

The server (`server/`) is a single Node.js process. It serves every phone app over plain HTTP and keeps
the heavy sessions (WhatsApp Web in headless Chrome, IMAP, Google APIs, video conversion) on its side.

> Türkçe: [SUNUCU_KURULUMU.md](SUNUCU_KURULUMU.md)

## 1. Requirements

| | Minimum | Recommended |
|---|---|---|
| OS | Ubuntu 22.04 / 24.04 or Debian 12, x86_64 | Ubuntu 22.04 LTS |
| CPU / RAM | 1 vCPU / 1 GB (+2 GB swap, created automatically) | 2 vCPU / 2–4 GB |
| Disk | 10 GB | 20 GB (BelleTube caches videos, default limit 4 GB) |
| Network | a public IPv4 address, TCP port **80** open | |

Any VPS works (Google Cloud e2-small, Hetzner CX22, Oracle free tier x86, a Raspberry Pi 4/5 with
Chromium, a spare PC at home with port forwarding…). One WhatsApp account uses ~300–500 MB RAM in Chrome.

> **Why HTTP and not HTTPS?** Stock Symbian Belle cannot negotiate modern TLS. Every request carries the
> server password (`X-Api-Key` header or `?key=`), so pick a long password and treat the server as personal.
> If you install the [TLS patches](TLS_PATCH.md) you may put HTTPS in front later. See [SECURITY.md](../SECURITY.md).

## 2. Install

```bash
# on your workstation
scp -r server/ user@your-server:~/belle-server
# on the server
cd ~/belle-server
bash install.sh
```

`install.sh` is idempotent (safe to run again) and does the following:

1. creates a 2 GB swap file when RAM < 2 GB
2. installs ffmpeg, build tools, emoji fonts
3. installs Node.js 20 (NodeSource)
4. installs Google Chrome (x86_64) or Chromium (ARM)
5. downloads **yt-dlp** to `~/bin` (BelleTube)
6. runs `npm install` (Puppeteer's own Chrome download is skipped, the system Chrome is used)
7. generates a random password in `.bellekey` (mode 600)
8. writes `ecosystem.config.js` and starts the service with **pm2** (auto-start on boot)
9. installs **Caddy** as a reverse proxy: port 80 → `127.0.0.1:3000`

At the end it prints:

```
Server address : http://203.0.113.10
Password       : xxxxxxxxxxxxxxxxxxxx
Web panel      : http://203.0.113.10/panel
```

Options: `--port 3100` (internal Node port), `--no-caddy` (bring your own proxy; Node only listens on 127.0.0.1).

**Open port 80** in your provider's firewall (Google Cloud: VPC firewall rule `tcp:80`; Oracle: security
list + `iptables`; AWS: security group).

## 3. Connect the phone apps

In every app open *Settings* and enter:

- **Server address**: `http://203.0.113.10` (your IP or a domain, no trailing slash)
- **Server password**: the value printed by `install.sh` (also in `~/belle-server/.bellekey`)

BelleMail, Belle Files and Belle Browser share one address file on the phone (`C:\Data\E6\sunucu.ini`), so setting it in
one of them sets it for all three.

## 4. Per-service setup

### WhatsApp (WhatsBelle)
Open WhatsBelle, type your number with country code (e.g. `447700900123`), press **Continue**. If the
number has no session on the server yet, the server starts one and the phone shows a QR code. Scan it from
the phone that has WhatsApp: *Settings → Linked devices → Link a device*. You can also open
`http://your-server/login` in a desktop browser. Sessions survive restarts (`.wwebjs_auth/`).

A second WhatsApp number can be added from *Settings → Accounts → Add 2nd account* (W²).

By default all groups are listed. Set `GROUP_FILTER` (see below) to show only groups whose name contains a word.

### E-mail (BelleMail, WhatsBelle mail tab)
Open `http://your-server/mail/setup` (browser asks for the password; user name can be anything).
Choose Gmail / Outlook / Yandex / Yahoo / iCloud or custom IMAP/SMTP. For Gmail create an
**app password** (Google Account → Security → 2-Step Verification → App passwords). Stored in `data/mail.json`.

### Google Drive (Belle Files)
1. In [Google Cloud Console](https://console.cloud.google.com/) create a project, enable **Google Drive API**.
2. *APIs & Services → Credentials → Create credentials → OAuth client ID*, type **Desktop app**.
3. Open `http://your-server/drive/setup`, paste the client ID and secret, press *Connect*. Google redirects to
   `http://127.0.0.1:8765/…` which will not open — copy that whole address from the browser bar and paste it
   back into the setup page. Tokens are stored in `data/`.
4. While the OAuth consent screen is in *Testing* mode, add your Google account as a test user.

### YouTube account (BelleTube subscriptions, optional)
BelleTube works without an account. To import your subscriptions: create an OAuth client of type
**TVs and Limited Input devices** (YouTube Data API v3 enabled), enter it at `http://your-server/yt/setup`,
then on the phone *BelleTube → Settings → Connect Google account* and type the shown code at `google.com/device`.

### AI keys (ApiLauncher, optional)
ApiLauncher can call OpenAI / Anthropic / Google / xAI directly (needs the TLS patch) or through the server.
For server mode enter your keys in the app and press *Save keys to the server*; they are stored in
`data/ai_keys.json` and never sent back to the phone.

### Remote desktop (Belle Remote + Belle Remote PC)
Nothing to configure on the server: the relay is built in (`/uzak/…`). On the PC run *Belle Remote PC*, enter
the server address and password, tick *Be reachable from anywhere through the server*.

## 5. Configuration (environment variables)

Edit `ecosystem.config.js`, then `pm2 restart belle-server --update-env`.

| Variable | Default | Meaning |
|---|---|---|
| `BELLE_KEY` | read from `.bellekey` | server password (required) |
| `PORT` | `3000` | internal port (Node listens on 127.0.0.1 only) |
| `CHROME_PATH` | `/usr/bin/google-chrome` | browser used by WhatsApp Web, server browser, reading mode |
| `YTDLP_PATH` | `~/bin/yt-dlp` | yt-dlp binary for BelleTube |
| `YT_CACHE_MAX_MB` | `4000` | BelleTube video cache limit |
| `CHAT_LIMIT` | `10` | chats per page sent to the phone |
| `MSG_LIMIT` | `50` | messages per chat |
| `KEEP_PER_CHAT` | `20` | messages kept in the server database per chat |
| `GROUP_FILTER` | `""` | only list groups whose name contains this word (`""` = all) |
| `AVATAR_SIZE` | `40` | profile picture size in pixels |

A second, optional password can be put in `.bellekey2` (e.g. to give a family member access and revoke it later).

## 6. Operating

```bash
pm2 logs belle-server          # live log
pm2 restart belle-server       # restart
cd ~/belle-server && git pull && npm install --omit=dev && pm2 restart belle-server   # update
~/bin/yt-dlp -U            # keep yt-dlp fresh when BelleTube stops working
```

Back up `data/`, `.wwebjs_auth/` and `.bellekey` to keep accounts and sessions.
Crash reports sent from the apps (*Send report*) land in `data/reports/`.

## 7. Troubleshooting

| Symptom | Fix |
|---|---|
| Apps say *could not connect* | port 80 closed in the cloud firewall; `curl -I http://your-ip/panel/giris` from outside |
| *Wrong server password* | compare with `.bellekey`; no spaces; restart after editing |
| QR code never appears | Chrome missing or out of memory: `pm2 logs`; check swap; `CHROME_PATH` |
| WhatsApp stops after a while | the server rebuilds a stuck session automatically; if it was logged out on the main phone, scan the QR again |
| BelleTube videos fail | `~/bin/yt-dlp -U` |
| Mail shows nothing | check `/mail/setup`; Gmail needs an app password and IMAP enabled |
