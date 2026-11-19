#include "belleadres.h"
#include "depo.h"
#include "uzak.h"
#include "dil.h"

#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QSettings>
#include <QtCore/QDateTime>
#include <QtCore/QUrl>
#include <QtCore/QRegExp>
#include <QtCore/QEvent>
#include <QtGui/QApplication>
#include <QtGui/QClipboard>
#include <QtGui/QDesktopServices>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkRequest>
#include <QtNetwork/QNetworkReply>
#include <QtNetwork/QNetworkInterface>

#ifdef Q_OS_SYMBIAN
#include <apgtask.h>
#include <coemain.h>
#include <w32std.h>
#include <f32file.h>
#include <baclipb.h>
#include <txtetext.h>
#endif

static const int KLanPort = 5680;
static const double KZoomlar[] = { 1.0, 1.5, 2.0, 3.0, 4.0 };
static const int KZoomSayisi = 5;

Uzak::Uzak(QObject *parent)
    : QObject(parent), m_sock(0), m_nam(new QNetworkAccessManager(this)), m_agYon(0), m_ag(0), m_isTur(0),
      m_profilSorgu(false), m_tarayici(false), m_geri(false), m_ileri(false), m_yuk(false), m_dl(0), m_dlDosya(0), m_dlYuzde(-1), m_alanG(640), m_alanY(410), m_gorunumOlcek(1.72),
      m_upgradeBekliyor(false),
      m_durum(0), m_port(0), m_kareNo(0), m_ix(5000), m_iy(5000), m_pcx(-1), m_pcy(-1), m_zoom(1.0), m_genel(false),
      m_gonderiliyor(false), m_yaziAlani(false), m_fps(1), m_kalite(35), m_genislik(640),
      m_otoYazi(false), m_arka(false), m_alinan(0), m_sonAlinan(0), m_kbps(0), m_ping(-1)
{
    m_z[0] = 0; m_z[1] = 0; m_z[2] = 10000; m_z[3] = 10000;
#if defined(Q_OS_SYMBIAN)
    m_dataDir = "C:/Data/BelleRemote";
#else
    m_dataDir = QDir::homePath() + "/BelleRemote";
#endif
    QDir().mkpath(m_dataDir);
    const QString priv = QDesktopServices::storageLocation(QDesktopServices::DataLocation);
    QDir().mkpath(priv);
    m_ayarDosya = priv + "/ayarlar.ini";
    ayarYukle();

    m_paket.setSingleShot(true);
    m_paket.setInterval(1000);
    connect(&m_paket, SIGNAL(timeout()), this, SLOT(paketGonder()));
    m_lanSure.setSingleShot(true);
    m_lanSure.setInterval(4000);
    connect(&m_lanSure, SIGNAL(timeout()), this, SLOT(onLanZamanAsimi()));
    m_saniye.setInterval(1000);
    connect(&m_saniye, SIGNAL(timeout()), this, SLOT(saniyelik()));
    m_durumMetni = Dil::t("Bağlı değil");
    // Önceki açılışın günlüğü korunur (rapor uygulama yeniden açıldıktan sonra gönderilse de görünsün)
    {
        QFile f(m_dataDir + "/gunluk.txt");
        if (f.open(QIODevice::ReadOnly)) {
            m_log = QString::fromUtf8(f.readAll()).split('\n', QString::SkipEmptyParts);
            while (m_log.size() > 119) m_log.removeFirst();
        }
    }
    log("acildi Belle Remote 1.3.1");
}

Uzak::~Uzak()
{
    if (m_sock) { m_sock->abort(); }
}

void Uzak::log(const QString &s)
{
    m_log << QDateTime::currentDateTime().toString("dd.MM HH:mm:ss ") + s;
    while (m_log.size() > 120) m_log.removeFirst();
    qDebug("E6U %s", s.toUtf8().constData());
    QFile f(m_dataDir + "/gunluk.txt");
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) f.write((m_log.join("\n") + "\n").toUtf8());
}

QString Uzak::gunlukMetni() const { return m_log.join("\n"); }
#ifdef Q_OS_SYMBIAN
// Qt panosu boş dönerse Symbian sistem panosundan doğrudan oku (başka uygulamada kopyalanan metin)
static QString sistemPanosu()
{
    QString out;
    RFs fs;
    if (fs.Connect() != KErrNone) return out;
    TRAPD(err, {
        CClipboard *cb = CClipboard::NewForReadingLC(fs);
        CPlainText *pt = CPlainText::NewL();
        CleanupStack::PushL(pt);
        pt->PasteFromStoreL(cb->Store(), cb->StreamDictionary(), 0);
        const TInt n = pt->DocumentLength();
        if (n > 0) {
            HBufC *b = HBufC::NewLC(n);
            TPtr p = b->Des();
            pt->Extract(p, 0, n);
            out = QString::fromUtf16(p.Ptr(), p.Length());
            CleanupStack::PopAndDestroy(b);
        }
        CleanupStack::PopAndDestroy(2);   // pt, cb
    });
    Q_UNUSED(err);
    fs.Close();
    out.replace(QChar(0x2029), '\n');     // paragraf sonu
    out.replace(QChar(0x2028), '\n');
    return out;
}
#endif

QString Uzak::panoMetni() const
{
    QString t = QApplication::clipboard()->text();
#ifdef Q_OS_SYMBIAN
    if (t.isEmpty()) t = sistemPanosu();
#endif
    return t;
}

static QString jsonEsc(const QString &s)
{
    QString o = "\"";
    for (int i = 0; i < s.length(); ++i) {
        const QChar c = s.at(i);
        if (c == '\\') o += "\\\\";
        else if (c == '"') o += "\\\"";
        else if (c == '\n') o += "\\n";
        else if (c == '\r') o += "\\r";
        else if (c == '\t') o += "\\t";
        else if (c.unicode() < 32) o += QString("\\u%1").arg(c.unicode(), 4, 16, QChar('0'));
        else o += c;
    }
    return o + "\"";
}

void Uzak::raporGonder()
{
    if (m_anahtar.isEmpty()) { emit mesaj(Dil::t("Rapor için önce sunucu parolası kaydedilmeli")); return; }
    QString t = Dil::t("Belle Remote raporu • ") + QDateTime::currentDateTime().toString("dd.MM.yyyy HH:mm:ss") + "\n";
    t += "Qt " + QString(qVersion()) + "  sunucu: " + m_sunucu + "  kip: " + m_kip
         + QString("  fps %1  kalite %2  genislik %3").arg(m_fps).arg(m_kalite).arg(m_genislik) + "\n";
    t += "Durum: " + m_durumMetni + "\n\n" + m_log.join("\n") + "\n";
    const QString body = "{\"app\":\"BelleRemote\",\"version\":\"1.4.1\",\"note\":\"\",\"text\":" + jsonEsc(t) + "}";
    QNetworkRequest r(QUrl(m_sunucu + "/api/report"));
    r.setRawHeader("X-Api-Key", m_anahtar.toUtf8()); r.setRawHeader("X-Lang", Dil::kodu());
    r.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    QNetworkReply *rep = m_nam->post(r, body.toUtf8());
    connect(rep, SIGNAL(finished()), this, SLOT(onRapor()));
    log("rapor gonderiliyor");
}

