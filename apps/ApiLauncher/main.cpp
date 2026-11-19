#include "belleadres.h"
#include "pano.h"
#include <QtGui/QApplication>
#include "dil.h"
#include "depo.h"
#include "ayna.h"
#include <QtDeclarative/QDeclarativeView>
#include <QtDeclarative/QDeclarativeEngine>
#include <QtCore/QUrl>
#include <QtCore/QFile>
#include <QtNetwork/QSslSocket>
#include <QtNetwork/QSslCertificate>
#include <QtDeclarative/QDeclarativeContext>
#include "yardim.h"

// ApiLauncher (eski ApiLauncher): GPT, Claude, Gemini ve Grok icin sohbet uygulamasi (Nokia E6, Qt 4.7.4)
// Uygulama adi depolama yolu degismesin diye ic olarak "ApiLauncher" kalir (sohbetler ve ayarlar korunur).
int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    belleKokSertifikalariYukle();   // HTTPS (e6.msahincelen.xyz): guncel kok sertifikalar, dogrulama acik
    Dil *dil = Dil::kur(&app);   // Turkce / English (QML'den once)
    Depo *depo = Depo::kur(QString::fromLatin1("ApiLauncher"));   // onbellek/indirme surucusu (kutuphane/depo)
    // Ayarlar hafiza kartina aynalanir; telefon sifirlaninca / ROM sonrasi otomatik geri gelir (kutuphane/ayna)
    Ayna::baslat("ApiLauncher", QStringList() << "C:/Data/ApiLauncher");
    app.setApplicationName("E6AI");

    // Telefonun kok sertifika deposu eski; saglayicilarin guncel kok sertifikalarini ekle
    // (dogrulama kapatilmaz, yalnizca guvenilen kokler genisletilir)
    QFile pem(":/certs/roots.pem");
    if (pem.open(QIODevice::ReadOnly)) {
        const QList<QSslCertificate> roots = QSslCertificate::fromData(pem.readAll(), QSsl::Pem);
        if (!roots.isEmpty()) QSslSocket::addDefaultCaCertificates(roots);
    }

    Yardim yardim;   // view'den once: kapanista QML hala erisebilir
    yardim.tlsTestDosyasi();
    QDeclarativeView view;
    view.setResizeMode(QDeclarativeView::SizeRootObjectToView);
    view.setAttribute(Qt::WA_OpaquePaintEvent);
    view.setAttribute(Qt::WA_NoSystemBackground);
    view.viewport()->setAttribute(Qt::WA_OpaquePaintEvent);
    view.viewport()->setAttribute(Qt::WA_NoSystemBackground);
    view.rootContext()->setContextProperty("yardim", &yardim);
    static Pano belPano; view.rootContext()->setContextProperty("pano", &belPano);   // Ctrl+V (kutuphane/pano)
    view.rootContext()->setContextProperty("depo", depo);
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