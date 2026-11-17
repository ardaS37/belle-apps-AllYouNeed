#include "drive.h"
#include "dil.h"
#include "belleserver.h"
#include "gdrive.h"

#include <QtCore/QDir>
#include <QtCore/QFileInfo>
#include <QtCore/QSettings>
#include <QtCore/QUrl>
#include <QtCore/QTimer>
#include <QtCore/QEventLoop>
#include <QtCore/QDateTime>
#include <QtCore/QDirIterator>
#include <QtCore/QCryptographicHash>
#include <QtGui/QApplication>
#include <QtGui/QClipboard>
#include <QtGui/QFileDialog>
#include <QtGui/QDesktopServices>
#include <QtGui/QInputDialog>
#include <QtGui/QLineEdit>
#include <QtGui/QMessageBox>

// Ayarlar: QSettings("BelleFiles", "Drive"): mod, key
static QSettings &ayar() { static QSettings s("BelleFiles", "Drive"); return s; }

static GKopru *kopru()
{
    static GKopru *k = 0;
    if (!k) k = new GKopru(qApp);
    return k;
}

QString driveMod() { return ayar().value("mod", "sunucu").toString(); }
QString driveServer() { return driveMod() == "google" ? kopru()->adres() : belleServer(); }
QString driveKey() { return ayar().value("key").toString(); }

// 1: dogru, 0: parola hatali, -1: sunucuya ulasilamadi
static int driveCheck(const QString &server, const QString &key)
{
    QNetworkAccessManager nam;
    QNetworkRequest req(QUrl(server + "/drive/api/status"));
    req.setRawHeader("X-Api-Key", key.toUtf8()); req.setRawHeader("X-Lang", Dil::kodu());
    QNetworkReply *r = nam.get(req);
    QEventLoop loop;
    QTimer::singleShot(20000, &loop, SLOT(quit()));
    QObject::connect(r, SIGNAL(finished()), &loop, SLOT(quit()));
    loop.exec();
    const int status = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    r->deleteLater();
    if (status == 401 || status == 403) return 0;
    if (status == 0) return -1;
    return 1;
}

QNetworkReply *KeyedNam::createRequest(Operation op, const QNetworkRequest &req, QIODevice *data)
{
    if (driveMod() == "sunucu" && req.url().toString().startsWith(driveServer())) {
        QNetworkRequest r(req);
        r.setRawHeader("X-Api-Key", driveKey().toUtf8()); r.setRawHeader("X-Lang", Dil::kodu());
        return QNetworkAccessManager::createRequest(op, r, data);
    }
    return QNetworkAccessManager::createRequest(op, req, data);
}

static QString mimeFor(const QString &path)
{
    const QString e = QFileInfo(path).suffix().toLower();
    if (e == "jpg" || e == "jpeg") return "image/jpeg";
    if (e == "png") return "image/png";
    if (e == "gif") return "image/gif";
    if (e == "bmp") return "image/bmp";
    if (e == "mp4" || e == "m4v") return "video/mp4";
    if (e == "3gp") return "video/3gpp";
    if (e == "avi") return "video/x-msvideo";
    if (e == "mp3") return "audio/mpeg";
    if (e == "m4a" || e == "aac") return "audio/mp4";
    if (e == "amr") return "audio/amr";
    if (e == "wav") return "audio/wav";
    if (e == "txt" || e == "log" || e == "md" || e == "ini") return "text/plain";
    if (e == "html" || e == "htm") return "text/html";
    if (e == "csv") return "text/csv";
    if (e == "pdf") return "application/pdf";
    if (e == "zip") return "application/zip";
    if (e == "vcf") return "text/vcard";
    if (e == "sis" || e == "sisx") return "application/vnd.symbian.install";
    if (e == "jar") return "application/java-archive";
    return "application/octet-stream";
}

Drive::Drive(QObject *parent)
    : QObject(parent), m_file(0), m_uploading(false), m_canceled(false), m_gYeni(false),
      m_isIndir(false), m_isAktif(false), m_isIptal(false), m_isToplam(0), m_isYuklenen(0), m_isAtlanan(0), m_isHata(0) {}

bool Drive::hazir() const
{
    return driveMod() == "google" ? GAuth::ins()->bagli() : !driveKey().isEmpty();
}

QString Drive::downloadDir() const
{
    const QString secilen = ayar().value("indirme").toString();
    if (!secilen.isEmpty() && QDir().mkpath(secilen)) return secilen;
#if defined(Q_OS_SYMBIAN)
    const QString d = QDir("E:/").exists() ? QString("E:/Drive") : QString("C:/Data/Drive");
#else
    const QString d = QDir::homePath() + "/BelleFiles/Drive";
#endif
    QDir().mkpath(d);
    return d;
}

