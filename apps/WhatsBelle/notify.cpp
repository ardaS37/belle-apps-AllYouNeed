#include "notify.h"

#include <QtCore/QFile>
#include <QtCore/QDir>
#include <QtCore/QFileInfo>
#include <QtCore/QDateTime>
#include <QtCore/QTextStream>

#ifdef Q_OS_SYMBIAN
#include <e32base.h>
#include <hal.h>
#include <coemain.h>
#include <apgtask.h>
#include <akndiscreetpopup.h>
#include <aknsconstants.h>
#include <hwrmvibra.h>
#include <AknSoftNotifier.h>
#include <hwrmlight.h>
#include "QPiglerAPI.h"
#include <QtGui/QImage>

static const TUid KWhatsBelleUid = { 0xE39CF226 };

static TPtrC16 ptr(const QString &s)
{
    return TPtrC16(reinterpret_cast<const TUint16 *>(s.utf16()), s.length());
}
#endif

// Ayar dosyasi: varsa acilista baslatma kapali
static QString offFile()
{
#ifdef Q_OS_SYMBIAN
    return QString("C:/Data/WhatsE6/autostart.off");
#else
    return QDir::tempPath() + "/whatse6_autostart.off";
#endif
}

static QString logFile()
{
#ifdef Q_OS_SYMBIAN
    return QString("C:/Data/WhatsE6/gunluk.txt");
#else
    return QDir::tempPath() + "/whatse6_gunluk.txt";
#endif
}

static QString piglerIdsFile()
{
#ifdef Q_OS_SYMBIAN
    return QString("C:/Data/WhatsE6/pigler.txt");
#else
    return QDir::tempPath() + "/whatse6_pigler.txt";
#endif
}

Notify::Notify(QObject *parent)
    : QObject(parent), m_noteId(0), m_pending(0), m_pigOk(false),
      m_pigChat(0), m_pigMail(0), m_countChat(0), m_countMail(0), m_tapRemove(0)
#ifdef Q_OS_SYMBIAN
    , m_soft(0), m_pig(0)
#endif
{
    connect(&m_ticker, SIGNAL(timeout()), this, SIGNAL(tick()));
    initPigler();
}

Notify::~Notify()
{
#ifdef Q_OS_SYMBIAN
    delete m_soft;
    // Kapanirken kalan bildirimler dokununca uygulamayi yeniden acsin
    if (m_pigOk && m_pig) {
        if (m_pigChat) m_pig->setLaunchAppOnTap(m_pigChat, true);
        if (m_pigMail) m_pig->setLaunchAppOnTap(m_pigMail, true);
    }
#endif
}

// ---- Pigler (durum cubugu cekmecesi; ayrica "Pigler Notifications API" eklentisi kurulmali) ----
void Notify::initPigler()
{
    QFile f(piglerIdsFile());
    if (f.open(QIODevice::ReadOnly)) {
        const QStringList parts = QString::fromUtf8(f.readAll()).split(' ');
        if (parts.size() >= 2) { m_pigChat = parts.at(0).toInt(); m_pigMail = parts.at(1).toInt(); }
        f.close();
    }
#ifdef Q_OS_SYMBIAN
    m_pig = new QPiglerAPI(this);
    m_pig->setAppId(0xE39CF226);                 // dokununca WhatsBelle acilsin
    const qint32 r = m_pig->init("WhatsE6");
    if (r < 0) {
        m_pigInfo = QString("pigler yok (%1)").arg(r);
        delete m_pig;
        m_pig = 0;
        return;
    }
    m_pigOk = true;
    connect(m_pig, SIGNAL(handleTap(qint32)), this, SLOT(onPiglerTap(qint32)));
    m_pigInfo = QString("pigler v%1, en fazla %2").arg(m_pig->getAPIVersion()).arg(m_pig->getMaxNotificationsCount());
    if (r > 0) m_bootTap = (r == m_pigMail) ? "mail" : "chat";    // uygulama bildirime dokunularak acildi
#endif
}

static void saveIds(int chat, int mail)
{
    QDir().mkpath(QFileInfo(piglerIdsFile()).absolutePath());
    QFile f(piglerIdsFile());
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) { f.write(QByteArray::number(chat) + " " + QByteArray::number(mail)); f.close(); }
}