void Uzak::onRapor()
{
    QNetworkReply *r = qobject_cast<QNetworkReply *>(sender());
    r->deleteLater();
    const bool ok = r->error() == QNetworkReply::NoError;
    log(QString("rapor ") + (ok ? "gonderildi" : "HATA " + r->errorString()));
    emit mesaj(ok ? Dil::t("Rapor gönderildi") : Dil::t("Rapor gönderilemedi: ") + r->errorString());
}

// ---------------- Ayarlar ----------------

void Uzak::ayarYukle()
{
    QSettings s(m_ayarDosya, QSettings::IniFormat);
    m_sunucu = belleSunucuTasi(s.value("sunucu").toString());   // eski IP -> yeni adres
    m_anahtar = s.value("anahtar").toString();
    m_telAdi = s.value("telefonAdi", "Nokia E6").toString();
    m_kip = s.value("kip", "paket").toString();
    m_fps = s.value("fps", 1).toInt();
    m_kalite = s.value("kalite", 35).toInt();
    m_genislik = s.value("genislik", 640).toInt();
    m_otoYazi = s.value("otoYazi", false).toBool();
    m_gorunumOlcek = s.value("gorunumOlcek", 1.72).toDouble();
    if (qAbs(m_gorunumOlcek - 1.25) < 0.01 || qAbs(m_gorunumOlcek - 1.6) < 0.01) m_gorunumOlcek = 1.72;   // 1.2'nin Normal/Genis'i -> 1100 px
    const int surum = s.value("ayarSurum", 0).toInt();
    // 1.0-1.0.1 menü hatası, menüler açılırken alt sınır değerlerini (kalite 10, 320 px, 1 fps) yazmıştı: bir kez varsayılana dön
    if (surum < 3) { m_kip = "paket"; m_fps = 1; m_kalite = 35; m_genislik = 640; }
    // 1.0.6: PC'de yazı alanı açılınca yazı penceresinin kendiliğinden açılması varsayılan KAPALI (kullanıcı isteği)
    if (surum < 4) m_otoYazi = false;
    if (surum < 4) { s.setValue("ayarSurum", 4); ayarKaydet(); }
}

void Uzak::ayarKaydet()
{
    QSettings s(m_ayarDosya, QSettings::IniFormat);
    s.setValue("sunucu", m_sunucu);
    s.setValue("anahtar", m_anahtar);
    s.setValue("telefonAdi", m_telAdi);
    s.setValue("kip", m_kip);
    s.setValue("fps", m_fps);
    s.setValue("kalite", m_kalite);
    s.setValue("genislik", m_genislik);
    s.setValue("otoYazi", m_otoYazi);
    s.setValue("gorunumOlcek", m_gorunumOlcek);
    s.sync();
    if (s.status() != QSettings::NoError) log("AYAR YAZILAMADI: " + m_ayarDosya);
}

static QString temizle(const QString &v)
{
    QString k;
    for (int i = 0; i < v.length(); ++i) if (v.at(i).unicode() >= 32 && v.at(i).unicode() != 127) k += v.at(i);
    return k.trimmed();
}

void Uzak::setSunucu(const QString &url)
{
    QString u = temizle(url);
    while (u.endsWith('/')) u.chop(1);
    if (u.isEmpty()) u = "https://e6.msahincelen.xyz";
    if (!u.startsWith("http")) u = "http://" + u;
    m_sunucu = u; ayarKaydet(); emit ayarChanged();
    log("sunucu: " + u);
}

void Uzak::setAnahtar(const QString &k)
{
    m_anahtar = temizle(k); ayarKaydet(); emit ayarChanged();
    log("parola kaydedildi (" + QString::number(m_anahtar.length()) + " karakter)");
}

void Uzak::setTelefonAdi(const QString &s) { m_telAdi = temizle(s); if (m_telAdi.isEmpty()) m_telAdi = "Nokia E6"; ayarKaydet(); emit ayarChanged(); }

static QString ayarSatiri(const QString &kip, int fps, int kalite, int genislik)
{
    return QString("kip=%1\nfps=%2\nkalite=%3\ngenislik=%4").arg(kip).arg(fps).arg(kalite).arg(genislik);
}

void Uzak::setKip(const QString &k)
{
    m_kip = (k == "akis") ? "akis" : "paket";
    ayarKaydet(); emit ayarChanged();
    if (m_durum == 2) { simdiGonder(); cerceve('A', ayarSatiri(m_kip, m_arka ? 0 : m_fps, m_kalite, m_genislik).toUtf8()); }
}
void Uzak::setFps(int f)
{
    m_fps = qBound(1, f, 15); ayarKaydet(); emit ayarChanged();
    if (m_durum == 2 && !m_arka) cerceve('A', QString("fps=%1").arg(m_fps).toUtf8());
}
void Uzak::setKalite(int q)
{
    m_kalite = qBound(10, q, 90); ayarKaydet(); emit ayarChanged();
    if (m_durum == 2) cerceve('A', QString("kalite=%1").arg(m_kalite).toUtf8());
}
void Uzak::setGenislik(int w)
{
    m_genislik = qBound(320, w, 1280); ayarKaydet(); emit ayarChanged();
    if (m_durum == 2) cerceve('A', QString("genislik=%1").arg(m_genislik).toUtf8());
}
void Uzak::setOtoYazi(bool b) { m_otoYazi = b; ayarKaydet(); emit ayarChanged(); }

// ---------------- Profiller (bir kez bağlanınca kaydedilir) ----------------

QVariantList Uzak::profiller() const
{
    QVariantList out;
    QSettings s(m_ayarDosya, QSettings::IniFormat);
    const int n = s.beginReadArray("profiller");
    for (int i = 0; i < n; ++i) {
        s.setArrayIndex(i);
        QVariantMap m;
        m["ad"] = s.value("ad").toString();
        m["lan"] = s.value("lan").toString();
        m["yol"] = s.value("yol").toString();
        m["tarih"] = s.value("tarih").toString();
        out << m;
    }
    s.endArray();
    return out;
}

static void profilYaz(QSettings &s, const QVariantList &l)
{
    s.remove("profiller");
    s.beginWriteArray("profiller", l.size());
    for (int i = 0; i < l.size(); ++i) {
        s.setArrayIndex(i);
        const QVariantMap m = l.at(i).toMap();
        s.setValue("ad", m.value("ad")); s.setValue("lan", m.value("lan"));
        s.setValue("yol", m.value("yol")); s.setValue("tarih", m.value("tarih"));
    }
    s.endArray();
}

void Uzak::profilKaydet()
{
    if (m_pcAdi.isEmpty()) return;
    QVariantList l = profiller();
    QString lan;
    for (int i = 0; i < l.size(); ++i) {
        if (l.at(i).toMap().value("ad").toString() == m_pcAdi) { lan = l.at(i).toMap().value("lan").toString(); l.removeAt(i); break; }
    }
    if (m_yol == "LAN") lan = m_host + ":" + QString::number(m_port);
    else if (!m_lanYedek.isEmpty()) lan = m_lanYedek;
    QVariantMap m;
    m["ad"] = m_pcAdi; m["lan"] = lan; m["yol"] = m_yol;
    m["tarih"] = QDateTime::currentDateTime().toString("dd.MM.yyyy HH:mm");
    l.prepend(m);                       // son bağlanılan en üstte
    while (l.size() > 8) l.removeLast();
    QSettings s(m_ayarDosya, QSettings::IniFormat);
    profilYaz(s, l);
}

