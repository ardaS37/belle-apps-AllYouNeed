#include "pil.h"
#include "pano.h"
#include "dil.h"

#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QSettings>
#include <QtCore/QTextStream>
#include <QtCore/QUrl>
#include <QtCore/QRegExp>
#include <QtCore/QMetaObject>
#include <QtGui/QApplication>
#include <QtGui/QPainter>
#include <QtGui/QLinearGradient>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkRequest>
#include <QtNetwork/QNetworkReply>
#include <QtNetwork/QNetworkConfigurationManager>
#include <QtDeclarative/QDeclarativeView>
#include <QtDeclarative/QDeclarativeEngine>
#include <QtDeclarative/QDeclarativeContext>

#ifdef Q_OS_SYMBIAN
#include <apgtask.h>
#include <coemain.h>
#include <w32std.h>
#include <hwrmvibra.h>
#include <hal.h>
#include <e32std.h>
#endif

static const uint KHistorySecs = 48 * 3600;
static const char *KUserAgent = "BelleWidgets/1.6 (Nokia E6; Symbian Belle)";

// Widget yazilari 8 bit gidiyor; Turkce harfler bozulmasin diye sadelestirilir
static QString ascii(const QString &s)
{
    static const QString a = Dil::t("çÇğĞıİöÖşŞüÜ°");
    static const QString b = "cCgGiIoOsSuU ";
    QString o;
    for (int i = 0; i < s.length(); ++i) {
        const int k = a.indexOf(s.at(i));
        if (k == a.length() - 1) { o += "C"; continue; }   // derece isareti -> "9C"
        o += k >= 0 ? b.at(k) : s.at(i);
    }
    return QString::fromLatin1(o.toLatin1());
}

static QString hm(double hours)
{
    if (hours <= 0) return QString();
    const int total = int(hours * 60 + 0.5);
    const int h = total / 60, m = total % 60;
    if (h == 0) return QString::number(m) + " dk";
    if (h >= 48) return QString::number(h / 24) + Dil::t(" gün");
    return QString::number(h) + " sa " + QString::number(m) + " dk";
}

// WMO hava kodu -> Turkce aciklama
static QString weatherDesc(int c)
{
    switch (c) {
    case 0: return Dil::t("Açık");
    case 1: return Dil::t("Az bulutlu");
    case 2: return Dil::t("Parçalı bulutlu");
    case 3: return Dil::t("Kapalı");
    case 45: case 48: return QString::fromUtf8("Sisli");
    case 51: case 53: case 55: return Dil::t("Çisenti");
    case 56: case 57: return Dil::t("Dondurucu çisenti");
    case 61: return Dil::t("Hafif yağmur");
    case 63: return Dil::t("Yağmurlu");
    case 65: return Dil::t("Şiddetli yağmur");
    case 66: case 67: return Dil::t("Dondurucu yağmur");
    case 71: return Dil::t("Hafif kar");
    case 73: return Dil::t("Karlı");
    case 75: return Dil::t("Yoğun kar");
    case 77: return Dil::t("Kar taneleri");
    case 80: case 81: return Dil::t("Sağanak");
    case 82: return Dil::t("Şiddetli sağanak");
    case 85: case 86: return Dil::t("Kar sağanağı");
    case 95: return Dil::t("Gök gürültülü");
    case 96: case 99: return Dil::t("Dolulu fırtına");
    default: return QString::fromUtf8("—");
    }
}

// 0 gunes/ay, 1 parcali, 2 bulut, 3 sis, 4 yagmur, 5 kar, 6 firtina
static int weatherKind(int c)
{
    if (c <= 1) return 0;
    if (c == 2) return 1;
    if (c == 3) return 2;
    if (c == 45 || c == 48) return 3;
    if ((c >= 71 && c <= 77) || c == 85 || c == 86) return 5;
    if (c >= 95) return 6;
    if (c >= 51) return 4;
    return 2;
}

Pil::Pil(QObject *parent)
    : QObject(parent), m_level(-1), m_state(0), m_fine(false), m_fullAlerted(false), m_lowAlerted(false),
      m_historyVersion(0), m_ramPct(-1), m_ramFreeMB(-1), m_ramTotalMB(-1), m_cpuPct(-1),
      m_finePct(-1), m_lastIdleUs(-1), m_lastWallUs(-1), m_uiOpen(false),
      m_lat(0), m_lon(0), m_temp(0), m_wcode(-1), m_isDay(true), m_nam(0), m_geoReply(0), m_wReply(0),
      m_style("wide"), m_imageFlip(0), m_fullAlert(true), m_lowAlert(15),
      m_widgetReady(false), m_publishPending(false), m_cpuErr(0)
#ifdef E6_MOBILITY
      , m_info(0)
#ifdef Q_OS_SYMBIAN
      , m_batt(0)
#endif
#endif
{
#ifdef Q_OS_SYMBIAN
    m_dir = "C:/Data/E6Pil";
#else
    m_dir = QDir::homePath() + "/E6Pil";
#endif
    m_wind = 0;
    QDir().mkpath(m_dir);
    for (int i = 0; i < 2; ++i) { m_w[i] = 0; m_wActive[i] = false; m_wSusp[i] = false; }
    log("----- basladi v1.6 BelleWidgets" + QString(startedAtBoot() ? " (telefon acilisinda)" : ""));
    m_widgetStatus = Dil::t("Başlatılıyor");
    loadSettings();
    loadHistory();

#ifdef E6_MOBILITY
    log("adim: cihaz bilgisi");
    m_info = new QSystemDeviceInfo(this);
    connect(m_info, SIGNAL(batteryLevelChanged(int)), this, SLOT(onBarsChanged()));
    connect(m_info, SIGNAL(powerStateChanged(QSystemDeviceInfo::PowerState)), this, SLOT(onBarsChanged()));
#endif
    log("adim: pil okunuyor");
    readBattery();
#ifdef Q_OS_SYMBIAN
    // Gercek yuzde (cihaz bilgisi yalnizca 7 basamakli cubuk veriyor: 100, 85, 71, 57 ...)
    log("adim: batarya bilgisi");
    m_batt = new QSystemBatteryInfo(this);
    connect(m_batt, SIGNAL(remainingCapacityPercentChanged(int)), this, SLOT(onBarsChanged()));
    requestFine();
    readBattery();
#endif
    addSample();
    computeEstimate();
    log("adim: RAM/CPU");
    sampleSys();
    log("pil %" + QString::number(m_level) + (m_fine ? "" : " (cubuk)") + " durum " + QString::number(m_state)
        + ", RAM %" + QString::number(m_ramPct) + " (" + QString::number(m_ramFreeMB) + " MB bos)");

    m_liveTimer.setInterval(60 * 1000);
    connect(&m_liveTimer, SIGNAL(timeout()), this, SLOT(onLiveTick()));
    m_weatherTimer.setInterval(60 * 60 * 1000);
    connect(&m_weatherTimer, SIGNAL(timeout()), this, SLOT(onWeatherTick()));
    m_weatherTimer.start();
    QTimer::singleShot(startedAtBoot() ? 90000 : 4000, this, SLOT(onWeatherTick()));
    // Pil 5 dakikada bir okunur: sistem "yuzde degisti" bildirimini gondermiyor (1.4 gunlugu)
    m_battTimer.setInterval(5 * 60 * 1000);
    connect(&m_battTimer, SIGNAL(timeout()), this, SLOT(onBattTick()));
    m_battTimer.start();

    QTimer::singleShot(startedAtBoot() ? 20000 : 1500, this, SLOT(initWidget()));
}

