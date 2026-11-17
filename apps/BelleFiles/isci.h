#ifndef ISCI_H
#define ISCI_H

// Arka plan dosya isleri (arayuz donmasin): kopyala, tasi, sil, zip olustur, zip ac.
// Ilerleme sinyalleriyle QML'deki ilerleme penceresini besler; iptal edilebilir.

#include <QtCore/QThread>
#include <QtCore/QStringList>
#include <QtCore/QVariantList>
#include <QtCore/QTime>
#include "zip.h"

class Isci : public QThread, public ZipIzleyici
{
    Q_OBJECT
    Q_PROPERTY(bool calisiyor READ calisiyor NOTIFY durumDegisti)
public:
    explicit Isci(QObject *parent = 0);
    bool calisiyor() const { return isRunning(); }

    // tur: "kopyala" | "tasi" | "sil" | "zip" | "zipac"
    //  kopyala/tasi: kaynaklar -> hedef klasor     sil: kaynaklar
    //  zip: kaynaklar -> hedef (.zip yolu)          zipac: kaynaklar[0] arsiv -> hedef klasor, secili: ogeler (bos: tumu)
    Q_INVOKABLE bool baslat(const QString &tur, const QStringList &kaynaklar, const QString &hedef,
                            const QStringList &secili = QStringList());
    Q_INVOKABLE void iptal() { m_iptal = true; }
    Q_INVOKABLE QVariantList zipListe(const QString &arsiv);
    Q_INVOKABLE QString hata() const { return m_hata; }
    Q_INVOKABLE QString benzersiz(const QString &klasor, const QString &ad) const;
    // Sifreli zip: sonraki "zipac" isinde kullanilacak parola; is parola yuzunden bittiyse parolaSorunu()
    Q_INVOKABLE void parolaAyarla(const QString &p) { m_parola = p; }
    Q_INVOKABLE bool parolaSorunu() const { return m_parolaSorunu; }
    Q_INVOKABLE bool zipSifreli(const QString &arsiv, const QStringList &secili = QStringList());

    bool zipIlerleme(qint64 bayt);

signals:
    void durumDegisti();
    void ilerleme(double bitti, double toplam, const QString &ad, int adet, int toplamAdet);
    void bitti(bool ok, const QString &mesaj, const QString &sonuc);

protected:
    void run();

private slots:
    void onBitti();

private:
    struct Is { QString yol; QString goreli; bool klasor; qint64 boyut; };
    void topla(const QString &yol, const QString &goreli, QList<Is> *liste);
    bool dosyaKopyala(const QString &a, const QString &b);
    bool klasorSil(const QString &yol);
    void bildir(const QString &ad, bool zorla = false);
    void kopyalaTasi(bool tasi);
    void sil();
    void zipYap();
    void zipAc();
    void zipEkle();

    QString m_tur, m_hedef;
    QStringList m_kaynaklar, m_secili;
    volatile bool m_iptal;
    qint64 m_bitti, m_toplam;
    int m_adet, m_toplamAdet;
    QTime m_saat;
    QString m_ad;
    bool m_ok;
    QString m_mesaj, m_sonuc, m_hata;
    QString m_parola;
    bool m_parolaSorunu;
};

#endif
