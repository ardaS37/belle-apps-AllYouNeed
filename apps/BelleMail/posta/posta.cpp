#include "posta.h"
#include "imap.h"
#include "smtp.h"
#include "mime.h"
#include "dil.h"

#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QSettings>
#include <QtCore/QDateTime>
#include <QtCore/QTextStream>
#include <QtCore/QUrl>
#include <QtCore/QRegExp>
#include <QtCore/QtAlgorithms>
#include <QtGui/QApplication>
#include <QtGui/QClipboard>
#include <QtGui/QDesktopServices>
#include <QtGui/QWidget>
#include <QtGui/QInputContext>
#include <QtNetwork/QNetworkConfigurationManager>
#include <QtNetwork/QNetworkSession>

#define L1(s) QString::fromLatin1(s)

static const int SAYFA = 20;

// ozel klasor + sabit anahtarla karistirma (duz metin gorunmesin diye; gercek sifreleme degildir)
static QByteArray karistir(const QByteArray &b)
{
    static const char a[] = "BelleMail/E6-dogrudan";
    QByteArray o(b);
    for (int i = 0; i < o.size(); ++i) o[i] = char(o.at(i) ^ a[i % (sizeof(a) - 1)]);
    return o;
}

static bool azalan(qint64 a, qint64 b) { return a > b; }
static bool uidAzalan(const QVariant &a, const QVariant &b) { return a.toMap().value(L1("uid")).toLongLong() > b.toMap().value(L1("uid")).toLongLong(); }

Posta::Posta(const QString &ozelKlasor, const QString &gunlukDosyasi, QObject *parent)
    : QObject(parent), m_ozel(ozelKlasor), m_gunluk(gunlukDosyasi), m_imapPort(993), m_smtpPort(465),
      m_imap(new Imap(this)), m_deneme(0), m_smtp(new Smtp(this)), m_smtpIs(0), m_ag(0), m_agHazir(false),
      m_isVar(false), m_beklenen(0), m_sayac(0), m_exists(0), m_uidGecerlilik(0), m_klasorHazir(false),
      m_ekSuruyor(false), m_kontrolDk(5), m_sonUidNext(0), m_okunmamis(0)
{
    QDir().mkpath(m_ozel);
    connect(m_imap, SIGNAL(bitti(int,bool,QString,QVariantList)), this, SLOT(imapBitti(int,bool,QString,QVariantList)));
    connect(m_imap, SIGNAL(ilerleme(qint64,qint64)), this, SLOT(imapIlerleme(qint64,qint64)));
    connect(m_imap, SIGNAL(koptu(QString)), this, SLOT(imapKoptu(QString)));
    connect(m_smtp, SIGNAL(bitti(bool,QString)), this, SLOT(smtpBitti(bool,QString)));
    hesapOku();
    QSettings s(m_ozel + L1("/durum.ini"), QSettings::IniFormat);
    m_kontrolDk = s.value(L1("kontrolDk"), 5).toInt();
    m_sonUidNext = s.value(L1("sonUidNext")).toString().toLongLong();
    connect(&m_kontrol, SIGNAL(timeout()), this, SLOT(kontrolZamani()));
    if (m_kontrolDk > 0) { m_kontrol.setInterval(m_kontrolDk * 60000); m_kontrol.start(); }
#ifdef Q_OS_SYMBIAN
    // Symbian'da ham soket ag baglantisini kendisi acmaz: once ag oturumu
    QNetworkConfigurationManager yon;
    m_ag = new QNetworkSession(yon.defaultConfiguration(), this);
    connect(m_ag, SIGNAL(opened()), this, SLOT(agAcildi()));
    m_ag->open();
    QTimer::singleShot(15000, this, SLOT(agAcildi()));
#else
    m_agHazir = true;
#endif
    kayit(L1("acildi v2.0, hesap=") + (hesapVar() ? L1("var") : L1("yok")));
}

Posta::~Posta()
{
    m_imap->kapat();
}

void Posta::agAcildi()
{
    if (m_agHazir) return;
    m_agHazir = true;
    kayit(L1("ag hazir"));
    siradaki();
    if (hesapVar()) QTimer::singleShot(3000, this, SLOT(kontrolZamani()));
}

void Posta::kayit(const QString &s) const
{
    QFile f(m_gunluk);
    if (!f.open(QIODevice::Append | QIODevice::Text)) return;
    if (f.size() > 100000) { f.close(); f.open(QIODevice::WriteOnly | QIODevice::Text); }
    QTextStream(&f) << QDateTime::currentDateTime().toString(L1("dd.MM hh:mm:ss ")) << s << "\n";
}

QString Posta::gunluk() const
{
    QFile f(m_gunluk);
    if (!f.open(QIODevice::ReadOnly)) return QString();
    const qint64 n = f.size();
    if (n > 6000) f.seek(n - 6000);
    return QString::fromUtf8(f.readAll());
}

// ======================================================================= hesap
void Posta::hesapOku()
{
    QSettings s(m_ozel + L1("/hesap.ini"), QSettings::IniFormat);
    m_imapSunucu = s.value(L1("imap")).toString();
    m_imapPort = s.value(L1("imapPort"), 993).toInt();
    m_smtpSunucu = s.value(L1("smtp")).toString();
    m_smtpPort = s.value(L1("smtpPort"), 465).toInt();
    m_kul = s.value(L1("user")).toString();
    m_ad = s.value(L1("name")).toString();
    m_hazirAyar = s.value(L1("preset")).toString();
    m_parola = QString::fromUtf8(karistir(QByteArray::fromBase64(s.value(L1("p")).toString().toLatin1())));
    m_imap->ayarla(m_imapSunucu, m_imapPort, m_kul, m_parola);
}

void Posta::hesapYaz(const QVariantMap &h)
{
    QSettings s(m_ozel + L1("/hesap.ini"), QSettings::IniFormat);
    s.setValue(L1("imap"), h.value(L1("imap")).toString().trimmed());
    s.setValue(L1("imapPort"), h.value(L1("imapPort"), 993).toInt());
    s.setValue(L1("smtp"), h.value(L1("smtp")).toString().trimmed());
    s.setValue(L1("smtpPort"), h.value(L1("smtpPort"), 465).toInt());
    s.setValue(L1("user"), h.value(L1("user")).toString().trimmed());
    s.setValue(L1("name"), h.value(L1("name")).toString().trimmed());
    s.setValue(L1("preset"), h.value(L1("preset")).toString());
    s.setValue(L1("p"), QString::fromLatin1(karistir(h.value(L1("pass")).toString().toUtf8()).toBase64()));
    s.sync();
}

QVariantMap Posta::hesap() const
{
    QVariantMap m;
    m.insert(L1("imap"), m_imapSunucu);
    m.insert(L1("imapPort"), m_imapPort);
    m.insert(L1("smtp"), m_smtpSunucu);
    m.insert(L1("smtpPort"), m_smtpPort);
    m.insert(L1("user"), m_kul);
    m.insert(L1("name"), m_ad);
    m.insert(L1("preset"), m_hazirAyar);
    m.insert(L1("parolaVar"), !m_parola.isEmpty());
    return m;
}

