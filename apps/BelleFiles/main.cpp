#include "belleadres.h"
#include <QtGui/QApplication>
#include "dil.h"
#include <QtDeclarative/QDeclarativeView>
#include <QtDeclarative/QDeclarativeEngine>
#include <QtDeclarative/QDeclarativeContext>
#include <QtCore/QUrl>
#include <QtCore/QTextCodec>
#include <QtCore/QFile>
#include <QtCore/QDir>
#include <QtCore/QDateTime>

#include "metin.h"
#include "drive.h"
#include "isci.h"
#include "yedek.h"
#include "ayna.h"

// QML uyarilari (hata ayiklama): C:/Data/BelleFiles/qml_uyari.txt (en cok 150 satir / acilis)
static void qmlUyari(QtMsgType tur, const char *m)
{
    static int adet = 0;
    if (tur == QtDebugMsg || ++adet > 150) return;
#if defined(Q_OS_SYMBIAN)
    QFile g(QString::fromLatin1("C:/Data/BelleFiles/qml_uyari.txt"));
#else
    QFile g(QString::fromLatin1("qml_uyari.txt"));
#endif
    if (adet == 1 && g.size() > 32 * 1024) g.remove();
    if (g.open(QIODevice::Append))
        g.write((QDateTime::currentDateTime().toString(QString::fromLatin1("dd.MM hh:mm:ss ")) + QString::fromUtf8(m) + QString::fromLatin1("\n")).toUtf8());
}

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    belleKokSertifikalariYukle();   // HTTPS (e6.msahincelen.xyz): guncel kok sertifikalar, dogrulama acik
    QDir().mkpath(QString::fromLatin1("C:/Data/BelleFiles"));
    qInstallMsgHandler(qmlUyari);
    Dil *dil = Dil::kur(&app);   // Turkce / English (QML'den once)
    app.setApplicationName("BelleFiles");
    QTextCodec::setCodecForCStrings(QTextCodec::codecForName("UTF-8"));
    Ayna::baslat("BelleFiles", QStringList() << "C:/Data/BelleFiles");   // ayarlar karta aynalanir

    Metin fs;
    Drive drive;
    Isci isci;
    Yedek yedek;
    KeyedNamFactory namFactory;            // gorunumden uzun yasamali

    QDeclarativeView view;
    view.setResizeMode(QDeclarativeView::SizeRootObjectToView);
    view.setAttribute(Qt::WA_OpaquePaintEvent);
    view.setAttribute(Qt::WA_NoSystemBackground);
    view.viewport()->setAttribute(Qt::WA_OpaquePaintEvent);
    view.viewport()->setAttribute(Qt::WA_NoSystemBackground);
    view.engine()->setNetworkAccessManagerFactory(&namFactory);
    view.rootContext()->setContextProperty("fs", &fs);
    view.rootContext()->setContextProperty("drive", &drive);
    view.rootContext()->setContextProperty("isci", &isci);
    view.rootContext()->setContextProperty("yedek", &yedek);
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
