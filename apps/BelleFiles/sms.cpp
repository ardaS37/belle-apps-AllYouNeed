#include "sms.h"
#include "dil.h"

#include <QtCore/QFile>
#include <QtCore/QTextStream>
#include <QtCore/QDateTime>
#include <QtCore/QSet>
#include <QtCore/QList>
#include <QtCore/QXmlStreamReader>
#include <QtCore/QCoreApplication>

struct SmsKayit {
    QString adres, ad, govde;
    qint64 zamanMs;
    int tur;          // 1 gelen, 2 gonderilen, 3 taslak, 4 giden
    bool okundu;
    QString klasor;
};

static QString xmlKacis(const QString &s)
{
    QString o;
    o.reserve(s.size() + 16);
    for (int i = 0; i < s.size(); ++i) {
        const QChar c = s.at(i);
        switch (c.unicode()) {
        case '&': o += "&amp;"; break;
        case '<': o += "&lt;"; break;
        case '>': o += "&gt;"; break;
        case '"': o += "&quot;"; break;
        case '\'': o += "&apos;"; break;
        case '\n': o += "&#10;"; break;
        case '\r': o += "&#13;"; break;
        default:
            if (c.unicode() < 0x20 && c.unicode() != '\t') o += QString("&#%1;").arg(c.unicode());
            else o += c;
        }
    }
    return o;
}

static QString anahtar(const QString &adres, qint64 ms, const QString &govde)
{
    QString d;
    for (int i = 0; i < adres.size(); ++i) if (adres.at(i).isDigit()) d += adres.at(i);
    if (d.length() > 9) d = d.right(9);
    if (d.isEmpty()) d = adres.toLower();
    return d + "|" + QString::number(ms / 1000) + "|" + govde.left(40);
}

#ifdef Q_OS_SYMBIAN
#include <msvapi.h>
#include <msvids.h>
#include <msvuids.h>
#include <mtclreg.h>
#include <smut.h>
#include <smuthdr.h>
#include <smsclnt.h>
#include <txtrich.h>
#include <txtfmlyr.h>
#include <gsmupdu.h>

class Gozlemci : public MMsvSessionObserver {
public:
    void HandleSessionEventL(TMsvSessionEvent, TAny *, TAny *, TAny *) { }
};

static QString qs(const TDesC &d) { return QString::fromUtf16(d.Ptr(), d.Length()); }
static TPtrC ds(const QString &s) { return TPtrC(reinterpret_cast<const TUint16 *>(s.utf16()), s.length()); }

static TTime epoch() { return TTime(TDateTime(1970, EJanuary, 0, 0, 0, 0, 0)); }

// Tek mesaji oku
static void tekOkuL(CMsvSession &s, TMsvId id, int klasorTuru, const QString &klasorAdi, QList<SmsKayit> &out,
                    CParaFormatLayer *pf, CCharFormatLayer *cf)
{
    CMsvEntry *e = s.GetEntryL(id);
    CleanupStack::PushL(e);
    const TMsvEntry te = e->Entry();
    SmsKayit k;
    k.tur = klasorTuru;
    k.klasor = klasorAdi;
    k.ad = qs(te.iDetails);
    k.okundu = !te.Unread();
    k.zamanMs = te.iDate.MicroSecondsFrom(epoch()).Int64() / 1000;
    k.govde = qs(te.iDescription);
    k.adres = k.ad;
    if (e->HasStoreL()) {
        CMsvStore *st = e->ReadStoreL();
        CleanupStack::PushL(st);
        CRichText *rt = CRichText::NewL(pf, cf);
        CleanupStack::PushL(rt);
        if (st->HasBodyTextL()) {
            st->RestoreBodyTextL(*rt);
            const TInt n = rt->DocumentLength();
            HBufC *b = HBufC::NewLC(n);
            TPtr p = b->Des();
            rt->Extract(p, 0, n);
            k.govde = qs(*b);
            CleanupStack::PopAndDestroy(b);
        }
        CSmsHeader *h = CSmsHeader::NewL(CSmsPDU::ESmsDeliver, *rt);
        CleanupStack::PushL(h);
        TRAPD(hh, h->RestoreL(*st));
        if (hh == KErrNone) {
            if (h->Type() == CSmsPDU::ESmsDeliver) {
                k.adres = qs(h->FromAddress());
                if (klasorTuru == 0) k.tur = 1;
            } else {
                if (h->Recipients().Count() > 0) k.adres = qs(h->Recipients()[0]->Address());
                if (klasorTuru == 0) k.tur = 2;
            }
        }
        CleanupStack::PopAndDestroy(3, st);   // h, rt, st
    }
    if (k.tur == 0) k.tur = 1;
    CleanupStack::PopAndDestroy(e);
    out << k;
}

