#ifndef MEDIAKEYS_H
#define MEDIAKEYS_H

#include <QtCore/QObject>
#include <QtCore/QTimer>

#ifdef Q_OS_SYMBIAN
#include <remconcoreapitargetobserver.h>
class CRemConInterfaceSelector;
class CRemConCoreApiTarget;
#endif

// Ses tuslari ve kulaklik/bluetooth kumanda tuslari (Symbian RemCon).
// Ses tusu basili tutulunca up()/down() tekrarlanir.
class MediaKeys : public QObject
#ifdef Q_OS_SYMBIAN
    , public MRemConCoreApiTargetObserver
#endif
{
    Q_OBJECT
public:
    explicit MediaKeys(QObject *parent = 0);
    ~MediaKeys();

#ifdef Q_OS_SYMBIAN
    void MrccatoCommand(TRemConCoreApiOperationId aOperationId, TRemConCoreApiButtonAction aButtonAct);
    void MrccatoPlay(TRemConCoreApiPlaybackSpeed aSpeed, TRemConCoreApiButtonAction aButtonAct);
#endif

signals:
    void up();
    void down();
    void playPause();
    void next();
    void previous();
    void stop();

private slots:
    void repeat();

private:
    QTimer m_repeat;
    int m_dir;
#ifdef Q_OS_SYMBIAN
    CRemConInterfaceSelector *m_selector;
    CRemConCoreApiTarget *m_target;
#endif
};

#endif
