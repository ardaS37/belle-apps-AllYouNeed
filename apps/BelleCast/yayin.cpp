#include "yayin.h"

#include <QtCore/QDir>
#include <QtCore/QFileInfo>
#include <QtCore/QDateTime>
#include <QtCore/QTextCodec>
#include <QtCore/QRegExp>
#include <QtCore/QXmlStreamReader>
#include <QtGui/QDesktopServices>
#include <QtNetwork/QTcpServer>
#include <QtNetwork/QTcpSocket>
#include <QtNetwork/QSslSocket>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkRequest>
#include <QtNetwork/QNetworkReply>

static const char *KAjan = "BelleCast/0.1 (Symbian; Nokia E6)";
static const qint64 KSinir = 256 * 1024;      // oynaticiya bekleyen en cok veri (fazlasinda uzaktan okuma durur)
static const qint64 KParca = 16 * 1024;

// ======================================================================= YayinBaglanti

YayinBaglanti::YayinBaglanti(QTcpSocket *oyn, Yayin *y)
    : QObject(y), m_oyn(oyn), m_y(y), m_istekTamam(false), m_id(0), m_yonlendirme(0),
      m_baslikTamam(false), m_chunked(false), m_chunkKalan(-1), m_metaAralik(0), m_metaSay(0), m_metaBoy(-1),
      m_oynBaslikGitti(false), m_aktarilan(0)
{
    connect(m_oyn, SIGNAL(readyRead()), this, SLOT(oynaticiOku()));
    connect(m_oyn, SIGNAL(disconnected()), this, SLOT(oynaticiKoptu()));
    connect(m_oyn, SIGNAL(bytesWritten(qint64)), this, SLOT(pompala()));
}

YayinBaglanti::~YayinBaglanti()
{
    if (m_uzak) { m_uzak->abort(); m_uzak->deleteLater(); }
}

void YayinBaglanti::oynaticiOku()
{
    if (!m_oyn) return;
    if (m_istekTamam) { m_oyn->readAll(); return; }
    m_istek += m_oyn->readAll();
    if (m_istek.size() > 16 * 1024) { bitir("400 Bad Request"); return; }
    const int son = m_istek.indexOf("\r\n\r\n");
    if (son < 0) return;
    m_istekTamam = true;
    const QList<QByteArray> ilk = m_istek.left(m_istek.indexOf("\r\n")).split(' ');
    if (ilk.size() < 2 || (ilk.at(0) != "GET" && ilk.at(0) != "HEAD")) { bitir("405 Method Not Allowed"); return; }
    if (ilk.at(0) == "HEAD") {
        // oynatici once tur soruyorsa: sonsuz akis, boyut yok
        m_oyn->write("HTTP/1.0 200 OK\r\nContent-Type: audio/mpeg\r\nConnection: close\r\n\r\n");
        m_oyn->disconnectFromHost();
        return;
    }
    QByteArray yol = ilk.at(1);
    const QList<QByteArray> p = yol.split('/');          // /y/<id>.<uzanti>
    if (p.size() < 3 || p.at(1) != "y") { bitir("404 Not Found"); return; }
    m_id = p.at(2).split('.').value(0).toInt();
    const QString u = m_y->urlIcin(m_id);
    if (u.isEmpty()) { bitir("404 Not Found"); return; }
    m_y->kayit("akis basladi #" + QString::number(m_id) + " " + QUrl(u).host());
    if (QUrl(u).path().toLower().endsWith(".m3u8") || QUrl(u).path().toLower().endsWith(".m3u8/")) {
        // HLS: baglantiyi HlsAkis devralir
        QTcpSocket *s = m_oyn;
        disconnect(s, 0, this, 0);
        m_oyn = 0;
        new HlsAkis(s, m_y, m_id, QUrl(u));
        deleteLater();
        return;
    }
    baglan(QUrl(u));
}

void YayinBaglanti::oynaticiKoptu()
{
    m_y->kayit(QString("akis bitti #%1 (%2 KB)").arg(m_id).arg(m_aktarilan / 1024));
    if (m_uzak) { disconnect(m_uzak, 0, this, 0); m_uzak->abort(); }
    if (m_oyn) m_oyn->deleteLater();
    deleteLater();
}

void YayinBaglanti::baglan(const QUrl &u)
{
    m_url = u;
    m_ham.clear();
    m_baslikTamam = false;
    m_chunked = false;
    m_chunkKalan = -1;
    m_chunkTampon.clear();
    m_metaAralik = 0;
    m_metaBoy = -1;
    if (m_uzak) { disconnect(m_uzak, 0, this, 0); m_uzak->abort(); m_uzak->deleteLater(); }
    const bool ssl = u.scheme().toLower() == "https";
    QTcpSocket *s = ssl ? new QSslSocket(this) : new QTcpSocket(this);
    m_uzak = s;
    s->setReadBufferSize(64 * 1024);
    connect(s, SIGNAL(readyRead()), this, SLOT(uzakOku()));
    connect(s, SIGNAL(disconnected()), this, SLOT(uzakKoptu()));
    connect(s, SIGNAL(error(QAbstractSocket::SocketError)), this, SLOT(uzakHata()));
    const quint16 port = quint16(u.port(ssl ? 443 : 80));
    if (ssl) {
        QSslSocket *ss = static_cast<QSslSocket *>(s);
        connect(ss, SIGNAL(encrypted()), this, SLOT(uzakBaglandi()));
        ss->connectToHostEncrypted(u.host(), port);
    } else {
        connect(s, SIGNAL(connected()), this, SLOT(uzakBaglandi()));
        s->connectToHost(u.host(), port);
    }
}

void YayinBaglanti::uzakBaglandi()
{
    if (!m_uzak) return;
    QByteArray yol = m_url.encodedPath();
    if (yol.isEmpty()) yol = "/";
    if (m_url.hasQuery()) yol += "?" + m_url.encodedQuery();
    QByteArray host = m_url.host().toUtf8();
    const bool ssl = m_url.scheme().toLower() == "https";
    if (m_url.port() > 0 && m_url.port() != (ssl ? 443 : 80)) host += ":" + QByteArray::number(m_url.port());
    QByteArray r = "GET " + yol + " HTTP/1.0\r\nHost: " + host + "\r\nUser-Agent: " + KAjan
                 + "\r\nAccept: */*\r\nIcy-MetaData: 1\r\nConnection: close\r\n\r\n";
    m_uzak->write(r);
}

void YayinBaglanti::uzakHata()
{
    if (!m_uzak) return;
    if (m_baslikTamam && m_uzak->error() == QAbstractSocket::RemoteHostClosedError) return;   // normal kapanis
    m_y->kayit("akis hatasi #" + QString::number(m_id) + ": " + m_uzak->errorString());
    if (!m_oynBaslikGitti) bitir("502 Bad Gateway");
}

