#include "nativevideo.h"

#include <QtCore/QUrl>
#include <QtCore/QEvent>
#include <QtGui/QGraphicsScene>
#include <QtDeclarative/QDeclarativeView>
#include <qvideowidget.h>

QPointer<QDeclarativeView> NativeVideo::s_host;

void NativeVideo::setHost(QDeclarativeView *view)
{
    s_host = view;
}

NativeVideo::NativeVideo(QDeclarativeItem *parent)
    : QDeclarativeItem(parent), m_player(new QMediaPlayer(this)), m_widget(0), m_showVideo(true),
      m_mediaPending(false), m_wantPlay(false), m_volume(70)
{
    setFlag(QGraphicsItem::ItemHasNoContents, true);
    setFlag(QGraphicsItem::ItemSendsScenePositionChanges, true);

    connect(m_player, SIGNAL(positionChanged(qint64)), this, SIGNAL(positionChanged()));
    connect(m_player, SIGNAL(durationChanged(qint64)), this, SIGNAL(durationChanged()));
    connect(m_player, SIGNAL(stateChanged(QMediaPlayer::State)), this, SIGNAL(stateChanged()));
    connect(m_player, SIGNAL(mediaStatusChanged(QMediaPlayer::MediaStatus)), this, SIGNAL(statusChanged()));
    connect(m_player, SIGNAL(volumeChanged(int)), this, SIGNAL(volumeChanged()));
    connect(m_player, SIGNAL(playbackRateChanged(qreal)), this, SIGNAL(playbackRateChanged()));
    connect(m_player, SIGNAL(error(QMediaPlayer::Error)), this, SLOT(onError(QMediaPlayer::Error)));
    connect(m_player, SIGNAL(videoAvailableChanged(bool)), this, SIGNAL(videoAvailableChanged()));
    m_player->setNotifyInterval(500);
    // Symbian oynaticisi medya yuklenirken sesi kendi varsayilanina cekiyor: yuklenince ve calmaya
    // baslayinca istenen ses yeniden verilir
    connect(m_player, SIGNAL(mediaStatusChanged(QMediaPlayer::MediaStatus)), this, SLOT(reapplyVolume()));
    connect(m_player, SIGNAL(stateChanged(QMediaPlayer::State)), this, SLOT(reapplyVolume()));

    // Sayfa/ust ogeler hareket edince de yerel pencere dogru yerde kalsin
    m_sync.setInterval(400);
    connect(&m_sync, SIGNAL(timeout()), this, SLOT(syncWidget()));
    m_sync.start();
}

// Kilitlenince/arka plana gecince QML bu ogeyi tamamen yok eder, one donunce yeniden kurar.
// Sira onemli: once oynatici durur ve pencereden ayrilir, sonra oynatici, en son pencere silinir;
// aksi halde silinmis pencereye cizmeye calisan oynatici uygulamayi cokertebiliyor.
NativeVideo::~NativeVideo()
{
    m_sync.stop();
    if (m_player) {
        disconnect(m_player, 0, this, 0);
        m_player->stop();
        m_player->setMedia(QMediaContent());
        m_player->setVideoOutput(static_cast<QVideoWidget *>(0));
        delete m_player;
        m_player = 0;
    }
    if (m_widget) {
        m_widget->removeEventFilter(this);
        m_widget->hide();
        delete m_widget;
        m_widget = 0;
    }
}

void NativeVideo::ensureWidget()
{
    if (m_widget || !s_host) return;
    m_widget = new QVideoWidget(s_host->viewport());
    // Kendi Symbian penceresi (RWindow) olsun: video yuzeyi bu pencereye baglanir ve
    // ana pencerenin (QML arayuzunun) ustunde birlestirilir. Aksi halde arayuzun altinda kaliyor.
    m_widget->setAttribute(Qt::WA_NativeWindow);
    m_widget->winId();
    m_widget->setAspectRatioMode(Qt::KeepAspectRatio);
    m_widget->setAutoFillBackground(true);
    QPalette pal = m_widget->palette();
    pal.setColor(QPalette::Window, Qt::black);
    m_widget->setPalette(pal);
    m_widget->installEventFilter(this);
    m_widget->hide();
    m_player->setVideoOutput(m_widget);
}

void NativeVideo::syncWidget()
{
    ensureWidget();
    if (!m_widget || !s_host) return;
    const bool vis = m_showVideo && isVisible() && scene() && width() > 1 && height() > 1
                     && !m_source.isEmpty();
    if (!vis) {
        if (m_widget->isVisible()) m_widget->hide();
        return;
    }
    const QRectF sr = mapToScene(boundingRect()).boundingRect();
    const QRect r = s_host->mapFromScene(sr).boundingRect().intersected(s_host->viewport()->rect());
    if (r.width() < 2 || r.height() < 2) {
        if (m_widget->isVisible()) m_widget->hide();
        return;
    }
    if (m_widget->geometry() != r) m_widget->setGeometry(r);
    if (!m_widget->isVisible()) { m_widget->show(); m_widget->raise(); }
}

