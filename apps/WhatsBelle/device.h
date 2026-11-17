#ifndef DEVICE_H
#define DEVICE_H

#include <QtCore/QObject>
#include <QtCore/QStringList>
#include <QtCore/QTime>
#include <QtCore/QMap>

class QNetworkAccessManager;
class QNetworkReply;
class QTimer;

#include <qmobilityglobal.h>
#include <qmediarecorder.h>
#include <qaudiocapturesource.h>
#ifdef QTM_NAMESPACE
// Bu SDK'da QtMobility siniflari genel ad alaninda; yine de tanimliysa kullan
#endif

// QML'e "device" adiyla acilan yardimci: galeri dosyalari, yukleme, ses kaydi
class Device : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool recording READ recording NOTIFY recordingChanged)
    Q_PROPERTY(bool uploading READ uploading NOTIFY uploadingChanged)

public:
    explicit Device(QObject *parent = 0);

    // kind: "image", "video", "audio"  -> en yeniden eskiye mutlak dosya yollari
    Q_INVOKABLE QStringList mediaFiles(const QString &kind, int limit);
    Q_INVOKABLE QString scanInfo() const { return m_scanInfo; }      // son taramanin ozeti (tani icin)
    Q_INVOKABLE QString recordInfo() const { return m_recordInfo; }  // ses kaydi bicimleri (tani icin)
    Q_INVOKABLE QString fileName(const QString &path) const;
    Q_INVOKABLE void setClipboard(const QString &text);              // mesaj kopyalama
    Q_INVOKABLE QString fileSizeText(const QString &path) const;
    Q_INVOKABLE QString fileUrl(const QString &path) const;

    Q_INVOKABLE void upload(const QString &url, const QString &key,
                            const QString &sender, const QString &receiver,
                            const QString &filePath);
    Q_INVOKABLE void cancelUpload();

    // Sesli mesaj: sunucudan uygulamanin ozel klasorune indirilir (onbellek), sohbet balonunda calinir
    // name: "<rakamlar>.mp3"  -> audioReady(name, yol) / audioFailed(name, mesaj)
    Q_INVOKABLE void fetchAudio(const QString &url, const QString &name);
    Q_INVOKABLE QString cachedAudio(const QString &name) const;   // varsa yerel yol, yoksa ""

    Q_INVOKABLE bool startRecording();
    Q_INVOKABLE QString stopRecording();
    Q_INVOKABLE void cancelRecording();

    bool recording() const { return m_recording; }
    bool uploading() const { return m_reply != 0; }

signals:
    void uploadProgress(int percent);
    void uploadFinished(bool ok, const QString &message);
    void recordingChanged();
    void uploadingChanged();
    void recordSeconds(int seconds);
    void recordError(const QString &message);
    void audioReady(const QString &name, const QString &path);
    void audioFailed(const QString &name, const QString &message);

private slots:
    void onReplyFinished();
    void onAudioFinished();
    void onUploadProgress(qint64 sent, qint64 total);
    void onRecordTick();
    void onRecorderError(QMediaRecorder::Error error);

private:
    QStringList searchRoots() const;
    QString audioDir() const;
    QMap<QNetworkReply *, QString> m_audioJobs;
    QString m_scanInfo;
    QString m_recordInfo;

    QNetworkAccessManager *m_nam;
    QNetworkReply *m_reply;
    QAudioCaptureSource *m_source;
    QMediaRecorder *m_recorder;
    QTimer *m_tick;
    QTime m_recStart;
    QString m_recPath;
    bool m_recording;
};

#endif
