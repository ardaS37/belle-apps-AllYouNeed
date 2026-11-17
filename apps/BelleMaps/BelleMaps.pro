# Belle Maps (eski adi Belle Harita) - hizli, hafif harita (Nokia E6, Symbian Belle, Qt 4.7.4 / telefonda Qt 4.8)
# s60-maps'ten: OpenStreetMap karolari, katman secimi, adres arama, rota (OSRM), GPS
# MahoMaps'ten: karolarin karta onbelleklenmesi (cevrimdisi bakilan yerler), koyu tema, kayitli yerler
# Karolar CARTO / OpenTopoMap (duz HTTP); arama Photon (HTTPS, istege bagli sunucu uzerinden); rota OSRM (HTTP)

TARGET = BelleMaps
TEMPLATE = app
QT += declarative network

SOURCES += main.cpp gunluk.cpp
HEADERS += arac.h gunluk.h
RESOURCES += resources.qrc
OTHER_FILES += qml/*.qml

win32: CONFIG += console

symbian {
    TARGET.UID3 = 0xE39CF23D
    VERSION = 1.3.2
    TARGET.CAPABILITY += NetworkServices
    TARGET.EPOCHEAPSIZE = 0x40000 0x3000000
    TARGET.EPOCSTACKSIZE = 0x14000
    LIBS += -lhal

    ICON = BelleMaps.svg
    DEPLOYMENT.display_name = Belle Maps
    vendorinfo = "%{\"Belle Maps\"}" ":\"Belle Maps\""
    my_deployment.pkg_prerules += vendorinfo
    DEPLOYMENT += my_deployment
}

# Ortak harita kutuphanesi: Harita.qml, karo onbellegi, GPS (Location yetkisi)
include($$PWD/../kutuphane/harita/harita.pri)
# Ayar aynasi (E:/BelleYedek/Uygulamalar/BelleMaps)
include($$PWD/../kutuphane/ayna/ayna.pri)

# Dil destegi (Turkce / English): kutuphane/dil
include($$PWD/../kutuphane/dil/dil.pri)

# Ortak sunucu adresi + HTTPS kok sertifikalari
include(../kutuphane/sunucu/sunucu.pri)
