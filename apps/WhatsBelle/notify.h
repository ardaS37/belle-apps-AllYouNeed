#ifndef NOTIFY_H
#define NOTIFY_H

#include <QtCore/QObject>
#include <QtCore/QTimer>

#ifdef Q_OS_SYMBIAN
class CAknSoftNotifier;
class QPiglerAPI;
#endif

// QML'e "notify" adiyla acilir:
//  - arka planda gelen mesajlar icin Symbian kose bildirimi (CAknDiscreetPopup) ve titresim
//  - durum cubugu cekmecesinde / bekleme ekraninda kalan bildirim (CAknSoftNotifier)
//  - arka plan zamanlayicisi: QML Timer'i (animasyon tabanli) uygulama arka plandayken
//    durabildigi icin bildirim kontrolu bu C++ zamanlayicisiyla tetiklenir
//  - kalici gunluk dosyasi (hata raporu icin)
//  - "telefon acilinca baslat" ayari
class Notify : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool autostart READ autostart WRITE setAutostart NOTIFY autostartChanged)
public:
    explicit Notify(QObject *parent = 0);
    ~Notify();

    Q_INVOKABLE void show(const QString &title, const QString &text);
    Q_INVOKABLE void vibrate(int ms);
    Q_INVOKABLE void sendToBackground();

    // Cekmece bildirimi. Pigler eklentisi kuruluysa durum cubugu cekmecesinde kendi metnimizle
    // (dokununca uygulama acilir, tapped(kind) gelir); degilse sistemin "sohbet mesaji" notu.
    // kind: "chat" | "mail" (her biri ayri satir). Uygulama acilinca clearPosted().
    Q_INVOKABLE void post(const QString &title, const QString &text, int count);
    Q_INVOKABLE void postKind(const QString &kind, const QString &title, const QString &text, int count);
    Q_INVOKABLE void clearPosted();
    Q_INVOKABLE bool screenOff() const;
    Q_INVOKABLE QString postInfo() const { return m_postInfo; }
    Q_INVOKABLE bool piglerReady() const { return m_pigOk; }
    Q_INVOKABLE QString piglerInfo() const { return m_pigInfo; }

    Q_INVOKABLE void startTicker(int ms);
    Q_INVOKABLE void stopTicker();

    Q_INVOKABLE void log(const QString &line);
    Q_INVOKABLE QString logText() const;
    Q_INVOKABLE void clearLog();

    bool autostart() const;
    void setAutostart(bool on);

    static bool startedAtBoot();      // telefon yeni acildiysa (ilk 3 dk)
    static bool autostartAllowed();   // ayar dosyasina bakar

signals:
    void autostartChanged();
    void tick();
    void tapped(const QString &kind);

private slots:
    void onPiglerTap(qint32 id);
    void removeTapped();

private:
    void initPigler();
    QTimer m_ticker;
    int m_noteId;
    int m_pending;
    QString m_postInfo;
    bool m_pigOk;
    QString m_pigInfo;
    int m_pigChat, m_pigMail;
    int m_countChat, m_countMail;
    int m_tapRemove;
    QString m_bootTap;
#ifdef Q_OS_SYMBIAN
    CAknSoftNotifier *m_soft;
    QPiglerAPI *m_pig;
#endif
public:
    Q_INVOKABLE QString takeBootTap() { QString k = m_bootTap; m_bootTap.clear(); return k; }
};

#endif
