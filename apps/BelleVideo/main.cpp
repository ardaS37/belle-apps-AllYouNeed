#include <QtGui/QApplication>
#include "pano.h"
#include "dil.h"
#include "ayna.h"
#include <QtDeclarative/QDeclarativeView>
#include <QtDeclarative/QDeclarativeEngine>
#include <QtDeclarative/QDeclarativeContext>
#include <QtDeclarative/qdeclarative.h>
#include <QtCore/QUrl>

#include "lib.h"
#include "nativevideo.h"
#include "mediakeys.h"
#include "sysstate.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    Dil *dil = Dil::kur(&app);   // Turkce / English (QML'den once)
    // Ayarlar hafiza kartina aynalanir; telefon sifirlaninca / ROM sonrasi otomatik geri gelir (kutuphane/ayna)
    Ayna::baslat("E6Video", QStringList() << "C:/Data/E6Video");
    app.setApplicationName("E6Video");

    qmlRegisterType<NativeVideo>("BelleVideo", 1, 0, "NativeVideo");

    Lib lib;
    MediaKeys keys;
    SysState sys;

    QDeclarativeView view;
    NativeVideo::setHost(&view);
    view.setResizeMode(QDeclarativeView::SizeRootObjectToView);
    view.setAttribute(Qt::WA_OpaquePaintEvent);
    view.setAttribute(Qt::WA_NoSystemBackground);
    view.viewport()->setAttribute(Qt::WA_OpaquePaintEvent);
    view.viewport()->setAttribute(Qt::WA_NoSystemBackground);
    view.rootContext()->setContextProperty("lib", &lib);
    static Pano belPano; view.rootContext()->setContextProperty("pano", &belPano);   // Ctrl+V (kutuphane/pano)
    view.rootContext()->setContextProperty("keys", &keys);
    view.rootContext()->setContextProperty("sys", &sys);
    QObject::connect(view.engine(), SIGNAL(quit()), &app, SLOT(quit()));

    view.rootContext()->setContextProperty("dil", dil);
    view.setSource(QUrl("qrc:/qml/main.qml"));

#if defined(Q_OS_SYMBIAN)
    view.showFullScreen();
#else
    view.resize(640, 480);
    view.show();
#endif
    return app.exec();
}
