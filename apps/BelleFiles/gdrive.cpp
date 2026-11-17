#include "gdrive.h"
#include "dil.h"

#include <QtCore/QSettings>
#include <QtCore/QDir>
#include <QtCore/QDateTime>
#include <QtCore/QEventLoop>
#include <QtCore/QTimer>
#include <QtCore/QBuffer>
#include <QtCore/QUrl>
#include <QtCore/QStringList>
#include <QtGui/QDesktopServices>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkRequest>
#include <QtNetwork/QNetworkReply>
#include <QtNetwork/QTcpSocket>
#include <QtNetwork/QHostAddress>
#include <QtScript/QScriptEngine>
#include <QtScript/QScriptValue>

#include "gizli.h"
static const char *KVarsayilanId = "";
static const char *KYonlendirme = "http://127.0.0.1:8765/";
static const char *KApi = "https://www.googleapis.com/drive/v3/";
static const char *KFields = "nextPageToken,files(id,name,mimeType,size,modifiedTime,starred,parents,owners(displayName),shortcutDetails)";
static const char *KKlasor = "application/vnd.google-apps.folder";

// ---------------- JSON ----------------

QVariant jsonCoz(const QByteArray &b)
{
    static QScriptEngine *e = 0;
    if (!e) e = new QScriptEngine;
    QString s = QString::fromUtf8(b).trimmed();
    if (s.isEmpty()) return QVariant();
    const QScriptValue v = e->evaluate("(" + s + ")");
    if (e->hasUncaughtException()) { e->clearExceptions(); return QVariant(); }
    return v.toVariant();
}

static QByteArray jsonDizgi(const QString &s)
{
    QString o = "\"";
    for (int i = 0; i < s.length(); ++i) {
        const QChar c = s.at(i);
        if (c == '\\') o += "\\\\";
        else if (c == '"') o += "\\\"";
        else if (c == '\n') o += "\\n";
        else if (c == '\r') o += "\\r";
        else if (c == '\t') o += "\\t";
        else if (c.unicode() < 32) o += QString("\\u%1").arg(c.unicode(), 4, 16, QChar('0'));
        else o += c;
    }
    o += "\"";
    return o.toUtf8();
}

QByteArray jsonYaz(const QVariant &v)
{
    switch (v.type()) {
    case QVariant::Map: {
        QByteArray o = "{";
        const QVariantMap m = v.toMap();
        bool ilk = true;
        for (QVariantMap::const_iterator it = m.constBegin(); it != m.constEnd(); ++it) {
            if (!ilk) o += ",";
            ilk = false;
            o += jsonDizgi(it.key()) + ":" + jsonYaz(it.value());
        }
        return o + "}";
    }
    case QVariant::List: case QVariant::StringList: {
        QByteArray o = "[";
        const QVariantList l = v.toList();
        for (int i = 0; i < l.size(); ++i) { if (i) o += ","; o += jsonYaz(l.at(i)); }
        return o + "]";
    }
    case QVariant::Bool: return v.toBool() ? "true" : "false";
    case QVariant::Int: case QVariant::LongLong: case QVariant::UInt: case QVariant::ULongLong: return QByteArray::number(v.toLongLong());
    case QVariant::Double: return QByteArray::number(v.toDouble(), 'g', 15);
    case QVariant::Invalid: return "null";
    default: return jsonDizgi(v.toString());
    }
}

// ---------------- GAuth ----------------

GAuth *GAuth::ins()
{
    static GAuth *g = 0;
    if (!g) g = new GAuth;
    return g;
}

GAuth::GAuth(QObject *parent) : QObject(parent), m_nam(new QNetworkAccessManager(this)), m_bitis(0) {}

QString GAuth::ayarDosya() const
{
    const QString d = QDesktopServices::storageLocation(QDesktopServices::DataLocation);
    QDir().mkpath(d);
    return d + "/drive_google.ini";
}

