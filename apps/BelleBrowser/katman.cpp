#include "katman.h"
#include "depo.h"
#include "dil.h"
#include "belleserver.h"

#include <QtCore/QSettings>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QDataStream>
#include <QtCore/QDateTime>
#include <QtCore/QTimer>
#include <QtCore/QStringList>
#include <QtNetwork/QNetworkCookie>
#include <QtNetwork/QNetworkDiskCache>
#include <QtNetwork/QSslError>

static QSettings &ayarDosya() { static QSettings s("BelleBrowser", "Ayar"); return s; }

static QString veriKlasoru()
{
#if defined(Q_OS_SYMBIAN)
    const QString d = Depo::yol("BelleBrowser");
#else
    const QString d = QDir::homePath() + "/BelleBrowser";
#endif
    QDir().mkpath(d);
    return d;
}

KatmanAyar &KatmanAyar::al()
{
    static KatmanAyar a;
    static bool ilk = true;
    if (ilk) { ilk = false; a.orijinal = a.giden = 0; a.yukle(); }
    return a;
}

void KatmanAyar::yukle()
{
    QSettings &s = ayarDosya();
    sunucu = belleServer();
    anahtar = s.value("anahtar").toString();
    mod = s.value("mod", "akilli").toString();
    ua = s.value("ua", "mobil").toString();
    resimW = s.value("resimW", 640).toInt();
    resimQ = s.value("resimQ", 8).toInt();
    reklam = s.value("reklam", true).toBool();
    sertifikaYoksay = s.value("sertifikaYoksay", false).toBool();
}

void KatmanAyar::kaydet() const
{
    QSettings &s = ayarDosya();
    s.setValue("anahtar", anahtar);
    s.setValue("mod", mod);
    s.setValue("ua", ua);
    s.setValue("resimW", resimW);
    s.setValue("resimQ", resimQ);
    s.setValue("reklam", reklam);
    s.setValue("sertifikaYoksay", sertifikaYoksay);
    s.sync();
}

// Mobil kimlik: eski Android tarayicisi -> siteler eski WebKit'in calistirabilecegi hafif sayfayi gonderir
QString KatmanAyar::uaMetni() const
{
    if (ua == "masa") return "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/534.34 (KHTML, like Gecko) Chrome/19.0 Safari/534.34";
    if (ua == "modern") return "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36";
    return "Mozilla/5.0 (Linux; U; Android 4.0.4; tr-tr; Nokia E6) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30";
}

// ---------------- kalici cerezler ----------------

KaliciCerez::KaliciCerez(QObject *parent) : QNetworkCookieJar(parent), m_degisen(0)
{
    QFile f(dosya());
    if (f.open(QIODevice::ReadOnly)) {
        QList<QNetworkCookie> l;
        const QDateTime simdi = QDateTime::currentDateTime();
        foreach (const QByteArray &satir, f.readAll().split('\n')) {
            if (satir.isEmpty()) continue;
            const QList<QNetworkCookie> c = QNetworkCookie::parseCookies(satir);
            foreach (const QNetworkCookie &k, c) if (!k.isSessionCookie() && k.expirationDate() > simdi) l << k;
        }
        setAllCookies(l);
    }
}

KaliciCerez::~KaliciCerez() { kaydet(); }

QString KaliciCerez::dosya() const { return veriKlasoru() + "/cerezler.txt"; }

bool KaliciCerez::setCookiesFromUrl(const QList<QNetworkCookie> &cookies, const QUrl &url)
{
    const bool r = QNetworkCookieJar::setCookiesFromUrl(cookies, url);
    if (r && ++m_degisen >= 10) kaydet();
    return r;
}

void KaliciCerez::kaydet()
{
    m_degisen = 0;
    QFile f(dosya());
    if (!f.open(QIODevice::WriteOnly)) return;
    foreach (const QNetworkCookie &c, allCookies()) {
        if (c.isSessionCookie()) continue;
        f.write(c.toRawForm(QNetworkCookie::Full));
        f.write("\n");
    }
}

void KaliciCerez::temizle() { setAllCookies(QList<QNetworkCookie>()); kaydet(); }

KaliciCerez *KaliciCerez::ortak()
{
    static KaliciCerez *c = 0;
    if (!c) c = new KaliciCerez(0);
    return c;
}

// ---------------- ag yoneticisi ----------------

static const char *KReklam[] = {
    "doubleclick.net", "googlesyndication.com", "googleadservices.com", "google-analytics.com", "googletagmanager.com",
    "googletagservices.com", "adservice.google.com", "adnxs.com", "adsrvr.org", "taboola.com", "outbrain.com",
    "criteo.com", "criteo.net", "scorecardresearch.com", "facebook.net", "amazon-adsystem.com", "rubiconproject.com",
    "pubmatic.com", "openx.net", "smartadserver.com", "yandex.ru/ads", "mc.yandex.ru", "adform.net", "teads.tv",
    "hotjar.com", "quantserve.com", "moatads.com", "admatic.com.tr", "adhood.com", "popads.net", "propellerads.com",
    "onesignal.com", "chartbeat.com", "yieldlove.com", "33across.com", 0 };

