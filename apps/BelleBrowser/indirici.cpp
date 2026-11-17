#include "indirici.h"
#include "katman.h"

#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QSettings>
#include <QtCore/QVariantMap>
#include <QtCore/QRegExp>
#include <QtNetwork/QNetworkReply>

static QSettings &ayar() { static QSettings s("BelleBrowser", "Genel"); return s; }

Indirici::Indirici(QObject *parent) : QObject(parent), m_nam(new KatmanNam(this)), m_sira(0) {}

QString Indirici::klasor() const
{
    QString d = ayar().value("indirmeKlasoru").toString();
    if (d.isEmpty()) {
#if defined(Q_OS_SYMBIAN)
        d = QDir("E:/").exists() ? QString("E:/Downloads") : QString("C:/Data/Downloads");
#else
        d = QDir::homePath() + "/Downloads";
#endif
    }
    QDir().mkpath(d);
    return d;
}

void Indirici::setKlasor(const QString &d) { ayar().setValue("indirmeKlasoru", d); ayar().sync(); emit degisti(); }

int Indirici::etkin() const { int n = 0; foreach (Is *i, m_isler) if (i->durum == "iniyor") ++n; return n; }

QVariantList Indirici::liste() const
{
    QVariantList l;
    for (int k = m_isler.size() - 1; k >= 0; --k) {
        const Is *i = m_isler.at(k);
        QVariantMap m;
        m["id"] = i->id; m["ad"] = i->ad; m["yol"] = i->yol; m["url"] = i->url; m["durum"] = i->durum;
        m["alinan"] = double(i->alinan); m["toplam"] = double(i->toplam);
        l << m;
    }
    return l;
}

QString Indirici::benzersiz(const QString &adIn) const
{
    QString ad = adIn;
    ad.replace(QRegExp("[\\\\/:*?\"<>|]"), "_");
    if (ad.isEmpty()) ad = "indirilen";
    const QString k = klasor();
    QString p = k + "/" + ad;
    if (!QFileInfo(p).exists()) return p;
    const int nokta = ad.lastIndexOf('.');
    const QString kok = nokta > 0 ? ad.left(nokta) : ad, uz = nokta > 0 ? ad.mid(nokta) : QString();
    for (int n = 2; n < 1000; ++n) { p = k + "/" + kok + " (" + QString::number(n) + ")" + uz; if (!QFileInfo(p).exists()) break; }
    return p;
}

int Indirici::baslat(const QString &url, const QString &adOneri)
{
    QUrl u = QUrl::fromUserInput(url);
    if (!u.isValid()) return -1;
    Is *i = new Is;
    i->id = ++m_sira; i->url = u.toString(); i->alinan = 0; i->toplam = -1; i->durum = "iniyor"; i->f = 0;
    QString ad = adOneri.trimmed();
    if (ad.isEmpty()) ad = QUrl::fromPercentEncoding(u.path().section('/', -1).toUtf8());
    i->ad = ad.isEmpty() ? QString("indirilen") : ad;
    i->yol = benzersiz(i->ad);
    i->f = new QFile(i->yol + ".part", this);
    if (!i->f->open(QIODevice::WriteOnly)) { delete i->f; delete i; return -1; }
    QNetworkRequest req(u);
    req.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::AlwaysNetwork);
    i->r = m_nam->get(req);
    connect(i->r, SIGNAL(metaDataChanged()), this, SLOT(meta()));
    connect(i->r, SIGNAL(readyRead()), this, SLOT(veri()));
    connect(i->r, SIGNAL(finished()), this, SLOT(son()));
    connect(i->r, SIGNAL(downloadProgress(qint64,qint64)), this, SLOT(ilerleme(qint64,qint64)));
    m_isler << i;
    emit degisti();
    return i->id;
}

Indirici::Is *Indirici::bul(QNetworkReply *r) { foreach (Is *i, m_isler) if (i->r == r) return i; return 0; }

void Indirici::meta()
{
    QNetworkReply *r = qobject_cast<QNetworkReply *>(sender());
    Is *i = bul(r);
    if (!i) return;
    const QString cd = QString::fromUtf8(r->rawHeader("Content-Disposition"));
    QRegExp rx("filename\\*?=(?:UTF-8'')?\"?([^\";]+)\"?", Qt::CaseInsensitive);
    if (rx.indexIn(cd) >= 0) {
        const QString yeni = QUrl::fromPercentEncoding(rx.cap(1).toUtf8()).trimmed();
        if (!yeni.isEmpty() && yeni != i->ad) {
            i->ad = yeni;
            const QString eskiPart = i->yol + ".part";
            i->yol = benzersiz(yeni);
            i->f->close();
            QFile::rename(eskiPart, i->yol + ".part");
            i->f->setFileName(i->yol + ".part");
            i->f->open(QIODevice::Append);
        }
    }
}

void Indirici::veri()
{
    QNetworkReply *r = qobject_cast<QNetworkReply *>(sender());
    Is *i = bul(r);
    if (!i || !i->f) return;
    const QByteArray b = r->readAll();
    if (i->f->write(b) != b.size()) { i->durum = "hata"; r->abort(); }
    i->alinan += b.size();
}

void Indirici::ilerleme(qint64 a, qint64 t)
{
    Is *i = bul(qobject_cast<QNetworkReply *>(sender()));
    if (!i) return;
    if (t > 0) i->toplam = t;
    Q_UNUSED(a);
    emit degisti();
}

void Indirici::son()
{
    QNetworkReply *r = qobject_cast<QNetworkReply *>(sender());
    Is *i = bul(r);
    if (!i) return;
    if (i->f) { i->f->write(r->readAll()); i->f->close(); }
    const int kod = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const bool ok = r->error() == QNetworkReply::NoError && (kod == 0 || kod < 400) && i->durum == "iniyor";
    QString mesaj;
    if (ok) {
        QFile::remove(i->yol);
        QFile::rename(i->yol + ".part", i->yol);
        i->durum = "bitti";
        i->toplam = i->alinan;
    } else {
        QFile::remove(i->yol + ".part");
        if (i->durum == "iniyor") i->durum = r->error() == QNetworkReply::OperationCanceledError ? "iptal" : "hata";
        mesaj = kod >= 400 ? "HTTP " + QString::number(kod) : r->errorString();
    }
    r->deleteLater();
    i->r = 0;
    if (i->f) { i->f->deleteLater(); i->f = 0; }
    emit degisti();
    emit bitti(i->ad, i->yol, ok, mesaj);
}

void Indirici::iptal(int id) { foreach (Is *i, m_isler) if (i->id == id && i->r) { i->durum = "iptal"; i->r->abort(); } }

void Indirici::kaldir(int id, bool dosyaSil)
{
    for (int k = 0; k < m_isler.size(); ++k) {
        Is *i = m_isler.at(k);
        if (i->id != id) continue;
        if (i->r) { i->durum = "iptal"; i->r->abort(); }
        if (dosyaSil) QFile::remove(i->yol);
        m_isler.removeAt(k);
        delete i;
        break;
    }
    emit degisti();
}

QString Indirici::yol(int id) const { foreach (Is *i, m_isler) if (i->id == id) return i->yol; return QString(); }

void Indirici::temizle()
{
    for (int k = m_isler.size() - 1; k >= 0; --k) if (m_isler.at(k)->durum != "iniyor") { delete m_isler.at(k); m_isler.removeAt(k); }
    emit degisti();
}
