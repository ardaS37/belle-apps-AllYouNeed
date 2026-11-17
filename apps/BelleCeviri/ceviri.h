#ifndef CEVIRI_H
#define CEVIRI_H

// BelleCeviri cekirdegi: QML'e "cv" adiyla acilir.
//  - genel HTTP istegi (GET/POST, istenen basliklar): servislerin (Google, DeepL, Gemini...) hepsi
//    QML'deki Servis.js'te tanimlidir; burada yalnizca tasima. Qt 4.7 XHR'in gizledigi 402/429
//    gibi yanitlar da govdesiyle gelir.
//  - pano, kucuk dosya yardimcilari (anahtar ice aktarma), gunluk.

#include <QtCore/QObject>
#include <QtCore/QStringList>
#include <QtCore/QVariantMap>

class QNetworkAccessManager;

class Ceviri : public QObject
{
    Q_OBJECT
public:
    explicit Ceviri(const QString &veri, QObject *parent = 0);

    // Sonuc yanit(id, kod, govde, hata) ile gelir. kod: HTTP durumu (0: ag hatasi)
    Q_INVOKABLE void istek(const QString &id, const QString &yontem, const QString &url, const QVariantMap &basliklar, const QString &govde);
    Q_INVOKABLE void iptal(const QString &onEk);           // id'si bu onekle baslayanlari durdur

    Q_INVOKABLE void panoya(const QString &metin);
    Q_INVOKABLE QString pano() const;
    Q_INVOKABLE void girisiTamamla() const;   // islenmemis (alti cizili) kelimeyi kutuya isle

    Q_INVOKABLE bool dosyaVar(const QString &yol) const;
    Q_INVOKABLE QString dosyaOku(const QString &yol) const;
    Q_INVOKABLE bool dosyaSil(const QString &yol);
    Q_INVOKABLE QString veriKlasoru() const { return m_veri; }

    Q_INVOKABLE void kayit(const QString &s);
    Q_INVOKABLE QString gunluk() const;
    // tek seferlik zamanlayici (QML Timer ekran kapaliyken durur): ms sonra zamanDoldu(ad)
    Q_INVOKABLE void zamanla(const QString &ad, int ms);

signals:
    void yanit(const QString &id, int kod, const QString &govde, const QString &hata);
    void zamanDoldu(const QString &ad);

private slots:
    void bitti();
    void zamanTik();

private:
    QString m_veri;
    QNetworkAccessManager *m_nam;
    QStringList m_gunluk;
};

#endif
