#ifndef PIL_H
#define PIL_H

#include <QtCore/QObject>
#include <QtCore/QVariantList>
#include <QtCore/QStringList>
#include <QtCore/QDateTime>
#include <QtCore/QTimer>
#include <QtGui/QImage>

// QtMobility pil bilgisi: telefonda ve Qt Simulator'da
#if defined(Q_OS_SYMBIAN) || defined(Q_WS_SIMULATOR)
#define E6_MOBILITY 1
#include <qsystemdeviceinfo.h>
#ifdef Q_OS_SYMBIAN
#include <qsystembatteryinfo.h>   // telefonda gercek yuzdeyi dogru veriyor (Simulator'da cop deger)
#endif
QTM_USE_NAMESPACE
#endif

#include "homescreenwidget.h"

class QDeclarativeView;
class QNetworkAccessManager;
class QNetworkReply;

// QML'e "pil" adiyla acilir. Pil + hava durumu + RAM/CPU, tek ana ekran widget'i.
// Hafiflik:
// - Pil: yalnizca sistem bildirimleriyle (zamanlayici yok).
// - RAM/CPU: dakikada bir, YALNIZCA ana ekran widget'i gorunurken (ekran kapali / baska uygulama: durur).
// - Hava durumu: saatte bir, yalnizca telefonda zaten acik bir internet baglantisi varsa (baglanti kurdurmaz).
// - Arayuz (QML) yalnizca acikken bellekte.
// Widget: Nokia HSWidgetPlugin.dll (Wunderland'in yontemi).
//   "rows": "threerows" sablonu (70x70 resimde buyuk yuzde + 3 satir: pil, hava, RAM/CPU)
//   "wide": "wideimage" sablonu (312x82, hepsi cizilir)
class Pil : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int level READ level NOTIFY changed)
    Q_PROPERTY(int state READ state NOTIFY changed)            // 0 bilinmiyor, 1 pilde, 2 sarj oluyor, 3 dolu (prizde)
    Q_PROPERTY(QString stateText READ stateText NOTIFY changed)
    Q_PROPERTY(QString estimate READ estimate NOTIFY changed)
    Q_PROPERTY(QString updated READ updated NOTIFY changed)
    Q_PROPERTY(bool finePercent READ finePercent NOTIFY changed)
    Q_PROPERTY(int ramPercent READ ramPercent NOTIFY sysChanged)
    Q_PROPERTY(int ramFreeMB READ ramFreeMB NOTIFY sysChanged)
    Q_PROPERTY(int ramTotalMB READ ramTotalMB NOTIFY sysChanged)
    Q_PROPERTY(int cpuPercent READ cpuPercent NOTIFY sysChanged)
    Q_PROPERTY(QString city READ city NOTIFY weatherChanged)
    Q_PROPERTY(QString weatherText READ weatherText NOTIFY weatherChanged)
    Q_PROPERTY(QString weatherLine READ weatherLine NOTIFY weatherChanged)
    Q_PROPERTY(QString weatherUpdated READ weatherUpdated NOTIFY weatherChanged)
    Q_PROPERTY(QString weatherStatus READ weatherStatus NOTIFY weatherChanged)
    Q_PROPERTY(QVariantList forecast READ forecast NOTIFY weatherChanged)       // 7 gun: day,date,code,desc,max,min,rain,wind,sunrise,sunset
    Q_PROPERTY(QVariantList hourly READ hourly NOTIFY weatherChanged)           // onumuzdeki 24 saat: saat,temp,code,desc,rain
    Q_PROPERTY(double temp READ temp NOTIFY weatherChanged)
    Q_PROPERTY(double wind READ wind NOTIFY weatherChanged)
    Q_PROPERTY(bool hasWeather READ hasWeather NOTIFY weatherChanged)
    Q_PROPERTY(int wcode READ wcode NOTIFY weatherChanged)                      // anlik hava kodu (simge icin)
    Q_PROPERTY(QString widgetStatus READ widgetStatus NOTIFY widgetChanged)
    Q_PROPERTY(QString style READ style NOTIFY widgetChanged)
    Q_PROPERTY(QString previewUrl READ previewUrl NOTIFY widgetChanged)
    Q_PROPERTY(bool fullAlert READ fullAlert NOTIFY settingsChanged)
    Q_PROPERTY(int lowAlert READ lowAlert NOTIFY settingsChanged)
    Q_PROPERTY(int historyVersion READ historyVersion NOTIFY historyChanged)

