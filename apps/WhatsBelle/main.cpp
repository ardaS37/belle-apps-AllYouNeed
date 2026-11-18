#include "belleadres.h"
#include "pano.h"
#include <QtGui/QApplication>
#include "dil.h"
#include "ayna.h"
#include <QtDeclarative/QDeclarativeView>
#include <QtDeclarative/QDeclarativeEngine>
#include <QtDeclarative/QDeclarativeContext>
#include <QtCore/QUrl>

#include "device.h"
#include "notify.h"
#include "mediakeys.h"
#include "haritaag.h"
#include "gpskonum.h"
#include <QtCore/QTimer>
#include <QtCore/QFile>
#include <QtCore/QDir>
#include <QtCore/QDateTime>

// QML uyarilari (hata ayiklama icin) C:/Data/WhatsBelle/qml_uyari.txt
static void qmlUyari(QtMsgType tur, const char *m)
{
    static int adet = 0;
    if (tur == QtDebugMsg || ++adet > 120) return;
    QFile g("C:/Data/WhatsE6/qml_uyari.txt");
    if (adet == 1 && g.size() > 32 * 1024) g.remove();
    if (g.open(QIODevice::Append)) g.write((QDateTime::currentDateTime().toString("dd.MM hh:mm:ss ") + QString::fromUtf8(m) + "\n").toUtf8());
}

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    belleKokSertifikalariYukle();   // HTTPS (e6.msahincelen.xyz): guncel kok sertifikalar, dogrulama acik
    Dil *dil = Dil::kur(&app);   // Turkce / English (QML'den once)
#if defined(Q_OS_SYMBIAN)
    QDir().mkpath("C:/Data/WhatsE6");
    qInstallMsgHandler(qmlUyari);
#endif
    // Ayarlar hafiza kartina aynalanir; telefon sifirlaninca / ROM sonrasi otomatik geri gelir (kutuphane/ayna)
    Ayna::baslat("WhatsBelle", QStringList() << "C:/Data/WhatsE6");
    app.setApplicationName("WhatsE6");

    // Acilis listesinden baslatildiysa ve kullanici bunu kapattiysa hemen cik
    const bool atBoot = Notify::startedAtBoot();
    if (atBoot && !Notify::autostartAllowed()) return 0;
    Notify notify;

    Device device;
    MediaKeys keys;
    GpsKonum gps;       // yalnizca "Anlik konumum"a basilinca acilir

    QDeclarativeView view;
    HaritaAg::kur(view.engine());   // konum ekranindaki harita karolari karta onbelleklenir
    view.setResizeMode(QDeclarativeView::SizeRootObjectToView);
    view.setAttribute(Qt::WA_OpaquePaintEvent);
    view.setAttribute(Qt::WA_NoSystemBackground);
    view.viewport()->setAttribute(Qt::WA_OpaquePaintEvent);
    view.viewport()->setAttribute(Qt::WA_NoSystemBackground);
    view.rootContext()->setContextProperty("device", &device);
    static Pano belPano; view.rootContext()->setContextProperty("pano", &belPano);   // Ctrl+V (kutuphane/pano)
    view.rootContext()->setContextProperty("notify", &notify);
    view.rootContext()->setContextProperty("keys", &keys);
    view.rootContext()->setContextProperty("gps", &gps);
    view.rootContext()->setContextProperty("startedAtBoot", atBoot);
    QObject::connect(view.engine(), SIGNAL(quit()), &app, SLOT(quit()));

    view.rootContext()->setContextProperty("dil", dil);
    view.setSource(QUrl("qrc:/qml/main.qml"));

#if defined(Q_OS_SYMBIAN)
    view.showFullScreen();
    // Telefon acilisinda arka planda baslasin (bildirimler icin)
    if (atBoot) QTimer::singleShot(500, &notify, SLOT(sendToBackground()));
#else
    view.resize(640, 480);
    view.show();
#endif
    return app.exec();
}