static void klasorOkuL(CMsvSession &s, TMsvId klasor, int tur, const QString &ad, QList<SmsKayit> &out,
                       CParaFormatLayer *pf, CCharFormatLayer *cf)
{
    CMsvEntry *fe = s.GetEntryL(klasor);
    CleanupStack::PushL(fe);
    CMsvEntrySelection *sel = fe->ChildrenWithMtmL(KUidMsgTypeSMS);
    CleanupStack::PushL(sel);
    for (TInt i = 0; i < sel->Count(); ++i) {
        TRAP_IGNORE(tekOkuL(s, sel->At(i), tur, ad, out, pf, cf));
        if ((i & 15) == 0) QCoreApplication::processEvents();
    }
    CleanupStack::PopAndDestroy(sel);
    // Alt klasorler (Klasorlerim altindakiler)
    CMsvEntrySelection *alt = fe->ChildrenWithTypeL(KUidMsvFolderEntry);
    CleanupStack::PushL(alt);
    for (TInt i = 0; i < alt->Count(); ++i) {
        CMsvEntry *ae = s.GetEntryL(alt->At(i));
        const QString altAd = ad + "/" + qs(ae->Entry().iDetails);
        delete ae;
        TRAP_IGNORE(klasorOkuL(s, alt->At(i), tur, altAd, out, pf, cf));
    }
    CleanupStack::PopAndDestroy(2, fe);   // alt, fe
}

static void hepsiniOkuL(QList<SmsKayit> &out)
{
    Gozlemci g;
    CMsvSession *s = CMsvSession::OpenSyncL(g);
    CleanupStack::PushL(s);
    CParaFormatLayer *pf = CParaFormatLayer::NewL();
    CleanupStack::PushL(pf);
    CCharFormatLayer *cf = CCharFormatLayer::NewL();
    CleanupStack::PushL(cf);
    klasorOkuL(*s, KMsvGlobalInBoxIndexEntryId, 1, "Gelen", out, pf, cf);
    klasorOkuL(*s, KMsvSentEntryId, 2, Dil::t("Gönderilen"), out, pf, cf);
    klasorOkuL(*s, KMsvDraftEntryId, 3, "Taslaklar", out, pf, cf);
    klasorOkuL(*s, KMsvGlobalOutBoxIndexEntryId, 4, "Giden", out, pf, cf);
    TRAP_IGNORE(klasorOkuL(*s, TMsvId(0x1008) /* Klasorlerim (KMsvMyFoldersEntryIdValue) */, 0, Dil::t("Klasörlerim"), out, pf, cf));
    CleanupStack::PopAndDestroy(3, s);
}

static int sayL()
{
    Gozlemci g;
    CMsvSession *s = CMsvSession::OpenSyncL(g);
    CleanupStack::PushL(s);
    int n = 0;
    const TMsvId kl[4] = { KMsvGlobalInBoxIndexEntryId, KMsvSentEntryId, KMsvDraftEntryId, KMsvGlobalOutBoxIndexEntryId };
    for (int i = 0; i < 4; ++i) {
        CMsvEntry *fe = s->GetEntryL(kl[i]);
        CleanupStack::PushL(fe);
        CMsvEntrySelection *sel = fe->ChildrenWithMtmL(KUidMsgTypeSMS);
        n += sel->Count();
        delete sel;
        CleanupStack::PopAndDestroy(fe);
    }
    CleanupStack::PopAndDestroy(s);
    return n;
}