QString GAuth::clientId() const { QSettings s(ayarDosya(), QSettings::IniFormat); return s.value("client_id", KVarsayilanId).toString(); }
QString GAuth::clientSecret() const
{
    QSettings s(ayarDosya(), QSettings::IniFormat);
    const QString v = s.value("client_secret").toString();
    if (!v.isEmpty()) return v;
    // girilmemisse ve varsayilan istemci kullaniliyorsa gomulu anahtar (gizli.h)
    return clientId() == QLatin1String(KVarsayilanId) ? QString::fromLatin1(BF_VARSAYILAN_SECRET) : QString();
}
QString GAuth::email() const { QSettings s(ayarDosya(), QSettings::IniFormat); return s.value("email").toString(); }
bool GAuth::bagli() const { QSettings s(ayarDosya(), QSettings::IniFormat); return !s.value("refresh").toString().isEmpty(); }

void GAuth::setClient(const QString &id, const QString &secret)
{
    QSettings s(ayarDosya(), QSettings::IniFormat);
    s.setValue("client_id", id.trimmed().isEmpty() ? QString(KVarsayilanId) : id.trimmed());
    s.setValue("client_secret", secret.trimmed());
}

void GAuth::cikis()
{
    QSettings s(ayarDosya(), QSettings::IniFormat);
    s.remove("refresh"); s.remove("email");
    m_access.clear(); m_bitis = 0;
}

QString GAuth::izinAdresi()
{
    // Qt 4.7'de SHA-256 yok: PKCE "plain" yontemi (Google destekler)
    const char *harf = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~";
    qsrand(uint(QDateTime::currentDateTime().toTime_t()) ^ uint(qrand()));
    m_verifier.clear();
    for (int i = 0; i < 64; ++i) m_verifier += QChar(harf[qrand() % 66]);
    QSettings s(ayarDosya(), QSettings::IniFormat);
    s.setValue("verifier", m_verifier);
    QUrl u("https://accounts.google.com/o/oauth2/v2/auth");
    u.addQueryItem("client_id", clientId());
    u.addQueryItem("redirect_uri", KYonlendirme);
    u.addQueryItem("response_type", "code");
    u.addQueryItem("scope", "https://www.googleapis.com/auth/drive");
    u.addQueryItem("access_type", "offline");
    u.addQueryItem("prompt", "consent");
    u.addQueryItem("code_challenge", m_verifier);
    u.addQueryItem("code_challenge_method", "plain");
    return QString::fromLatin1(u.toEncoded());
}

static QByteArray formKodla(const QList<QPair<QString, QString> > &l)
{
    QByteArray o;
    for (int i = 0; i < l.size(); ++i) {
        if (i) o += "&";
        o += QUrl::toPercentEncoding(l.at(i).first) + "=" + QUrl::toPercentEncoding(l.at(i).second);
    }
    return o;
}

QString GAuth::kodGir(const QString &yapistirilan)
{
    QString kod = yapistirilan.trimmed();
    const int i = kod.indexOf("code=");
    if (i >= 0) { kod = kod.mid(i + 5); const int j = kod.indexOf('&'); if (j >= 0) kod = kod.left(j); kod = QUrl::fromPercentEncoding(kod.toLatin1()); }
    if (kod.isEmpty()) return Dil::t("Kod bulunamadı");
    if (clientSecret().isEmpty()) return Dil::t("Önce Client secret girin");
    QSettings s(ayarDosya(), QSettings::IniFormat);
    if (m_verifier.isEmpty()) m_verifier = s.value("verifier").toString();
    QList<QPair<QString, QString> > f;
    f << qMakePair(QString("code"), kod) << qMakePair(QString("client_id"), clientId())
      << qMakePair(QString("client_secret"), clientSecret()) << qMakePair(QString("redirect_uri"), QString(KYonlendirme))
      << qMakePair(QString("grant_type"), QString("authorization_code")) << qMakePair(QString("code_verifier"), m_verifier);
    QByteArray c;
    const int st = istek("POST", "https://oauth2.googleapis.com/token", formKodla(f), "application/x-www-form-urlencoded", &c);
    const QVariantMap j = jsonCoz(c).toMap();
    if (st != 200 || j.value("refresh_token").toString().isEmpty())
        return Dil::t("Google reddetti: ") + (j.value("error_description").toString().isEmpty() ? j.value("error").toString() + " (" + QString::number(st) + ")" : j.value("error_description").toString());
    s.setValue("refresh", j.value("refresh_token").toString());
    m_access = j.value("access_token").toString();
    m_bitis = QDateTime::currentMSecsSinceEpoch() + qint64(j.value("expires_in").toInt()) * 1000;
    QByteArray a;
    if (istek("GET", QString(KApi) + "about?fields=user(emailAddress)", QByteArray(), QByteArray(), &a) == 200)
        s.setValue("email", jsonCoz(a).toMap().value("user").toMap().value("emailAddress").toString());
    return QString();
}

