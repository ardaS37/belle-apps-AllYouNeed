# Security notes

These apps and the server are a **personal** setup: one owner, a handful of devices. Read this before
exposing a server to the internet.

## Transport

- With a domain name in front of the server (Caddy obtains the certificate) and the [Qt TLS patch](docs/TLS_PATCH.md)
  on the phone, the apps talk to the server over **HTTPS**. Without a domain, traffic is **plain HTTP** and anyone
  on the network path (public Wi-Fi, mobile operator) can read it, including the server password and messages.
- The phone's built-in media player and browser cannot do modern TLS, so the media links the apps hand to them
  (video/audio streams) always use plain HTTP.
- Mitigations: use a long random password (the installer creates one), use a domain with HTTPS, and avoid
  untrusted Wi-Fi. Desktop browsers (web panel, setup pages) should always use HTTPS.

## Authentication

- Every endpoint except the panel login page requires the password (`X-Api-Key` header, `?key=` for media URLs,
  HTTP Basic auth in browsers, or a cookie derived from the password for the web panel).
- `.bellekey2` can hold a second password that you can revoke independently.
- There is **no rate limiting**. Put the server behind a firewall that only allows port 80 (and SSH), and consider
  fail2ban or a VPN if you need more.

## Data on the server

| Location | Contents |
|---|---|
| `.wwebjs_auth/` | WhatsApp Web session (full access to your WhatsApp account) |
| `data/whatse6.db` | recent messages cached for the phone |
| `data/mail.json` | IMAP/SMTP credentials (use an app password) |
| `data/drive*.json`, `data/google*.json` | Google OAuth client and tokens |
| `data/ai_keys.json` | AI provider API keys (ApiLauncher server mode) |
| `data/reports/` | logs sent by the apps' *Send report* button |
| `media/` | converted photos, voice notes, videos |

Protect the server like you would protect your phone: keep the OS updated, use SSH keys, back up `data/` and
`.wwebjs_auth/` to an encrypted location.

## Phone

- API keys entered in ApiLauncher (direct mode) and Google OAuth secrets entered in Belle Files are stored in the
  apps' private folders. The source code contains **no** keys or OAuth client secrets; you supply your own.
- If you disable certificate verification in the system TLS patch, HTTPS no longer protects against
  man-in-the-middle attacks.

## Unofficial clients

WhatsApp, Google and YouTube do not endorse third-party clients. Accounts used through automation may be
restricted. Use at your own risk.

## Reporting a problem

Please open a GitHub issue without sensitive details, or contact the maintainer privately for anything that
could put users at risk.