void Uzak::profilSil(int i)
{
    QVariantList l = profiller();
    if (i < 0 || i >= l.size()) return;
    l.removeAt(i);
    QSettings s(m_ayarDosya, QSettings::IniFormat);
    profilYaz(s, l);
}

QString Uzak::telefonIp() const
{
    QStringList ips;
    foreach (const QHostAddress &a, QNetworkInterface::allAddresses()) {
        if (a.protocol() != QAbstractSocket::IPv4Protocol) continue;
        if (a == QHostAddress::LocalHost || a.toString().startsWith("169.254.")) continue;
        ips << a.toString();
    }
    return ips.isEmpty() ? Dil::t("(ağ bağlantısı yok)") : ips.join(", ");
}

// ---------------- Bağlantı ----------------

void Uzak::durumYap(int d, const QString &m)
{
    m_durum = d; m_durumMetni = m;
    emit durumChanged();
}

// ---- Ağ oturumu: Nokia'da mobil veri / Wi-Fi kendiliğinden açılmıyor; ham soketten önce açtırılır ----

void Uzak::agHazirla()
{
    if (!m_agYon) m_agYon = new QNetworkConfigurationManager(this);
    if (m_ag && m_ag->isOpen()) { isYap(); return; }
    const QNetworkConfiguration cfg = m_agYon->defaultConfiguration();
    if (!cfg.isValid()) { isYap(); return; }          // masaüstü / simülatör: gerek yok
    if (!m_ag) {
        m_ag = new QNetworkSession(cfg, this);
        connect(m_ag, SIGNAL(opened()), this, SLOT(onAgAcildi()));
        connect(m_ag, SIGNAL(error(QNetworkSession::SessionError)), this, SLOT(onAgHata(QNetworkSession::SessionError)));
    }
    durumYap(1, Dil::t("İnternet bağlantısı açılıyor…"));
    log("ag oturumu aciliyor");
    m_ag->open();
}

void Uzak::onAgAcildi()
{
    log("ag oturumu acik (" + m_ag->configuration().name() + ")  ip: " + telefonIp());
    if (m_isTur) isYap();
}

void Uzak::onAgHata(QNetworkSession::SessionError)
{
    const QString h = m_ag ? m_ag->errorString() : QString();
    log("ag oturumu hatasi: " + h);
    if (!m_isTur) return;
    m_isTur = 0;
    durumYap(0, Dil::t("İnternet bağlantısı açılamadı: ") + h);
    emit mesaj(m_durumMetni);
}

// Telefon bu adresle aynı yerel ağda mı? (ilk üç sayı aynı). IP yoksa bilinmez -> dene.
bool Uzak::ayniAg(const QString &lan) const
{
    const QString host = lan.section(':', 0, 0);
    const QString onEk = host.section('.', 0, 2) + ".";
    bool ipVar = false;
    foreach (const QHostAddress &a, QNetworkInterface::allAddresses()) {
        if (a.protocol() != QAbstractSocket::IPv4Protocol || a == QHostAddress::LocalHost) continue;
        const QString s = a.toString();
        if (s.startsWith("169.254.")) continue;
        ipVar = true;
        if (s.startsWith(onEk)) return true;
    }
    return !ipVar;
}

void Uzak::isYap()
{
    const int tur = m_isTur;
    m_isTur = 0;
    if (tur == 1) lanBaslat(m_isLan, QString());
    else if (tur == 2) sunucuBaslat(m_isPc);
    else if (tur == 3) {
        if (!m_isLan.isEmpty() && ayniAg(m_isLan)) {
            lanBaslat(m_isLan, m_isPc);       // olmazsa sunucuya geçer
        } else {
            if (!m_isLan.isEmpty()) log("farkli ag (" + telefonIp() + "), dogrudan sunucu");
            sunucuBaslat(m_isPc);
        }
    }
    else if (tur == 4) {
        // Kayıtlı PC: önce sunucudan PC'nin ŞU ANKİ yerel adresini öğren (ev / dükkan farklı ağlar)
        if (m_anahtar.isEmpty()) { m_isTur = 3; isYap(); return; }
        durumYap(1, Dil::t("%1 aranıyor…").arg(m_isPc));
        m_profilSorgu = true;
        pcListesiIste();
    }
}

void Uzak::baglanLan(const QString &adres)
{
    m_isTur = 1; m_isLan = temizle(adres); m_isPc.clear();
    agHazirla();
}

void Uzak::baglanSunucu(const QString &pc)
{
    if (m_anahtar.isEmpty()) { emit mesaj(Dil::t("Önce Ayarlar'dan sunucu parolasını girin")); return; }
    m_isTur = 2; m_isPc = temizle(pc);
    agHazirla();
}

void Uzak::baglanProfil(int i)
{
    const QVariantList l = profiller();
    if (i < 0 || i >= l.size()) return;
    const QVariantMap m = l.at(i).toMap();
    m_isTur = 4; m_isLan = m.value("lan").toString(); m_isPc = m.value("ad").toString();
    agHazirla();
}

void Uzak::baglanIkili(const QString &lan, const QString &ad)
{
    m_isTur = 3; m_isLan = lan; m_isPc = ad;
    agHazirla();
}

void Uzak::lanBaslat(const QString &adres, const QString &yedekPc)
{
    QString a = temizle(adres);
    int port = KLanPort;
    const int c = a.lastIndexOf(':');
    if (c > 0) { port = a.mid(c + 1).toInt(); a = a.left(c); if (port <= 0) port = KLanPort; }
    if (a.isEmpty()) { emit mesaj(Dil::t("Adres boş")); return; }
    baslat(a, port, false, QString());
    m_lanYedek = yedekPc.isEmpty() ? QString() : adres;
    if (!yedekPc.isEmpty()) {
        m_hedefPc = yedekPc;            // LAN olmazsa sunucu üzerinden bu ada bağlan
        m_lanSure.start();
    }
}

void Uzak::sunucuBaslat(const QString &pc)
{
    if (m_anahtar.isEmpty()) { emit mesaj(Dil::t("Önce Ayarlar'dan sunucu parolasını girin")); durumYap(0, Dil::t("Parola yok")); return; }
    const QUrl u(m_sunucu);
    if (u.host().isEmpty()) { emit mesaj(Dil::t("Sunucu adresi geçersiz")); return; }
    baslat(u.host(), u.port(80), true, temizle(pc));
}

