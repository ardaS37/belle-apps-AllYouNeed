#include "metin.h"
#include "dil.h"

#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QDateTime>
#include <QtCore/QTextCodec>
#include <QtCore/QUrl>
#include <QtCore/QtAlgorithms>
#include <QtGui/QApplication>
#include <QtGui/QClipboard>
#include <QtGui/QDesktopServices>
#include <QtGui/QKeyEvent>
#include <QtGui/QWidget>
#include <QtGui/QInputContext>
#include <QtGui/QImageReader>

static const char *KBundleMark = "@@@E6METIN@@@ ";

static QString norm(const QString &p)
{
    QString s = QDir::fromNativeSeparators(p.trimmed());
    if (s.length() > 3 && s.endsWith('/')) s.chop(1);
    return s;
}

static const QStringList &textExts()
{
    static QStringList l = QString(
        "txt text log ini cfg conf config inf csv tsv json xml html htm xhtml shtml css js mjs ts md markdown rst "
        "py pyw c cpp cc cxx h hpp hh java kt cs php rb pl lua sh bash bat cmd ps1 sql yaml yml toml properties prop "
        "srt sub ass ssa lrc vtt vcf vcs ics m3u m3u8 pls nfo diz url desktop qml pro pri pkg rss atom svg tex bib "
        "rtf jad mf manifest env lst list readme me todo nb asm s vb vbs reg go rs swift dart gradle cmake mak make "
        "diff patch po pot strings plist wml xsl xslt dtd").split(' ');
    return l;
}

static QString codecName(const QString &enc)
{
    const QString e = enc.trimmed();
    if (e.isEmpty()) return QString();
    if (e.compare("UTF8", Qt::CaseInsensitive) == 0) return "UTF-8";
    return e;
}

static bool byNameAsc(const QVariant &a, const QVariant &b)
{
    return QString::localeAwareCompare(a.toMap().value("name").toString().toLower(),
                                       b.toMap().value("name").toString().toLower()) < 0;
}
static bool byDateDesc(const QVariant &a, const QVariant &b)
{
    return a.toMap().value("time").toUInt() > b.toMap().value("time").toUInt();
}
static bool bySizeDesc(const QVariant &a, const QVariant &b)
{
    return a.toMap().value("size").toLongLong() > b.toMap().value("size").toLongLong();
}

Metin::Metin(QObject *parent)
    : QObject(parent), m_logLoaded(false)
{
#if defined(Q_OS_SYMBIAN)
    m_base = QDir("E:/").exists() ? "E:/BelleFiles" : "C:/Data/BelleFiles";
    m_data = "C:/Data/BelleFiles";
    // E6Metin'den gecis: eski notlar klasoru varsa onu kullanmaya devam et
    const QString eski = QDir("E:/").exists() ? "E:/E6Metin/Notlar" : "C:/Data/E6Metin/Notlar";
#else
    m_base = QDir::homePath() + "/BelleFiles";
    m_data = m_base + "/veri";
    const QString eski = QDir::homePath() + "/E6Metin/Notlar";
#endif
    m_notes = QFileInfo(eski).isDir() ? eski : m_base + "/Notlar";
    QDir().mkpath(m_notes);
    QDir().mkpath(m_data);
}

void Metin::setNotesDir(const QString &path)
{
    const QString p = norm(path);
    if (p.isEmpty()) return;
    QDir().mkpath(p);
    if (QFileInfo(p).isDir()) m_notes = p;
}

QString Metin::exportDir() const
{
    const QString d = m_base + Dil::t("/Disa aktarilan");
    QDir().mkpath(d);
    return d;
}

QString Metin::backupDir() const
{
    const QString d = m_base + "/Yedek";
    QDir().mkpath(d);
    return d;
}

// ================= Gezinme =================

