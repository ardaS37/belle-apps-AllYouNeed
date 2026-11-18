// BelleGram: Nokia E6 (Symbian Belle) icin dogrudan Telegram istemcisi. Sunucu yok: MTProto 2.0 (tg/).
#include <QtGui/QApplication>
#include "pano.h"
#include <QtGui/QDesktopServices>
#include <QtDeclarative/QDeclarativeView>
#include <QtDeclarative/QDeclarativeEngine>
#include <QtDeclarative/QDeclarativeContext>
#include <QtCore/QUrl>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QDateTime>
#include "dil.h"
#include "telegram.h"
#include "cihaz.h"
#include "bildirim.h"
#include "haritaag.h"
#include "gpskonum.h"

// QML uyarilari (hata ayiklama icin): C:/Data/BelleGram/qml_uyari.txt (masaustunde calisma klasoru)
static QString sUyariDosyasi;
static void qmlUyari(QtMsgType tur, const char *m)
{
    static int adet = 0;
    if (tur == QtDebugMsg || ++adet > 150) return;
    QFile g(sUyariDosyasi);
    if (adet == 1 && g.size() > 32 * 1024) g.remove();
    if (g.open(QIODevice::Append))
        g.write((QDateTime::currentDateTime().toString(QString::fromLatin1("dd.MM hh:mm:ss ")) + QString::fromUtf8(m) + QString::fromLatin1("\n")).toUtf8());
}

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    app.setApplicationName(QString::fromLatin1("BelleGram"));
    Dil *dil = Dil::kur(&app);

#if defined(Q_OS_SYMBIAN)
    const QString acik = QString::fromLatin1("C:/Data/BelleGram");             // gunluk (CODA ile okunabilir)
    const QString ozel = QCoreApplication::applicationDirPath();               // C:/private/E39CF23F: oturum anahtari
#else
    const QString acik = QDir::currentPath();
    const QString ozel = QDesktopServices::storageLocation(QDesktopServices::DataLocation);
#endif
    QDir().mkpath(acik);
    QDir().mkpath(ozel);
    sUyariDosyasi = acik + QString::fromLatin1("/qml_uyari.txt");
    qInstallMsgHandler(qmlUyari);

    Telegram tg(ozel, acik + QString::fromLatin1("/gunluk.txt"));
    Cihaz cihaz(ozel + QString::fromLatin1("/kayit"));
    GpsKonum gps;       // yalnizca konum ekraninda "Anlik konumum"a basilinca acilir
    Bildirim bildirim(ozel, acik + QString::fromLatin1("/gunluk.txt"));

    QDeclarativeView view;
    HaritaAg::kur(view.engine());   // harita karolari onbelleklenir
    view.setResizeMode(QDeclarativeView::SizeRootObjectToView);
    view.setAttribute(Qt::WA_OpaquePaintEvent);
    view.setAttribute(Qt::WA_NoSystemBackground);
    view.viewport()->setAttribute(Qt::WA_OpaquePaintEvent);
    view.viewport()->setAttribute(Qt::WA_NoSystemBackground);
    view.rootContext()->setContextProperty(QString::fromLatin1("tg"), &tg);
    static Pano belPano; view.rootContext()->setContextProperty("pano", &belPano);   // Ctrl+V (kutuphane/pano)
    view.rootContext()->setContextProperty(QString::fromLatin1("dil"), dil);
    view.rootContext()->setContextProperty(QString::fromLatin1("cihaz"), &cihaz);
    view.rootContext()->setContextProperty(QString::fromLatin1("gps"), &gps);
    view.rootContext()->setContextProperty(QString::fromLatin1("bildirim"), &bildirim);
    QObject::connect(view.engine(), SIGNAL(quit()), &app, SLOT(quit()));
    view.setSource(QUrl(QString::fromLatin1("qrc:/qml/main.qml")));

#if defined(Q_OS_SYMBIAN)
    view.showFullScreen();
#else
    view.resize(640, 480);
    view.show();
#endif
    return app.exec();
}
