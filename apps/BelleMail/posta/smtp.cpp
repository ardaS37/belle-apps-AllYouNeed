#include "smtp.h"
#include "mime.h"
#include <QtNetwork/QSslSocket>
#include <QtCore/QDateTime>
#include <QtCore/QRegExp>
#include <stdlib.h>

Smtp::Smtp(QObject *parent)
    : QObject(parent), m_s(0), m_adim(Selam), m_alici(0), m_port(465), m_plainVar(false), m_loginVar(false), m_tlsVar(false)
{
    m_zaman.setSingleShot(true);
    m_zaman.setInterval(60000);
    connect(&m_zaman, SIGNAL(timeout()), this, SLOT(zamanAsimi()));
}

static QString adres(const QString &s)
{
    QRegExp r(QString::fromLatin1("<([^>]+)>"));
    if (r.indexIn(s) >= 0) return r.cap(1).trimmed();
    return s.trimmed();
}

static QByteArray adresBasligi(const QString &s)
{
    QRegExp r(QString::fromLatin1("^\\s*\"?([^\"<]*)\"?\\s*<([^>]+)>\\s*$"));
    if (r.indexIn(s) >= 0 && !r.cap(1).trimmed().isEmpty())
        return Mime::baslikKodla(r.cap(1).trimmed()) + " <" + r.cap(2).trimmed().toUtf8() + ">";
    return s.trimmed().toUtf8();
}

QByteArray Smtp::iletiOlustur(const Posta &p, QByteArray *mesajKimligi)
{
    QByteArray o;
    const QString alan = p.kimden.section(QLatin1Char('@'), 1);
    QByteArray rastgele;
    for (int i = 0; i < 8; ++i) rastgele += QByteArray::number(qrand() % 256, 16).rightJustified(2, '0');
    const QByteArray kimlik = "<" + rastgele + "." + QByteArray::number(QDateTime::currentDateTime().toTime_t()) + "@" + (alan.isEmpty() ? QByteArray("belle.mail") : alan.toUtf8()) + ">";
    if (mesajKimligi) *mesajKimligi = kimlik;
    o += "From: " + (p.kimdenAd.isEmpty() ? p.kimden.toUtf8() : Mime::baslikKodla(p.kimdenAd) + " <" + p.kimden.toUtf8() + ">") + "\r\n";
    QList<QByteArray> kime;
    for (int i = 0; i < p.kime.size(); ++i) kime.append(adresBasligi(p.kime.at(i)));
    o += "To: ";
    for (int i = 0; i < kime.size(); ++i) { if (i) o += ",\r\n "; o += kime.at(i); }
    o += "\r\n";
    if (!p.bilgi.isEmpty()) {
        o += "Cc: ";
        for (int i = 0; i < p.bilgi.size(); ++i) { if (i) o += ",\r\n "; o += adresBasligi(p.bilgi.at(i)); }
        o += "\r\n";
    }
    o += "Subject: " + Mime::baslikKodla(p.konu.isEmpty() ? QString::fromUtf8("(konu yok)") : p.konu) + "\r\n";
    o += "Date: " + Mime::simdi() + "\r\n";
    o += "Message-ID: " + kimlik + "\r\n";
    if (!p.yanitlanan.isEmpty()) {
        o += "In-Reply-To: " + p.yanitlanan.toUtf8() + "\r\n";
        o += "References: " + p.yanitlanan.toUtf8() + "\r\n";
    }
    o += "MIME-Version: 1.0\r\n";
    o += "User-Agent: BelleMail (Nokia E6)\r\n";
    o += "Content-Type: text/plain; charset=UTF-8\r\n";
    o += "Content-Transfer-Encoding: base64\r\n\r\n";
    QString metin = p.metin;
    metin.replace(QString::fromLatin1("\r\n"), QString::fromLatin1("\n")).replace(QLatin1Char('\n'), QString::fromLatin1("\r\n"));
    const QByteArray b = metin.toUtf8().toBase64();
    for (int i = 0; i < b.size(); i += 76) o += b.mid(i, 76) + "\r\n";
    return o;
}

void Smtp::gonder(const QString &sunucu, int port, const QString &kullanici, const QString &parola, const Posta &p)
{
    if (m_s) { emit bitti(false, tr("Önceki gönderim sürüyor.")); return; }
    m_kullanici = kullanici;
    m_parola = parola;
    m_kimden = p.kimden;
    m_alicilar.clear();
    const QStringList hepsi = p.kime + p.bilgi;
    for (int i = 0; i < hepsi.size(); ++i) { const QString a = adres(hepsi.at(i)); if (a.contains(QLatin1Char('@'))) m_alicilar.append(a); }
    if (m_alicilar.isEmpty()) { emit bitti(false, tr("Alıcı adresi gerekli.")); return; }
    m_ileti = iletiOlustur(p);
    // nokta ile baslayan satirlar ikilenir (RFC 5321 4.5.2)
    m_ileti.replace("\r\n.", "\r\n..");
    m_port = port > 0 ? port : 465;
    m_adim = Selam;
    m_tampon.clear();
    m_cokSatir.clear();
    m_plainVar = m_loginVar = m_tlsVar = false;
    m_s = new QSslSocket(this);
    connect(m_s, SIGNAL(readyRead()), this, SLOT(okunabilir()));
    connect(m_s, SIGNAL(encrypted()), this, SLOT(sifreli()));
    connect(m_s, SIGNAL(error(QAbstractSocket::SocketError)), this, SLOT(hata()));
    m_s->setPeerVerifyMode(QSslSocket::VerifyPeer);
    if (m_port == 465) m_s->connectToHostEncrypted(sunucu, quint16(m_port));
    else {
        connect(m_s, SIGNAL(connected()), this, SLOT(baglandi()));
        m_s->connectToHost(sunucu, quint16(m_port));
    }
    m_zaman.start();
}