QString Drive::pickFile()
{
#if defined(Q_OS_SYMBIAN)
    const QString start = QDir("E:/").exists() ? QString("E:/") : QString("C:/Data/");
#else
    const QString start = QDir::homePath();
#endif
    return QFileDialog::getOpenFileName(0, Dil::t("Yüklenecek dosya"), start);
}

QString Drive::localPath(const QString &name) const
{
    QString n = name;
    n.replace(QRegExp("[\\\\/:*?\"<>|]"), "_");
    if (n.trimmed().isEmpty()) n = "dosya";
    return downloadDir() + "/" + n;
}

bool Drive::upload(const QString &path, const QString &folder) { return uploadIc(path, folder, QString(), false); }
bool Drive::uploadYedek(const QString &path, const QString &klasorAdi) { return uploadIc(path, QString("root"), klasorAdi, true); }

bool Drive::uploadIc(const QString &path, const QString &folder, const QString &klasorAdi, bool replace)
{
    if (busy()) return false;
    if (driveMod() == "google") return uploadGoogle(path, folder, klasorAdi, replace);
    QFile *f = new QFile(path, this);
    if (!f->open(QIODevice::ReadOnly)) { delete f; return false; }
    QUrl url(driveServer() + "/drive/api/upload");
    url.addQueryItem("f", folder.isEmpty() ? QString("root") : folder);
    url.addQueryItem("name", QFileInfo(path).fileName());
    if (!klasorAdi.isEmpty()) url.addQueryItem("folderName", klasorAdi);
    if (replace) url.addQueryItem("replace", "1");
    QNetworkRequest req(url);
    req.setRawHeader("X-Api-Key", driveKey().toUtf8()); req.setRawHeader("X-Lang", Dil::kodu());
    req.setHeader(QNetworkRequest::ContentTypeHeader, mimeFor(path));
    req.setHeader(QNetworkRequest::ContentLengthHeader, f->size());
    m_file = f;
    m_uploading = true;
    m_canceled = false;
    m_gYeni = false;
    m_path = path;
    m_reply = m_nam.post(req, f);
    connect(m_reply, SIGNAL(uploadProgress(qint64, qint64)), this, SLOT(onUploadProgress(qint64, qint64)));
    connect(m_reply, SIGNAL(finished()), this, SLOT(onFinished()));
    emit busyChanged();
    return true;
}

static QString qk(const QString &s) { QString o = s; o.replace("\\", "\\\\"); o.replace("'", "\\'"); return o; }

static QString driveUrl(const QString &yol, const QList<QPair<QString, QString> > &p)
{
    QUrl u(yol.startsWith("http") ? yol : "https://www.googleapis.com/drive/v3/" + yol);
    for (int i = 0; i < p.size(); ++i) u.addQueryItem(p.at(i).first, p.at(i).second);
    return QString::fromLatin1(u.toEncoded());
}

