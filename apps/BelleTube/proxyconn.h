#ifndef PROXYCONN_H
#define PROXYCONN_H

#include <QtCore/QObject>
#include <QtCore/QByteArray>
#include <QtCore/QString>
#include <QtCore/QTimer>
#include <QtCore/QPointer>
#include <QtNetwork/QTcpSocket>
#include <QtNetwork/QNetworkReply>

class Tube;

// Yerel sunucunun tek bir baglantisi: oynaticinin HTTP (Range) istegini okur.
//  - "/<id>_<tur>": telefondaki (inmis) dosyadan gonderir
//  - "/r/<id>_<tur>": aktarma; istegi (Range dahil) uzak sunucuya iletir, gelen veriyi aninda
//    oynaticiya gecirir. E6'nin oynaticisi uzak adreste goruntu vermiyor, 127.0.0.1'de veriyor.
class ProxyConn : public QObject
{
    Q_OBJECT
public:
    ProxyConn(QTcpSocket *sock, Tube *tube);

private slots:
    void onReadyRead();
    void pump();
    void onWaitTick();
    void onDisconnected();
    void relayPump();
    void relayFinished();

private:
    void startResponse();
    void startRelay(bool head);
    bool relayHeader();
    void fail(const char *status);

    QPointer<QNetworkReply> m_up;   // aktarma: uzak sunucu yaniti
    bool m_relay, m_upHeaderSent, m_upDone, m_isHead;

    QPointer<QTcpSocket> m_sock;   // soket silinince otomatik bosalir
    Tube *m_tube;
    QByteArray m_head;
    QString m_key;
    qint64 m_pos, m_end;
    qint64 m_rangeStart, m_rangeEnd;
    bool m_hasRange, m_headerDone, m_streaming, m_closing;
    int m_waitTicks;
    QTimer m_wait;
};

#endif
