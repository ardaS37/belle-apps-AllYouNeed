#ifndef NATIVEVIDEO_H
#define NATIVEVIDEO_H

#include <QtDeclarative/QDeclarativeItem>
#include <QtCore/QTimer>
#include <QtCore/QPointer>
#include <qmediaplayer.h>

class QVideoWidget;
class QDeclarativeView;

// QML'de "NativeVideo": Symbian'in yerel video penceresi (QVideoWidget) ile oynatir.
// QML Video ogesi E6'da goruntu vermedigi icin bu yol kullanilir. Yerel pencere QML
// arayuzunun USTUNDE durur; ogenin ekrandaki yerine ve gorunurlugune gore konumlandirilir.
// Bu yuzden videonun uzerine QML ile bir sey cizilemez (kontroller videonun altinda).
class NativeVideo : public QDeclarativeItem
{
    Q_OBJECT
    Q_PROPERTY(QString source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(int volume READ volume WRITE setVolume NOTIFY volumeChanged)          // 0-100
    Q_PROPERTY(int position READ position WRITE setPosition NOTIFY positionChanged)  // ms
    Q_PROPERTY(int duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(bool playing READ playing NOTIFY stateChanged)
    Q_PROPERTY(bool paused READ paused NOTIFY stateChanged)
    // QMediaPlayer::MediaStatus: 2 yukleniyor, 3 yuklendi, 4 takildi, 5 tamponluyor,
    // 6 tamponlandi, 7 sona geldi, 8 gecersiz
    Q_PROPERTY(int status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY error)
    Q_PROPERTY(qreal playbackRate READ playbackRate WRITE setPlaybackRate NOTIFY playbackRateChanged)
    Q_PROPERTY(bool showVideo READ showVideo WRITE setShowVideo NOTIFY showVideoChanged)
    Q_PROPERTY(bool videoAvailable READ videoAvailable NOTIFY videoAvailableChanged)

public:
    explicit NativeVideo(QDeclarativeItem *parent = 0);
    ~NativeVideo();

    static void setHost(QDeclarativeView *view);

    QString source() const { return m_source; }
    void setSource(const QString &s);
    int volume() const;
    void setVolume(int v);
    int position() const;
    void setPosition(int ms);
    int duration() const;
    bool playing() const;
    bool paused() const;
    int status() const;
    QString errorString() const;
    qreal playbackRate() const;
    void setPlaybackRate(qreal r);
    bool showVideo() const { return m_showVideo; }
    void setShowVideo(bool s);
    bool videoAvailable() const;

    // Tani: goruntu akisi, durum ve pencere konumu
    Q_INVOKABLE QString debugInfo() const;
    Q_INVOKABLE void play();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void stop();

signals:
    void sourceChanged();
    void volumeChanged();
    void positionChanged();
    void durationChanged();
    void stateChanged();
    void statusChanged();
    void error();
    void playbackRateChanged();
    void showVideoChanged();
    void videoAvailableChanged();
    void clicked();

protected:
    void geometryChanged(const QRectF &newGeometry, const QRectF &oldGeometry);
    QVariant itemChange(GraphicsItemChange change, const QVariant &value);
    bool eventFilter(QObject *obj, QEvent *ev);

private slots:
    void syncWidget();
    void onError(QMediaPlayer::Error e);
    void applyMedia();
    void reapplyVolume();

private:
    void ensureWidget();

    static QPointer<QDeclarativeView> s_host;
    QMediaPlayer *m_player;
    QVideoWidget *m_widget;
    QString m_source;
    QTimer m_sync;
    bool m_showVideo;
    bool m_mediaPending;   // pencere ekranda yerini alana kadar medya bekletilir
    bool m_wantPlay;       // medya yuklenince oynatilsin mi
    int m_volume;          // istenen ses (oynatici medya yuklerken sifirlayabiliyor; yeniden uygulanir)
};

#endif