bool Drive::uploadGoogle(const QString &path, const QString &folder, const QString &klasorAdi, bool replace)
{
    GAuth *g = GAuth::ins();
    typedef QPair<QString, QString> P;
    QString hata;
    const QString a = g->erisimAnahtari(&hata);
    if (a.isEmpty()) { yukSonuc(false, hata, QString()); return true; }
    QString hedef = folder.isEmpty() ? QString("root") : folder;
    QByteArray c;
    if (!klasorAdi.isEmpty()) {
        QList<P> p;
        p << P("q", "name='" + qk(klasorAdi) + "' and mimeType='application/vnd.google-apps.folder' and 'root' in parents and trashed=false")
          << P("fields", "files(id)") << P("pageSize", "1");
        if (g->istek("GET", driveUrl("files", p), QByteArray(), QByteArray(), &c) != 200) { yukSonuc(false, Dil::t("Drive'a ulaşılamadı"), QString()); return true; }
        const QVariantList fl = jsonCoz(c).toMap().value("files").toList();
        if (!fl.isEmpty()) hedef = fl.first().toMap().value("id").toString();
        else {
            QVariantMap b; b["name"] = klasorAdi; b["mimeType"] = "application/vnd.google-apps.folder"; QVariantList pl; pl << QString("root"); b["parents"] = pl;
            QList<P> p2; p2 << P("fields", "id");
            if (g->istek("POST", driveUrl("files", p2), jsonYaz(b), "application/json", &c) != 200) { yukSonuc(false, Dil::t("Klasör oluşturulamadı"), QString()); return true; }
            hedef = jsonCoz(c).toMap().value("id").toString();
        }
    }
    const QString ad = QFileInfo(path).fileName();
    QString varOlan;
    if (replace) {
        QList<P> p;
        p << P("q", "name='" + qk(ad) + "' and '" + hedef + "' in parents and trashed=false") << P("fields", "files(id)") << P("pageSize", "1");
        if (g->istek("GET", driveUrl("files", p), QByteArray(), QByteArray(), &c) == 200) {
            const QVariantList fl = jsonCoz(c).toMap().value("files").toList();
            if (!fl.isEmpty()) varOlan = fl.first().toMap().value("id").toString();
        }
    }
    QFile *f = new QFile(path, this);
    if (!f->open(QIODevice::ReadOnly)) { delete f; return false; }
    const QString fields = "id,name,mimeType,size,modifiedTime,starred,parents";
    QList<P> up; up << P("uploadType", "media") << P("supportsAllDrives", "true") << P("fields", fields);
    QNetworkRequest req(QUrl::fromEncoded(driveUrl(varOlan.isEmpty() ? QString("https://www.googleapis.com/upload/drive/v3/files")
                                                                      : "https://www.googleapis.com/upload/drive/v3/files/" + varOlan, up).toLatin1()));
    req.setRawHeader("Authorization", "Bearer " + g->erisimAnahtari().toLatin1());
    req.setHeader(QNetworkRequest::ContentTypeHeader, mimeFor(path));
    req.setHeader(QNetworkRequest::ContentLengthHeader, f->size());
    m_file = f;
    m_uploading = true;
    m_canceled = false;
    m_path = path;
    m_gYeni = varOlan.isEmpty();
    m_gKlasor = hedef;
    m_reply = varOlan.isEmpty() ? g->nam()->post(req, f) : g->nam()->sendCustomRequest(req, "PATCH", f);
    connect(m_reply, SIGNAL(uploadProgress(qint64, qint64)), this, SLOT(onUploadProgress(qint64, qint64)));
    connect(m_reply, SIGNAL(finished()), this, SLOT(onFinished()));
    emit busyChanged();
    return true;
}

// ================= Klasor yedekleme / esitleme =================

QString Drive::klasorBulYap(const QString &ust, const QString &ad, QString *hata)
{
    QByteArray c;
    if (driveMod() == "google") {
        GAuth *g = GAuth::ins();
        typedef QPair<QString, QString> P;
        QList<P> p;
        p << P("q", "name='" + qk(ad) + "' and mimeType='application/vnd.google-apps.folder' and '" + ust + "' in parents and trashed=false")
          << P("fields", "files(id)") << P("pageSize", "1");
        const int s = g->istek("GET", driveUrl("files", p), QByteArray(), QByteArray(), &c);
        if (s != 200) { *hata = s == 401 || s == 403 ? Dil::t("Google izni reddedildi") : Dil::t("Drive'a ulaşılamadı"); return QString(); }
        const QVariantList fl = jsonCoz(c).toMap().value("files").toList();
        if (!fl.isEmpty()) return fl.first().toMap().value("id").toString();
        QVariantMap b; b["name"] = ad; b["mimeType"] = "application/vnd.google-apps.folder"; QVariantList pl; pl << ust; b["parents"] = pl;
        QList<P> p2; p2 << P("fields", "id");
        if (g->istek("POST", driveUrl("files", p2), jsonYaz(b), "application/json", &c) != 200) { *hata = Dil::t("Klasör oluşturulamadı: ") + ad; return QString(); }
        return jsonCoz(c).toMap().value("id").toString();
    }
    QUrl url(belleServer() + "/drive/api/folder");
    url.addQueryItem("f", ust);
    url.addQueryItem("name", ad);
    QNetworkRequest req(url);
    req.setRawHeader("X-Api-Key", driveKey().toUtf8()); req.setRawHeader("X-Lang", Dil::kodu());
    req.setHeader(QNetworkRequest::ContentTypeHeader, "text/plain");
    QNetworkReply *r = m_nam.post(req, QByteArray());
    QEventLoop loop;
    QTimer::singleShot(30000, &loop, SLOT(quit()));
    connect(r, SIGNAL(finished()), &loop, SLOT(quit()));
    loop.exec();
    const int s = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    c = r->readAll();
    r->deleteLater();
    if (s != 200) {
        *hata = s == 401 || s == 403 ? Dil::t("Sunucu parolası hatalı") : (s == 0 ? Dil::t("Sunucuya ulaşılamadı") : jsonCoz(c).toMap().value("error").toString());
        if (hata->isEmpty()) *hata = "HTTP " + QString::number(s);
        return QString();
    }
    return jsonCoz(c).toMap().value("id").toString();
}