void Uzak::baslat(const QString &host, int port, bool sunucuYolu, const QString &pc)
{
    if (m_sock) { m_sock->disconnect(this); m_sock->abort(); m_sock->deleteLater(); m_sock = 0; }
    m_lanSure.stop();
    m_buf.clear();
    m_bekleyen.clear(); m_paket.stop(); m_gonderiliyor = false;
    m_host = host; m_port = port;
    m_yol = sunucuYolu ? "Sunucu" : "LAN";
    m_hedefPc = pc;
    m_upgradeBekliyor = sunucuYolu;
    m_pcAdi = sunucuYolu ? pc : host;
    m_z[0] = 0; m_z[1] = 0; m_z[2] = 10000; m_z[3] = 10000; m_zoom = 1.0; m_genel = false;
    m_kare = QImage(); m_yaziAlani = false; m_arka = false;
    m_tarayici = (sunucuYolu && pc == "tarayici");
    if (!m_tarayici) { QSettings s(m_ayarDosya, QSettings::IniFormat); m_kip = s.value("kip", "paket").toString(); emit ayarChanged(); }   // tarayicidaki akis kipi PC'ye tasinmasin
    m_adres.clear(); m_baslik.clear(); m_geri = m_ileri = m_yuk = false; emit adresChanged();
    emit zoomChanged(); emit yaziAlaniChanged(); emit bekleyenChanged();

    m_sock = new QTcpSocket(this);
    m_sock->setSocketOption(QAbstractSocket::LowDelayOption, 1);
    m_sock->setSocketOption(QAbstractSocket::KeepAliveOption, 1);
    connect(m_sock, SIGNAL(connected()), this, SLOT(onBaglandi()));
    connect(m_sock, SIGNAL(readyRead()), this, SLOT(onVeri()));
    connect(m_sock, SIGNAL(error(QAbstractSocket::SocketError)), this, SLOT(onHata(QAbstractSocket::SocketError)));
    connect(m_sock, SIGNAL(disconnected()), this, SLOT(onKapandi()));
    durumYap(1, sunucuYolu ? Dil::t("Sunucuya bağlanıyor… (%1)").arg(pc)
                           : Dil::t("Yerel ağda bağlanıyor… %1:%2").arg(host).arg(port));
    log(QString("baglan %1 %2:%3 %4").arg(m_yol).arg(host).arg(port).arg(pc));
    m_sock->connectToHost(host, port);
}

void Uzak::onLanZamanAsimi()
{
    if (m_durum == 2 || m_yol != "LAN" || m_hedefPc.isEmpty()) return;
    log("LAN zaman asimi, sunucuya geciliyor");
    const QString pc = m_hedefPc, yedek = m_lanYedek;
    emit mesaj(Dil::t("Yerel ağda bulunamadı, sunucu üzerinden deneniyor"));
    sunucuBaslat(pc);
    m_lanYedek = yedek;
}

void Uzak::onBaglandi()
{
    if (m_upgradeBekliyor) {
        QByteArray q;
        q += "GET /uzak/baglan?rol=tel&hedef=" + QUrl::toPercentEncoding(m_hedefPc) + " HTTP/1.1\r\n";
        q += "Host: " + m_host.toUtf8() + "\r\n";
        q += "Connection: Upgrade\r\nUpgrade: e6uzak\r\n";
        q += "User-Agent: BelleRemote/1.0 (Symbian Belle)\r\n";
        q += "X-Api-Key: " + m_anahtar.toUtf8() + "\r\n\r\n";
        m_sock->write(q);
        durumYap(1, Dil::t("Sunucuda %1 aranıyor…").arg(m_hedefPc));
    } else {
        merhaba();
    }
}

void Uzak::merhaba()
{
    m_lanSure.stop();
    // Tarayicida goruntu canli akar (akis kipi, en az 4 kare/sn); Seceneklerden paket kipine gecilebilir
    if (m_tarayici && m_kip != "akis") { m_kip = "akis"; emit ayarChanged(); }
    const int fps = m_tarayici ? qMax(m_fps, 4) : m_fps;
    QString h = "anahtar=" + m_anahtar + "\nistemci=nokia\nkip=" + m_kip
            + QString("\ngenislik=%1\nkalite=%2\nfps=%3\nad=").arg(m_genislik).arg(m_kalite).arg(fps) + m_telAdi;
    // tarayici: pencere telefonun alanina tam otursun, goruntu pencereyle ayni genislikte (ornegin 1100 px) gelsin
    if (m_tarayici) h += "\ngorunum=" + gorunumMetni() + "\ngenislik=" + gorunumMetni().section('x', 0, 0);
    cerceve('H', h.toUtf8());
    durumYap(1, Dil::t("Kimlik doğrulanıyor…"));
}

void Uzak::kes()
{
    m_lanSure.stop(); m_paket.stop(); m_saniye.stop();
    m_bekleyen.clear(); m_gonderiliyor = false;
    if (m_sock) { m_sock->disconnect(this); m_sock->abort(); m_sock->deleteLater(); m_sock = 0; }
    m_yaziAlani = false;
    emit yaziAlaniChanged(); emit bekleyenChanged();
    durumYap(0, Dil::t("Bağlantı kesildi"));
    log("kesildi");
}

void Uzak::onHata(QAbstractSocket::SocketError e)
{
    if (!m_sock) return;
    const QString es = m_sock->errorString();
    log(QString("soket hatasi %1 %2").arg(int(e)).arg(es));
    // Profil bağlantısı: LAN başarısızsa hemen sunucuya geç
    if (m_durum != 2 && m_yol == "LAN" && !m_hedefPc.isEmpty()) {
        m_sock->disconnect(this);
        QTimer::singleShot(0, this, SLOT(onLanZamanAsimi()));
        return;
    }
    if (e == QAbstractSocket::RemoteHostClosedError && m_durum == 2) return;   // onKapandi ele alır
    m_sock->disconnect(this); m_sock->deleteLater(); m_sock = 0;
    m_saniye.stop(); m_paket.stop();
    QString m;
    if (e == QAbstractSocket::ConnectionRefusedError) m = Dil::t("Bağlantı reddedildi (PC uygulaması açık mı, LAN etkin mi?)");
    else if (e == QAbstractSocket::HostNotFoundError) m = Dil::t("Adres bulunamadı");
    else if (e == QAbstractSocket::SocketTimeoutError) m = Dil::t("Zaman aşımı");
    else m = Dil::t("Bağlantı hatası: ") + es;
    durumYap(0, m);
    emit mesaj(m);
}

void Uzak::onKapandi()
{
    if (!m_sock) return;
    m_sock->disconnect(this); m_sock->deleteLater(); m_sock = 0;
    m_saniye.stop(); m_paket.stop();
    m_bekleyen.clear(); m_gonderiliyor = false; emit bekleyenChanged();
    if (m_durum == 2) { durumYap(0, Dil::t("PC bağlantıyı kapattı")); emit mesaj(m_durumMetni); }
    else if (m_durum == 1) { durumYap(0, Dil::t("Bağlantı kapandı")); emit mesaj(m_durumMetni); }
    log("baglanti kapandi");
}

void Uzak::cerceve(char tur, const QByteArray &veri)
{
    if (!m_sock || m_sock->state() != QAbstractSocket::ConnectedState) return;
    QByteArray b;
    b.reserve(5 + veri.size());
    const quint32 n = veri.size();
    b.append(tur);
    b.append(char((n >> 24) & 0xff)); b.append(char((n >> 16) & 0xff));
    b.append(char((n >> 8) & 0xff)); b.append(char(n & 0xff));
    b.append(veri);
    m_sock->write(b);
}