// Tek mesaji ilgili klasore yaz
static void tekYazL(CMsvSession &s, CSmsClientMtm &mtm, TMsvId servis, const SmsKayit &k)
{
    TMsvId klasor = KMsvGlobalInBoxIndexEntryId;
    if (k.tur == 2) klasor = KMsvSentEntryId;
    else if (k.tur == 3 || k.tur == 4) klasor = KMsvDraftEntryId;     // giden kutusu: gonderilmesin
    mtm.SwitchCurrentEntryL(klasor);
    mtm.CreateMessageL(servis);
    mtm.Body().Reset();
    mtm.Body().InsertL(0, ds(k.govde));
    if (k.tur != 1 && !k.adres.isEmpty()) mtm.AddAddresseeL(ds(k.adres), ds(k.ad != k.adres ? k.ad : QString()));
    mtm.SaveMessageL();
    if (k.tur == 1) {
        // Gelen mesaj: gonderen adresi "deliver" basligiyla yazilir
        CSmsHeader *h = CSmsHeader::NewL(CSmsPDU::ESmsDeliver, mtm.Body());
        CleanupStack::PushL(h);
        h->SetFromAddressL(ds(k.adres));
        CMsvStore *st = mtm.Entry().EditStoreL();
        CleanupStack::PushL(st);
        h->StoreL(*st);
        st->StoreBodyTextL(mtm.Body());
        st->CommitL();
        CleanupStack::PopAndDestroy(2, h);
    }
    TMsvEntry te = mtm.Entry().Entry();
    te.iDate = epoch() + TTimeIntervalMicroSeconds(k.zamanMs * 1000);
    const QString ad = k.ad.isEmpty() ? k.adres : k.ad;
    te.iDetails.Set(ds(ad));
    const QString ozet = k.govde.left(60).replace('\n', ' ');
    te.iDescription.Set(ds(ozet));
    te.SetInPreparation(EFalse);
    te.SetVisible(ETrue);
    te.SetComplete(ETrue);
    te.SetNew(EFalse);
    te.SetUnread(!k.okundu);
    if (k.tur == 1 || k.tur == 2) te.SetReadOnly(ETrue);
    if (k.tur == 2) te.SetSendingState(KMsvSendStateSent);
    mtm.Entry().ChangeL(te);
}

static void geriYukleL(const QList<SmsKayit> &kayitlar, int *eklenen, int *atlanan, int *hatali)
{
    // Var olanlar (cift eklememek icin)
    QList<SmsKayit> mevcut;
    hepsiniOkuL(mevcut);
    QSet<QString> var;
    foreach (const SmsKayit &k, mevcut) var.insert(anahtar(k.adres, k.zamanMs, k.govde));

    Gozlemci g;
    CMsvSession *s = CMsvSession::OpenSyncL(g);
    CleanupStack::PushL(s);
    CClientMtmRegistry *reg = CClientMtmRegistry::NewL(*s);
    CleanupStack::PushL(reg);
    CSmsClientMtm *mtm = static_cast<CSmsClientMtm *>(reg->NewMtmL(KUidMsgTypeSMS));
    CleanupStack::PushL(mtm);
    TMsvId servis = KMsvLocalServiceIndexEntryId;
    TRAP_IGNORE(TSmsUtilities::ServiceIdL(*s, servis));
    int i = 0;
    foreach (const SmsKayit &k, kayitlar) {
        const QString a = anahtar(k.adres, k.zamanMs, k.govde);
        if (var.contains(a)) { ++*atlanan; continue; }
        TRAPD(err, tekYazL(*s, *mtm, servis, k));
        if (err == KErrNone) { ++*eklenen; var.insert(a); } else ++*hatali;
        if ((++i & 7) == 0) QCoreApplication::processEvents();
    }
    CleanupStack::PopAndDestroy(3, s);
}
#endif

// ---------------------------------------------------------------------------

int Sms::say(QString *hata)
{
#ifdef Q_OS_SYMBIAN
    int n = -1;
    TRAPD(err, n = sayL());
    if (err != KErrNone) { if (hata) *hata = QString("Mesajlar okunamadı (hata %1)").arg(err); return -1; }
    return n;
#else
    if (hata) *hata = Dil::t("SMS yalnızca telefonda");
    return -1;
#endif
}

