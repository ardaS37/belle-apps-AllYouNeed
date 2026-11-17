// QML'e "cihaz": galeri dosyalari, panoya kopyalama, sesli mesaj kaydi (mikrofon -> PCM -> OGG/Opus)
#ifndef CIHAZ_H
#define CIHAZ_H

#include <QtCore/QObject>
#include <QtCore/QStringList>
#include <QtCore/QTime>
#include <QtCore/QBuffer>

class QTimer;
#ifdef BG_SES
#include <qmobilityglobal.h>
#include <qaudioinput.h>
#include <qaudioformat.h>
#endif

class Cihaz : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool kayitta READ kayitta NOTIFY kayitDegisti)
public:
    explicit Cihaz(const QString &geciciKlasor, QObject *parent = 0);

    // tur: image | video | audio | file -> en yeniden eskiye mutlak yollar
    Q_INVOKABLE QStringList dosyalar(const QString &tur, int sinir);
    Q_INVOKABLE QString dosyaAdi(const QString &yol) const;
    Q_INVOKABLE QString boyutMetni(const QString &yol) const;
    Q_INVOKABLE QString url(const QString &yol) const;
    Q_INVOKABLE void panoya(const QString &metin);
    Q_INVOKABLE QString pano() const;
    // E6: tahmini yazimdaki (alti cizili) kelimeyi metne isle; yoksa Enter'dan once text eksik kalir
    Q_INVOKABLE void girisiTamamla() const;
    Q_INVOKABLE void ac(const QString &yol);

    // Ses kaydi: kayitBasla -> kayitBitir() OGG yolu ("" hata). sonSure / sonDalga (hex) son kaydin bilgileri
    Q_INVOKABLE bool kayitBasla();
    Q_INVOKABLE QString kayitBitir();
    Q_INVOKABLE void kayitIptal();
    Q_INVOKABLE int sonSure() const { return m_sonSure; }
    Q_INVOKABLE QString sonDalga() const { return m_sonDalga; }
    bool kayitta() const { return m_kayitta; }

signals:
    void kayitDegisti();
    void kayitSaniye(int saniye);
    void kayitHatasi(const QString &mesaj);

private slots:
    void tik();

private:
    QStringList kokler() const;
    QString m_gecici;
    QTimer *m_tik;
    QTime m_bas;
    bool m_kayitta;
    int m_sonSure, m_hz;
    QString m_sonDalga;
    QBuffer m_tampon;
#ifdef BG_SES
    QAudioInput *m_giris;
#endif
};

#endif
