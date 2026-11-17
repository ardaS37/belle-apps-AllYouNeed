#ifndef SERVECONN_H
#define SERVECONN_H

#include <QtCore/QObject>
#include <QtCore/QFile>
#include <QtCore/QPointer>
#include <QtCore/QUrl>

class QTcpSocket;
class QNetworkReply;
class Lib;

// Yerel sunucuya gelen tek bir oynatici baglantisi.
//  GET /f/<n>.<uzanti>  -> telefondaki dosya (Range destekli, sarma icin)
//  GET /r/<n>.<uzanti>  -> uzak adresten aktarma (yonlendirmeler izlenir, Range iletilir)
class ServeConn : public QObject
{
    Q_OBJECT
public:
    ServeConn(QTcpSocket *sock, Lib *lib);

private slots:
    void onReadyRead();
    void onDisconnected();
    void pumpFile();
    void relayMeta();
    void relayPump();
    void relayFinished();

private:
    void fail(const char *status);
    void startFile(const QString &path, bool head);
    void startRelay(const QUrl &url, bool head);

    QPointer<QTcpSocket> m_sock;
    Lib *m_lib;
    QByteArray m_head;
    bool m_headerDone;
    bool m_closing;
    bool m_hasRange;
    qint64 m_rangeStart, m_rangeEnd;

    // dosya
    QFile m_file;
    qint64 m_pos, m_end;
    bool m_streaming;

    // aktarma
    QPointer<QNetworkReply> m_up;
    bool m_isHead;
    bool m_upHeaderSent;
    bool m_upDone;
    int m_redirects;
};

#endif