QString GAuth::erisimAnahtari(QString *hata)
{
    if (!m_access.isEmpty() && m_bitis > QDateTime::currentMSecsSinceEpoch() + 60000) return m_access;
    QSettings s(ayarDosya(), QSettings::IniFormat);
    const QString r = s.value("refresh").toString();
    if (r.isEmpty()) { if (hata) *hata = Dil::t("Google hesabı bağlı değil"); return QString(); }
    QList<QPair<QString, QString> > f;
    f << qMakePair(QString("client_id"), clientId()) << qMakePair(QString("client_secret"), clientSecret())
      << qMakePair(QString("refresh_token"), r) << qMakePair(QString("grant_type"), QString("refresh_token"));
    QByteArray c;
    const int st = istek("POST", "https://oauth2.googleapis.com/token", formKodla(f), "application/x-www-form-urlencoded", &c);
    const QVariantMap j = jsonCoz(c).toMap();
    if (st != 200 || j.value("access_token").toString().isEmpty()) {
        if (j.value("error").toString() == "invalid_grant") cikis();
        if (hata) *hata = Dil::t("Google anahtarı yenilenemedi: ") + j.value("error").toString() + " (" + QString::number(st) + ")";
        return QString();
    }
    m_access = j.value("access_token").toString();
    m_bitis = QDateTime::currentMSecsSinceEpoch() + qint64(j.value("expires_in").toInt()) * 1000;
    return m_access;
}

int GAuth::istek(const QByteArray &yontem, const QString &url, const QByteArray &govde, const QByteArray &tur, QByteArray *cevap, int zamanMs)
{
    QNetworkRequest req((QUrl::fromEncoded(url.toLatin1())));
    if (!url.startsWith("https://oauth2.googleapis.com/")) {
        QString hata;
        const QString a = erisimAnahtari(&hata);
        if (a.isEmpty()) { if (cevap) *cevap = jsonYaz(QVariantMap()); return 401; }
        req.setRawHeader("Authorization", "Bearer " + a.toLatin1());
    }
    if (!tur.isEmpty()) req.setHeader(QNetworkRequest::ContentTypeHeader, tur);
    QBuffer *buf = new QBuffer;
    buf->setData(govde);
    buf->open(QIODevice::ReadOnly);
    QNetworkReply *r = m_nam->sendCustomRequest(req, yontem, buf);
    buf->setParent(r);
    QEventLoop loop;
    QTimer::singleShot(zamanMs, &loop, SLOT(quit()));
    connect(r, SIGNAL(finished()), &loop, SLOT(quit()));
    loop.exec();
    const int st = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (cevap) *cevap = r->readAll();
    r->deleteLater();
    return st;
}

// ---------------- Yardimcilar ----------------

static QString boyutYazi(qint64 b)
{
    if (b <= 0) return QString();
    if (b >= 1073741824) return QString::number(b / 1073741824.0, 'f', 1) + " GB";
    if (b >= 1048576) return QString::number(b / 1048576.0, 'f', 1) + " MB";
    return QString::number(qMax<qint64>(1, (b + 512) / 1024)) + " KB";
}

static QString tarihYazi(const QString &iso)
{
    if (iso.isEmpty()) return QString();
    QDateTime t = QDateTime::fromString(iso.left(19), "yyyy-MM-ddTHH:mm:ss");
    t.setTimeSpec(Qt::UTC);
    t = t.toLocalTime();
    const QDateTime n = QDateTime::currentDateTime();
    if (t.date() == n.date()) return t.toString("HH:mm");
    return t.toString(t.date().year() == n.date().year() ? "dd.MM" : "dd.MM.yyyy");
}