QString Drive::yolKlasoru(const QString &yol, QString *hata)
{
    if (yol.isEmpty()) return "root";
    if (m_isKlasor.contains(yol)) return m_isKlasor.value(yol);
    const int i = yol.lastIndexOf('/');
    const QString ust = i < 0 ? QString("root") : yolKlasoru(yol.left(i), hata);
    if (ust.isEmpty()) return QString();
    const QString id = klasorBulYap(ust, i < 0 ? yol : yol.mid(i + 1), hata);
    if (!id.isEmpty()) m_isKlasor.insert(yol, id);
    return id;
}

void Drive::isTopla(const QString &dirIn, const QString &hedefYol, bool degisenler)
{
    const QString dir = QDir(dirIn).absolutePath();
    QDirIterator it(dir, QDir::Files | QDir::Hidden | QDir::System, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        const QString yol = it.next();
        const QFileInfo fi(yol);
        if (fi.fileName().endsWith(".e6tmp") || fi.fileName().endsWith(".part")) continue;
        QString rel = QDir(dir).relativeFilePath(fi.absolutePath());
        if (rel == ".") rel.clear();
        IsDosya d;
        d.yol = yol;
        d.klasorYolu = rel.isEmpty() ? hedefYol : hedefYol + "/" + rel;
        d.anahtar = QString::fromLatin1(QCryptographicHash::hash((hedefYol + "|" + yol.toLower()).toUtf8(), QCryptographicHash::Md5).toHex());
        d.iz = QString::number(fi.size()) + ":" + QString::number(fi.lastModified().toTime_t());
        if (degisenler && ayar().value("yuklenen/" + d.anahtar).toString() == d.iz) { ++m_isAtlanan; continue; }
        m_isListe << d;
    }
}

bool Drive::klasorYedekle(const QString &dir, const QString &hedefYol, bool degisenler)
{
    return cokluIc(QStringList() << dir, hedefYol, degisenler, true);
}

bool Drive::cokluYedekle(const QStringList &yollar, const QString &hedefYol, bool degisenler)
{
    return cokluIc(yollar, hedefYol, degisenler, false);
}

bool Drive::cokluIc(const QStringList &yollar, const QString &hedefYol, bool degisenler, bool icerik)
{
    if (busy() || m_isAktif) return false;
    m_isListe.clear();
    m_isKlasor.clear();
    m_isYuklenen = m_isAtlanan = m_isHata = 0;
    m_isSonHata.clear();
    m_isIptal = false;
    QString hedef = hedefYol;
    while (hedef.endsWith('/')) hedef.chop(1);
    foreach (const QString &y, yollar) {
        const QFileInfo fi(y);
        if (fi.isDir()) {
            // icerik: klasorun ici dogrudan hedefe (not esitleme); aksi halde klasor kendi adiyla hedefin altina
            isTopla(y, icerik && !hedef.isEmpty() ? hedef : (hedef.isEmpty() ? fi.fileName() : hedef + "/" + fi.fileName()), degisenler);
        } else if (fi.isFile()) {
            IsDosya d;
            d.yol = fi.absoluteFilePath();
            d.klasorYolu = hedef;
            d.anahtar = QString::fromLatin1(QCryptographicHash::hash((hedef + "|" + d.yol.toLower()).toUtf8(), QCryptographicHash::Md5).toHex());
            d.iz = QString::number(fi.size()) + ":" + QString::number(fi.lastModified().toTime_t());
            if (degisenler && ayar().value("yuklenen/" + d.anahtar).toString() == d.iz) ++m_isAtlanan;
            else m_isListe << d;
        }
    }
    m_isToplam = m_isListe.size();
    m_isIndir = false;
    m_isAktif = true;
    emit isDurum();
    QTimer::singleShot(0, this, SLOT(isSonraki()));
    return true;
}

// ================= Klasor indirme (Drive -> telefon) =================

// Bir Drive klasorunun tum ogeleri (sayfa sayfa). Sunucu modunda da Google modunda da ayni /drive/api/list.
QVariantList Drive::listeTum(const QString &klasorId, QString *hata)
{
    QVariantList hepsi;
    QString sayfa;
    for (int guard = 0; guard < 100; ++guard) {
        QUrl url(driveServer() + "/drive/api/list");
        url.addQueryItem("v", "my");
        url.addQueryItem("f", klasorId);
        if (!sayfa.isEmpty()) url.addQueryItem("p", sayfa);
        QNetworkRequest req(url);
        if (driveMod() == "sunucu") req.setRawHeader("X-Api-Key", driveKey().toUtf8()); req.setRawHeader("X-Lang", Dil::kodu());
        QNetworkReply *r = m_nam.get(req);
        QEventLoop loop;
        QTimer::singleShot(60000, &loop, SLOT(quit()));
        connect(r, SIGNAL(finished()), &loop, SLOT(quit()));
        loop.exec();
        const int s = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray c = r->readAll();
        r->deleteLater();
        if (s != 200) {
            *hata = s == 401 || s == 403 ? Dil::t("Sunucu parolası hatalı")
                  : (s == 0 ? Dil::t("Drive'a ulaşılamadı") : jsonCoz(c).toMap().value("error").toString());
            if (hata->isEmpty()) *hata = "HTTP " + QString::number(s);
            return QVariantList();
        }
        const QVariantMap j = jsonCoz(c).toMap();
        hepsi += j.value("items").toList();
        sayfa = j.value("next").toString();
        if (sayfa.isEmpty() || m_isIptal) break;
    }
    return hepsi;
}

