#include "belleadres.h"
#include "yardim.h"
#include "dil.h"

#include <QtCore/QDir>
#include <QtCore/QDirIterator>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QDateTime>
#include <QtCore/QBuffer>
#include <QtCore/QUrl>
#include <QtCore/QVariantMap>
#include <QtGui/QApplication>
#include <QtGui/QClipboard>
#include <QtGui/QImage>
#include <QtGui/QImageReader>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkRequest>
#include <QtNetwork/QNetworkReply>
#include <QtNetwork/QSslConfiguration>
#include <QtNetwork/QSslCipher>
#include <QtNetwork/QSslCertificate>
#include <QtCore/QRegExp>
#include <QtCore/QEventLoop>
#include <QtCore/QTimer>

static const char *KSurum = "1.3.4";

Yardim::Yardim(QObject *parent) : QObject(parent), m_nam(0)   // ag yoneticisi yalnizca rapor gonderilirken kurulur (eski surumdeki gibi acilista ag yok)
{
#if defined(Q_OS_SYMBIAN)
    m_dir = "C:/Data/ApiLauncher";
#else
    m_dir = QDir::homePath() + "/ApiLauncher";
#endif
    QDir().mkpath(m_dir);
    QFile f(m_dir + "/gunluk.txt");
    if (f.open(QIODevice::ReadOnly)) {
        m_log = QString::fromUtf8(f.readAll()).split('\n', QString::SkipEmptyParts);
        while (m_log.size() > 119) m_log.removeFirst();
    }
    log(QString("acildi v") + KSurum);
}

void Yardim::log(const QString &s)
{
    m_log << QDateTime::currentDateTime().toString("dd.MM HH:mm:ss ") + s;
    while (m_log.size() > 120) m_log.removeFirst();
    qDebug("API %s", s.toUtf8().constData());
    QFile f(m_dir + "/gunluk.txt");
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) f.write((m_log.join("\n") + "\n").toUtf8());
}

QString Yardim::gunluk() const { return m_log.join("\n"); }
QString Yardim::panoMetni() const { return QApplication::clipboard()->text(); }
QString Yardim::dosyaUrl(const QString &yol) const { return QUrl::fromLocalFile(yol).toString(); }

// ---------------- Sorun bildirme (/api/report) ----------------

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

void Yardim::raporGonder(const QString &sunucu, const QString &parola, const QString &not_)
{
    QString s = belleSunucuTasi(sunucu);
    while (s.endsWith('/')) s.chop(1);
    if (s.isEmpty()) s = "https://e6.msahincelen.xyz";
    if (parola.trimmed().isEmpty()) { emit raporBitti(false, Dil::t("Önce Ayarlar > Bağlantı'ya sunucu parolasını girin")); return; }
    QString t = Dil::t("ApiLauncher raporu • ") + QDateTime::currentDateTime().toString("dd.MM.yyyy HH:mm:ss") + "\n";
    t += "Qt " + QString(qVersion()) + "\n";
    if (!not_.trimmed().isEmpty()) t += "Not: " + not_.trimmed() + "\n";
    t += "\n" + m_log.join("\n") + "\n";
    const QString body = "{\"app\":\"ApiLauncher\",\"version\":\"" + QString(KSurum) + "\",\"note\":" + jsonEsc(not_) + ",\"text\":" + jsonEsc(t) + "}";
    QNetworkRequest r(QUrl(s + "/api/report"));
    r.setRawHeader("X-Api-Key", parola.trimmed().toUtf8()); r.setRawHeader("X-Lang", Dil::kodu());
    r.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    if (!m_nam) m_nam = new QNetworkAccessManager(this);
    QNetworkReply *rep = m_nam->post(r, body.toUtf8());
    connect(rep, SIGNAL(finished()), this, SLOT(onRapor()));
    log("rapor gonderiliyor");
}