QVariantList Metin::listDir(const QString &pathIn, bool allFiles, const QString &filter, const QString &sort) const
{
    QVariantList out;
    const QString path = norm(pathIn);
    if (path.isEmpty()) {
        QStringList rp, rn;   // yol, gorunen ad
        rp << m_notes; rn << Dil::t("Notlarım");
#if defined(Q_OS_SYMBIAN)
        rp << "E:/"; rn << Dil::t("Hafıza kartı (E:)");
        rp << "F:/"; rn << Dil::t("Yığın bellek (F:)");
        rp << "C:/Data"; rn << Dil::t("Telefon belleği (C:)");
        rp << "C:/"; rn << Dil::t("C: kök dizini (sistem)");
        rp << "Z:/"; rn << Dil::t("Z: ROM (salt okunur)");
        rp << "E:/Documents"; rn << Dil::t("Belgeler (kart)");
        rp << "C:/Data/Documents"; rn << Dil::t("Belgeler (telefon)");
        rp << "E:/Downloads"; rn << Dil::t("İndirilenler (kart)");
        rp << "C:/Data/Downloads"; rn << Dil::t("İndirilenler (telefon)");
#else
        rp << QDir::homePath(); rn << Dil::t("Ev klasörü");
        rp << QDir::rootPath(); rn << Dil::t("Kök");
#endif
        rp << exportDir(); rn << Dil::t("Dışa aktarılanlar");
        rp << backupDir(); rn << QString::fromUtf8("Yedekler");
        for (int i = 0; i < rp.size(); ++i) {
            if (!QFileInfo(rp.at(i)).isDir()) continue;
            QVariantMap m;
            m["name"] = rn.at(i);
            m["path"] = norm(rp.at(i));
            m["dir"] = true;
            m["size"] = 0;
            m["time"] = 0;
            m["ext"] = "";
            m["text"] = false;
            out << m;
        }
        return out;
    }

    QDir d(path);
    QVariantList dirs, files;
    const QString f = filter.trimmed();
    foreach (const QFileInfo &fi, d.entryInfoList(QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System)) {
        const QString name = fi.fileName();
        if (!f.isEmpty() && !name.contains(f, Qt::CaseInsensitive)) continue;
        QVariantMap m;
        m["name"] = name;
        m["path"] = norm(fi.absoluteFilePath());
        m["time"] = fi.lastModified().toTime_t();
        if (fi.isDir()) {
            if (!allFiles && name.startsWith('.')) continue;
            m["dir"] = true;
            m["size"] = 0;
            m["ext"] = "";
            m["text"] = false;
            dirs << m;
        } else {
            const QString ext = fi.suffix().toLower();
            const bool txt = textExts().contains(ext) || (ext.isEmpty() && fi.size() < 256 * 1024);
            if (!allFiles && (!txt || name.endsWith(".e6tmp"))) continue;
            m["dir"] = false;
            m["size"] = fi.size();
            m["ext"] = ext;
            m["text"] = txt;
            files << m;
        }
    }
    qSort(dirs.begin(), dirs.end(), sort == "date" ? byDateDesc : byNameAsc);
    if (sort == "date") qSort(files.begin(), files.end(), byDateDesc);
    else if (sort == "size") qSort(files.begin(), files.end(), bySizeDesc);
    else qSort(files.begin(), files.end(), byNameAsc);
    out << dirs << files;
    return out;
}

bool Metin::isRoot(const QString &pathIn) const
{
    const QString p = norm(pathIn);
    return p.isEmpty() || p.length() <= 3 || p.compare("C:/Data", Qt::CaseInsensitive) == 0;
}

QString Metin::parentDir(const QString &pathIn) const
{
    const QString path = norm(pathIn);
    if (path.isEmpty() || path.length() <= 3) return QString();
#if defined(Q_OS_SYMBIAN)
    if (path.compare("C:/Data", Qt::CaseInsensitive) == 0) return QString();
#endif
    return norm(QFileInfo(path).absolutePath());
}

bool Metin::isText(const QString &path) const
{
    const QFileInfo fi(path);
    const QString ext = fi.suffix().toLower();
    return textExts().contains(ext) || (ext.isEmpty() && fi.size() < 256 * 1024);
}

QString Metin::textExtensions() const { return textExts().join(" "); }

