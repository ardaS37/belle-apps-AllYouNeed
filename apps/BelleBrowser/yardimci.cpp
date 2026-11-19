#include "yardimci.h"
#include "depo.h"
#include "dil.h"
#include "katman.h"
#include "belleserver.h"

#include <QtGui/QApplication>
#include <QtGui/QClipboard>
#include <QtGui/QPalette>
#include <QtGui/QColor>
#include <QtGui/QDesktopServices>
#include <QtGui/QMouseEvent>
#include <QtGui/QKeyEvent>
#include <QtDeclarative/QDeclarativeView>
#include <QtCore/QSettings>
#include <QtCore/QTimer>
#include <QtCore/QEventLoop>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QProcess>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkReply>
#include <QtWebKit/QWebSettings>
#include <QtGui/QGraphicsSceneContextMenuEvent>
#include <QtCore/QDateTime>

static QSettings &genel() { static QSettings s("BelleBrowser", "Genel"); return s; }

Yardimci::Yardimci(QDeclarativeView *view, QObject *parent) : QObject(parent), m_view(view), m_yazi(false), m_cift(false), m_nam(0)
{
    qApp->installEventFilter(this);
    startTimer(3000);       // tasarruf gostergesi
}

QString Yardimci::mod() const { return KatmanAyar::al().mod; }
QString Yardimci::ua() const { return KatmanAyar::al().ua; }
QString Yardimci::sunucu() const { return KatmanAyar::al().sunucu; }
bool Yardimci::parolaVar() const { return !KatmanAyar::al().anahtar.isEmpty(); }
int Yardimci::resimW() const { return KatmanAyar::al().resimW; }
int Yardimci::resimQ() const { return KatmanAyar::al().resimQ; }
bool Yardimci::reklam() const { return KatmanAyar::al().reklam; }
bool Yardimci::sertifikaYoksay() const { return KatmanAyar::al().sertifikaYoksay; }

QString Yardimci::tasarruf() const
{
    const KatmanAyar &a = KatmanAyar::al();
    const qint64 fark = a.orijinal - a.giden;
    if (a.orijinal <= 0 || fark <= 0) return QString();
    const int yuzde = int(100.0 * fark / a.orijinal);
    return (fark > 1048576 ? QString::number(fark / 1048576.0, 'f', 1) + " MB" : QString::number(fark / 1024) + " KB")
            + Dil::t(" tasarruf (%") + QString::number(yuzde) + ")";
}

void Yardimci::timerEvent(QTimerEvent *) { emit istatistik(); }

void Yardimci::setMod(const QString &m) { KatmanAyar::al().mod = m; KatmanAyar::al().kaydet(); emit ayarDegisti(); }
void Yardimci::setUa(const QString &u) { KatmanAyar::al().ua = u; KatmanAyar::al().kaydet(); emit ayarDegisti(); }
void Yardimci::setResim(int w, int q) { KatmanAyar::al().resimW = w; KatmanAyar::al().resimQ = q; KatmanAyar::al().kaydet(); emit ayarDegisti(); }
void Yardimci::setReklam(bool b) { KatmanAyar::al().reklam = b; KatmanAyar::al().kaydet(); emit ayarDegisti(); }
void Yardimci::setSertifikaYoksay(bool b) { KatmanAyar::al().sertifikaYoksay = b; KatmanAyar::al().kaydet(); emit ayarDegisti(); }
void Yardimci::setSunucu(const QString &adres) { belleSetServer(adres); KatmanAyar::al().sunucu = belleServer(); emit ayarDegisti(); }

int Yardimci::setParola(const QString &p)
{
    QNetworkAccessManager nam;
    QNetworkRequest req(QUrl(KatmanAyar::al().sunucu + "/tb/durum"));
    req.setRawHeader("X-Api-Key", p.trimmed().toUtf8()); req.setRawHeader("X-Lang", Dil::kodu());
    QNetworkReply *r = nam.get(req);
    QEventLoop loop;
    QTimer::singleShot(20000, &loop, SLOT(quit()));
    connect(r, SIGNAL(finished()), &loop, SLOT(quit()));
    loop.exec();
    const int kod = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    r->deleteLater();
    if (kod == 401 || kod == 403) return 0;
    if (kod != 200) return -1;
    KatmanAyar::al().anahtar = p.trimmed();
    KatmanAyar::al().kaydet();
    emit ayarDegisti();
    return 1;
}

void Yardimci::parolaSil() { KatmanAyar::al().anahtar.clear(); KatmanAyar::al().kaydet(); emit ayarDegisti(); }

// Imlecle tiklama: gercek dokunma gibi gorunume fare olayi gonderilir (WebKit odagi, baglantilar, formlar dahil)
void Yardimci::tikla(qreal sx, qreal sy, bool cift)
{
    if (!m_view) return;
    m_bas = m_view->mapFromScene(QPointF(sx, sy));
    m_cift = cift;
    QWidget *vp = m_view->viewport();
    QMouseEvent bas(QEvent::MouseButtonPress, m_bas, m_view->viewport()->mapToGlobal(m_bas), Qt::LeftButton, Qt::LeftButton, Qt::NoModifier);
    QApplication::sendEvent(vp, &bas);
    QTimer::singleShot(70, this, SLOT(birak()));
}

