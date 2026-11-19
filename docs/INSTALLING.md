# Installing the apps on the phone

## Requirements

- Nokia E6 (or another Symbian^3 / Anna / Belle phone) with **Qt 4.7.4 or newer** — Belle ships Qt 4.8.
- **QtMobility 1.1+** (preinstalled on Belle).
- A memory card is recommended (caches, downloads, settings mirror).

### Recommended: TLS 1.2 patch

Symbian^3 / Anna / Belle only speak TLS 1.0 out of the box. Apps that connect to HTTPS services directly
(for example BelleMail, BelleCeviri, BelleKitap) need the Qt TLS 1.2 patch; the system patch makes the
phone's own browser, mail and store work again:

- **Symbian TLS 1.2 patch (system):** <https://github.com/shinovon/symbian-tls> (downloads: <https://nnproject.cc/tls/>)
- **Qt TLS 1.2 patch (Qt apps):** <https://github.com/shinovon/qt-patches> (downloads: <https://nnproject.cc/qtls/>)

Step-by-step notes: [TLS_PATCH.md](TLS_PATCH.md).

## Installing a `.sis`

1. Download the `.sis` files from the Releases page (or build them, see [BUILDING.md](BUILDING.md)).
2. On the phone: *Settings → Application manager → Installation settings → Software installation:* **All**.
   The packages are self-signed, so the phone asks for confirmation; accept.
3. Copy the files to the phone (USB mass storage, Bluetooth, or download in the browser) and open them.
4. Apps that use the server (see the table in the README): open *Settings* and enter your **server address**
   and **password** (see [SERVER_SETUP.md](SERVER_SETUP.md)). The other apps work right away.

Upgrading: install the new `.sis` over the old one. Settings are kept, and most apps also mirror their settings
to a memory drive (`<drive>:\BelleYedek\Uygulamalar`, see below), so they come back automatically after a phone reset or a ROM flash.

## Packages that need more than self-signing

| Package | Why | How |
|---|---|---|
| **WhatsBelle**, **BelleMail**, **BelleGram** | embed the Pigler plugin (`All -Tcb`) for status-bar notifications | the apps install on any phone; the embedded Pigler part needs a hacked phone (Install Server patch). Skip Pigler if your phone is not hacked — the apps still work. Reboot after installing Pigler. |
| **BelleMiddleKey** (`BelleMiddleKey.sis`) | `SwEvent`, `ReadDeviceData`, `WriteDeviceData`, `PowerMgmt` | a hacked phone (Install Server patch, see [TLS_PATCH.md](TLS_PATCH.md#0-prerequisites-both-patches)) or a developer certificate; the self-signed SIS is rejected on a stock phone |

## Language

All apps follow the phone language (Turkish → Turkish, anything else → English). To force a language open any
app's settings and tap **Dil / Language**; the choice is shared by all apps (`C:\Data\E6\dil.ini`) and applies
the next time each app starts. PC apps follow the Windows display language; put `en` or `tr` in a `dil.txt`
file next to the `.exe` to override.

## Storage location

Caches, downloads and other large files go to one drive per app, chosen at start-up in this order:

1. the drive the app is installed on, if it is not `C:`;
2. the memory card (removable drive, e.g. `F:` on the E6);
3. the internal mass memory (e.g. `E:` on the E6);
4. `C:` (phone memory, small, so last).

A drive is skipped if it is missing, read-only, has less than 2 MB free, or a test file cannot be written and read
back (failing cards often stay visible but stop writing). To pick a drive yourself, open the app's settings and tap
**Storage location**: Automatic → each working drive → `C:`. The choice is stored per app in `C:\Data\E6\depo.ini`
and applies the next time the app starts. Files that are already on another drive are not moved.

Available in ApiLauncher, BelleBrowser, BelleCast, BelleFiles, BelleGram, BelleKitap, BelleMail, BelleMaps,
BelleMusic, BelleRemote, BelleTube and BelleVideo. The settings mirror uses its own fixed order: a working drive that
already holds `BelleYedek`, otherwise memory card → mass memory → `C:`. Your own notes in Belle Files stay where they
are.

## Optional extras

- [TLS patches](TLS_PATCH.md) – HTTPS for the apps that reach services directly, plus direct modes in ApiLauncher,
  Belle Maps search and Belle Files (Google).
- [Pigler](PIGLER.md) – WhatsBelle, BelleMail and BelleGram notifications in the status-bar drawer.