QVariantMap Metin::info(const QString &path) const
{
    QVariantMap m;
    const QFileInfo fi(path);
    m["exists"] = fi.exists();
    m["dir"] = fi.isDir();
    m["size"] = fi.size();
    m["time"] = fi.lastModified().toTime_t();
    m["name"] = fi.fileName();
    m["base"] = fi.completeBaseName();
    m["ext"] = fi.suffix().toLower();
    m["folder"] = norm(fi.absolutePath());
    m["readOnly"] = fi.exists() && !fi.isWritable();
    if (fi.isDir()) {
        QDir d(path);
        m["count"] = d.entryList(QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot).size();
    }
    return m;
}

bool Metin::exists(const QString &path) const { return !path.isEmpty() && QFileInfo(path).exists(); }
bool Metin::isDir(const QString &path) const { return !path.isEmpty() && QFileInfo(path).isDir(); }
QString Metin::fileName(const QString &path) const { return QFileInfo(norm(path)).fileName(); }
QString Metin::baseName(const QString &path) const { return QFileInfo(norm(path)).completeBaseName(); }
QString Metin::suffix(const QString &path) const { return QFileInfo(norm(path)).suffix().toLower(); }
QString Metin::folderOf(const QString &path) const { return norm(QFileInfo(norm(path)).absolutePath()); }

QString Metin::join(const QString &dir, const QString &name) const
{
    QString d = norm(dir);
    if (!d.endsWith('/')) d += '/';
    return d + name;
}

QString Metin::uniquePath(const QString &dir, const QString &name) const
{
    QString p = join(dir, name);
    if (!QFileInfo(p).exists()) return p;
    const QFileInfo fi(name);
    const QString base = fi.completeBaseName().isEmpty() ? name : fi.completeBaseName();
    const QString ext = fi.completeBaseName().isEmpty() || fi.suffix().isEmpty() ? QString() : "." + fi.suffix();
    for (int i = 2; i < 1000; ++i) {
        p = join(dir, base + " (" + QString::number(i) + ")" + ext);
        if (!QFileInfo(p).exists()) return p;
    }
    return join(dir, base + "_" + QString::number(QDateTime::currentDateTime().toTime_t()) + ext);
}

QString Metin::sizeText(qint64 b) const
{
    if (b >= 1024LL * 1024 * 1024) return QString::number(b / (1024.0 * 1024 * 1024), 'f', 2) + " GB";
    if (b >= 1024 * 1024) return QString::number(b / (1024.0 * 1024), 'f', 1) + " MB";
    if (b < 1024) return QString::number(b) + " B";
    return QString::number((b + 1023) / 1024) + " KB";
}

void Metin::girisiTamamla() const
{
    QWidget *w = QApplication::focusWidget();
    if (w && w->inputContext()) w->inputContext()->reset();
}

bool Metin::validName(const QString &name) const
{
    const QString n = name.trimmed();
    if (n.isEmpty() || n == "." || n == "..") return false;
    static const QString bad = "\\/:*?\"<>|";
    for (int i = 0; i < n.length(); ++i) {
        if (bad.contains(n.at(i)) || n.at(i).unicode() < 32) return false;
    }
    return true;
}

// ================= Okuma / yazma =================

QString Metin::decode(const QByteArray &bytes, const QString &wantIn, QString *used, bool *bom, bool *binary) const
{
    QString want = codecName(wantIn);
    QByteArray data = bytes;
    *bom = false;
    *binary = false;

    if (bytes.startsWith("\xEF\xBB\xBF")) {
        *bom = true;
        if (want.isEmpty()) want = "UTF-8";
        if (want == "UTF-8") data = bytes.mid(3);
    } else if (bytes.startsWith("\xFF\xFE")) {
        *bom = true;
        if (want.isEmpty()) want = "UTF-16LE";
        if (want == "UTF-16LE") data = bytes.mid(2);
    } else if (bytes.startsWith("\xFE\xFF")) {
        *bom = true;
        if (want.isEmpty()) want = "UTF-16BE";
        if (want == "UTF-16BE") data = bytes.mid(2);
    } else if (want.isEmpty() && bytes.size() >= 4 && bytes.at(1) == 0 && bytes.at(3) == 0 && bytes.at(0) != 0) {
        want = "UTF-16LE";   // BOM'suz UTF-16 (ozellikle Windows'tan gelen dosyalar)
    }

    if (!want.startsWith("UTF-16")) {
        const int n = qMin(data.size(), 8192);
        int zeros = 0;
        for (int i = 0; i < n; ++i) if (data.at(i) == 0) zeros++;
        *binary = zeros > 0;
    }

    if (want.isEmpty()) {
        QTextCodec *u = QTextCodec::codecForName("UTF-8");
        QTextCodec::ConverterState st;
        const QString s = u->toUnicode(data.constData(), data.size(), &st);
        if (st.invalidChars == 0) {
            *used = "UTF-8";
            return s;
        }
        want = "windows-1254";
    }
    QTextCodec *c = QTextCodec::codecForName(want.toLatin1());
    if (!c) { c = QTextCodec::codecForName("UTF-8"); want = "UTF-8"; }
    *used = want;
    return c->toUnicode(data);
}