void YayinBaglanti::uzakKoptu()
{
    if (!m_uzak) return;
    if (m_uzak->bytesAvailable() > 0) uzakOku();
    if (!m_oynBaslikGitti) { bitir("502 Bad Gateway"); return; }
    if (m_oyn) m_oyn->disconnectFromHost();          // bekleyen veri gittikten sonra kapanir
}

void YayinBaglanti::pompala() { uzakOku(); }

void YayinBaglanti::uzakOku()
{
    if (!m_uzak || !m_oyn) return;
    while (m_uzak && m_uzak->bytesAvailable() > 0 && m_oyn && m_oyn->bytesToWrite() < KSinir) {
        const QByteArray d = m_uzak->read(KParca);
        if (d.isEmpty()) break;
        if (!m_baslikTamam) {
            m_ham += d;
            if (m_ham.size() > 32 * 1024) { bitir("502 Bad Gateway"); return; }
            if (m_ham.indexOf("\r\n\r\n") < 0 && m_ham.indexOf("\n\n") < 0) continue;
            basliklariIsle();
            continue;
        }
        govdeIsle(d);
    }
}

void YayinBaglanti::basliklariIsle()
{
    int son = m_ham.indexOf("\r\n\r\n"), atla = 4;
    const int son2 = m_ham.indexOf("\n\n");
    if (son < 0 || (son2 >= 0 && son2 < son)) { son = son2; atla = 2; }
    const QByteArray bas = m_ham.left(son);
    const QByteArray kalan = m_ham.mid(son + atla);
    m_ham.clear();
    const QList<QByteArray> satirlar = bas.split('\n');
    const QList<QByteArray> durum = satirlar.value(0).trimmed().split(' ');
    const int kod = durum.value(1).toInt();       // "ICY 200 OK" ya da "HTTP/1.1 200 OK"
    QByteArray konum;
    m_tur.clear();
    for (int i = 1; i < satirlar.size(); ++i) {
        const QByteArray s = satirlar.at(i).trimmed();
        const int iki = s.indexOf(':');
        if (iki <= 0) continue;
        const QByteArray ad = s.left(iki).trimmed().toLower(), deger = s.mid(iki + 1).trimmed();
        if (ad == "location") konum = deger;
        else if (ad == "content-type") m_tur = deger;
        else if (ad == "icy-metaint") m_metaAralik = deger.toInt();
        else if (ad == "transfer-encoding" && deger.toLower().contains("chunked")) m_chunked = true;
    }
    if (kod >= 300 && kod < 400 && !konum.isEmpty()) {
        if (++m_yonlendirme > 6) { bitir("502 Bad Gateway"); return; }
        const QUrl yeni = m_url.resolved(QUrl::fromEncoded(konum));
        m_y->kayit("akis yonlendirme -> " + yeni.host());
        baglan(yeni);
        return;
    }
    if (kod < 200 || kod >= 300) {
        m_y->kayit(QString("akis yaniti %1 (%2)").arg(kod).arg(QString::fromLatin1(satirlar.value(0).trimmed())));
        bitir("502 Bad Gateway");
        return;
    }
    m_baslikTamam = true;
    m_metaSay = m_metaAralik;
    m_metaBoy = -1;
    m_y->kayit(QString("akis tur=%1 metaint=%2%3").arg(QString::fromLatin1(m_tur)).arg(m_metaAralik).arg(m_chunked ? " chunked" : ""));
    if (!kalan.isEmpty()) govdeIsle(kalan);
}

void YayinBaglanti::govdeIsle(const QByteArray &gelen)
{
    QByteArray d;
    if (m_chunked) {
        // chunked cozumu: "boyut\r\n veri \r\n"
        m_chunkTampon += gelen;
        for (;;) {
            if (m_chunkKalan < 0) {
                const int nl = m_chunkTampon.indexOf("\r\n");
                if (nl < 0) break;
                bool ok = false;
                m_chunkKalan = m_chunkTampon.left(nl).split(';').value(0).trimmed().toLongLong(&ok, 16);
                m_chunkTampon.remove(0, nl + 2);
                if (!ok) { m_chunkKalan = -1; continue; }
                if (m_chunkKalan == 0) { m_chunkTampon.clear(); break; }
            }
            if (m_chunkTampon.size() < m_chunkKalan + 2) {
                if (m_chunkTampon.size() > m_chunkKalan) break;            // yalnizca \r\n eksik
                d += m_chunkTampon;
                m_chunkKalan -= m_chunkTampon.size();
                m_chunkTampon.clear();
                break;
            }
            d += m_chunkTampon.left(int(m_chunkKalan));
            m_chunkTampon.remove(0, int(m_chunkKalan) + 2);
            m_chunkKalan = -1;
        }
    } else d = gelen;
    if (d.isEmpty()) return;
    if (m_metaAralik <= 0) { sesYaz(d); return; }
    // ICY ara verileri: her metaint ses baytindan sonra 1 bayt boy (x16) + o kadar metin
    int i = 0;
    const int n = d.size();
    while (i < n) {
        if (m_metaBoy < 0 && m_metaSay > 0) {
            const int al = qMin(m_metaSay, n - i);
            sesYaz(d.mid(i, al));
            i += al;
            m_metaSay -= al;
            continue;
        }
        if (m_metaBoy < 0) {                 // boy bayti
            m_metaBoy = uchar(d.at(i++)) * 16;
            m_meta.clear();
            if (m_metaBoy == 0) { m_metaBoy = -1; m_metaSay = m_metaAralik; }
            continue;
        }
        const int al = qMin(m_metaBoy - m_meta.size(), n - i);
        m_meta += d.mid(i, al);
        i += al;
        if (m_meta.size() >= m_metaBoy) {
            const int b = m_meta.indexOf("StreamTitle='");
            if (b >= 0) {
                int e = m_meta.indexOf("';", b + 13);
                if (e < 0) e = m_meta.indexOf('\'', b + 13);
                QByteArray ham = m_meta.mid(b + 13, e > b ? e - b - 13 : -1);
                while (ham.endsWith('\0')) ham.chop(1);
                // UTF-8 degilse Turkce Windows kodlamasi varsay
                QString t = QString::fromUtf8(ham);
                if (t.contains(QChar(0xFFFD))) { QTextCodec *c = QTextCodec::codecForName("windows-1254"); t = c ? c->toUnicode(ham) : QString::fromLatin1(ham); }
                m_y->baslikBildir(m_id, t.trimmed());
            }
            m_metaBoy = -1;
            m_metaSay = m_metaAralik;
        }
    }
}

