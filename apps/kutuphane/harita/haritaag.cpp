#include "rotacizgi.h"
#include "depo.h"
#include "haritaag.h"
#include "cevrimdisi.h"
#include "karoyukleyici.h"
#include <QtDeclarative/QDeclarativeContext>

#include <QtCore/QDir>
#include <QtCore/QDirIterator>
#include <QtCore/QFileInfo>
#include <QtCore/QFile>
#include <QtCore/QThread>
#include <QtCore/QRegExp>
#include <QtNetwork/QNetworkRequest>
#include <QtDeclarative/QDeclarativeEngine>
#include <cstring>

static const qint64 KOnbellekEnCok = 120LL * 1024 * 1024;   // asilirsa (acilista) karo onbellegi bastan kurulur

static QString veriKoku()
{
#if defined(Q_OS_SYMBIAN)
    return Depo::yol("BelleHarita");
#else
    return QDir::homePath() + "/BelleHarita";
#endif
}

QString HaritaNam::onbellekKlasoru() { return veriKoku() + "/karolar"; }

QString HaritaNam::karoDosyasi(const QUrl &u)
{
    QString yol = u.path();
    yol.replace(QRegExp("[^A-Za-z0-9_./-]"), "_");
    if (yol.contains("..")) yol.replace("..", "_");
    return onbellekKlasoru() + "/" + u.host() + yol + ".k";
}

bool HaritaNam::karoMu(const QUrl &u)
{
    const QString h = u.host();
    return h.endsWith("tile.openstreetmap.org") || h.endsWith("tile.opentopomap.org") ||
           (h == "server.arcgisonline.com" && u.path().contains("/MapServer/tile/"));
}

HaritaNam::HaritaNam(QObject *parent) : QNetworkAccessManager(parent) {}

QNetworkReply *HaritaNam::createRequest(Operation op, const QNetworkRequest &reqIn, QIODevice *data)
{
    QNetworkRequest req(reqIn);
    // diger istekler (API, arama, rota) onbellege hic girmez
    req.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::AlwaysNetwork);
    req.setAttribute(QNetworkRequest::CacheSaveControlAttribute, false);
    if (op == GetOperation && karoMu(req.url())) {
        // cevrimdisi indirilmis alan ya da daha once bakilmis karo: dosyadan (internet gerekmez)
        const QString yerel = Cevrimdisi::dosyaYolu(req.url());
        if (QFile::exists(yerel)) return QNetworkAccessManager::createRequest(op, QNetworkRequest(QUrl::fromLocalFile(yerel)), data);
        const QString onb = karoDosyasi(req.url());
        if (QFile::exists(onb)) return QNetworkAccessManager::createRequest(op, QNetworkRequest(QUrl::fromLocalFile(onb)), data);
        // OSM karo kullanim kurali: uygulamayi tanitan User-Agent zorunlu
        req.setRawHeader("User-Agent", "BelleMaps/1.2 (Nokia E6 Symbian; Qt 4.8; kisisel kullanim)");
        return new KaroYanit(QNetworkAccessManager::createRequest(op, req, data), onb, this);
    }
    return QNetworkAccessManager::createRequest(op, req, data);
}

// ---------------- KaroYanit ----------------
KaroYanit::KaroYanit(QNetworkReply *ic, const QString &dosya, QObject *parent)
    : QNetworkReply(parent), m_ic(ic), m_kon(0), m_dosya(dosya), m_bitti(false)
{
    setRequest(ic->request());
    setUrl(ic->url());
    setOperation(QNetworkAccessManager::GetOperation);
    open(QIODevice::ReadOnly | QIODevice::Unbuffered);
    connect(m_ic, SIGNAL(finished()), this, SLOT(bitti()));
    connect(m_ic, SIGNAL(downloadProgress(qint64,qint64)), this, SIGNAL(downloadProgress(qint64,qint64)));
}

KaroYanit::~KaroYanit() { if (m_ic) { m_ic->disconnect(this); m_ic->deleteLater(); } }

void KaroYanit::abort() { if (m_ic) m_ic->abort(); }