struct Ihrac { const char *mime; const char *text; const char *file; const char *ext; const char *label; };
static const Ihrac KIhrac[] = {
    { "application/vnd.google-apps.document", "text/plain", "application/pdf", "pdf", "Doküman" },
    { "application/vnd.google-apps.spreadsheet", "text/csv", "application/pdf", "pdf", "E-Tablo" },
    { "application/vnd.google-apps.presentation", "text/plain", "application/pdf", "pdf", "Sunu" },
    { "application/vnd.google-apps.drawing", 0, "image/jpeg", "jpg", "Çizim" },
    { 0, 0, 0, 0, 0 }
};
static const Ihrac *ihracBul(const QString &m) { for (int i = 0; KIhrac[i].mime; ++i) if (m == KIhrac[i].mime) return &KIhrac[i]; return 0; }

static bool metinMi(const QString &m, const QString &ad)
{
    return m.startsWith("text/") || m.contains("json") || m.contains("xml") || m.contains("javascript")
        || QRegExp("\\.(txt|md|csv|log|ini|json)$", Qt::CaseInsensitive).indexIn(ad) >= 0;
}

// Sunucunun itemOf() islevinin birebir karsiligi
static QVariantMap ogeOf(const QVariantMap &f)
{
    QString id = f.value("id").toString(), mime = f.value("mimeType").toString();
    if (mime == "application/vnd.google-apps.shortcut" && f.contains("shortcutDetails")) {
        const QVariantMap sd = f.value("shortcutDetails").toMap();
        id = sd.value("targetId").toString(); mime = sd.value("targetMimeType").toString();
    }
    const QString ad = f.value("name").toString();
    const Ihrac *ex = ihracBul(mime);
    QString kind = "file";
    if (mime == KKlasor) kind = "folder";
    else if (mime.startsWith("image/")) kind = "image";
    else if (mime.startsWith("video/")) kind = "video";
    else if (mime.startsWith("audio/")) kind = "audio";
    else if (mime == "application/pdf") kind = "pdf";
    else if (QRegExp("spreadsheet|excel|csv").indexIn(mime) >= 0) kind = "sheet";
    else if (QRegExp("presentation|powerpoint").indexIn(mime) >= 0) kind = "slides";
    else if (QRegExp("document|msword|wordprocessing").indexIn(mime) >= 0) kind = "doc";
    else if (QRegExp("zip|rar|7z|compressed|tar").indexIn(mime) >= 0) kind = "archive";
    else if (metinMi(mime, ad)) kind = "text";
    QRegExp rx("\\.([A-Za-z0-9]{1,5})$");
    const QString ext = rx.indexIn(ad) >= 0 ? rx.cap(1) : (ex ? QString(ex->ext) : QString());
    const qint64 boyut = f.value("size").toString().toLongLong();
    QVariantMap o;
    o["id"] = id; o["name"] = ad; o["mime"] = mime; o["kind"] = kind; o["ext"] = ext.toUpper();
    o["size"] = double(boyut); o["sizeText"] = ex ? QString::fromUtf8(ex->label) : boyutYazi(boyut);
    o["modified"] = f.value("modifiedTime").toString(); o["date"] = tarihYazi(f.value("modifiedTime").toString());
    o["starred"] = f.value("starred").toBool();
    const QVariantList p = f.value("parents").toList();
    o["parent"] = p.isEmpty() ? QString() : p.first().toString();
    const QVariantList ow = f.value("owners").toList();
    o["owner"] = ow.isEmpty() ? QString() : ow.first().toMap().value("displayName").toString();
    o["google"] = ex != 0; o["dlExt"] = ex ? QString(ex->ext) : QString();
    o["canText"] = ex ? (ex->text != 0) : (metinMi(mime, ad) && boyut < 2000000);
    return o;
}

static QString qkac(const QString &s) { QString o = s; o.replace("\\", "\\\\"); o.replace("'", "\\'"); return o; }