void NativeVideo::geometryChanged(const QRectF &n, const QRectF &o)
{
    QDeclarativeItem::geometryChanged(n, o);
    syncWidget();
}

QVariant NativeVideo::itemChange(GraphicsItemChange change, const QVariant &value)
{
    if (change == ItemVisibleHasChanged || change == ItemScenePositionHasChanged || change == ItemSceneHasChanged)
        QTimer::singleShot(0, this, SLOT(syncWidget()));
    return QDeclarativeItem::itemChange(change, value);
}

bool NativeVideo::eventFilter(QObject *obj, QEvent *ev)
{
    if (obj == m_widget && ev->type() == QEvent::MouseButtonRelease) {
        emit clicked();
        return true;
    }
    return QDeclarativeItem::eventFilter(obj, ev);
}

void NativeVideo::onError(QMediaPlayer::Error e)
{
    if (e != QMediaPlayer::NoError) emit error();
}

// Symbian: yeni olusturulan yerel pencere ekran sunucusunda etkinlesmeden medya baglanirsa
// oynatici -18 (KErrNotReady) veriyor. Bu yuzden once pencere gosterilir, medya biraz sonra verilir.
void NativeVideo::setSource(const QString &s)
{
    if (s == m_source) return;
    m_source = s;
    ensureWidget();
    if (s.isEmpty()) {
        m_mediaPending = false;
        m_wantPlay = false;
        m_player->stop();
        m_player->setMedia(QMediaContent());
    } else {
        m_mediaPending = true;
        syncWidget();                                  // pencereyi simdi goster (siyah)
        QTimer::singleShot(400, this, SLOT(applyMedia()));
    }
    syncWidget();
    emit sourceChanged();
}

void NativeVideo::applyMedia()
{
    if (!m_mediaPending || m_source.isEmpty()) return;
    m_mediaPending = false;
    syncWidget();
    if (m_widget) m_widget->repaint();
    m_player->setMedia(QMediaContent(QUrl(m_source)));
    if (m_wantPlay) m_player->play();
}

int NativeVideo::volume() const { return m_volume; }
void NativeVideo::setVolume(int v)
{
    m_volume = qBound(0, v, 100);
    m_player->setVolume(m_volume);
    emit volumeChanged();
}
void NativeVideo::reapplyVolume()
{
    if (!m_player) return;
    const QMediaPlayer::MediaStatus st = m_player->mediaStatus();
    const bool loaded = st == QMediaPlayer::LoadedMedia || st == QMediaPlayer::BufferedMedia;
    if (!loaded && m_player->state() != QMediaPlayer::PlayingState) return;
    // Oynatici "ayni deger" diye atlamasin: once bir basamak farkli, sonra istenen deger
    m_player->setVolume(m_volume > 0 ? m_volume - 1 : 1);
    m_player->setVolume(m_volume);
}
int NativeVideo::position() const { return int(m_player->position()); }
void NativeVideo::setPosition(int ms) { m_player->setPosition(qMax(0, ms)); }
int NativeVideo::duration() const { return int(m_player->duration()); }
bool NativeVideo::playing() const { return m_player->state() == QMediaPlayer::PlayingState; }
bool NativeVideo::paused() const { return m_player->state() == QMediaPlayer::PausedState; }
int NativeVideo::status() const { return int(m_player->mediaStatus()); }
QString NativeVideo::errorString() const { return m_player->errorString(); }
qreal NativeVideo::playbackRate() const { return m_player->playbackRate(); }
bool NativeVideo::videoAvailable() const { return m_player->isVideoAvailable(); }

QString NativeVideo::debugInfo() const
{
    QString s = QString("akis:%1 durum:%2").arg(m_player->isVideoAvailable() ? "var" : "yok").arg(int(m_player->mediaStatus()));
    if (m_widget) {
        const QRect g = m_widget->geometry();
        s += QString(" pencere:%1 %2x%3+%4+%5").arg(m_widget->isVisible() ? "acik" : "gizli")
                .arg(g.width()).arg(g.height()).arg(g.x()).arg(g.y());
    } else {
        s += " pencere:yok";
    }
    if (!m_player->errorString().isEmpty()) s += " hata:" + m_player->errorString();
    return s;
}
void NativeVideo::setPlaybackRate(qreal r) { m_player->setPlaybackRate(r); }

void NativeVideo::setShowVideo(bool s)
{
    if (s == m_showVideo) return;
    m_showVideo = s;
    syncWidget();
    emit showVideoChanged();
}

void NativeVideo::play() { m_wantPlay = true; syncWidget(); if (!m_mediaPending) m_player->play(); }
void NativeVideo::pause() { m_wantPlay = false; m_player->pause(); }
void NativeVideo::stop() { m_wantPlay = false; m_player->stop(); }