Pil::~Pil()
{
#ifdef Q_OS_SYMBIAN
#endif
}

QString Pil::stateText() const
{
    switch (m_state) {
    case 1: return QString::fromUtf8("Pilde");
    case 2: return Dil::t("Şarj oluyor");
    case 3: return Dil::t("Dolu, prizde");
    default: return QString::fromUtf8("Bilinmiyor");
    }
}

QString Pil::previewUrl() const
{
    return m_lastImage.isEmpty() ? QString() : QUrl::fromLocalFile(m_lastImage).toString();
}

bool Pil::startedAtBoot() const
{
#ifdef Q_OS_SYMBIAN
    TInt period = 0;
    HAL::Get(HAL::ENanoTickPeriod, period);
    const TInt64 ms = TInt64(User::NTickCount()) * TInt64(period) / 1000;
    return ms < 4 * 60 * 1000;
#else
    return false;
#endif
}

void Pil::log(const QString &s)
{
    const QString line = QDateTime::currentDateTime().toString("dd.MM HH:mm:ss ") + s + "\n";
    qDebug("E6P %s", s.toUtf8().constData());
    // Yalnizca son 50 satir tutulur (her yazimda hemen dosyaya: cokme olursa son adim gorunsun)
    const QString path = m_dir + "/gunluk.txt";
    QFile f(path);
    QList<QByteArray> lines;
    if (f.open(QIODevice::ReadOnly)) {
        lines = f.readAll().split('\n');
        f.close();
    }
    while (!lines.isEmpty() && lines.last().isEmpty()) lines.removeLast();
    lines << line.trimmed().toUtf8();
    while (lines.size() > 50) lines.removeFirst();
    QByteArray out;
    foreach (const QByteArray &l, lines) { out += l; out += '\n'; }
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        f.write(out);
        f.close();
    }
}

QString Pil::logText() const
{
    QFile f(m_dir + "/gunluk.txt");
    if (!f.open(QIODevice::ReadOnly)) return Dil::t("(günlük boş)");
    return QString::fromUtf8(f.readAll().right(5000));
}

// ================= Pil =================

void Pil::readBattery()
{
#ifdef E6_MOBILITY
    m_fine = m_finePct > 0 && m_finePct <= 100;
    m_level = m_fine ? m_finePct : m_info->batteryLevel();
    switch (m_info->currentPowerState()) {
    case QSystemDeviceInfo::BatteryPower: m_state = 1; break;
    case QSystemDeviceInfo::WallPowerChargingBattery: m_state = 2; break;
    case QSystemDeviceInfo::WallPower: m_state = 3; break;
    default: m_state = 0;
    }
#else
    const int m = QTime::currentTime().minute();     // masaustu testi icin taklit
    m_level = 100 - (m * 5 / 3) % 100;
    m_state = (m / 10) % 3 == 2 ? 2 : 1;
    m_fine = true;
#endif
    m_level = qBound(0, m_level, 100);
    m_updated = QDateTime::currentDateTime();
}

// Gercek yuzdeyi iste; sonuc finePercentResult ile gelir (uygulamayi bekletmez)
void Pil::onBarsChanged()
{
    requestFine();
    refresh();
}

void Pil::requestFine()
{
#ifdef Q_OS_SYMBIAN
    if (m_batt) {
        const int p = m_batt->remainingCapacityPercent();
        if (p > 0 && p <= 100) m_finePct = p;
    }
#endif
}

void Pil::finePercentResult(int pct, int err)
{
    static bool logged = false;
    if (!logged) {
        logged = true;
        log("guc API: %" + QString::number(pct) + " (hata " + QString::number(err) + ")");
    }
    if (pct > 0 && pct <= 100) m_finePct = pct;
    refresh();
}

void Pil::refresh()
{
    const int oldLevel = m_level, oldState = m_state;
    readBattery();
    if (m_level == oldLevel && m_state == oldState) return;
    addSample();
    computeEstimate();

    const bool onPower = m_state == 2 || m_state == 3;
    if (m_fullAlert && onPower && m_level >= 100 && !m_fullAlerted) {
        m_fullAlerted = true;
        vibrate(700);
        log("pil doldu, uyari");
    }
    if (!onPower || m_level < 95) m_fullAlerted = false;
    if (m_lowAlert > 0 && m_state == 1 && m_level <= m_lowAlert && !m_lowAlerted) {
        m_lowAlerted = true;
        vibrate(400);
        log("pil azaldi, uyari %" + QString::number(m_level));
    }
    if (onPower || m_level > m_lowAlert + 3) m_lowAlerted = false;

    emit changed();
    publish(false);
}

void Pil::addSample()
{
    const uint now = QDateTime::currentDateTime().toTime_t();
    m_hT << now;
    m_hL << m_level;
    m_hC << (m_state >= 2);
    while (!m_hT.isEmpty() && now - m_hT.first() > KHistorySecs) { m_hT.removeFirst(); m_hL.removeFirst(); m_hC.removeFirst(); }
    appendHistory();
    m_historyVersion++;
    emit historyChanged();
}