static QString apiUrl(const QString &yol, const QList<QPair<QString, QString> > &p)
{
    QUrl u(QString(KApi) + yol);
    for (int i = 0; i < p.size(); ++i) u.addQueryItem(p.at(i).first, p.at(i).second);
    return QString::fromLatin1(u.toEncoded());
}

// ---------------- GKopru ----------------

GKopru::GKopru(QObject *parent) : QTcpServer(parent)
{
    listen(QHostAddress::LocalHost, 0);
}

QString GKopru::adres() const { return QString("http://127.0.0.1:%1").arg(serverPort()); }

void GKopru::incomingConnection(int handle)
{
    QTcpSocket *s = new QTcpSocket(this);
    s->setSocketDescriptor(handle);
    connect(s, SIGNAL(readyRead()), this, SLOT(onOku()));
    connect(s, SIGNAL(disconnected()), s, SLOT(deleteLater()));
}

void GKopru::onOku()
{
    QTcpSocket *s = qobject_cast<QTcpSocket *>(sender());
    if (!s || s->property("islendi").toBool()) return;
    QByteArray b = s->property("tampon").toByteArray() + s->readAll();
    const int son = b.indexOf("\r\n\r\n");
    if (son < 0) { s->setProperty("tampon", b); return; }
    s->setProperty("islendi", true);
    const QList<QByteArray> ilk = b.left(b.indexOf("\r\n")).split(' ');
    if (ilk.size() < 2) { s->close(); return; }
    const QUrl u = QUrl::fromEncoded(ilk.at(1));
    QVariantMap sorgu;
    QList<QPair<QString, QString> > q = u.queryItems();
    for (int i = 0; i < q.size(); ++i) sorgu[q.at(i).first] = q.at(i).second;
    isle(s, ilk.at(0), u.path(), sorgu);
}

void GKopru::yanit(QTcpSocket *s, int kod, const QByteArray &tur, const QByteArray &govde)
{
    QByteArray h = "HTTP/1.1 " + QByteArray::number(kod) + (kod == 200 ? " OK" : " Hata") + "\r\n";
    h += "Content-Type: " + tur + "\r\nContent-Length: " + QByteArray::number(govde.size()) + "\r\nConnection: close\r\n\r\n";
    s->write(h + govde);
    s->disconnectFromHost();
}

void GKopru::jsonHata(QTcpSocket *s, int kod, const QString &mesaj, bool kurulum)
{
    QVariantMap m;
    m["error"] = mesaj; m["needSetup"] = kurulum;
    yanit(s, kod, "application/json", jsonYaz(m));
}

static QString hataMetni(const QByteArray &c, int st)
{
    const QVariantMap j = jsonCoz(c).toMap();
    const QString m = j.value("error").toMap().value("message").toString();
    return m.isEmpty() ? QString("HTTP %1").arg(st) : m;
}

