#ifndef KAROYUKLEYICI_H
#define KAROYUKLEYICI_H

// Karo yukleyici (MahoMaps'teki TilesProvider gibi): karolar C++'ta, ana is parcaciginda, sirayla ve en fazla
// 4 eszamanli indirilip karta yazilir. QML'e yalnizca kartta hazir dosya (file://) verilir; boylece QML'in ag
// uzerinden resim yukleyicisi (arka plan is parcacigi + iptaller) hic kullanilmaz.
// Eskiden: hizli yakinlik/kaydirma degisiminde yuzlerce yarim istek iptal ediliyor, QML'in yukleyicisi
// Symbian'da cokuyordu (yan is parcaciginda bos isaretci, ana is parcaciginda ROM'da abort).
//
// QML:  source: karoYukleyici.yerel(uzakAdres, surum)    // "" donerse indirme sirasina girer
//       Connections { target: karoYukleyici; onHazir: if (url === uzakAdres) surum++ }
#include <QtCore/QObject>
#include <QtCore/QStringList>
#include <QtCore/QSet>
#include <QtCore/QHash>

class QNetworkAccessManager;
class QNetworkReply;

class KaroYukleyici : public QObject
{
    Q_OBJECT
public:
    explicit KaroYukleyici(QObject *parent = 0);
    static KaroYukleyici *tek();
    // Yerel dosya adresi; yoksa "" ve indirme sirasina alinir (surum: QML yeniden hesaplasin diye)
    Q_INVOKABLE QString yerel(const QString &uzak, int surum = 0);

signals:
    void hazir(const QString &url);

private slots:
    void bitti();

private:
    void sirayiIslet();
    QNetworkAccessManager *m_nam;
    QStringList m_sira;                  // en yeni istek basta
    QHash<QNetworkReply *, QString> m_aktif;
    QSet<QString> m_bekleyen;            // sirada ya da iniyor
    QHash<QString, int> m_hata;          // basarisiz deneme sayisi
};

#endif