// Kalan / dolma suresi: ayni durumdaki (pilde ya da sarjda) son bolumde, ILK ornekten yuzdenin
// SON DEGISTIGI ana kadar gecen sureye gore hesaplanir. (Simdiki zamana gore hesaplanirsa yuzde
// degismedikce sure yanlis bicimde buyur; v1.2'deki hata buydu.)
void Pil::computeEstimate()
{
    if (m_state == 3) { m_estimate = Dil::t("Tam dolu"); return; }
    const bool charging = m_state == 2;
    const uint now = QDateTime::currentDateTime().toTime_t();
    int first = -1;
    for (int i = m_hT.size() - 1; i >= 0; --i) {
        if (m_hC.at(i) != (m_state >= 2) || now - m_hT.at(i) > 8 * 3600) break;
        first = i;
    }
    m_estimate = Dil::t("Hesaplanıyor…");
    if (first < 0) return;
    // yuzdenin simdiki degere ilk ulastigi ornek
    int lastChange = m_hT.size() - 1;
    while (lastChange > first && m_hL.at(lastChange - 1) == m_hL.at(lastChange)) --lastChange;
    const double hours = (m_hT.at(lastChange) - m_hT.at(first)) / 3600.0;
    const int diff = charging ? m_hL.at(lastChange) - m_hL.at(first) : m_hL.at(first) - m_hL.at(lastChange);
    const int need = m_fine ? 3 : 14;
    if (hours < 0.25 || diff < need) return;
    const double rate = diff / hours;
    if (charging) m_estimate = "~" + hm((100 - m_level) / rate) + Dil::t(" içinde dolar");
    else m_estimate = "~" + hm(m_level / rate) + Dil::t(" kaldı");
}

QVariantList Pil::history(int hours) const
{
    QVariantList out;
    const uint from = QDateTime::currentDateTime().toTime_t() - uint(hours) * 3600;
    for (int i = 0; i < m_hT.size(); ++i) {
        if (m_hT.at(i) < from) continue;
        QVariantMap m;
        m["t"] = m_hT.at(i);
        m["level"] = m_hL.at(i);
        m["charging"] = m_hC.at(i);
        out << m;
    }
    return out;
}

void Pil::loadHistory()
{
    const QString path = m_dir + "/gecmis.txt";
    const uint now = QDateTime::currentDateTime().toTime_t();
    QFile f(path);
    if (f.open(QIODevice::ReadOnly)) {
        QTextStream in(&f);
        while (!in.atEnd()) {
            const QStringList p = in.readLine().split(' ');
            if (p.size() < 3 || now - p.at(0).toUInt() > KHistorySecs) continue;
            m_hT << p.at(0).toUInt();
            m_hL << p.at(1).toInt();
            m_hC << (p.at(2) == "1");
        }
        f.close();
    }
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        QTextStream out(&f);
        for (int i = 0; i < m_hT.size(); ++i) out << m_hT.at(i) << ' ' << m_hL.at(i) << ' ' << (m_hC.at(i) ? 1 : 0) << '\n';
    }
}

void Pil::appendHistory()
{
    QFile f(m_dir + "/gecmis.txt");
    if (!f.open(QIODevice::WriteOnly | QIODevice::Append)) return;
    QTextStream out(&f);
    out << m_hT.last() << ' ' << m_hL.last() << ' ' << (m_hC.last() ? 1 : 0) << '\n';
}

// ================= Sistem (RAM / CPU) =================

#ifdef Q_OS_SYMBIAN
// Cekirdegin bos dongu ("Null") is parcaciginin toplam CPU suresi. Iki olcum arasindaki farkin
// gecen sureye orani bos zamandir; kalani islemci kullanimidir.
// Yontem 1: cekirdegin bos dongu ("Null") is parcaciginin CPU suresi (bos zaman).
// err: 1 bulunamadi, 2 acilamadi, 3 GetCpuTime desteklenmiyor
static qint64 idleCpuUs(int *err)
{
    TFindThread finder(_L("*::Null"));
    TFullName name;
    if (finder.Next(name) != KErrNone) { *err = 1; return -1; }
    RThread t;
    if (t.Open(finder) != KErrNone) { *err = 2; return -1; }
    TTimeIntervalMicroSeconds us;
    const TInt e = t.GetCpuTime(us);
    t.Close();
    if (e != KErrNone) { *err = 3; return -1; }
    *err = 0;
    return us.Int64();
}

// Yontem 2 (yedek): butun is parcaciklarinin (Null haric) toplam CPU suresi (mesgul zaman).
// Dakikada bir ve yalnizca ana ekran gorunurken calisir.
static qint64 busyCpuUs()
{
    TFindThread finder(_L("*"));
    TFullName name;
    qint64 sum = 0;
    int ok = 0;
    while (finder.Next(name) == KErrNone) {
        if (name.Right(6) == _L("::Null")) continue;
        RThread t;
        if (t.Open(finder) != KErrNone) continue;
        TTimeIntervalMicroSeconds us;
        if (t.GetCpuTime(us) == KErrNone) { sum += us.Int64(); ok++; }
        t.Close();
    }
    return ok > 0 ? sum : -1;
}
#endif

void Pil::sampleSys()
{
    const int oldRam = m_ramPct, oldCpu = m_cpuPct;
#ifdef Q_OS_SYMBIAN
    TInt total = 0, freeMem = 0;
    HAL::Get(HALData::EMemoryRAM, total);
    HAL::Get(HALData::EMemoryRAMFree, freeMem);
    if (total > 0) {
        m_ramTotalMB = total / (1024 * 1024);
        m_ramFreeMB = freeMem / (1024 * 1024);
        m_ramPct = int(100.0 * (total - freeMem) / total + 0.5);
    }
    // m_lastIdleUs: yontem 1'de bos sure, yontem 2'de mesgul sure (m_cpuErr ile ayirt edilir)
    const qint64 wall = QDateTime::currentDateTime().toMSecsSinceEpoch() * 1000;
    int err = 0;
    qint64 v = -1;
    if (m_cpuErr <= 0) v = idleCpuUs(&err);
    if (v < 0) {
        if (m_cpuErr <= 0) {
            m_cpuErr = err > 0 ? err : 8;
            log("cpu: bos zaman okunamadi (" + QString::number(err) + "), toplam is parcacigi yontemine geciliyor");
            m_lastIdleUs = -1;
        }
        v = busyCpuUs();
        if (v >= 0 && m_lastIdleUs >= 0 && wall > m_lastWallUs)
            m_cpuPct = qBound(0, int(100.0 * double(v - m_lastIdleUs) / double(wall - m_lastWallUs) + 0.5), 100);
        else if (v < 0 && m_cpuErr != 9) { m_cpuErr = 9; log("cpu: toplam yontem de okunamadi"); }
    } else if (m_lastIdleUs >= 0 && wall > m_lastWallUs) {
        m_cpuPct = qBound(0, int((1.0 - double(v - m_lastIdleUs) / double(wall - m_lastWallUs)) * 100 + 0.5), 100);
    }
    m_lastIdleUs = v;
    m_lastWallUs = wall;
#else
    m_ramTotalMB = 256;
    m_ramFreeMB = 60 + QTime::currentTime().second();
    m_ramPct = int(100.0 * (m_ramTotalMB - m_ramFreeMB) / m_ramTotalMB);
    m_cpuPct = (QTime::currentTime().second() * 7) % 100;
#endif
    if (oldRam != m_ramPct || oldCpu != m_cpuPct) emit sysChanged();
}