static QString detectEol(const QString &t)
{
    const int crlf = t.count("\r\n");
    const int cr = t.count('\r') - crlf;
    const int lf = t.count('\n') - crlf;
    if (crlf == 0 && lf == 0 && cr == 0) return QString();
    if (crlf >= lf && crlf >= cr) return "crlf";
    if (cr > lf) return "cr";
    return "lf";
}

static QString normalizeEol(QString t)
{
    t.replace("\r\n", "\n");
    t.replace('\r', '\n');
    return t;
}

QVariantMap Metin::readText(const QString &path, const QString &encoding) const
{
    QVariantMap r;
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) {
        r["ok"] = false;
        r["error"] = f.errorString();
        return r;
    }
    const QByteArray b = f.readAll();
    f.close();
    QString used;
    bool bom = false, binary = false;
    QString t = decode(b, encoding, &used, &bom, &binary);
    if (binary) t.replace(QChar(0), QChar(0x2400));   // NUL yerine gorunur isaret
    const QString eol = detectEol(t);
    r["ok"] = true;
    r["text"] = normalizeEol(t);
    r["encoding"] = used;
    r["eol"] = eol;
    r["bom"] = bom;
    r["binary"] = binary;
    r["size"] = b.size();
    return r;
}

QVariantMap Metin::readPart(const QString &path, qint64 offset, int length, const QString &encoding) const
{
    QVariantMap r;
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) {
        r["ok"] = false;
        r["error"] = f.errorString();
        return r;
    }
    const qint64 size = f.size();
    if (offset < 0) offset = 0;
    if (offset > size) offset = size;
    f.seek(offset);
    QByteArray b = f.read(length + 4);
    int end = qMin(length, b.size());
    // UTF-8 cok baytli karakteri ortadan bolme
    while (end < b.size() && (static_cast<unsigned char>(b.at(end)) & 0xC0) == 0x80) end++;
    b.truncate(end);
    f.close();
    QString used;
    bool bom = false, binary = false;
    QString t = decode(b, encoding.isEmpty() ? QString("UTF-8") : encoding, &used, &bom, &binary);
    if (binary) t.replace(QChar(0), QChar(0x2400));
    r["ok"] = true;
    r["text"] = normalizeEol(t);
    r["offset"] = offset;
    r["next"] = offset + b.size();
    r["size"] = size;
    r["encoding"] = used;
    return r;
}

