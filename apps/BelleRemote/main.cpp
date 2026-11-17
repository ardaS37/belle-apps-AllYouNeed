#include "belleadres.h"
#include <QtGui/QApplication>
#include "dil.h"
#include "ayna.h"
#include <QtDeclarative/QDeclarativeView>
#include <QtDeclarative/QDeclarativeEngine>
#include <QtDeclarative/QDeclarativeContext>
#include <QtCore/QUrl>
#include <QtCore/QTimer>
#include <QtCore/QFile>

#include "uzak.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    belleKokSertifikalariYukle();   // HTTPS (e6.msahincelen.xyz): guncel kok sertifikalar, dogrulama acik
    Dil *dil = Dil::kur(&app);   // Turkce / English (QML'den once)
    // Ayarlar hafiza kartina aynalanir; telefon sifirlaninca / ROM sonrasi otomatik geri gelir (kutuphane/ayna)
    Ayna::baslat("BelleRemote", QStringList() << "C:/Data/BelleRemote");
    app.setApplicationName("BelleRemote");

    Uzak uzak;
    app.installEventFilter(&uzak);

    QDeclarativeView view;
    view.setResizeMode(QDeclarativeView::SizeRootObjectToView);
    view.setAttribute(Qt::WA_OpaquePaintEvent);
    view.setAttribute(Qt::WA_NoSystemBackground);
    view.viewport()->setAttribute(Qt::WA_OpaquePaintEvent);
    view.viewport()->setAttribute(Qt::WA_NoSystemBackground);
    view.engine()->addImageProvider("ekran", new EkranSaglayici(&uzak));
    view.rootContext()->setContextProperty("uzak", &uzak);
    QObject::connect(view.engine(), SIGNAL(quit()), &app, SLOT(quit()));
    view.rootContext()->setContextProperty("dil", dil);
    view.setSource(QUrl("qrc:/qml/main.qml"));
#if defined(Q_OS_SYMBIAN)
    view.showFullScreen();
#else
    view.resize(640, 480);
    view.show();
    // Yalnızca masaüstü/simülatör testi: Z:/e6uzak_test.txt (1. satır IP:port, 2. satır parola) okunur ve silinir.
    {
        QFile f("Z:/e6uzak_test.txt");
        if (f.open(QIODevice::ReadOnly)) {
            const QList<QByteArray> l = f.readAll().split('\n');
            f.close(); f.remove();
            if (l.size() >= 2 && !l.at(1).trimmed().isEmpty()) uzak.setAnahtar(QString::fromUtf8(l.at(1)).trimmed());
            if (!l.isEmpty()) uzak.baglanLan(QString::fromUtf8(l.at(0)).trimmed());
        }
    }
#endif
    return app.exec();
}