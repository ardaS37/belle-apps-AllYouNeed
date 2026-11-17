# Accounts: Telegram API ID and e-mail app passwords

> 🇹🇷 Türkçe: [HESAPLAR.md](HESAPLAR.md)

BelleGram and BelleMail work **without a server**: the phone talks to Telegram and to your mail
provider directly. Nothing is built into the apps — you enter your own details once, and they are
stored only in the app's private folder on the phone.

## BelleGram: your Telegram `api_id` and `api_hash`

Every Telegram client needs an application ID. BelleGram does not ship one (a published ID gets
blocked by Telegram), so you create your own. It is free and takes two minutes, on a computer:

1. Open **https://my.telegram.org** and sign in with your phone number (with country code, e.g.
   `+905321234567`). Telegram sends the login code **to your Telegram app**, not by SMS.
2. Click **API development tools**.
3. Fill in the form (only the first two fields matter):
   - *App title*: `BelleGram`
   - *Short name*: `bellegram` (5–32 letters/digits)
   - *Platform*: **Other** (or Desktop)
   - URL and description can stay empty.
4. Click **Create application**. The page now shows:
   - **App api_id** — a number, e.g. `12345678`
   - **App api_hash** — 32 characters (0-9, a-f)
5. On the phone open BelleGram. The first screen asks for these two values — type them (Ctrl+V pastes)
   and press **Save and continue**, then sign in with your phone number as usual.

Keep the `api_hash` to yourself and never post it publicly. You can change it later in BelleGram →
Settings → *Change API details* (this signs you out).

If "Create application" shows a plain *ERROR*, try again later or from another browser/network — the
form is known to be picky (an ad blocker or VPN often causes it).

## BelleMail: app password

BelleMail signs in with IMAP/SMTP. Big providers do not accept your normal password there; they want
an **app password** — a separate 16-character password only for this app, which you can revoke any time.

### Gmail

1. Your Google account must have **2-Step Verification** turned on:
   https://myaccount.google.com/signinoptions/twosv
2. Open **https://myaccount.google.com/apppasswords** (sign in again if asked).
3. Type a name, e.g. `BelleMail`, and click **Create**.
4. Google shows a 16-letter password (`abcd efgh ijkl mnop`). Type it in BelleMail → *App password*
   (spaces are optional). Google will not show it again — create a new one if you lose it.

IMAP is always on for Gmail accounts now; no extra setting is needed.

### Yandex
id.yandex.com → **Security** → **App passwords** → *Mail*. Also turn on IMAP in Yandex Mail →
Settings → *Email clients*.

### Yahoo
Account security → **Generate app password**.

### iCloud
https://appleid.apple.com → **Sign-In and Security** → **App-Specific Passwords**.

### Other providers / your own domain
Choose *Other* and enter the IMAP server (port 993, TLS) and SMTP server (465 TLS or 587 STARTTLS).
Usually your normal mailbox password works.

**Outlook / Hotmail** only accept OAuth sign-in since 2024, so they are not supported yet.

## Notifications

BelleMail checks for new mail every 5 minutes (Menu → *New mail check*: 2/5/15/30 min or off) while
it is running. Press **Back** on the inbox (or Menu → *Send to background*) instead of closing the
app; new mail then appears in the status-bar drawer ([Pigler](PIGLER.md)) and as a pop-up.
