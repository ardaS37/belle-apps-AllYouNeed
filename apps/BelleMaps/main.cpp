#include "belleadres.h"
#include <QtGui/QApplication>
#include "dil.h"
#include <QtDeclarative/QDeclarativeView>
#include <QtDeclarative/QDeclarativeEngine>
#include <QtDeclarative/QDeclarativeContext>
#include <QtCore/QUrl>

#include "ayna.h"
#include "arac.h"
#include "haritaag.h"
#include "gpskonum.h"
#include "cevrimdisi.h"
#include <QtCore/QFile>
#include <QtCore/QDir>
#include <QtCore/QDateTime>
#include <cstdio>

#include "gunluk.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    belleKokSertifikalariYukle();   // HTTPS (e6.msahincelen.xyz): guncel kok sertifikalar, dogrulama acik
    Dil *dil = Dil::kur(&app);   // Turkce / English (QML'den once)
#if defined(Q_OS_SYMBIAN)
    const QString veri = QDir("E:/").exists() ? QString("E:/BelleHarita") : QString("C:/Data/BelleHarita");
#else
    const QString veri = QDir::homePath() + "/BelleHarita";
#endif
    QDir().mkpath(veri);
    Gunluk::kur(veri);                      // gunluk: sinirsiz, devreden, cokmede kaybolmaz
    qDebug("Belle Maps 1.3.1 basladi");
    // Ayarlar (kayitli yerler dahil) hafiza kartina aynalanir
    Ayna::baslat("BelleHarita", QStringList());
    app.setApplicationName("BelleHarita");
    app.setApplicationVersion("1.3.1");
    Gunluk gunluk(veri, "1.3.1");          // cokme algilama + sunucuya rapor
    QObject::connect(&app, SIGNAL(aboutToQuit()), &gunluk, SLOT(temizCikis()));

    Arac arac;
    GpsKonum gps;
    Cevrimdisi cevrimdisi;      // secili alani karta indirme

    QDeclarativeView view;
    HaritaAg::kur(view.engine());           // karolar karta onbelleklenir
    view.setResizeMode(QDeclarativeView::SizeRootObjectToView);
    view.setAttribute(Qt::WA_OpaquePaintEvent);
    view.setAttribute(Qt::WA_NoSystemBackground);
    view.viewport()->setAttribute(Qt::WA_OpaquePaintEvent);
    view.viewport()->setAttribute(Qt::WA_NoSystemBackground);
    view.rootContext()->setContextProperty("arac", &arac);
    view.rootContext()->setContextProperty("gps", &gps);
    view.rootContext()->setContextProperty("cevrimdisi", &cevrimdisi);
    view.rootContext()->setContextProperty("gunluk", &gunluk);
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