void Uzak::onVeri()
{
    if (!m_sock) return;
    const QByteArray gelen = m_sock->readAll();
    m_alinan += gelen.size();
    m_buf.append(gelen);

    if (m_upgradeBekliyor) {
        const int e = m_buf.indexOf("\r\n\r\n");
        if (e < 0) { if (m_buf.size() > 8192) kes(); return; }
        const QString bas = QString::fromLatin1(m_buf.left(e));
        m_buf.remove(0, e + 4);
        const QString ilk = bas.section("\r\n", 0, 0);
        if (ilk.contains(" 101")) {
            m_upgradeBekliyor = false;
            log("aktarici eslesti");
            merhaba();
        } else {
            QString m;
            if (ilk.contains(" 404")) m = Dil::t("%1 sunucuda çevrimiçi değil (PC uygulaması açık ve 'Sunucu' etkin mi?)").arg(m_hedefPc);
            else if (ilk.contains(" 403")) m = Dil::t("Sunucu parolası hatalı");
            else if (ilk.contains(" 409")) m = Dil::t("PC şu an başka bir oturumda");
            else m = Dil::t("Sunucu yanıtı: ") + ilk;
            log("aktarici: " + ilk);
            if (m_sock) { m_sock->disconnect(this); m_sock->abort(); m_sock->deleteLater(); m_sock = 0; }
            durumYap(0, m); emit mesaj(m);
            return;
        }
    }

    while (m_buf.size() >= 5) {
        const uchar *p = reinterpret_cast<const uchar *>(m_buf.constData());
        const quint32 n = (quint32(p[1]) << 24) | (quint32(p[2]) << 16) | (quint32(p[3]) << 8) | quint32(p[4]);
        if (n > 8 * 1024 * 1024) { log("bozuk cerceve"); kes(); return; }
        if (quint32(m_buf.size()) < 5 + n) break;
        const char tur = m_buf.at(0);
        const QByteArray veri = m_buf.mid(5, n);
        m_buf.remove(0, 5 + n);
        isle(tur, veri);
        if (!m_sock) return;
    }
}

void Uzak::isle(char tur, const QByteArray &veri)
{
    const QString metin = (tur == 'J') ? QString() : QString::fromUtf8(veri);
    switch (tur) {
    case 'O': {
        foreach (const QString &s, metin.split('\n')) {
            if (s.startsWith("ad=")) m_pcAdi = s.mid(3).trimmed();
            if (s.trimmed() == "tarayici=1") m_tarayici = true;
        }
        m_kaynakAdi = m_tarayici ? Dil::t("Tarayıcı") : Dil::t("Masaüstü");
        durumYap(2, Dil::t("Bağlı: ") + m_pcAdi + " (" + m_yol + ")");
        if (!m_tarayici) profilKaydet();
        m_alinan = 0; m_sonAlinan = 0; m_saniye.start();
        log("baglandi " + m_pcAdi + " " + m_yol);
        cerceve('S', "masaustu");
        break;
    }
    case 'N':
        log("reddedildi: " + metin);
        if (m_sock) { m_sock->disconnect(this); m_sock->abort(); m_sock->deleteLater(); m_sock = 0; }
        durumYap(0, Dil::t("PC reddetti: ") + (metin.isEmpty() ? Dil::t("parola hatalı") : metin));
        emit mesaj(m_durumMetni);
        break;
    case 'L':
        emit pencereListesi(metin.split('\n', QString::SkipEmptyParts));
        break;
    case 'K': {
        const QStringList a = metin.split(' ');
        if (a.size() >= 3 && a.at(2) == "1") { m_pcx = a.at(0).toInt(); m_pcy = a.at(1).toInt(); }
        else { m_pcx = -1; m_pcy = -1; }
        break;
    }
    case 'J': {
        cerceve('G', QByteArray());         // akış denetimi: aldım
        QImage img;
        if (img.loadFromData(veri, "JPG")) {
            m_kare = img;
            ++m_kareNo;
            if (m_gonderiliyor) { m_gonderiliyor = false; emit bekleyenChanged(); }
            emit kareGeldi();
        } else log("jpeg cozulemedi " + QString::number(veri.size()));
        break;
    }
    case 'T': {
        const bool y = metin.trimmed() == "1";
        if (y != m_yaziAlani) { m_yaziAlani = y; emit yaziAlaniChanged(); }
        break;
    }
    case 'M':
        if (metin.startsWith("Kaynak: ")) { m_kaynakAdi = metin.mid(8); emit durumChanged(); }
        emit mesaj(metin);
        break;
    case 'R': {   // tarayici: adres \n baslik \n geri \n ileri \n yukleniyor
        const QStringList a = metin.split('\n');
        m_adres = a.value(0); m_baslik = a.value(1);
        m_geri = a.value(2) == "1"; m_ileri = a.value(3) == "1"; m_yuk = a.value(4) == "1";
        emit adresChanged();
        break;
    }
    case 'D': {   // tarayici: indirme hazir  id \t ad \t bayt
        const QStringList a = metin.split('\t');
        if (a.size() >= 3) { log("indirme hazir " + a.at(1) + " " + a.at(2)); emit indirmeHazir(a.at(0), a.at(1), a.at(2).toDouble()); }
        break;
    }
    case 'P':
        if (m_pingSaat.isValid()) { m_ping = m_pingSaat.elapsed(); emit istatistik(); }
        break;
    default:
        break;
    }
}

void Uzak::saniyelik()
{
    static int sayac = 0;
    const qint64 fark = m_alinan - m_sonAlinan;
    m_sonAlinan = m_alinan;
    m_kbps = m_kbps * 0.6 + (fark / 1024.0) * 0.4;
    if (++sayac % 10 == 1 && m_durum == 2) {   // 10 sn'de bir ping (aktarıcıda bağlantıyı da canlı tutar)
        m_pingSaat.start();
        cerceve('P', QByteArray::number(QDateTime::currentDateTime().toTime_t()));
    }
    emit istatistik();
}

// ---------------- Oturum ----------------

void Uzak::pencereListesiIste() { cerceve('L', QByteArray()); }

void Uzak::kaynakSec(const QString &s)
{
    simdiGonder();
    m_z[0] = 0; m_z[1] = 0; m_z[2] = 10000; m_z[3] = 10000; m_zoom = 1.0; m_genel = false; emit zoomChanged();
    m_ix = 5000; m_iy = 5000; emit imlecChanged();
    cerceve('S', s.toUtf8());
    m_gonderiliyor = true; emit bekleyenChanged();
}

void Uzak::girdiEkle(const QString &satir)
{
    if (m_durum != 2) return;
    if (m_kip == "akis") {
        cerceve('I', satir.toUtf8());
        return;
    }
    m_bekleyen << satir;
    m_paket.start();                  // her girdide yeniden: son girdiden 1 sn sonra
    emit bekleyenChanged();
}

void Uzak::paketGonder()
{
    m_paket.stop();
    if (m_durum != 2) return;
    // Bekleyen imleç hareketi: son tıklamadan sonra imleç kıpırdadıysa oraya götür
    if (!m_bekleyen.isEmpty() && m_bekleyen.last() == "#M") m_bekleyen.removeLast();
    QStringList satirlar;
    foreach (const QString &s, m_bekleyen) {
        if (s == "#M") continue;
        if (s == "#Z") continue;
        satirlar << s;
    }
    const bool zoomVar = m_bekleyen.contains("#Z");
    m_bekleyen.clear();
    if (zoomVar) zoomGonder();
    satirlar << QString("M %1 %2").arg(m_ix).arg(m_iy);   // imleci son konumda bırak
    cerceve('I', satirlar.join("\n").toUtf8());
    m_gonderiliyor = true;
    emit bekleyenChanged();
}

void Uzak::simdiGonder()
{
    if (!m_bekleyen.isEmpty()) paketGonder();
}

