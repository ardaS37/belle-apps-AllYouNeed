# Ortak harita kutuphanesi (Belle Harita, WhatsBelle konum ekrani)
#  - Harita.qml / KonumSecici.qml / HaritaJs.js: uygulamanin qrc:/qml/ klasorune eklenir (ayni adla kullanilir)
#  - HaritaAg: karo disk onbellegi (QML NAM fabrikasi)    - GpsKonum: telefon konum servisi (QtMobility location)
INCLUDEPATH += $$PWD
HEADERS += $$PWD/haritaag.h $$PWD/gpskonum.h $$PWD/cevrimdisi.h $$PWD/rotacizgi.h $$PWD/karoyukleyici.h
SOURCES += $$PWD/haritaag.cpp $$PWD/gpskonum.cpp $$PWD/cevrimdisi.cpp $$PWD/rotacizgi.cpp $$PWD/karoyukleyici.cpp
RESOURCES += $$PWD/harita.qrc
QT += network declarative
CONFIG += mobility
MOBILITY += location
DEFINES += BELLE_GPS
symbian: TARGET.CAPABILITY += Location
