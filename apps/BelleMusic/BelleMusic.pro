# BelleMusic (eski adi E6Muzik 2) - muzik istemcisi (Nokia E6, Qt 4.7.4 + QtMobility)
# Yayin: s60tube muzik servisi (MIDPlay'in sunucusu). Kisisel derleme (kisisel.flag): yalnizca Belle sunucusu /muzik.
# UID, veri yollari (C:/Data/E6Muzik, LocalStorage "E6Muzik"), Ayna adi ESKI ADLARLA kalir: ayarlar ve kitaplik korunur.
TARGET = BelleMusic
# Kisisel derleme: klasorde "kisisel.flag" varsa uygulama yalnizca kendi Belle sunucumuza baglanir
# (yayina giden surum bu dosya olmadan derlenir ve s60tube kullanir).
exists($$PWD/kisisel.flag): DEFINES += BM_KISISEL
TEMPLATE = app
QT += declarative network
CONFIG += mobility
MOBILITY += multimedia

SOURCES += main.cpp music.cpp mediakeys.cpp
HEADERS += music.h relayconn.h mediakeys.h
RESOURCES += resources.qrc

OTHER_FILES += qml/*.qml qml/*.js

symbian {
    TARGET.UID3 = 0xE39CF22C
    VERSION = 2.0.0
    TARGET.CAPABILITY += NetworkServices
    # Ses ve kulaklik tuslari (RemCon)
    LIBS += -lremconcoreapi -lremconinterfacebase
    TARGET.EPOCHEAPSIZE = 0x40000 0x4000000
    TARGET.EPOCSTACKSIZE = 0x14000

    ICON = BelleMusic.svg
    DEPLOYMENT.display_name = BelleMusic

    vendorinfo = "%{\"BelleMusic\"}" ":\"BelleMusic\""
    my_deployment.pkg_prerules += vendorinfo
    DEPLOYMENT += my_deployment
}

# Ayar aynasi (E:/BelleYedek/Uygulamalar/E6Muzik2)
include($$PWD/../kutuphane/ayna/ayna.pri)

# Dil destegi (Turkce / English): kutuphane/dil
include($$PWD/../kutuphane/dil/dil.pri)
include($$PWD/../kutuphane/depo/depo.pri)   # depolama yeri (kurulum surucusu / kart / E / C)

# Ortak pano yardimcisi (Ctrl+V: QML paste() E6da calismiyor)
include($$PWD/../kutuphane/pano/pano.pri)
