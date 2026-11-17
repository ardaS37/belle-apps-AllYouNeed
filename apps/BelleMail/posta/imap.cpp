#include "imap.h"
#include <QtNetwork/QSslSocket>
#include <QtNetwork/QSslError>

Imap::Imap(QObject *parent)
    : QObject(parent), m_s(0), m_durum(Kapali), m_port(993), m_sayac(0), m_yolda(0)
{
    m_zaman.setSingleShot(true);
    m_zaman.setInterval(60000);
    connect(&m_zaman, SIGNAL(timeout()), this, SLOT(zamanAsimi()));
}

Imap::~Imap()
{
    if (m_s) m_s->abort();
}

void Imap::ayarla(const QString &sunucu, int port, const QString &kullanici, const QString &parola)
{
    kapat();
    m_sunucu = sunucu.trimmed();
    m_port = port > 0 ? port : 993;
    m_kullanici = kullanici.trimmed();
    m_parola = parola;
}

QByteArray Imap::dize(const QByteArray &s)
{
    QByteArray o("\"");
    for (int i = 0; i < s.size(); ++i) {
        const char c = s.at(i);
        if (c == '"' || c == '\\') o.append('\\');
        if (c == '\r' || c == '\n') continue;
        o.append(c);
    }
    o.append('"');
    return o;
}

int Imap::komut(const QByteArray &metin)
{
    const int no = ++m_sayac;
    m_kuyruk.append(qMakePair(no, metin));
    if (m_durum == Kapali) baglan();
    else if (m_durum == Hazir) gonderSiradaki();
    return no;
}

void Imap::baglan()
{
    if (m_s) { m_s->abort(); m_s->deleteLater(); m_s = 0; }
    m_tampon.clear();
    m_toplanan.clear();
    m_yetenek.clear();
    m_yolda = 0;
    m_durum = Baglaniyor;
    m_s = new QSslSocket(this);
    connect(m_s, SIGNAL(encrypted()), this, SLOT(sifreliHazir()));
    connect(m_s, SIGNAL(readyRead()), this, SLOT(okunabilir()));
    connect(m_s, SIGNAL(error(QAbstractSocket::SocketError)), this, SLOT(soketHatasi()));
    connect(m_s, SIGNAL(sslErrors(QList<QSslError>)), this, SLOT(sslHatalari()));
    m_s->setPeerVerifyMode(QSslSocket::VerifyPeer);
    m_s->connectToHostEncrypted(m_sunucu, quint16(m_port));
    m_zaman.start();
}

void Imap::kapat()
{
    if (m_s) {
        if (m_durum == Hazir) { m_s->write("Z LOGOUT\r\n"); m_s->flush(); }
        m_s->disconnectFromHost();
        m_s->deleteLater();
        m_s = 0;
    }
    m_durum = Kapali;
    m_zaman.stop();
    m_yolda = 0;
}

void Imap::sifreliHazir()
{
    m_zaman.start();   // karsilama satirini bekle
}

void Imap::sslHatalari()
{
    // dogrulama acik: hata soketHatasi() ile bildirilir (kok sertifikalar kutuphane/sunucu/roots.pem)
}

void Imap::soketHatasi()
{
    if (!m_s || sender() != m_s) return;   // eski (kapatilmis) soketin gec gelen hatasi
    QString neden = m_s->errorString();
    if (m_s->error() == QAbstractSocket::SslHandshakeFailedError) neden = tr("Güvenli bağlantı kurulamadı (sertifika): %1").arg(neden);
    if (m_s->error() == QAbstractSocket::RemoteHostClosedError && m_durum == Hazir && m_yolda == 0 && m_kuyruk.isEmpty()) {
        // bos dururken sunucu kapatti: sessizce kapan, sonraki komutta yeniden baglanir
        m_durum = Kapali;
        m_s->deleteLater();
        m_s = 0;
        m_zaman.stop();
        return;
    }
    hepsiniBitir(neden);
}

void Imap::zamanAsimi()
{
    if (m_durum == Hazir && m_yolda == 0) return;
    if (m_durum == Kapali) return;
    hepsiniBitir(tr("Sunucu yanıt vermedi (zaman aşımı)."));
}

void Imap::hepsiniBitir(const QString &neden)
{
    const bool giristeydi = m_durum == Baglaniyor || m_durum == Giris || m_durum == Yetenek;
    if (m_s) { m_s->abort(); m_s->deleteLater(); m_s = 0; }
    m_durum = Kapali;
    m_zaman.stop();
    QList<QPair<int, QByteArray> > k = m_kuyruk;
    m_kuyruk.clear();
    const int yolda = m_yolda;
    m_yolda = 0;
    emit koptu(neden);
    Q_UNUSED(giristeydi);
    if (yolda) emit bitti(yolda, false, neden, QVariantList());
    for (int i = 0; i < k.size(); ++i) emit bitti(k.at(i).first, false, neden, QVariantList());
}

void Imap::gonderSiradaki()
{
    if (m_durum != Hazir || m_yolda || m_kuyruk.isEmpty() || !m_s) return;
    const QPair<int, QByteArray> k = m_kuyruk.takeFirst();
    m_yolda = k.first;
    m_toplanan.clear();
    m_s->write("B" + QByteArray::number(k.first) + " " + k.second + "\r\n");
    m_zaman.start();
}

