# Pigler — status-bar notifications on Belle

Symbian Belle has a notification drawer (pull down the status bar), but the public SDK offers no API for
third-party apps to put their own entries there. **[Pigler](https://github.com/piglerorg/pigler)** fills that
gap: a small indicator plugin that runs inside the system UI and a client library apps link against.

**WhatsBelle** uses it so that new messages show the sender and text in the drawer; tapping the entry opens
that chat. Without Pigler, WhatsBelle falls back to a corner pop-up and the system's generic
"new chat message" note.

**BelleMail** (new e-mail) and **BelleGram** (new Telegram messages) use it the same way (`bildirim.cpp` in
each app) and embed the same `Pigler.sis`.

## What is in this repository

| Path | What |
|---|---|
| `apps/kutuphane/pigler/` | unmodified copy of the Pigler repository (GPL-3.0), including plugin sources |
| `apps/kutuphane/pigler/qt-library/pigler.pri` | Qt client (`QPiglerAPI`), included by `apps/WhatsBelle/WhatsBelle.pro` |
| `apps/kutuphane/pigler/sis_hazir/Pigler.sis` | prebuilt plugin package 1.4.1 (UID `0x20292B69`) from the Pigler project |
| `apps/WhatsBelle/notify.cpp` | how WhatsBelle uses it: `initPigler()`, `postKind()`, `onPiglerTap()`, `clearPosted()` |

`WhatsBelle.pro` embeds `Pigler.sis` into `WhatsBelle.sis`, so installing WhatsBelle also offers to install the
plugin (one installation, then **reboot**).

## Requirements and risks

- The plugin is an ECom indicator plugin loaded by a system process and needs **`All -Tcb`** capabilities.
  Such a package can only be installed on a **hacked** phone (Install Server patch) or signed with a
  developer certificate.
- A bug in the plugin can freeze or reboot the phone, because it runs inside the system UI. Back up first.
- No sound or vibration from the plugin itself (WhatsBelle vibrates on its own). Not shown on the lock screen.
- Max 10 notifications per app, 100 total; each has 2 lines of up to 63 characters and an optional 52 px icon.
- `setLaunchAppOnTap(true)` can start a second instance while the app is already running, so WhatsBelle keeps it
  `false` while running and switches it to `true` when it closes.
- The plugin itself can only be built with the **Belle SDK** (`CAknIndicatorPlugin::AddStatusPanelItemL` is
  Belle-only); the client library builds with the Symbian^3 Qt 4.7.4 SDK used for our apps.

## Using it in another app

```qmake
symbian {
    include($$PWD/../kutuphane/pigler/qt-library/pigler.pri)   # QPiglerAPI, -lrandom -laknnotify
}
```

```cpp
#include "QPiglerAPI.h"
QPiglerAPI *p = new QPiglerAPI(this);
p->setAppId(0xE39CF226);              // UID3 of the app to launch on tap (call before init)
qint32 r = p->init("MyApp");          // < 0: plugin missing; > 0: the app was started by tapping an entry
connect(p, SIGNAL(handleTap(qint32)), this, SLOT(onTap(qint32)));
qint32 id = p->createNotification("Title", "Text");
p->updateNotification(id, "Title", "New text");
p->setNotificationIcon(id, QImage(":/images/icon.png"));
p->removeNotification(id);
```

## License

Pigler is © its authors and licensed under **GPL-3.0**. Because WhatsBelle links the Pigler client library,
WhatsBelle (and, for simplicity, this whole repository) is distributed under GPL-3.0 as well.