void Smtp::baglandi() { m_zaman.start(); }

void Smtp::sifreli()
{
    m_zaman.start();
    if (m_adim == StartTls) { m_adim = Ehlo2; yaz("EHLO belle.mail"); }
}

void Smtp::yaz(const QByteArray &s)
{
    if (!m_s) return;
    m_s->write(s + "\r\n");
    m_zaman.start();
}

void Smtp::hata()
{
    if (!m_s) return;
    if (m_adim == Quit) { bitir(true, QString()); return; }
    QString n = m_s->errorString();
    if (m_s->error() == QAbstractSocket::SslHandshakeFailedError) n = tr("Güvenli bağlantı kurulamadı (sertifika): %1").arg(n);
    bitir(false, n);
}

void Smtp::zamanAsimi()
{
    if (m_s) bitir(m_adim == Quit, m_adim == Quit ? QString() : tr("Posta sunucusu yanıt vermedi (zaman aşımı)."));
}

void Smtp::bitir(bool ok, const QString &m)
{
    m_zaman.stop();
    if (m_s) { m_s->flush(); m_s->abort(); m_s->deleteLater(); m_s = 0; }
    m_parola.clear();
    m_ileti.clear();
    emit bitti(ok, m);
}

void Smtp::okunabilir()
{
    if (!m_s) return;
    m_tampon += m_s->readAll();
    m_zaman.start();
    int idx;
    while (m_s && (idx = m_tampon.indexOf("\r\n")) >= 0) {
        const QByteArray satir = m_tampon.left(idx);
        m_tampon.remove(0, idx + 2);
        if (satir.size() < 3) continue;
        m_cokSatir += satir.mid(4) + "\n";
        if (satir.size() > 3 && satir.at(3) == '-') continue;   // devami var
        const int kod = satir.left(3).toInt();
        const QByteArray metin = m_cokSatir;
        m_cokSatir.clear();
        ilerle(kod, metin);
    }
}

void Smtp::ilerle(int kod, const QByteArray &metin)
{
    const QString hataMetni = QString::fromUtf8(metin).trimmed();
    switch (m_adim) {
    case Selam:
        if (kod != 220) { bitir(false, hataMetni); return; }
        m_adim = Ehlo;
        yaz("EHLO belle.mail");
        return;
    case Ehlo:
    case Ehlo2: {
        if (kod != 250) { bitir(false, hataMetni); return; }
        const QByteArray u = metin.toUpper();
        m_tlsVar = u.contains("STARTTLS");
        const int a = u.indexOf("AUTH");
        const QByteArray auth = a >= 0 ? u.mid(a, u.indexOf('\n', a) - a) : QByteArray();
        m_plainVar = auth.contains("PLAIN");
        m_loginVar = auth.contains("LOGIN");
        if (!m_s->isEncrypted()) {
            if (!m_tlsVar) { bitir(false, tr("Sunucu şifreli bağlantıyı (STARTTLS) desteklemiyor.")); return; }
            m_adim = StartTls;
            yaz("STARTTLS");
            return;
        }
        if (m_plainVar || !m_loginVar) {
            QByteArray k;
            k.append('\0'); k += m_kullanici.toUtf8(); k.append('\0'); k += m_parola.toUtf8();
            m_adim = Auth;
            yaz("AUTH PLAIN " + k.toBase64());
        } else {
            m_adim = AuthKul;
            yaz("AUTH LOGIN");
        }
        return;
    }
    case StartTls:
        if (kod != 220) { bitir(false, hataMetni); return; }
        m_s->startClientEncryption();
        return;
    case AuthKul:
        if (kod != 334) { bitir(false, hataMetni); return; }
        m_adim = AuthPar;
        yaz(m_kullanici.toUtf8().toBase64());
        return;
    case AuthPar:
        if (kod != 334) { bitir(false, hataMetni); return; }
        m_adim = Auth;
        yaz(m_parola.toUtf8().toBase64());
        return;
    case Auth:
        if (kod != 235) { bitir(false, tr("Giriş reddedildi: %1").arg(hataMetni)); return; }
        m_adim = MailFrom;
        yaz("MAIL FROM:<" + m_kimden.toUtf8() + ">");
        return;
    case MailFrom:
        if (kod != 250) { bitir(false, hataMetni); return; }
        m_adim = RcptTo;
        m_alici = 0;
        yaz("RCPT TO:<" + m_alicilar.at(0).toUtf8() + ">");
        return;
    case RcptTo:
        if (kod != 250 && kod != 251) { bitir(false, tr("Alıcı kabul edilmedi (%1): %2").arg(m_alicilar.value(m_alici)).arg(hataMetni)); return; }
        if (++m_alici < m_alicilar.size()) { yaz("RCPT TO:<" + m_alicilar.at(m_alici).toUtf8() + ">"); return; }
        m_adim = Data;
        yaz("DATA");
        return;
    case Data:
        if (kod != 354) { bitir(false, hataMetni); return; }
        m_adim = Govde;
        m_s->write(m_ileti);
        yaz(".");
        return;
    case Govde:
        if (kod != 250) { bitir(false, hataMetni); return; }
        m_adim = Quit;
        yaz("QUIT");
        bitir(true, QString());
        return;
    default:
        return;
    }
}