void Posta::hesapSil()
{
    QFile::remove(m_ozel + L1("/hesap.ini"));
    m_imap->kapat();
    hesapOku();
    m_klasorHazir = false;
    m_klasorler.clear();
    m_ozelKutu.clear();
    m_onizlemeOnbellek.clear();
    m_secili.clear();
    m_sonUidNext = 0;
    QSettings s(m_ozel + L1("/durum.ini"), QSettings::IniFormat);
    s.remove(L1("sonUidNext"));
    kayit(L1("hesap silindi"));
    emit hesapDegisti();
}

void Posta::hesapDene(const QVariantMap &h)
{
    QVariantMap x(h);
    // parola bos birakildiysa kayitli parola (ayni kullanici)
    if (x.value(L1("pass")).toString().isEmpty() && x.value(L1("user")).toString().trimmed() == m_kul) x.insert(L1("pass"), m_parola);
    QString p = x.value(L1("pass")).toString();
    if (x.value(L1("preset")).toString() == L1("gmail")) p.remove(QLatin1Char(' '));   // uygulama sifresi bosluklu yazilabilir
    x.insert(L1("pass"), p);
    if (!x.value(L1("user")).toString().contains(QLatin1Char('@')) || p.isEmpty() || x.value(L1("imap")).toString().trimmed().isEmpty()) {
        emit hesapSonuc(false, Dil::t("E-posta adresi, şifre ve sunucu gerekli."));
        return;
    }
    m_denemeHesap = x;
    if (!m_deneme) {
        m_deneme = new Imap(this);
        connect(m_deneme, SIGNAL(bitti(int,bool,QString,QVariantList)), this, SLOT(denemeBitti(int,bool,QString,QVariantList)));
        connect(m_deneme, SIGNAL(girisHatasi(QString)), this, SLOT(denemeGirisHatasi(QString)));
    }
    m_deneme->ayarla(x.value(L1("imap")).toString(), x.value(L1("imapPort"), 993).toInt(), x.value(L1("user")).toString(), p);
    m_deneme->komut("NOOP");
    kayit(L1("hesap deneniyor: ") + x.value(L1("imap")).toString());
}

void Posta::denemeGirisHatasi(const QString &m)
{
    kayit(L1("giris reddedildi: ") + m);
}

void Posta::denemeBitti(int no, bool ok, const QString &durum, const QVariantList &y)
{
    Q_UNUSED(no); Q_UNUSED(y);
    if (m_denemeHesap.isEmpty()) return;
    const QVariantMap h = m_denemeHesap;
    m_denemeHesap.clear();
    m_deneme->kapat();
    if (!ok) {
        kayit(L1("hesap denemesi basarisiz: ") + durum);
        emit hesapSonuc(false, hataMetni(durum));
        return;
    }
    hesapYaz(h);
    m_imap->kapat();
    hesapOku();
    m_klasorHazir = false;
    m_klasorler.clear();
    m_ozelKutu.clear();
    m_onizlemeOnbellek.clear();
    m_secili.clear();
    m_sonUidNext = 0;
    kayit(L1("hesap kaydedildi: ") + m_imapSunucu);
    emit hesapDegisti();
    emit hesapSonuc(true, QString());
    QTimer::singleShot(1500, this, SLOT(kontrolZamani()));   // yeni posta sayacini baslat
}

QString Posta::hataMetni(const QString &s) const
{
    const QString k = s.toLower();
    if (k.contains(L1("authenticationfailed")) || k.contains(L1("invalid credentials")) || k.contains(L1("authentication failed"))
        || k.contains(L1("login failed")) || k.contains(L1("[auth]")) || k.contains(L1("incorrect")))
        return Dil::t("Giriş reddedildi. Gmail, Yahoo, iCloud ve Yandex için normal şifreniz değil, hesap ayarlarından oluşturduğunuz \"uygulama şifresi\" gerekir.") + L1("\n(") + s + L1(")");
    if (k.contains(L1("webalert")) || k.contains(L1("web login")))
        return Dil::t("Sağlayıcı önce tarayıcıdan giriş yapmanızı istiyor (güvenlik uyarısı).") + L1("\n(") + s + L1(")");
    return s;
}

// ======================================================================= ayarlar
QString Posta::downloadDir() const
{
#if defined(Q_OS_SYMBIAN)
    const QString d = QDir(L1("E:/")).exists() ? L1("E:/Mail") : L1("C:/Data/Mail");
#else
    const QString d = QDir::homePath() + L1("/E6Mail");
#endif
    QDir().mkpath(d);
    return d;
}

void Posta::setKontrolDakika(int dk)
{
    if (dk < 0) dk = 0;
    m_kontrolDk = dk;
    QSettings s(m_ozel + L1("/durum.ini"), QSettings::IniFormat);
    s.setValue(L1("kontrolDk"), dk);
    if (dk > 0) { m_kontrol.setInterval(dk * 60000); m_kontrol.start(); }
    else m_kontrol.stop();
    emit ayarDegisti();
}

bool Posta::openFile(const QString &path) { return QDesktopServices::openUrl(QUrl::fromLocalFile(path)); }
QString Posta::pano() const { return QApplication::clipboard()->text(); }
void Posta::girisiTamamla() const
{
    QWidget *w = QApplication::focusWidget();
    if (w && w->inputContext()) w->inputContext()->reset();
}

// ======================================================================= istekler
int Posta::istek(const QString &tur, const QVariantMap &p)
{
    const int id = ++m_sayac;
    if (!hesapVar()) {
        QMetaObject::invokeMethod(this, "yanit", Qt::QueuedConnection, Q_ARG(int, id), Q_ARG(bool, false), Q_ARG(QVariant, QVariant()),
                                  Q_ARG(QString, Dil::t("Posta hesabı girilmemiş. Menü → Hesap.")));
        return id;
    }
    if (tur == L1("gonder")) {
        if (m_smtp->mesgul()) {
            QMetaObject::invokeMethod(this, "yanit", Qt::QueuedConnection, Q_ARG(int, id), Q_ARG(bool, false), Q_ARG(QVariant, QVariant()),
                                      Q_ARG(QString, Dil::t("Önceki gönderim sürüyor.")));
            return id;
        }
        Smtp::Posta ps;
        ps.kimden = m_kul;
        ps.kimdenAd = m_ad;
        ps.konu = p.value(L1("subject")).toString().trimmed();
        ps.metin = p.value(L1("body")).toString();
        ps.yanitlanan = p.value(L1("ref")).toString();
        const QStringList kime = p.value(L1("to")).toString().split(QRegExp(L1("[,;]")), QString::SkipEmptyParts);
        for (int i = 0; i < kime.size(); ++i) if (!kime.at(i).trimmed().isEmpty()) ps.kime.append(kime.at(i).trimmed());
        const QStringList cc = p.value(L1("cc")).toString().split(QRegExp(L1("[,;]")), QString::SkipEmptyParts);
        for (int i = 0; i < cc.size(); ++i) if (!cc.at(i).trimmed().isEmpty()) ps.bilgi.append(cc.at(i).trimmed());
        m_smtpIs = id;
        kayit(L1("gonderiliyor: %1 alici").arg(ps.kime.size() + ps.bilgi.size()));
        m_smtp->gonder(m_smtpSunucu, m_smtpPort, m_kul, m_parola, ps);
        return id;
    }
    Is is;
    is.id = id;
    is.p = p;
    if (tur == L1("liste")) is.tur = IsListe;
    else if (tur == L1("mesaj")) is.tur = IsMesaj;
    else if (tur == L1("islem")) is.tur = IsIslem;
    else if (tur == L1("klasorler")) is.tur = IsKlasorler;
    else {
        QMetaObject::invokeMethod(this, "yanit", Qt::QueuedConnection, Q_ARG(int, id), Q_ARG(bool, false), Q_ARG(QVariant, QVariant()), Q_ARG(QString, L1("?")));
        return id;
    }
    // ayni turden eski liste istegi kuyrukta bekliyorsa artik gereksiz
    if (is.tur == IsListe)
        for (int i = m_kuyruk.size() - 1; i >= 0; --i)
            if (m_kuyruk.at(i).tur == IsListe) { emit yanit(m_kuyruk.at(i).id, false, QVariant(), L1("iptal")); m_kuyruk.removeAt(i); }
    kuyrugaEkle(is);
    return id;
}

