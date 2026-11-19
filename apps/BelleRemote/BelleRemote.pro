# Belle Remote - Symbian Belle telefonlar icin uzak masaustu + sunucu tarayicisi (Qt 4.7.4 / telefonda Qt 4.8)
# BelleRemote'tan turetildi (BelleRemote ayri uygulama olarak duruyor). PC tarafi: BelleRemote\pc\BelleRemotePC.exe
# Sunucu tarayicisi: sunucuda basliksiz Chrome (sunucu: tarayici.js), hedef=tarayici
TARGET = BelleRemote
TEMPLATE = app
QT += declarative network

SOURCES += main.cpp uzak.cpp
HEADERS += uzak.h
RESOURCES += resources.qrc
OTHER_FILES += qml/*.qml qml/*.js PROTOKOL.md

win32: CONFIG += console

symbian {
    TARGET.UID3 = 0xE39CF239
    VERSION = 1.4.2
    TARGET.CAPABILITY = NetworkServices
    INCLUDEPATH += /epoc32/include/mw /epoc32/include/platform/mw /epoc32/include/platform
    LIBS += -lcone -lws32 -lapgrfx -leuser -lefsrv -lbafl -letext -lestor
    TARGET.EPOCHEAPSIZE = 0x40000 0x3000000

    ICON = BelleRemote.svg
    DEPLOYMENT.display_name = Belle Remote
    vendorinfo = "%{\"Belle Remote\"}" ":\"Belle Remote\""
    my_deployment.pkg_prerules += vendorinfo
    DEPLOYMENT += my_deployment
}

# Ayar aynasi (E:/BelleYedek/Uygulamalar/BelleRemote)
include($$PWD/../kutuphane/ayna/ayna.pri)

# Dil destegi (Turkce / English): kutuphane/dil
include($$PWD/../kutuphane/dil/dil.pri)
include($$PWD/../kutuphane/depo/depo.pri)   # depolama yeri (kurulum surucusu / kart / E / C)

# Ortak sunucu adresi + HTTPS kok sertifikalari
include(../kutuphane/sunucu/sunucu.pri)

# Ortak pano yardimcisi (Ctrl+V: QML paste() E6da calismiyor)
include($$PWD/../kutuphane/pano/pano.pri)