void Notify::onPiglerTap(qint32 id)
{
    const QString kind = (id == m_pigMail) ? "mail" : "chat";
    if (id == m_pigMail) { m_pigMail = 0; m_countMail = 0; }
    if (id == m_pigChat) { m_pigChat = 0; m_countChat = 0; }
    saveIds(m_pigChat, m_pigMail);
    log(QString("pigler: bildirime dokunuldu (%1, kimlik %2)").arg(kind).arg(id));
    // Eklenti dokunulan bildirimi kendisi silmeli; silmezse biz silelim. Eklenti su an bu
    // dokunma cagrisinin donusunu bekledigi icin silme istegi biraz sonra gonderilir.
    m_tapRemove = id;
    QTimer::singleShot(600, this, SLOT(removeTapped()));
#ifdef Q_OS_SYMBIAN
    TApaTask t(CCoeEnv::Static()->WsSession());
    t.SetWgId(CCoeEnv::Static()->RootWin().Identifier());
    t.BringToForeground();
#endif
    emit tapped(kind);
}

void Notify::removeTapped()
{
#ifdef Q_OS_SYMBIAN
    if (m_pigOk && m_pig && m_tapRemove > 0) {
        const qint32 r = m_pig->removeNotification(m_tapRemove);
        log(QString("pigler: dokunulan bildirim silindi (sonuc %1)").arg(r));   // -1: eklenti zaten silmis
    }
#endif
    m_tapRemove = 0;
}

void Notify::postKind(const QString &kind, const QString &title, const QString &text, int count)
{
    if (count <= 0) return;
#ifdef Q_OS_SYMBIAN
    if (m_pigOk && m_pig) {
        const bool mail = kind == "mail";
        int &id = mail ? m_pigMail : m_pigChat;
        int &n = mail ? m_countMail : m_countChat;
        n += count;
        const QString head = n > 1 ? QString("%1 (%2 yeni)").arg(title).arg(n) : title;
        qint32 r = m_pig->setNotification(id, head, text);
        if (id > 0 && r == KErrNone) r = id;                 // var olani guncelleme basarili: eklenti 0 dondurur
        if (r == KErrNotFound || r == KErrAccessDenied) r = m_pig->setNotification(0, head, text);   // eski kimlik gecersiz
        if (r > 0) {
            if (id != r) {
                id = r;
                m_pig->setRemoveOnTap(id, true);
                // Uygulama calisirken ikinci kopyasi acilmasin: dokunma bize gelir, one kendimiz geliriz.
                // Uygulama kapanirken (yikicida) acma secenegi geri acilir.
                m_pig->setLaunchAppOnTap(id, false);
                QImage icon(mail ? ":/images/nav_mail_on_d.png" : ":/images/nav_chats_on_d.png");
                if (!icon.isNull()) m_pig->setNotificationIcon(id, icon);
            }
            saveIds(m_pigChat, m_pigMail);
            m_postInfo = QString("pigler: %1 kimlik=%2 adet=%3").arg(kind).arg(id).arg(n);
            log(m_postInfo);
            return;
        }
        m_postInfo = QString("pigler hatasi %1, eski yonteme donuldu").arg(r);
        log(m_postInfo);
    }
#endif
    post(title, text, count);
}

void Notify::show(const QString &title, const QString &text)
{
#ifdef Q_OS_SYMBIAN
    const QString t = title.left(60);
    const QString x = text.left(120);
    TRAPD(err, CAknDiscreetPopup::ShowGlobalPopupL(ptr(t), ptr(x), KAknsIIDNone, KNullDesC, 0, 0,
                                                   0, 0, NULL, KWhatsBelleUid, TUid::Null()));
    if (err != KErrNone) log(QString("kose bildirimi hatasi: %1").arg(err));
#else
    Q_UNUSED(title); Q_UNUSED(text);
#endif
}

// Durum cubugu cekmecesi / bekleme ekrani: sistemin "sohbet mesaji" yumusak bildirimi.
// Metni sistem belirler ("N yeni sohbet mesaji"); uygulama acilinca kaldirilir.
// Ekran isigi kapali mi (telefon kullanilmiyor). Okunamazsa "acik" sayilir.
bool Notify::screenOff() const
{
#ifdef Q_OS_SYMBIAN
    static CHWRMLight *light = 0;
    if (!light) TRAP_IGNORE(light = CHWRMLight::NewL());
    if (!light) return false;
    return light->LightStatus(CHWRMLight::EPrimaryDisplay) == CHWRMLight::ELightOff;
#else
    return false;
#endif
}

