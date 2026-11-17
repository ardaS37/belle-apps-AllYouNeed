#include "cihaz.h"
#include "dil.h"
#include "opusses.h"
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QDateTime>
#include <QtCore/QElapsedTimer>
#include <QtCore/QPair>
#include <QtCore/QTimer>
#include <QtCore/QUrl>
#include <QtCore/QtAlgorithms>
#include <QtGui/QApplication>
#include <QtGui/QClipboard>
#include <QtGui/QDesktopServices>
#include <QtGui/QWidget>
#include <QtGui/QInputContext>
#ifdef BG_SES
#include <qaudiodeviceinfo.h>
#endif

Cihaz::Cihaz(const QString &geciciKlasor, QObject *parent)
    : QObject(parent), m_gecici(geciciKlasor), m_tik(new QTimer(this)), m_kayitta(false), m_sonSure(0), m_hz(16000)
#ifdef BG_SES
      , m_giris(0)
#endif
{
    QDir().mkpath(m_gecici);
    m_tik->setInterval(500);
    connect(m_tik, SIGNAL(timeout()), this, SLOT(tik()));
}

// ---------------------------------------------------------------- galeri
QStringList Cihaz::kokler() const
{
    QStringList r;
#if defined(Q_OS_SYMBIAN)
    foreach (const QFileInfo &d, QDir::drives()) {
        QString p = d.absolutePath();
        if (p.startsWith(QLatin1Char('Z'), Qt::CaseInsensitive) || p.startsWith(QLatin1Char('D'), Qt::CaseInsensitive)) continue;
        if (p.startsWith(QLatin1Char('C'), Qt::CaseInsensitive)) p = QString::fromLatin1("C:/Data");
        if (QDir(p).exists()) r << p;
    }
    if (r.isEmpty()) r << QString::fromLatin1("C:/Data") << QString::fromLatin1("E:/");
#else
    r << QDesktopServices::storageLocation(QDesktopServices::PicturesLocation)
      << QDesktopServices::storageLocation(QDesktopServices::DocumentsLocation);
#endif
    return r;
}

static bool yeniOnce(const QFileInfo &a, const QFileInfo &b) { return a.lastModified() > b.lastModified(); }

static bool atlanacak(const QString &ad)
{
    const QString n = ad.toLower();
    return n.startsWith(QLatin1Char('.')) || n.startsWith(QLatin1Char('_')) || n == QLatin1String("private") || n == QLatin1String("sys")
        || n == QLatin1String("resource") || n == QLatin1String("system") || n == QLatin1String("logs") || n == QLatin1String("cache")
        || n == QLatin1String("thumbnails") || n == QLatin1String("installs") || n == QLatin1String("nokia") || n == QLatin1String("predic")
        || n == QLatin1String("widgets") || n == QLatin1String("games") || n == QLatin1String("mail") || n == QLatin1String("messages")
        || n == QLatin1String("bellegram");
}

QStringList Cihaz::dosyalar(const QString &tur, int sinir)
{
    QStringList uz;
    if (tur == QLatin1String("image")) uz << "jpg" << "jpeg" << "png" << "gif";
    else if (tur == QLatin1String("video")) uz << "mp4" << "3gp" << "3g2" << "m4v" << "avi";
    else if (tur == QLatin1String("audio")) uz << "amr" << "mp3" << "wav" << "aac" << "m4a" << "ogg";
    else uz << "pdf" << "txt" << "doc" << "docx" << "xls" << "xlsx" << "ppt" << "zip" << "rar" << "sis" << "sisx" << "jar" << "apk" << "epub";

    QElapsedTimer sure;
    sure.start();
    QList<QFileInfo> bulunan;
    int klasor = 0;
    foreach (const QString &kok, kokler()) {
        QList<QPair<QString, int> > kuyruk;
        kuyruk.append(qMakePair(kok, 0));
        while (!kuyruk.isEmpty() && sure.elapsed() < 6000 && klasor < 4000) {
            const QPair<QString, int> c = kuyruk.takeFirst();
            ++klasor;
            const QFileInfoList l = QDir(c.first).entryInfoList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot | QDir::Readable);
            foreach (const QFileInfo &fi, l) {
                if (fi.isDir()) {
                    if (c.second < 6 && !atlanacak(fi.fileName())) kuyruk.append(qMakePair(fi.absoluteFilePath(), c.second + 1));
                } else if (uz.contains(fi.suffix().toLower()) && fi.size() > 0) {
                    bulunan.append(fi);
                }
            }
        }
    }
    qSort(bulunan.begin(), bulunan.end(), yeniOnce);
    QStringList out;
    for (int i = 0; i < bulunan.size() && out.size() < sinir; ++i) {
        const QString p = bulunan.at(i).absoluteFilePath();
        if (!out.contains(p)) out << p;
    }
    return out;
}

