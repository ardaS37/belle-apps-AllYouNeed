#include "mime.h"
#include <QtCore/QTextCodec>
#include <QtCore/QRegExp>
#include <QtCore/QStringList>
#include <ctype.h>

#define L1(s) QString::fromLatin1(s)

namespace Mime {

static QByteArray qCoz(const QByteArray &t, bool altCizgi)
{
    QByteArray o;
    o.reserve(t.size());
    for (int i = 0; i < t.size(); ++i) {
        const char c = t.at(i);
        if (c == '_' && altCizgi) o.append(' ');
        else if (c == '=' && i + 2 < t.size()) {
            bool ok = false;
            const int v = t.mid(i + 1, 2).toInt(&ok, 16);
            if (ok) { o.append(char(v)); i += 2; }
            else o.append(c);
        } else o.append(c);
    }
    return o;
}

QString metne(const QByteArray &veri, const QByteArray &charset)
{
    QByteArray cs = charset.trimmed().toLower();
    if (cs.startsWith('"')) cs = cs.mid(1);
    if (cs.endsWith('"')) cs.chop(1);
    if (cs == "utf8") cs = "utf-8";
    if (cs == "us-ascii" || cs == "ascii" || cs == "unknown-8bit" || cs == "x-unknown") cs.clear();
    if (cs == "iso-8859-1" || cs == "latin1") cs = "windows-1252";   // pratikte hep 1252
    if (!cs.isEmpty() && cs != "utf-8") {
        QTextCodec *c = QTextCodec::codecForName(cs);
        if (c) return c->toUnicode(veri);
    }
    QTextCodec *u = QTextCodec::codecForName("UTF-8");
    QTextCodec::ConverterState st;
    const QString s = u->toUnicode(veri.constData(), veri.size(), &st);
    if (st.invalidChars == 0 || cs == "utf-8") return s;
    QTextCodec *tr = QTextCodec::codecForName("windows-1254");
    return tr ? tr->toUnicode(veri) : QString::fromLatin1(veri);
}

QString baslikCoz(const QByteArray &s)
{
    QString sonuc;
    QByteArray bekleyen, bekleyenCs;
    bool sonKodlu = false;
    int i = 0;
    const int n = s.size();
    while (i < n) {
        const int b = s.indexOf("=?", i);
        int q1 = -1, q2 = -1, e = -1;
        if (b >= 0) {
            q1 = s.indexOf('?', b + 2);
            q2 = q1 > 0 ? s.indexOf('?', q1 + 1) : -1;
            e = q2 > 0 ? s.indexOf("?=", q2 + 1) : -1;
        }
        if (b < 0 || q1 < 0 || q2 != q1 + 2 || e < 0) {
            if (!bekleyen.isEmpty()) { sonuc += metne(bekleyen, bekleyenCs); bekleyen.clear(); }
            if (b < 0) { sonuc += metne(s.mid(i), QByteArray()); break; }
            sonuc += metne(s.mid(i, b + 2 - i), QByteArray());
            i = b + 2;
            sonKodlu = false;
            continue;
        }
        const QByteArray duz = s.mid(i, b - i);
        if (!(sonKodlu && duz.trimmed().isEmpty())) {
            if (!bekleyen.isEmpty()) { sonuc += metne(bekleyen, bekleyenCs); bekleyen.clear(); }
            sonuc += metne(duz, QByteArray());
        }
        QByteArray cs = s.mid(b + 2, q1 - b - 2).toLower();
        const int yildiz = cs.indexOf('*');
        if (yildiz >= 0) cs = cs.left(yildiz);
        const char kod = char(toupper(s.at(q1 + 1)));
        const QByteArray metin = s.mid(q2 + 1, e - q2 - 1);
        const QByteArray cozuk = kod == 'B' ? QByteArray::fromBase64(metin) : qCoz(metin, true);
        if (cs != bekleyenCs && !bekleyen.isEmpty()) { sonuc += metne(bekleyen, bekleyenCs); bekleyen.clear(); }
        bekleyenCs = cs;
        bekleyen += cozuk;
        sonKodlu = true;
        i = e + 2;
    }
    if (!bekleyen.isEmpty()) sonuc += metne(bekleyen, bekleyenCs);
    return sonuc.simplified();
}

QString rfc2231Coz(const QByteArray &s)
{
    const int a = s.indexOf('\'');
    const int b = a >= 0 ? s.indexOf('\'', a + 1) : -1;
    if (a < 0 || b < 0) return baslikCoz(s);
    const QByteArray cs = s.left(a);
    QByteArray v = s.mid(b + 1);
    QByteArray o;
    for (int i = 0; i < v.size(); ++i) {
        if (v.at(i) == '%' && i + 2 < v.size()) {
            bool ok = false;
            const int x = v.mid(i + 1, 2).toInt(&ok, 16);
            if (ok) { o.append(char(x)); i += 2; continue; }
        }
        o.append(v.at(i));
    }
    return metne(o, cs);
}

QByteArray aktarimCoz(const QByteArray &veri, const QByteArray &kodlama)
{
    const QByteArray k = kodlama.toLower();
    if (k == "base64") {
        QByteArray t;
        t.reserve(veri.size());
        for (int i = 0; i < veri.size(); ++i) {
            const char c = veri.at(i);
            if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '+' || c == '/' || c == '=') t.append(c);
        }
        const int esit = t.indexOf('=');
        if (esit >= 0 && esit < t.size() - 2) t = t.left(esit);   // yarida kesilmis govde
        t.chop(t.size() % 4);
        return QByteArray::fromBase64(t);
    }
    if (k == "quoted-printable") {
        QByteArray o;
        o.reserve(veri.size());
        for (int i = 0; i < veri.size(); ++i) {
            const char c = veri.at(i);
            if (c != '=') { o.append(c); continue; }
            if (i + 1 < veri.size() && veri.at(i + 1) == '\n') { i += 1; continue; }
            if (i + 2 < veri.size() && veri.at(i + 1) == '\r' && veri.at(i + 2) == '\n') { i += 2; continue; }
            if (i + 2 < veri.size()) {
                bool ok = false;
                const int v = veri.mid(i + 1, 2).toInt(&ok, 16);
                if (ok) { o.append(char(v)); i += 2; continue; }
            }
            if (i + 2 >= veri.size()) break;   // kesik son
            o.append(c);
        }
        return o;
    }
    return veri;
}