void Pil::onLiveTick()
{
    requestFine();
    refresh();          // pil (1.4'te burada pil yeniden okunmuyordu)
    sampleSys();
    publish(false);
}

// 5 dakikada bir, ana ekran gorunmese de: pil gecmisi ve kalan sure icin
void Pil::onBattTick()
{
    requestFine();
    refresh();
}

// RAM/CPU yalnizca ana ekran widget'i gorunurken ya da arayuz acikken olculur
void Pil::updateLiveTimer()
{
    const bool run = (m_wActive[0] && !m_wSusp[0]) || (m_wActive[1] && !m_wSusp[1]) || m_uiOpen;
    if (run && !m_liveTimer.isActive()) { sampleSys(); m_liveTimer.start(); }
    else if (!run && m_liveTimer.isActive()) m_liveTimer.stop();
}

void Pil::setUiOpen(bool open)
{
    m_uiOpen = open;
    updateLiveTimer();
    if (open && !m_city.isEmpty() && (m_wUpdated.isNull() || m_wUpdated.secsTo(QDateTime::currentDateTime()) > 30 * 60))
        fetchWeather(false);
}

// ================= Hava durumu (Open-Meteo, duz HTTP, anahtarsiz) =================

QString Pil::weatherText() const
{
    if (m_wcode < 0) return QString();
    return weatherDesc(m_wcode);
}

QString Pil::weatherLine() const
{
    if (m_city.isEmpty()) return Dil::t("Hava: şehir seçin");
    if (m_wcode < 0) return m_city + Dil::t(": bekleniyor");
    QString s = m_city + " " + QString::number(qRound(m_temp)) + QString::fromUtf8("° ") + weatherDesc(m_wcode);
    if (!m_forecast.isEmpty()) {
        const QVariantMap d = m_forecast.first().toMap();
        s += "  " + QString::number(qRound(d.value("max").toDouble())) + "/" + QString::number(qRound(d.value("min").toDouble()));
    }
    return s;
}

static QNetworkConfigurationManager *ncm()
{
    static QNetworkConfigurationManager *m = 0;
    if (!m) m = new QNetworkConfigurationManager(qApp);
    return m;
}

bool Pil::isOnline() const
{
    return ncm()->isOnline();
}

void Pil::onWeatherTick()
{
    if (m_city.isEmpty()) return;
    if (!m_wUpdated.isNull() && m_wUpdated.secsTo(QDateTime::currentDateTime()) < 50 * 60) return;
    fetchWeather(false);
}

// Yenileme: sehir yeniden aranir (geocoding) ve ardindan hava cekilir. Kullanici notu: bu yol daha iyi yanit veriyor.
void Pil::refreshWeather()
{
    if (m_city.isEmpty()) { m_wStatus = Dil::t("Önce şehir seçin"); emit weatherChanged(); return; }
    if (m_wReply) m_wReply->abort();
    if (m_geoReply) return;
    setCity(m_city);
}

void Pil::fetchWeather(bool manual)
{
    if (m_wReply) return;
    if (!manual && !isOnline()) { log("hava: baglanti yok, atlandi"); return; }
    if (!m_nam) m_nam = new QNetworkAccessManager(this);
    const QString url = QString("http://api.open-meteo.com/v1/forecast?latitude=%1&longitude=%2"
                                "&current_weather=true&daily=weathercode,temperature_2m_max,temperature_2m_min,precipitation_probability_max,windspeed_10m_max,sunrise,sunset"
                                "&hourly=temperature_2m,weathercode,precipitation_probability"
                                "&timezone=auto&forecast_days=7").arg(m_lat, 0, 'f', 3).arg(m_lon, 0, 'f', 3);
    QNetworkRequest req((QUrl(url)));
    req.setRawHeader("User-Agent", KUserAgent);
    m_wReply = m_nam->get(req);
    connect(m_wReply, SIGNAL(finished()), this, SLOT(onWeatherReply()));
    m_wStatus = Dil::t("Güncelleniyor…");
    emit weatherChanged();
}

static double jsonNum(const QString &s, const QString &key, bool *ok)
{
    QRegExp rx("\"" + key + "\":(-?[0-9.]+)");
    if (rx.indexIn(s) < 0) { if (ok) *ok = false; return 0; }
    if (ok) *ok = true;
    return rx.cap(1).toDouble();
}

static QStringList jsonArray(const QString &s, const QString &key)
{
    QRegExp rx("\"" + key + "\":\\[([^\\]]*)\\]");
    if (rx.indexIn(s) < 0) return QStringList();
    QString inner = rx.cap(1);
    inner.remove('"');
    return inner.split(',');
}

