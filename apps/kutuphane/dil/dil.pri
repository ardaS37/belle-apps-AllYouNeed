# Dil destegi (Turkce / English). Kullanim: include($$PWD/../kutuphane/dil/dil.pri)
# Uygulama klasorunde dil/dil.qrc ve dil/en.txt bulunmali (araclar/dil_cikar.ps1 uretir).
INCLUDEPATH += $$PWD
HEADERS += $$PWD/dil.h
SOURCES += $$PWD/dil.cpp
RESOURCES += $$_PRO_FILE_PWD_/dil/dil.qrc
