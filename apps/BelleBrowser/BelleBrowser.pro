# Belle Browser - Nokia E6 (Symbian Belle) icin modern tarayici (Qt 4.7.4 / QML 1.1 / QtWebKit)
# Dokunmatik + orta tus/ok tuslariyla fare imleci, sekmeler, yer imleri, indirme yoneticisi, dahili video,
# istege bagli sunucu katmani (HTTPS/TLS sorunu yok, resimler kucultulur, okuma modu), Belle Remote baglantisi.

TARGET = BelleBrowser
TEMPLATE = app
QT += declarative network webkit
CONFIG += mobility
MOBILITY += multimedia

SOURCES += main.cpp katman.cpp yardimci.cpp indirici.cpp
HEADERS += katman.h yardimci.h indirici.h belleserver.h
RESOURCES += resources.qrc
OTHER_FILES += qml/*.qml qml/*.js

win32: CONFIG += console

symbian {
    TARGET.UID3 = 0xE39CF23B
    VERSION = 1.1.1
    TARGET.CAPABILITY = NetworkServices ReadUserData WriteUserData
    TARGET.EPOCHEAPSIZE = 0x100000 0x6000000
    TARGET.EPOCSTACKSIZE = 0x14000

    ICON = BelleBrowser.svg
    DEPLOYMENT.display_name = Belle Browser

    vendorinfo = "%{\"Belle Browser\"}" ":\"Belle Browser\""
    my_deployment.pkg_prerules += vendorinfo
    DEPLOYMENT += my_deployment
}

# Ayar aynasi (E:/BelleYedek/Uygulamalar/BelleBrowser)
include($$PWD/../kutuphane/ayna/ayna.pri)

# Dil destegi (Turkce / English): kutuphane/dil
include($$PWD/../kutuphane/dil/dil.pri)

# Ortak sunucu adresi + HTTPS kok sertifikalari
include(../kutuphane/sunucu/sunucu.pri)

# Ortak pano yardimcisi (Ctrl+V: QML paste() E6da calismiyor)
include($$PWD/../kutuphane/pano/pano.pri)
