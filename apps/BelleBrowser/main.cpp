// Belle Browser — Nokia E6 (Symbian Belle) icin modern tarayici. Qt 4.7.4 / QML 1.1 / QtWebKit.
#include "belleadres.h"
#include "pano.h"
#include <QtGui/QApplication>
#include "dil.h"
#include "depo.h"
#include "ayna.h"
#include <QtDeclarative/QDeclarativeView>
#include <QtDeclarative/QDeclarativeEngine>
#include <QtDeclarative/QDeclarativeContext>
#include <QtCore/QUrl>
#include <QtCore/QDir>
#include <QtCore/QTextCodec>
#include <QtCore/QFile>
#include <QtCore/QDateTime>
#include <QtDeclarative/QDeclarativeError>
#include <QtWebKit/QWebSettings>
#include <cstdio>

#include "katman.h"
#include "yardimci.h"
#include "indirici.h"

static QString gGunluk;
static void gunluk(const QString &s)
{
    if (gGunluk.isEmpty()) return;
    QFile g(gGunluk);
    if (g.open(QIODevice::Append)) g.write((QDateTime::currentDateTime().toString("dd.MM hh:mm:ss.zzz") + " " + s + "\n").toUtf8());
}

// QML uyarilari ve console.log da gunluge gider (hata raporunda gorunur)
static void mesajYakala(QtMsgType tur, const char *m)
{
    fprintf(stderr, "%s\n", m);
    static int adet = 0;
    if (++adet > 400) return;      // bir oturumda en fazla 400 satir
    gunluk(QString(tur == QtDebugMsg ? "  " : "  UYARI ") + QString::fromUtf8(m));
}

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    belleKokSertifikalariYukle();   // HTTPS (e6.msahincelen.xyz): guncel kok sertifikalar, dogrulama acik
    Dil *dil = Dil::kur(&app);   // Turkce / English (QML'den once)
    Depo *depo = Depo::kur(QString::fromLatin1("BelleBrowser"));   // onbellek/indirme surucusu (kutuphane/depo)
    // Ayarlar hafiza kartina aynalanir; telefon sifirlaninca / ROM sonrasi otomatik geri gelir (kutuphane/ayna)
    Ayna::baslat("BelleBrowser", QStringList() << "C:/Data/BelleBrowser");
    app.setApplicationName("BelleBrowser");
    app.setOrganizationName("BelleBrowser");
    QTextCodec::setCodecForCStrings(QTextCodec::codecForName("UTF-8"));

#if defined(Q_OS_SYMBIAN)
    const QString veri = Depo::yol("BelleBrowser");
#else
    const QString veri = QDir::homePath() + "/BelleBrowser";
#endif
    QDir().mkpath(veri + "/depo");
    gGunluk = veri + "/gunluk.txt";
    gunluk("basladi 1.1");
    qInstallMsgHandler(mesajYakala);
    QWebSettings *w = QWebSettings::globalSettings();
    w->setAttribute(QWebSettings::PluginsEnabled, false);
    w->setAttribute(QWebSettings::JavascriptEnabled, true);
    w->setAttribute(QWebSettings::JavascriptCanOpenWindows, true);
    w->setAttribute(QWebSettings::LocalStorageEnabled, true);
    w->setAttribute(QWebSettings::OfflineStorageDatabaseEnabled, true);
    w->setAttribute(QWebSettings::OfflineWebApplicationCacheEnabled, true);
    w->setAttribute(QWebSettings::DnsPrefetchEnabled, true);
    w->setAttribute(QWebSettings::FrameFlatteningEnabled, true);       // mobil: ic cerceveler sayfayla birlikte kayar
    w->setAttribute(QWebSettings::ZoomTextOnly, false);
    // Star Browser gibi: sayfa parcalar (tile) halinde onceden cizilir, kaydirma sirasinda yeniden cizim yapilmaz
    w->setAttribute(QWebSettings::TiledBackingStoreEnabled, true);
    w->setOfflineStoragePath(veri + "/depo");
    w->setOfflineWebApplicationCachePath(veri + "/depo");
    w->setLocalStoragePath(veri + "/depo");
    w->setIconDatabasePath(veri + "/depo");
    w->setMaximumPagesInCache(2);
    w->setObjectCacheCapacities(1 * 1024 * 1024, 6 * 1024 * 1024, 12 * 1024 * 1024);
    w->setFontSize(QWebSettings::MinimumFontSize, 9);
    w->setDefaultTextEncoding("UTF-8");

    gunluk("webkit ayarlari tamam");
    KatmanNamFactory fabrika;              // gorunumden uzun yasamali
    QDeclarativeView view;
    view.engine()->setNetworkAccessManagerFactory(&fabrika);
    view.engine()->setOfflineStoragePath(veri + "/depo");
    view.setResizeMode(QDeclarativeView::SizeRootObjectToView);
    view.setViewportUpdateMode(QGraphicsView::FullViewportUpdate);
    view.setAttribute(Qt::WA_OpaquePaintEvent);
    view.setAttribute(Qt::WA_NoSystemBackground);
    view.viewport()->setAttribute(Qt::WA_OpaquePaintEvent);
    view.viewport()->setAttribute(Qt::WA_NoSystemBackground);

    Yardimci tb(&view);
    tb.setGunlukYolu(gGunluk);
    Indirici indir;
    view.rootContext()->setContextProperty("tb", &tb);
    static Pano belPano; view.rootContext()->setContextProperty("pano", &belPano);   // Ctrl+V (kutuphane/pano)
    view.rootContext()->setContextProperty("depo", depo);
    view.rootContext()->setContextProperty("indir", &indir);
    QObject::connect(view.engine(), SIGNAL(quit()), &app, SLOT(quit()));
    gunluk("qml yukleniyor");
    view.rootContext()->setContextProperty("dil", dil);
    view.setSource(QUrl("qrc:/qml/main.qml"));
    {   // QML yuklenemezse (ornegin QtWebKit eksik) nedeni dosyada gorunur
        QString s = "qml durum=" + QString::number(int(view.status()));
        foreach (const QDeclarativeError &h, view.errors()) s += "\n  HATA " + h.toString();
        gunluk(s);
    }

#if defined(Q_OS_SYMBIAN)
    view.showFullScreen();
#else
    view.resize(640, 480);
    view.show();
#endif
    gunluk("gosterildi, olay dongusu");
    const int r = app.exec();
    gunluk("cikis");
    KaliciCerez::ortak()->kaydet();
    return r;
}