QString utf7Coz(const QByteArray &s)
{
    QString o;
    for (int i = 0; i < s.size(); ++i) {
        const char c = s.at(i);
        if (c != '&') { o.append(QLatin1Char(c)); continue; }
        const int son = s.indexOf('-', i + 1);
        if (son < 0) { o.append(QString::fromLatin1(s.mid(i))); break; }
        if (son == i + 1) { o.append(QLatin1Char('&')); i = son; continue; }
        QByteArray b64 = s.mid(i + 1, son - i - 1);
        b64.replace(',', '/');
        while (b64.size() % 4) b64.append('=');
        const QByteArray u = QByteArray::fromBase64(b64);
        for (int j = 0; j + 1 < u.size(); j += 2) o.append(QChar(ushort((uchar(u.at(j)) << 8) | uchar(u.at(j + 1)))));
        i = son;
    }
    return o;
}

static QString varliklar(QString s)
{
    s.replace(L1("&nbsp;"), L1(" ")).replace(L1("&lt;"), L1("<")).replace(L1("&gt;"), L1(">"))
     .replace(L1("&quot;"), L1("\"")).replace(L1("&#39;"), L1("'")).replace(L1("&zwnj;"), QString());
    QRegExp sayi(L1("&#(x?)([0-9a-fA-F]+);"));
    int p = 0;
    while ((p = sayi.indexIn(s, p)) >= 0) {
        bool ok = false;
        const int v = sayi.cap(2).toInt(&ok, sayi.cap(1).isEmpty() ? 10 : 16);
        const QString r = ok && v > 0 && v < 0x10000 ? QString(QChar(ushort(v))) : QString();
        s.replace(p, sayi.matchedLength(), r);
        p += r.size();
    }
    return s.replace(L1("&amp;"), L1("&"));
}

QString htmldenMetin(const QString &html)
{
    QString s = html;
    QRegExp blok(L1("<(script|style|head|title)\\b.*</\\1\\s*>"), Qt::CaseInsensitive);
    blok.setMinimal(true);
    s.remove(blok);
    QRegExp yarim(L1("<(script|style|head)\\b.*$"), Qt::CaseInsensitive);   // onizlemede yarida kesilmis blok
    s.remove(yarim);
    QRegExp yorum(L1("<!--.*-->"));
    yorum.setMinimal(true);
    s.remove(yorum);
    s.replace(QRegExp(L1("<[^>]*>")), L1(" "));
    s.remove(QRegExp(L1("<[^>]*$")));
    s = varliklar(s);
    QRegExp css(L1("[^{}\\n]*\\{[^}]*\\}"));
    s.replace(css, L1(" "));
    return s.simplified();
}