bool Posta::downloadAttachment(const QString &folder, int uid, const QString &part, const QString &name)
{
    if (m_ekSuruyor || !hesapVar()) return false;
    Is is;
    is.tur = IsEk;
    is.p.insert(L1("f"), folder);
    is.p.insert(L1("uid"), uid);
    is.p.insert(L1("part"), part);
    QString n = name;
    n.replace(QRegExp(L1("[\\\\/:*?\"<>|]")), L1("_"));
    if (n.trimmed().isEmpty()) n = L1("ek");
    m_ekAd = n;
    m_ekSuruyor = true;
    emit busyChanged();
    kuyrugaEkle(is);
    return true;
}

void Posta::cancel()
{
    if (!m_ekSuruyor) return;
    if (m_isVar && m_is.tur == IsEk) {
        m_imap->kapat();     // buyuk ek yarida: baglantiyi kes (sonraki istek yeniden baglanir)
        m_secili.clear();
        m_beklenen = 0;
        m_ekSuruyor = false;
        emit busyChanged();
        emit downloadFinished(false, Dil::t("İptal edildi"), QString());
        m_isVar = false;
        siradaki();
        return;
    }
    for (int i = m_kuyruk.size() - 1; i >= 0; --i) if (m_kuyruk.at(i).tur == IsEk) m_kuyruk.removeAt(i);
    m_ekSuruyor = false;
    emit busyChanged();
    emit downloadFinished(false, Dil::t("İptal edildi"), QString());
}

void Posta::simdiKontrol() { kontrolZamani(); }

void Posta::kontrolZamani()
{
    if (!hesapVar() || !m_agHazir) return;
    if (m_isVar || !m_kuyruk.isEmpty()) {   // kullanici isleri once: biraz sonra
        QTimer::singleShot(30000, this, SLOT(kontrolZamani()));
        return;
    }
    Is is;
    is.tur = IsKontrol;
    kuyrugaEkle(is);
}

void Posta::kuyrugaEkle(const Is &is)
{
    m_kuyruk.append(is);
    siradaki();
}

void Posta::siradaki()
{
    if (m_isVar || m_kuyruk.isEmpty() || !m_agHazir) return;
    m_is = m_kuyruk.takeFirst();
    m_isVar = true;
    m_is.adim = 0;
    adim(QVariantList());
}

void Posta::komut(const QByteArray &k)
{
    m_beklenen = m_imap->komut(k);
}

void Posta::bitir(bool ok, const QVariant &veri, const QString &hata)
{
    const Is is = m_is;
    m_isVar = false;
    m_beklenen = 0;
    if (is.tur == IsEk) {
        m_ekSuruyor = false;
        emit busyChanged();
        if (ok) emit downloadFinished(true, Dil::t("İndirildi"), veri.toString());
        else emit downloadFinished(false, hata, QString());
    } else if (is.tur == IsKontrol) {
        if (!ok) kayit(L1("denetim hatasi: ") + hata);
    } else {
        if (!ok) kayit(L1("hata (is %1): ").arg(is.tur) + hata);
        emit yanit(is.id, ok, veri, hata);
    }
    siradaki();
}

void Posta::imapIlerleme(qint64 alinan, qint64 toplam)
{
    if (m_isVar && m_is.tur == IsEk) emit progress(double(alinan) * 0.74, double(toplam) * 0.74);   // base64 -> yaklasik gercek boyut
}

void Posta::imapKoptu(const QString &neden)
{
    m_secili.clear();
    kayit(L1("baglanti koptu: ") + neden);
}

void Posta::imapBitti(int no, bool ok, const QString &durum, const QVariantList &y)
{
    if (!m_isVar || no != m_beklenen) return;
    m_beklenen = 0;
    if (!ok) {
        if (m_is.adim == 101) m_secili.clear();
        bitir(false, QVariant(), hataMetni(durum.isEmpty() ? Dil::t("Sunucu hatası") : durum));
        return;
    }
    adim(y);
}

void Posta::smtpBitti(bool ok, const QString &mesaj)
{
    const int id = m_smtpIs;
    m_smtpIs = 0;
    kayit(ok ? L1("gonderildi") : L1("gonderilemedi: ") + mesaj);
    QVariantMap m;
    m.insert(L1("ok"), ok);
    emit yanit(id, ok, m, ok ? QString() : hataMetni(mesaj));
}

// ======================================================================= klasorler
static QString duzKucuk(const QString &s) { return s.toLower(); }

void Posta::klasorleriAl(const QVariantList &y)
{
    m_klasorler.clear();
    m_ozelKutu.clear();
    for (int i = 0; i < y.size(); ++i) {
        const QVariantList t = y.at(i).toList();
        if (t.value(0).toByteArray().toUpper() != "LIST" || t.size() < 4) continue;
        Klasor k;
        k.ham = t.at(3).toByteArray();
        k.ad = Mime::utf7Coz(k.ham);
        k.secilemez = false;
        const QVariantList bayrak = t.at(1).toList();
        for (int j = 0; j < bayrak.size(); ++j) {
            const QByteArray b = bayrak.at(j).toByteArray().toLower();
            if (b == "\\noselect" || b == "\\nonexistent") k.secilemez = true;
            else if (b == "\\sent") k.ozel = L1("sent");
            else if (b == "\\trash") k.ozel = L1("trash");
            else if (b == "\\junk") k.ozel = L1("spam");
            else if (b == "\\all" || b == "\\archive") k.ozel = L1("all");
            else if (b == "\\drafts") k.ozel = L1("drafts");
            else if (b == "\\flagged") k.ozel = L1("starred");
        }
        if (k.ham.toUpper() == "INBOX") { k.ham = "INBOX"; k.ozel = L1("inbox"); }
        if (!k.ozel.isEmpty() && !m_ozelKutu.contains(k.ozel)) m_ozelKutu.insert(k.ozel, k.ham);
        m_klasorler.append(k);
    }
    // ozel isaret gondermeyen sunucular: ada gore tahmin
    static const char *TAHMIN[][2] = {
        { "sent", "sent" }, { "sent", "gönderil" }, { "sent", "giden" },
        { "trash", "trash" }, { "trash", "deleted" }, { "trash", "çöp" }, { "trash", "silinen" },
        { "spam", "spam" }, { "spam", "junk" }, { "spam", "istenmeyen" }, { "spam", "önemsiz" },
        { "all", "all mail" }, { "all", "tüm postalar" }, { "all", "archive" }, { "all", "arşiv" },
        { "drafts", "draft" }, { "drafts", "taslak" } };
    for (unsigned t = 0; t < sizeof(TAHMIN) / sizeof(TAHMIN[0]); ++t) {
        const QString ozel = L1(TAHMIN[t][0]);
        if (m_ozelKutu.contains(ozel)) continue;
        const QString anahtar = QString::fromUtf8(TAHMIN[t][1]);
        for (int i = 0; i < m_klasorler.size(); ++i) {
            if (m_klasorler.at(i).secilemez || !m_klasorler.at(i).ozel.isEmpty()) continue;
            if (duzKucuk(m_klasorler.at(i).ad).contains(anahtar)) {
                m_klasorler[i].ozel = ozel;
                m_ozelKutu.insert(ozel, m_klasorler.at(i).ham);
                break;
            }
        }
    }
    m_klasorHazir = true;
    kayit(L1("klasorler: %1 (gonderilen=%2 cop=%3 spam=%4 tum=%5)").arg(m_klasorler.size())
          .arg(QString::fromLatin1(m_ozelKutu.value(L1("sent")))).arg(QString::fromLatin1(m_ozelKutu.value(L1("trash"))))
          .arg(QString::fromLatin1(m_ozelKutu.value(L1("spam")))).arg(QString::fromLatin1(m_ozelKutu.value(L1("all")))));
}

