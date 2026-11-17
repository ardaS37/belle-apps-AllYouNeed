#include "gpskonum.h"
#include "dil.h"
#include <QtCore/QDateTime>

GpsKonum::GpsKonum(QObject *parent)
    : QObject(parent),
#ifdef BELLE_GPS
      m_kaynak(0), m_uydu(0),
#endif
      m_aktif(false), m_tek(true), m_enIyi(1e9), m_gorunen(0), m_kullanilan(0)
{
    m_sure.setSingleShot(true);
    connect(&m_sure, SIGNAL(timeout()), this, SLOT(zamanAsimi()));
    m_tik.setInterval(1000);                    // gecen sureyi ekranda guncelle
    connect(&m_tik, SIGNAL(timeout()), this, SLOT(tikla()));
}

void GpsKonum::baslat(bool tekSefer)
{
#ifdef BELLE_GPS
    if (m_aktif) { m_tek = m_tek && tekSefer; return; }
    m_tek = tekSefer;
    m_enIyi = 1e9;
    m_gorunen = m_kullanilan = 0;
    m_bas.start();
    m_kaynak = QGeoPositionInfoSource::createDefaultSource(this);
    if (!m_kaynak) { m_durum = Dil::t("Bu telefonda konum servisi bulunamadı"); emit durumDegisti(); emit hata(m_durum); return; }
    m_kaynak->setPreferredPositioningMethods(QGeoPositionInfoSource::AllPositioningMethods);
    m_kaynak->setUpdateInterval(1500);
    connect(m_kaynak, SIGNAL(positionUpdated(QGeoPositionInfo)), this, SLOT(guncelleme(QGeoPositionInfo)));
    connect(m_kaynak, SIGNAL(updateTimeout()), this, SLOT(kaynakHatasi()));
    m_uydu = QGeoSatelliteInfoSource::createDefaultSource(this);
    if (m_uydu) {
        connect(m_uydu, SIGNAL(satellitesInViewUpdated(QList<QGeoSatelliteInfo>)), this, SLOT(uyduGorunen(QList<QGeoSatelliteInfo>)));
        connect(m_uydu, SIGNAL(satellitesInUseUpdated(QList<QGeoSatelliteInfo>)), this, SLOT(uyduKullanilan(QList<QGeoSatelliteInfo>)));
        m_uydu->startUpdates();
    }
    m_aktif = true;
    emit aktifDegisti();
    durumYaz();
    // son bilinen konum hemen (kaba da olsa) gosterilsin
    const QGeoPositionInfo son = m_kaynak->lastKnownPosition();
    m_kaynak->startUpdates();
    m_tik.start();
    m_sure.start(tekSefer ? 150000 : 900000);
    if (son.isValid() && son.timestamp().secsTo(QDateTime::currentDateTime()) < 600) guncelleme(son);
#else
    Q_UNUSED(tekSefer);
    m_durum = Dil::t("Konum servisi bu derlemede yok");
    emit durumDegisti();
    emit hata(m_durum);
#endif
}

void GpsKonum::durdur()
{
#ifdef BELLE_GPS
    // kaynaklar tamamen silinir: GPS alicisi kapanir, pil harcanmaz
    if (m_kaynak) { m_kaynak->stopUpdates(); m_kaynak->deleteLater(); m_kaynak = 0; }
    if (m_uydu) { m_uydu->stopUpdates(); m_uydu->deleteLater(); m_uydu = 0; }
#endif
    m_sure.stop();
    m_tik.stop();
    if (m_aktif) {
        m_aktif = false;
        if (m_enIyi < 1e9) m_durum = Dil::t("GPS kapalı • son konum ±%1 m").arg(qRound(m_enIyi));
        else m_durum = Dil::t("GPS kapalı");
        emit aktifDegisti();
        emit durumDegisti();
    }
}

void GpsKonum::durumYaz()
{
    if (!m_aktif) return;
    const int sn = m_bas.elapsed() / 1000;
    const QString sure = sn < 60 ? QString::number(sn) + " sn" : QString::number(sn / 60) + " dk " + QString::number(sn % 60) + " sn";
    QString s;
    if (m_enIyi < 1e9) {
        s = Dil::t("Konum bulundu ±%1 m").arg(qRound(m_enIyi));
        if (m_enIyi > 100) s += Dil::t(" (kaba: ağ / baz istasyonu), GPS hassaslaşıyor…");
    } else if (m_gorunen == 0) {
        s = Dil::t("GPS'e bağlanılıyor… uydu aranıyor");
    } else if (m_kullanilan < 3) {
        s = Dil::t("Uydu aranıyor: %1 görünüyor, %2 kilitlendi (en az 3 gerekir)").arg(m_gorunen).arg(m_kullanilan);
    } else {
        s = Dil::t("%1 uydu kilitlendi, konum hesaplanıyor").arg(m_kullanilan);
    }
    if (m_enIyi < 1e9 && m_gorunen > 0) s += Dil::t(" • %1/%2 uydu").arg(m_kullanilan).arg(m_gorunen);
    m_durum = s + QString::fromUtf8(" • ") + sure;
    emit durumDegisti();
}

void GpsKonum::tikla() { durumYaz(); }

#ifdef BELLE_GPS
void GpsKonum::guncelleme(const QGeoPositionInfo &p)
{
    if (!p.isValid() || !m_aktif) return;
    double dog = p.hasAttribute(QGeoPositionInfo::HorizontalAccuracy) ? p.attribute(QGeoPositionInfo::HorizontalAccuracy) : 500;
    if (dog <= 0) dog = 500;
    m_enIyi = qMin(m_enIyi, dog);
    durumYaz();
    emit bulundu(p.coordinate().latitude(), p.coordinate().longitude(), dog);
    if (m_tek && m_aktif && dog <= 50) durdur();      // yeterince iyi: kapat
}

void GpsKonum::uyduGorunen(const QList<QGeoSatelliteInfo> &l) { m_gorunen = l.size(); durumYaz(); }
void GpsKonum::uyduKullanilan(const QList<QGeoSatelliteInfo> &l) { m_kullanilan = l.size(); durumYaz(); }
void GpsKonum::kaynakHatasi() { durumYaz(); }
#endif

void GpsKonum::zamanAsimi()
{
    const bool hicYok = m_enIyi >= 1e9;
    durdur();
    if (hicYok) emit hata(Dil::t("Konum bulunamadı. Açık havada tekrar deneyin (GPS ilk uydu araması birkaç dakika sürebilir)."));
}