QByteArray baslikKodla(const QString &s)
{
    bool ascii = true;
    for (int i = 0; i < s.size(); ++i) if (s.at(i).unicode() > 126 || s.at(i).unicode() < 32) { ascii = false; break; }
    if (ascii) return s.toLatin1();
    // her parca en cok ~45 bayt UTF-8 (kodlanmis kelime 75 karakteri gecmesin), karakter sinirinda bolunur
    QByteArray o;
    QByteArray parca;
    for (int i = 0; i < s.size(); ++i) {
        QString ch(s.at(i));
        if (s.at(i).isHighSurrogate() && i + 1 < s.size()) { ch.append(s.at(i + 1)); ++i; }
        const QByteArray u = ch.toUtf8();
        if (parca.size() + u.size() > 45) {
            if (!o.isEmpty()) o += "\r\n ";
            o += "=?UTF-8?B?" + parca.toBase64() + "?=";
            parca.clear();
        }
        parca += u;
    }
    if (!parca.isEmpty()) {
        if (!o.isEmpty()) o += "\r\n ";
        o += "=?UTF-8?B?" + parca.toBase64() + "?=";
    }
    return o;
}

static const char *AYLAR[] = { "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec" };
static const char *GUNLER[] = { "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" };

QDateTime tarihCoz(const QByteArray &ham)
{
    QString s = QString::fromLatin1(ham);
    s.remove(QRegExp(L1("\\([^)]*\\)")));
    s.replace(QLatin1Char(','), QLatin1Char(' '));
    const QStringList p = s.split(QLatin1Char(' '), QString::SkipEmptyParts);
    int gun = 0, ay = 0, yil = 0, ofs = 0;
    QTime saat;
    for (int i = 0; i < p.size(); ++i) {
        const QString t = p.at(i);
        if (t.contains(QLatin1Char(':'))) {
            const QStringList h = t.split(QLatin1Char(':'));
            saat = QTime(h.value(0).toInt(), h.value(1).toInt(), h.value(2).toInt());
            continue;
        }
        if ((t.startsWith(QLatin1Char('+')) || t.startsWith(QLatin1Char('-'))) && t.size() == 5) {
            const int v = t.mid(1).toInt();
            ofs = ((v / 100) * 3600 + (v % 100) * 60) * (t.startsWith(QLatin1Char('-')) ? -1 : 1);
            continue;
        }
        const QString kucuk = t.left(3).toLower();
        bool ayMi = false;
        for (int a = 0; a < 12; ++a) if (kucuk == QLatin1String(AYLAR[a])) { ay = a + 1; ayMi = true; break; }
        if (ayMi) continue;
        bool ok = false;
        const int v = t.toInt(&ok);
        if (!ok) continue;
        if (v > 31 || t.size() == 4) yil = v < 100 ? 2000 + v : v;
        else if (!gun) gun = v;
    }
    if (!gun || !ay || !yil) return QDateTime();
    QDateTime d(QDate(yil, ay, gun), saat.isValid() ? saat : QTime(0, 0), Qt::UTC);
    return d.addSecs(-ofs);
}

QByteArray simdi()
{
    const QDateTime yerel = QDateTime::currentDateTime();
    QDateTime utc = yerel.toUTC();
    utc.setTimeSpec(Qt::LocalTime);
    const int ofs = utc.secsTo(yerel);
    const int dk = qAbs(ofs) / 60;
    QByteArray z = ofs < 0 ? "-" : "+";
    z += QByteArray::number(dk / 60).rightJustified(2, '0') + QByteArray::number(dk % 60).rightJustified(2, '0');
    const QDate g = yerel.date();
    QByteArray ay = AYLAR[g.month() - 1];
    ay[0] = char(toupper(ay.at(0)));
    return QByteArray(GUNLER[g.dayOfWeek() - 1]) + ", " + QByteArray::number(g.day()) + " " + ay + " " + QByteArray::number(g.year()) + " "
         + yerel.time().toString(L1("hh:mm:ss")).toLatin1() + " " + z;
}

}
