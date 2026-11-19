# Ayar aynasi (bkz. ayna.h). Kullanim: include($$PWD/../kutuphane/ayna/ayna.pri)
INCLUDEPATH += $$PWD
HEADERS += $$PWD/ayna.h
SOURCES += $$PWD/ayna.cpp
symbian: LIBS += -leuser
include($$PWD/../depo/depo.pri)   # yedek koku: saglam surucu (kart -> E -> C)
