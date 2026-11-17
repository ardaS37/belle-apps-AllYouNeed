# BelleMail - e-posta istemcisi (Nokia E6, Qt 4.7.4). 2.0'dan beri SUNUCUSUZ:
# telefon posta kutusuna dogrudan IMAP (TLS 993) ile baglanir, SMTP (465 / 587 STARTTLS) ile gonderir.
TARGET = BelleMail
TEMPLATE = app
QT += core gui network declarative

INCLUDEPATH += posta
HEADERS += posta/posta.h posta/imap.h posta/smtp.h posta/mime.h bildirim.h
SOURCES += main.cpp posta/posta.cpp posta/imap.cpp posta/smtp.cpp posta/mime.cpp bildirim.cpp
RESOURCES += resources.qrc
OTHER_FILES += qml/*.qml qml/*.js

symbian {
    TARGET.UID3 = 0xE39CF229
    TARGET.CAPABILITY += NetworkServices
    TARGET.EPOCHEAPSIZE = 0x40000 0x4000000
    TARGET.EPOCSTACKSIZE = 0x14000
    VERSION = 2.0.0
    ICON = BelleMail.svg
    DEPLOYMENT.display_name = BelleMail
    vendorinfo = "%{\"BelleMail\"}" ":\"BelleMail\""
    my_deployment.pkg_prerules += vendorinfo
    DEPLOYMENT += my_deployment
    # Bildirimler: ust kose kutusu (avkon), titresim, durum cubugu cekmecesi (Pigler, GPL-3.0)
    INCLUDEPATH += /epoc32/include/mw /epoc32/include/platform/mw /epoc32/include/platform
    LIBS += -lavkon -laknskins -leikcore -lcone -lws32 -lapgrfx -lhwrmvibraclient -leuser -laknnotify
    include($$PWD/../kutuphane/pigler/qt-library/pigler.pri)
    pigler_embed.pkg_postrules = "@\"$$PWD/../kutuphane/pigler/sis_hazir/Pigler.sis\",(0x20292B69)"
    DEPLOYMENT += pigler_embed
}

# Ayar aynasi (E:/BelleYedek/Uygulamalar/Mail)
include($$PWD/../kutuphane/ayna/ayna.pri)

# Dil destegi (Turkce / English): kutuphane/dil
include($$PWD/../kutuphane/dil/dil.pri)

# Kok sertifikalar (TLS dogrulamasi icin; sunucu adresi artik kullanilmiyor)
include(../kutuphane/sunucu/sunucu.pri)