void YayinBaglanti::sesYaz(const QByteArray &d)
{
    if (!m_oyn || d.isEmpty()) return;
    if (!m_oynBaslikGitti) {
        QByteArray tur = m_tur.isEmpty() ? QByteArray("audio/mpeg") : m_tur.split(';').value(0).trimmed();
        if (tur == "audio/aacp" || tur == "audio/x-aac") tur = "audio/aac";
        if (tur == "audio/mp3" || tur == "audio/x-mpeg") tur = "audio/mpeg";
        m_oyn->write("HTTP/1.0 200 OK\r\nContent-Type: " + tur + "\r\nCache-Control: no-cache\r\nConnection: close\r\n\r\n");
        m_oynBaslikGitti = true;
    }
    m_oyn->write(d);
    m_aktarilan += d.size();
    m_y->kayitYaz(m_id, d, m_tur);
}

void YayinBaglanti::bitir(const QByteArray &durum)
{
    if (m_uzak) { disconnect(m_uzak, 0, this, 0); m_uzak->abort(); }
    if (!m_oyn) return;
    if (!m_oynBaslikGitti) m_oyn->write("HTTP/1.0 " + durum + "\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");
    m_oyn->disconnectFromHost();
}

// ======================================================================= HlsAkis

static const qint64 KHlsSinir = 384 * 1024;   // oynaticida bu kadar veri bekliyorsa yeni parca cekme

HlsAkis::HlsAkis(QTcpSocket *oyn, Yayin *y, int id, const QUrl &liste)
    : QObject(y), m_oyn(oyn), m_y(y), m_id(id), m_liste(liste), m_sonSira(-1), m_hedefSure(6),
      m_bitti(false), m_baslikGitti(false), m_tsSesPid(-1), m_hata(0), m_aktarilan(0)
{
    connect(m_oyn, SIGNAL(disconnected()), this, SLOT(oynaticiKoptu()));
    connect(m_oyn, SIGNAL(bytesWritten(qint64)), this, SLOT(devam()));
    m_yenile.setSingleShot(true);
    connect(&m_yenile, SIGNAL(timeout()), this, SLOT(listeYenile()));
    m_y->kayit("hls basladi #" + QString::number(id));
    listeIste(liste);
}

HlsAkis::~HlsAkis()
{
    if (m_listeIstek) m_listeIstek->abort();
    if (m_parcaIstek) m_parcaIstek->abort();
}

void HlsAkis::oynaticiKoptu()
{
    m_y->kayit(QString("hls bitti #%1 (%2 KB)").arg(m_id).arg(m_aktarilan / 1024));
    m_yenile.stop();
    if (m_listeIstek) { disconnect(m_listeIstek, 0, this, 0); m_listeIstek->abort(); }
    if (m_parcaIstek) { disconnect(m_parcaIstek, 0, this, 0); m_parcaIstek->abort(); }
    if (m_oyn) m_oyn->deleteLater();
    deleteLater();
}

void HlsAkis::listeIste(const QUrl &u)
{
    if (m_listeIstek) return;
    QNetworkRequest r(u);
    r.setRawHeader("User-Agent", KAjan);
    m_listeIstek = m_y->nam()->get(r);
    connect(m_listeIstek, SIGNAL(finished()), this, SLOT(listeGeldi()));
}

void HlsAkis::listeYenile() { listeIste(m_liste); }

void HlsAkis::listeGeldi()
{
    QNetworkReply *r = m_listeIstek;
    if (!r) return;
    m_listeIstek = 0;
    r->deleteLater();
    const QUrl yon = r->attribute(QNetworkRequest::RedirectionTargetAttribute).toUrl();
    if (!yon.isEmpty()) { m_liste = r->url().resolved(yon); listeIste(m_liste); return; }
    if (r->error() != QNetworkReply::NoError) {
        m_y->kayit("hls liste hatasi: " + r->errorString());
        if (++m_hata > 5) { if (m_oyn) m_oyn->disconnectFromHost(); return; }
        m_yenile.start(3000);
        return;
    }
    m_hata = 0;
    listeIsle(r->readAll(), r->url());
}

void HlsAkis::listeIsle(const QByteArray &m, const QUrl &taban)
{
    const QList<QByteArray> satirlar = m.split('\n');
    // ana liste mi (varyantlar)? en dusuk bant genisligini sec (telefon icin yeterli)
    if (m.contains("#EXT-X-STREAM-INF")) {
        QUrl sec;
        qint64 enAz = -1;
        for (int i = 0; i < satirlar.size(); ++i) {
            const QByteArray s = satirlar.at(i).trimmed();
            if (!s.startsWith("#EXT-X-STREAM-INF")) continue;
            qint64 bw = 0;
            const int b = s.indexOf("BANDWIDTH=");
            if (b >= 0) bw = s.mid(b + 10).split(',').value(0).toLongLong();
            for (int j = i + 1; j < satirlar.size(); ++j) {
                const QByteArray a = satirlar.at(j).trimmed();
                if (a.isEmpty() || a.startsWith('#')) continue;
                if (enAz < 0 || (bw > 0 && bw < enAz)) { enAz = bw; sec = taban.resolved(QUrl::fromEncoded(a)); }
                break;
            }
        }
        if (sec.isValid()) { m_liste = sec; m_y->kayit("hls varyant " + QString::number(enAz / 1000) + " kbps"); listeIste(sec); }
        return;
    }
    if (m.contains("#EXT-X-KEY:METHOD=AES")) { m_y->kayit("hls sifreli, desteklenmiyor"); if (m_oyn) m_oyn->disconnectFromHost(); return; }
    qint64 sira = 0;
    QList<QPair<qint64, QUrl> > parcalar;
    for (int i = 0; i < satirlar.size(); ++i) {
        const QByteArray s = satirlar.at(i).trimmed();
        if (s.startsWith("#EXT-X-MEDIA-SEQUENCE:")) sira = s.mid(22).toLongLong();
        else if (s.startsWith("#EXT-X-TARGETDURATION:")) m_hedefSure = qMax(1, s.mid(22).toInt());
        else if (s.startsWith("#EXT-X-ENDLIST")) m_bitti = true;
        else if (!s.isEmpty() && !s.startsWith('#')) { parcalar << qMakePair(sira, taban.resolved(QUrl::fromEncoded(s))); ++sira; }
    }
    // ilk yuklemede canli yayinin son 3 parcasindan basla (gecikme az, tampon yeterli)
    if (m_sonSira < 0 && !m_bitti && parcalar.size() > 3) m_sonSira = parcalar.at(parcalar.size() - 4).first;
    for (int i = 0; i < parcalar.size(); ++i)
        if (parcalar.at(i).first > m_sonSira) { m_kuyruk << parcalar.at(i).second; m_sonSira = parcalar.at(i).first; }
    if (!m_bitti) m_yenile.start(qMax(2000, m_hedefSure * 1000 / 2));
    sonrakiParca();
}

