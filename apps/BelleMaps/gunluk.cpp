#include "gunluk.h"
#include "dil.h"
#include <QtCore/QFile>
#include <QtCore/QDir>
#include <QtCore/QDateTime>
#include <QtCore/QUrl>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkRequest>
#include <QtNetwork/QNetworkReply>
#include <cstdio>
#ifdef Q_OS_SYMBIAN
#include <e32std.h>
#include <hal.h>
#endif

static QString gDosya, gKlasor;
static int gSertifika = 0, gDns = 0;

static void yaz(const QString &satir)
{
    if (gDosya.isEmpty()) return;
    QFile g(gDosya);
    if (g.size() > 256 * 1024) {                       // devret: son ~256 KB eski dosyada kalir
        QFile::remove(gKlasor + "/gunluk_eski.txt");
        g.rename(gKlasor + "/gunluk_eski.txt");
        g.setFileName(gDosya);
    }
    if (g.open(QIODevice::Append)) {
        g.write((QDateTime::currentDateTime().toString("dd.MM hh:mm:ss ") + satir + "\n").toUtf8());
        g.close();                                     // her satir diske: cokmede kaybolmaz
    }
}

static void mesajYakala(QtMsgType tur, const char *m)
{
    fprintf(stderr, "%s\n", m);
    const QString s = QString::fromUtf8(m);
    // zararsiz tekrarlar: ilk ikisi yazilir, sonra her 50'de bir ozet
    if (s.startsWith("CSymbianCertificateRetriever")) { if (++gSertifika > 2 && gSertifika % 50) return; }
    else if (s.contains("received hostInfo for wrong lookup ID")) { if (++gDns > 2 && gDns % 50) return; }
    yaz((tur == QtDebugMsg ? QString() : (tur == QtFatalMsg ? QString("OLUMCUL ") : QString("UYARI "))) + s);
}

void Gunluk::kur(const QString &klasor)
{
    gKlasor = klasor;
    gDosya = klasor + "/gunluk.txt";
    qInstallMsgHandler(mesajYakala);
}

Gunluk::Gunluk(const QString &klasor, const QString &surum, QObject *parent)
    : QObject(parent), m_klasor(klasor), m_surum(surum), m_cokme(false), m_nam(0)
{
    // Onceki calisma duzgun kapanmadiysa isaret dosyasi durur
    QFile is(m_klasor + "/acik.isaret");
    if (is.exists()) {
        m_cokme = true;
        if (is.open(QIODevice::ReadOnly)) { m_oncekiBas = QString::fromUtf8(is.readAll()).trimmed(); is.close(); }
        QFile b(m_klasor + "/rapor.bekliyor");
        if (b.open(QIODevice::WriteOnly)) { b.write(m_oncekiBas.toUtf8()); b.close(); }
        yaz("ONCEKI CALISMA COKTU (baslangic: " + m_oncekiBas + ")");
    }
    if (is.open(QIODevice::WriteOnly)) { is.write(QDateTime::currentDateTime().toString("dd.MM.yyyy hh:mm:ss").toUtf8()); is.close(); }
    connect(&m_bellek, SIGNAL(timeout()), this, SLOT(bellekYaz()));
    m_bellek.start(30000);
    QTimer::singleShot(3000, this, SLOT(bellekYaz()));
}

bool Gunluk::raporBekliyor() const { return QFile::exists(m_klasor + "/rapor.bekliyor"); }

void Gunluk::temizCikis()
{
    yaz("duzgun cikis");
    QFile::remove(m_klasor + "/acik.isaret");
}

void Gunluk::bellekYaz()
{
#ifdef Q_OS_SYMBIAN
    TInt buyuk = 0;
    const TInt hucre = User::AllocSize(buyuk);
    TInt bos = 0, toplam = 0;
    HAL::Get(HALData::EMemoryRAMFree, bos);
    HAL::Get(HALData::EMemoryRAM, toplam);
    // buyuk: yigindaki ayrilmis toplam bayt (ust sinir .pro'da 48 MB)
    yaz(QString("bellek: kullanilan %1 KB (%2 parca, sinir 48 MB) - telefon bos RAM %3 / %4 MB")
        .arg(buyuk / 1024).arg(hucre).arg(bos / 1048576).arg(toplam / 1048576));
#endif
}

QString Gunluk::metin() const
{
    // son ~120 KB (eski + yeni gunluk)
    QByteArray b;
    QFile e(m_klasor + "/gunluk_eski.txt"), g(m_klasor + "/gunluk.txt");
    if (e.open(QIODevice::ReadOnly)) { b = e.readAll(); e.close(); }
    if (g.open(QIODevice::ReadOnly)) { b += g.readAll(); g.close(); }
    if (b.size() > 120 * 1024) b = b.right(120 * 1024);
    return QString::fromUtf8(b);
}

static QString jsonEsc(const QString &s)
{
    QString o = "\"";
    for (int i = 0; i < s.size(); i++) {
        const QChar c = s.at(i);
        if (c == '"') o += "\\\""; else if (c == '\\') o += "\\\\";
        else if (c == '\n') o += "\\n"; else if (c == '\r') o += "\\r"; else if (c == '\t') o += "\\t";
        else if (c.unicode() < 32) o += QString("\\u%1").arg(c.unicode(), 4, 16, QChar('0'));
        else o += c;
    }
    return o + "\"";
}

void Gunluk::gonder(const QString &sunucu, const QString &anahtar, const QString &not_)
{
    if (anahtar.isEmpty()) { emit raporSonucu(false, Dil::t("Rapor için Ayarlar'da sunucu parolasını girin")); return; }
    if (!m_nam) m_nam = new QNetworkAccessManager(this);
    QString n = not_;
    if (raporBekliyor()) n = Dil::t("Otomatik çökme raporu (çöken açılış: ") + m_oncekiBas + ") " + n;
    const QString body = "{\"app\":\"BelleMaps\",\"version\":\"" + m_surum + "\",\"note\":" + jsonEsc(n) + ",\"text\":" + jsonEsc(metin()) + "}";
    QString s = sunucu; while (s.endsWith('/')) s.chop(1);
    QNetworkRequest r(QUrl(s + "/api/report"));
    r.setRawHeader("X-Api-Key", anahtar.toUtf8()); r.setRawHeader("X-Lang", Dil::kodu());
    r.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    QNetworkReply *rep = m_nam->post(r, body.toUtf8());
    connect(rep, SIGNAL(finished()), this, SLOT(gonderildi()));
    yaz("rapor gonderiliyor");
}

void Gunluk::gonderildi()
{
    QNetworkReply *r = qobject_cast<QNetworkReply *>(sender());
    if (!r) return;
    r->deleteLater();
    const int kod = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const bool ok = r->error() == QNetworkReply::NoError && kod >= 200 && kod < 300;
    yaz(QString("rapor ") + (ok ? "gonderildi" : "HATA " + r->errorString()));
    if (ok) { QFile::remove(m_klasor + "/rapor.bekliyor"); emit raporDegisti(); }
    emit raporSonucu(ok, ok ? Dil::t("Hata raporu gönderildi") :
                     (kod == 403 ? Dil::t("Rapor gönderilemedi: sunucu parolası hatalı") : Dil::t("Rapor gönderilemedi: ") + r->errorString()));
}