void Yardim::onRapor()
{
    QNetworkReply *r = qobject_cast<QNetworkReply *>(sender());
    r->deleteLater();
    const bool ok = r->error() == QNetworkReply::NoError;
    const int code = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    log(QString("rapor ") + (ok ? "gonderildi" : "HATA " + r->errorString()));
    emit raporBitti(ok, ok ? Dil::t("Rapor gönderildi")
                           : (code == 403 ? Dil::t("Sunucu parolası hatalı") : Dil::t("Gönderilemedi: ") + r->errorString()));
}

// ---------------- HTTPS tanisi ----------------

void Yardim::tlsTest(const QString &url)
{
    if (!m_nam) m_nam = new QNetworkAccessManager(this);
    QNetworkRequest r((QUrl(url)));
    QNetworkReply *rep = m_nam->get(r);
    rep->setProperty("tlsUrl", url);
    connect(rep, SIGNAL(finished()), this, SLOT(onTlsBitti()));
    connect(rep, SIGNAL(sslErrors(QList<QSslError>)), this, SLOT(onTlsHatalari(QList<QSslError>)));
    log("tls test: " + QUrl(url).host());
}

void Yardim::onTlsHatalari(const QList<QSslError> &e)
{
    QNetworkReply *r = qobject_cast<QNetworkReply *>(sender());
    foreach (const QSslError &x, e)
        log("tls sertifika hatasi " + QUrl(r->property("tlsUrl").toString()).host() + ": " + x.errorString()
            + (x.certificate().isNull() ? QString() : " [" + x.certificate().subjectInfo(QSslCertificate::CommonName) + " / veren " + x.certificate().issuerInfo(QSslCertificate::CommonName) + "]"));
}

void Yardim::onTlsBitti()
{
    QNetworkReply *r = qobject_cast<QNetworkReply *>(sender());
    r->deleteLater();
    const QString host = QUrl(r->property("tlsUrl").toString()).host();
    const int code = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QSslConfiguration c = r->sslConfiguration();
    QString zincir;
    foreach (const QSslCertificate &x, c.peerCertificateChain()) zincir += " > " + x.subjectInfo(QSslCertificate::CommonName);
    log(QString("tls sonuc %1: hata=%2 (%3) http=%4 sifre=%5 %6 zincir:%7")
        .arg(host).arg(int(r->error())).arg(r->errorString()).arg(code)
        .arg(c.sessionCipher().name()).arg(c.sessionCipher().protocolString()).arg(zincir));
}

QVariantMap Yardim::istekHatasi(const QString &method, const QString &url, const QVariantMap &headers, const QString &body)
{
    QVariantMap sonuc;
    sonuc["status"] = 0;
    sonuc["body"] = QString();
    if (!m_nam) m_nam = new QNetworkAccessManager(this);
    QNetworkRequest r((QUrl(url)));
    for (QVariantMap::const_iterator it = headers.constBegin(); it != headers.constEnd(); ++it)
        r.setRawHeader(it.key().toUtf8(), it.value().toString().toUtf8());
    QNetworkReply *rep = method == "GET" ? m_nam->get(r) : m_nam->post(r, body.toUtf8());
    QEventLoop dongu;
    QTimer zaman;
    zaman.setSingleShot(true);
    connect(&zaman, SIGNAL(timeout()), &dongu, SLOT(quit()));
    connect(rep, SIGNAL(finished()), &dongu, SLOT(quit()));
    zaman.start(30000);
    dongu.exec();
    if (rep->isFinished()) {
        sonuc["status"] = rep->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        sonuc["body"] = QString::fromUtf8(rep->readAll().left(4000));
        log(QString("istek ayrintisi %1: http %2, ag hatasi %3").arg(QUrl(url).host()).arg(sonuc["status"].toInt()).arg(int(rep->error())));
    } else {
        rep->abort();
        log("istek ayrintisi " + QUrl(url).host() + ": zaman asimi");
    }
    rep->deleteLater();
    return sonuc;
}

void Yardim::tlsTestDosyasi()
{
    QFile f(m_dir + "/tlstest.txt");
    if (!f.open(QIODevice::ReadOnly)) return;
    const QStringList adresler = QString::fromUtf8(f.readAll()).split(QRegExp("\\s+"), QString::SkipEmptyParts);
    f.close();
    f.remove();                        // bir kez calissin
    foreach (const QString &u, adresler) tlsTest(u);
}

