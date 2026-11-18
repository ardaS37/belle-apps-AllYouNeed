# BelleWidgets (eski BelleWidgets; TARGET/UID ayni, ustune kurulur) - pil, hava, RAM/CPU ana ekran widget'lari (Nokia E6, Symbian Belle, Qt 4.7.4)
# Arka planda hafif: zamanlayici yok, yalnizca sistemin pil bildirimleriyle calisir; arayuz yalnizca acikken bellekte.
# Widget: Nokia'nin hazir derlenmis HSWidgetPlugin.dll'i (Wunderland'in widget'i ayni yontemi kullaniyor),
# github.com/djbozkosz/Symbian-HomeScreen-Widget-QML sarmalayicisiyla. Sunucu kullanmaz.

TARGET = BelleWidgets
TEMPLATE = app
QT += declarative network

SOURCES += main.cpp pil.cpp
HEADERS += pil.h homescreenwidget.h
RESOURCES += resources.qrc
OTHER_FILES += qml/*.qml

TARGETNAME = BelleWidgets
TARGETUID3 = 0xE39CF235
HSWIDGETLIB = HSWidgetPlugin.dll
symbian {
    DEFINES += TARGETUID3=\"$${TARGETUID3}\"
    DEFINES += HSWIDGETLIB=\"$${TARGETNAME}$${HSWIDGETLIB}\"
} else {
    DEFINES += TARGETUID3=\\\"$${TARGETUID3}\\\"
    DEFINES += HSWIDGETLIB=\\\"$${TARGETNAME}$${HSWIDGETLIB}\\\"
}

# VM'de masaustu Qt ile arayuz testi (pil degerleri taklit edilir)
win32: CONFIG += console

# Qt Simulator (E6 cihaz gorunumu): QtMobility pil bilgisi simulatorun pil ayarindan gelir
# (qmake'e "CONFIG+=e6sim" verilir: bellewidgets_sim.bat)
e6sim|simulator {
    CONFIG += mobility
    MOBILITY += systeminfo
}

symbian {
    CONFIG += mobility
    MOBILITY += systeminfo

    TARGET.UID3 = $${TARGETUID3}
    VERSION = 1.6.1
    # HSWidgetPlugin.dll'in yetkisiyle BIREBIR ayni olmali (yoksa DLL yuklenmez / widget calismaz)
    TARGET.CAPABILITY = NetworkServices
    INCLUDEPATH += /epoc32/include/platform/mw /epoc32/include/platform /epoc32/include/mw
    LIBS += -lapgrfx -lcone -lws32 -lbitgdi -lfbscli -laknskins -laknskinsrv -leikcore -lavkon
    LIBS += -lhwrmvibraclient -lhal -leuser
    TARGET.EPOCHEAPSIZE = 0x20000 0x1000000

    # Widget DLL'i uygulamaya ozel adla kurulur: BelleWidgetsHSWidgetPlugin.dll
    hsdll.pkg_postrules += "\"$$PWD/bin/$${HSWIDGETLIB}\" - \"!:/sys/bin/$${TARGETNAME}$${HSWIDGETLIB}\""
    DEPLOYMENT += hsdll

    # Acilista baslatma (Startup List Management)
    MMP_RULES += "SOURCEPATH ." "START RESOURCE E39CF235.rss" "TARGETPATH /private/101f875a/import" "END"
    startup.pkg_postrules = "\"C:/QtSDK/Symbian/SDKs/Symbian3Qt474/epoc32/data/z/private/101f875a/import/E39CF235.rsc\" - \"c:/private/101f875a/import/[E39CF235].rsc\""
    DEPLOYMENT += startup

    ICON = BelleWidgets.svg
    DEPLOYMENT.display_name = BelleWidgets
    vendorinfo = "%{\"BelleWidgets\"}" ":\"BelleWidgets\""
    my_deployment.pkg_prerules += vendorinfo
    DEPLOYMENT += my_deployment
}

# Ayar aynasi (E:/BelleYedek/Uygulamalar/BelleWidgets)
include($$PWD/../kutuphane/ayna/ayna.pri)

# Dil destegi (Turkce / English): kutuphane/dil
include($$PWD/../kutuphane/dil/dil.pri)

# Ortak pano yardimcisi (Ctrl+V: QML paste() E6da calismiyor)
include($$PWD/../kutuphane/pano/pano.pri)
