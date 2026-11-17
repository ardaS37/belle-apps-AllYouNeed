#ifndef YARDIM_H
#define YARDIM_H

#include <QtCore/QObject>
#include <QtCore/QStringList>
#include <QtCore/QVariantList>
#include <QtCore/QVariantMap>
#include <QtNetwork/QSslError>

class QNetworkAccessManager;

// ApiLauncher (eski ApiLauncher) için QML'in tek başına yapamadığı işler:
//  - günlük: C:/Data/ApiLauncher/gunluk.txt (son 120 satır)
//  - sorun bildirme: günlüğü sunucunun /api/report ucuna gönderir (diğer uygulamalarla aynı sistem)
//  - fotoğraflar: telefondaki resimleri listeler, gönderilecek resmi küçültüp JPEG base64 yapar
//  - oluşturulan resmi (base64) hafıza kartına kaydeder
//  - telefon panosunu okur
class Yardim : public QObject
{
    Q_OBJECT
public:
    explicit Yardim(QObject *parent = 0);

    Q_INVOKABLE void log(const QString &s);
    Q_INVOKABLE QString gunluk() const;
    Q_INVOKABLE void raporGonder(const QString &sunucu, const QString &parola, const QString &not_);
    Q_INVOKABLE QVariantList resimler() const;                                   // [{yol, ad, tarih}] yeniden eskiye
    Q_INVOKABLE QString resimBase64(const QString &yol, int enBuyuk, int kalite) const;  // JPEG, base64
    Q_INVOKABLE QString resimKaydet(const QString &base64, const QString &uzanti);       // kaydedilen dosya yolu
    Q_INVOKABLE QString panoMetni() const;
    Q_INVOKABLE QString dosyaUrl(const QString &yol) const;
    // HTTPS tanisi: adrese GET atar, TLS surumu / sifre / sertifika hatalarini gunluge yazar
    Q_INVOKABLE void tlsTest(const QString &url);
    void tlsTestDosyasi();   // C:/Data/ApiLauncher/tlstest.txt varsa icindeki adresleri dener
    // Qt 4.7 XHR bazi HTTP kodlarinda (402, 429...) durum 0 verir ve govdeyi gizler. Ayni istegi
    // C++ ile yeniden atar (en cok 30 sn bekler): { status, body } ya da HTTP yanit yoksa status 0
    Q_INVOKABLE QVariantMap istekHatasi(const QString &method, const QString &url, const QVariantMap &headers, const QString &body);

signals:
    void raporBitti(bool ok, const QString &mesaj);

private slots:
    void onRapor();
    void onTlsBitti();
    void onTlsHatalari(const QList<QSslError> &e);

private:
    QString m_dir;
    QStringList m_log;
    QNetworkAccessManager *m_nam;
};

#endif
