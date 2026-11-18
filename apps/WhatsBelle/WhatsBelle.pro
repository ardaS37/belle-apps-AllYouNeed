# WhatsBelle (WhatsBelle) - kendi WhatsBelle sunucusu icin Qt Quick WhatsApp istemcisi
# Hedef: Nokia E6 (Symbian Anna/Belle, 640x480), Qt 4.7.4 + QtMobility (ses kaydi)

TARGET = WhatsBelle
TEMPLATE = app
QT += declarative network
CONFIG += mobility
MOBILITY += multimedia

SOURCES += main.cpp device.cpp notify.cpp mediakeys.cpp
HEADERS += device.h notify.h mediakeys.h
RESOURCES += resources.qrc

OTHER_FILES += \
    qml/main.qml \
    qml/Api.js \
    qml/Util.js \
    qml/LoginPage.qml \
    qml/ChatListPage.qml \
    qml/ChatPage.qml \
    qml/ContactsPage.qml \
    qml/SettingsPage.qml \
    qml/MediaPicker.qml \
    qml/Header.qml \
    qml/IconButton.qml \
    qml/Avatar.qml \
    qml/BottomNav.qml \
    qml/TextField.qml \
    qml/Toast.qml

symbian {
    TARGET.UID3 = 0xE39CF226
    # NetworkServices: internet, UserEnvironment: mikrofon (sesli mesaj)
    TARGET.CAPABILITY += NetworkServices UserEnvironment

    # Arka plan bildirimi (kose bildirimi), titresim, acilista baslatma
    INCLUDEPATH += /epoc32/include/mw /epoc32/include/platform/mw /epoc32/include/platform
    LIBS += -lavkon -laknskins -leikcore -lcone -lws32 -lapgrfx -lhwrmvibraclient -lhwrmlightclient -lhal -leuser -laknnotify
    # Durum cubugu cekmecesi bildirimleri: Pigler istemcisi (ortak kutuphane, GPL-3.0)
    include($$PWD/../kutuphane/pigler/qt-library/pigler.pri)
    # Pigler eklentisi WhatsBelle.sis icine gomulur: tek kurulum (eklenti ilk kurulumdan sonra
    # telefonun yeniden baslatilmasini ister). Paket kendi Belle/Anna/N97 secimini yapar.
    pigler_embed.pkg_postrules = "@\"$$PWD/../kutuphane/pigler/sis_hazir/Pigler.sis\",(0x20292B69)"
    DEPLOYMENT += pigler_embed
    # Ses tuslari (sesli mesaj ses duzeyi): RemCon
    LIBS += -lremconcoreapi -lremconinterfacebase
    MMP_RULES += "SOURCEPATH ." "START RESOURCE E39CF226.rss" "TARGETPATH /private/101f875a/import" "END"
    startup.pkg_postrules = "\"C:/QtSDK/Symbian/SDKs/Symbian3Qt474/epoc32/data/z/private/101f875a/import/E39CF226.rsc\" - \"c:/private/101f875a/import/[E39CF226].rsc\""
    DEPLOYMENT += startup
    TARGET.EPOCHEAPSIZE = 0x40000 0x4000000
    TARGET.EPOCSTACKSIZE = 0x14000

    ICON = WhatsBelle.svg
    VERSION = 1.12.1
    DEPLOYMENT.display_name = WhatsBelle

    vendorinfo = "%{\"WhatsBelle\"}" ":\"WhatsBelle\""
    my_deployment.pkg_prerules += vendorinfo
    DEPLOYMENT += my_deployment
}

# Ayar aynasi (E:/BelleYedek/Uygulamalar/WhatsBelle)
include($$PWD/../kutuphane/ayna/ayna.pri)
# Konum gonderme / gosterme: harita, karo onbellegi, GPS (kutuphane/harita)
include($$PWD/../kutuphane/harita/harita.pri)

# Dil destegi (Turkce / English): kutuphane/dil
include($$PWD/../kutuphane/dil/dil.pri)

# Ortak sunucu adresi + HTTPS kok sertifikalari
include(../kutuphane/sunucu/sunucu.pri)

# Ortak pano yardimcisi (Ctrl+V: QML paste() E6da calismiyor)
include($$PWD/../kutuphane/pano/pano.pri)