void Uzak::imleciGorunumdeTut()
{
    if (m_zoom <= 1.0) return;
    const int w = m_z[2] - m_z[0], h = m_z[3] - m_z[1];
    const int pay = w / 10;
    int x1 = m_z[0], y1 = m_z[1];
    if (m_ix < x1 + pay) x1 = m_ix - pay;
    else if (m_ix > x1 + w - pay) x1 = m_ix + pay - w;
    const int payY = h / 10;
    if (m_iy < y1 + payY) y1 = m_iy - payY;
    else if (m_iy > y1 + h - payY) y1 = m_iy + payY - h;
    x1 = qBound(0, x1, 10000 - w); y1 = qBound(0, y1, 10000 - h);
    if (x1 != m_z[0] || y1 != m_z[1]) {
        m_z[0] = x1; m_z[1] = y1; m_z[2] = x1 + w; m_z[3] = y1 + h;
        emit zoomChanged();
        if (m_kip == "akis") zoomGonder();
        else if (!m_bekleyen.contains("#Z")) { m_bekleyen << "#Z"; m_paket.start(); emit bekleyenChanged(); }
    }
}

void Uzak::tasi(int dx, int dy)
{
    // dx, dy: görünüm (ekrandaki bölge) onbinde biri -> kaynak koordinatına
    const int w = m_z[2] - m_z[0], h = m_z[3] - m_z[1];
    const int nx = m_ix + dx * w / 10000, ny = m_iy + dy * h / 10000;
    // Yakınlaştırmada görünen bölge "önden" kaymaz: imleç bölgenin kenarına dayanıp itildikçe kayar
    bool zoomDegisti = false;
    if (m_zoom > 1.0) {
        int x1 = m_z[0], y1 = m_z[1];
        if (nx < x1) x1 = nx; else if (nx > x1 + w) x1 = nx - w;
        if (ny < y1) y1 = ny; else if (ny > y1 + h) y1 = ny - h;
        x1 = qBound(0, x1, 10000 - w); y1 = qBound(0, y1, 10000 - h);
        if (x1 != m_z[0] || y1 != m_z[1]) { m_z[0] = x1; m_z[1] = y1; m_z[2] = x1 + w; m_z[3] = y1 + h; zoomDegisti = true; }
    }
    // Tüm görüntünün kenarına dayanıp itince sayfayı kaydır (tekerlek): alt/üst dikey, sağ/sol yatay
    int tekerY = 0, tekerX = 0;
    if (ny > 10000 && dy > 0) tekerY = -1; else if (ny < 0 && dy < 0) tekerY = 1;
    if (nx > 10000 && dx > 0) tekerX = 1; else if (nx < 0 && dx < 0) tekerX = -1;
    m_ix = qBound(0, nx, 10000);
    m_iy = qBound(0, ny, 10000);
    emit imlecChanged();
    if (zoomDegisti) {
        emit zoomChanged();
        if (m_kip == "akis") zoomGonder();
        else if (!m_bekleyen.contains("#Z")) { m_bekleyen << "#Z"; m_paket.start(); emit bekleyenChanged(); }
    }
    if (m_durum != 2) return;
    if (m_kip == "akis") cerceve('I', QString("M %1 %2").arg(m_ix).arg(m_iy).toUtf8());
    else { if (m_bekleyen.isEmpty() || m_bekleyen.last() != "#M") m_bekleyen << "#M"; m_paket.start(); emit bekleyenChanged(); }
    if (tekerY) tekerlek(tekerY);
    if (tekerX) yatay(tekerX);
}

void Uzak::imlecGorunumde(double vx, double vy)
{
    vx = qBound(0.0, vx, 1.0); vy = qBound(0.0, vy, 1.0);
    m_ix = m_z[0] + int(vx * (m_z[2] - m_z[0]));
    m_iy = m_z[1] + int(vy * (m_z[3] - m_z[1]));
    emit imlecChanged();
}

void Uzak::tikla(const QString &d)
{
    const QString xy = QString(" %1 %2").arg(m_ix).arg(m_iy);
    if (d == "2") { girdiEkle("C L" + xy); girdiEkle("C L" + xy); }        // çift tık
    else if (d == "D") girdiEkle("D L" + xy);                                // sürükle: bas
    else if (d == "U") girdiEkle("U L" + xy);                                // sürükle: bırak
    else girdiEkle("C " + d + xy);
}

void Uzak::tekerlek(int n) { girdiEkle(QString("W %1").arg(n)); }
void Uzak::yatay(int n) { girdiEkle(QString("X %1").arg(n)); }

// s tuşu: 1x <-> 2x (imleç ortada)
void Uzak::zoomDongu()
{
    if (m_zoom > 1.01) { yakinlas(0); return; }
    m_zoom = 2.0;
    const int w = int(10000 / m_zoom), h = int(10000 / m_zoom);
    const int x1 = qBound(0, m_ix - w / 2, 10000 - w), y1 = qBound(0, m_iy - h / 2, 10000 - h);
    m_z[0] = x1; m_z[1] = y1; m_z[2] = x1 + w; m_z[3] = y1 + h;
    emit zoomChanged();
    if (m_durum != 2) return;
    simdiGonder();
    zoomGonder();
    m_gonderiliyor = true; emit bekleyenChanged();
}

// Yakınlaştırmadayken görünen bölgeyi kaydır (dx, dy: -1/0/+1, bölgenin dörtte biri kadar).
// İmleç de aynı miktarda kayar ki görüntü imlece geri dönmesin.
void Uzak::kaydir(int dx, int dy)
{
    if (m_zoom <= 1.0) return;
    const int w = m_z[2] - m_z[0], h = m_z[3] - m_z[1];
    const int x1 = qBound(0, m_z[0] + dx * w / 6, 10000 - w);   // adım: bölgenin altıda biri
    const int y1 = qBound(0, m_z[1] + dy * h / 6, 10000 - h);
    if (x1 == m_z[0] && y1 == m_z[1]) return;
    m_ix = qBound(0, m_ix + (x1 - m_z[0]), 10000); m_iy = qBound(0, m_iy + (y1 - m_z[1]), 10000);
    m_z[0] = x1; m_z[1] = y1; m_z[2] = x1 + w; m_z[3] = y1 + h;
    emit zoomChanged(); emit imlecChanged();
    if (m_durum != 2) return;
    if (m_kip == "akis") zoomGonder();
    else if (!m_bekleyen.contains("#Z")) { m_bekleyen << "#Z"; m_paket.start(); emit bekleyenChanged(); }
    else m_paket.start();
}
void Uzak::tus(const QString &kombo) { girdiEkle("K " + kombo.trimmed().toLower()); }

void Uzak::yaz(const QString &metin, bool enterBas)
{
    if (m_durum != 2) return;
    simdiGonder();                          // önce bekleyen tıklamalar (metin kutusuna odak)
    QString t = metin;
    t.replace("\r\n", "\n"); t.replace('\r', '\n');
    if (enterBas) t += "\n";
    if (t.isEmpty()) return;
    cerceve('Y', t.toUtf8());
    m_gonderiliyor = true; emit bekleyenChanged();
    log("yazi gonderildi (" + QString::number(metin.length()) + " karakter)");
}

void Uzak::genelAc()
{
    if (m_durum != 2 || m_genel) return;
    simdiGonder();                              // bekleyen tiklamalar once gitsin
    m_genel = true;
    emit zoomChanged();
    cerceve('Z', QByteArray("0 0 10000 10000"));     // tum ekran (telefon genisliginde: dusuk cozunurluk)
    m_gonderiliyor = true; emit bekleyenChanged();
}

