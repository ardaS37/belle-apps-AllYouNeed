# BelleVideo - yerel video oynatici (Nokia E6, Qt 4.7.4 + QtMobility)
# Star Player'in (Allstar Software, MIT) yeteneklerinden yola cikilarak bastan yazildi:
# arka planda video sesi, calma listesi, akis + indirme, kaldigi yerden devam, klavye ile kullanim.
# Bizim sunucuyu kullanmaz.

TARGET = BelleVideo
TEMPLATE = app
QT += declarative network
CONFIG += mobility
MOBILITY += multimedia systeminfo

SOURCES += main.cpp lib.cpp audioextract.cpp nativevideo.cpp mediakeys.cpp sysstate.cpp
HEADERS += lib.h serveconn.h audioextract.h nativevideo.h mediakeys.h sysstate.h
RESOURCES += resources.qrc

OTHER_FILES += qml/*.qml qml/*.js

symbian {
    TARGET.UID3 = 0xE39CF233
    TARGET.CAPABILITY += NetworkServices
    # Ses ve kulaklik tuslari (RemCon)
    LIBS += -lremconcoreapi -lremconinterfacebase
    # Arka plana alma, uygulama onde mi
    LIBS += -lcone -lws32 -lapgrfx
    # Ekran isigi (ekran kapandi mi)
    LIBS += -lhwrmlightclient
    TARGET.EPOCHEAPSIZE = 0x40000 0x4000000
    TARGET.EPOCSTACKSIZE = 0x14000

    VERSION = 1.1.0
    ICON = BelleVideo.svg
    DEPLOYMENT.display_name = BelleVideo

    vendorinfo = "%{\"BelleVideo\"}" ":\"BelleVideo\""
    my_deployment.pkg_prerules += vendorinfo
    DEPLOYMENT += my_deployment
}

# Ayar aynasi (E:/BelleYedek/Uygulamalar/BelleVideo)
include($$PWD/../kutuphane/ayna/ayna.pri)

# Dil destegi (Turkce / English): kutuphane/dil
include($$PWD/../kutuphane/dil/dil.pri)
include($$PWD/../kutuphane/depo/depo.pri)   # depolama yeri (kurulum surucusu / kart / E / C)

# Ortak pano yardimcisi (Ctrl+V: QML paste() E6da calismiyor)
include($$PWD/../kutuphane/pano/pano.pri)