QString Cihaz::dosyaAdi(const QString &yol) const { return QFileInfo(yol).fileName(); }

QString Cihaz::boyutMetni(const QString &yol) const
{
    const qint64 s = QFileInfo(yol).size();
    if (s >= 1024 * 1024) return QString::number(s / (1024.0 * 1024.0), 'f', 1) + QString::fromLatin1(" MB");
    return QString::number((s + 1023) / 1024) + QString::fromLatin1(" KB");
}

QString Cihaz::url(const QString &yol) const
{
    if (yol.isEmpty()) return QString();
    return QUrl::fromLocalFile(yol).toString();
}

void Cihaz::panoya(const QString &metin) { QApplication::clipboard()->setText(metin); }
QString Cihaz::pano() const { return QApplication::clipboard()->text(); }
void Cihaz::girisiTamamla() const
{
    QWidget *w = QApplication::focusWidget();
    if (w && w->inputContext()) w->inputContext()->reset();
}

void Cihaz::ac(const QString &yol) { QDesktopServices::openUrl(QUrl::fromLocalFile(yol)); }

// ---------------------------------------------------------------- ses kaydi
bool Cihaz::kayitBasla()
{
#ifdef BG_SES
    if (m_kayitta) return true;
    const QAudioDeviceInfo aygit = QAudioDeviceInfo::defaultInputDevice();
    QAudioFormat f;
    f.setChannels(1);
    f.setSampleSize(16);
    f.setSampleType(QAudioFormat::SignedInt);
    f.setByteOrder(QAudioFormat::LittleEndian);
    f.setCodec(QString::fromLatin1("audio/pcm"));
    const int hizlar[] = { 16000, 8000, 24000, 48000, 12000 };
    m_hz = 0;
    for (int i = 0; i < 5 && !m_hz; ++i) {
        f.setFrequency(hizlar[i]);
        if (aygit.isFormatSupported(f)) m_hz = hizlar[i];
    }
    if (!m_hz) {
        emit kayitHatasi(Dil::t("Mikrofon bu ses biçimini desteklemiyor."));
        return false;
    }
    f.setFrequency(m_hz);
    delete m_giris;
    m_giris = new QAudioInput(aygit, f, this);
    m_tampon.close();
    m_tampon.setData(QByteArray());
    m_tampon.open(QIODevice::WriteOnly);
    m_giris->start(&m_tampon);
    if (m_giris->error() != QAudio::NoError) {
        emit kayitHatasi(Dil::t("Mikrofon açılamadı (kod %1).").arg(int(m_giris->error())));
        return false;
    }
    m_kayitta = true;
    m_bas.start();
    m_tik->start();
    emit kayitDegisti();
    emit kayitSaniye(0);
    return true;
#else
    emit kayitHatasi(Dil::t("Bu sürümde ses kaydı yok."));
    return false;
#endif
}

QString Cihaz::kayitBitir()
{
#ifdef BG_SES
    if (!m_kayitta) return QString();
    m_giris->stop();
    m_tik->stop();
    m_kayitta = false;
    emit kayitDegisti();
    const QByteArray pcm = m_tampon.data();
    m_tampon.close();
    m_tampon.setData(QByteArray());
    if (pcm.size() < m_hz) {    // yarim saniyeden kisa
        emit kayitHatasi(Dil::t("Kayıt çok kısa."));
        return QString();
    }
    QString hata;
    int sure = 0;
    const QByteArray ogg = OpusSes::kodla(pcm, m_hz, &sure, &hata);
    if (ogg.isEmpty()) { emit kayitHatasi(Dil::t("Ses kodlanamadı: ") + hata); return QString(); }
    m_sonSure = qMax(1, sure);
    m_sonDalga = QString::fromLatin1(OpusSes::dalga(pcm).toHex());
    const QString yol = m_gecici + QString::fromLatin1("/kayit_") + QDateTime::currentDateTime().toString(QString::fromLatin1("yyyyMMdd_hhmmss")) + QString::fromLatin1(".ogg");
    QFile d(yol);
    if (!d.open(QIODevice::WriteOnly) || d.write(ogg) != ogg.size()) { emit kayitHatasi(Dil::t("Kayıt yazılamadı.")); return QString(); }
    d.close();
    return yol;
#else
    return QString();
#endif
}

void Cihaz::kayitIptal()
{
#ifdef BG_SES
    if (!m_kayitta) return;
    m_giris->stop();
    m_tik->stop();
    m_kayitta = false;
    m_tampon.close();
    m_tampon.setData(QByteArray());
    emit kayitDegisti();
#endif
}

void Cihaz::tik()
{
    if (m_kayitta) emit kayitSaniye(m_bas.elapsed() / 1000);
}