void Pil::onWeatherReply()
{
    QNetworkReply *r = m_wReply;
    m_wReply = 0;
    r->deleteLater();
    if (r->error() != QNetworkReply::NoError) {
        m_wStatus = Dil::t("Hata: ") + r->errorString();
        log("hava hatasi: " + r->errorString());
        emit weatherChanged();
        return;
    }
    const QString s = QString::fromUtf8(r->readAll());
    const int cw = s.indexOf("\"current_weather\":{");
    if (cw < 0) { m_wStatus = Dil::t("Beklenmeyen yanıt"); emit weatherChanged(); return; }
    const QString cur = s.mid(cw, s.indexOf('}', cw) - cw);
    bool ok = false;
    m_temp = jsonNum(cur, "temperature", &ok);
    m_wcode = int(jsonNum(cur, "weathercode", 0));
    m_isDay = jsonNum(cur, "is_day", 0) != 0;
    m_wind = jsonNum(cur, "windspeed", 0);
    const int d = s.indexOf("\"daily\":{");
    // Saatlik: simdiki saatten itibaren 24 saat
    m_hourly.clear();
    const int hi = s.indexOf("\"hourly\":{");
    if (hi >= 0) {
        const QString hs = (d > hi) ? s.mid(hi, d - hi) : s.mid(hi);
        const QStringList ht = jsonArray(hs, "time"), htc = jsonArray(hs, "temperature_2m"), hc = jsonArray(hs, "weathercode"), hp = jsonArray(hs, "precipitation_probability");
        const QString simdi = QDateTime::currentDateTime().toString("yyyy-MM-ddTHH:00");
        int bas = ht.indexOf(simdi);
        if (bas < 0) bas = 0;
        for (int i = bas; i < ht.size() && i < htc.size() && i < hc.size() && m_hourly.size() < 24; ++i) {
            QVariantMap m;
            m["saat"] = ht.at(i).mid(11, 5);
            m["temp"] = htc.at(i).toDouble();
            m["code"] = hc.at(i).toInt();
            m["desc"] = weatherDesc(hc.at(i).toInt());
            m["rain"] = i < hp.size() ? hp.at(i).toInt() : -1;
            m_hourly << m;
        }
    }
    m_forecast.clear();
    if (d >= 0) {
        const QString daily = s.mid(d);
        const QStringList t = jsonArray(daily, "time"), c = jsonArray(daily, "weathercode"),
                          mx = jsonArray(daily, "temperature_2m_max"), mn = jsonArray(daily, "temperature_2m_min"),
                          rn = jsonArray(daily, "precipitation_probability_max"), wd = jsonArray(daily, "windspeed_10m_max"),
                          sr = jsonArray(daily, "sunrise"), ss = jsonArray(daily, "sunset");
        static const char *gunler[7] = { "Pzt", "Sal", "\xC3\x87" "ar", "Per", "Cum", "Cmt", "Paz" };
        for (int i = 0; i < t.size() && i < c.size() && i < mx.size() && i < mn.size(); ++i) {
            QVariantMap m;
            m["date"] = QDate::fromString(t.at(i), "yyyy-MM-dd").toString("dd.MM");
            const QDate gd = QDate::fromString(t.at(i), "yyyy-MM-dd");
            m["day"] = i == 0 ? Dil::t("Bugün") : (i == 1 ? Dil::t("Yarın") : QString::fromUtf8(gunler[(gd.dayOfWeek() + 6) % 7]));
            m["rain"] = i < rn.size() ? rn.at(i).toInt() : -1;
            m["wind"] = i < wd.size() ? wd.at(i).toDouble() : -1;
            m["sunrise"] = i < sr.size() ? sr.at(i).mid(11, 5) : QString();
            m["sunset"] = i < ss.size() ? ss.at(i).mid(11, 5) : QString();
            m["code"] = c.at(i).toInt();
            m["desc"] = weatherDesc(c.at(i).toInt());
            m["max"] = mx.at(i).toDouble();
            m["min"] = mn.at(i).toDouble();
            m_forecast << m;
        }
    }
    m_wUpdated = QDateTime::currentDateTime();
    m_wStatus = ok ? Dil::t("Güncel") : Dil::t("Eksik veri");
    QSettings st(m_dir + "/ayarlar.ini", QSettings::IniFormat);
    st.setValue("wTemp", m_temp);
    st.setValue("wCode", m_wcode);
    st.setValue("wDay", m_isDay);
    st.setValue("wTime", m_wUpdated);
    log("hava: " + QString::number(m_temp) + " kod " + QString::number(m_wcode));
    emit weatherChanged();
    publish(false);
}

void Pil::setCity(const QString &nameIn)
{
    const QString name = nameIn.trimmed();
    if (name.isEmpty() || m_geoReply) return;
    if (!m_nam) m_nam = new QNetworkAccessManager(this);
    const QString url = "http://geocoding-api.open-meteo.com/v1/search?count=1&language=tr&format=json&name="
                        + QString::fromLatin1(QUrl::toPercentEncoding(name));
    QNetworkRequest req((QUrl::fromEncoded(url.toLatin1())));
    req.setRawHeader("User-Agent", KUserAgent);
    m_geoReply = m_nam->get(req);
    connect(m_geoReply, SIGNAL(finished()), this, SLOT(onGeoReply()));
    m_wStatus = Dil::t("Şehir aranıyor…");
    emit weatherChanged();
}

void Pil::onGeoReply()
{
    QNetworkReply *r = m_geoReply;
    m_geoReply = 0;
    r->deleteLater();
    if (r->error() != QNetworkReply::NoError) {
        m_wStatus = Dil::t("Şehir aranamadı: ") + r->errorString();
        emit weatherChanged();
        return;
    }
    const QString s = QString::fromUtf8(r->readAll());
    QRegExp nameRx("\"name\":\"([^\"]*)\"");
    bool okLat = false, okLon = false;
    const double lat = jsonNum(s, "latitude", &okLat), lon = jsonNum(s, "longitude", &okLon);
    if (nameRx.indexIn(s) < 0 || !okLat || !okLon) {
        m_wStatus = Dil::t("Şehir bulunamadı");
        emit weatherChanged();
        return;
    }
    m_city = nameRx.cap(1);
    m_lat = lat;
    m_lon = lon;
    m_wcode = -1;
    m_wUpdated = QDateTime();
    saveSettings();
    log("sehir: " + m_city + " " + QString::number(lat) + "," + QString::number(lon));
    emit weatherChanged();
    fetchWeather(true);
}

// ================= Ayarlar =================

void Pil::loadSettings()
{
    QSettings s(m_dir + "/ayarlar.ini", QSettings::IniFormat);
    m_style = s.value("style3", "rows").toString();
    if (m_style != "wide" && m_style != "rows" && m_style != "small") m_style = "rows";
    m_fullAlert = s.value("fullAlert", true).toBool();
    m_lowAlert = s.value("lowAlert", 15).toInt();
    m_city = s.value("city").toString();
    m_lat = s.value("lat", 0).toDouble();
    m_lon = s.value("lon", 0).toDouble();
    if (s.contains("wCode")) {
        m_temp = s.value("wTemp").toDouble();
        m_wcode = s.value("wCode").toInt();
        m_isDay = s.value("wDay", true).toBool();
        m_wUpdated = s.value("wTime").toDateTime();
    }
}

void Pil::saveSettings()
{
    QSettings s(m_dir + "/ayarlar.ini", QSettings::IniFormat);
    s.setValue("style3", m_style);
    s.setValue("fullAlert", m_fullAlert);
    s.setValue("lowAlert", m_lowAlert);
    s.setValue("city", m_city);
    s.setValue("lat", m_lat);
    s.setValue("lon", m_lon);
}

void Pil::setStyle(const QString &st)
{
    // Yalnizca arayuzdeki onizlemenin turu (iki widget her zaman kayitli)
    if (st == m_style || (st != "wide" && st != "rows")) return;
    m_style = st;
    saveSettings();
    publish(true);
}

