#include "volumekeys.h"

#ifdef Q_OS_SYMBIAN
#include <remconcoreapitarget.h>
#include <remconinterfaceselector.h>
#endif

VolumeKeys::VolumeKeys(QObject *parent)
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

VolumeKeys::~VolumeKeys()
{
#ifdef Q_OS_SYMBIAN
    delete m_selector;
#endif
}

void VolumeKeys::repeat()
{
    if (m_dir > 0) emit up();
    else if (m_dir < 0) emit down();
}

#ifdef Q_OS_SYMBIAN
void VolumeKeys::MrccatoCommand(TRemConCoreApiOperationId aOperationId, TRemConCoreApiButtonAction aButtonAct)
{
    int dir = 0;
    if (aOperationId == ERemConCoreApiVolumeUp) dir = 1;
    else if (aOperationId == ERemConCoreApiVolumeDown) dir = -1;
    else return;

    switch (aButtonAct) {
    case ERemConCoreApiButtonClick:
        m_repeat.stop();
        m_dir = dir;
        repeat();
        break;
    case ERemConCoreApiButtonPress:
        m_dir = dir;
        repeat();
        m_repeat.start();
        break;
    case ERemConCoreApiButtonRelease:
        m_repeat.stop();
        m_dir = 0;
        break;
    default:
        break;
    }
}
#endif
