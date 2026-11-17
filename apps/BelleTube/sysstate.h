#ifndef SYSSTATE_H
#define SYSSTATE_H

#include <QtCore/QObject>
#include <QtCore/QTimer>

#include <qmobilityglobal.h>

// Bu SDK'da sistem bilgisi siniflari QtMobility ad alaninda
QTM_BEGIN_NAMESPACE
class QSystemDeviceInfo;
class QSystemScreenSaver;
QTM_END_NAMESPACE
QTM_USE_NAMESPACE

// QML'e "sys" adiyla acilir.
//  - locked: tus/ekran kilidi acik mi (kilitlenince video arka plan sesine devredilir)
//  - keepScreenOn(true): video izlerken ekranin kendiliginden kapanmasini/kilitlenmesini engeller
class SysState : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool locked READ locked NOTIFY lockedChanged)
    // foreground: uygulama gercekten onde mi (Symbian pencere grubu odagi). Qt.application.active
    // yerel video penceresi acilinca yanlislikla false oluyor; bu yuzden ona guvenilmez.
    Q_PROPERTY(bool foreground READ foreground NOTIFY foregroundChanged)
public:
    explicit SysState(QObject *parent = 0);

    bool locked() const { return m_locked; }
    bool foreground() const { return m_foreground; }
    Q_INVOKABLE void keepScreenOn(bool on);

signals:
    void lockedChanged();
    void foregroundChanged();

private slots:
    void poll();

private:
    QSystemDeviceInfo *m_dev;
    QSystemScreenSaver *m_saver;
    QTimer m_poll;
    bool m_locked;
    bool m_foreground;
};

#endif