QVariantList Posta::klasorListesi() const
{
    static const char *SIRA[] = { "inbox", "starred", "sent", "drafts", "all", "spam", "trash" };
    QVariantList bas, son;
    for (unsigned s = 0; s < sizeof(SIRA) / sizeof(SIRA[0]); ++s) {
        for (int i = 0; i < m_klasorler.size(); ++i) {
            const Klasor &k = m_klasorler.at(i);
            if (k.secilemez || k.ozel != L1(SIRA[s])) continue;
            QVariantMap m;
            m.insert(L1("k"), k.ozel);
            m.insert(L1("ad"), k.ad);
            m.insert(L1("ozel"), k.ozel);
            bas.append(m);
            break;
        }
    }
    QStringList adlar;
    QHash<QString, QVariantMap> harita;
    for (int i = 0; i < m_klasorler.size(); ++i) {
        const Klasor &k = m_klasorler.at(i);
        if (k.secilemez || !k.ozel.isEmpty()) continue;
        QString ad = k.ad;
        if (ad.startsWith(L1("[Gmail]/"))) ad = ad.mid(8);
        else if (ad.startsWith(L1("[Google Mail]/"))) ad = ad.mid(14);
        QVariantMap m;
        m.insert(L1("k"), L1("k:") + QString::fromLatin1(k.ham));
        m.insert(L1("ad"), ad);
        m.insert(L1("ozel"), QString());
        adlar.append(ad.toLower() + L1("\x01") + QString::number(i));
        harita.insert(adlar.last(), m);
    }
    qSort(adlar);
    for (int i = 0; i < adlar.size(); ++i) son.append(harita.value(adlar.at(i)));
    return bas + son;
}

QByteArray Posta::kutuYolu(const QString &f, bool *sanal, QString *hata) const
{
    if (sanal) *sanal = false;
    if (f.isEmpty() || f == L1("inbox")) return "INBOX";
    if (f.startsWith(L1("k:"))) return f.mid(2).toLatin1();
    if (f == L1("starred") && !m_ozelKutu.contains(f)) { if (sanal) *sanal = true; return "INBOX"; }
    if (m_ozelKutu.contains(f)) return m_ozelKutu.value(f);
    if (hata) *hata = Dil::t("Bu hesapta bu klasör yok.");
    return QByteArray();
}

// ======================================================================= ayristirma
QVariantMap Posta::fetchHaritasi(const QVariant &yanit, qint64 *seq)
{
    QVariantMap m;
    const QVariantList t = yanit.toList();
    if (t.size() < 3 || t.at(1).toByteArray().toUpper() != "FETCH") return m;
    if (seq) *seq = t.at(0).toByteArray().toLongLong();
    const QVariantList l = t.at(2).toList();
    for (int i = 0; i + 1 < l.size(); i += 2) m.insert(QString::fromLatin1(l.at(i).toByteArray().toUpper()), l.at(i + 1));
    return m;
}

QVariant Posta::govdeBul(const QVariantMap &m, const QByteArray &parca)
{
    const QString on = L1("BODY[") + QString::fromLatin1(parca) + L1("]");
    QMapIterator<QString, QVariant> it(m);
    while (it.hasNext()) { it.next(); if (it.key().startsWith(on)) return it.value(); }
    return QVariant();
}

static QString adresMetni(const QVariantList &a)
{
    // (ad adl kutu sunucu)
    const QByteArray kutu = a.value(2).toByteArray(), sunucu = a.value(3).toByteArray();
    if (kutu.isEmpty() || sunucu.isEmpty()) return QString();
    return QString::fromUtf8(kutu) + L1("@") + QString::fromUtf8(sunucu);
}

QVariantMap Posta::zarf(const QVariant &env) const
{
    const QVariantList e = env.toList();
    QVariantMap z;
    const QDateTime d = Mime::tarihCoz(e.value(0).toByteArray());
    z.insert(L1("ts"), d.isValid() ? double(d.toTime_t()) * 1000.0 : 0.0);
    const QString konu = Mime::baslikCoz(e.value(1).toByteArray());
    z.insert(L1("subject"), konu.isEmpty() ? Dil::t("(konu yok)") : konu);
    const char *alanlar[] = { "", "", "from", "sender", "replyTo", "to", "cc", "bcc" };
    for (int f = 2; f <= 7; ++f) {
        const QVariantList liste = e.value(f).toList();
        QVariantList adlar, adresler;
        for (int i = 0; i < liste.size(); ++i) {
            const QVariantList a = liste.at(i).toList();
            const QString adr = adresMetni(a);
            if (adr.isEmpty()) continue;
            adlar.append(Mime::baslikCoz(a.value(0).toByteArray()));
            adresler.append(adr);
        }
        z.insert(L1(alanlar[f]) + L1("Ad"), adlar);
        z.insert(L1(alanlar[f]) + L1("Adr"), adresler);
    }
    z.insert(L1("inReplyTo"), QString::fromLatin1(e.value(8).toByteArray()));
    z.insert(L1("messageId"), QString::fromLatin1(e.value(9).toByteArray()));
    return z;
}

