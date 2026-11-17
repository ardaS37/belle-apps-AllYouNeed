# Building from source

## Toolchain

The apps target **Symbian^3 / Anna / Belle** with **Qt 4.7.4** (the phone runs Qt 4.8, which is backwards
compatible) and **QML 1.1** (QtQuick 1). The last official toolchain is Windows-only:

1. A **Windows 7** (32 or 64 bit) machine or VM. Newer Windows versions mostly work, but the Symbian build
   tools (sbsv2, Perl, GCCE 4.4.1) are happiest on Windows 7.
2. **Qt SDK 1.2.1 offline installer** (`QtSdk-offline-win-x86-v1.2.1.exe`). In the installer select
   *Symbian Toolchains → Symbian^3 Qt 4.7.4* (includes QtMobility 1.1.3) and *Qt Simulator* if you want to test UIs.
3. Optional: Qt Creator from the same SDK, and **CODA** on the phone for on-device run/debug over Wi-Fi.

## Folder layout

Every app's `.pro` file includes shared code with `$$PWD/../kutuphane/...`, so keep this layout:

```
apps/
  kutuphane/      shared library: ayna (settings mirror), harita (maps), pigler, dil (i18n)
  WhatsBelle/
  BelleFiles/
  ...
```

The Symbian build system does not like spaces or long paths. Copy to a short path first, e.g. `C:\WhatsBelle`
and `C:\kutuphane`.

## Command-line build

From a *Qt for Symbian^3* command prompt (or set the variables shown in `tools/build_env.bat`):

```bat
cd /d C:\WhatsBelle
qmake WhatsBelle.pro -r -spec symbian-sbsv2 "CONFIG+=release"
make release-gcce
make sis
```

The result is `WhatsBelle.sis`, **self-signed** with the SDK's default certificate. Apps that only use
user-grantable capabilities (`NetworkServices`, `ReadUserData`, `WriteUserData`, `UserEnvironment`, `Location`)
install on any phone. Others need a developer certificate or a hacked phone:

| App | Extra capabilities |
|---|---|
| BelleMiddleKey | `SwEvent WriteDeviceData ReadDeviceData PowerMgmt`: `make sis` fails (createpackage cannot strip SwEvent). Package by hand after `make release-gcce`: replace `$(PLATFORM)`→`armv5`, `$(TARGET)`→`urel` in `BelleMiddleKey_template.pkg`, then `makesis BelleMiddleKey_elle.pkg u.sis` and `signsis -s u.sis BelleMiddleKey.sis selfsigned.cer selfsigned.key` (from `epoc32/../src/s60installs`). The package also contains the Qt-free service `BelleMiddleKeyServis.exe` (`servis/servis.mmp`, added to bld.inf by the .pro). |
| WhatsBelle | embeds `Pigler.sis`, which needs `All -Tcb` (see [PIGLER.md](PIGLER.md)) |
| BelleWidgets (BelleWidgets) | home-screen widget plugin (see below) |

### BelleWidgets home-screen plugin

`apps/BelleWidgets` deploys Nokia's prebuilt **HSWidgetPlugin.dll** (from the *Symbian-HomeScreen-Widget-QML*
template project). The DLL is not included here; put it at `apps/BelleWidgets/bin/HSWidgetPlugin.dll` before building.

## Translations

UI strings are Turkish in the source and translated at runtime from `dil/en.txt` (see
[TRANSLATING.md](TRANSLATING.md)). `dil/en.txt` and `dil/dil.qrc` are generated: after editing UI text run

```powershell
tools\dil_cikar.ps1 -Uygulama apps\WhatsBelle
```

## PC apps

`pc/BelleRemotePC` is a single-folder C# WinForms program for .NET Framework 4.x.
Run `derle.bat` in each folder (uses `csc.exe` from the .NET Framework, no Visual Studio needed).

## Server

Plain Node.js 20, no build step: `npm install --omit=dev`, then `node server.js` with `BELLE_KEY` set.
See [SERVER_SETUP.md](SERVER_SETUP.md).

## Checking JavaScript

`tools\js_denetle.js` parses every QML JavaScript file with Windows' built-in ES5 engine (no Node needed):

```bat
cscript //nologo //E:{16d51579-a30b-4c8b-a276-0ff4dc41e755} tools\js_denetle.js apps\WhatsBelle\qml\Api.js ...
```