bool Drive::indirTopla(const QString &klasorId, const QString &yerel, int derinlik, QString *hata)
{
    if (derinlik > 12) return true;
    const QVariantList l = listeTum(klasorId, hata);
    if (!hata->isEmpty()) return false;
    foreach (const QVariant &v, l) {
        const QVariantMap it = v.toMap();
        QString ad = it.value("name").toString();
        ad.replace(QRegExp("[\\\\/:*?\"<>|]"), "_");
        if (ad.trimmed().isEmpty()) continue;
        if (it.value("kind").toString() == "folder") {
            if (!indirTopla(it.value("id").toString(), yerel + "/" + ad, derinlik + 1, hata)) return false;
        } else if (!it.value("google").toBool()) {       // Google belgeleri (Docs/Sheets) yedek degildir, atla
            IsDosya d;
            d.yol = yerel + "/" + ad;
            d.klasorYolu = it.value("id").toString();     // indirmede: Drive dosya kimligi
            m_isListe << d;
        }
    }
    return true;
}

bool Drive::klasorIndir(const QString &driveYol, const QString &yerel)
{
    if (busy() || m_isAktif || driveYol.isEmpty() || yerel.isEmpty()) return false;
    m_isListe.clear();
    m_isKlasor.clear();
    m_isYuklenen = m_isAtlanan = m_isHata = m_isToplam = 0;
    m_isSonHata.clear();
    m_isIptal = false;
    m_isIndir = true;
    m_indirKok = driveYol;
    m_indirYerel = yerel;
    m_tekAd.clear();
    m_isAktif = true;
    emit isDurum();
    emit isIlerleme(0, 0, Dil::t("Drive klasörü taranıyor…"));
    QTimer::singleShot(0, this, SLOT(indirHazirla()));
    return true;
}

bool Drive::dosyaIndir(const QString &driveYol, const QString &yerelDosya)
{
    QString y = driveYol;
    while (y.endsWith('/')) y.chop(1);
    const int i = y.lastIndexOf('/');
    if (i <= 0) return false;                      // dosya bir klasorde olmali ("Klasor/ad.zip")
    if (!klasorIndir(y.left(i), yerelDosya)) return false;
    m_tekAd = y.mid(i + 1);                        // indirHazirla bir sonraki dongude calisir
    return true;
}

void Drive::indirHazirla()
{
    if (!m_isAktif) return;
    QString hata, id = "root";
    foreach (const QString &parca, m_indirKok.split('/', QString::SkipEmptyParts)) {
        const QVariantList l = listeTum(id, &hata);
        if (!hata.isEmpty()) { isSonu(false, hata); return; }
        QString bulunan;
        foreach (const QVariant &v, l) {
            const QVariantMap it = v.toMap();
            if (it.value("kind").toString() == "folder" && it.value("name").toString().compare(parca, Qt::CaseInsensitive) == 0) { bulunan = it.value("id").toString(); break; }
        }
        if (bulunan.isEmpty()) { isSonu(false, Dil::t("Drive'da bulunamadı: ") + m_indirKok); return; }
        id = bulunan;
    }
    if (!m_tekAd.isEmpty()) {
        // tek dosya: klasorde adiyla bul, yerel tam yola indir
        const QVariantList l = listeTum(id, &hata);
        if (!hata.isEmpty()) { isSonu(false, hata); return; }
        foreach (const QVariant &v, l) {
            const QVariantMap it = v.toMap();
            if (it.value("kind").toString() != "folder" && it.value("name").toString().compare(m_tekAd, Qt::CaseInsensitive) == 0) {
                IsDosya d; d.yol = m_indirYerel; d.klasorYolu = it.value("id").toString();
                m_isListe << d;
                break;
            }
        }
        if (m_isListe.isEmpty()) { isSonu(false, Dil::t("Drive'da bulunamadı: ") + m_indirKok + "/" + m_tekAd); return; }
    } else if (!indirTopla(id, m_indirYerel, 0, &hata)) { isSonu(false, hata); return; }
    if (m_isListe.isEmpty()) { isSonu(false, Dil::t("Drive klasörü boş: ") + m_indirKok); return; }
    m_isToplam = m_isListe.size();
    QTimer::singleShot(0, this, SLOT(isSonraki()));
}