void Pil::setFullAlert(bool on) { m_fullAlert = on; saveSettings(); emit settingsChanged(); }
void Pil::setLowAlert(int p) { m_lowAlert = qBound(0, p, 50); saveSettings(); emit settingsChanged(); }

// ================= Cizim =================

static QColor levelColor(int level, int state)
{
    if (state == 2) return QColor("#5BC0EB");
    if (level <= 15) return QColor("#F15C6D");
    if (level <= 40) return QColor("#FFB300");
    return QColor("#4CD787");
}

static QColor loadColor(int pct)
{
    if (pct >= 85) return QColor("#F15C6D");
    if (pct >= 60) return QColor("#FFB300");
    return QColor("#5BC0EB");
}

static void drawWeatherIcon(QPainter &p, const QRectF &r, int code, bool day)
{
    const int k = weatherKind(code);
    p.save();
    p.setPen(Qt::NoPen);
    const qreal s = r.width();
    const QPointF c = r.center();
    if (k == 0 || k == 1) {
        if (day) {
            p.setBrush(QColor("#FFC233"));
            p.drawEllipse(QPointF(c.x() - (k ? s * 0.12 : 0), c.y() - (k ? s * 0.1 : 0)), s * 0.26, s * 0.26);
        } else {
            p.setBrush(QColor("#E0E6EC"));
            p.drawEllipse(QPointF(c.x() - s * 0.08, c.y() - s * 0.06), s * 0.24, s * 0.24);
            p.setBrush(QColor(16, 20, 24));
            p.drawEllipse(QPointF(c.x() + s * 0.02, c.y() - s * 0.14), s * 0.2, s * 0.2);
        }
    }
    if (k >= 1) {
        // bulut
        p.setBrush(k == 6 ? QColor("#7E8A96") : QColor("#D5DCE3"));
        p.drawEllipse(QPointF(c.x() - s * 0.16, c.y() + s * 0.06), s * 0.18, s * 0.16);
        p.drawEllipse(QPointF(c.x() + s * 0.04, c.y() - s * 0.02), s * 0.22, s * 0.22);
        p.drawEllipse(QPointF(c.x() + s * 0.22, c.y() + s * 0.08), s * 0.16, s * 0.14);
        p.drawRoundedRect(QRectF(c.x() - s * 0.32, c.y() + s * 0.04, s * 0.66, s * 0.18), s * 0.08, s * 0.08);
    }
    if (k == 3) {
        p.setPen(QPen(QColor("#AEB8C2"), 2));
        for (int i = 0; i < 3; ++i) p.drawLine(QPointF(r.left() + s * 0.12, c.y() + s * (0.3 + i * 0.1)), QPointF(r.right() - s * 0.12, c.y() + s * (0.3 + i * 0.1)));
    } else if (k == 4 || k == 6) {
        p.setPen(QPen(QColor("#5BC0EB"), 2));
        for (int i = -1; i <= 1; ++i) p.drawLine(QPointF(c.x() + i * s * 0.18, c.y() + s * 0.3), QPointF(c.x() + i * s * 0.18 - s * 0.06, c.y() + s * 0.44));
        if (k == 6) {
            QPolygonF b;
            b << QPointF(c.x() + s * 0.04, c.y() + s * 0.18) << QPointF(c.x() - s * 0.08, c.y() + s * 0.36)
              << QPointF(c.x(), c.y() + s * 0.36) << QPointF(c.x() - s * 0.06, c.y() + s * 0.5)
              << QPointF(c.x() + s * 0.1, c.y() + s * 0.3) << QPointF(c.x() + s * 0.02, c.y() + s * 0.3);
            p.setPen(Qt::NoPen);
            p.setBrush(QColor("#FFC233"));
            p.drawPolygon(b);
        }
    } else if (k == 5) {
        p.setBrush(Qt::white);
        for (int i = -1; i <= 1; ++i) p.drawEllipse(QPointF(c.x() + i * s * 0.18, c.y() + s * 0.38), s * 0.05, s * 0.05);
    }
    p.restore();
}

static void drawBar(QPainter &p, const QRectF &r, int pct, const QColor &c)
{
    p.setPen(Qt::NoPen);
    p.setBrush(QColor(255, 255, 255, 40));
    p.drawRoundedRect(r, 3, 3);
    if (pct < 0) return;
    p.setBrush(c);
    p.drawRoundedRect(QRectF(r.x(), r.y(), r.width() * qMax(0.03, pct / 100.0), r.height()), 3, 3);
}

// "wideimage" (312x82): pil | hava durumu | RAM / CPU
QImage Pil::drawWide() const
{
    QImage img(312, 82, QImage::Format_ARGB32);
    img.fill(0);
    QPainter p(&img);
    p.setRenderHint(QPainter::Antialiasing);
    p.setRenderHint(QPainter::TextAntialiasing);
    p.setPen(Qt::NoPen);
    p.setBrush(QColor(16, 20, 24, 210));
    p.drawRoundedRect(QRectF(1, 1, 310, 80), 12, 12);
    p.setPen(QColor(255, 255, 255, 30));
    p.drawLine(QPointF(100, 12), QPointF(100, 70));
    p.drawLine(QPointF(214, 12), QPointF(214, 70));

    QFont big("Nokia Sans"); big.setBold(true); big.setPixelSize(30);
    QFont mid("Nokia Sans"); mid.setBold(true); mid.setPixelSize(22);
    QFont small("Nokia Sans"); small.setPixelSize(13);

    // pil
    p.setFont(big);
    p.setPen(Qt::white);
    p.drawText(QRectF(4, 4, 92, 40), Qt::AlignCenter, QString::number(m_level) + "%");
    drawBar(p, QRectF(14, 46, 72, 8), m_level, levelColor(m_level, m_state));
    p.setFont(small);
    p.setPen(levelColor(m_level, m_state));
    p.drawText(QRectF(4, 58, 92, 18), Qt::AlignCenter, m_state == 2 ? Dil::t("Şarjda") : (m_state == 3 ? QString::fromUtf8("Dolu") : QString::fromUtf8("Pilde")));

    // hava
    if (m_wcode >= 0) {
        drawWeatherIcon(p, QRectF(104, 10, 40, 40), m_wcode, m_isDay);
        p.setFont(mid);
        p.setPen(Qt::white);
        p.drawText(QRectF(146, 10, 66, 40), Qt::AlignLeft | Qt::AlignVCenter, QString::number(qRound(m_temp)) + QString::fromUtf8("°"));
        p.setFont(small);
        p.setPen(QColor(200, 208, 216));
        p.drawText(QRectF(104, 52, 108, 22), Qt::AlignHCenter | Qt::AlignVCenter,
                   p.fontMetrics().elidedText(m_city.isEmpty() ? weatherDesc(m_wcode) : m_city, Qt::ElideRight, 106));
    } else {
        p.setFont(small);
        p.setPen(QColor(160, 170, 180));
        p.drawText(QRectF(104, 10, 108, 62), Qt::AlignCenter | Qt::TextWordWrap,
                   m_city.isEmpty() ? Dil::t("Şehir seçin") : Dil::t("Hava bekleniyor"));
    }

    // RAM / CPU
    p.setFont(small);
    p.setPen(QColor(220, 226, 232));
    p.drawText(QRectF(222, 10, 50, 16), Qt::AlignLeft | Qt::AlignVCenter, "RAM");
    p.drawText(QRectF(254, 10, 50, 16), Qt::AlignRight | Qt::AlignVCenter, m_ramPct >= 0 ? QString::number(m_ramPct) + "%" : "-");
    drawBar(p, QRectF(222, 28, 82, 7), m_ramPct, loadColor(m_ramPct));
    p.drawText(QRectF(222, 42, 50, 16), Qt::AlignLeft | Qt::AlignVCenter, "CPU");
    p.drawText(QRectF(254, 42, 50, 16), Qt::AlignRight | Qt::AlignVCenter, m_cpuPct >= 0 ? QString::number(m_cpuPct) + "%" : "-");
    drawBar(p, QRectF(222, 60, 82, 7), m_cpuPct, loadColor(m_cpuPct));
    return img;
}