void GKopru::isle(QTcpSocket *s, const QByteArray &yontem, const QString &yol, const QVariantMap &sorgu)
{
    Q_UNUSED(yontem);
    GAuth *g = GAuth::ins();
    if (yol == "/drive/api/status") {
        QVariantMap m; m["configured"] = !g->clientSecret().isEmpty(); m["connected"] = g->bagli(); m["email"] = g->email();
        yanit(s, 200, "application/json", jsonYaz(m)); return;
    }
    if (!g->bagli()) { jsonHata(s, 409, Dil::t("Google hesabı bağlı değil. Drive menüsü → Bağlantı ayarları → Google hesabını bağla"), true); return; }
    QRegExp idRx("^[\\w-]{4,}$");
    QByteArray c;
    int st;
    typedef QPair<QString, QString> P;

    if (yol == "/drive/api/list") {
        const QString v = sorgu.value("v").toString();
        QString folder = sorgu.value("f").toString();
        if (idRx.indexIn(folder) < 0) folder = "root";
        const QString q = sorgu.value("q").toString().trimmed();
        QList<P> p;
        p << P("pageSize", "40") << P("fields", KFields) << P("supportsAllDrives", "true")
          << P("includeItemsFromAllDrives", "true") << P("orderBy", "modifiedTime desc");
        if (!sorgu.value("p").toString().isEmpty()) p << P("pageToken", sorgu.value("p").toString());
        QString baslik, ust;
        if (!q.isEmpty()) { p << P("q", "name contains '" + qkac(q) + "' and trashed=false"); baslik = QString::fromUtf8("“") + q + QString::fromUtf8("”"); }
        else if (v == "shared") { p << P("q", "sharedWithMe and trashed=false"); baslik = Dil::t("Paylaşılan"); }
        else if (v == "starred") { p << P("q", "starred and trashed=false"); baslik = Dil::t("Yıldızlı"); }
        else if (v == "my") {
            p << P("q", "'" + folder + "' in parents and trashed=false");
            if (folder == "root") baslik = Dil::t("Drive'ım");
            else {
                QList<P> fp; fp << P("fields", "name,parents") << P("supportsAllDrives", "true");
                if (g->istek("GET", apiUrl("files/" + folder, fp), QByteArray(), QByteArray(), &c) == 200) {
                    const QVariantMap fi = jsonCoz(c).toMap();
                    baslik = fi.value("name").toString();
                    const QVariantList pl = fi.value("parents").toList();
                    ust = pl.isEmpty() ? QString("root") : pl.first().toString();
                }
            }
        } else { p << P("q", "trashed=false"); baslik = Dil::t("Tümü"); }
        st = g->istek("GET", apiUrl("files", p), QByteArray(), QByteArray(), &c);
        if (st != 200) { jsonHata(s, st == 401 ? 409 : 502, hataMetni(c, st), st == 401); return; }
        const QVariantMap j = jsonCoz(c).toMap();
        QVariantList items;
        const QVariantList fl = j.value("files").toList();
        for (int i = 0; i < fl.size(); ++i) items << ogeOf(fl.at(i).toMap());
        QVariantMap o;
        o["title"] = baslik; o["folder"] = v == "my" ? folder : QString(); o["parent"] = ust;
        o["items"] = items; o["next"] = j.value("nextPageToken").toString();
        yanit(s, 200, "application/json", jsonYaz(o)); return;
    }
    if (yol.startsWith("/drive/api/file/")) {
        const QString id = yol.mid(16);
        QList<P> p; p << P("fields", "id,name,mimeType,size,modifiedTime,starred,parents,owners(displayName),shortcutDetails") << P("supportsAllDrives", "true");
        st = g->istek("GET", apiUrl("files/" + id, p), QByteArray(), QByteArray(), &c);
        if (st != 200) { jsonHata(s, 502, hataMetni(c, st)); return; }
        yanit(s, 200, "application/json", jsonYaz(ogeOf(jsonCoz(c).toMap()))); return;
    }
    if (yol.startsWith("/drive/api/text/")) {
        const QString id = yol.mid(16);
        QList<P> p; p << P("fields", "mimeType") << P("supportsAllDrives", "true");
        st = g->istek("GET", apiUrl("files/" + id, p), QByteArray(), QByteArray(), &c);
        const Ihrac *ex = st == 200 ? ihracBul(jsonCoz(c).toMap().value("mimeType").toString()) : 0;
        QList<P> p2;
        if (ex && ex->text) { p2 << P("mimeType", ex->text); st = g->istek("GET", apiUrl("files/" + id + "/export", p2), QByteArray(), QByteArray(), &c); }
        else { p2 << P("alt", "media") << P("supportsAllDrives", "true"); st = g->istek("GET", apiUrl("files/" + id, p2), QByteArray(), QByteArray(), &c, 120000); }
        if (st != 200) { yanit(s, 502, "text/plain; charset=utf-8", (Dil::t("Okunamadı: ") + hataMetni(c, st)).toUtf8()); return; }
        if (c.size() > 150000) c = c.left(150000) + Dil::t("\n\n… (devamı kesildi)").toUtf8();
        yanit(s, 200, "text/plain; charset=utf-8", c); return;
    }
    if (yol.startsWith("/drive/api/star/") || yol.startsWith("/drive/api/trash/")) {
        const bool yildiz = yol.startsWith("/drive/api/star/");
        const QString id = yol.mid(yildiz ? 16 : 17);
        QVariantMap b;
        if (yildiz) b["starred"] = sorgu.value("on").toString() == "1"; else b["trashed"] = true;
        QList<P> p; p << P("supportsAllDrives", "true");
        st = g->istek("PATCH", apiUrl("files/" + id, p), jsonYaz(b), "application/json", &c);
        if (st != 200) { jsonHata(s, 502, hataMetni(c, st)); return; }
        QVariantMap o; o["ok"] = true; if (yildiz) o["starred"] = b.value("starred");
        yanit(s, 200, "application/json", jsonYaz(o)); return;
    }
    if (yol == "/drive/api/mkdir" || yol == "/drive/api/folder" || yol == "/drive/api/exists") {
        QString ust = sorgu.value("f").toString();
        if (idRx.indexIn(ust) < 0) ust = "root";
        const QString ad = sorgu.value("name").toString().trimmed();
        if (ad.isEmpty()) { jsonHata(s, 400, Dil::t("Ad boş")); return; }
        if (yol != "/drive/api/mkdir") {
            QList<P> p;
            QString q = "name='" + qkac(ad) + "' and '" + ust + "' in parents and trashed=false";
            if (yol == "/drive/api/folder") q += QString(" and mimeType='") + KKlasor + "'";
            p << P("q", q) << P("fields", "files(id,name)") << P("pageSize", "1") << P("supportsAllDrives", "true") << P("includeItemsFromAllDrives", "true");
            st = g->istek("GET", apiUrl("files", p), QByteArray(), QByteArray(), &c);
            if (st != 200) { jsonHata(s, 502, hataMetni(c, st)); return; }
            const QVariantList fl = jsonCoz(c).toMap().value("files").toList();
            QVariantMap o;
            if (yol == "/drive/api/exists") { o["exists"] = !fl.isEmpty(); yanit(s, 200, "application/json", jsonYaz(o)); return; }
            if (!fl.isEmpty()) { o["id"] = fl.first().toMap().value("id"); o["name"] = ad; o["created"] = false; yanit(s, 200, "application/json", jsonYaz(o)); return; }
        }
        QVariantMap b; b["name"] = ad; b["mimeType"] = KKlasor; QVariantList pl; pl << ust; b["parents"] = pl;
        QList<P> p; p << P("supportsAllDrives", "true") << P("fields", "id,name,mimeType,modifiedTime,parents");
        st = g->istek("POST", apiUrl("files", p), jsonYaz(b), "application/json", &c);
        if (st != 200) { jsonHata(s, 502, hataMetni(c, st)); return; }
        const QVariantMap f = jsonCoz(c).toMap();
        if (yol == "/drive/api/folder") { QVariantMap o; o["id"] = f.value("id"); o["name"] = ad; o["created"] = true; yanit(s, 200, "application/json", jsonYaz(o)); }
        else yanit(s, 200, "application/json", jsonYaz(ogeOf(f)));
        return;
    }
    if (yol.startsWith("/drive/dl/")) { indir(s, yol.mid(10)); return; }
    if (yol.startsWith("/drive/img/")) { resim(s, yol.mid(11), qBound(100, sorgu.value("w").toInt(), 1600)); return; }
    if (yol == "/drive/api/recent") { yanit(s, 200, "application/json", "{\"items\":[]}"); return; }
    jsonHata(s, 404, Dil::t("Bu işlem doğrudan Google modunda yok: ") + yol);
}

