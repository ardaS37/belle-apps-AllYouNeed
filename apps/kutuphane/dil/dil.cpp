#include "dil.h"

#include <QtCore/QCoreApplication>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QDir>
#include <QtCore/QLocale>
#include <QtCore/QSettings>
#include <QtCore/QTextStream>

Dil *Dil::s_tek = 0;

static QString kacisCoz(const QString &s)
{
    if (!s.contains('\\')) return s;
    QString o;
    o.reserve(s.size());
    for (int i = 0; i < s.size(); i++) {
        if (s.at(i) == '\\' && i + 1 < s.size()) {
            const QChar c = s.at(++i);
            if (c == 'n') o += '\n';
            else if (c == 't') o += '\t';
            else o += c;
        } else o += s.at(i);
    }
    return o;
}

bool SozlukCevirmen::yukle(const QString &dosya)
{
    QFile f(dosya);
    if (!f.open(QIODevice::ReadOnly)) return false;
    QTextStream ts(&f);
    ts.setCodec("UTF-8");
    while (!ts.atEnd()) {
        const QString satir = ts.readLine();
        if (satir.isEmpty() || satir.startsWith('#')) continue;
        const int sekme = satir.indexOf('\t');
        if (sekme <= 0) continue;
        const QString en = satir.mid(sekme + 1);
        if (en.isEmpty()) continue;
        m_s.insert(kacisCoz(satir.left(sekme)), kacisCoz(en));
    }
    return !m_s.isEmpty();
}

// QML qsTr metni UTF-8 olarak gonderir; baglam (dosya adi) kullanilmaz: ayni metin her yerde ayni cevrilir
QString SozlukCevirmen::translate(const char *, const char *sourceText, const char *) const
{
    if (!sourceText || !*sourceText) return QString();
    return m_s.value(QString::fromUtf8(sourceText));
}

Dil::Dil(QObject *parent) : QObject(parent), m_kod("tr"), m_secim("auto"), m_cev(0) {}

QString Dil::ayarDosyasi()
{
#if defined(Q_OS_SYMBIAN)
    return QString("C:/Data/E6/dil.ini");
#else
    return QDir::homePath() + "/E6/dil.ini";
#endif
}

QString Dil::otomatikKod()
{
    return QLocale::system().language() == QLocale::Turkish ? QString("tr") : QString("en");
}

Dil *Dil::kur(QCoreApplication *app, const QString &sozluk)
{
    if (s_tek) return s_tek;
    Dil *d = new Dil(app);
    s_tek = d;
    QSettings s(ayarDosyasi(), QSettings::IniFormat);
    d->m_secim = s.value("dil", "auto").toString();
    if (d->m_secim != "tr" && d->m_secim != "en") d->m_secim = "auto";
    d->m_kod = d->m_secim == "auto" ? otomatikKod() : d->m_secim;
    if (d->m_kod == "en") {
        d->m_cev = new SozlukCevirmen(d);
        if (d->m_cev->yukle(sozluk)) app->installTranslator(d->m_cev);
        else { delete d->m_cev; d->m_cev = 0; }
    }
    return d;
}

QString Dil::t(const QString &tr)
{
    if (s_tek && s_tek->m_cev) {
        const QString e = s_tek->m_cev->bul(tr);
        if (!e.isEmpty()) return e;
    }
    return tr;
}

QString Dil::t(const char *utf8)
{
    return t(QString::fromUtf8(utf8));
}

bool Dil::yenidenBaslat() const
{
    const QString hedef = m_secim == "auto" ? otomatikKod() : m_secim;
    return hedef != m_kod;
}

void Dil::sec(const QString &secim)
{
    const QString v = (secim == "tr" || secim == "en") ? secim : QString("auto");
    if (v == m_secim) return;
    QDir().mkpath(QFileInfo(ayarDosyasi()).absolutePath());
    QSettings s(ayarDosyasi(), QSettings::IniFormat);
    s.setValue("dil", v);
    s.sync();
    m_secim = v;
    emit degisti();
}
