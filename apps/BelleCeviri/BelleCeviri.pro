# BelleCeviri - Nokia E6 (Symbian Belle, Qt 4.7.4 / QML 1.1): ceviri + sozluk
# Servisler (hangisi acilirsa o calisir): Google Ceviri (resmi olmayan yol), MyMemory, DeepL Free,
# Gemini, Groq, Mistral, OpenAI, Claude; sozluk: TDK, Wiktionary. Anahtarlar koda gomulmez.

TARGET = BelleCeviri
TEMPLATE = app
QT += declarative network

SOURCES += main.cpp ceviri.cpp
HEADERS += ceviri.h
RESOURCES += resources.qrc
OTHER_FILES += qml/*.qml qml/*.js

symbian {
    TARGET.UID3 = 0xE39CF241
    TARGET.CAPABILITY += NetworkServices
    TARGET.EPOCHEAPSIZE = 0x40000 0x4000000
    TARGET.EPOCSTACKSIZE = 0x14000
    VERSION = 0.2.0
    ICON = BelleCeviri.svg
    DEPLOYMENT.display_name = BelleCeviri
    vendorinfo = "%{\"BelleCeviri\"}" ":\"BelleCeviri\""
    my_deployment.pkg_prerules += vendorinfo
    DEPLOYMENT += my_deployment
}

include($$PWD/../kutuphane/dil/dil.pri)
