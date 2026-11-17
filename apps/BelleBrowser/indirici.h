#ifndef INDIRICI_H
#define INDIRICI_H

// Indirme yoneticisi (QML'de "indir"): baglantidaki dosyayi E:/Downloads'a (ayarlanabilir) indirir.
// Sunucu modunda HTTPS dosyalar da sunucu katmanindan gelir (eski TLS sorunu yok).
#include <QtCore/QObject>
#include <QtCore/QVariantList>
#include <QtCore/QHash>
#include <QtCore/QPointer>

class QNetworkAccessManager;
class QNetworkReply;
class QFile;

class Indirici : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList liste READ liste NOTIFY degisti)
    Q_PROPERTY(QString klasor READ klasor NOTIFY degisti)
    Q_PROPERTY(int etkin READ etkin NOTIFY degisti)
public:
    explicit Indirici(QObject *parent = 0);
    QVariantList liste() const;
    QString klasor() const;
    int etkin() const;
    Q_INVOKABLE int baslat(const QString &url, const QString &adOneri);
    Q_INVOKABLE void iptal(int id);
    Q_INVOKABLE void kaldir(int id, bool dosyaSil);
    Q_INVOKABLE QString yol(int id) const;
    Q_INVOKABLE void setKlasor(const QString &d);
    Q_INVOKABLE void temizle();             // biten/iptal olanlari listeden kaldir

signals:
    void degisti();
    void bitti(const QString &ad, const QString &yol, bool ok, const QString &mesaj);

private slots:
    void meta();
    void veri();
    void son();
    void ilerleme(qint64 a, qint64 t);

private:
    struct Is { int id; QString url, ad, yol, durum; qint64 alinan, toplam; QPointer<QNetworkReply> r; QFile *f; };
    QString benzersiz(const QString &ad) const;
    Is *bul(QNetworkReply *r);
    QNetworkAccessManager *m_nam;
    QList<Is *> m_isler;
    int m_sira;
};

#endif