bool Drive::indirIc(const QString &id, const QString &hedef)
{
    QDir().mkpath(QFileInfo(hedef).absolutePath());
    m_path = hedef;
    QFile *f = new QFile(hedef + ".part", this);
    if (!f->open(QIODevice::WriteOnly | QIODevice::Truncate)) { delete f; return false; }
    QNetworkRequest req(QUrl(driveServer() + "/drive/dl/" + id));
    if (driveMod() == "sunucu") req.setRawHeader("X-Api-Key", driveKey().toUtf8()); req.setRawHeader("X-Lang", Dil::kodu());
    m_file = f;
    m_uploading = false;
    m_canceled = false;
    m_reply = m_nam.get(req);
    connect(m_reply, SIGNAL(downloadProgress(qint64, qint64)), this, SLOT(onDownloadProgress(qint64, qint64)));
    connect(m_reply, SIGNAL(readyRead()), this, SLOT(onReadyRead()));
    connect(m_reply, SIGNAL(finished()), this, SLOT(onFinished()));
    emit busyChanged();
    return true;
}

void Drive::setDownloadDir(const QString &dir)
{
    if (dir.isEmpty()) ayar().remove("indirme"); else ayar().setValue("indirme", dir);
    ayar().sync();
    emit serverChanged();
}

void Drive::isIptal()
{
    if (!m_isAktif) return;
    m_isIptal = true;
    cancel();
}

void Drive::isSonraki()
{
    if (!m_isAktif) return;
    if (m_isIptal) { isSonu(false, QString::fromUtf8("Durduruldu")); return; }
    if (m_isListe.isEmpty()) { isSonu(m_isHata == 0, QString()); return; }
    const IsDosya d = m_isListe.takeFirst();
    emit isIlerleme(m_isToplam - m_isListe.size() - 1, m_isToplam, QFileInfo(d.yol).fileName());
    if (m_isIndir) {
        if (!indirIc(d.klasorYolu, d.yol)) {
            ++m_isHata;
            m_isSonHata = Dil::t("Yazılamadı: ") + d.yol;
            QTimer::singleShot(0, this, SLOT(isSonraki()));
        }
        return;
    }
    QString hata;
    const QString id = yolKlasoru(d.klasorYolu, &hata);
    if (id.isEmpty()) {
        // baglanti / izin sorunu: devam etmenin anlami yok
        isSonu(false, hata.isEmpty() ? Dil::t("Drive klasörü hazırlanamadı") : hata);
        return;
    }
    m_isAnahtar = d.anahtar;
    m_isIz = d.iz;
    if (!uploadIc(d.yol, id, QString(), true)) {
        ++m_isHata;
        m_isSonHata = Dil::t("Okunamadı: ") + QFileInfo(d.yol).fileName();
        QTimer::singleShot(0, this, SLOT(isSonraki()));
    }
}

void Drive::yukSonuc(bool ok, const QString &mesaj, const QString &json)
{
    if (!m_isAktif) { emit uploadFinished(ok, mesaj, json); return; }
    if (ok) {
        ++m_isYuklenen;
        ayar().setValue("yuklenen/" + m_isAnahtar, m_isIz);
    } else {
        ++m_isHata;
        m_isSonHata = mesaj;
        if (m_canceled || mesaj.contains(QString::fromUtf8("izni")) || mesaj.contains(Dil::t("parolası"))) {
            isSonu(false, m_isIptal ? QString::fromUtf8("Durduruldu") : mesaj);
            return;
        }
    }
    QTimer::singleShot(0, this, SLOT(isSonraki()));
}