bool KatmanNam::reklamMi(const QString &hostIn)
{
    const QString host = hostIn.toLower();
    for (int i = 0; KReklam[i]; ++i) {
        const QString a = QString::fromLatin1(KReklam[i]);
        if (host == a || host.endsWith("." + a)) return true;
    }
    return false;
}

KatmanNam::KatmanNam(QObject *parent) : QNetworkAccessManager(parent)
{
    setCookieJar(KaliciCerez::ortak());
    KaliciCerez::ortak()->setParent(0);          // birden cok yonetici ayni kavanozu paylasir
    static bool onbellekVerildi = false;
    if (!onbellekVerildi) {
        onbellekVerildi = true;
        QNetworkDiskCache *c = new QNetworkDiskCache(this);
        c->setCacheDirectory(veriKlasoru() + "/onbellek");
        c->setMaximumCacheSize(24 * 1024 * 1024);
        setCache(c);
    }
    connect(this, SIGNAL(sslErrors(QNetworkReply*,QList<QSslError>)), this, SLOT(sslHata(QNetworkReply*,QList<QSslError>)));
}

void KatmanNam::sslHata(QNetworkReply *r, const QList<QSslError> &)
{
    if (KatmanAyar::al().sertifikaYoksay) r->ignoreSslErrors();
}

static bool resimMi(const QNetworkRequest &req)
{
    const QByteArray acc = req.rawHeader("Accept");
    if (acc.startsWith("image/")) return true;
    const QString p = req.url().path().toLower();
    return p.endsWith(".jpg") || p.endsWith(".jpeg") || p.endsWith(".png") || p.endsWith(".webp") || p.endsWith(".avif") || p.endsWith(".bmp");
}

QNetworkReply *KatmanNam::createRequest(Operation op, const QNetworkRequest &reqIn, QIODevice *data)
{
    const QUrl u = reqIn.url();
    const QString sema = u.scheme().toLower();
    if (sema != "http" && sema != "https") return QNetworkAccessManager::createRequest(op, reqIn, data);
    KatmanAyar &a = KatmanAyar::al();
    if (a.reklam && reklamMi(u.host())) return new BosYanit(reqIn, op, this);

    QNetworkRequest req(reqIn);
    req.setRawHeader("User-Agent", a.uaMetni().toLatin1());
    if (!req.hasRawHeader("Accept-Language")) req.setRawHeader("Accept-Language", "tr-TR,tr;q=0.9,en;q=0.6");

    const QUrl sunucu(a.sunucu);
    const bool sunucuyaZaten = u.host() == sunucu.host();
    const bool vekil = !sunucuyaZaten && !a.anahtar.isEmpty()
            && (a.mod == "sikistir" || (a.mod == "akilli" && sema == "https"));
    if (!vekil) {
        if (sunucuyaZaten && !a.anahtar.isEmpty()) req.setRawHeader("X-Api-Key", a.anahtar.toUtf8()); req.setRawHeader("X-Lang", Dil::kodu());
        return QNetworkAccessManager::createRequest(op, req, data);
    }

    QUrl vu(a.sunucu + "/tb/g");
    vu.addEncodedQueryItem("u", QUrl::toPercentEncoding(QString::fromLatin1(u.toEncoded())));
    if (resimMi(reqIn)) {
        vu.addQueryItem("img", "1");
        if (a.mod == "sikistir") { vu.addQueryItem("w", QString::number(a.resimW)); vu.addQueryItem("q", QString::number(a.resimQ)); }
        else { vu.addQueryItem("w", "1280"); vu.addQueryItem("q", "4"); }
    }
    QNetworkRequest vr(vu);
    foreach (const QByteArray &h, req.rawHeaderList()) vr.setRawHeader(h, req.rawHeader(h));
    // cerezler: WebKit kavanozdan asil adres icin ekler; yoksa biz ekleyelim
    if (!vr.hasRawHeader("Cookie")) {
        const QList<QNetworkCookie> c = cookieJar()->cookiesForUrl(u);
        if (!c.isEmpty()) {
            QByteArray s;
            foreach (const QNetworkCookie &k, c) { if (!s.isEmpty()) s += "; "; s += k.toRawForm(QNetworkCookie::NameAndValueOnly); }
            vr.setRawHeader("Cookie", s);
        }
    }
    vr.setRawHeader("X-Api-Key", a.anahtar.toUtf8()); vr.setRawHeader("X-Lang", Dil::kodu());
    if (a.ua != "mobil") vr.setRawHeader("X-Belle-UA", a.ua.toLatin1());
    vr.setAttribute(QNetworkRequest::CacheLoadControlAttribute, reqIn.attribute(QNetworkRequest::CacheLoadControlAttribute));
    QNetworkReply *ic = QNetworkAccessManager::createRequest(op, vr, data);
    return new VekilYanit(ic, reqIn, op, this);
}

