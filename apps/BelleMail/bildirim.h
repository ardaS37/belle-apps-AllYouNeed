#ifndef BILDIRIM_H
#define BILDIRIM_H

#include <QtCore/QObject>
#include <QtCore/QMap>
#include <QtCore/QString>

#ifdef Q_OS_SYMBIAN
class QPiglerAPI;
#endif

// QML'e "bildirim" adiyla acilir (BelleGram'dan; BelleMail'de tek satir "posta"):
//  - durum cubugu cekmecesi: Pigler eklentisi (SIS'e gomulu). Her anahtara bir satir:
//    "Ad (3 yeni)" + son mesaj; dokununca uygulama one gelir, dokunuldu(sohbet) yayilir
//  - ust kose bildirimi (CAknDiscreetPopup) ve titresim (CHWRMVibra)
//  - uygulama onde mi (onde): QApplication etkin/etkisiz olaylarindan
class Bildirim : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool onde READ onde NOTIFY ondeDegisti)
public:
    Bildirim(const QString &klasor, const QString &gunluk, QObject *parent = 0);
    ~Bildirim();

    bool onde() const { return m_onde; }

    // yeni mesaj: arka plandaysa cekmece satiri + kose + titresim; ondeyse yalniz kose
    Q_INVOKABLE void mesaj(const QString &sohbet, const QString &baslik, const QString &metin, bool titret);
    Q_INVOKABLE void kose(const QString &baslik, const QString &metin);
    Q_INVOKABLE void titret(int ms);
    Q_INVOKABLE void temizle(const QString &sohbet);   // sohbet acildi / okundu
    Q_INVOKABLE void hepsiniTemizle();
    Q_INVOKABLE void arkaPlan();                      // uygulamayi kapatmadan arka plana al
    Q_INVOKABLE QString acilisSohbeti();               // uygulama bildirime dokunularak acildiysa
    Q_INVOKABLE bool piglerHazir() const { return m_pigOk; }
    Q_INVOKABLE QString piglerBilgi() const { return m_pigBilgi; }

signals:
    void ondeDegisti();
    void dokunuldu(const QString &sohbet);

protected:
    bool eventFilter(QObject *o, QEvent *e);

private slots:
    void piglerDokunma(qint32 id);
    void dokunulaniSil();

private:
    void piglerKur();
    void kaydet();
    void kayit(const QString &s);
    QString m_dosya, m_gunluk;
    bool m_onde;
    bool m_pigOk;
    QString m_pigBilgi;
    QMap<QString, int> m_kimlik;     // sohbet -> pigler kimligi
    QMap<QString, int> m_adet;       // sohbet -> okunmamis adedi
    int m_silinecek;
    QString m_acilis;
#ifdef Q_OS_SYMBIAN
    QPiglerAPI *m_pig;
#endif
};

#endif