void Drive::isSonu(bool ok, const QString &mesaj)
{
    m_isAktif = false;
    m_isListe.clear();
    m_isKlasor.clear();
    ayar().sync();
    QString m = mesaj;
    const bool indir = m_isIndir;
    m_isIndir = false;
    if (m.isEmpty() && indir) {
        m = QString::number(m_isYuklenen) + Dil::t(" dosya indirildi → ") + m_indirYerel;
        if (m_isHata) m += QString::fromUtf8(", ") + QString::number(m_isHata) + Dil::t(" hata (") + m_isSonHata + ")";
    } else if (m.isEmpty()) {
        m = QString::number(m_isYuklenen) + Dil::t(" dosya yüklendi");
        if (m_isAtlanan) m += QString::fromUtf8(", ") + QString::number(m_isAtlanan) + Dil::t(" değişmemiş atlandı");
        if (m_isHata) m += QString::fromUtf8(", ") + QString::number(m_isHata) + Dil::t(" hata (") + m_isSonHata + ")";
    } else if (m_isYuklenen) {
        m += QString::fromUtf8(" • ") + QString::number(m_isYuklenen) + (indir ? Dil::t(" dosya indirilmişti") : Dil::t(" dosya yüklenmişti"));
    }
    emit isDurum();
    emit isBitti(ok, m_isYuklenen, m_isAtlanan, m);
}
bool Drive::download(const QString &id, const QString &name)
{
    if (busy()) return false;
    m_path = localPath(name);
    QFile *f = new QFile(m_path + ".part", this);
    if (!f->open(QIODevice::WriteOnly | QIODevice::Truncate)) { delete f; return false; }
    QNetworkRequest req(QUrl(driveServer() + "/drive/dl/" + id));
    if (driveMod() == "sunucu") req.setRawHeader("X-Api-Key", driveKey().toUtf8()); req.setRawHeader("X-Lang", Dil::kodu());
    m_file = f;
    m_uploading = false;
    m_canceled = false;
    m_reply = m_nam.get(req);
    connect(m_reply, SIGNAL(downloadProgress(qint64, qint64)), this, SLOT(onDownloadProgress(qint64, qint64)));
    connect(m_reply, SIGNAL(readyRead()), this, SLOT(onReadyRead()));
    connect(m_reply, SIGNAL(finished()), this, SLOT(onFinished()));
    emit busyChanged();
    return true;
}

void Drive::cancel() { if (m_reply) { m_canceled = true; m_reply->abort(); } }

void Drive::onUploadProgress(qint64 done, qint64 total)
{
    emit progress(double(done), double(total > 0 ? total : (m_file ? m_file->size() : 0)));
}

void Drive::onDownloadProgress(qint64 done, qint64 total) { emit progress(double(done), double(total)); }

void Drive::onReadyRead() { if (m_reply && m_file && !m_uploading) m_file->write(m_reply->readAll()); }

void Drive::onFinished()
{
    QNetworkReply *r = m_reply;
    if (!r) return;
    const int status = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const bool netOk = r->error() == QNetworkReply::NoError;
    QString err = m_canceled ? Dil::t("İptal edildi") : r->errorString();
    if (status == 401 || status == 403) err = driveMod() == "google" ? Dil::t("Google izni reddedildi") : Dil::t("Sunucu parolası hatalı");

    if (m_uploading) {
        QByteArray body = r->readAll();
        if (m_file) { m_file->close(); m_file->deleteLater(); m_file = 0; }
        m_reply = 0;
        r->deleteLater();
        if (netOk && status == 200 && driveMod() == "google") {
            QVariantMap f = jsonCoz(body).toMap();
            if (m_gYeni && !f.value("id").toString().isEmpty()) {   // yeni dosya: adini ve klasorunu ayarla
                typedef QPair<QString, QString> P;
                QList<P> p; p << P("supportsAllDrives", "true") << P("fields", "id,name,mimeType,size,modifiedTime,starred,parents");
                if (m_gKlasor != "root") { p << P("addParents", m_gKlasor) << P("removeParents", "root"); }
                QVariantMap b; b["name"] = QFileInfo(m_path).fileName();
                QByteArray c;
                if (GAuth::ins()->istek("PATCH", driveUrl("files/" + f.value("id").toString(), p), jsonYaz(b), "application/json", &c) == 200) f = jsonCoz(c).toMap();
            }
            body = jsonYaz(gdriveOge(f));
        }
        emit busyChanged();
        if (netOk && status == 200) yukSonuc(true, Dil::t("Yüklendi"), QString::fromUtf8(body));
        else {
            QString msg = err;
            const int i = body.indexOf("\"error\":\"");
            if (i >= 0) { const int s = i + 9; msg = QString::fromUtf8(body.mid(s, body.indexOf('"', s) - s)); }
            else { const QString m2 = jsonCoz(body).toMap().value("error").toMap().value("message").toString(); if (!m2.isEmpty()) msg = m2; }
            yukSonuc(false, msg, QString());
        }
    } else {
        if (m_file && netOk) m_file->write(r->readAll());
        const QString part = m_file ? m_file->fileName() : QString();
        if (m_file) { m_file->close(); m_file->deleteLater(); m_file = 0; }
        m_reply = 0;
        r->deleteLater();
        emit busyChanged();
        const QString ctype = r->header(QNetworkRequest::ContentTypeHeader).toString();
        if (m_isAktif && m_isIndir) {           // klasor indirme isinin bir dosyasi
            if (netOk && status == 200 && !ctype.startsWith("text/html")) {
                QFile::remove(m_path);
                if (QFile::rename(part, m_path)) ++m_isYuklenen;
                else { ++m_isHata; m_isSonHata = Dil::t("Yazılamadı: ") + QFileInfo(m_path).fileName(); QFile::remove(part); }
            } else {
                QFile::remove(part);
                ++m_isHata;
                m_isSonHata = netOk ? Dil::t("Alınamadı: ") + QFileInfo(m_path).fileName() : err;
                if (m_canceled || status == 401 || status == 403) { isSonu(false, m_isIptal ? QString::fromUtf8("Durduruldu") : err); return; }
            }
            QTimer::singleShot(0, this, SLOT(isSonraki()));
            return;
        }
        if (netOk && status == 200 && !ctype.startsWith("text/html")) {
            QFile::remove(m_path);
            QFile::rename(part, m_path);
            emit downloadFinished(true, Dil::t("İndirildi"), m_path);
        } else {
            QFile::remove(part);
            emit downloadFinished(false, netOk ? Dil::t("Dosya alınamadı") : err, QString());
        }
    }
}

