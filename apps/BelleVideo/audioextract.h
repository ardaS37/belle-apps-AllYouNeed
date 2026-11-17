#ifndef AUDIOEXTRACT_H
#define AUDIOEXTRACT_H

#include <QtCore/QObject>
#include <QtCore/QFile>
#include <QtCore/QTimer>
#include <QtCore/QVector>
#include <QtCore/QByteArray>

// MP4/3GP/MOV videonun ses izini (AAC/MP3) ayri, parcalanmamis bir .m4a dosyasina kopyalar.
// Yeniden kodlama yok: ses ornekleri oldugu gibi tasinir, yalnizca yeni bir moov kutusu yazilir.
//
// Neden: Symbian'da video dosyasi "yalnizca ses" oynaticisina verilince yine video oturumu
// aciliyor ve donanim video cozucusu kullaniliyor. Ekran kilitlenince cozucu uygulamadan
// alininca (-12015 KErrMMDecoder) oynatici hata verip uygulamayi cokertebiliyor.
// Ayri ses dosyasi saf ses oturumunda calar, kilitte de sorunsuz surer.
//
// Is kucuk parcalar halinde zamanlayiciyla yapilir; arayuz ve oynatma donmaz.
class AudioExtract : public QObject
{
    Q_OBJECT
public:
    explicit AudioExtract(QObject *parent = 0);

    // Hedef dosya hazirsa hemen true doner; degilse cikarmayi baslatir (oncekini iptal eder)
    bool start(const QString &src, const QString &dst);
    void cancel();
    bool busy() const { return m_timer.isActive(); }
    QString source() const { return m_src; }
    int progress() const;           // 0-100
    QString lastError() const { return m_err; }

signals:
    void finished(const QString &src, const QString &dst, bool ok, const QString &message);

private slots:
    void step();

private:
    bool parse();
    bool buildHeader(QByteArray &out);
    void fail(const QString &msg);

    QString m_src, m_dst, m_err;
    QFile m_in, m_out;
    QTimer m_timer;

    // kaynaktan alinan kutular (ham, baslik dahil)
    QByteArray m_mvhd, m_tkhd, m_mdhd, m_hdlr, m_smhd, m_stsd, m_stts, m_stsz;
    // ornek tablosu
    QVector<quint32> m_sizes;
    QVector<qint64> m_chunkOffsets;
    QVector<quint32> m_chunkSamples;   // her parcadaki ornek sayisi
    int m_chunk;                       // siradaki parca
    int m_sample;                      // siradaki ornek
    qint64 m_total, m_done;
};

#endif
