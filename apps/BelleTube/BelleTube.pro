# BelleTube - kendi sunucusu uzerinden YouTube istemcisi (Nokia E6, Qt 4.7.4 + QtMobility)

TARGET = BelleTube
TEMPLATE = app
QT += declarative network
CONFIG += mobility
MOBILITY += multimedia systeminfo

SOURCES += main.cpp tube.cpp nativevideo.cpp volumekeys.cpp sysstate.cpp
HEADERS += tube.h proxyconn.h nativevideo.h volumekeys.h sysstate.h
RESOURCES += resources.qrc

OTHER_FILES += qml/*.qml qml/*.js

symbian {
    TARGET.UID3 = 0xE39CF227
    TARGET.CAPABILITY += NetworkServices
    # Ses tuslari (RemCon)
    LIBS += -lremconcoreapi -lremconinterfacebase
    # Uygulama onde mi (pencere grubu odagi)
    LIBS += -lcone -lws32
    TARGET.EPOCHEAPSIZE = 0x40000 0x4000000
    TARGET.EPOCSTACKSIZE = 0x14000

    VERSION = 1.1.0
    ICON = BelleTube.svg
    DEPLOYMENT.display_name = BelleTube

    vendorinfo = "%{\"BelleTube\"}" ":\"BelleTube\""
    my_deployment.pkg_prerules += vendorinfo
    DEPLOYMENT += my_deployment
}

# Ayar aynasi (E:/BelleYedek/Uygulamalar/BelleTube)
include($$PWD/../kutuphane/ayna/ayna.pri)

# Dil destegi (Turkce / English): kutuphane/dil
include($$PWD/../kutuphane/dil/dil.pri)
include($$PWD/../kutuphane/depo/depo.pri)   # depolama yeri (kurulum surucusu / kart / E / C)

# Ortak sunucu adresi + HTTPS kok sertifikalari
include(../kutuphane/sunucu/sunucu.pri)

# Ortak pano yardimcisi (Ctrl+V: QML paste() E6da calismiyor)
include($$PWD/../kutuphane/pano/pano.pri)