bool Drive::openFile(const QString &path) { return QDesktopServices::openUrl(QUrl::fromLocalFile(path)); }
bool Drive::fileExists(const QString &path) const { return QFileInfo(path).exists(); }
qint64 Drive::fileSize(const QString &path) const { return QFileInfo(path).size(); }
double Drive::fileTime(const QString &path) const { return double(QFileInfo(path).lastModified().toMSecsSinceEpoch()); }
QString Drive::baseName(const QString &path) const { return QFileInfo(path).fileName(); }

void Drive::openWeb()
{
    if (driveMod() == "google") { QDesktopServices::openUrl(QUrl("https://drive.google.com/")); return; }
    QUrl url(belleDuzHttp(driveServer()) + "/drive");   // telefonun tarayicisi TLS 1.2 bilmez
    url.addQueryItem("key", driveKey());
    QDesktopServices::openUrl(url);
}

void Drive::openUrl(const QString &url) { QDesktopServices::openUrl(QUrl::fromEncoded(url.toLatin1())); }

void Drive::forgetKey() { ayar().remove("key"); ayar().sync(); emit serverChanged(); }

bool Drive::changeServer()
{
    bool ok = false;
    QString cur = belleServer();
    cur.replace("http://", "");
    const QString in = QInputDialog::getText(0, Dil::t("Sunucu adresi"),
        Dil::t("Sunucu adresi (ör. 203.0.113.10):"), QLineEdit::Normal, cur, &ok);
    if (!ok) return false;
    const QString s = belleNormalizeServer(in);
    if (s.isEmpty() || s == belleServer()) return false;
    const int c = driveCheck(s, driveKey());
    if (c == -1) { QMessageBox::warning(0, QString::fromUtf8("Sunucu"), Dil::t("Bu adrese ulaşılamadı. Adres kaydedilmedi.")); return false; }
    belleSetServer(s);
    emit serverChanged();
    return true;
}

void Drive::setMod(const QString &m)
{
    ayar().setValue("mod", m == "google" ? "google" : "sunucu");
    ayar().sync();
    emit serverChanged();
}

bool Drive::hasKey() const { return !driveKey().isEmpty(); }

int Drive::setKey(const QString &key)
{
    QString k;
    for (int i = 0; i < key.length(); ++i) if (key.at(i).unicode() >= 32 && key.at(i).unicode() != 127) k += key.at(i);
    k = k.trimmed();
    const int c = driveCheck(belleServer(), k);
    if (c == 1) { ayar().setValue("key", k); ayar().sync(); emit serverChanged(); }
    return c;
}

QString Drive::googleClientId() const { return GAuth::ins()->clientId(); }
bool Drive::googleHasSecret() const { return !GAuth::ins()->clientSecret().isEmpty(); }
void Drive::setGoogleClient(const QString &id, const QString &secret)
{
    GAuth::ins()->setClient(id, secret.trimmed().isEmpty() ? GAuth::ins()->clientSecret() : secret);
    emit serverChanged();
}
bool Drive::googleBagli() const { return GAuth::ins()->bagli(); }
QString Drive::googleEmail() const { return GAuth::ins()->email(); }
QString Drive::googleIzinAdresi()
{
    const QString u = GAuth::ins()->izinAdresi();
    QApplication::clipboard()->setText(u);
    return u;
}
QString Drive::googleKodGir(const QString &yapistirilan)
{
    const QString h = GAuth::ins()->kodGir(yapistirilan);
    emit serverChanged();
    return h;
}
void Drive::googleCikis() { GAuth::ins()->cikis(); emit serverChanged(); }
