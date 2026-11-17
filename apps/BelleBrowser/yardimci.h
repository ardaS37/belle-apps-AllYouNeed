#ifndef YARDIMCI_H
#define YARDIMCI_H

// QML'e "tb" adiyla verilen yardimci: ayarlar, sunucu parolasi, imlec tiklamasi, pano, harici acma.
#include <QtCore/QObject>
#include <QtCore/QPointF>
#include <QtCore/QStringList>

class QDeclarativeView;
class QNetworkAccessManager;

class Yardimci : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString mod READ mod NOTIFY ayarDegisti)
    Q_PROPERTY(QString ua READ ua NOTIFY ayarDegisti)
    Q_PROPERTY(QString sunucu READ sunucu NOTIFY ayarDegisti)
    Q_PROPERTY(bool parolaVar READ parolaVar NOTIFY ayarDegisti)
    Q_PROPERTY(int resimW READ resimW NOTIFY ayarDegisti)
    Q_PROPERTY(int resimQ READ resimQ NOTIFY ayarDegisti)
    Q_PROPERTY(bool reklam READ reklam NOTIFY ayarDegisti)
    Q_PROPERTY(bool sertifikaYoksay READ sertifikaYoksay NOTIFY ayarDegisti)
    Q_PROPERTY(QString tasarruf READ tasarruf NOTIFY istatistik)
    Q_PROPERTY(bool yaziKipi READ yaziKipi WRITE setYaziKipi NOTIFY yaziKipiDegisti)
public:
    explicit Yardimci(QDeclarativeView *view, QObject *parent = 0);
    QString mod() const;
    QString ua() const;
    QString sunucu() const;
    bool parolaVar() const;
    int resimW() const;
    int resimQ() const;
    bool reklam() const;
    bool sertifikaYoksay() const;
    QString tasarruf() const;
    bool yaziKipi() const { return m_yazi; }
    void setYaziKipi(bool y) { if (y != m_yazi) { m_yazi = y; emit yaziKipiDegisti(); } }

    Q_INVOKABLE void setMod(const QString &m);
    Q_INVOKABLE void setUa(const QString &u);
    Q_INVOKABLE void setResim(int w, int q);
    Q_INVOKABLE void setReklam(bool b);
    Q_INVOKABLE void setSertifikaYoksay(bool b);
    Q_INVOKABLE void setSunucu(const QString &adres);
    Q_INVOKABLE int setParola(const QString &p);            // 1 dogru, 0 hatali, -1 ulasilamadi
    Q_INVOKABLE void parolaSil();

    Q_INVOKABLE void tikla(qreal sx, qreal sy, bool cift);  // sahne koordinati (QML mapToItem(null))
    Q_INVOKABLE QString pano() const;
    Q_INVOKABLE void setPano(const QString &s);
    Q_INVOKABLE bool disaAc(const QString &url);
    Q_INVOKABLE QString anahtarliAdres(const QString &yol) const;   // sunucu + yol + key (video oynatici icin)
    Q_INVOKABLE QString vekilAdres(const QString &url) const;       // https video/dosya: sunucudan akit
    Q_INVOKABLE QString okumaAdres(const QString &url) const;
    // Sade gorunum: sayfa sunucudaki Chrome'da acilip tek sutuna indirilir (yerlesim bozuk sitelere)
    Q_INVOKABLE QString sadeAdres(const QString &url) const;
    // Gece temasi: Symbian yazi tahmini (henuz onaylanmamis sozcuk) ve form kutulari pencere paletinin
    // yazi rengini kullanir; varsayilan siyah oldugu icin koyu zeminde gorunmuyordu
    Q_INVOKABLE void setKoyu(bool koyu);
    Q_INVOKABLE void cerezSil();
    Q_INVOKABLE void onbellekSil();
    Q_INVOKABLE QString ayar(const QString &k, const QString &v) const;
    Q_INVOKABLE void setAyar(const QString &k, const QString &v);
    Q_INVOKABLE bool belleRemoteAc(const QString &url);
    Q_INVOKABLE QString surum() const { return "1.1"; }
    Q_INVOKABLE void log(const QString &s);                         // E:/BelleBrowser/gunluk.txt
    Q_INVOKABLE QString gunluk() const;                             // son satirlar
    Q_INVOKABLE void raporGonder(const QString &not_, const QString &ek);   // sunucu /api/report
    void setGunlukYolu(const QString &y) { m_gunluk = y; }

signals:
    void ayarDegisti();
    void istatistik();
    void yaziKipiDegisti();
    void yaziBitir();           // yazi kipinde orta tus / Esc: sayfadan cik, imlece don
    void sayfaBaglam(qreal sx, qreal sy);   // sayfada uzun basma (WebKit'in Ingilizce menusu yerine): sahne koordinati
    void raporBitti(bool ok, const QString &mesaj);

protected:
    bool eventFilter(QObject *o, QEvent *e);
    void timerEvent(QTimerEvent *);

private slots:
    void birak();
    void raporCevap();

private:
    QDeclarativeView *m_view;
    bool m_yazi;
    QPoint m_bas;
    bool m_cift;
    QString m_gunluk;
    QNetworkAccessManager *m_nam;
};

#endif
