#include "cevrimdisi.h"
#include "dil.h"
#include "haritaag.h"

#include <QtCore/QDir>
#include <QtCore/QDirIterator>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QTimer>
#include <QtCore/qmath.h>
#include <QtNetwork/QNetworkRequest>
#include <QtNetwork/QNetworkReply>

static const int KEnFazlaKaro = 25000;
static const int KEsZamanli = 3;

static int lngX(double lng, int z) { return int(floor((lng + 180.0) / 360.0 * (1 << z))); }
static int latY(double lat, int z)
{
    lat = qBound(-85.0511, lat, 85.0511);
    const double r = lat * M_PI / 180.0;
    return int(floor((1.0 - log(tan(r) + 1.0 / cos(r)) / M_PI) / 2.0 * (1 << z)));
}

Cevrimdisi::Cevrimdisi(QObject *parent)
    : QObject(parent), m_calisiyor(false), m_iptal(false), m_toplam(0), m_biten(0), m_hatali(0), m_aktif(0) {}

QString Cevrimdisi::kok()
{
    return QFileInfo(HaritaNam::onbellekKlasoru()).absolutePath() + "/cevrimdisi";
}

QString Cevrimdisi::dosyaYolu(const QUrl &u)
{
    QString yol = u.path();
    yol.replace(QRegExp("[^A-Za-z0-9_./-]"), "_");
    if (yol.contains("..")) yol.replace("..", "_");
    return kok() + "/" + u.host() + yol + ".k";
}

int Cevrimdisi::say(double lat1, double lng1, double lat2, double lng2, int z1, int z2) const
{
    qint64 n = 0;
    for (int z = z1; z <= z2; ++z) {
        const qint64 w = qAbs(lngX(lng2, z) - lngX(lng1, z)) + 1, h = qAbs(latY(lat2, z) - latY(lat1, z)) + 1;
        n += w * h;
        if (n > 1000000) return 1000000;
    }
    return int(n);
}

QString Cevrimdisi::adres(const Karo &k) const
{
    QString s = m_sablon;
    const QString alt = m_altlar.isEmpty() ? QString() : m_altlar.at((k.x + k.y) % m_altlar.size());
    s.replace("{s}", alt).replace("{z}", QString::number(k.z)).replace("{x}", QString::number(k.x)).replace("{y}", QString::number(k.y));
    return s;
}

bool Cevrimdisi::baslat(const QString &sablon, const QStringList &altlar, double lat1, double lng1, double lat2, double lng2, int z1, int z2)
{
    if (m_calisiyor || say(lat1, lng1, lat2, lng2, z1, z2) > KEnFazlaKaro) return false;
    m_sablon = sablon;
    m_altlar = altlar;
    m_kuyruk.clear();
    for (int z = z1; z <= z2; ++z) {
        const int xa = qMin(lngX(lng1, z), lngX(lng2, z)), xb = qMax(lngX(lng1, z), lngX(lng2, z));
        const int ya = qMin(latY(lat1, z), latY(lat2, z)), yb = qMax(latY(lat1, z), latY(lat2, z));
        for (int x = xa; x <= xb; ++x)
            for (int y = ya; y <= yb; ++y) { Karo k = { z, x, y }; m_kuyruk << k; }
    }
    m_toplam = m_kuyruk.size();
    m_biten = m_hatali = m_aktif = 0;
    m_iptal = false;
    m_calisiyor = true;
    emit durumDegisti();
    emit ilerledi();
    for (int i = 0; i < KEsZamanli; ++i) QTimer::singleShot(0, this, SLOT(sonraki()));
    return true;
}

void Cevrimdisi::iptal() { if (m_calisiyor) { m_iptal = true; m_kuyruk.clear(); } }

void Cevrimdisi::sonraki()
{
    while (!m_kuyruk.isEmpty() && !m_iptal) {
        const Karo k = m_kuyruk.takeFirst();
        const QUrl u(adres(k));
        if (QFile::exists(dosyaYolu(u))) { ++m_biten; emit ilerledi(); continue; }     // zaten var
        QNetworkRequest r(u);
        r.setRawHeader("User-Agent", "BelleMaps/1.1 (Nokia E6 Symbian; Qt 4.8; cevrimdisi alan)");
        QNetworkReply *rep = m_nam.get(r);
        connect(rep, SIGNAL(finished()), this, SLOT(indi()));
        ++m_aktif;
        return;
    }
    if (m_aktif == 0 && m_calisiyor) {
        m_calisiyor = false;
        emit durumDegisti();
        emit bitti(!m_iptal, m_iptal ? Dil::t("Durduruldu: %1 / %2 karo").arg(m_biten).arg(m_toplam)
                                     : Dil::t("%1 karo indirildi%2").arg(m_biten).arg(m_hatali ? Dil::t(", %1 indirilemedi").arg(m_hatali) : QString()));
    }
}

void Cevrimdisi::indi()
{
    QNetworkReply *rep = qobject_cast<QNetworkReply *>(sender());
    if (!rep) return;
    --m_aktif;
    const int st = rep->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray veri = rep->readAll();
    if (rep->error() == QNetworkReply::NoError && st == 200 && veri.size() > 60) {
        const QString yol = dosyaYolu(rep->url());
        QDir().mkpath(QFileInfo(yol).absolutePath());
        QFile f(yol);
        if (f.open(QIODevice::WriteOnly)) { f.write(veri); ++m_biten; }
        else ++m_hatali;
    } else ++m_hatali;
    rep->deleteLater();
    emit ilerledi();
    QTimer::singleShot(0, this, SLOT(sonraki()));
}

QString Cevrimdisi::boyutMetni() const
{
    qint64 t = 0;
    QDirIterator it(kok(), QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) { it.next(); t += it.fileInfo().size(); }
    return t > 1048576 ? QString::number(t / 1048576.0, 'f', 1) + " MB" : QString::number(t / 1024) + " KB";
}

int Cevrimdisi::dosyaSayisi() const
{
    int n = 0;
    QDirIterator it(kok(), QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) { it.next(); ++n; }
    return n;
}

void Cevrimdisi::hepsiniSil()
{
    if (m_calisiyor) return;
    QDirIterator it(kok(), QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) QFile::remove(it.next());
}
