#ifndef RELAYCONN_H
#define RELAYCONN_H

#include <QtCore/QObject>
#include <QtCore/QByteArray>
#include <QtCore/QString>
#include <QtCore/QFile>
#include <QtCore/QPointer>
#include <QtCore/QUrl>
#include <QtNetwork/QTcpSocket>
#include <QtNetwork/QNetworkReply>

class Music;

// Yerel aktaricinin tek baglantisi. Oynaticinin "GET /s/N.mp3" (Range) istegini okur:
//  - kaynak telefondaki dosyaysa dosyadan gonderir
//  - kaynak uzak adresse istegi iletir, 30x yonlendirmelerini izler, gelen veriyi aninda gecirir
class RelayConn : public QObject
{
    Q_OBJECT
public:
    RelayConn(QTcpSocket *sock, Music *music);

private slots:
    void onReadyRead();
    void onDisconnected();
    void upMeta();
    void upPump();
    void upFinished();
    void filePump();

private:
    void fail(const char *status);
    void startRemote(const QUrl &url);
    void startFile(const QString &path);
    bool sendUpHeader();

    Music *m_music;
    QPointer<QTcpSocket> m_sock;
    QPointer<QNetworkReply> m_up;
    QFile m_file;
    QByteArray m_head;
    bool m_headerDone, m_isHead, m_hasRange, m_upHeaderSent, m_upDone, m_closing;
    qint64 m_rangeStart, m_rangeEnd, m_pos, m_end;
    int m_redirects;
};

#endif
