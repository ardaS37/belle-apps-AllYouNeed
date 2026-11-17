#ifndef VOLUMEKEYS_H
#define VOLUMEKEYS_H

#include <QtCore/QObject>
#include <QtCore/QTimer>

#ifdef Q_OS_SYMBIAN
#include <remconcoreapitargetobserver.h>
class CRemConInterfaceSelector;
class CRemConCoreApiTarget;
#endif

// Ses tuslari: Symbian'da medya uygulamalari ses tuslarini sistemin uzaktan kumanda
// servisinden (RemCon) alir. Uygulama ondeyken tus basildikca up()/down() yayar;
// basili tutulunca tekrarlar.
class VolumeKeys : public QObject
#ifdef Q_OS_SYMBIAN
    , public MRemConCoreApiTargetObserver
#endif
{
    Q_OBJECT
public:
    explicit VolumeKeys(QObject *parent = 0);
    ~VolumeKeys();

#ifdef Q_OS_SYMBIAN
    void MrccatoCommand(TRemConCoreApiOperationId aOperationId, TRemConCoreApiButtonAction aButtonAct);
#endif

signals:
    void up();
    void down();

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
