#ifndef KITAP_H
#define KITAP_H

// BelleKitap cekirdegi: QML'e "kt" adiyla acilir.
//  - kutuphane taramasi (E: ve C:/Data; .epub her yerde, .txt "kitap/book" adli klasorlerde), adim adim
//  - EPUB: container.xml -> OPF (baslik, yazar, kapak, spine), icindekiler (NCX ya da EPUB3 nav)
//  - bolumler Qt zengin metnine uygun sade HTML'e cevrilir; resimler ekrana sigdirilir;
//    uzun bolumler parcalara bolunur (telefonda hizli dizilsin)

#include <QtCore/QObject>
#include <QtCore/QStringList>
#include <QtCore/QVariantList>
#include <QtCore/QVariantMap>
#include <QtCore/QTimer>
#include <QtCore/QFile>
#include <QtCore/QUrl>

class QNetworkAccessManager;
class QNetworkReply;

class Kitap : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool taraniyor READ taraniyor NOTIFY taramaDegisti)
    Q_PROPERTY(bool indiriyor READ indiriyor NOTIFY indirmeDegisti)
public:
    explicit Kitap(const QString &veri, QObject *parent = 0);

    Q_INVOKABLE QVariantList kutuphane() const { return m_kutuphane; }   // [{yol, baslik, yazar, kapak, boyut, tur}]
    Q_INVOKABLE void tara();
    bool taraniyor() const { return m_taraniyor; }

    // Kitabi ac: {ok, hata, baslik, yazar, bolumSayisi, icindekiler:[{baslik, bolum, derinlik}]}
    Q_INVOKABLE QVariantMap ac(const QString &yol);
    // Acik kitabin bolumu, parcalar halinde (sade HTML). genislik: resimlerin en buyuk genisligi (piksel)
    Q_INVOKABLE QStringList bolum(int i, int genislik);
    Q_INVOKABLE QString bolumBasligi(int i) const;

    // ---- cevrimici kitaplar (Gutenberg / Vikikaynak) ----
    Q_INVOKABLE void getir(const QString &id, const QString &url);         // sonuc metinGeldi(id, govde, hata)
    Q_INVOKABLE bool indir(const QString &url, const QString &yol);        // sonuc indirmeBitti(ok, yol, hata)
    Q_INVOKABLE void indirmeIptal();
    Q_INVOKABLE bool metinKaydet(const QString &yol, const QString &metin);
    Q_INVOKABLE QVariantMap kitapEkle(const QString &yol);                 // indirileni kitapliga hemen ekle
    Q_INVOKABLE QString kitapKlasoru() const;
    Q_INVOKABLE QString guvenliAd(const QString &ad) const;
    bool indiriyor() const { return m_indirme != 0; }

    Q_INVOKABLE bool dosyaVar(const QString &yol) const;
    Q_INVOKABLE bool dosyaSil(const QString &yol);
    Q_INVOKABLE QString veriKlasoru() const { return m_veri; }
    Q_INVOKABLE void kayit(const QString &s);
    Q_INVOKABLE QString gunluk() const;
    Q_INVOKABLE void zamanla(const QString &ad, int ms);

signals:
    void taramaDegisti();
    void taramaIlerleme(int bulunan);
    void taramaBitti();
    void zamanDoldu(const QString &ad);
    void metinGeldi(const QString &id, const QString &govde, const QString &hata);
    void indirmeDegisti();
    void indirmeIlerleme(double alinan, double toplam);
    void indirmeBitti(bool ok, const QString &yol, const QString &hata);

private slots:
    void taramaAdimi();
    void zamanTik();
    void getirBitti();
    void indirOku();
    void indirIlerle(qint64 a, qint64 t);
    void indirBitti();

private:
    bool epubCoz(const QString &epub, const QString &kok, QVariantMap *bilgi, QStringList *spine, QVariantList *icindekiler, QString *hata);
    bool tamAc(const QString &epub, const QString &hedef, QString *hata);
    QByteArray girdiOku(const QString &epub, const QString &ad);
    QVariantMap ustVeri(const QString &yol);
    QString onbellekIcin(const QString &yol) const;
    void kaydet();

    QString m_veri, m_onbellek;
    QVariantList m_kutuphane;
    bool m_taraniyor;
    QStringList m_kuyruk, m_bulunan;
    QTimer m_tarama;
    int m_ustVeriSira;
    // acik kitap
    QString m_acikYol, m_acikKok;
    bool m_acikTxt;
    QStringList m_spine;
    QStringList m_bolumAdlari;
    QStringList m_gunluk;
    // ag
    void getirAt(const QUrl &u, const QString &id, int yon);
    void indirAt(const QUrl &u);
    QNetworkAccessManager *m_nam;
    QNetworkReply *m_indirme;
    QFile *m_indirDosya;
    QString m_indirYol;
    int m_indirYon;
    bool m_iptal;
};

#endif
