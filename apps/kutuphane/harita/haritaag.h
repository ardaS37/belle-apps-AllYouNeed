#ifndef HARITAAG_H
#define HARITAAG_H

// Harita karolari icin karta onbellek: her karo kendi dosyasinda (E:/BelleMaps/karolar/<sunucu>/<z>/<x>/<y>.k).
// Varsa dogrudan dosyadan verilir, yoksa agdan indirilip dosyaya yazilir. Yalnizca karo sunuculari onbelleklenir.
//
// Eskiden QNetworkDiskCache kullaniliyordu: QML her is parcacigi icin ayri NAM (ve ayri disk onbellegi) acar,
// ayni klasoru birden cok nesne yonetiyordu; onbellek dolunca her biri klasorun TAMAMINI bellege listeleyip
// temizliyordu -> uzun rotada harita uzaklasinca "hafiza dolu" ve yan is parcacigi cokmesi.
// Simdi paylasilan nesne yok, klasor bellege listelenmez; boyut acilista arka planda (sabit bellekle) denetlenir.
//
// Kullanim: HaritaAg::kur(view.engine());   (QML'in tum istekleri bu NAM'dan gecer)

#include <QtCore/QUrl>
#include <QtCore/QByteArray>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkReply>
#include <QtDeclarative/QDeclarativeNetworkAccessManagerFactory>

class QDeclarativeEngine;

class HaritaNam : public QNetworkAccessManager
{
public:
    explicit HaritaNam(QObject *parent = 0);
    static bool karoMu(const QUrl &u);
    static QString onbellekKlasoru();
    static QString karoDosyasi(const QUrl &u);
protected:
    QNetworkReply *createRequest(Operation op, const QNetworkRequest &req, QIODevice *data);
};

// Agdan gelen karo yanitini sarar: QML'e aynen verir, basariliysa karoyu dosyaya da yazar
class KaroYanit : public QNetworkReply
{
    Q_OBJECT
public:
    KaroYanit(QNetworkReply *ic, const QString &dosya, QObject *parent);
    ~KaroYanit();
    void abort();
    qint64 bytesAvailable() const;
    bool isSequential() const { return true; }
protected:
    qint64 readData(char *veri, qint64 en);
private slots:
    void bitti();
private:
    QNetworkReply *m_ic;
    QByteArray m_veri;
    qint64 m_kon;
    QString m_dosya;
    bool m_bitti;
};

class HaritaAg : public QDeclarativeNetworkAccessManagerFactory
{
public:
    QNetworkAccessManager *create(QObject *parent) { return new HaritaNam(parent); }
    static void kur(QDeclarativeEngine *engine);
    static qint64 onbellekBoyutu();
    static void onbellekSil();
};

#endif
