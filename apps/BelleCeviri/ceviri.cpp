#include "ceviri.h"

#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QDateTime>
#include <QtCore/QUrl>
#include <QtCore/QTimer>
#include <QtGui/QApplication>
#include <QtGui/QClipboard>
#include <QtGui/QWidget>
#include <QtGui/QInputContext>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkRequest>
#include <QtNetwork/QNetworkReply>

Ceviri::Ceviri(const QString &veri, QObject *parent)
    : QObject(parent), m_veri(veri), m_nam(new QNetworkAccessManager(this))
{
    QDir().mkpath(m_veri);
    QFile g(m_veri + "/gunluk.txt");
    if (g.open(QIODevice::ReadOnly)) {
        m_gunluk = QString::fromUtf8(g.readAll()).split('\n', QString::SkipEmptyParts);
        while (m_gunluk.size() > 150) m_gunluk.removeFirst();
    }
}

void Ceviri::istek(const QString &id, const QString &yontem, const QString &url, const QVariantMap &basliklar, const QString &govde)
{
    QNetworkRequest r(QUrl::fromEncoded(url.toUtf8()));
    r.setRawHeader("User-Agent", "Mozilla/5.0 (Symbian/3; NokiaE6-00) BelleCeviri/0.1");
    for (QVariantMap::const_iterator it = basliklar.constBegin(); it != basliklar.constEnd(); ++it)
        r.setRawHeader(it.key().toUtf8(), it.value().toString().toUtf8());
    QNetworkReply *rep = yontem.toUpper() == "POST" ? m_nam->post(r, govde.toUtf8()) : m_nam->get(r);
    rep->setProperty("id", id);
    connect(rep, SIGNAL(finished()), this, SLOT(bitti()));
}

void Ceviri::iptal(const QString &onEk)
{
    foreach (QNetworkReply *r, m_nam->findChildren<QNetworkReply *>())
        if (r->property("id").toString().startsWith(onEk) && r->isRunning()) { r->setProperty("iptal", true); r->abort(); }
}

void Ceviri::bitti()
{
    QNetworkReply *r = qobject_cast<QNetworkReply *>(sender());
    if (!r) return;
    r->deleteLater();
    if (r->property("iptal").toBool()) return;
    const int kod = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QString govde = QString::fromUtf8(r->readAll());
    QString hata;
    if (kod == 0 && r->error() != QNetworkReply::NoError) hata = r->errorString();
    emit yanit(r->property("id").toString(), kod, govde, hata);
}

void Ceviri::panoya(const QString &metin) { QApplication::clipboard()->setText(metin); }
QString Ceviri::pano() const { return QApplication::clipboard()->text(); }
void Ceviri::girisiTamamla() const
{
    QWidget *w = QApplication::focusWidget();
    if (w && w->inputContext()) w->inputContext()->reset();
}

bool Ceviri::dosyaVar(const QString &yol) const { return QFileInfo(yol).exists(); }
QString Ceviri::dosyaOku(const QString &yol) const
{
    QFile f(yol);
    if (!f.open(QIODevice::ReadOnly) || f.size() > 64 * 1024) return QString();
    return QString::fromUtf8(f.readAll());
}
bool Ceviri::dosyaSil(const QString &yol) { return QFile::remove(yol); }

void Ceviri::kayit(const QString &s)
{
    m_gunluk << QDateTime::currentDateTime().toString("dd.MM HH:mm:ss ") + s;
    while (m_gunluk.size() > 150) m_gunluk.removeFirst();
    QFile g(m_veri + "/gunluk.txt");
    if (g.open(QIODevice::WriteOnly | QIODevice::Truncate)) g.write((m_gunluk.join("\n") + "\n").toUtf8());
}

QString Ceviri::gunluk() const { return m_gunluk.join("\n"); }

void Ceviri::zamanla(const QString &ad, int ms)
{
    QTimer *t = new QTimer(this);
    t->setSingleShot(true);
    t->setObjectName(ad);
    connect(t, SIGNAL(timeout()), this, SLOT(zamanTik()));
    t->start(qMax(1, ms));
}

void Ceviri::zamanTik()
{
    QTimer *t = qobject_cast<QTimer *>(sender());
    if (!t) return;
    const QString ad = t->objectName();
    t->deleteLater();
    emit zamanDoldu(ad);
}