void Uzak::genelSec(double vx, double vy, bool bitir)
{
    if (!m_genel) return;
    // yakinlastirma yoksa 2x ile acilir
    if (m_zoom <= 1.01) m_zoom = 2.0;
    const int w = int(10000 / m_zoom), h = int(10000 / m_zoom);
    const int cx = qBound(0, int(vx * 10000), 10000), cy = qBound(0, int(vy * 10000), 10000);
    const int x1 = qBound(0, cx - w / 2, 10000 - w), y1 = qBound(0, cy - h / 2, 10000 - h);
    m_z[0] = x1; m_z[1] = y1; m_z[2] = x1 + w; m_z[3] = y1 + h;
    m_ix = qBound(x1, cx, x1 + w); m_iy = qBound(y1, cy, y1 + h);       // imlec de oraya
    emit imlecChanged();
    if (bitir) genelKapat(); else emit zoomChanged();
}

void Uzak::genelKapat()
{
    if (!m_genel) return;
    m_genel = false;
    emit zoomChanged();
    if (m_durum != 2) return;
    zoomGonder();                               // secilen (ya da eski) bolgeye don
    m_gonderiliyor = true; emit bekleyenChanged();
}

void Uzak::zoomGonder()
{
    cerceve('Z', QString("%1 %2 %3 %4").arg(m_z[0]).arg(m_z[1]).arg(m_z[2]).arg(m_z[3]).toUtf8());
}

void Uzak::yakinlas(int yon)
{
    int i = 0;
    for (int k = 0; k < KZoomSayisi; ++k) if (KZoomlar[k] <= m_zoom + 0.01) i = k;   // 2,5x gibi ara değerler de
    if (yon == 0) i = 0; else i = qBound(0, i + (yon > 0 ? 1 : -1), KZoomSayisi - 1);
    m_zoom = KZoomlar[i];
    const int w = int(10000 / m_zoom), h = int(10000 / m_zoom);
    int x1 = qBound(0, m_ix - w / 2, 10000 - w), y1 = qBound(0, m_iy - h / 2, 10000 - h);
    m_z[0] = x1; m_z[1] = y1; m_z[2] = x1 + w; m_z[3] = y1 + h;
    emit zoomChanged();
    if (m_durum != 2) return;
    simdiGonder();
    zoomGonder();
    m_gonderiliyor = true; emit bekleyenChanged();
}

void Uzak::yenile()
{
    simdiGonder();
    cerceve('F', QByteArray());
    m_gonderiliyor = true; emit bekleyenChanged();
}

void Uzak::arkaPlan(bool arka)
{
    if (arka == m_arka) return;
    m_arka = arka;
    if (m_durum != 2) return;
    if (arka) { simdiGonder(); cerceve('A', "fps=0"); log("arka plan: kare durduruldu"); }
    else { cerceve('A', QString("fps=%1").arg(m_fps).toUtf8()); cerceve('F', QByteArray()); log("on plan"); }
}

bool Uzak::eventFilter(QObject *o, QEvent *e)
{
    if (e->type() == QEvent::ApplicationDeactivate) arkaPlan(true);
    else if (e->type() == QEvent::ApplicationActivate) arkaPlan(false);
    return QObject::eventFilter(o, e);
}

void Uzak::arkaPlanaAl()
{
#ifdef Q_OS_SYMBIAN
    TApaTask t(CCoeEnv::Static()->WsSession());
    t.SetWgId(CCoeEnv::Static()->RootWin().Identifier());
    t.SendToBackground();
#endif
    arkaPlan(true);
}

// ---------------- Sunucudaki çevrimiçi PC'ler ----------------

void Uzak::pcListesiIste()
{
    if (m_anahtar.isEmpty()) { emit pcListesi(QVariantList(), Dil::t("Önce sunucu parolasını girin")); return; }
    QNetworkRequest r(QUrl(m_sunucu + "/uzak/liste"));
    r.setRawHeader("X-Api-Key", m_anahtar.toUtf8()); r.setRawHeader("X-Lang", Dil::kodu());
    r.setRawHeader("User-Agent", "BelleRemote/1.0 (Symbian Belle)");
    QNetworkReply *rep = m_nam->get(r);
    connect(rep, SIGNAL(finished()), this, SLOT(onPcListesi()));
}

void Uzak::onPcListesi()
{
    QNetworkReply *r = qobject_cast<QNetworkReply *>(sender());
    r->deleteLater();
    if (r->error() != QNetworkReply::NoError) {
        const int code = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        QString h = code == 403 ? Dil::t("Sunucu parolası hatalı")
                  : code == 404 ? Dil::t("Sunucuda uzak masaüstü aktarıcısı yok (güncellenmemiş)")
                  : Dil::t("Sunucuya ulaşılamadı: ") + r->errorString();
        if (m_profilSorgu) {                 // liste alınamadı: kayıtlı adresle dene
            m_profilSorgu = false;
            log("profil: liste alinamadi, kayitli adres");
            m_isTur = 3; isYap();
            return;
        }
        emit pcListesi(QVariantList(), h);
        return;
    }
    // {"pcler":[{"ad":"X","lan":"1.2.3.4:5680","sure":12}],...}  (küçük, düzenli JSON; regexp yeter)
    const QString t = QString::fromUtf8(r->readAll());
    QVariantList out;
    QRegExp rx("\\{\"ad\":\"((?:[^\"\\\\]|\\\\.)*)\",\"lan\":\"([^\"]*)\",\"sure\":(\\d+)");
    int pos = 0;
    while ((pos = rx.indexIn(t, pos)) >= 0) {
        QVariantMap m;
        QString ad = rx.cap(1); ad.replace("\\\"", "\""); ad.replace("\\\\", "\\");
        m["ad"] = ad; m["lan"] = rx.cap(2); m["sure"] = rx.cap(3).toInt();
        out << m;
        pos += rx.matchedLength();
    }
    if (m_profilSorgu) {
        m_profilSorgu = false;
        bool bulundu = false;
        foreach (const QVariant &v, out) {
            const QVariantMap m = v.toMap();
            if (m.value("ad").toString() == m_isPc) { m_isLan = m.value("lan").toString(); bulundu = true; break; }
        }
        log(QString("profil: ") + (bulundu ? "sunucuda, simdiki adres " + m_isLan : "sunucuda yok, kayitli adres " + m_isLan));
        if (!bulundu && !ayniAg(m_isLan)) {
            durumYap(0, Dil::t("%1 şu an çevrimiçi değil (PC açık ve 'Sunucu' etkin mi?)").arg(m_isPc));
            emit mesaj(m_durumMetni);
        } else {
            m_isTur = 3; isYap();
        }
    }
    emit pcListesi(out, QString());
}

// ---------------- Sunucu tarayicisi ----------------

void Uzak::baglanTarayici() { baglanSunucu("tarayici"); }

void Uzak::git(const QString &s)
{
    const QString t = temizle(s);
    if (t.isEmpty() || m_durum != 2) return;
    simdiGonder();
    m_z[0] = 0; m_z[1] = 0; m_z[2] = 10000; m_z[3] = 10000; m_zoom = 1.0; m_genel = false; emit zoomChanged();
    cerceve('U', t.toUtf8());
    m_gonderiliyor = true; emit bekleyenChanged();
    log("git " + t.left(80));
}

void Uzak::tarayiciKomut(const QString &k)
{
    if (m_durum != 2) return;
    simdiGonder();
    cerceve('B', k.toUtf8());
    m_gonderiliyor = true; emit bekleyenChanged();
}

void Uzak::indirmeIslem(const QString &id, const QString &islem)
{
    cerceve('d', (islem + " " + id).toUtf8());
}