bool Sms::yedekle(const QString &xmlYolu, int *adet, QString *hata)
{
    QList<SmsKayit> l;
#ifdef Q_OS_SYMBIAN
    TRAPD(err, hepsiniOkuL(l));
    if (err != KErrNone && l.isEmpty()) { if (hata) *hata = Dil::t("Mesajlar okunamadı (hata %1)").arg(err); return false; }
#else
    SmsKayit k; k.adres = "+905550000000"; k.ad = "Deneme"; k.govde = Dil::t("Merhaba <deneme> & \"çğışöü\"\nikinci satır");
    k.zamanMs = QDateTime::currentDateTime().toMSecsSinceEpoch(); k.tur = 1; k.okundu = true; k.klasor = "Gelen";
    l << k;
#endif
    QFile f(xmlYolu);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) { if (hata) *hata = Dil::t("Dosya açılamadı: ") + xmlYolu; return false; }
    QTextStream t(&f);
    t.setCodec("UTF-8");
    t << "<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>\n";
    t << "<!-- Belle Files SMS yedegi (Nokia E6). Android 'SMS Backup & Restore' ile de acilir. -->\n";
    t << "<smses count=\"" << l.size() << "\">\n";
    foreach (const SmsKayit &k, l) {
        const QDateTime dt = QDateTime::fromMSecsSinceEpoch(k.zamanMs);
        t << "  <sms protocol=\"0\" address=\"" << xmlKacis(k.adres) << "\" date=\"" << k.zamanMs << "\" type=\"" << k.tur
          << "\" subject=\"null\" body=\"" << xmlKacis(k.govde) << "\" toa=\"null\" sc_toa=\"null\" service_center=\"null\" read=\""
          << (k.okundu ? 1 : 0) << "\" status=\"-1\" locked=\"0\" date_sent=\"0\" readable_date=\"" << dt.toString("dd.MM.yyyy HH:mm:ss")
          << "\" contact_name=\"" << xmlKacis(k.ad.isEmpty() || k.ad == k.adres ? QString("(Unknown)") : k.ad)
          << "\" klasor=\"" << xmlKacis(k.klasor) << "\" />\n";
    }
    t << "</smses>\n";
    t.flush();
    f.close();
    if (adet) *adet = l.size();
    return true;
}

bool Sms::geriYukle(const QString &xmlYolu, int *eklenen, int *atlanan, int *hatali, QString *hata)
{
    *eklenen = *atlanan = *hatali = 0;
    QFile f(xmlYolu);
    if (!f.open(QIODevice::ReadOnly)) { if (hata) *hata = Dil::t("Yedek dosyası açılamadı"); return false; }
    QList<SmsKayit> l;
    QXmlStreamReader r(&f);
    while (!r.atEnd()) {
        r.readNext();
        if (r.isStartElement() && r.name() == "sms") {
            const QXmlStreamAttributes a = r.attributes();
            SmsKayit k;
            k.adres = a.value("address").toString();
            k.govde = a.value("body").toString();
            k.zamanMs = a.value("date").toString().toLongLong();
            k.tur = a.value("type").toString().toInt();
            k.okundu = a.value("read").toString() != "0";
            k.ad = a.value("contact_name").toString();
            if (k.ad == "(Unknown)" || k.ad == "null") k.ad.clear();
            if (k.tur < 1 || k.tur > 6) k.tur = 1;
            if (k.tur > 4) k.tur = 3;
            l << k;
        }
    }
    if (r.hasError() && l.isEmpty()) { if (hata) *hata = Dil::t("Yedek okunamadı: ") + r.errorString(); return false; }
    if (l.isEmpty()) { if (hata) *hata = Dil::t("Yedekte mesaj yok"); return false; }
#ifdef Q_OS_SYMBIAN
    TRAPD(err, geriYukleL(l, eklenen, atlanan, hatali));
    if (err != KErrNone) { if (hata) *hata = Dil::t("Mesaj sunucusu hatası %1").arg(err); return *eklenen > 0; }
    return true;
#else
    *atlanan = l.size();
    if (hata) *hata = Dil::t("Geri yükleme yalnızca telefonda");
    return false;
#endif
}
