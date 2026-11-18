#include "belleadres.h"
#include "pano.h"
#include <QtGui/QApplication>
#include "dil.h"
#include "ayna.h"
#include <QtDeclarative/QDeclarativeView>
#include <QtDeclarative/QDeclarativeEngine>
#include <QtDeclarative/QDeclarativeContext>
#include <QtDeclarative/qdeclarative.h>
#include <QtCore/QUrl>

#include "tube.h"
#include "nativevideo.h"
#include "volumekeys.h"
#include "sysstate.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    belleKokSertifikalariYukle();   // HTTPS (e6.msahincelen.xyz): guncel kok sertifikalar, dogrulama acik
    Dil *dil = Dil::kur(&app);   // Turkce / English (QML'den once)
    // Ayarlar hafiza kartina aynalanir; telefon sifirlaninca / ROM sonrasi otomatik geri gelir (kutuphane/ayna)
    Ayna::baslat("E6Tube", QStringList());
    app.setApplicationName("E6Tube");

    qmlRegisterType<NativeVideo>("BelleTube", 1, 0, "NativeVideo");

    Tube tube;
    VolumeKeys volumeKeys;
    SysState sys;

    QDeclarativeView view;
    NativeVideo::setHost(&view);
    view.setResizeMode(QDeclarativeView::SizeRootObjectToView);
    view.setAttribute(Qt::WA_OpaquePaintEvent);
    view.setAttribute(Qt::WA_NoSystemBackground);
    view.viewport()->setAttribute(Qt::WA_OpaquePaintEvent);
    view.viewport()->setAttribute(Qt::WA_NoSystemBackground);
    view.rootContext()->setContextProperty("tube", &tube);
    static Pano belPano; view.rootContext()->setContextProperty("pano", &belPano);   // Ctrl+V (kutuphane/pano)
    view.rootContext()->setContextProperty("volumeKeys", &volumeKeys);
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
