# TLS 1.2 / 1.3 on Symbian Belle

Out of the box Symbian Belle only speaks SSL 3.0 / TLS 1.0 with old cipher suites. Practically every modern
HTTPS site and API refuses that. The apps in this repository are built so that **nothing requires TLS**:
they talk plain HTTP to your own server, and the server makes the HTTPS calls. Installing the community TLS
patches is optional, but it unlocks extra features:

| App | Without the patch | With the patch |
|---|---|---|
| ApiLauncher | AI calls go through your server (keys stored there) | *Direct (HTTPS)* mode: phone → provider, keys stay on the phone |
| Belle Maps | address search through your server (option in Settings) | direct Photon/Nominatim search; HTTPS tile servers |
| Belle Files | Drive through your server | *Google direct* mode with your own OAuth client |
| Belle Browser | heavy HTTPS sites through the server layer | direct HTTPS browsing for most sites |
| Built-in browser, Nokia Store, e-mail, video streaming | mostly broken | work again |

There are **two independent patches**. Qt apps (all of ours) use Qt's own network stack, so they need the
Qt patch; the system patch fixes native apps (web browser, mail, video player…).

> ⚠️ Both patches replace system files on a *hacked* phone. Make a full backup first, read every step,
> and use them at your own risk. They are made by the Symbian community, not by this project; we only
> describe how they were used on the test phone. Get the files from the original authors (links below).

## 0. Prerequisites (both patches)

1. A phone with **Norton/HelloOX-style hack** applied and **RomPatcher+** installed
   (search *"Symbian Belle hack HelloOX2"* / *"Norton hack Belle"* on [nnproject.cc](https://nnproject.cc/) forums).
2. In RomPatcher+ apply (and add to *Auto*): **Open4All** and **Install Server RP+**.
3. A file manager that can see system folders, e.g. **X-plore** (*Settings → Show system files*).
4. Know your Qt version: install `qtversiontest.sis` from the Qt patch package. Belle / Belle Refresh / Belle FP1
   ship **Qt 4.8.0**, Belle FP2 ships **Qt 4.8.1**.

## 1. Qt TLS 1.2 patch (needed by Qt apps)

Source: **nnproject Qt TLS patch** — <https://nnproject.cc/qtls/> (package `qtls.zip`); source code:
<https://github.com/shinovon/qt-patches> and <https://github.com/shinovon/openssl-symbian>.

| Firmware | Install |
|---|---|
| Belle / Belle Refresh / Belle FP1 (Qt 4.8.0) | install `QtNetwork_4.8.0.sis`, reboot |
| Belle FP2 (Qt 4.8.1) | install `QtNetwork_4.8.1.sis`, reboot |
| Symbian^3 / Anna (Qt 4.7.4) | if `C:\sys\bin\QtNetwork.dll` is missing install `QtNetwork_4.7.4.sis`; otherwise copy `474\QtNetwork.dll` to `C:\sys\bin` with Open4All |
| S60v3 FP1/FP2, S60v5 (Qt 4.7.3) | copy `473_9x\QtNetwork.dll` to `C:\sys\bin` |

If installation fails with **"Component is built-in"**, use the *RunInstallServerNotForRom* patch instead of
*Install Server RP+*: copy `RunInstallServerNotForRom.rmp` to `C:\patches\` and `ynstallserver.exe` to
`C:\sys\bin\` (both are in the `ynstallserver` folder of the package), apply it in RomPatcher+, try again.

## 2. System TLS patch (native apps)

Source: **symbian-tls** by shinovon (an mbedTLS based replacement of `ssl.dll`) —
<https://github.com/shinovon/symbian-tls>, distributed via <https://nnproject.cc/tls/>. Version 1.4 (v14) adds TLS 1.2; later builds (v21) add TLS 1.3.

The usual way is to install the provided `.sis`. Manual method used on the test phone (Belle Refresh):

1. Connect the phone in *Mass storage* mode and copy the package's `sys\bin\ssl.dll`, `sys\bin\mbedtls.dll`
   and the matching `sys\hash\…` files to the memory card (e.g. `E:\TLS\`).
2. On the phone: RomPatcher+ → apply **Open4All**.
3. X-plore: back up the existing `C:\sys\bin\ssl.dll` (and `mbedtls.dll` if present) to the card.
4. Copy the new files to `C:\sys\bin\` and `C:\sys\hash\` (overwrite). If you get *"in use"*, close the browser
   and network apps, or reboot and copy before opening anything.
5. Reboot. Test with `https://www.howsmyssl.com` in the stock browser.

**Certificate checks.** With a CA bundle in `C:\resource\mbedtls\cacerts\` the library verifies server
certificates (recommended). Without that folder some builds skip verification, which silences certificate
warnings but makes man-in-the-middle attacks possible — only do that knowingly.

**Undo:** copy your backed-up `ssl.dll` back to `C:\sys\bin\` and reboot.

## 3. HTTPS video streaming (optional)

nnproject also publishes *Belle HTTPS streaming* (<https://nnproject.cc/bellehttpsplayer/>), which makes the
stock video player stream HTTPS URLs (`playbackhelper.sis` + `httpfsys.dll` / `hxnetwksvc.dll`). Some FP2
devices additionally need the *c2z4bin* patch with DomainSrv. Not required by our apps.

## Verifying in our apps

- ApiLauncher → Settings → Connection → *Direct (HTTPS)* → **Test connection**.
- Belle Maps → Settings → turn *Use the server for search* off and search an address.

If a test fails, the apps fall back to the server automatically where possible.