// ---------------- Fotoğraflar ----------------

QVariantList Yardim::resimler() const
{
    QStringList kokler;
#if defined(Q_OS_SYMBIAN)
    kokler << "E:/Images" << "E:/DCIM" << "E:/Pictures" << "C:/Data/Images" << "F:/Images";
#else
    kokler << QDir::homePath() + "/Pictures" << QDir::homePath() + "/ApiLauncher";
#endif
    QList<QFileInfo> bulunan;
    QStringList filtre;
    filtre << "*.jpg" << "*.jpeg" << "*.png" << "*.JPG" << "*.JPEG" << "*.PNG";
    foreach (const QString &k, kokler) {
        if (!QDir(k).exists()) continue;
        QDirIterator it(k, filtre, QDir::Files, QDirIterator::Subdirectories);
        int n = 0;
        while (it.hasNext() && n < 600) { it.next(); bulunan << it.fileInfo(); ++n; }
    }
    // yeniden eskiye, en çok 90
    for (int i = 0; i < bulunan.size(); ++i)
        for (int j = i + 1; j < bulunan.size(); ++j)
            if (bulunan.at(j).lastModified() > bulunan.at(i).lastModified()) bulunan.swap(i, j);
    QVariantList out;
    for (int i = 0; i < bulunan.size() && i < 90; ++i) {
        QVariantMap m;
        m["yol"] = bulunan.at(i).absoluteFilePath();
        m["url"] = QUrl::fromLocalFile(bulunan.at(i).absoluteFilePath()).toString();
        m["ad"] = bulunan.at(i).fileName();
        m["tarih"] = bulunan.at(i).lastModified().toString("dd.MM.yyyy");
        out << m;
    }
    return out;
}

// Gönderim için küçült: en uzun kenar enBuyuk piksel, JPEG kalite; base64 döner (hata: boş)
QString Yardim::resimBase64(const QString &yol, int enBuyuk, int kalite) const
{
    QImageReader rd(yol);
    QSize s = rd.size();
    if (s.isValid() && (s.width() > enBuyuk || s.height() > enBuyuk)) {
        s.scale(enBuyuk, enBuyuk, Qt::KeepAspectRatio);
        rd.setScaledSize(s);                    // büyük kamera fotoğrafını belleğe tam açmadan küçült
    }
    QImage img = rd.read();
    if (img.isNull()) { const_cast<Yardim *>(this)->log("resim okunamadi: " + yol); return QString(); }
    if (img.width() > enBuyuk || img.height() > enBuyuk) img = img.scaled(enBuyuk, enBuyuk, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    QByteArray ba;
    QBuffer b(&ba);
    b.open(QIODevice::WriteOnly);
    img.save(&b, "JPG", kalite);
    const_cast<Yardim *>(this)->log(QString("resim hazir %1x%2 %3 KB").arg(img.width()).arg(img.height()).arg(ba.size() / 1024));
    return QString::fromLatin1(ba.toBase64());
}

QString Yardim::resimKaydet(const QString &base64, const QString &uzanti)
{
#if defined(Q_OS_SYMBIAN)
    QString klasor = QDir("E:/").exists() ? "E:/Images/ApiLauncher" : "C:/Data/Images/ApiLauncher";
#else
    QString klasor = QDir::homePath() + "/ApiLauncher/resimler";
#endif
    QDir().mkpath(klasor);
    const QString ext = uzanti.isEmpty() ? QString("png") : uzanti;
    const QString yol = klasor + "/resim_" + QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss") + "." + ext;
    QFile f(yol);
    if (!f.open(QIODevice::WriteOnly)) { log("resim kaydedilemedi: " + yol); return QString(); }
    f.write(QByteArray::fromBase64(base64.toLatin1()));
    f.close();
    log("resim kaydedildi " + yol + " " + QString::number(f.size() / 1024) + " KB");
    return yol;
}