void GKopru::indir(QTcpSocket *s, const QString &id)
{
    GAuth *g = GAuth::ins();
    typedef QPair<QString, QString> P;
    QByteArray c;
    QList<P> p; p << P("fields", "name,mimeType,size") << P("supportsAllDrives", "true");
    int st = g->istek("GET", apiUrl("files/" + id, p), QByteArray(), QByteArray(), &c);
    if (st != 200) { yanit(s, 502, "text/plain", hataMetni(c, st).toUtf8()); return; }
    const QVariantMap f = jsonCoz(c).toMap();
    const Ihrac *ex = ihracBul(f.value("mimeType").toString());
    QString ad = f.value("name").toString();
    QList<P> p2;
    QString url;
    if (ex) { p2 << P("mimeType", ex->file); url = apiUrl("files/" + id + "/export", p2); ad = ad.section('.', 0, -2).isEmpty() ? ad : ad.section('.', 0, -2); ad += QString(".") + ex->ext; }
    else { p2 << P("alt", "media") << P("supportsAllDrives", "true"); url = apiUrl("files/" + id, p2); }
    QString hata;
    const QString a = g->erisimAnahtari(&hata);
    if (a.isEmpty()) { yanit(s, 409, "text/plain", hata.toUtf8()); return; }
    QNetworkRequest req(QUrl::fromEncoded(url.toLatin1()));
    req.setRawHeader("Authorization", "Bearer " + a.toLatin1());
    QNetworkReply *r = g->nam()->get(req);
    GAktar ak(r, s, ad.toUtf8());
    connect(r, SIGNAL(metaDataChanged()), &ak, SLOT(baslik()));
    connect(r, SIGNAL(readyRead()), &ak, SLOT(veri()));
    QEventLoop loop;
    connect(r, SIGNAL(finished()), &loop, SLOT(quit()));
    connect(s, SIGNAL(disconnected()), &loop, SLOT(quit()));
    loop.exec();
    if (r->isRunning()) r->abort();
    ak.veri();
    if (!ak.baslikYazildi) { const int k = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt(); yanit(s, 502, "text/plain", QString("HTTP %1").arg(k).toUtf8()); }
    else s->disconnectFromHost();
    r->deleteLater();
}