void Uzak::telefonaIndir(const QString &id, const QString &ad)
{
    if (m_dl) { emit mesaj(Dil::t("Başka bir indirme sürüyor")); return; }
#if defined(Q_OS_SYMBIAN)
    const QString klasor = Depo::yol("Downloads");
#else
    const QString klasor = QDir::homePath() + "/BelleRemote/indirilen";
#endif
    QDir().mkpath(klasor);
    QString temiz = ad;
    temiz.replace(QRegExp("[\\\\/:*?\"<>|]"), "_");
    m_dlYol = klasor + "/" + temiz;
    if (QFile::exists(m_dlYol)) {
        const int nokta = temiz.lastIndexOf('.');
        const QString ek = nokta > 0 ? temiz.mid(nokta) : QString();
        const QString kok = nokta > 0 ? temiz.left(nokta) : temiz;
        for (int i = 2; i < 100 && QFile::exists(m_dlYol); ++i) m_dlYol = klasor + "/" + kok + QString(" (%1)").arg(i) + ek;
    }
    m_dlDosya = new QFile(m_dlYol + ".part", this);
    if (!m_dlDosya->open(QIODevice::WriteOnly)) { delete m_dlDosya; m_dlDosya = 0; emit mesaj(Dil::t("Dosya yazılamıyor: ") + m_dlYol); return; }
    QNetworkRequest r(QUrl(m_sunucu + "/uzak/indir/" + id));
    r.setRawHeader("X-Api-Key", m_anahtar.toUtf8()); r.setRawHeader("X-Lang", Dil::kodu());
    r.setRawHeader("User-Agent", "BelleRemote/1.0 (Symbian Belle)");
    m_dl = m_nam->get(r);
    connect(m_dl, SIGNAL(readyRead()), this, SLOT(onIndirmeVeri()));
    connect(m_dl, SIGNAL(downloadProgress(qint64,qint64)), this, SLOT(onIndirmeIlerleme(qint64,qint64)));
    connect(m_dl, SIGNAL(finished()), this, SLOT(onIndirmeSon()));
    m_dlAd = ad; m_dlYuzde = 0; emit indirmeChanged();
    indirmeIslem(id, "telefon");
    log("telefona indir " + ad);
}

void Uzak::indirmeIptal() { if (m_dl) m_dl->abort(); }

void Uzak::onIndirmeVeri() { if (m_dl && m_dlDosya) m_dlDosya->write(m_dl->readAll()); }

void Uzak::onIndirmeIlerleme(qint64 r, qint64 t)
{
    const int y = t > 0 ? int(r * 100 / t) : 0;
    if (y != m_dlYuzde) { m_dlYuzde = y; emit indirmeChanged(); }
}

void Uzak::onIndirmeSon()
{
    QNetworkReply *r = m_dl;
    m_dl = 0;
    if (m_dlDosya) { m_dlDosya->write(r->readAll()); m_dlDosya->close(); }
    const bool ok = r->error() == QNetworkReply::NoError;
    r->deleteLater();
    if (ok) {
        QFile::remove(m_dlYol);
        QFile::rename(m_dlYol + ".part", m_dlYol);
        log("indirildi " + m_dlYol);
        emit indirmeBitti(true, Dil::t("İndirildi: ") + m_dlYol);
    } else {
        QFile::remove(m_dlYol + ".part");
        log("indirme hatasi " + r->errorString());
        emit indirmeBitti(false, Dil::t("İndirilemedi: ") + r->errorString());
    }
    delete m_dlDosya; m_dlDosya = 0;
    m_dlYuzde = -1; m_dlAd.clear(); emit indirmeChanged();
}
// ---------------- Sik kullanilanlar ----------------

QVariantList Uzak::favoriler() const
{
    QVariantList out;
    QSettings s(m_ayarDosya, QSettings::IniFormat);
    const int n = s.beginReadArray("favoriler");
    for (int i = 0; i < n; ++i) {
        s.setArrayIndex(i);
        QVariantMap m;
        m["adres"] = s.value("adres").toString();
        m["baslik"] = s.value("baslik").toString();
        out << m;
    }
    s.endArray();
    return out;
}

static void favoriYaz(QSettings &s, const QVariantList &l)
{
    s.remove("favoriler");
    s.beginWriteArray("favoriler", l.size());
    for (int i = 0; i < l.size(); ++i) {
        s.setArrayIndex(i);
        const QVariantMap m = l.at(i).toMap();
        s.setValue("adres", m.value("adres")); s.setValue("baslik", m.value("baslik"));
    }
    s.endArray();
}

bool Uzak::favoriEkle(const QString &adres, const QString &baslik)
{
    const QString a = adres.trimmed();
    if (a.isEmpty()) return false;
    QVariantList l = favoriler();
    for (int i = 0; i < l.size(); ++i) if (l.at(i).toMap().value("adres").toString() == a) return false;
    QVariantMap m;
    m["adres"] = a; m["baslik"] = baslik.trimmed().isEmpty() ? a : baslik.trimmed().left(80);
    l.prepend(m);
    while (l.size() > 60) l.removeLast();
    QSettings s(m_ayarDosya, QSettings::IniFormat);
    favoriYaz(s, l);
    log("favori eklendi " + a.left(80));
    return true;
}

void Uzak::favoriSil(int i)
{
    QVariantList l = favoriler();
    if (i < 0 || i >= l.size()) return;
    l.removeAt(i);
    QSettings s(m_ayarDosya, QSettings::IniFormat);
    favoriYaz(s, l);
}
// ---------------- Tarayici penceresi boyutu ----------------

QString Uzak::gorunumMetni() const
{
    const int g = qBound(320, int(m_alanG * m_gorunumOlcek + 0.5), 1600);
    const int y = qBound(240, int(m_alanY * m_gorunumOlcek + 0.5), 1600);
    return QString("%1x%2").arg(g).arg(y);
}

void Uzak::setAlan(int g, int y)
{
    if (g < 100 || y < 100 || (g == m_alanG && y == m_alanY)) return;
    m_alanG = g; m_alanY = y;
    if (m_durum == 2 && m_tarayici) cerceve('A', ("gorunum=" + gorunumMetni() + "\ngenislik=" + gorunumMetni().section('x', 0, 0)).toUtf8());
}

void Uzak::setGorunumOlcek(double o)
{
    m_gorunumOlcek = qBound(1.0, o, 2.0);
    ayarKaydet(); emit ayarChanged();
    if (m_durum == 2 && m_tarayici) { cerceve('A', ("gorunum=" + gorunumMetni() + "\ngenislik=" + gorunumMetni().section('x', 0, 0)).toUtf8()); m_gonderiliyor = true; emit bekleyenChanged(); }
}
// Belle Browser "Belle Remote'ta aç": C:/Data/E6/belleremote_ac.txt (son 2 dakika icinde yazildiysa)
QString Uzak::acilacakAdres()
{
#if defined(Q_OS_SYMBIAN)
    const QString dosya = "C:/Data/E6/belleremote_ac.txt";
#else
    const QString dosya = QDir::homePath() + "/E6/belleremote_ac.txt";
#endif
    QFileInfo fi(dosya);
    if (!fi.exists()) return QString();
    QString a;
    if (fi.lastModified().secsTo(QDateTime::currentDateTime()) < 120) {
        QFile f(dosya);
        if (f.open(QIODevice::ReadOnly)) a = QString::fromUtf8(f.readAll()).trimmed();
    }
    QFile::remove(dosya);
    return a;
}