qint64 KaroYanit::bytesAvailable() const { return (m_veri.size() - m_kon) + QIODevice::bytesAvailable(); }

qint64 KaroYanit::readData(char *veri, qint64 en)
{
    const qint64 k = qMin(en, qint64(m_veri.size()) - m_kon);
    if (k <= 0) return m_bitti ? -1 : 0;
    memcpy(veri, m_veri.constData() + m_kon, size_t(k));
    m_kon += k;
    return k;
}

static bool resimMi(const QByteArray &b)
{
    return b.size() > 100 && (b.startsWith("\x89PNG") || b.startsWith("\xFF\xD8"));
}

void KaroYanit::bitti()
{
    QNetworkReply *ic = m_ic;
    m_ic = 0;
    m_veri = ic->readAll();
    const QVariant durum = ic->attribute(QNetworkRequest::HttpStatusCodeAttribute);
    setAttribute(QNetworkRequest::HttpStatusCodeAttribute, durum);
    setAttribute(QNetworkRequest::HttpReasonPhraseAttribute, ic->attribute(QNetworkRequest::HttpReasonPhraseAttribute));
    setAttribute(QNetworkRequest::RedirectionTargetAttribute, ic->attribute(QNetworkRequest::RedirectionTargetAttribute));
    setHeader(QNetworkRequest::ContentTypeHeader, ic->header(QNetworkRequest::ContentTypeHeader));
    setHeader(QNetworkRequest::ContentLengthHeader, m_veri.size());
    const QNetworkReply::NetworkError hata = ic->error();
    const QString hataMetni = ic->errorString();
    ic->deleteLater();
    if (hata == QNetworkReply::NoError && durum.toInt() == 200 && resimMi(m_veri)) {
        // gecici dosyaya yaz, sonra yeniden adlandir (yarim dosya kalmasin)
        QDir().mkpath(QFileInfo(m_dosya).absolutePath());
        QFile f(m_dosya + ".t");
        if (f.open(QIODevice::WriteOnly)) {
            const bool ok = f.write(m_veri) == m_veri.size();
            f.close();
            if (ok) { QFile::remove(m_dosya); f.rename(m_dosya); } else f.remove();
        }
    }
    if (hata != QNetworkReply::NoError) setError(hata, hataMetni);
    m_bitti = true;
    emit metaDataChanged();
    if (hata != QNetworkReply::NoError) emit error(hata);
    if (!m_veri.isEmpty()) emit readyRead();
    emit finished();
}

// ---------------- bakim (arka plan) ----------------
// Eski QNetworkDiskCache klasorunu siler; yeni onbellek siniri astiysa bastan kurar. Klasor bellege listelenmez.
class OnbellekBakim : public QThread
{
public:
    void run()
    {
        const QString eski = veriKoku() + "/onbellek";
        if (QDir(eski).exists()) {
            QDirIterator it(eski, QDir::Files, QDirIterator::Subdirectories);
            while (it.hasNext()) QFile::remove(it.next());
        }
        if (HaritaAg::onbellekBoyutu() > KOnbellekEnCok) HaritaAg::onbellekSil();
    }
};

void HaritaAg::kur(QDeclarativeEngine *engine)
{
    static HaritaAg fabrika;
    engine->setNetworkAccessManagerFactory(&fabrika);
    RotaCizgi::kaydet();                  // Harita.qml: import BelleMaps 1.0 (RotaCizgi)
    engine->rootContext()->setContextProperty("karoYukleyici", KaroYukleyici::tek());   // karolari C++ indirir
    static OnbellekBakim *bakim = 0;
    if (!bakim) { bakim = new OnbellekBakim; bakim->start(QThread::LowestPriority); }
}

qint64 HaritaAg::onbellekBoyutu()
{
    qint64 t = 0;
    QDirIterator it(HaritaNam::onbellekKlasoru(), QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) { it.next(); t += it.fileInfo().size(); }
    return t;
}

void HaritaAg::onbellekSil()
{
    QDirIterator it(HaritaNam::onbellekKlasoru(), QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) QFile::remove(it.next());
}