void HlsAkis::devam() { sonrakiParca(); }

void HlsAkis::sonrakiParca()
{
    if (!m_oyn || m_parcaIstek || m_kuyruk.isEmpty()) {
        if (m_oyn && m_bitti && m_kuyruk.isEmpty() && !m_parcaIstek && m_oyn->bytesToWrite() == 0) m_oyn->disconnectFromHost();
        return;
    }
    if (m_oyn->bytesToWrite() > KHlsSinir) return;      // oynatici yetismiyor: bekle (bytesWritten ile devam)
    QNetworkRequest r(m_kuyruk.takeFirst());
    r.setRawHeader("User-Agent", KAjan);
    m_parcaIstek = m_y->nam()->get(r);
    connect(m_parcaIstek, SIGNAL(finished()), this, SLOT(parcaGeldi()));
}

void HlsAkis::parcaGeldi()
{
    QNetworkReply *r = m_parcaIstek;
    if (!r) return;
    m_parcaIstek = 0;
    r->deleteLater();
    if (r->error() != QNetworkReply::NoError) m_y->kayit("hls parca hatasi: " + r->errorString());
    else parcaYaz(r->readAll());
    sonrakiParca();
}

void HlsAkis::parcaYaz(QByteArray d)
{
    if (d.isEmpty()) return;
    if (uchar(d.at(0)) == 0x47 && d.size() >= 188) { d = tsSes(d); if (d.isEmpty()) return; }
    // basta (ve TS'den cikan seste) ID3 etiketleri: "ID3" + 2 surum + 1 bayrak + 4 bayt syncsafe boy
    while (d.size() >= 10 && d.startsWith("ID3")) {
        const uchar *p = (const uchar *)d.constData();
        const int boy = (p[6] << 21) | (p[7] << 14) | (p[8] << 7) | p[9];
        const int top = 10 + boy + ((p[5] & 0x10) ? 10 : 0);
        if (top > d.size()) return;
        d.remove(0, top);
    }
    if (d.isEmpty()) return;
    if (m_tur.isEmpty()) {
        const uchar a = uchar(d.at(0)), b = d.size() > 1 ? uchar(d.at(1)) : 0;
        m_tur = (a == 0xFF && (b & 0xF6) == 0xF0) ? QByteArray("audio/aac") : QByteArray("audio/mpeg");   // ADTS ise AAC
        m_y->kayit("hls tur " + QString::fromLatin1(m_tur));
    }
    yaz(d);
}

// MPEG-TS: ses PES paketlerinin yukunu birlestir (ilk ses akisi; PAT/PMT'ye gerek yok)
QByteArray HlsAkis::tsSes(const QByteArray &ts)
{
    QByteArray out;
    const uchar *p = (const uchar *)ts.constData();
    const int n = ts.size() - ts.size() % 188;
    for (int o = 0; o + 188 <= n; o += 188) {
        const uchar *k = p + o;
        if (k[0] != 0x47) continue;
        const bool bas = k[1] & 0x40;
        const int pid = ((k[1] & 0x1F) << 8) | k[2];
        const int af = (k[3] >> 4) & 3;
        int i = 4;
        if (af == 2) continue;                       // yalniz uyarlama alani
        if (af == 3) i += 1 + k[4];
        if (i >= 188) continue;
        if (bas && i + 9 <= 188 && k[i] == 0 && k[i + 1] == 0 && k[i + 2] == 1) {
            const int sid = k[i + 3];
            const bool ses = sid >= 0xC0 && sid <= 0xDF;
            if (m_tsSesPid < 0 && ses) m_tsSesPid = pid;
            if (pid != m_tsSesPid) continue;
            i += 9 + k[i + 8];                       // PES basligi
            if (i >= 188) continue;
        } else if (pid != m_tsSesPid) continue;
        out.append((const char *)k + i, 188 - i);
    }
    return out;
}

void HlsAkis::yaz(const QByteArray &d)
{
    if (!m_oyn) return;
    if (!m_baslikGitti) {
        m_oyn->write("HTTP/1.0 200 OK\r\nContent-Type: " + m_tur + "\r\nCache-Control: no-cache\r\nConnection: close\r\n\r\n");
        m_baslikGitti = true;
    }
    m_oyn->write(d);
    m_aktarilan += d.size();
    m_y->kayitYaz(m_id, d, m_tur);
}

// ======================================================================= Yayin

Yayin::Yayin(const QString &veriKlasoru, QObject *parent)
    : QObject(parent), m_veri(veriKlasoru), m_sunucu(new QTcpServer(this)), m_sonId(1),
      m_nam(new QNetworkAccessManager(this)), m_indirme(0), m_indirYon(0), m_iptal(false),
      m_kayitBoy(0), m_kayitBildirim(-1)
{
    QDir().mkpath(m_veri);
#if defined(Q_OS_SYMBIAN)
    m_indirKlasor = QDir("E:/").exists() ? QString::fromLatin1("E:/Podcasts") : QString::fromLatin1("C:/Data/Podcasts");
    m_kayitKlasor = QDir("E:/").exists() ? QString::fromLatin1("E:/Radyo Kayitlari") : QString::fromLatin1("C:/Data/Radyo Kayitlari");
#else
    m_indirKlasor = m_veri + "/Podcasts";
    m_kayitKlasor = m_veri + "/Radyo Kayitlari";
#endif
    QDir().mkpath(m_indirKlasor);
    QFile g(m_veri + "/gunluk.txt");
    if (g.open(QIODevice::ReadOnly)) {
        m_gunluk = QString::fromUtf8(g.readAll()).split('\n', QString::SkipEmptyParts);
        while (m_gunluk.size() > 150) m_gunluk.removeFirst();
    }
    connect(m_sunucu, SIGNAL(newConnection()), this, SLOT(yeniBaglanti()));
    if (!m_sunucu->listen(QHostAddress::LocalHost, 0)) kayit("aktarma sunucusu acilamadi: " + m_sunucu->errorString());
}

QString Yayin::aktarma(const QString &url)
{
    if (!m_sunucu->isListening() || url.isEmpty()) return url;
    int id = m_urlId.value(url, 0);
    if (!id) { id = m_sonId++; m_urlId.insert(url, id); m_idUrl.insert(id, url); }
    QString uz = QFileInfo(QUrl(url).path()).suffix().toLower();
    if (uz == "m3u8") uz = "aac";                       // HLS radyolar cogunlukla AAC
    if (uz != "mp3" && uz != "aac" && uz != "m4a" && uz != "ogg") uz = "mp3";
    return QString("http://127.0.0.1:%1/y/%2.%3").arg(m_sunucu->serverPort()).arg(id).arg(uz);
}

