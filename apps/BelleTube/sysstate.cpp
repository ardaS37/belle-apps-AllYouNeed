#include "sysstate.h"

#include <qsystemdeviceinfo.h>
#include <qsystemscreensaver.h>
#include <QtGui/QApplication>

#ifdef Q_OS_SYMBIAN
#include <coemain.h>
#include <w32std.h>
#endif

SysState::SysState(QObject *parent)
    : QObject(parent), m_dev(new QSystemDeviceInfo(this)), m_saver(0), m_locked(false), m_foreground(true)
{
    // lockStatusChanged sinyali her surumde gelmeyebiliyor; yarim saniyede bir yoklamak ucuz ve guvenli
    m_poll.setInterval(500);
    connect(&m_poll, SIGNAL(timeout()), this, SLOT(poll()));
    m_poll.start();
    poll();
}

void SysState::poll()
{
    const bool l = (m_dev->lockStatus() & QSystemDeviceInfo::TouchAndKeyboardLocked) != 0;
    if (l != m_locked) {
        m_locked = l;
        emit lockedChanged();
    }
    bool fg = true;
#ifdef Q_OS_SYMBIAN
    // Odaktaki pencere grubu bizimki mi? (video penceresi de ayni grupta oldugu icin etkilenmez)
    CCoeEnv *env = CCoeEnv::Static();
    if (env) fg = env->WsSession().GetFocusWindowGroup() == env->RootWin().Identifier();
#else
    fg = QApplication::activeWindow() != 0;
#endif
    if (fg != m_foreground) {
        m_foreground = fg;
        emit foregroundChanged();
    }
}

void SysState::keepScreenOn(bool on)
{
    if (on) {
        if (!m_saver) {
            m_saver = new QSystemScreenSaver(this);
            m_saver->setScreenSaverInhibited(true);
        }
    } else if (m_saver) {
        delete m_saver;          // silinince engel kalkar
        m_saver = 0;
    }
}
