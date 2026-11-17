# Belle Files - Nokia E6 (Belle) icin not defteri + dosya yoneticisi + Google Drive istemcisi (Qt 4.7.4 / QML 1.1)
# E6Metin'in devami: metin duzenleyici (buyuk dosyalar parca parca), dosya yoneticisi (SIS/JAR yukleyiciye,
# video/muzik harici oynaticiya), Drive sekmesi (sunucu uzerinden ya da kendi Google hesabiyla dogrudan),
# notu Drive'a yedekleme ve basili tutulan dosyayi Drive'a yukleme.
# Google modu: OAuth "Masaustu uygulamasi" istemcisi. Client ID / secret uygulama icinden girilir, koda gomulmez.

TARGET = BelleFiles
TEMPLATE = app
QT += declarative network script
# dahili ses calar (Oynatici.qml, QtMultimediaKit) ??? E6Muzik ile ayni Qt Mobility
CONFIG += mobility
MOBILITY += multimedia

SOURCES += main.cpp metin.cpp drive.cpp gdrive.cpp zip.cpp zipsifre.cpp isci.cpp yedek.cpp sms.cpp
HEADERS += metin.h drive.h gdrive.h belleserver.h gizli.h zip.h zipsifre.h isci.h yedek.h sms.h
# Ayar aynasi: kendi ozel klasorunu E:/BelleYedek/Uygulamalar/BelleFiles altina kopyalar (ROM yuklenince geri gelir)
include($$PWD/../kutuphane/ayna/ayna.pri)
RESOURCES += resources.qrc

OTHER_FILES += qml/*.qml qml/*.js

# VM'de masaustu Qt 4.7.4 ile test derlemesi: QML uyarilari konsola duser
win32: CONFIG += console

symbian {
    TARGET.UID3 = 0xE39CF23A
    VERSION = 1.6.0
    # Yedekler: rehber (ReadUserData/WriteUserData + QtMobility contacts/versit), SMS (Symbian mesaj sunucusu)
    TARGET.CAPABILITY = NetworkServices ReadUserData WriteUserData
    MOBILITY += contacts versit
    DEFINES += BELLE_MOBILITY_REHBER
    LIBS += -lmsgs -lsmcm -lgsmu -letext -lefsrv -leuser
    TARGET.EPOCHEAPSIZE = 0x40000 0x4000000
    TARGET.EPOCSTACKSIZE = 0x14000

    ICON = BelleFiles.svg
    DEPLOYMENT.display_name = Belle Files

    vendorinfo = "%{\"Belle Files\"}" ":\"Belle Files\""
    my_deployment.pkg_prerules += vendorinfo
    DEPLOYMENT += my_deployment
}

# Dil destegi (Turkce / English): kutuphane/dil
include($$PWD/../kutuphane/dil/dil.pri)

# Ortak sunucu adresi + HTTPS kok sertifikalari
include(../kutuphane/sunucu/sunucu.pri)