QString Yayin::yerelUrl(const QString &yol) const { return QUrl::fromLocalFile(yol).toString(); }

void Yayin::yeniBaglanti()
{
    while (m_sunucu->hasPendingConnections()) {
        QTcpSocket *s = m_sunucu->nextPendingConnection();
        if (s) new YayinBaglanti(s, this);
    }
}

void Yayin::baslikBildir(int id, const QString &baslik)
{
    const QString u = m_idUrl.value(id);
    if (u.isEmpty() || m_baslik.value(u) == baslik) return;
    m_baslik.insert(u, baslik);
    kayit("calan: " + baslik);
    emit baslikDegisti(u, baslik);
}

// ---- radyo kaydi ----

void Yayin::kayitBaslat(const QString &url, const QString &istasyon)
{
    if (!m_kayitUrl.isEmpty()) kayitDurdur();
    m_kayitUrl = url;
    m_kayitAd = istasyon;
    m_kayitYol.clear();              // dosya ilk ses geldiginde, turune gore uzantiyla acilir
    m_kayitBoy = 0;
    m_kayitBildirim = -1;
    m_kayitSaat.start();
    kayit("kayit basladi: " + istasyon);
    emit kayitDegisti();
}

void Yayin::kayitYaz(int id, const QByteArray &d, const QByteArray &tur)
{
    if (m_kayitUrl.isEmpty() || m_idUrl.value(id) != m_kayitUrl || d.isEmpty()) return;
    if (!m_kayit.isOpen()) {
        QString uz = QString::fromLatin1("mp3");
        const QByteArray t = tur.toLower();
        if (t.contains("aac")) uz = QString::fromLatin1("aac");
        else if (t.contains("ogg")) uz = QString::fromLatin1("ogg");
        else if (t.contains("mp4") || t.contains("m4a")) uz = QString::fromLatin1("m4a");
        QDir().mkpath(m_kayitKlasor);
        m_kayitYol = m_kayitKlasor + "/" + guvenliAd(m_kayitAd + " " + QDateTime::currentDateTime().toString("yyyy-MM-dd HH.mm")) + "." + uz;
        m_kayit.setFileName(m_kayitYol);
        if (!m_kayit.open(QIODevice::WriteOnly | QIODevice::Append)) {
            kayit("kayit dosyasi acilamadi: " + m_kayitYol);
            m_kayitUrl.clear();
            emit kayitDegisti();
            emit kayitBitti(QString(), 0);
            return;
        }
    }
    if (m_kayit.write(d) != d.size()) {         // kart doldu vb.
        kayit("kayit yazilamadi (yer dolu olabilir)");
        kayitDurdur();
        return;
    }
    m_kayitBoy += d.size();
    const int sn = m_kayitSaat.elapsed() / 1000;
    if (sn != m_kayitBildirim) { m_kayitBildirim = sn; emit kayitDegisti(); }
}

void Yayin::kayitDurdur()
{
    if (m_kayitUrl.isEmpty()) return;
    const QString yol = m_kayitYol;
    const double boy = double(m_kayitBoy);
    m_kayitUrl.clear();
    if (m_kayit.isOpen()) m_kayit.close();
    if (!yol.isEmpty() && boy < 4096) { QFile::remove(yol); kayit("kayit bos, silindi"); emit kayitDegisti(); emit kayitBitti(QString(), 0); return; }
    kayit(QString("kayit bitti: %1 (%2 KB)").arg(yol).arg(qint64(boy) / 1024));
    emit kayitDegisti();
    emit kayitBitti(yol, boy);
}

QVariantList Yayin::kayitlar() const
{
    QVariantList out;
    QDir d(m_kayitKlasor);
    foreach (const QFileInfo &fi, d.entryInfoList(QStringList() << "*.mp3" << "*.aac" << "*.ogg" << "*.m4a", QDir::Files, QDir::Time)) {
        QVariantMap m;
        m["yol"] = fi.absoluteFilePath();
        m["ad"] = fi.completeBaseName();
        m["boyut"] = double(fi.size());
        m["zaman"] = double(fi.lastModified().toMSecsSinceEpoch());
        m["uzanti"] = fi.suffix().toLower();
        out << m;
    }
    return out;
}

// ---- indirme ----

bool Yayin::indir(const QString &url, const QString &dosyaAdi)
{
    if (m_indirme) return false;
    m_indirAd = guvenliAd(dosyaAdi);
    m_indirYol = m_indirKlasor + "/" + m_indirAd;
    m_indirDosya.setFileName(m_indirYol + ".part");
    if (!m_indirDosya.open(QIODevice::WriteOnly | QIODevice::Truncate)) { emit indirmeBitti(false, m_indirYol, QString::fromUtf8("Dosya yazılamadı")); return false; }
    m_indirYon = 0;
    m_iptal = false;
    m_indirSaat.start();
    indirBaslat(QUrl(url));
    emit indirmeDegisti();
    kayit("indirme: " + m_indirAd);
    return true;
}

void Yayin::indirBaslat(const QUrl &u)
{
    QNetworkRequest r(u);
    r.setRawHeader("User-Agent", KAjan);
    m_indirme = m_nam->get(r);
    connect(m_indirme, SIGNAL(readyRead()), this, SLOT(indirOku()));
    connect(m_indirme, SIGNAL(downloadProgress(qint64,qint64)), this, SLOT(indirIlerle(qint64,qint64)));
    connect(m_indirme, SIGNAL(finished()), this, SLOT(indirBitti()));
}

void Yayin::indirOku()
{
    if (!m_indirme) return;
    const int kod = m_indirme->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (kod >= 300 && kod < 400) { m_indirme->readAll(); return; }
    m_indirDosya.write(m_indirme->readAll());
}

void Yayin::indirIlerle(qint64 a, qint64 t)
{
    const int ms = qMax(1, m_indirSaat.elapsed());
    emit indirmeIlerleme(double(a), double(t), int(a / 1024 * 1000 / ms));
}

void Yayin::indirmeIptal()
{
    if (!m_indirme) return;
    m_iptal = true;
    m_indirme->abort();
}