public:
    explicit Pil(QObject *parent = 0);
    ~Pil();

    int level() const { return m_level; }
    int state() const { return m_state; }
    QString stateText() const;
    QString estimate() const { return m_estimate; }
    QString updated() const { return m_updated.toString("HH:mm"); }
    bool finePercent() const { return m_fine; }
    int ramPercent() const { return m_ramPct; }
    int ramFreeMB() const { return m_ramFreeMB; }
    int ramTotalMB() const { return m_ramTotalMB; }
    int cpuPercent() const { return m_cpuPct; }
    QString city() const { return m_city; }
    QString weatherText() const;
    QString weatherLine() const;
    QString weatherUpdated() const { return m_wUpdated.isNull() ? QString() : m_wUpdated.toString("dd.MM HH:mm"); }
    QString weatherStatus() const { return m_wStatus; }
    QVariantList forecast() const { return m_forecast; }
    QVariantList hourly() const { return m_hourly; }
    double temp() const { return m_temp; }
    double wind() const { return m_wind; }
    bool hasWeather() const { return m_wcode >= 0; }
    int wcode() const { return m_wcode; }
    QString widgetStatus() const { return m_widgetStatus; }
    QString style() const { return m_style; }
    QString previewUrl() const;
    bool fullAlert() const { return m_fullAlert; }
    int lowAlert() const { return m_lowAlert; }
    int historyVersion() const { return m_historyVersion; }

    bool startedAtBoot() const;
    void log(const QString &s);
    void setUiOpen(bool open);
    void finePercentResult(int pct, int err);

    Q_INVOKABLE QVariantList history(int hours) const;
    Q_INVOKABLE void setStyle(const QString &s);
    Q_INVOKABLE void setFullAlert(bool on);
    Q_INVOKABLE void setLowAlert(int percent);
    Q_INVOKABLE void republish();
    Q_INVOKABLE void retryWidget();
    Q_INVOKABLE QString logText() const;
    Q_INVOKABLE void quitApp();
    Q_INVOKABLE void setCity(const QString &name);     // ad ile ara (Open-Meteo geocoding), ilk sonucu kaydet
    Q_INVOKABLE void refreshWeather();                 // elle: sehri yeniden arayip (geocoding) gunceller; baglanti yoksa da dener

public slots:
    void refreshAll();     // pil + RAM/CPU + hava + widget'lar (QML'den de cagrilir)
    void refresh();
    void initWidget();

signals:
    void changed();
    void sysChanged();
    void weatherChanged();
    void widgetChanged();
    void settingsChanged();
    void historyChanged();
    void openRequested();

private slots:
    void onWidgetEvent(QHSEvent ev);
    void onWidgetItemEvent(QString item, QHSItemEvent ev);
    void onLiveTick();
    void onBarsChanged();
    void onWeatherTick();
    void onGeoReply();
    void onWeatherReply();
    void onBattTick();
    void publishQueued();

private:
    void readBattery();
    void requestFine();
    int m_finePct;
    void computeEstimate();
    void addSample();
    void loadHistory();
    void appendHistory();
    void loadSettings();
    void saveSettings();
    void publish(bool force);
    void publishOne(int i, bool force);
    void removeWidget();
    void sampleSys();
    void updateLiveTimer();
    void fetchWeather(bool manual);
    bool isOnline() const;
    QImage drawWide() const;
    QImage drawIcon() const;
    void vibrate(int ms);

    // pil
    int m_level;
    int m_state;
    bool m_fine;             // gercek yuzde mi (yoksa 7 basamakli cubuk)
    bool m_fullAlerted;
    bool m_lowAlerted;
    QString m_estimate;
    QDateTime m_updated;
    QList<uint> m_hT;
    QList<int> m_hL;
    QList<bool> m_hC;
    int m_historyVersion;
    // sistem
    int m_ramPct, m_ramFreeMB, m_ramTotalMB, m_cpuPct;
    qint64 m_lastIdleUs;
    qint64 m_lastWallUs;
    QTimer m_liveTimer;
    bool m_uiOpen;
    // hava
    QString m_city;
    double m_lat, m_lon;
    double m_temp;
    int m_wcode;
    bool m_isDay;
    QVariantList m_forecast;
    QVariantList m_hourly;
    double m_wind;
    QDateTime m_wUpdated;
    QString m_wStatus;
    QTimer m_weatherTimer;
    QNetworkAccessManager *m_nam;
    QNetworkReply *m_geoReply;
    QNetworkReply *m_wReply;
    // ayarlar / widget
    QString m_dir;
    QString m_style;
    QString m_widgetStatus;
    QString m_lastImage;
    int m_imageFlip;
    bool m_fullAlert;
    int m_lowAlert;
    // Iki sabit kimlikli widget: 0 = "BelleWidgets" (tworows), 1 = "BelleWidgets genis" (wideimage).
    // Icerik yalnizca ana ekran o widget'i etkinlestirdikten / surdurdukten sonra gonderilir.
    CHomeScreenWidget *m_w[2];
    bool m_wActive[2];
    bool m_wSusp[2];
    QString m_wKey[2];
    bool m_widgetReady;
    bool m_publishPending;
    QTimer m_battTimer;      // 5 dk: pil okuma (C++ zamanlayici; arka planda da calisir)
    int m_cpuErr;
#ifdef E6_MOBILITY
    QSystemDeviceInfo *m_info;
#ifdef Q_OS_SYMBIAN
    QSystemBatteryInfo *m_batt;
#endif
#endif
};

// Arayuz yalnizca kullanici acinca olusturulur (QML motoru arka planda bellekte durmaz).
// QML'e "ui" adiyla acilir.
class Ekran : public QObject
{
    Q_OBJECT
public:
    explicit Ekran(Pil *pil, QObject *parent = 0);
    bool eventFilter(QObject *o, QEvent *e);
    void quietFor(int ms) { m_quietUntil = QDateTime::currentDateTime().addMSecs(ms); }
public slots:
    void show();
    void hide();
private slots:
    void destroyView();
private:
    Pil *m_pil;
    QDeclarativeView *m_view;
    bool m_hiding;
    QDateTime m_quietUntil;
};

#endif