void GKopru::resim(QTcpSocket *s, const QString &id, int w)
{
    GAuth *g = GAuth::ins();
    typedef QPair<QString, QString> P;
    QByteArray c;
    QList<P> p; p << P("fields", "thumbnailLink") << P("supportsAllDrives", "true");
    int st = g->istek("GET", apiUrl("files/" + id, p), QByteArray(), QByteArray(), &c);
    QString t = st == 200 ? jsonCoz(c).toMap().value("thumbnailLink").toString() : QString();
    if (t.isEmpty()) { yanit(s, 404, "text/plain", "yok"); return; }
    t.replace(QRegExp("=s\\d+$"), QString("=s%1").arg(w));
    st = g->istek("GET", t, QByteArray(), QByteArray(), &c);
    if (st != 200) { yanit(s, 502, "text/plain", "alinamadi"); return; }
    yanit(s, 200, "image/jpeg", c);
}

// ---------------- GAktar ----------------

GAktar::GAktar(QNetworkReply *r, QTcpSocket *s, const QByteArray &ad, QObject *parent)
    : QObject(parent), baslikYazildi(false), m_r(r), m_s(s), m_ad(ad) {}

void GAktar::baslik()
{
    if (baslikYazildi) return;
    const int k = m_r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (k != 200) return;
    baslikYazildi = true;
    QByteArray h = "HTTP/1.1 200 OK\r\n";
    const QByteArray tur = m_r->header(QNetworkRequest::ContentTypeHeader).toByteArray();
    h += "Content-Type: " + (tur.isEmpty() ? QByteArray("application/octet-stream") : tur) + "\r\n";
    const QVariant uz = m_r->header(QNetworkRequest::ContentLengthHeader);
    if (uz.isValid()) h += "Content-Length: " + QByteArray::number(uz.toLongLong()) + "\r\n";
    h += "Content-Disposition: attachment; filename*=UTF-8''" + QUrl::toPercentEncoding(QString::fromUtf8(m_ad)) + "\r\n";
    h += "Connection: close\r\n\r\n";
    m_s->write(h);
}

void GAktar::veri()
{
    if (!baslikYazildi) baslik();
    if (baslikYazildi && m_r->bytesAvailable() > 0) m_s->write(m_r->readAll());
}

QVariantMap gdriveOge(const QVariantMap &f) { return ogeOf(f); }