void Yardimci::birak()
{
    if (!m_view) return;
    QWidget *vp = m_view->viewport();
    QMouseEvent b(QEvent::MouseButtonRelease, m_bas, vp->mapToGlobal(m_bas), Qt::LeftButton, Qt::NoButton, Qt::NoModifier);
    QApplication::sendEvent(vp, &b);
    if (m_cift) {
        m_cift = false;
        QMouseEvent d(QEvent::MouseButtonDblClick, m_bas, vp->mapToGlobal(m_bas), Qt::LeftButton, Qt::LeftButton, Qt::NoModifier);
        QApplication::sendEvent(vp, &d);
        QMouseEvent b2(QEvent::MouseButtonRelease, m_bas, vp->mapToGlobal(m_bas), Qt::LeftButton, Qt::NoButton, Qt::NoModifier);
        QApplication::sendEvent(vp, &b2);
    }
}

bool Yardimci::eventFilter(QObject *o, QEvent *e)
{
    // WebKit'in kendi (Ingilizce, "Open in New Window") menusu yerine bizim Turkce menu
    if (e->type() == QEvent::GraphicsSceneContextMenu && o->inherits("QGraphicsWebView")) {
        const QPointF p = static_cast<QGraphicsSceneContextMenuEvent *>(e)->scenePos();
        emit sayfaBaglam(p.x(), p.y());
        return true;
    }
    if (m_yazi && e->type() == QEvent::KeyPress) {
        QKeyEvent *k = static_cast<QKeyEvent *>(e);
        if (k->key() == Qt::Key_Select || k->key() == Qt::Key_Escape || k->key() == Qt::Key_Context2) {
            setYaziKipi(false);
            emit yaziBitir();
            return true;
        }
    }
    return QObject::eventFilter(o, e);
}

QString Yardimci::pano() const { return QApplication::clipboard()->text(); }
void Yardimci::setPano(const QString &s) { QApplication::clipboard()->setText(s); }
bool Yardimci::disaAc(const QString &url) { return QDesktopServices::openUrl(QUrl::fromUserInput(url)); }

QString Yardimci::anahtarliAdres(const QString &yol) const
{
    const KatmanAyar &a = KatmanAyar::al();
    return a.sunucu + yol + (yol.contains('?') ? "&" : "?") + "key=" + QString::fromLatin1(QUrl::toPercentEncoding(a.anahtar));
}

QString Yardimci::vekilAdres(const QString &url) const
{
    return anahtarliAdres("/tb/g?u=" + QString::fromLatin1(QUrl::toPercentEncoding(url)));
}

QString Yardimci::sadeAdres(const QString &urlIn) const
{
    const QString o = okumaAdres(urlIn);
    return QString(o).replace("/tb/oku?u=", "/tb/sade?u=");
}

QString Yardimci::okumaAdres(const QString &urlIn) const
{
    QString url = urlIn.trimmed();
    const QString sunucu = KatmanAyar::al().sunucu;
    // zaten okuma / vekil sayfasindaysa asil adresi cikar (yoksa sunucu kendi sayfasini okumaya calisir)
    for (int i = 0; i < 3 && url.startsWith(sunucu + "/tb/"); ++i) {
        const QString u = QUrl(url).queryItemValue("u");
        if (u.isEmpty()) break;
        url = QUrl::fromPercentEncoding(u.toUtf8());
    }
    // semasiz adres ("haberler.com"): sunucu "Gecersiz adres" diyordu
    if (!url.contains("://")) url = "http://" + url;
    return sunucu + "/tb/oku?u=" + QString::fromLatin1(QUrl::toPercentEncoding(url));
}

void Yardimci::setKoyu(bool koyu)
{
    QPalette p = QApplication::palette();
    if (koyu) {
        p.setColor(QPalette::Text, QColor("#e8eaed"));
        p.setColor(QPalette::WindowText, QColor("#e8eaed"));
        p.setColor(QPalette::ButtonText, QColor("#e8eaed"));
        p.setColor(QPalette::Base, QColor("#25282d"));
        p.setColor(QPalette::Window, QColor("#15171a"));
        p.setColor(QPalette::Button, QColor("#25282d"));
        p.setColor(QPalette::Highlight, QColor("#8ab4f8"));
        p.setColor(QPalette::HighlightedText, QColor("#15171a"));
    } else {
        p.setColor(QPalette::Text, QColor("#202124"));
        p.setColor(QPalette::WindowText, QColor("#202124"));
        p.setColor(QPalette::ButtonText, QColor("#202124"));
        p.setColor(QPalette::Base, QColor("#ffffff"));
        p.setColor(QPalette::Window, QColor("#ffffff"));
        p.setColor(QPalette::Button, QColor("#f1f3f4"));
        p.setColor(QPalette::Highlight, QColor("#1a73e8"));
        p.setColor(QPalette::HighlightedText, QColor("#ffffff"));
    }
    QApplication::setPalette(p);
    if (m_view) { m_view->setPalette(p); m_view->viewport()->setPalette(p); }
}