QVariantMap Metin::writeText(const QString &pathIn, const QString &text, const QString &encodingIn,
                             const QString &eol, bool bom, bool backup)
{
    QVariantMap r;
    const QString path = norm(pathIn);
    QString enc = codecName(encodingIn);
    if (enc.isEmpty()) enc = "UTF-8";
    QTextCodec *c = QTextCodec::codecForName(enc.toLatin1());
    if (!c) { c = QTextCodec::codecForName("UTF-8"); enc = "UTF-8"; }

    QString t = normalizeEol(text);   // gelen metinde \r\n olsa da cift \r olmasin
    if (eol == "crlf") t.replace("\n", "\r\n");
    else if (eol == "cr") t.replace('\n', '\r');

    QByteArray out;
    if (bom) {
        if (enc == "UTF-8") out = "\xEF\xBB\xBF";
        else if (enc == "UTF-16LE") out = "\xFF\xFE";
        else if (enc == "UTF-16BE") out = "\xFE\xFF";
    }
    QTextCodec::ConverterState st(QTextCodec::IgnoreHeader);
    out += c->fromUnicode(t.constData(), t.length(), &st);
    r["lost"] = st.invalidChars;

    QDir().mkpath(QFileInfo(path).absolutePath());
    const QString tmp = path + ".e6tmp";
    QFile f(tmp);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        r["ok"] = false;
        r["error"] = f.errorString();
        return r;
    }
    const qint64 w = f.write(out);
    f.flush();
    f.close();
    if (w != out.size()) {
        QFile::remove(tmp);
        r["ok"] = false;
        r["error"] = Dil::t("Yazılamadı (yer dolu olabilir)");
        return r;
    }
    if (QFile::exists(path)) {
        if (backup) {
            QFile::remove(path + ".bak");
            if (!QFile::rename(path, path + ".bak")) QFile::remove(path);
        } else if (!QFile::remove(path)) {
            QFile::remove(tmp);
            r["ok"] = false;
            r["error"] = Dil::t("Eski dosya değiştirilemedi (salt okunur ya da açık)");
            return r;
        }
    }
    if (!QFile::rename(tmp, path)) {
        r["ok"] = false;
        r["error"] = Dil::t("Geçici dosyanın adı değiştirilemedi: ") + tmp;
        return r;
    }
    r["ok"] = true;
    r["size"] = out.size();
    return r;
}

// ================= Dosya islemleri =================

bool Metin::makeDir(const QString &path)
{
    m_error.clear();
    if (QFileInfo(path).exists()) { m_error = Dil::t("Bu adda bir öğe zaten var"); return false; }
    if (!QDir().mkpath(path)) { m_error = Dil::t("Klasör oluşturulamadı"); return false; }
    return true;
}

bool Metin::copyRec(const QString &src, const QString &dst)
{
    const QFileInfo fi(src);
    if (fi.isDir()) {
        if (!QDir().mkpath(dst)) return false;
        bool ok = true;
        foreach (const QFileInfo &c, QDir(src).entryInfoList(QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System))
            ok = copyRec(c.absoluteFilePath(), dst + "/" + c.fileName()) && ok;
        return ok;
    }
    return QFile::copy(src, dst);
}

bool Metin::removeRec(const QString &path)
{
    const QFileInfo fi(path);
    if (fi.isDir() && !fi.isSymLink()) {
        bool ok = true;
        foreach (const QFileInfo &c, QDir(path).entryInfoList(QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System))
            ok = removeRec(c.absoluteFilePath()) && ok;
        return QDir().rmdir(path) && ok;
    }
    if (!QFile::remove(path)) {
        QFile::setPermissions(path, QFile::ReadOwner | QFile::WriteOwner);
        return QFile::remove(path);
    }
    return true;
}

QString Metin::copyPath(const QString &srcIn, const QString &dstDirIn)
{
    m_error.clear();
    const QString src = norm(srcIn), dstDir = norm(dstDirIn);
    if (!QFileInfo(src).exists()) { m_error = Dil::t("Kaynak bulunamadı"); return QString(); }
    if (QFileInfo(src).isDir() && (dstDir.compare(src, Qt::CaseInsensitive) == 0 ||
                                   dstDir.startsWith(src + "/", Qt::CaseInsensitive))) {
        m_error = Dil::t("Klasör kendi içine kopyalanamaz");
        return QString();
    }
    QDir().mkpath(dstDir);
    const QString dst = uniquePath(dstDir, QFileInfo(src).fileName());
    if (!copyRec(src, dst)) { m_error = Dil::t("Kopyalanamadı (yer dolu ya da erişim yok)"); return QString(); }
    return dst;
}

