# Installing the apps on the phone

## Requirements

- Nokia E6 (or another Symbian^3 / Anna / Belle phone) with **Qt 4.7.4 or newer** — Belle ships Qt 4.8.
- **QtMobility 1.1+** (preinstalled on Belle).
- A memory card is recommended (caches, downloads, settings mirror).

### Recommended: TLS 1.2 patch

Symbian^3 / Anna / Belle only speak TLS 1.0 out of the box. Installing the community TLS 1.2 patch is
strongly recommended — the server-free apps (BelleMail, BelleGram, BelleCast, BelleCeviri, BelleKitap)
connect to modern HTTPS/TLS services much more reliably with it, and the phone's own browser, mail and
store start working again:

- **Symbian TLS 1.2 patch (system):** <https://github.com/shinovon/symbian-tls> (downloads: <https://nnproject.cc/tls/>)
- **Qt TLS 1.2 patch (Qt apps):** <https://github.com/shinovon/qt-patches> (downloads: <https://nnproject.cc/qtls/>)

Step-by-step notes: [TLS_PATCH.md](TLS_PATCH.md).

## Installing a `.sis`

1. Download the `.sis` files from the Releases page (or build them, see [BUILDING.md](BUILDING.md)).
2. On the phone: *Settings → Application manager → Installation settings → Software installation:* **All**.
   The packages are self-signed, so the phone asks for confirmation; accept.
3. Copy the files to the phone (USB mass storage, Bluetooth, or download in the browser) and open them.
4. Open the app → *Settings* → enter your **server address** and **password** (see [SERVER_SETUP.md](SERVER_SETUP.md)).

Upgrading: install the new `.sis` over the old one. Settings are kept, and most apps also mirror their settings
to the memory card (`E:\...`), so they come back automatically after a phone reset or a ROM flash.

## Packages that need more than self-signing

| Package | Why | How |
|---|---|---|
| **WhatsBelle** (`WhatsBelle.sis`) | embeds the Pigler plugin (`All -Tcb`) | the app itself installs on any phone; the embedded Pigler part needs a hacked phone (Install Server patch). Skip Pigler if your phone is not hacked — WhatsBelle still works. Reboot after installing Pigler. |
| **BelleMiddleKey** (`BelleMiddleKey.sis`) | `SwEvent`, `ReadDeviceData`, `WriteDeviceData`, `PowerMgmt` | a hacked phone (Install Server patch, see [TLS_PATCH.md](TLS_PATCH.md#0-prerequisites-both-patches)) or a developer certificate; the self-signed SIS is rejected on a stock phone |

## Language

All apps follow the phone language (Turkish → Turkish, anything else → English). To force a language open any
app's settings and tap **Dil / Language**; the choice is shared by all apps (`C:\Data\E6\dil.ini`) and applies
the next time each app starts. PC apps follow the Windows display language; put `en` or `tr` in a `dil.txt`
file next to the `.exe` to override.

## Optional extras

- [TLS patches](TLS_PATCH.md) – direct HTTPS for ApiLauncher, Belle Maps search, Belle Files Google mode.
- [Pigler](PIGLER.md) – WhatsBelle notifications in the status-bar drawer.