void Imap::okunabilir()
{
    if (!m_s || sender() != m_s) return;
    m_tampon += m_s->readAll();
    m_zaman.start();
    for (;;) {
        int pos = 0;
        bool tam = false, bekle = false;
        for (;;) {
            const int idx = m_tampon.indexOf("\r\n", pos);
            if (idx < 0) { bekle = true; break; }
            const int lb = idx - 1;
            if (lb >= pos && m_tampon.at(lb) == '}') {
                const int ob = m_tampon.lastIndexOf('{', lb);
                if (ob >= pos) {
                    bool ok = false;
                    const qint64 uz = m_tampon.mid(ob + 1, lb - ob - 1).toLongLong(&ok);
                    if (ok) {
                        const qint64 gerek = idx + 2 + uz;
                        if (m_tampon.size() < gerek) {
                            if (uz > 65536) emit ilerleme(m_tampon.size() - (idx + 2), uz);
                            bekle = true;
                            break;
                        }
                        pos = int(gerek);
                        continue;
                    }
                }
            }
            const QByteArray y = m_tampon.left(idx + 2);
            m_tampon.remove(0, idx + 2);
            yanitIsle(y);
            tam = true;
            break;
        }
        if (bekle || !tam || !m_s) break;
    }
}

void Imap::yanitIsle(const QByteArray &y)
{
    if (y.startsWith("* ")) {
        const QVariantList t = ayristir(y, 2);
        const QByteArray ilk = t.value(0).toByteArray().toUpper();
        if (m_durum == Baglaniyor) {
            if (ilk == "OK") {
                m_durum = Giris;
                m_s->write("L1 LOGIN " + dize(m_kullanici.toUtf8()) + " " + dize(m_parola.toUtf8()) + "\r\n");
            } else if (ilk == "PREAUTH") {
                m_durum = Yetenek;
                m_s->write("L2 CAPABILITY\r\n");
            } else {
                hepsiniBitir(tr("Sunucu bağlantıyı reddetti."));
            }
            return;
        }
        if (ilk == "CAPABILITY") {
            m_yetenek.clear();
            for (int i = 1; i < t.size(); ++i) m_yetenek.append(t.at(i).toByteArray().toUpper());
        }
        if (ilk == "BYE" && m_yolda == 0 && m_durum == Hazir) return;   // sunucu kapaniyor: soket hatasi gelecek
        m_toplanan.append(QVariant(t));
        return;
    }
    if (y.startsWith("+")) return;   // devam istegi (kullanmiyoruz)
    const int sp = y.indexOf(' ');
    if (sp < 0) return;
    const QByteArray etiket = y.left(sp);
    QByteArray geri = y.mid(sp + 1).trimmed();
    const int sp2 = geri.indexOf(' ');
    const QByteArray sonuc = (sp2 < 0 ? geri : geri.left(sp2)).toUpper();
    const QString metin = QString::fromUtf8(sp2 < 0 ? QByteArray() : geri.mid(sp2 + 1));
    const bool ok = sonuc == "OK";
    if (etiket == "L1") {
        if (!ok) {
            const QString m = metin.isEmpty() ? tr("Giriş reddedildi.") : metin;
            m_durum = Kapali;   // hepsiniBitir'den once: girisHatasi ile ayirt edilir
            emit girisHatasi(m);
            hepsiniBitir(m);
            return;
        }
        m_durum = Yetenek;
        m_toplanan.clear();
        m_s->write("L2 CAPABILITY\r\n");
        return;
    }
    if (etiket == "L2") {
        m_durum = Hazir;
        m_toplanan.clear();
        gonderSiradaki();
        return;
    }
    if (etiket == "B" + QByteArray::number(m_yolda)) {
        const int no = m_yolda;
        const QVariantList t = m_toplanan;
        m_toplanan.clear();
        m_yolda = 0;
        m_zaman.stop();
        emit bitti(no, ok, metin, t);
        gonderSiradaki();
    }
}

QVariantList Imap::ayristir(const QByteArray &s, int bas)
{
    QVariantList l;
    int i = bas;
    const int n = s.size();
    while (i < n) {
        while (i < n && s.at(i) == ' ') ++i;
        if (i >= n || s.at(i) == '\r' || s.at(i) == '\n') break;
        const int once = i;
        l.append(deger(s, i));
        if (i == once) ++i;
    }
    return l;
}

QVariant Imap::deger(const QByteArray &s, int &i)
{
    const int n = s.size();
    while (i < n && s.at(i) == ' ') ++i;
    if (i >= n) return QVariant();
    const char c = s.at(i);
    if (c == '(') {
        ++i;
        QVariantList l;
        for (;;) {
            while (i < n && s.at(i) == ' ') ++i;
            if (i >= n) break;
            if (s.at(i) == ')') { ++i; break; }
            if (s.at(i) == '\r' || s.at(i) == '\n') { ++i; continue; }
            const int once = i;
            l.append(deger(s, i));
            if (i == once) ++i;
        }
        return l;
    }
    if (c == '"') {
        ++i;
        QByteArray o;
        while (i < n && s.at(i) != '"') {
            if (s.at(i) == '\\' && i + 1 < n) ++i;
            o.append(s.at(i));
            ++i;
        }
        ++i;
        return o;
    }
    if (c == '{') {
        const int k = s.indexOf('}', i);
        if (k < 0) { i = n; return QVariant(); }
        const int uz = s.mid(i + 1, k - i - 1).toInt();
        i = k + 1;
        if (i < n && s.at(i) == '\r') ++i;
        if (i < n && s.at(i) == '\n') ++i;
        const QByteArray o = s.mid(i, uz);
        i += uz;
        return o;
    }
    const int b = i;
    int kose = 0;
    while (i < n) {
        const char ch = s.at(i);
        if (ch == '[') ++kose;
        else if (ch == ']') --kose;
        else if (kose <= 0 && (ch == ' ' || ch == '(' || ch == ')' || ch == '\r' || ch == '\n')) break;
        ++i;
    }
    const QByteArray a = s.mid(b, i - b);
    if (a == "NIL") return QVariant();
    return a;
}
