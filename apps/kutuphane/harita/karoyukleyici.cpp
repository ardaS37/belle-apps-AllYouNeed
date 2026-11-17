#include "karoyukleyici.h"
#include "haritaag.h"
#include "cevrimdisi.h"

#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QDir>
#include <QtCore/QUrl>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkRequest>
#include <QtNetwork/QNetworkReply>

static const int KEsZamanli = 4;
static const int KSiraEnCok = 48;      // eski gorunumlerin istekleri atilir (hizli kaydirmada birikmesin)

KaroYukleyici::KaroYukleyici(QObject *parent) : QObject(parent), m_nam(new QNetworkAccessManager(this)) {}

KaroYukleyici *KaroYukleyici::tek()
{
    static KaroYukleyici *k = 0;
    if (!k) k = new KaroYukleyici;
    return k;
}

QString KaroYukleyici::yerel(const QString &uzak, int)
{
    if (uzak.isEmpty()) return QString();
    const QUrl u(uzak);
    const QString c = Cevrimdisi::dosyaYolu(u);
    if (QFile::exists(c)) return QUrl::fromLocalFile(c).toString();
    const QString o = HaritaNam::karoDosyasi(u);
    if (QFile::exists(o)) return QUrl::fromLocalFile(o).toString();
    if (m_hata.value(uzak) >= 3) return QString();            // bu oturumda 3 kez inmediyse vazgec
    if (m_bekleyen.contains(uzak)) {
        // zaten sirada: one al (su an ekranda isteniyor)
        const int i = m_sira.indexOf(uzak);
        if (i > 0) m_sira.move(i, 0);
        return QString();
    }
    m_bekleyen.insert(uzak);
    m_sira.prepend(uzak);
    while (m_sira.size() > KSiraEnCok) m_bekleyen.remove(m_sira.takeLast());
    sirayiIslet();
    return QString();
}

void KaroYukleyici::sirayiIslet()
{
    while (m_aktif.size() < KEsZamanli && !m_sira.isEmpty()) {
        const QString uzak = m_sira.takeFirst();
        QNetworkRequest r((QUrl(uzak)));
        // OSM karo kullanim kurali: uygulamayi tanitan User-Agent zorunlu
        r.setRawHeader("User-Agent", "BelleMaps/1.2 (Nokia E6 Symbian; Qt 4.8; kisisel kullanim)");
        QNetworkReply *rep = m_nam->get(r);
        m_aktif.insert(rep, uzak);
        connect(rep, SIGNAL(finished()), this, SLOT(bitti()));
    }
}

static bool resimMi(const QByteArray &b)
{
    return b.size() > 100 && (b.startsWith("\x89PNG") || b.startsWith("\xFF\xD8"));
}

void KaroYukleyici::bitti()
{
    QNetworkReply *rep = qobject_cast<QNetworkReply *>(sender());
    if (!rep) return;
    const QString uzak = m_aktif.take(rep);
    m_bekleyen.remove(uzak);
    const QByteArray veri = rep->readAll();
    const int durum = rep->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const bool ok = rep->error() == QNetworkReply::NoError && durum == 200 && resimMi(veri);
    rep->deleteLater();
    if (ok) {
        const QString dosya = HaritaNam::karoDosyasi(QUrl(uzak));
        QDir().mkpath(QFileInfo(dosya).absolutePath());
        QFile f(dosya + ".t");
        bool yazildi = false;
        if (f.open(QIODevice::WriteOnly)) {
            yazildi = f.write(veri) == veri.size();
            f.close();
            if (yazildi) { QFile::remove(dosya); yazildi = f.rename(dosya); } else f.remove();
        }
        if (yazildi) { m_hata.remove(uzak); emit hazir(uzak); }
    } else {
        m_hata[uzak] = m_hata.value(uzak) + 1;
    }
    sirayiIslet();
}