// BODYSTRUCTURE -> duz parca listesi {no, tur, charset, kodlama, ad, boyut, ek}
void Posta::yapiGez(const QVariant &v, const QString &onek, QVariantList &parcalar)
{
    const QVariantList l = v.toList();
    if (l.isEmpty()) return;
    if (l.at(0).type() == QVariant::List) {          // multipart
        int n = 0;
        for (int i = 0; i < l.size() && l.at(i).type() == QVariant::List; ++i) {
            ++n;
            yapiGez(l.at(i), onek.isEmpty() ? QString::number(n) : onek + L1(".") + QString::number(n), parcalar);
        }
        return;
    }
    const QByteArray tur = l.value(0).toByteArray().toLower(), alt = l.value(1).toByteArray().toLower();
    QByteArray charset, ad, adYildiz;
    const QVariantList par = l.value(2).toList();
    for (int i = 0; i + 1 < par.size(); i += 2) {
        const QByteArray k = par.at(i).toByteArray().toLower();
        if (k == "charset") charset = par.at(i + 1).toByteArray();
        else if (k == "name") ad = par.at(i + 1).toByteArray();
        else if (k == "name*") adYildiz = par.at(i + 1).toByteArray();
    }
    const int dIdx = tur == "text" ? 9 : (tur == "message" && alt == "rfc822" ? 11 : 8);
    const QVariantList disp = l.value(dIdx).toList();
    const QByteArray yerlesim = disp.value(0).toByteArray().toLower();
    const QVariantList dpar = disp.value(1).toList();
    for (int i = 0; i + 1 < dpar.size(); i += 2) {
        const QByteArray k = dpar.at(i).toByteArray().toLower();
        if (k == "filename") ad = dpar.at(i + 1).toByteArray();
        else if (k == "filename*") adYildiz = dpar.at(i + 1).toByteArray();
    }
    QString adMetni = !adYildiz.isEmpty() ? Mime::rfc2231Coz(adYildiz) : Mime::baslikCoz(ad);
    const bool ek = yerlesim == "attachment" || (!adMetni.isEmpty() && tur != "text") || (tur == "message" && alt == "rfc822");
    if (tur == "message" && adMetni.isEmpty()) adMetni = L1("ileti.eml");
    QVariantMap p;
    p.insert(L1("no"), onek.isEmpty() ? L1("1") : onek);
    p.insert(L1("tur"), QString::fromLatin1(tur + "/" + alt));
    p.insert(L1("charset"), QString::fromLatin1(charset));
    p.insert(L1("kodlama"), QString::fromLatin1(l.value(5).toByteArray().toLower()));
    p.insert(L1("boyut"), l.value(6).toByteArray().toLongLong());
    p.insert(L1("ad"), adMetni);
    p.insert(L1("ek"), ek);
    parcalar.append(p);
}

static void parcaSec(const QVariantList &parcalar, QVariantMap *metin, QVariantMap *html, QVariantList *ekler)
{
    for (int i = 0; i < parcalar.size(); ++i) {
        const QVariantMap p = parcalar.at(i).toMap();
        if (p.value(L1("ek")).toBool()) { if (ekler) ekler->append(p); continue; }
        const QString t = p.value(L1("tur")).toString();
        if (t == L1("text/plain") && metin && metin->isEmpty()) *metin = p;
        else if (t == L1("text/html") && html && html->isEmpty()) *html = p;
    }
}

QVariantMap Posta::ozet(const QVariantMap &f, bool giden) const
{
    const QVariantMap z = zarf(f.value(L1("ENVELOPE")));
    QVariantMap m;
    m.insert(L1("uid"), f.value(L1("UID")).toByteArray().toLongLong());
    const QString on = giden ? L1("to") : L1("from");
    const QString ad = z.value(on + L1("Ad")).toList().value(0).toString();
    const QString adr = z.value(on + L1("Adr")).toList().value(0).toString();
    m.insert(L1("from"), ad.isEmpty() ? adr : ad);
    m.insert(L1("fromAddr"), adr);
    m.insert(L1("subject"), z.value(L1("subject")));
    m.insert(L1("ts"), z.value(L1("ts")));
    bool okundu = false, yildiz = false;
    const QVariantList b = f.value(L1("FLAGS")).toList();
    for (int i = 0; i < b.size(); ++i) {
        const QByteArray x = b.at(i).toByteArray().toLower();
        if (x == "\\seen") okundu = true;
        else if (x == "\\flagged") yildiz = true;
    }
    m.insert(L1("unread"), !okundu);
    m.insert(L1("starred"), yildiz);
    QVariantList parcalar, ekler;
    yapiGez(f.value(L1("BODYSTRUCTURE")), QString(), parcalar);
    parcaSec(parcalar, 0, 0, &ekler);
    m.insert(L1("att"), !ekler.isEmpty());
    m.insert(L1("snippet"), QString());
    return m;
}

// ======================================================================= is adimlari
bool Posta::sec(const QByteArray &kutu, int sonraki, bool zorla)
{
    if (!zorla && m_secili == kutu && !kutu.isEmpty()) { m_is.adim = sonraki; return false; }
    m_is.kutu = kutu;
    m_is.sonraki = sonraki;
    m_is.adim = 101;
    komut("SELECT " + Imap::dize(kutu));
    return true;
}

void Posta::sil()
{
    m_is.adim = 10;
    komut("UID STORE " + QByteArray::number(m_is.uid) + " +FLAGS.SILENT (\\Deleted)");
}

void Posta::tasi(const QByteArray &hedef)
{
    if (m_imap->yetenek("MOVE")) {
        m_is.adim = 12;
        komut("UID MOVE " + QByteArray::number(m_is.uid) + " " + Imap::dize(hedef));
    } else {
        m_is.adim = 13;
        komut("UID COPY " + QByteArray::number(m_is.uid) + " " + Imap::dize(hedef));
    }
}