// 70x70: buyuk pil yuzdesi ve doluluk cubugu ("threerows" sablonunun resmi)
QImage Pil::drawIcon() const
{
    QImage img(70, 70, QImage::Format_ARGB32);
    img.fill(0);
    QPainter p(&img);
    p.setRenderHint(QPainter::Antialiasing);
    p.setRenderHint(QPainter::TextAntialiasing);
    const QColor c = levelColor(m_level, m_state);
    p.setPen(Qt::NoPen);
    p.setBrush(QColor(16, 20, 24, 220));
    p.drawRoundedRect(QRectF(1, 1, 68, 68), 12, 12);
    drawBar(p, QRectF(8, 54, 54, 8), m_level, c);
    QFont f("Nokia Sans");
    f.setBold(true);
    f.setPixelSize(m_level >= 100 ? 24 : 28);
    p.setFont(f);
    p.setPen(Qt::white);
    p.drawText(QRectF(0, 6, 70, 44), Qt::AlignCenter, QString::number(m_level) + "%");
    if (m_state == 2 || m_state == 3) {
        QPolygonF b;
        b << QPointF(62, 3) << QPointF(55, 15) << QPointF(60, 15) << QPointF(57, 25) << QPointF(66, 11) << QPointF(61, 11);
        p.setPen(QPen(QColor(16, 20, 24), 1));
        p.setBrush(QColor("#FFB300"));
        p.drawPolygon(b);
    }
    return img;
}

// ================= Widget (HSWidgetPlugin.dll) =================
//
// 1.4'e kadarki cokme: icerik, ana ekran widget'i etkinlestirmeden ve uygulamanin olay dongusu daha
// baslamadan gonderiliyordu; Nokia DLL'i hata firlatiyor, bizim (GCCE) kodumuz yakalayamiyordu.
// Simdi: widget'lar yalnizca kaydedilir; icerik EActivate/EResume geldikten sonra, olay dongusu icinden
// (kuyruga alinarak) gonderilir. Iki sabit kimlik: <UID>_satir ve <UID>_genis.

// Ana ekranda gorunen adlar (kimlikler degismedi: eski BelleWidgets widget'lari yerinde kalir)
static const char *KWNames[2] = { "BelleWidgets", "BelleWidgets genis" };
static const char *KWIds[2] = { "_satir", "_genis" };

void Pil::initWidget()
{
#ifdef Q_OS_SYMBIAN
    if (m_widgetReady) return;
    for (int i = 0; i < 2; ++i) {
        if (m_w[i]) continue;
        log(QString("widget: kaydediliyor ") + KWNames[i]);
        m_w[i] = new CHomeScreenWidget(i == 0 ? NHomeScreenWidget::TYPE_TWO_ROWS : NHomeScreenWidget::TYPE_WIDE_IMAGE,
                                       KWNames[i], QString(TARGETUID3) + KWIds[i], this);
        if (!m_w[i]->hsWidget()) {
            log("widget: kutuphane yuklenemedi");
            delete m_w[i];
            m_w[i] = 0;
            m_widgetStatus = Dil::t("Widget kütüphanesi yüklenemedi (HSWidgetPlugin)");
            emit widgetChanged();
            return;
        }
        connect(m_w[i], SIGNAL(widgetEvent(QHSEvent)), this, SLOT(onWidgetEvent(QHSEvent)));
        connect(m_w[i], SIGNAL(widgetItemEvent(QString,QHSItemEvent)), this, SLOT(onWidgetItemEvent(QString,QHSItemEvent)));
    }
    m_widgetReady = true;
    log("widget: iki widget kayitli");
    m_widgetStatus = Dil::t("Hazır • ana ekrana ekleyin: \"BelleWidgets\" ya da \"BelleWidgets genis\"");
#else
    m_widgetStatus = Dil::t("Masaüstü/Simulator: widget yok, önizleme gösteriliyor");
#endif
    emit widgetChanged();
    publish(true);   // yalnizca onizleme; etkin widget yoksa ana ekrana bir sey gitmez
}

// Ana ekrana gonderimi her zaman olay dongusune birakir
void Pil::publish(bool force)
{
    if (force) { m_wKey[0].clear(); m_wKey[1].clear(); }
    // Onizleme (yalnizca arayuz aciksa)
    if (m_uiOpen || force) {
        m_imageFlip = 1 - m_imageFlip;
        m_lastImage = m_dir + "/onizleme" + QString::number(m_imageFlip) + ".png";
        (m_style == "wide" ? drawWide() : drawIcon()).save(m_lastImage, "PNG");
        emit widgetChanged();
    }
    if (!m_publishPending) {
        m_publishPending = true;
        QTimer::singleShot(0, this, SLOT(publishQueued()));
    }
}

void Pil::publishQueued()
{
    m_publishPending = false;
    publishOne(0, false);
    publishOne(1, false);
}