void Yardimci::cerezSil() { KaliciCerez::ortak()->temizle(); }

void Yardimci::onbellekSil()
{
    QWebSettings::clearMemoryCaches();
#if defined(Q_OS_SYMBIAN)
    const QString d = Depo::yol("BelleBrowser/onbellek");
#else
    const QString d = QDir::homePath() + "/BelleBrowser/onbellek";
#endif
    QDir k(d);
    foreach (const QString &alt, k.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        QDir a(d + "/" + alt);
        foreach (const QString &f, a.entryList(QDir::Files)) a.remove(f);
    }
}

QString Yardimci::ayar(const QString &k, const QString &v) const { return genel().value(k, v).toString(); }
void Yardimci::setAyar(const QString &k, const QString &v) { genel().setValue(k, v); genel().sync(); }

// Belle Remote'u sunucu tarayicisi kipinde bu adresle ac (Belle Remote acilista dosyayi okur)
bool Yardimci::belleRemoteAc(const QString &url)
{
#if defined(Q_OS_SYMBIAN)
    const QString dosya = "C:/Data/E6/belleremote_ac.txt";
#else
    const QString dosya = QDir::homePath() + "/E6/belleremote_ac.txt";
#endif
    QDir().mkpath(QFileInfo(dosya).absolutePath());
    QFile f(dosya);
    if (f.open(QIODevice::WriteOnly)) { f.write(url.toUtf8()); f.close(); }
#if defined(Q_OS_SYMBIAN)
    return QProcess::startDetached("BelleRemote.exe");
#else
    return false;
#endif
}

// ---------------- gunluk ve hata raporu ----------------
void Yardimci::log(const QString &s)
{
    if (m_gunluk.isEmpty()) return;
    QFile f(m_gunluk);
    if (f.size() > 200 * 1024) f.remove();      // buyumesin
    if (f.open(QIODevice::Append)) f.write((QDateTime::currentDateTime().toString("dd.MM hh:mm:ss ") + s + "\n").toUtf8());
}

QString Yardimci::gunluk() const
{
    QFile f(m_gunluk);
    if (!f.open(QIODevice::ReadOnly)) return QString();
    QByteArray b = f.readAll();
    if (b.size() > 24000) b = b.right(24000);
    return QString::fromUtf8(b);
}

static QString jsonKacis(const QString &s)
{
    QString o = "\"";
    for (int i = 0; i < s.length(); ++i) {
        const QChar c = s.at(i);
        if (c == '\\') o += "\\\\";
        else if (c == '"') o += "\\\"";
        else if (c == '\n') o += "\\n";
        else if (c == '\r') o += "\\r";
        else if (c == '\t') o += "\\t";
        else if (c.unicode() < 0x20) o += QString("\\u%1").arg(c.unicode(), 4, 16, QChar('0'));
        else o += c;
    }
    return o + "\"";
}

void Yardimci::raporGonder(const QString &not_, const QString &ek)
{
    const KatmanAyar &a = KatmanAyar::al();
    if (a.anahtar.isEmpty()) { emit raporBitti(false, Dil::t("Önce Ayarlar'dan sunucu parolasını girin")); return; }
    const QString metin = ek + "\n----- gunluk -----\n" + gunluk();
    const QString govde = "{\"app\":\"BelleBrowser\",\"version\":\"" + surum() + "\",\"note\":" + jsonKacis(not_) + ",\"text\":" + jsonKacis(metin) + "}";
    if (!m_nam) m_nam = new QNetworkAccessManager(this);
    QNetworkRequest r(QUrl(a.sunucu + "/api/report"));
    r.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    r.setRawHeader("X-Api-Key", a.anahtar.toUtf8()); r.setRawHeader("X-Lang", Dil::kodu());
    QNetworkReply *rep = m_nam->post(r, govde.toUtf8());
    connect(rep, SIGNAL(finished()), this, SLOT(raporCevap()));
    log("rapor gonderiliyor");
}

void Yardimci::raporCevap()
{
    QNetworkReply *rep = qobject_cast<QNetworkReply *>(sender());
    if (!rep) return;
    const int kod = rep->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    rep->deleteLater();
    if (kod >= 200 && kod < 300) emit raporBitti(true, Dil::t("Rapor gönderildi, teşekkürler"));
    else emit raporBitti(false, Dil::t("Rapor gönderilemedi") + (kod ? " (HTTP " + QString::number(kod) + ")" : Dil::t(" (bağlantı yok)")));
}