void Posta::adim(const QVariantList &y)
{
    for (;;) {
        // ---- ortak adimlar ----
        if (m_is.adim == 100) {                 // LIST sonucu
            klasorleriAl(y);
            m_is.adim = 0;
            continue;
        }
        if (m_is.adim == 101) {                 // SELECT sonucu
            m_exists = 0;
            for (int i = 0; i < y.size(); ++i) {
                const QVariantList t = y.at(i).toList();
                if (t.value(1).toByteArray().toUpper() == "EXISTS") m_exists = t.value(0).toByteArray().toLongLong();
                const QByteArray b = t.value(1).toByteArray();
                if (b.startsWith("[UIDVALIDITY")) m_uidGecerlilik = b.mid(13).replace("]", "").trimmed().toLongLong();
            }
            m_secili = m_is.kutu;
            m_is.adim = m_is.sonraki;
            continue;
        }
        if (m_is.adim == 10) {                  // \Deleted isaretlendi -> sil
            m_is.adim = 11;
            if (m_imap->yetenek("UIDPLUS")) komut("UID EXPUNGE " + QByteArray::number(m_is.uid));
            else komut("EXPUNGE");
            return;
        }
        if (m_is.adim == 11 || m_is.adim == 12) { QVariantMap m; m.insert(L1("ok"), true); bitir(true, m); return; }
        if (m_is.adim == 13) { sil(); return; }   // COPY tamam -> kaynaktan sil

        const bool klasorGerek = m_is.tur != IsKontrol;
        if (m_is.adim == 0 && klasorGerek && !m_klasorHazir) {
            m_is.adim = 100;
            komut("LIST \"\" \"*\"");
            return;
        }

        switch (m_is.tur) {
        // ================================================================== liste
        case IsListe: {
            if (m_is.adim == 0) {
                QString hata;
                bool sanal = false;
                const QByteArray kutu = kutuYolu(m_is.p.value(L1("f")).toString(), &sanal, &hata);
                if (kutu.isEmpty()) { bitir(false, QVariant(), hata); return; }
                m_is.sanalYildiz = sanal;
                if (sec(kutu, 1, true)) return;
                continue;
            }
            if (m_is.adim == 1) {
                const QString q = m_is.p.value(L1("q")).toString().trimmed();
                if (!q.isEmpty() || m_is.sanalYildiz) {
                    QByteArray k = "UID SEARCH ";
                    bool utf = false;
                    for (int i = 0; i < q.size(); ++i) if (q.at(i).unicode() > 127) utf = true;
                    if (!q.isEmpty() && m_imap->yetenek("X-GM-EXT-1")) {
                        k += "X-GM-RAW " + Imap::dize(q.toUtf8());
                        if (m_is.sanalYildiz) k += " FLAGGED";
                    } else {
                        if (utf) k += "CHARSET UTF-8 ";
                        if (m_is.sanalYildiz) k += "FLAGGED ";
                        if (!q.isEmpty()) { const QByteArray d = Imap::dize(q.toUtf8()); k += "OR OR SUBJECT " + d + " FROM " + d + " BODY " + d; }
                    }
                    m_is.adim = 2;
                    komut(k.trimmed());
                    return;
                }
                const int s = m_is.p.value(L1("s")).toInt();
                const qint64 hi = m_exists - qint64(s) * SAYFA, lo = qMax(qint64(1), hi - SAYFA + 1);
                m_is.toplam = int(m_exists);
                m_is.daha = lo > 1;
                if (hi < 1) { m_is.adim = 4; continue; }
                m_is.adim = 3;
                komut("FETCH " + QByteArray::number(lo) + ":" + QByteArray::number(hi) + " (UID FLAGS ENVELOPE BODYSTRUCTURE)");
                return;
            }
            if (m_is.adim == 2) {
                QList<qint64> uidler;
                for (int i = 0; i < y.size(); ++i) {
                    const QVariantList t = y.at(i).toList();
                    if (t.value(0).toByteArray().toUpper() != "SEARCH") continue;
                    for (int j = 1; j < t.size(); ++j) uidler.append(t.at(j).toByteArray().toLongLong());
                }
                qSort(uidler.begin(), uidler.end(), azalan);
                const int s = m_is.p.value(L1("s")).toInt();
                m_is.toplam = uidler.size();
                m_is.daha = uidler.size() > (s + 1) * SAYFA;
                const QList<qint64> sayfa = uidler.mid(s * SAYFA, SAYFA);
                if (sayfa.isEmpty()) { m_is.adim = 4; continue; }
                QByteArray k;
                for (int i = 0; i < sayfa.size(); ++i) { if (i) k += ","; k += QByteArray::number(sayfa.at(i)); }
                m_is.adim = 3;
                komut("UID FETCH " + k + " (UID FLAGS ENVELOPE BODYSTRUCTURE)");
                return;
            }
            if (m_is.adim == 3) {
                const QString f = m_is.p.value(L1("f")).toString();
                const bool giden = f == L1("sent") || f == L1("drafts");
                QHash<QByteArray, QList<qint64> > gruplar;
                QList<QByteArray> sira;
                for (int i = 0; i < y.size(); ++i) {
                    const QVariantMap fm = fetchHaritasi(y.at(i), 0);
                    if (!fm.contains(L1("ENVELOPE"))) continue;
                    QVariantMap o = ozet(fm, giden);
                    const qint64 uid = o.value(L1("uid")).toLongLong();
                    const QString anahtar = QString::fromLatin1(m_secili) + L1(":") + QString::number(m_uidGecerlilik) + L1(":") + QString::number(uid);
                    if (m_onizlemeOnbellek.contains(anahtar)) o.insert(L1("snippet"), m_onizlemeOnbellek.value(anahtar));
                    else {
                        QVariantList parcalar;
                        yapiGez(fm.value(L1("BODYSTRUCTURE")), QString(), parcalar);
                        QVariantMap metin, html;
                        parcaSec(parcalar, &metin, &html, 0);
                        const QVariantMap secilen = metin.isEmpty() ? html : metin;
                        if (!secilen.isEmpty()) {
                            const QByteArray no = secilen.value(L1("no")).toString().toLatin1();
                            const QByteArray g = no + (metin.isEmpty() ? "|h" : "|t");
                            if (!gruplar.contains(g)) sira.append(g);
                            gruplar[g].append(uid);
                            QVariantMap bilgi;
                            bilgi.insert(L1("kodlama"), secilen.value(L1("kodlama")));
                            bilgi.insert(L1("charset"), secilen.value(L1("charset")));
                            m_parcaBilgi.insert(QString::number(uid) + L1(":") + QString::fromLatin1(no), bilgi);
                        }
                    }
                    m_is.ogeler.append(o);
                }
                qSort(m_is.ogeler.begin(), m_is.ogeler.end(), uidAzalan);
                m_is.onizleme.clear();
                for (int i = 0; i < sira.size(); ++i) m_is.onizleme.append(qMakePair(sira.at(i), gruplar.value(sira.at(i))));
                m_is.adim = 4;
                continue;
            }
            if (m_is.adim == 4) {
                if (!m_is.onizleme.isEmpty()) {
                    const QPair<QByteArray, QList<qint64> > g = m_is.onizleme.first();
                    const QByteArray no = g.first.left(g.first.indexOf('|'));
                    const bool html = g.first.endsWith("|h");
                    QByteArray k;
                    for (int i = 0; i < g.second.size(); ++i) { if (i) k += ","; k += QByteArray::number(g.second.at(i)); }
                    m_is.adim = 5;
                    komut("UID FETCH " + k + " (BODY.PEEK[" + no + "]<0." + (html ? "6000" : "1500") + ">)");
                    return;
                }
                m_is.adim = 6;
                komut("STATUS INBOX (UNSEEN)");
                return;
            }
            if (m_is.adim == 5) {
                const QPair<QByteArray, QList<qint64> > g = m_is.onizleme.takeFirst();
                const QByteArray no = g.first.left(g.first.indexOf('|'));
                const bool html = g.first.endsWith("|h");
                for (int i = 0; i < y.size(); ++i) {
                    const QVariantMap fm = fetchHaritasi(y.at(i), 0);
                    const qint64 uid = fm.value(L1("UID")).toByteArray().toLongLong();
                    if (!uid) continue;
                    const QVariantMap bilgi = m_parcaBilgi.value(QString::number(uid) + L1(":") + QString::fromLatin1(no));
                    const QByteArray ham = Mime::aktarimCoz(govdeBul(fm, no).toByteArray(), bilgi.value(L1("kodlama")).toString().toLatin1());
                    QString metin = Mime::metne(ham, bilgi.value(L1("charset")).toString().toLatin1());
                    metin = html ? Mime::htmldenMetin(metin) : metin.simplified();
                    metin.remove(QRegExp(L1("\\[image:[^\\]]*\\]")));
                    metin = metin.simplified().left(140);
                    const QString anahtar = QString::fromLatin1(m_secili) + L1(":") + QString::number(m_uidGecerlilik) + L1(":") + QString::number(uid);
                    m_onizlemeOnbellek.insert(anahtar, metin);
                    for (int j = 0; j < m_is.ogeler.size(); ++j) {
                        QVariantMap o = m_is.ogeler.at(j).toMap();
                        if (o.value(L1("uid")).toLongLong() == uid) { o.insert(L1("snippet"), metin); m_is.ogeler[j] = o; break; }
                    }
                }
                if (m_onizlemeOnbellek.size() > 2000) m_onizlemeOnbellek.clear();
                m_is.adim = 4;
                continue;
            }
            if (m_is.adim == 6) {
                for (int i = 0; i < y.size(); ++i) {
                    const QVariantList t = y.at(i).toList();
                    if (t.value(0).toByteArray().toUpper() != "STATUS") continue;
                    const QVariantList d = t.value(2).toList();
                    for (int j = 0; j + 1 < d.size(); j += 2)
                        if (d.at(j).toByteArray().toUpper() == "UNSEEN") {
                            const int u = d.at(j + 1).toByteArray().toInt();
                            if (u != m_okunmamis) { m_okunmamis = u; emit okunmamisDegisti(); }
                        }
                }
                QVariantMap r;
                r.insert(L1("user"), m_kul);
                r.insert(L1("folder"), m_is.p.value(L1("f")));
                r.insert(L1("total"), m_is.toplam);
                r.insert(L1("more"), m_is.daha);
                r.insert(L1("unseen"), m_okunmamis);
                r.insert(L1("items"), m_is.ogeler);
                bitir(true, r);
                return;
            }
            break;
        }
        // ================================================================== tek posta
        case IsMesaj: {
            if (m_is.adim == 0) {
                QString hata;
                const QByteArray kutu = kutuYolu(m_is.p.value(L1("f")).toString(), 0, &hata);
                if (kutu.isEmpty()) { bitir(false, QVariant(), hata); return; }
                m_is.uid = m_is.p.value(L1("uid")).toLongLong();
                if (sec(kutu, 1, false)) return;
                continue;
            }
            if (m_is.adim == 1) {
                m_is.adim = 2;
                komut("UID FETCH " + QByteArray::number(m_is.uid) + " (UID FLAGS ENVELOPE BODYSTRUCTURE)");
                return;
            }
            if (m_is.adim == 2) {
                QVariantMap fm;
                for (int i = 0; i < y.size(); ++i) {
                    const QVariantMap x = fetchHaritasi(y.at(i), 0);
                    if (x.value(L1("UID")).toByteArray().toLongLong() == m_is.uid && x.contains(L1("ENVELOPE"))) { fm = x; break; }
                }
                if (fm.isEmpty()) { bitir(false, QVariant(), Dil::t("Posta bulunamadı (silinmiş ya da taşınmış olabilir).")); return; }
                const QString f = m_is.p.value(L1("f")).toString();
                const QVariantMap o = ozet(fm, false);
                const QVariantMap z = zarf(fm.value(L1("ENVELOPE")));
                QVariantList parcalar, ekler;
                yapiGez(fm.value(L1("BODYSTRUCTURE")), QString(), parcalar);
                QVariantMap metin, html;
                parcaSec(parcalar, &metin, &html, &ekler);
                QVariantMap v;
                v.insert(L1("uid"), m_is.uid);
                v.insert(L1("folder"), f);
                v.insert(L1("subject"), z.value(L1("subject")));
                v.insert(L1("from"), o.value(L1("from")));
                v.insert(L1("fromAddr"), o.value(L1("fromAddr")));
                v.insert(L1("ts"), z.value(L1("ts")));
                v.insert(L1("starred"), o.value(L1("starred")));
                v.insert(L1("wasUnread"), o.value(L1("unread")));
                const char *alan[] = { "to", "cc", "replyTo", "from" };
                for (int a = 0; a < 4; ++a) {
                    v.insert(L1(alan[a]) + L1("Ad"), z.value(L1(alan[a]) + L1("Ad")));
                    v.insert(L1(alan[a]) + L1("Adr"), z.value(L1(alan[a]) + L1("Adr")));
                }
                v.insert(L1("messageId"), z.value(L1("messageId")));
                QVariantList ekListe;
                for (int i = 0; i < ekler.size(); ++i) {
                    const QVariantMap e = ekler.at(i).toMap();
                    QVariantMap x;
                    x.insert(L1("part"), e.value(L1("no")));
                    x.insert(L1("name"), e.value(L1("ad")).toString().isEmpty() ? L1("ek") : e.value(L1("ad")));
                    // base64 ile gelen boyut ~%37 fazla
                    const qint64 b = e.value(L1("boyut")).toLongLong();
                    x.insert(L1("size"), double(e.value(L1("kodlama")).toString() == L1("base64") ? b * 3 / 4 : b));
                    x.insert(L1("type"), e.value(L1("tur")));
                    ekListe.append(x);
                    QVariantMap bilgi;
                    bilgi.insert(L1("kodlama"), e.value(L1("kodlama")));
                    bilgi.insert(L1("charset"), e.value(L1("charset")));
                    m_parcaBilgi.insert(QString::number(m_is.uid) + L1(":") + e.value(L1("no")).toString(), bilgi);
                }
                v.insert(L1("att"), ekListe);
                v.insert(L1("html"), QString());
                v.insert(L1("text"), QString());
                m_is.veri = v;
                m_is.okunmamisti = o.value(L1("unread")).toBool();
                m_is.veri.insert(L1("_metin"), metin);
                m_is.veri.insert(L1("_html"), html);
                QByteArray k;
                if (!html.isEmpty()) k += "BODY.PEEK[" + html.value(L1("no")).toString().toLatin1() + "]<0.600000>";
                if (!metin.isEmpty()) { if (!k.isEmpty()) k += " "; k += "BODY.PEEK[" + metin.value(L1("no")).toString().toLatin1() + "]<0." + (html.isEmpty() ? "300000" : "60000") + ">"; }
                if (k.isEmpty()) { m_is.adim = 4; continue; }
                m_is.adim = 3;
                komut("UID FETCH " + QByteArray::number(m_is.uid) + " (" + k + ")");
                return;
            }
            if (m_is.adim == 3) {
                QVariantMap fm;
                for (int i = 0; i < y.size(); ++i) {
                    const QVariantMap x = fetchHaritasi(y.at(i), 0);
                    if (x.value(L1("UID")).toByteArray().toLongLong() == m_is.uid || !x.isEmpty()) { fm = x; if (x.value(L1("UID")).toByteArray().toLongLong() == m_is.uid) break; }
                }
                const char *tur[] = { "_html", "_metin" };
                const char *hedef[] = { "html", "text" };
                for (int t = 0; t < 2; ++t) {
                    const QVariantMap p = m_is.veri.value(L1(tur[t])).toMap();
                    if (p.isEmpty()) continue;
                    const QByteArray no = p.value(L1("no")).toString().toLatin1();
                    const QByteArray ham = Mime::aktarimCoz(govdeBul(fm, no).toByteArray(), p.value(L1("kodlama")).toString().toLatin1());
                    m_is.veri.insert(L1(hedef[t]), Mime::metne(ham, p.value(L1("charset")).toString().toLatin1()));
                }
                m_is.adim = 4;
                continue;
            }
            if (m_is.adim == 4) {
                m_is.veri.remove(L1("_html"));
                m_is.veri.remove(L1("_metin"));
                if (m_is.okunmamisti && m_is.p.value(L1("okundu"), true).toBool()) {
                    m_is.adim = 5;
                    komut("UID STORE " + QByteArray::number(m_is.uid) + " +FLAGS.SILENT (\\Seen)");
                    return;
                }
                bitir(true, m_is.veri);
                return;
            }
            if (m_is.adim == 5) {
                if (m_secili == "INBOX" && m_okunmamis > 0) { --m_okunmamis; emit okunmamisDegisti(); }
                bitir(true, m_is.veri);
                return;
            }
            break;
        }
        // ================================================================== islemler
        case IsIslem: {
            const QString f = m_is.p.value(L1("f")).toString();
            const QString a = m_is.p.value(L1("a")).toString();
            if (m_is.adim == 0) {
                QString hata;
                bool sanal = false;
                const QByteArray kutu = kutuYolu(f, &sanal, &hata);
                if (kutu.isEmpty()) { bitir(false, QVariant(), hata); return; }
                m_is.uid = m_is.p.value(L1("uid")).toLongLong();
                if (sec(kutu, 1, false)) return;
                continue;
            }
            if (m_is.adim == 1) {
                const QByteArray u = QByteArray::number(m_is.uid);
                if (a == L1("read") || a == L1("unread") || a == L1("star") || a == L1("unstar")) {
                    const QByteArray b = (a == L1("read") || a == L1("unread")) ? "\\Seen" : "\\Flagged";
                    const QByteArray isaret = (a == L1("read") || a == L1("star")) ? "+" : "-";
                    m_is.adim = 12;
                    komut("UID STORE " + u + " " + isaret + "FLAGS.SILENT (" + b + ")");
                    return;
                }
                if (a == L1("archive")) {
                    const QByteArray hedef = m_ozelKutu.value(L1("all"));
                    if (hedef.isEmpty() || hedef == m_secili) { bitir(false, QVariant(), Dil::t("Bu hesapta arşiv klasörü yok.")); return; }
                    tasi(hedef);
                    return;
                }
                if (a == L1("trash")) {
                    const QByteArray cop = m_ozelKutu.value(L1("trash"));
                    if (cop.isEmpty() || cop == m_secili) { sil(); return; }
                    tasi(cop);
                    return;
                }
                if (a == L1("notspam")) { tasi("INBOX"); return; }
                bitir(false, QVariant(), Dil::t("Geçersiz işlem"));
                return;
            }
            break;
        }
        // ================================================================== klasor listesi
        case IsKlasorler: {
            QVariantMap r;
            r.insert(L1("items"), klasorListesi());
            bitir(true, r);
            return;
        }
        // ================================================================== ek indirme
        case IsEk: {
            const QByteArray no = m_is.p.value(L1("part")).toString().toLatin1();
            if (m_is.adim == 0) {
                QString hata;
                const QByteArray kutu = kutuYolu(m_is.p.value(L1("f")).toString(), 0, &hata);
                if (kutu.isEmpty()) { bitir(false, QVariant(), hata); return; }
                m_is.uid = m_is.p.value(L1("uid")).toLongLong();
                if (sec(kutu, 1, false)) return;
                continue;
            }
            if (m_is.adim == 1) {
                m_is.adim = 2;
                komut("UID FETCH " + QByteArray::number(m_is.uid) + " (BODY.PEEK[" + no + "])");
                return;
            }
            if (m_is.adim == 2) {
                QByteArray veri;
                for (int i = 0; i < y.size(); ++i) {
                    const QVariantMap fm = fetchHaritasi(y.at(i), 0);
                    const QVariant g = govdeBul(fm, no);
                    if (g.isValid()) { veri = g.toByteArray(); break; }
                }
                const QVariantMap bilgi = m_parcaBilgi.value(QString::number(m_is.uid) + L1(":") + QString::fromLatin1(no));
                veri = Mime::aktarimCoz(veri, bilgi.value(L1("kodlama")).toString().toLatin1());
                QString yol = downloadDir() + L1("/") + m_ekAd;
                const QFileInfo fi(yol);
                for (int n = 2; QFile::exists(yol) && n < 100; ++n)
                    yol = fi.absolutePath() + L1("/") + fi.completeBaseName() + L1(" (") + QString::number(n) + L1(")") + (fi.suffix().isEmpty() ? QString() : L1(".") + fi.suffix());
                QFile dosya(yol);
                if (!dosya.open(QIODevice::WriteOnly) || dosya.write(veri) != veri.size()) { bitir(false, QVariant(), Dil::t("Telefona yazılamadı")); return; }
                dosya.close();
                kayit(L1("ek indirildi: %1 bayt").arg(veri.size()));
                bitir(true, yol);
                return;
            }
            break;
        }
        // ================================================================== yeni posta denetimi
        case IsKontrol: {
            if (m_is.adim == 0) {
                m_is.adim = 1;
                komut("STATUS INBOX (UIDNEXT UNSEEN)");
                return;
            }
            if (m_is.adim == 1) {
                qint64 sonraki = 0;
                int okunmamis = -1;
                for (int i = 0; i < y.size(); ++i) {
                    const QVariantList t = y.at(i).toList();
                    if (t.value(0).toByteArray().toUpper() != "STATUS") continue;
                    const QVariantList d = t.value(2).toList();
                    for (int j = 0; j + 1 < d.size(); j += 2) {
                        const QByteArray k = d.at(j).toByteArray().toUpper();
                        if (k == "UIDNEXT") sonraki = d.at(j + 1).toByteArray().toLongLong();
                        else if (k == "UNSEEN") okunmamis = d.at(j + 1).toByteArray().toInt();
                    }
                }
                if (okunmamis >= 0 && okunmamis != m_okunmamis) { m_okunmamis = okunmamis; emit okunmamisDegisti(); }
                if (sonraki <= 0) { bitir(true, QVariant()); return; }
                if (m_sonUidNext <= 0 || sonraki < m_sonUidNext) {   // ilk calisma ya da kutu sifirlandi: bildirim yok
                    m_sonUidNext = sonraki;
                    QSettings s(m_ozel + L1("/durum.ini"), QSettings::IniFormat);
                    s.setValue(L1("sonUidNext"), QString::number(sonraki));
                    bitir(true, QVariant());
                    return;
                }
                if (sonraki == m_sonUidNext) { bitir(true, QVariant()); return; }
                m_is.toplam = int(sonraki);
                m_is.uid = sonraki;
                if (sec("INBOX", 2, false)) return;
                continue;
            }
            if (m_is.adim == 2) {
                m_is.adim = 3;
                komut("UID SEARCH UID " + QByteArray::number(m_sonUidNext) + ":* UNSEEN");
                return;
            }
            if (m_is.adim == 3) {
                QList<qint64> uidler;
                for (int i = 0; i < y.size(); ++i) {
                    const QVariantList t = y.at(i).toList();
                    if (t.value(0).toByteArray().toUpper() != "SEARCH") continue;
                    for (int j = 1; j < t.size(); ++j) { const qint64 u = t.at(j).toByteArray().toLongLong(); if (u >= m_sonUidNext) uidler.append(u); }
                }
                m_sonUidNext = m_is.uid;
                QSettings s(m_ozel + L1("/durum.ini"), QSettings::IniFormat);
                s.setValue(L1("sonUidNext"), QString::number(m_sonUidNext));
                if (uidler.isEmpty()) { bitir(true, QVariant()); return; }
                qSort(uidler.begin(), uidler.end(), azalan);
                m_is.uidler = uidler;
                m_is.adim = 4;
                komut("UID FETCH " + QByteArray::number(uidler.first()) + " (UID ENVELOPE)");
                return;
            }
            if (m_is.adim == 4) {
                QString kimden, konu;
                for (int i = 0; i < y.size(); ++i) {
                    const QVariantMap fm = fetchHaritasi(y.at(i), 0);
                    if (!fm.contains(L1("ENVELOPE"))) continue;
                    const QVariantMap z = zarf(fm.value(L1("ENVELOPE")));
                    kimden = z.value(L1("fromAd")).toList().value(0).toString();
                    if (kimden.isEmpty()) kimden = z.value(L1("fromAdr")).toList().value(0).toString();
                    konu = z.value(L1("subject")).toString();
                }
                kayit(L1("yeni posta: %1").arg(m_is.uidler.size()));
                emit yeniPosta(m_is.uidler.size(), kimden, konu);
                bitir(true, QVariant());
                return;
            }
            break;
        }
        }
        // beklenmeyen adim
        bitir(false, QVariant(), L1("ic hata (adim %1)").arg(m_is.adim));
        return;
    }
}
