#include "bildirim.h"

#include <QtCore/QFile>
#include <QtCore/QDir>
#include <QtCore/QFileInfo>
#include <QtCore/QDateTime>
#include <QtCore/QStringList>
#include <QtCore/QTimer>
#include <QtCore/QEvent>
#include <QtGui/QApplication>
#include <QtGui/QImage>

#ifdef Q_OS_SYMBIAN
#include <e32base.h>
#include <coemain.h>
#include <apgtask.h>
#include <akndiscreetpopup.h>
#include <aknsconstants.h>
#include <hwrmvibra.h>
#include "QPiglerAPI.h"

static const TUid KBelleGramUid = { 0xE39CF23F };

static TPtrC16 ptr(const QString &s)
{
    return TPtrC16(reinterpret_cast<const TUint16 *>(s.utf16()), s.length());
}
#endif

#define L1(s) QString::fromLatin1(s)

// klasor: pigler kimlik dosyasinin yeri (ozel klasor), gunluk: ortak gunluk dosyasi
Bildirim::Bildirim(const QString &klasor, const QString &gunluk, QObject *parent)
    : QObject(parent), m_dosya(klasor + L1("/pigler.txt")), m_gunluk(gunluk),
      m_onde(true), m_pigOk(false), m_silinecek(0)
#ifdef Q_OS_SYMBIAN
    , m_pig(0)
#endif
{
    // kayitli satirlar: "sohbet kimlik adet" (uygulama kapaliyken de cekmecede kalirlar)
    QFile f(m_dosya);
    if (f.open(QIODevice::ReadOnly)) {
        const QStringList satirlar = QString::fromUtf8(f.readAll()).split(QLatin1Char('\n'), QString::SkipEmptyParts);
        for (int i = 0; i < satirlar.size(); i++) {
            const QStringList p = satirlar.at(i).split(QLatin1Char(' '));
            if (p.size() < 3 || p.at(1).toInt() <= 0) continue;
            m_kimlik.insert(p.at(0), p.at(1).toInt());
            m_adet.insert(p.at(0), p.at(2).toInt());
        }
    }
    qApp->installEventFilter(this);
    piglerKur();
}

Bildirim::~Bildirim()
{
#ifdef Q_OS_SYMBIAN
    // kapanirken kalan bildirimler dokununca uygulamayi yeniden acsin
    if (m_pigOk && m_pig) {
        QMap<QString, int>::const_iterator it = m_kimlik.constBegin();
        for (; it != m_kimlik.constEnd(); ++it) m_pig->setLaunchAppOnTap(it.value(), true);
    }
#endif
}

bool Bildirim::eventFilter(QObject *o, QEvent *e)
{
    if (o == qApp && (e->type() == QEvent::ApplicationActivate || e->type() == QEvent::ApplicationDeactivate)) {
        const bool yeni = e->type() == QEvent::ApplicationActivate;
        if (yeni != m_onde) { m_onde = yeni; emit ondeDegisti(); }
    }
    return QObject::eventFilter(o, e);
}

void Bildirim::kayit(const QString &s)
{
    QFile f(m_gunluk);
    if (f.open(QIODevice::WriteOnly | QIODevice::Append))
        f.write((QDateTime::currentDateTime().toString(L1("dd.MM hh:mm:ss ")) + L1("bildirim: ") + s + L1("\n")).toUtf8());
}

void Bildirim::kaydet()
{
    QDir().mkpath(QFileInfo(m_dosya).absolutePath());
    QFile f(m_dosya);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) return;
    QMap<QString, int>::const_iterator it = m_kimlik.constBegin();
    for (; it != m_kimlik.constEnd(); ++it)
        f.write((it.key() + L1(" ") + QString::number(it.value()) + L1(" ") + QString::number(m_adet.value(it.key())) + L1("\n")).toUtf8());
}

// ---- Pigler (durum cubugu cekmecesi; eklenti BelleGram.sis icine gomulu) ----
void Bildirim::piglerKur()
{
#ifdef Q_OS_SYMBIAN
    m_pig = new QPiglerAPI(this);
    m_pig->setAppId(0xE39CF23F);                 // dokununca BelleGram acilsin
    const qint32 r = m_pig->init(L1("BelleGram"));
    if (r < 0) {
        m_pigBilgi = QString(L1("pigler yok (%1)")).arg(r);
        kayit(m_pigBilgi);
        delete m_pig;
        m_pig = 0;
        return;
    }
    m_pigOk = true;
    connect(m_pig, SIGNAL(handleTap(qint32)), this, SLOT(piglerDokunma(qint32)));
    m_pigBilgi = QString(L1("pigler v%1, en fazla %2")).arg(m_pig->getAPIVersion()).arg(m_pig->getMaxNotificationsCount());
    kayit(m_pigBilgi);
    // calisirken dokunma bize gelsin (ikinci kopya acilmasin)
    QMap<QString, int>::const_iterator it = m_kimlik.constBegin();
    for (; it != m_kimlik.constEnd(); ++it) m_pig->setLaunchAppOnTap(it.value(), false);
    if (r > 0) {                                  // uygulama bildirime dokunularak acildi
        m_acilis = m_kimlik.key(r);
        if (!m_acilis.isEmpty()) { m_kimlik.remove(m_acilis); m_adet.remove(m_acilis); kaydet(); }
    }
#endif
}