void Yayin::indirBitti()
{
    QNetworkReply *r = m_indirme;
    if (!r) return;
    r->deleteLater();
    const int kod = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QUrl yon = r->attribute(QNetworkRequest::RedirectionTargetAttribute).toUrl();
    if (!m_iptal && kod >= 300 && kod < 400 && !yon.isEmpty() && ++m_indirYon <= 8) {
        m_indirDosya.resize(0);
        m_indirDosya.seek(0);
        indirBaslat(r->url().resolved(yon));
        return;
    }
    m_indirme = 0;
    m_indirDosya.close();
    const bool ok = !m_iptal && r->error() == QNetworkReply::NoError && kod >= 200 && kod < 300;
    QString mesaj;
    if (ok) {
        QFile::remove(m_indirYol);
        QFile::rename(m_indirYol + ".part", m_indirYol);
    } else {
        QFile::remove(m_indirYol + ".part");
        mesaj = m_iptal ? QString::fromUtf8("İptal edildi") : (kod ? QString("HTTP %1").arg(kod) : r->errorString());
    }
    kayit(QString("indirme %1: %2 %3").arg(ok ? "tamam" : "olmadi").arg(m_indirAd).arg(mesaj));
    emit indirmeDegisti();
    emit indirmeBitti(ok, m_indirYol, mesaj);
}

// ---- dosya ----

bool Yayin::dosyaVar(const QString &yol) const { return QFileInfo(yol).exists(); }
bool Yayin::dosyaSil(const QString &yol) { return QFile::remove(yol); }
double Yayin::dosyaBoyutu(const QString &yol) const { return double(QFileInfo(yol).size()); }

QString Yayin::guvenliAd(const QString &ad) const
{
    QString s = ad;
    s.replace(QRegExp("[\\\\/:*?\"<>|\\r\\n\\t]"), "_");
    s = s.simplified();
    if (s.length() > 80) { const QString uz = QFileInfo(s).suffix(); s = s.left(70) + (uz.isEmpty() ? QString() : "." + uz); }
    return s.isEmpty() ? QString::fromLatin1("bolum.mp3") : s;
}

QString Yayin::metinOku(const QString &yol) const
{
    QFile f(yol.contains(':') ? yol : m_veri + "/" + yol);
    if (!f.open(QIODevice::ReadOnly)) return QString();
    return QString::fromUtf8(f.readAll());
}

bool Yayin::metinYaz(const QString &yol, const QString &metin)
{
    QFile f(yol.contains(':') ? yol : m_veri + "/" + yol);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) return false;
    f.write(metin.toUtf8());
    return true;
}

// ---- istekler: besleme, haber metni, genel ----

void Yayin::akisCek(const QString &istekId, const QString &url) { istekAt(QUrl(url), "akis", istekId, 0); }
void Yayin::metinCek(const QString &url) { istekAt(QUrl(url), "metin", url, 0); }
void Yayin::getir(const QString &istekId, const QString &url) { istekAt(QUrl(url), "getir", istekId, 0); }
bool Yayin::disaridaAc(const QString &url) { return QDesktopServices::openUrl(QUrl(url)); }

void Yayin::istekAt(const QUrl &u, const QString &tur, const QString &id, int yon)
{
    QNetworkRequest r(u);
    r.setRawHeader("User-Agent", tur == "metin" ? QByteArray("Mozilla/5.0 (Symbian/3; Series60/5.3 NokiaE6-00) BelleCast/0.1") : QByteArray(KAjan));
    r.setRawHeader("Accept-Encoding", "identity");
    QNetworkReply *rep = m_nam->get(r);
    rep->setProperty("tur", tur);
    rep->setProperty("id", id);
    rep->setProperty("yon", yon);
    connect(rep, SIGNAL(finished()), this, SLOT(istekBitti()));
}

static QString metinCoz(const QByteArray &ham, const QByteArray &turBasligi)
{
    QByteArray cs;
    const int i = turBasligi.toLower().indexOf("charset=");
    if (i >= 0) cs = turBasligi.mid(i + 8).split(';').value(0).trimmed().replace("\"", "");
    if (cs.isEmpty()) {
        QRegExp m("<meta[^>]*charset=[\"']?([A-Za-z0-9_\\-]+)", Qt::CaseInsensitive);
        if (m.indexIn(QString::fromLatin1(ham.left(4096))) >= 0) cs = m.cap(1).toLatin1();
    }
    QTextCodec *c = cs.isEmpty() ? 0 : QTextCodec::codecForName(cs);
    if (c && cs.toLower() != "utf-8") return c->toUnicode(ham);
    const QString u = QString::fromUtf8(ham);
    if (!u.contains(QChar(0xFFFD))) return u;
    QTextCodec *tr = QTextCodec::codecForName("windows-1254");
    return tr ? tr->toUnicode(ham) : QString::fromLatin1(ham);
}

void Yayin::istekBitti()
{
    QNetworkReply *r = qobject_cast<QNetworkReply *>(sender());
    if (!r) return;
    r->deleteLater();
    const QString tur = r->property("tur").toString(), id = r->property("id").toString();
    const int yon = r->property("yon").toInt();
    const int kod = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    QUrl hedef = r->attribute(QNetworkRequest::RedirectionTargetAttribute).toUrl();
    if (hedef.isEmpty() && kod >= 300 && kod < 400 && r->hasRawHeader("Location")) hedef = QUrl::fromEncoded(r->rawHeader("Location"));
    if (!hedef.isEmpty() && yon < 8) { istekAt(r->url().resolved(hedef), tur, id, yon + 1); return; }
    QString hata;
    QByteArray govde;
    if (r->error() != QNetworkReply::NoError || kod >= 400) hata = kod >= 400 ? QString("HTTP %1").arg(kod) : r->errorString();
    else govde = r->readAll();
    if (tur == "akis") {
        QVariantList ogeler;
        QVariantMap kanal;
        if (hata.isEmpty()) kanal = kanalCoz(govde, &ogeler, &hata);
        if (!hata.isEmpty()) kayit("besleme hatasi " + r->url().host() + ": " + hata);
        emit akisHazir(id, kanal, ogeler, hata);
    } else if (tur == "metin") {
        QString m;
        if (hata.isEmpty()) { m = sayfaMetni(govde.left(1500 * 1024)); if (m.isEmpty()) hata = QString::fromUtf8("Sayfada okunur metin bulunamadı"); }
        emit metinHazir(id, m, hata);
    } else {
        emit metinGeldi(id, hata.isEmpty() ? QString::fromUtf8(govde) : QString(), hata);
    }
}

// ---- HTML'den duz metin ----

