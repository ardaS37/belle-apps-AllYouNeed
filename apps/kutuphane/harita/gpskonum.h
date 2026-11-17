#ifndef GPSKONUM_H
#define GPSKONUM_H

// Telefonun konum servisi (GPS / A-GPS / ag).
// Pil: konum kaynagi YALNIZCA baslat() denince olusturulur; durdur() ya da ilk iyi sonuctan sonra (tekSefer)
// tamamen silinir. Uygulama acikken arka planda hic konum aranmaz.
// QML: gps.baslat(true) -> onBulundu(lat, lng, dogruluk) | onHata(mesaj); gps.durum (ekranda gosterilecek metin),
//      gps.gorunen / gps.kullanilan (uydu sayilari), gps.aktif

#include <QtCore/QObject>
#include <QtCore/QTimer>
#include <QtCore/QTime>

#ifdef BELLE_GPS
#include <qgeopositioninfosource.h>
#include <qgeopositioninfo.h>
#include <qgeosatelliteinfosource.h>
#include <qgeosatelliteinfo.h>
QTM_USE_NAMESPACE
#endif

class GpsKonum : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool aktif READ aktif NOTIFY aktifDegisti)
    Q_PROPERTY(bool destek READ destek CONSTANT)
    Q_PROPERTY(QString durum READ durum NOTIFY durumDegisti)
    Q_PROPERTY(int gorunen READ gorunen NOTIFY durumDegisti)
    Q_PROPERTY(int kullanilan READ kullanilan NOTIFY durumDegisti)
    Q_PROPERTY(double dogruluk READ dogruluk NOTIFY durumDegisti)
public:
    explicit GpsKonum(QObject *parent = 0);
    bool aktif() const { return m_aktif; }
    bool destek() const { return true; }
    QString durum() const { return m_durum; }
    int gorunen() const { return m_gorunen; }
    int kullanilan() const { return m_kullanilan; }
    double dogruluk() const { return m_enIyi < 1e9 ? m_enIyi : -1; }
    // tekSefer: yeterince dogru ilk sonuctan sonra kendiliginden kapanir; aksi halde durdur()'a kadar izler
    Q_INVOKABLE void baslat(bool tekSefer);
    Q_INVOKABLE void durdur();

signals:
    void bulundu(double lat, double lng, double dogruluk);
    void hata(const QString &mesaj);
    void aktifDegisti();
    void durumDegisti();

private slots:
#ifdef BELLE_GPS
    void guncelleme(const QGeoPositionInfo &p);
    void uyduGorunen(const QList<QGeoSatelliteInfo> &l);
    void uyduKullanilan(const QList<QGeoSatelliteInfo> &l);
    void kaynakHatasi();
#endif
    void zamanAsimi();
    void tikla();

private:
    void durumYaz();
#ifdef BELLE_GPS
    QGeoPositionInfoSource *m_kaynak;
    QGeoSatelliteInfoSource *m_uydu;
#endif
    bool m_aktif, m_tek;
    double m_enIyi;
    int m_gorunen, m_kullanilan;
    QString m_durum;
    QTime m_bas;
    QTimer m_sure, m_tik;
};

#endif