// ---------------- vekil yanit ----------------

VekilYanit::VekilYanit(QNetworkReply *ic, const QNetworkRequest &asil, QNetworkAccessManager::Operation op, QNetworkAccessManager *nam)
    : QNetworkReply(nam), m_ic(ic), m_nam(nam), m_meta(false)
{
    setRequest(asil);
    setUrl(asil.url());
    setOperation(op);
    open(QIODevice::ReadOnly | QIODevice::Unbuffered);
    ic->setParent(this);
    connect(ic, SIGNAL(metaDataChanged()), this, SLOT(meta()));
    connect(ic, SIGNAL(readyRead()), this, SLOT(hazir()));
    connect(ic, SIGNAL(finished()), this, SLOT(bitti()));
    connect(ic, SIGNAL(error(QNetworkReply::NetworkError)), this, SLOT(hata(QNetworkReply::NetworkError)));
    connect(ic, SIGNAL(downloadProgress(qint64,qint64)), this, SLOT(inis(qint64,qint64)));
    connect(ic, SIGNAL(uploadProgress(qint64,qint64)), this, SLOT(yukleme(qint64,qint64)));
}

VekilYanit::~VekilYanit() {}

void VekilYanit::abort() { if (m_ic) m_ic->abort(); }

qint64 VekilYanit::bytesAvailable() const { return QNetworkReply::bytesAvailable() + (m_ic ? m_ic->bytesAvailable() : 0); }

qint64 VekilYanit::readData(char *data, qint64 maxlen)
{
    if (!m_ic) return -1;
    const qint64 n = m_ic->read(data, maxlen);
    if (n > 0) KatmanAyar::al().giden += n;
    return n;
}

void VekilYanit::meta()
{
    if (!m_ic || m_meta) return;
    m_meta = true;
    const int kod = m_ic->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    setAttribute(QNetworkRequest::HttpStatusCodeAttribute, kod);
    setAttribute(QNetworkRequest::HttpReasonPhraseAttribute, m_ic->attribute(QNetworkRequest::HttpReasonPhraseAttribute));
    foreach (const QNetworkReply::RawHeaderPair &h, m_ic->rawHeaderPairs()) {
        const QByteArray ad = h.first.toLower();
        if (ad == "set-cookie") {
            QList<QNetworkCookie> c;
            foreach (const QByteArray &s, h.second.split('\n')) c << QNetworkCookie::parseCookies(s);
            if (!c.isEmpty() && m_nam->cookieJar()) m_nam->cookieJar()->setCookiesFromUrl(c, url());
            continue;
        }
        if (ad == "x-belle-orijinal") { KatmanAyar::al().orijinal += h.second.toLongLong(); continue; }
        if (ad.startsWith("x-belle") || ad == "transfer-encoding" || ad == "connection" || ad == "content-encoding" || ad == "content-length") continue;
        setRawHeader(h.first, h.second);
    }
    const QByteArray konum = m_ic->rawHeader("Location");
    if (!konum.isEmpty() && kod >= 300 && kod < 400)
        setAttribute(QNetworkRequest::RedirectionTargetAttribute, url().resolved(QUrl::fromEncoded(konum)));
    emit metaDataChanged();
}

void VekilYanit::hazir() { if (!m_meta) meta(); emit readyRead(); }

void VekilYanit::bitti()
{
    if (!m_meta) meta();
    if (m_ic && m_ic->rawHeader("X-Belle-Orijinal").isEmpty()) KatmanAyar::al().orijinal += m_ic->size() + m_ic->bytesAvailable();
    emit finished();
}

void VekilYanit::hata(QNetworkReply::NetworkError e)
{
    if (!m_ic) return;
    // HTTP hata kodlari (404, 500...) sayfanin kendisidir: WebKit sayfayi gostersin
    const int kod = m_ic->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (kod >= 400 && e >= QNetworkReply::ContentAccessDenied) return;
    setError(e, m_ic->errorString());
    emit error(e);
}

// ---------------- bos yanit ----------------

BosYanit::BosYanit(const QNetworkRequest &req, QNetworkAccessManager::Operation op, QObject *parent) : QNetworkReply(parent)
{
    setRequest(req);
    setUrl(req.url());
    setOperation(op);
    open(QIODevice::ReadOnly);
    setError(QNetworkReply::ContentAccessDenied, "Reklam engellendi");
    QTimer::singleShot(0, this, SLOT(bitir()));
}

void BosYanit::bitir()
{
    emit error(QNetworkReply::ContentAccessDenied);
    emit finished();
}

QNetworkAccessManager *KatmanNamFactory::create(QObject *parent) { return new KatmanNam(parent); }