static QString varliklariCoz(QString s)
{
    static const char *adlar[][2] = {
        { "nbsp", " " }, { "amp", "&" }, { "lt", "<" }, { "gt", ">" }, { "quot", "\"" }, { "apos", "'" },
        { "rsquo", "\xE2\x80\x99" }, { "lsquo", "\xE2\x80\x98" }, { "rdquo", "\xE2\x80\x9D" }, { "ldquo", "\xE2\x80\x9C" },
        { "hellip", "\xE2\x80\xA6" }, { "ndash", "\xE2\x80\x93" }, { "mdash", "\xE2\x80\x94" }, { "laquo", "\xC2\xAB" }, { "raquo", "\xC2\xBB" },
        { "ouml", "\xC3\xB6" }, { "Ouml", "\xC3\x96" }, { "uuml", "\xC3\xBC" }, { "Uuml", "\xC3\x9C" }, { "ccedil", "\xC3\xA7" }, { "Ccedil", "\xC3\x87" },
        { "eacute", "\xC3\xA9" }, { "acirc", "\xC3\xA2" }, { "icirc", "\xC3\xAE" }, { "ucirc", "\xC3\xBB" }, { "bull", "\xE2\x80\xA2" }, { "copy", "\xC2\xA9" }
    };
    if (!s.contains('&')) return s;
    QRegExp sayi("&#(x?)([0-9a-fA-F]+);");
    int p = 0;
    while ((p = sayi.indexIn(s, p)) >= 0) {
        bool ok = false;
        const uint k = sayi.cap(2).toUInt(&ok, sayi.cap(1).isEmpty() ? 10 : 16);
        const QString yeni = ok && k > 0 && k < 0xFFFF ? QString(QChar(k)) : QString();
        s.replace(p, sayi.matchedLength(), yeni);
        p += yeni.length();
    }
    for (unsigned i = 0; i < sizeof(adlar) / sizeof(adlar[0]); ++i)
        s.replace(QString::fromLatin1("&") + QString::fromLatin1(adlar[i][0]) + QString::fromLatin1(";"), QString::fromUtf8(adlar[i][1]));
    return s;
}

static QString duzMetin(QString h, int sinir)
{
    QRegExp sc("<(script|style|noscript)[^>]*>.*</\\1>", Qt::CaseInsensitive);
    sc.setMinimal(true);
    h.remove(sc);
    h.replace(QRegExp("<\\s*(br|/p|/div|/li|/h[1-6]|/tr)[^>]*>", Qt::CaseInsensitive), "\n");
    h.replace(QRegExp("<\\s*li(\\s[^>]*)?>", Qt::CaseInsensitive), QString::fromUtf8("\n\xE2\x80\xA2 "));
    h.remove(QRegExp("<[^>]*>"));
    h.remove(QRegExp("<!\\[CDATA\\[|\\]\\]>"));
    h = varliklariCoz(h);
    h.replace(QRegExp("[ \\t\\r\\f]+"), " ");
    h.replace(QRegExp(" ?\\n ?"), "\n");
    h.replace(QRegExp("\\n{3,}"), "\n\n");
    h = h.trimmed();
    if (sinir > 0 && h.length() > sinir) h = h.left(sinir) + QString(QChar(0x2026));
    return h;
}

QString Yayin::sayfaMetni(const QByteArray &ham) const
{
    QString h = metinCoz(ham, QByteArray());
    QRegExp sc("<(script|style|noscript)[^>]*>.*</\\1>", Qt::CaseInsensitive);
    sc.setMinimal(true);
    h.remove(sc);
    // icerik bolgesi: <article> varsa onun ici
    QRegExp art("<article[^>]*>(.*)</article>", Qt::CaseInsensitive);
    art.setMinimal(false);
    QString bolge = art.indexIn(h) >= 0 ? art.cap(1) : h;
    QRegExp par("<p(?:\\s[^>]*)?>(.*)</p>", Qt::CaseInsensitive);      // <picture>, <path> degil
    par.setMinimal(true);
    QStringList paraflar;
    int p = 0, toplam = 0;
    while ((p = par.indexIn(bolge, p)) >= 0 && toplam < 20000) {
        const QString t = duzMetin(par.cap(1), 0);
        p += par.matchedLength();
        if (t.length() < 40) continue;                 // menu, telif vb. kisa satirlar
        paraflar << t;
        toplam += t.length();
    }
    QString m = paraflar.join("\n\n");
    if (m.length() < 200) {
        QRegExp og("<meta[^>]*(property|name)=[\"'](og:description|description)[\"'][^>]*content=[\"']([^\"']*)[\"']", Qt::CaseInsensitive);
        if (og.indexIn(h) >= 0 && og.cap(3).length() > m.length()) m = varliklariCoz(og.cap(3));
    }
    return m;
}

// ---- besleme cozumu ----

static qint64 tarihCoz(const QString &t0)
{
    const QString t = t0.trimmed();
    if (t.isEmpty()) return 0;
    // ISO 8601: 2026-11-15T12:30:00+03:00 / Z
    QRegExp iso("^(\\d{4})-(\\d{2})-(\\d{2})(?:[T ](\\d{2}):(\\d{2})(?::(\\d{2}))?)?(?:\\.\\d+)?\\s*(Z|[+-]\\d{2}:?\\d{2})?");
    if (iso.indexIn(t) == 0) {
        QDateTime d(QDate(iso.cap(1).toInt(), iso.cap(2).toInt(), iso.cap(3).toInt()), QTime(iso.cap(4).toInt(), iso.cap(5).toInt(), iso.cap(6).toInt()), Qt::UTC);
        const QString z = iso.cap(7);
        if (z.length() > 1) { const int sg = z.at(0) == '-' ? -1 : 1; const QString n = QString(z).remove(':'); d = d.addSecs(-sg * (n.mid(1, 2).toInt() * 3600 + n.mid(3, 2).toInt() * 60)); }
        return d.toMSecsSinceEpoch();
    }
    // RFC 822: Sat, 15 Nov 2026 12:30:00 +0300
    QRegExp rfc("(\\d{1,2})\\s+([A-Za-z]{3})[A-Za-z]*\\s+(\\d{2,4})\\s+(\\d{1,2}):(\\d{2})(?::(\\d{2}))?\\s*([+-]\\d{4}|[A-Za-z]+)?");
    if (rfc.indexIn(t) >= 0) {
        static const char *aylar = "janfebmaraprmayjunjulaugsepoctnovdec";
        const int ay = QString::fromLatin1(aylar).indexOf(rfc.cap(2).toLower()) / 3 + 1;
        int yil = rfc.cap(3).toInt();
        if (yil < 100) yil += 2000;
        QDateTime d(QDate(yil, ay, rfc.cap(1).toInt()), QTime(rfc.cap(4).toInt(), rfc.cap(5).toInt(), rfc.cap(6).toInt()), Qt::UTC);
        const QString z = rfc.cap(7);
        if (z.startsWith('+') || z.startsWith('-')) { const int sg = z.at(0) == '-' ? -1 : 1; d = d.addSecs(-sg * (z.mid(1, 2).toInt() * 3600 + z.mid(3, 2).toInt() * 60)); }
        else if (z == "EST") d = d.addSecs(5 * 3600); else if (z == "EDT") d = d.addSecs(4 * 3600);
        else if (z == "PST") d = d.addSecs(8 * 3600); else if (z == "PDT") d = d.addSecs(7 * 3600);
        return d.toMSecsSinceEpoch();
    }
    return 0;
}

