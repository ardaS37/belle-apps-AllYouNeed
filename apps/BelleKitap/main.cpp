// BelleKitap: EPUB ve TXT e-kitap okuyucu — Nokia E6 (Symbian Belle)
#include <QtGui/QApplication>
#include <QtDeclarative/QDeclarativeView>
#include <QtDeclarative/QDeclarativeEngine>
#include <QtDeclarative/QDeclarativeContext>
#include <QtCore/QUrl>
#include <QtNetwork/QSslSocket>
#include <QtNetwork/QSslCertificate>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QDateTime>
#include <QtCore/QTextCodec>
#include "dil.h"
#include "kitap.h"

static QString sUyari;
static void qmlUyari(QtMsgType tur, const char *m)
{
    static int adet = 0;
    if (tur == QtDebugMsg || ++adet > 150) return;
    QFile g(sUyari);
    if (adet == 1 && g.size() > 32 * 1024) g.remove();
    if (g.open(QIODevice::Append))
        g.write((QDateTime::currentDateTime().toString(QString::fromLatin1("dd.MM hh:mm:ss ")) + QString::fromUtf8(m) + QString::fromLatin1("\n")).toUtf8());
}

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    app.setApplicationName(QString::fromLatin1("BelleKitap"));
    QTextCodec::setCodecForCStrings(QTextCodec::codecForName("UTF-8"));
    Dil *dil = Dil::kur(&app);
#if defined(Q_OS_SYMBIAN)
    const QString veri = QString::fromLatin1("C:/Data/BelleKitap");
#else
    const QString veri = QDir::homePath() + QString::fromLatin1("/BelleKitap");
#endif
    QDir().mkpath(veri);
    sUyari = veri + QString::fromLatin1("/qml_uyari.txt");
    qInstallMsgHandler(qmlUyari);

    // guncel kok sertifikalar (Gutenberg, Vikikaynak HTTPS)
    QFile pem(QString::fromLatin1(":/certs/roots.pem"));
    if (pem.open(QIODevice::ReadOnly)) { const QList<QSslCertificate> k = QSslCertificate::fromData(pem.readAll(), QSsl::Pem); if (!k.isEmpty()) QSslSocket::addDefaultCaCertificates(k); }

    Kitap kt(veri);
    kt.kayit(QString::fromLatin1("acildi v0.2"));

    QDeclarativeView view;
    view.setResizeMode(QDeclarativeView::SizeRootObjectToView);
    view.setAttribute(Qt::WA_OpaquePaintEvent);
    view.setAttribute(Qt::WA_NoSystemBackground);
    view.viewport()->setAttribute(Qt::WA_OpaquePaintEvent);
    view.viewport()->setAttribute(Qt::WA_NoSystemBackground);
    view.rootContext()->setContextProperty(QString::fromLatin1("kt"), &kt);
    view.rootContext()->setContextProperty(QString::fromLatin1("dil"), dil);
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