QString Metin::movePath(const QString &srcIn, const QString &dstDirIn)
{
    m_error.clear();
    const QString src = norm(srcIn), dstDir = norm(dstDirIn);
    if (!QFileInfo(src).exists()) { m_error = Dil::t("Kaynak bulunamadı"); return QString(); }
    if (folderOf(src).compare(dstDir, Qt::CaseInsensitive) == 0) return src;
    if (QFileInfo(src).isDir() && (dstDir.compare(src, Qt::CaseInsensitive) == 0 ||
                                   dstDir.startsWith(src + "/", Qt::CaseInsensitive))) {
        m_error = Dil::t("Klasör kendi içine taşınamaz");
        return QString();
    }
    QDir().mkpath(dstDir);
    const QString dst = uniquePath(dstDir, QFileInfo(src).fileName());
    if (QDir().rename(src, dst)) return dst;
    // Farkli surucu: kopyala ve sil
    if (!copyRec(src, dst)) { removeRec(dst); m_error = Dil::t("Taşınamadı"); return QString(); }
    if (!removeRec(src)) m_error = Dil::t("Kopyalandı ama kaynak silinemedi");
    return dst;
}

QString Metin::renamePath(const QString &srcIn, const QString &newNameIn)
{
    m_error.clear();
    const QString src = norm(srcIn);
    const QString newName = newNameIn.trimmed();
    if (!validName(newName)) { m_error = Dil::t("Geçersiz ad (\\ / : * ? \" < > | kullanılamaz)"); return QString(); }
    const QString dst = join(folderOf(src), newName);
    if (dst == src) return src;
    const bool caseOnly = dst.compare(src, Qt::CaseInsensitive) == 0;
    if (!caseOnly && QFileInfo(dst).exists()) { m_error = Dil::t("Bu adda bir öğe zaten var"); return QString(); }
    if (caseOnly) {
        const QString tmp = src + ".e6ad";
        if (!QDir().rename(src, tmp) || !QDir().rename(tmp, dst)) { m_error = Dil::t("Ad değiştirilemedi"); return QString(); }
        return dst;
    }
    if (!QDir().rename(src, dst)) { m_error = Dil::t("Ad değiştirilemedi (dosya açık ya da salt okunur)"); return QString(); }
    return dst;
}

QString Metin::changeExtension(const QString &pathIn, const QString &extIn, bool keepOriginal)
{
    m_error.clear();
    const QString path = norm(pathIn);
    QString ext = extIn.trimmed();
    while (ext.startsWith('.')) ext = ext.mid(1);
    const QFileInfo fi(path);
    const QString base = fi.completeBaseName().isEmpty() ? fi.fileName() : fi.completeBaseName();
    const QString newName = ext.isEmpty() ? base : base + "." + ext;
    if (keepOriginal) {
        const QString dst = uniquePath(folderOf(path), newName);
        if (!QFile::copy(path, dst)) { m_error = Dil::t("Kopya oluşturulamadı"); return QString(); }
        return dst;
    }
    return renamePath(path, newName);
}

bool Metin::removePath(const QString &path)
{
    m_error.clear();
    if (path.isEmpty() || isRoot(path)) { m_error = Dil::t("Bu klasör silinemez"); return false; }
    if (!QFileInfo(path).exists()) return true;
    if (!removeRec(norm(path))) { m_error = Dil::t("Silinemedi (açık ya da salt okunur olabilir)"); return false; }
    return true;
}

// ================= Pano ve sistem =================

QString Metin::clipboardText() const
{
    return QApplication::clipboard()->text();
}

void Metin::setClipboardText(const QString &text)
{
    QApplication::clipboard()->setText(text);
}

void Metin::sendKey(int key, int modifiers)
{
    QWidget *w = QApplication::focusWidget();
    if (!w) return;
    QKeyEvent press(QEvent::KeyPress, key, Qt::KeyboardModifiers(modifiers));
    QApplication::sendEvent(w, &press);
    QKeyEvent release(QEvent::KeyRelease, key, Qt::KeyboardModifiers(modifiers));
    QApplication::sendEvent(w, &release);
}

bool Metin::openExternally(const QString &path) const
{
    if (path.contains("://")) return QDesktopServices::openUrl(QUrl(path));
    return QDesktopServices::openUrl(QUrl::fromLocalFile(path));
}

QVariantMap Metin::resimBoyutu(const QString &path) const
{
    QVariantMap m;
    const QSize s = QImageReader(path).size();
    m["w"] = s.isValid() ? s.width() : 0;
    m["h"] = s.isValid() ? s.height() : 0;
    return m;
}