QString Bildirim::acilisSohbeti()
{
    const QString s = m_acilis;
    m_acilis.clear();
    return s;
}

void Bildirim::piglerDokunma(qint32 id)
{
    const QString sohbet = m_kimlik.key(id);
    m_kimlik.remove(sohbet);
    m_adet.remove(sohbet);
    kaydet();
    kayit(QString(L1("dokunuldu (%1)")).arg(id));
    // eklenti su an bu cagrinin donusunu bekliyor: silme biraz sonra
    m_silinecek = id;
    QTimer::singleShot(600, this, SLOT(dokunulaniSil()));
#ifdef Q_OS_SYMBIAN
    TApaTask t(CCoeEnv::Static()->WsSession());
    t.SetWgId(CCoeEnv::Static()->RootWin().Identifier());
    t.BringToForeground();
#endif
    if (!sohbet.isEmpty()) emit dokunuldu(sohbet);
}

void Bildirim::dokunulaniSil()
{
#ifdef Q_OS_SYMBIAN
    if (m_pigOk && m_pig && m_silinecek > 0) m_pig->removeNotification(m_silinecek);   // -1: eklenti zaten silmis
#endif
    m_silinecek = 0;
}

void Bildirim::mesaj(const QString &sohbet, const QString &baslik, const QString &metin, bool titresim)
{
    const QString kisaMetin = QString(metin).replace(QLatin1Char('\n'), QLatin1Char(' ')).left(200);
    if (m_onde) {                   // uygulama acik, baska sohbetteyiz: yalniz kose
        kose(baslik, kisaMetin);
        return;
    }
#ifdef Q_OS_SYMBIAN
    if (m_pigOk && m_pig) {
        const int n = m_adet.value(sohbet) + 1;
        const QString bas = n > 1 ? QString(L1("%1 (%2 yeni)")).arg(baslik).arg(n) : baslik;
        int id = m_kimlik.value(sohbet);
        qint32 r = m_pig->setNotification(id, bas, kisaMetin);
        if (id > 0 && r == KErrNone) r = id;           // var olani guncelleme: eklenti 0 dondurur
        if (r == KErrNotFound || r == KErrAccessDenied) { id = 0; r = m_pig->setNotification(0, bas, kisaMetin); }
        if (r > 0) {
            if (id != r) {
                m_pig->setRemoveOnTap(r, true);
                m_pig->setLaunchAppOnTap(r, false);
                QImage simge(L1(":/images/bildirim.png"));
                if (!simge.isNull()) m_pig->setNotificationIcon(r, simge);
            }
            m_kimlik.insert(sohbet, r);
            m_adet.insert(sohbet, n);
            kaydet();
        } else {
            kayit(QString(L1("pigler hatasi %1")).arg(r));
        }
    }
#else
    Q_UNUSED(sohbet);
#endif
    kose(baslik, kisaMetin);       // arka planda da ust kose kutusu gorunur
    if (titresim) titret(350);
}

void Bildirim::kose(const QString &baslik, const QString &metin)
{
#ifdef Q_OS_SYMBIAN
    const QString t = baslik.left(60);
    const QString x = metin.left(120);
    TRAPD(err, CAknDiscreetPopup::ShowGlobalPopupL(ptr(t), ptr(x), KAknsIIDNone, KNullDesC, 0, 0,
                                                   0, 0, NULL, KBelleGramUid, TUid::Null()));
    if (err != KErrNone) kayit(QString(L1("kose hatasi %1")).arg(err));
#else
    Q_UNUSED(baslik); Q_UNUSED(metin);
#endif
}

void Bildirim::titret(int ms)
{
#ifdef Q_OS_SYMBIAN
    static CHWRMVibra *vibra = 0;
    if (!vibra) TRAP_IGNORE(vibra = CHWRMVibra::NewL());
    if (vibra) TRAP_IGNORE(vibra->StartVibraL(ms));
#else
    Q_UNUSED(ms);
#endif
}

void Bildirim::temizle(const QString &sohbet)
{
    const int id = m_kimlik.value(sohbet);
    m_kimlik.remove(sohbet);
    m_adet.remove(sohbet);
    if (id <= 0) return;
    kaydet();
#ifdef Q_OS_SYMBIAN
    if (m_pigOk && m_pig) m_pig->removeNotification(id);
#endif
}

void Bildirim::hepsiniTemizle()
{
#ifdef Q_OS_SYMBIAN
    if (m_pigOk && m_pig) m_pig->removeAllNotifications();
#endif
    m_kimlik.clear();
    m_adet.clear();
    kaydet();
}