// Nokia'nin "yeni sohbet mesaji" notu: yalnizca ekran kapaliyken (telefona bakilmiyorken)
void Notify::post(const QString &title, const QString &text, int count)
{
    Q_UNUSED(title); Q_UNUSED(text);
    if (count <= 0) return;
    if (!screenOff()) {
        m_postInfo = "nokia notu atlandi (ekran acik)";
        log(m_postInfo);
        return;
    }
    m_pending += count;
#ifdef Q_OS_SYMBIAN
    TInt err = KErrNone;
    if (!m_soft) TRAP(err, m_soft = CAknSoftNotifier::NewL());
    if (m_soft) TRAP(err, m_soft->SetNotificationCountL(EChatMessageNotification, m_pending));
    m_postInfo = QString("cekmece: adet=%1 sonuc=%2").arg(m_pending).arg(err);
    log(m_postInfo);
#endif
}

void Notify::clearPosted()
{
#ifdef Q_OS_SYMBIAN
    // Uygulama one gelince bu uygulamanin tum cekmece bildirimleri silinir (kimlik bilinmese de)
    if (m_pigOk && m_pig) {
        const qint32 n = m_pig->removeAllNotifications();
        if (n > 0) log(QString("pigler: %1 bildirim silindi").arg(n));
        m_pigChat = m_pigMail = 0;
        m_countChat = m_countMail = 0;
        saveIds(0, 0);
    }
#endif
    if (m_pending == 0) return;
    m_pending = 0;
#ifdef Q_OS_SYMBIAN
    if (m_soft) {
        TRAPD(err, m_soft->CancelSoftNotificationL(EChatMessageNotification));
        Q_UNUSED(err);
    }
#endif
}

void Notify::startTicker(int ms)
{
    if (m_ticker.isActive() && m_ticker.interval() == ms) return;
    m_ticker.start(ms);
    log(QString("zamanlayici: %1 sn").arg(ms / 1000));
}

void Notify::stopTicker()
{
    if (m_ticker.isActive()) log("zamanlayici durdu");
    m_ticker.stop();
}

// ---- Kalici gunluk (en fazla ~48 KB, son kisim tutulur) ----
void Notify::log(const QString &line)
{
    QDir().mkpath(QFileInfo(logFile()).absolutePath());
    QFile f(logFile());
    if (f.size() > 48 * 1024 && f.open(QIODevice::ReadOnly)) {
        QByteArray all = f.readAll();
        f.close();
        all = all.right(24 * 1024);
        const int nl = all.indexOf('\n');
        if (nl >= 0) all = all.mid(nl + 1);
        if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) { f.write(all); f.close(); }
    }
    if (f.open(QIODevice::WriteOnly | QIODevice::Append)) {
        const QString s = QDateTime::currentDateTime().toString("dd.MM hh:mm:ss") + " " + line + "\n";
        f.write(s.toUtf8());
        f.close();
    }
}

QString Notify::logText() const
{
    QFile f(logFile());
    if (!f.open(QIODevice::ReadOnly)) return QString();
    return QString::fromUtf8(f.readAll());
}

void Notify::clearLog()
{
    QFile::remove(logFile());
}

void Notify::vibrate(int ms)
{
#ifdef Q_OS_SYMBIAN
    static CHWRMVibra *vibra = 0;
    if (!vibra) TRAP_IGNORE(vibra = CHWRMVibra::NewL());
    if (vibra) TRAP_IGNORE(vibra->StartVibraL(ms));
#else
    Q_UNUSED(ms);
#endif
}

void Notify::sendToBackground()
{
#ifdef Q_OS_SYMBIAN
    TApaTask t(CCoeEnv::Static()->WsSession());
    t.SetWgId(CCoeEnv::Static()->RootWin().Identifier());
    t.SendToBackground();
#endif
}

bool Notify::autostart() const { return autostartAllowed(); }

void Notify::setAutostart(bool on)
{
    if (on == autostart()) return;
    if (on) {
        QFile::remove(offFile());
    } else {
        QDir().mkpath(QFileInfo(offFile()).absolutePath());
        QFile f(offFile());
        if (f.open(QIODevice::WriteOnly)) { f.write("kapali"); f.close(); }
    }
    emit autostartChanged();
}

bool Notify::autostartAllowed()
{
    return !QFile::exists(offFile());
}

bool Notify::startedAtBoot()
{
#ifdef Q_OS_SYMBIAN
    TInt period = 1000;
    HAL::Get(HALData::ENanoTickPeriod, period);   // mikrosaniye
    const qint64 upMs = (qint64)User::NTickCount() * period / 1000;
    return upMs < 3 * 60 * 1000;
#else
    return false;
#endif
}