QString Metin::now(const QString &format) const
{
    return QDateTime::currentDateTime().toString(format.isEmpty() ? QString("dd.MM.yyyy HH:mm") : format);
}

// ================= Arama =================

QVariantList Metin::searchFiles(const QString &dirIn, const QString &query, bool inContent) const
{
    QVariantList out;
    const QString q = query.trimmed();
    if (q.isEmpty()) return out;
    QStringList queue;
    queue << norm(dirIn);
    int scanned = 0;
    while (!queue.isEmpty() && out.size() < 150 && scanned < 1500) {
        const QString dir = queue.takeFirst();
        foreach (const QFileInfo &fi, QDir(dir).entryInfoList(QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot, QDir::Name | QDir::IgnoreCase)) {
            if (fi.isDir()) {
                const QString n = fi.fileName().toLower();
                if (n.startsWith('.') || n == "private" || n == "sys" || n == "resource") continue;
                queue << norm(fi.absoluteFilePath());
                continue;
            }
            scanned++;
            const QString name = fi.fileName();
            if (name.contains(q, Qt::CaseInsensitive)) {
                QVariantMap m;
                m["path"] = norm(fi.absoluteFilePath());
                m["name"] = name;
                m["lineNo"] = 0;
                m["line"] = folderOf(fi.absoluteFilePath());
                out << m;
                if (out.size() >= 150) break;
                continue;
            }
            if (!inContent || !isText(fi.absoluteFilePath()) || fi.size() > 1024 * 1024) continue;
            const QVariantMap rt = readText(fi.absoluteFilePath(), QString());
            const QString t = rt.value("text").toString();
            const int at = t.indexOf(q, 0, Qt::CaseInsensitive);
            if (at < 0) continue;
            const int ls = t.lastIndexOf('\n', at) + 1;
            int le = t.indexOf('\n', at);
            if (le < 0) le = t.length();
            QVariantMap m;
            m["path"] = norm(fi.absoluteFilePath());
            m["name"] = name;
            m["lineNo"] = t.left(at).count('\n') + 1;
            m["line"] = t.mid(ls, qMin(le - ls, 120)).trimmed();
            m["pos"] = at;
            out << m;
            if (out.size() >= 150) break;
        }
    }
    return out;
}

// ================= Disa / ice aktarma =================

QString Metin::exportBundle(const QStringList &paths, const QString &outPath)
{
    m_error.clear();
    QString all = Dil::t("# Belle Files paketi • ") + now(QString()) + QString::fromUtf8(" • ") +
                  QString::number(paths.size()) + Dil::t(" dosya\n# İçe aktarmak için: Belle Files > dosya menüsü > Paketi içe aktar\n");
    int n = 0;
    foreach (const QString &p, paths) {
        if (QFileInfo(p).isDir()) continue;
        const QVariantMap rt = readText(p, QString());
        if (!rt.value("ok").toBool()) continue;
        all += "\n" + QString::fromLatin1(KBundleMark) + QFileInfo(p).fileName() + "\n";
        QString t = rt.value("text").toString();
        // Paketin icindeki dosyada isaret satiri varsa bozulmasin diye bir bosluk eklenir
        t.replace("\n" + QString::fromLatin1(KBundleMark), "\n " + QString::fromLatin1(KBundleMark));
        if (t.startsWith(QString::fromLatin1(KBundleMark))) t.prepend(' ');
        all += t;
        if (!t.endsWith('\n')) all += '\n';
        n++;
    }
    if (n == 0) { m_error = Dil::t("Dışa aktarılacak metin dosyası yok"); return QString(); }
    const QVariantMap w = writeText(outPath, all, "UTF-8", "crlf", false, false);
    if (!w.value("ok").toBool()) { m_error = w.value("error").toString(); return QString(); }
    return norm(outPath);
}

bool Metin::isBundle(const QString &path) const
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) return false;
    const QByteArray head = f.read(64 * 1024);
    return head.contains(QByteArray("\n") + KBundleMark) || head.startsWith(KBundleMark);
}

