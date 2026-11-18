// BelleMail: Nokia E6 (Qt 4.7.4) e-posta istemcisi. SUNUCUSUZ: telefon posta kutusuna dogrudan
// IMAP (TLS 993) ile baglanir, SMTP (465/587) ile gonderir (posta/). Hesap uygulama icinden girilir.
// Arka planda acik kalirsa yeni postalari belirli araliklarla denetler ve bildirir (Pigler + kose kutusu).

#include "belleadres.h"
#include "pano.h"
#include <QtGui/QApplication>
#include <QtGui/QDesktopServices>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QDateTime>
#include <QtCore/QUrl>
#include <QtDeclarative/QDeclarativeView>
#include <QtDeclarative/QDeclarativeEngine>
#include <QtDeclarative/QDeclarativeContext>
#include "dil.h"
#include "ayna.h"
#include "posta.h"
#include "bildirim.h"

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
    belleKokSertifikalariYukle();   // TLS: guncel kok sertifikalar (Gmail GTS, DigiCert, GlobalSign...), dogrulama acik
    Dil *dil = Dil::kur(&app);
    // Ayarlar hafiza kartina aynalanir (hesap parolasi DEGIL: o ozel klasorde)
    Ayna::baslat("Mail", QStringList() << "C:/Data/Mail");
    app.setApplicationName("Mail");

#if defined(Q_OS_SYMBIAN)
    const QString acik = QString::fromLatin1("C:/Data/BelleMail");             // gunluk (CODA ile okunabilir)
    const QString ozel = QCoreApplication::applicationDirPath();               // C:/private/E39CF229: hesap
#else
    const QString acik = QDir::currentPath();
    const QString ozel = QDesktopServices::storageLocation(QDesktopServices::DataLocation);
#endif
    QDir().mkpath(acik);
    QDir().mkpath(ozel);
    sUyariDosyasi = acik + QString::fromLatin1("/qml_uyari.txt");
    qInstallMsgHandler(qmlUyari);

    Posta posta(ozel, acik + QString::fromLatin1("/gunluk.txt"));
    Bildirim bildirim(ozel, acik + QString::fromLatin1("/gunluk.txt"));

    QDeclarativeView view;
    view.rootContext()->setContextProperty("mail", &posta);
    static Pano belPano; view.rootContext()->setContextProperty("pano", &belPano);   // Ctrl+V (kutuphane/pano)
    view.rootContext()->setContextProperty("bildirim", &bildirim);
    view.rootContext()->setContextProperty("dil", dil);
    view.setResizeMode(QDeclarativeView::SizeRootObjectToView);
    view.setAttribute(Qt::WA_OpaquePaintEvent);
    view.setAttribute(Qt::WA_NoSystemBackground);
    view.viewport()->setAttribute(Qt::WA_OpaquePaintEvent);
    view.viewport()->setAttribute(Qt::WA_NoSystemBackground);
    QObject::connect(view.engine(), SIGNAL(quit()), &app, SLOT(quit()));
    view.setSource(QUrl("qrc:/qml/main.qml"));

#if defined(Q_OS_SYMBIAN)
    view.showFullScreen();
#else
    view.resize(640, 480);
    view.show();
#endif
    return app.exec();
}