static int sureCoz(const QString &s)
{
    const QStringList p = s.trimmed().split(':');
    int t = 0;
    foreach (const QString &x, p) t = t * 60 + x.toInt();
    return t;
}

QVariantMap Yayin::kanalCoz(const QByteArray &xml0, QVariantList *ogeler, QString *hata) const
{
    QByteArray xml = xml0;
    int bas = xml.indexOf('<');
    if (bas > 0) xml.remove(0, bas);                  // BOM / bosluk
    QXmlStreamReader x(xml);
    QVariantMap kanal, oge;
    bool ogede = false, resimde = false;
    while (!x.atEnd()) {
        x.readNext();
        if (x.isStartElement()) {
            const QString ad = x.qualifiedName().toString().toLower();
            const QString yerel = x.name().toString().toLower();
            if (yerel == "item" || yerel == "entry") { ogede = true; oge.clear(); continue; }
            if (yerel == "image" && !ogede && ad == "image") { resimde = true; continue; }
            QVariantMap &h = ogede ? oge : kanal;
            const QXmlStreamAttributes a = x.attributes();
            if (yerel == "link" && a.hasAttribute("href")) {
                const QString rel = a.value("rel").toString();
                if (rel == "enclosure") { h["ses"] = a.value("href").toString(); h["sesTur"] = a.value("type").toString(); h["boy"] = a.value("length").toString().toDouble(); }
                else if ((rel.isEmpty() || rel == "alternate") && !h.contains("link")) h["link"] = a.value("href").toString();
                continue;
            }
            if (yerel == "enclosure") {
                const QString tur = a.value("type").toString();
                if (tur.startsWith("image")) { if (!h.contains("resim")) h["resim"] = a.value("url").toString(); }
                else if (!h.contains("ses")) { h["ses"] = a.value("url").toString(); h["sesTur"] = tur; h["boy"] = a.value("length").toString().toDouble(); }
                continue;
            }
            if (ad == "itunes:image") { h["resim"] = a.value("href").toString(); continue; }
            if (ad == "media:thumbnail" || (ad == "media:content" && a.value("medium").toString() == "image")) { if (!h.contains("resim")) h["resim"] = a.value("url").toString(); continue; }
            if (ad == "media:content" && a.value("type").toString().startsWith("audio") && !h.contains("ses")) { h["ses"] = a.value("url").toString(); h["sesTur"] = a.value("type").toString(); continue; }
            if (resimde && yerel == "url") { kanal["resim"] = x.readElementText().trimmed(); continue; }
            if (yerel == "title" && !resimde) { h["baslik"] = varliklariCoz(duzMetin(x.readElementText(QXmlStreamReader::IncludeChildElements), 300)); continue; }
            if (yerel == "link" && !resimde) { const QString l = x.readElementText().trimmed(); if (!l.isEmpty()) h["link"] = l; continue; }
            if (yerel == "guid" || (yerel == "id" && ogede)) { h["guid"] = x.readElementText().trimmed(); continue; }
            if (yerel == "pubdate" || ad == "dc:date" || yerel == "published" || (yerel == "updated" && !h.contains("zaman"))) { h["zaman"] = double(tarihCoz(x.readElementText())); continue; }
            if (ad == "itunes:duration") { h["sure"] = sureCoz(x.readElementText()); continue; }
            if ((ad == "itunes:author" || yerel == "author" || ad == "dc:creator") && !h.contains("yazar")) { h["yazar"] = duzMetin(x.readElementText(QXmlStreamReader::IncludeChildElements), 120); continue; }
            if (ad == "content:encoded" || yerel == "content" || yerel == "description" || yerel == "summary" || ad == "itunes:summary") {
                const QString ham = x.readElementText(QXmlStreamReader::IncludeChildElements);
                const QString t = duzMetin(ham, 4000);
                if (t.length() > h.value("ozet").toString().length()) h["ozet"] = t;
                if (!h.contains("resim")) {           // ozetteki ilk resim
                    QRegExp img("<img[^>]*src=[\"']([^\"']+)[\"']", Qt::CaseInsensitive);
                    if (img.indexIn(ham) >= 0) h["resim"] = img.cap(1);
                }
                continue;
            }
        } else if (x.isEndElement()) {
            const QString yerel = x.name().toString().toLower();
            if ((yerel == "item" || yerel == "entry") && ogede) {
                ogede = false;
                if (!oge.contains("guid")) oge["guid"] = oge.value("ses", oge.value("link")).toString();
                if (ogeler->size() < 150) ogeler->append(oge);
            } else if (yerel == "image" && resimde) resimde = false;
        }
    }
    if (x.hasError() && ogeler->isEmpty()) *hata = QString::fromUtf8("Besleme okunamadı: ") + x.errorString();
    else if (ogeler->isEmpty() && kanal.isEmpty()) *hata = QString::fromUtf8("RSS/Atom beslemesi değil");
    return kanal;
}

// ---- zamanlayici ----

void Yayin::zamanla(const QString &ad, int ms)
{
    QTimer *t = m_zaman.value(ad);
    if (!t) {
        t = new QTimer(this);
        t->setSingleShot(true);
        t->setObjectName(ad);
        connect(t, SIGNAL(timeout()), this, SLOT(zamanTik()));
        m_zaman.insert(ad, t);
    }
    m_zamanBas.insert(ad, QTime::currentTime());
    t->start(qMax(1, ms));
}

void Yayin::zamanIptal(const QString &ad) { QTimer *t = m_zaman.value(ad); if (t) t->stop(); }

int Yayin::zamanKalan(const QString &ad) const
{
    QTimer *t = m_zaman.value(ad);
    if (!t || !t->isActive()) return -1;
    return qMax(0, (t->interval() - m_zamanBas.value(ad).msecsTo(QTime::currentTime())) / 1000);
}

void Yayin::zamanTik()
{
    QTimer *t = qobject_cast<QTimer *>(sender());
    if (t) emit zamanDoldu(t->objectName());
}

// ---- gunluk ----

void Yayin::kayit(const QString &s)
{
    m_gunluk << QDateTime::currentDateTime().toString("dd.MM HH:mm:ss ") + s;
    while (m_gunluk.size() > 150) m_gunluk.removeFirst();
    QFile g(m_veri + "/gunluk.txt");
    if (g.open(QIODevice::WriteOnly | QIODevice::Truncate)) g.write((m_gunluk.join("\n") + "\n").toUtf8());
}

QString Yayin::gunluk() const { return m_gunluk.join("\n"); }
