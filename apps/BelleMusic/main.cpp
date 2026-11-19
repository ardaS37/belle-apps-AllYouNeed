#include <QtGui/QApplication>
#include "pano.h"
#include "dil.h"
#include "depo.h"
#include "ayna.h"
#include <QtDeclarative/QDeclarativeView>
#include <QtDeclarative/QDeclarativeEngine>
#include <QtDeclarative/QDeclarativeContext>
#include <QtCore/QUrl>
#include <QtCore/QFile>
#include <QtNetwork/QSslSocket>
#include <QtNetwork/QSslCertificate>

#include "music.h"
#include "mediakeys.h"

// BelleMusic: Belle sunucusu + s60tube muzik servisi icin yerel istemci (Nokia E6, Qt 4.7.4)
int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    Dil *dil = Dil::kur(&app);   // Turkce / English (QML'den once)
    Depo *depo = Depo::kur(QString::fromLatin1("BelleMusic"));   // onbellek/indirme surucusu (kutuphane/depo)
    // Ayarlar hafiza kartina aynalanir; telefon sifirlaninca / ROM sonrasi otomatik geri gelir (kutuphane/ayna)
    Ayna::baslat("E6Muzik2", QStringList() << "C:/Data/E6Muzik");
    app.setApplicationName("E6Muzik");

    // Kapak resimleri HTTPS'ten gelir; telefonun kok deposu eski, guncel kokleri ekle
    QFile pem(":/certs/roots.pem");
    if (pem.open(QIODevice::ReadOnly)) {
        const QList<QSslCertificate> roots = QSslCertificate::fromData(pem.readAll(), QSsl::Pem);
        if (!roots.isEmpty()) QSslSocket::addDefaultCaCertificates(roots);
    }

    Music music;
    MediaKeys keys;

    QDeclarativeView view;
    view.setResizeMode(QDeclarativeView::SizeRootObjectToView);
    view.setAttribute(Qt::WA_OpaquePaintEvent);
    view.setAttribute(Qt::WA_NoSystemBackground);
    view.viewport()->setAttribute(Qt::WA_OpaquePaintEvent);
    view.viewport()->setAttribute(Qt::WA_NoSystemBackground);
    view.rootContext()->setContextProperty("music", &music);
    static Pano belPano; view.rootContext()->setContextProperty("pano", &belPano);   // Ctrl+V (kutuphane/pano)
    view.rootContext()->setContextProperty("depo", depo);
    view.rootContext()->setContextProperty("keys", &keys);
    QObject::connect(view.engine(), SIGNAL(quit()), &app, SLOT(quit()));

    view.rootContext()->setContextProperty("dil", dil);
#ifdef BM_KISISEL
    view.rootContext()->setContextProperty("kisisel", QVariant(true));    // kisisel derleme: yalnizca kendi Belle sunucumuz
#else
    view.rootContext()->setContextProperty("kisisel", QVariant(false));   // yayin: s60tube (E6Muzik ile ayni)
#endif
    view.setSource(QUrl("qrc:/qml/main.qml"));

#if defined(Q_OS_SYMBIAN)
    view.showFullScreen();
#else
    view.resize(640, 480);
    view.show();
#endif
    return app.exec();
}
