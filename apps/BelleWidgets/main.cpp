#include <QtGui/QApplication>
#include "dil.h"
#include "ayna.h"
#include <QtCore/QTimer>

#include "pil.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    Dil::kur(&app);   // Turkce / English (QML'den once)
    // Ayarlar hafiza kartina aynalanir; telefon sifirlaninca / ROM sonrasi otomatik geri gelir (kutuphane/ayna)
    Ayna::baslat("BelleWidgets", QStringList() << "C:/Data/E6Pil");
    app.setApplicationName("E6Pil");
    // Arayuz kapatilsa da uygulama widget icin arka planda calismaya devam eder
    app.setQuitOnLastWindowClosed(false);

    Pil pil;
    Ekran ekran(&pil);

    // Telefon acilisinda (baslangic listesinden) basladiysa arayuz hic olusturulmaz, arka plana gecilir
    if (pil.startedAtBoot()) {
        ekran.quietFor(8000);
        QTimer::singleShot(0, &ekran, SLOT(hide()));
    } else {
        ekran.show();
    }

    return app.exec();
}
