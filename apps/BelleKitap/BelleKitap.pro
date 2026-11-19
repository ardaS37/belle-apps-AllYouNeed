# BelleKitap - Nokia E6 (Symbian Belle, Qt 4.7.4 / QML 1.1): EPUB ve TXT e-kitap okuyucu
# EPUB zip'i Belle Files'in zip koduyla acilir (zip.cpp), OPF/NCX/nav QXmlStreamReader ile okunur.

TARGET = BelleKitap
TEMPLATE = app
QT += declarative network

SOURCES += main.cpp kitap.cpp zip.cpp zipsifre.cpp
HEADERS += kitap.h zip.h zipsifre.h
RESOURCES += resources.qrc
OTHER_FILES += qml/*.qml qml/*.js

symbian {
    TARGET.UID3 = 0xE39CF242
    TARGET.CAPABILITY += NetworkServices
    TARGET.EPOCHEAPSIZE = 0x40000 0x4000000
    TARGET.EPOCSTACKSIZE = 0x14000
    VERSION = 0.3.0
    ICON = BelleKitap.svg
    DEPLOYMENT.display_name = BelleKitap
    vendorinfo = "%{\"BelleKitap\"}" ":\"BelleKitap\""
    my_deployment.pkg_prerules += vendorinfo
    DEPLOYMENT += my_deployment
}

include($$PWD/../kutuphane/dil/dil.pri)
include($$PWD/../kutuphane/depo/depo.pri)   # depolama yeri (kurulum surucusu / kart / E / C)

# Ortak pano yardimcisi (Ctrl+V: QML paste() E6da calismiyor)
include($$PWD/../kutuphane/pano/pano.pri)
