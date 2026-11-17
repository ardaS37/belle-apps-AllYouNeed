#include "mediakeys.h"

#ifdef Q_OS_SYMBIAN
#include <remconcoreapitarget.h>
#include <remconinterfaceselector.h>
#endif

MediaKeys::MediaKeys(QObject *parent)
    : QObject(parent), m_dir(0)
#ifdef Q_OS_SYMBIAN
    , m_selector(0), m_target(0)
#endif
{
    m_repeat.setInterval(220);
    connect(&m_repeat, SIGNAL(timeout()), this, SLOT(repeat()));
#ifdef Q_OS_SYMBIAN
    TRAPD(err, {
        m_selector = CRemConInterfaceSelector::NewL();
        m_target = CRemConCoreApiTarget::NewL(*m_selector, *this);   // secici sahiplenir
        m_selector->OpenTargetL();
    });
    if (err != KErrNone) {
        delete m_selector;
        m_selector = 0;
        m_target = 0;
    }
#endif
}

MediaKeys::~MediaKeys()
{
#ifdef Q_OS_SYMBIAN
    delete m_selector;
#endif
}

void MediaKeys::repeat()
{
    if (m_dir > 0) emit up();
    else if (m_dir < 0) emit down();
}

#ifdef Q_OS_SYMBIAN
void MediaKeys::MrccatoCommand(TRemConCoreApiOperationId aOperationId, TRemConCoreApiButtonAction aButtonAct)
{
    // Ses tuslari: basili tutma destekli
    if (aOperationId == ERemConCoreApiVolumeUp || aOperationId == ERemConCoreApiVolumeDown) {
        const int dir = aOperationId == ERemConCoreApiVolumeUp ? 1 : -1;
        switch (aButtonAct) {
        case ERemConCoreApiButtonClick: m_repeat.stop(); m_dir = dir; repeat(); break;
        case ERemConCoreApiButtonPress: m_dir = dir; repeat(); m_repeat.start(); break;
        case ERemConCoreApiButtonRelease: m_repeat.stop(); m_dir = 0; break;
        default: break;
        }
        return;
    }
    // Kumanda tuslari: yalnizca tiklama/basma aninda bir kez
    if (aButtonAct == ERemConCoreApiButtonRelease) return;
    switch (aOperationId) {
    case ERemConCoreApiPausePlayFunction:
    case ERemConCoreApiPlay:
    case ERemConCoreApiPause:
        emit playPause();
        break;
    case ERemConCoreApiStop:
        emit stop();
        break;
    case ERemConCoreApiForward:
    case ERemConCoreApiFastForward:
        emit next();
        break;
    case ERemConCoreApiBackward:
    case ERemConCoreApiRewind:
        emit previous();
        break;
    default:
        break;
    }
}

void MediaKeys::MrccatoPlay(TRemConCoreApiPlaybackSpeed, TRemConCoreApiButtonAction aButtonAct)
{
    if (aButtonAct != ERemConCoreApiButtonRelease) emit playPause();
}
#endif