void Pil::publishOne(int i, bool force)
{
    if (!m_w[i] || !m_wActive[i] || m_wSusp[i]) return;
    // RAM/CPU 5'lik adimlarla karsilastirilir: kucuk oynamalarda yeniden cizim / yayin yok
    const QString key = QString::number(m_level) + "_" + QString::number(m_state) + m_estimate
                        + QString::number(m_ramPct / 5) + "_" + QString::number(m_cpuPct / 5)
                        + weatherLine() + QString::number(m_isDay);
    if (!force && key == m_wKey[i]) return;
    m_wKey[i] = key;
    if (i == 1) {
        m_w[1]->setItem(NHomeScreenWidget::ITEM_IMAGE1, drawWide());
    } else {
        const QString sys = "RAM %" + (m_ramPct >= 0 ? QString::number(m_ramPct) : QString("-"))
                            + (m_cpuPct >= 0 ? " CPU %" + QString::number(m_cpuPct) : QString());
        QString batt = stateText();
        if (m_state != 3 && !m_estimate.startsWith(QString::fromUtf8("Hesap"))) batt += " " + m_estimate;
        m_w[0]->setItem(NHomeScreenWidget::ITEM_IMAGE1, drawIcon());
        m_w[0]->setItem(NHomeScreenWidget::ITEM_TEXT1, ascii(batt + " | " + sys));
        m_w[0]->setItem(NHomeScreenWidget::ITEM_TEXT2, ascii(weatherLine()));
    }
    m_w[i]->publish();
}

void Pil::republish()
{
    publish(true);
}

void Pil::retryWidget()
{
    m_widgetReady = false;
    initWidget();
}

void Pil::removeWidget()
{
}

// Her sey: pil, RAM/CPU, hava (10 dk'dan eskiyse ya da elle), widget'lar
void Pil::refreshAll()
{
    requestFine();
    refresh();
    sampleSys();
    if (!m_city.isEmpty() && (m_wUpdated.isNull() || m_forecast.isEmpty() || m_wUpdated.secsTo(QDateTime::currentDateTime()) > 10 * 60))
        refreshWeather();
    publish(true);
}

void Pil::onWidgetItemEvent(QString, QHSItemEvent ev)
{
    if (ev == ESelect) {
        log("widget'a dokunuldu");
        refreshAll();
        emit openRequested();
    }
}

void Pil::onWidgetEvent(QHSEvent ev)
{
    int i = sender() == m_w[1] ? 1 : 0;
    switch (ev) {
    case EActivate: case EResume: m_wActive[i] = true; m_wSusp[i] = false; break;
    case EDeactivate: m_wActive[i] = false; break;
    case ESuspend: m_wSusp[i] = true; break;
    default: break;
    }
    const bool any = (m_wActive[0] && !m_wSusp[0]) || (m_wActive[1] && !m_wSusp[1]);
    m_widgetStatus = (m_wActive[0] || m_wActive[1]) ? Dil::t("Ana ekranda") + (any ? "" : Dil::t(" (askıda)"))
                                                    : Dil::t("Hazır • ana ekrana ekleyin");
    updateLiveTimer();
    emit widgetChanged();
    if (ev == EActivate || ev == EResume) {
        requestFine();
        readBattery();
        computeEstimate();
        emit changed();
        m_wKey[i].clear();
        publish(false);
    }
}

void Pil::vibrate(int ms)
{
#ifdef Q_OS_SYMBIAN
    static CHWRMVibra *v = 0;
    TInt err = KErrNone;
    if (!v) TRAP(err, v = CHWRMVibra::NewL());
    if (err == KErrNone && v) TRAP(err, v->StartVibraL(ms));
#else
    Q_UNUSED(ms);
#endif
}

void Pil::quitApp()
{
    log("kapatildi");
    QApplication::quit();
}

// ================= Ekran (istege bagli arayuz) =================

Ekran::Ekran(Pil *pil, QObject *parent)
    : QObject(parent), m_pil(pil), m_view(0), m_hiding(false)
{
    connect(pil, SIGNAL(openRequested()), this, SLOT(show()));
    qApp->installEventFilter(this);
}

bool Ekran::eventFilter(QObject *o, QEvent *e)
{
    if (o == qApp && e->type() == QEvent::ApplicationActivate && !m_view && !m_hiding
        && (m_quietUntil.isNull() || QDateTime::currentDateTime() > m_quietUntil))
        QTimer::singleShot(0, this, SLOT(show()));
    return QObject::eventFilter(o, e);
}

void Ekran::show()
{
    m_hiding = false;
    if (!m_view) {
        m_pil->log("arayuz olusturuluyor");
        m_pil->setUiOpen(true);
        // Veriler olay dongusu icinden tazelenir (acilista dogrudan cagri cokmeye yol aciyordu)
        QTimer::singleShot(0, m_pil, SLOT(refreshAll()));
        m_view = new QDeclarativeView;
        m_view->setResizeMode(QDeclarativeView::SizeRootObjectToView);
        m_view->setAttribute(Qt::WA_OpaquePaintEvent);
        m_view->setAttribute(Qt::WA_NoSystemBackground);
        m_view->viewport()->setAttribute(Qt::WA_OpaquePaintEvent);
        m_view->viewport()->setAttribute(Qt::WA_NoSystemBackground);
        m_view->rootContext()->setContextProperty("pil", m_pil);
        static Pano belPano; m_view->rootContext()->setContextProperty("pano", &belPano);   // Ctrl+V (kutuphane/pano)
        m_view->rootContext()->setContextProperty("ui", this);
    m_view->rootContext()->setContextProperty("dil", Dil::tek());
        m_view->setSource(QUrl("qrc:/qml/main.qml"));
    }
#if defined(Q_OS_SYMBIAN)
    m_view->showFullScreen();
    TApaTask t(CCoeEnv::Static()->WsSession());
    t.SetWgId(CCoeEnv::Static()->RootWin().Identifier());
    t.BringToForeground();
#else
    m_view->resize(640, 480);
    m_view->show();
#endif
}

void Ekran::hide()
{
    m_hiding = true;
#ifdef Q_OS_SYMBIAN
    TApaTask t(CCoeEnv::Static()->WsSession());
    t.SetWgId(CCoeEnv::Static()->RootWin().Identifier());
    t.SendToBackground();
#endif
    QTimer::singleShot(400, this, SLOT(destroyView()));
}

void Ekran::destroyView()
{
    if (m_view) {
        m_view->hide();
        m_view->deleteLater();
        m_view = 0;
        m_pil->setUiOpen(false);
        m_pil->log("arayuz kapatildi (arka planda)");
    }
    m_hiding = false;
}