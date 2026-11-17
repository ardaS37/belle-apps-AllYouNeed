// BelleMiddleKeyServis: telefon acilisinda baslayan, Qt'siz, gorunmez kisayol servisi.
// Yalnizca kisayol atanmis tuslari yakalar; zamanlayici yalnizca bir tusa basilirken calisir.
// Ayar uygulamasi (BelleMiddleKey.exe) pencere olaylariyla yonetir: KBmkYenile/Duraklat/Surdur/Cikis.
// Durum: C:\Data\BelleMiddleKey\durum.txt  ("calisiyor <tus sayisi> <yakalama hatasi>")

#include <e32base.h>
#include <w32std.h>
#include <f32file.h>
#include <apgwgnam.h>
#include "motor.h"
#include "eylem.h"

_LIT(KDurum, "C:\\Data\\BelleMiddleKey\\durum.txt");
static const TInt KDuraklatmaUs = 10 * 60 * 1000000;   // uygulama cokerse 10 dk sonra kendiliginden surdur
static const TInt KGecisUs = 300000;                   // eslesmeyen basisi sisteme geri verdikten sonra yeniden yakala

class CServis : public CActive, public MMotorDinleyici
{
public:
    static CServis *NewLC();
    ~CServis();
    TBool Tek() const { return iTek; }
    // MMotorDinleyici
    void Tetiklendi(const TKisayol &aK) { Eylem::Calistir(iWs, aK, iM->iTitresim); }
    void Eslesmedi(TInt aScan, TUint aCode, TInt aTetik, TInt aSayi);
private:
    CServis() : CActive(EPriorityStandard), iTek(ETrue) {}
    void ConstructL();
    void RunL();
    void DoCancel() { iWs.EventReadyCancel(); }
    void Bekle() { iWs.EventReady(&iStatus); SetActive(); }
    void DurumYaz(const TDesC8 &aS);
    void Yakala();
    static TInt SurdurCb(TAny *aP);
    static TInt GecisCb(TAny *aP);

    RWsSession iWs;
    RWindowGroup iWg;
    CMotor *iM;
    CPeriodic *iSurdurZ;
    CPeriodic *iGecisZ;
    TBool iTek;
    TBool iDuraklatildi;
};

CServis *CServis::NewLC()
{
    CServis *s = new (ELeave) CServis;
    CleanupStack::PushL(s);
    s->ConstructL();
    return s;
}

void CServis::ConstructL()
{
    User::LeaveIfError(iWs.Connect());
    // zaten calisiyorsa ikinci kopya hemen cikar
    TInt wg = 0;
    CApaWindowGroupName::FindByAppUid(TUid::Uid(KBmkServisUid), iWs, wg);
    if (wg > 0) { iTek = EFalse; return; }

    iWg = RWindowGroup(iWs);
    User::LeaveIfError(iWg.Construct((TUint32)this, EFalse));
    iWg.SetOrdinalPosition(-1, -1000);   // hep arkada, odak almaz
    iWg.EnableReceiptOfFocus(EFalse);
    iWg.AutoForeground(EFalse);
    CApaWindowGroupName *ad = CApaWindowGroupName::NewLC(iWs);
    ad->SetHidden(ETrue);
    ad->SetSystem(ETrue);
    ad->SetAppUid(TUid::Uid(KBmkServisUid));
    ad->SetCaptionL(_L("BelleMiddleKey"));
    ad->SetWindowGroupName(iWg);
    CleanupStack::PopAndDestroy(ad);

    iSurdurZ = CPeriodic::NewL(EPriorityStandard);
    iGecisZ = CPeriodic::NewL(EPriorityStandard);
    iM = CMotor::NewL(iWs, iWg, *this);
    TRAP_IGNORE(iM->YukleL());
    Yakala();
    CActiveScheduler::Add(this);
    Bekle();
}

CServis::~CServis()
{
    Cancel();
    delete iM;
    delete iSurdurZ;
    delete iGecisZ;
    if (iTek) iWg.Close();
    iWs.Close();
}

void CServis::Yakala()
{
    iM->Yakala();
    TBuf8<64> s;
    s.Format(_L8("calisiyor %d %d\r\n"), iM->YakalananTus(), iM->YakalamaHatasi());
    DurumYaz(s);
}

void CServis::DurumYaz(const TDesC8 &aS)
{
    RFs fs;
    if (fs.Connect() != KErrNone) return;
    fs.MkDirAll(KDurum);
    RFile f;
    if (f.Replace(fs, KDurum, EFileWrite) == KErrNone) { f.Write(aS); f.Close(); }
    fs.Close();
}

void CServis::RunL()
{
    if (iStatus.Int() < 0) { Bekle(); return; }
    TWsEvent e;
    iWs.GetEvent(e);
    const TInt t = e.Type();
    if (t == KBmkCikis) {
        iM->Birak();
        DurumYaz(_L8("durdu\r\n"));
        CActiveScheduler::Stop();
        return;
    }
    if (t == KBmkYenile) {
        iM->Birak();
        TRAP_IGNORE(iM->YukleL());
        if (!iDuraklatildi) Yakala();
    } else if (t == KBmkDuraklat) {
        iM->Birak();
        iDuraklatildi = ETrue;
        iSurdurZ->Cancel();
        iSurdurZ->Start(KDuraklatmaUs, KDuraklatmaUs, TCallBack(SurdurCb, this));
        DurumYaz(_L8("duraklatildi\r\n"));
    } else if (t == KBmkSurdur) {
        iSurdurZ->Cancel();
        iDuraklatildi = EFalse;
        Yakala();
    } else {
        TRAP_IGNORE(iM->OlayL(e));
    }
    Bekle();
}

TInt CServis::SurdurCb(TAny *aP)
{
    CServis *s = static_cast<CServis *>(aP);
    s->iSurdurZ->Cancel();
    s->iDuraklatildi = EFalse;
    s->Yakala();
    return 0;
}

// Atanmamis bir basis (or. yalnizca "2 kez" atanmis tusa tek basis): tusu birakip basisi sisteme geri ver
void CServis::Eslesmedi(TInt aScan, TUint /*aCode*/, TInt aTetik, TInt aSayi)
{
    if (aTetik == ETetikUzun) return;
    iM->Birak();
    for (TInt i = 0; i < aSayi; ++i) {
        TRawEvent ev;
        ev.Set(TRawEvent::EKeyDown, aScan);
        iWs.SimulateRawEvent(ev);
        ev.Set(TRawEvent::EKeyUp, aScan);
        iWs.SimulateRawEvent(ev);
    }
    iWs.Flush();
    iGecisZ->Cancel();
    iGecisZ->Start(KGecisUs, KGecisUs, TCallBack(GecisCb, this));
}

TInt CServis::GecisCb(TAny *aP)
{
    CServis *s = static_cast<CServis *>(aP);
    s->iGecisZ->Cancel();
    if (!s->iDuraklatildi) s->iM->Yakala();
    return 0;
}

static void CalistirL()
{
    CActiveScheduler *as = new (ELeave) CActiveScheduler;
    CleanupStack::PushL(as);
    CActiveScheduler::Install(as);
    CServis *s = CServis::NewLC();
    if (s->Tek()) CActiveScheduler::Start();
    CleanupStack::PopAndDestroy(2);   // s, as
}

GLDEF_C TInt E32Main()
{
    CTrapCleanup *temizlik = CTrapCleanup::New();
    if (!temizlik) return KErrNoMemory;
    TRAPD(err, CalistirL());
    delete temizlik;
    return err;
}
