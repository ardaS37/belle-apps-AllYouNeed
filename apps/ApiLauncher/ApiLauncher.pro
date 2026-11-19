# ApiLauncher (eski ApiLauncher) - GPT, Claude, Gemini ve Grok icin sohbet uygulamasi (Nokia E6, Qt 4.7.4)
# Foto gonderme (dort servis), resim olusturma (GPT, Gemini, Grok), sorun bildirme (/api/report).
# TARGET ve UID ayni kaldi: eski ApiLauncher'nin uzerine kurulur, sohbetler ve ayarlar korunur.

TARGET = ApiLauncher
TEMPLATE = app
QT += declarative network

SOURCES += main.cpp yardim.cpp
HEADERS += yardim.h
RESOURCES += resources.qrc

OTHER_FILES += qml/*.qml qml/*.js

symbian {
    TARGET.UID3 = 0xE39CF228
    VERSION = 1.3.4
    TARGET.CAPABILITY += NetworkServices
    TARGET.EPOCHEAPSIZE = 0x40000 0x4000000
    TARGET.EPOCSTACKSIZE = 0x14000

    ICON = ApiLauncher.svg
    DEPLOYMENT.display_name = ApiLauncher

    vendorinfo = "%{\"ApiLauncher\"}" ":\"ApiLauncher\""
    my_deployment.pkg_prerules += vendorinfo
    DEPLOYMENT += my_deployment
}

# Ayar aynasi (E:/BelleYedek/Uygulamalar/ApiLauncher)
include($$PWD/../kutuphane/ayna/ayna.pri)

# Dil destegi (Turkce / English): kutuphane/dil
include($$PWD/../kutuphane/dil/dil.pri)
include($$PWD/../kutuphane/depo/depo.pri)   # depolama yeri (kurulum surucusu / kart / E / C)

# Ortak sunucu adresi + HTTPS kok sertifikalari
include(../kutuphane/sunucu/sunucu.pri)

# Ortak pano yardimcisi (Ctrl+V: QML paste() E6da calismiyor)
include($$PWD/../kutuphane/pano/pano.pri)