QStringList Metin::importBundle(const QString &bundlePath, const QString &targetDir)
{
    m_error.clear();
    QStringList created;
    const QVariantMap rt = readText(bundlePath, QString());
    if (!rt.value("ok").toBool()) { m_error = rt.value("error").toString(); return created; }
    const QString mark = QString::fromLatin1(KBundleMark);
    const QStringList lines = rt.value("text").toString().split('\n');
    QString name;
    QStringList body;
    QDir().mkpath(targetDir);
    for (int i = 0; i <= lines.size(); ++i) {
        const bool atEnd = i == lines.size();
        const QString line = atEnd ? QString() : lines.at(i);
        if (atEnd || line.startsWith(mark)) {
            if (!name.isEmpty()) {
                while (!body.isEmpty() && body.last().isEmpty()) body.removeLast();
                QString t = body.join("\n") + "\n";
                t.replace("\n " + mark, "\n" + mark);
                if (t.startsWith(" " + mark)) t = t.mid(1);
                QString safe = name.trimmed();
                if (!validName(safe)) safe = "not.txt";
                const QString p = uniquePath(targetDir, safe);
                const QVariantMap w = writeText(p, t, "UTF-8", "crlf", false, false);
                if (w.value("ok").toBool()) created << p;
            }
            if (atEnd) break;
            name = line.mid(mark.length());
            body.clear();
        } else if (!name.isEmpty()) {
            body << line;
        }
    }
    if (created.isEmpty()) m_error = Dil::t("Pakette dosya bulunamadı");
    return created;
}

QStringList Metin::textFilesIn(const QString &dir, bool recursive) const
{
    QStringList out;
    QStringList queue;
    queue << norm(dir);
    while (!queue.isEmpty() && out.size() < 500) {
        const QString d = queue.takeFirst();
        foreach (const QFileInfo &fi, QDir(d).entryInfoList(QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot, QDir::Name | QDir::IgnoreCase)) {
            if (fi.isDir()) { if (recursive && !fi.fileName().startsWith('.')) queue << norm(fi.absoluteFilePath()); continue; }
            if (isText(fi.absoluteFilePath()) && !fi.fileName().endsWith(".e6tmp")) out << norm(fi.absoluteFilePath());
        }
    }
    return out;
}

QString Metin::backupFolder(const QString &srcDir)
{
    m_error.clear();
    const QString src = norm(srcDir);
    if (!QFileInfo(src).isDir()) { m_error = Dil::t("Klasör bulunamadı"); return QString(); }
    const QString target = join(backupDir(), QFileInfo(src).fileName() + "_" + now("yyyyMMdd_HHmm"));
    const QString dst = uniquePath(folderOf(target), fileName(target));
    if (!copyRec(src, dst)) { m_error = Dil::t("Yedek tamamlanamadı (yer dolu olabilir)"); return dst; }
    return dst;
}

// ================= Gunluk =================

static const int KLogLines = 60;

void Metin::log(const QString &line)
{
    if (!m_logLoaded) {
        m_logLoaded = true;
        QFile in(m_data + "/gunluk.txt");
        if (in.open(QIODevice::ReadOnly)) {
            m_log = QString::fromUtf8(in.readAll().right(8000)).split('\n', QString::SkipEmptyParts);
            while (m_log.size() > KLogLines) m_log.removeFirst();
        }
    }
    m_log << QDateTime::currentDateTime().toString("dd.MM HH:mm:ss ") + line;
    qDebug("BF %s", line.toUtf8().constData());
    while (m_log.size() > KLogLines) m_log.removeFirst();
    QFile f(m_data + "/gunluk.txt");
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        f.write(m_log.join("\n").toUtf8());
        f.close();
    }
}

QString Metin::logText() const
{
    if (!m_logLoaded) {
        QFile in(m_data + "/gunluk.txt");
        if (in.open(QIODevice::ReadOnly)) return QString::fromUtf8(in.readAll().right(8000));
    }
    return m_log.isEmpty() ? Dil::t("(günlük boş)") : m_log.join("\n");
}

void Metin::clearLog()
{
    m_log.clear();
    m_logLoaded = true;
    QFile::remove(m_data + "/gunluk.txt");
}
