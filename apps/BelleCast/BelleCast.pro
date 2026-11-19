# BelleCast - Nokia E6 (Symbian Belle, Qt 4.7.4 / QML 1.1): internet radyosu + podcast + haber (RSS)
# Radyo akislari telefon ici aktarma sunucusundan (yayin.cpp) oynaticiya verilir: ICY, HTTPS,
# yonlendirme ve calan sarki adi orada cozulur. Bizim sunucuyu kullanmaz.

TARGET = BelleCast
TEMPLATE = app
QT += declarative network xml
CONFIG += mobility
MOBILITY += multimedia

SOURCES += main.cpp yayin.cpp mediakeys.cpp
HEADERS += yayin.h mediakeys.h
RESOURCES += resources.qrc
OTHER_FILES += qml/*.qml qml/*.js

symbian {
    TARGET.UID3 = 0xE39CF240
    TARGET.CAPABILITY += NetworkServices
    # Kulaklik / bluetooth kumanda tuslari (RemCon)
    LIBS += -lremconcoreapi -lremconinterfacebase
    TARGET.EPOCHEAPSIZE = 0x40000 0x4000000
    TARGET.EPOCSTACKSIZE = 0x14000
    VERSION = 0.3.0
    ICON = BelleCast.svg
    DEPLOYMENT.display_name = BelleCast
    vendorinfo = "%{\"BelleCast\"}" ":\"BelleCast\""
    my_deployment.pkg_prerules += vendorinfo
    DEPLOYMENT += my_deployment
}

# Dil destegi (Turkce / English): kutuphane/dil
include($$PWD/../kutuphane/dil/dil.pri)
include($$PWD/../kutuphane/depo/depo.pri)   # depolama yeri (kurulum surucusu / kart / E / C)

# Ortak pano yardimcisi (Ctrl+V: QML paste() E6da calismiyor)
include($$PWD/../kutuphane/pano/pano.pri)
