# Depolama yeri secimi (bkz. depo.h). Kullanim: include($$PWD/../kutuphane/depo/depo.pri)
# ayna.pri de bunu ekler; iki kez eklenirse dosyalar bir kez girer.
!contains(BELLE_DEPO, 1) {
    BELLE_DEPO = 1
    INCLUDEPATH += $$PWD
    HEADERS += $$PWD/depo.h
    SOURCES += $$PWD/depo.cpp
    RESOURCES += $$PWD/depo.qrc
    symbian: LIBS += -leuser -lefsrv
}
