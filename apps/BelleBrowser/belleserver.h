#ifndef BELLESERVER_H
#define BELLESERVER_H

// Belle uygulamalarinin (BelleMail, Belle Files, Belle Browser) ortak sunucu adresi. Adres telefonda herkesin okuyabildigi
// C:/Data/E6/sunucu.ini dosyasinda durur: bir uygulamada degistirilince digeri de yeni adresi kullanir.
// Dosya yoksa varsayilan adres gecerlidir. (Bu dosya Mail ve Drive projelerinde ayni kopyadir.)

#include <QtCore/QString>
#include <QtCore/QSettings>
#include <QtCore/QDir>
#include <QtCore/QFileInfo>
#include "belleadres.h"

inline QString belleDefaultServer() { return belleVarsayilanSunucu(); }

inline QString belleServerFile()
{
#if defined(Q_OS_SYMBIAN)
    return QString("C:/Data/E6/sunucu.ini");
#else
    return QDir::homePath() + "/E6/sunucu.ini";
#endif
}

// "1.2.3.4" -> "http://1.2.3.4", sondaki "/" atilir
inline QString belleNormalizeServer(const QString &in) { return belleSunucuTasi(in); }   // eski IP -> yeni adres

// Her istekte dosya okunmasin: uygulama boyunca tek kopya (inline + static yerel degisken)
inline QString &belleServerCache() { static QString c; return c; }

inline QString belleServer()
{
    QString &c = belleServerCache();
    if (c.isEmpty()) {
        QSettings s(belleServerFile(), QSettings::IniFormat);
        const QString v = belleNormalizeServer(s.value("server").toString());
        c = v.isEmpty() ? belleDefaultServer() : v;
    }
    return c;
}

inline void belleSetServer(const QString &server)
{
    QDir().mkpath(QFileInfo(belleServerFile()).absolutePath());
    QSettings s(belleServerFile(), QSettings::IniFormat);
    s.setValue("server", belleNormalizeServer(server));
    s.sync();
    belleServerCache() = belleNormalizeServer(server);
}

#endif
