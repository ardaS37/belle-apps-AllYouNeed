// BelleRemote PC - hizli ekran yakalama: DXGI Desktop Duplication (Windows 8+). GDI BitBlt 1080p'de ~33 ms, bu ~2-5 ms.
// Ekran degismediyse kare gelmez (WAIT_TIMEOUT) -> o kare hic kodlanmaz. Basarisizsa cagiran GDI'ye doner.
using System;
using System.Drawing;
using System.Runtime.InteropServices;

[StructLayout(LayoutKind.Sequential)]
struct D3dDoku { public uint W, H, Mip, Dizi, Bicim, OrnekSay, OrnekKal, Kullanim, Bag, Cpu, Diger; }
[StructLayout(LayoutKind.Sequential)]
struct D3dHarita { public IntPtr Veri; public uint Satir, Derinlik; }
[StructLayout(LayoutKind.Sequential)]
struct DxgiKareBilgi { public long SonSunum, SonFare; public uint Biriken; public int Birlesik, Korumali; public int Px, Py, Gorunur; public uint MetaBoyut, ImlecBoyut; }
[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
struct DxgiCikisTanim { [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string Ad; public int L, T, R, B; public int Bagli; public int Donme; public IntPtr Monitor; }

[ComImport, Guid("db6f6ddb-ac77-4e88-8253-819df9bbf140"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface ID3D11Device
{
    void a1(); void a2();
    [PreserveSig] int CreateTexture2D([In] ref D3dDoku t, IntPtr ilk, out IntPtr doku);
}

[ComImport, Guid("c0bfa96c-e089-44fb-8eaf-26f8796190da"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface ID3D11DeviceContext
{
    void c1(); void c2(); void c3(); void c4();                                   // ID3D11DeviceChild
    void a01(); void a02(); void a03(); void a04(); void a05(); void a06(); void a07();
    [PreserveSig] int Map(IntPtr kaynak, uint alt, int tur, uint bayrak, out D3dHarita h);
    [PreserveSig] void Unmap(IntPtr kaynak, uint alt);
    void a10(); void a11(); void a12(); void a13(); void a14(); void a15(); void a16(); void a17(); void a18(); void a19(); void a20();
    void a21(); void a22(); void a23(); void a24(); void a25(); void a26(); void a27(); void a28(); void a29(); void a30();
    void a31(); void a32(); void a33(); void a34(); void a35(); void a36(); void a37(); void a38(); void a39(); void a40();
    [PreserveSig] void CopyResource(IntPtr hedef, IntPtr kaynak);
}

[ComImport, Guid("6f15aaf2-d208-4e89-9ab4-489535d34f9c"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface ID3D11Texture2D
{
    void c1(); void c2(); void c3(); void c4(); void r1(); void r2(); void r3();
    [PreserveSig] void GetDesc(out D3dDoku t);
}

[ComImport, Guid("54ec77fa-1377-44e6-8c32-88fd5f44c84c"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IDXGIDevice
{
    void o1(); void o2(); void o3(); void o4();
    [PreserveSig] int GetAdapter(out IDXGIAdapter a);
}

[ComImport, Guid("2411e7e1-12ac-4ccf-bd14-9798e8534dc0"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IDXGIAdapter
{
    void o1(); void o2(); void o3(); void o4();
    [PreserveSig] int EnumOutputs(uint i, out IDXGIOutput1 c);
}

[ComImport, Guid("00cddea8-939b-4b83-a340-a685226666cc"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IDXGIOutput1
{
    void o1(); void o2(); void o3(); void o4();
    [PreserveSig] int GetDesc(out DxgiCikisTanim t);
    void b02(); void b03(); void b04(); void b05(); void b06(); void b07(); void b08(); void b09(); void b10(); void b11(); void b12();
    void d1(); void d2(); void d3();
    [PreserveSig] int DuplicateOutput([MarshalAs(UnmanagedType.IUnknown)] object aygit, out IDXGIOutputDuplication k);
}

[ComImport, Guid("191cfac3-a341-470d-b26e-a864f428319c"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IDXGIOutputDuplication
{
    void o1(); void o2(); void o3(); void o4();
    void GetDesc_();
    [PreserveSig] int AcquireNextFrame(uint ms, out DxgiKareBilgi bilgi, [MarshalAs(UnmanagedType.IUnknown)] out object kaynak);
    void f3(); void f4(); void f5(); void f6(); void f7();
    [PreserveSig] int ReleaseFrame();
}

class EkranKopya : IDisposable
{
    [DllImport("d3d11.dll")]
    static extern int D3D11CreateDevice(IntPtr adaptor, int tur, IntPtr yazilim, uint bayrak, IntPtr seviyeler, uint n, uint sdk, out IntPtr aygit, out int seviye, out IntPtr baglam);

    public const int TAMAM = 0, KAYBOLDU = 1;
    const int BEKLEME_DOLDU = unchecked((int)0x887A0027);

    ID3D11Device aygit; ID3D11DeviceContext baglam;
    object aygitNesne;
    IDXGIOutputDuplication kopya;
    IntPtr hazirlik;                 // CPU'dan okunan (staging) doku
    public readonly Rectangle Sinir; // ekranin masaustu koordinatlari
    public int W, H;
    bool kareVar, haritali;

    EkranKopya(Rectangle sinir) { Sinir = sinir; }

    // Verilen ekran dikdortgenine karsilik gelen cikis icin kopyalayici; olmazsa null
    public static EkranKopya Ac(Rectangle sinir, out string hata)
    {
        hata = null;
        var k = new EkranKopya(sinir);
        try { if (k.Kur(out hata)) return k; }
        catch (Exception ex) { hata = ex.Message; }
        k.Dispose();
        return null;
    }

    bool Kur(out string hata)
    {
        hata = null;
        IntPtr ap, cp; int sev;
        int hr = D3D11CreateDevice(IntPtr.Zero, 1 /* HARDWARE */, IntPtr.Zero, 0x20 /* BGRA_SUPPORT */, IntPtr.Zero, 0, 7, out ap, out sev, out cp);
        if (hr < 0) { hata = "D3D11 0x" + hr.ToString("X8"); return false; }
        aygitNesne = Marshal.GetObjectForIUnknown(ap); Marshal.Release(ap);
        aygit = (ID3D11Device)aygitNesne;
        baglam = (ID3D11DeviceContext)Marshal.GetObjectForIUnknown(cp); Marshal.Release(cp);
        IDXGIAdapter ad;
        if (((IDXGIDevice)aygitNesne).GetAdapter(out ad) < 0) { hata = L.T("adaptor yok"); return false; }
        for (uint i = 0; i < 16; i++)
        {
            IDXGIOutput1 c;
            if (ad.EnumOutputs(i, out c) < 0 || c == null) break;
            DxgiCikisTanim t;
            if (c.GetDesc(out t) >= 0 && t.L == Sinir.Left && t.T == Sinir.Top && t.R == Sinir.Right && t.B == Sinir.Bottom)
            {
                hr = c.DuplicateOutput(aygitNesne, out kopya);
                Marshal.ReleaseComObject(c);
                if (hr < 0) { hata = "DuplicateOutput 0x" + hr.ToString("X8"); return false; }
                W = Sinir.Width; H = Sinir.Height;
                return true;
            }
            Marshal.ReleaseComObject(c);
        }
        hata = L.T("ekran bu ekran kartinda degil");
        return false;
    }

    // Yeni kareyi alir. yeni=false: ekran degismedi (son kare gecerli). KAYBOLDU: yeniden kurulmali.
    public int Al(uint bekleMs, out bool yeni, out string hata)
    {
        yeni = false; hata = null;
        if (haritali) Birak();
        DxgiKareBilgi bi; object kay;
        int hr = kopya.AcquireNextFrame(kareVar ? bekleMs : 500, out bi, out kay);
        if (hr == BEKLEME_DOLDU) return kareVar ? TAMAM : KAYBOLDU;
        if (hr < 0) { hata = "AcquireNextFrame 0x" + hr.ToString("X8"); return KAYBOLDU; }
        try
        {
            if (bi.SonSunum != 0 || !kareVar)
            {
                var doku = (ID3D11Texture2D)kay;
                if (hazirlik == IntPtr.Zero)
                {
                    D3dDoku t; doku.GetDesc(out t);
                    W = (int)t.W; H = (int)t.H;
                    if (t.Bicim != 87 && t.Bicim != 91) { hata = L.T("ekran bicimi BGRA degil (") + t.Bicim + L.T(", HDR?)"); return KAYBOLDU; }
                    t.Mip = 1; t.Dizi = 1; t.OrnekSay = 1; t.OrnekKal = 0;
                    t.Kullanim = 3; t.Bag = 0; t.Cpu = 0x20000; t.Diger = 0;   // STAGING, CPU_ACCESS_READ
                    int h2 = aygit.CreateTexture2D(ref t, IntPtr.Zero, out hazirlik);
                    if (h2 < 0) { hata = "CreateTexture2D 0x" + h2.ToString("X8"); return KAYBOLDU; }
                }
                IntPtr kp = Marshal.GetComInterfaceForObject(doku, typeof(ID3D11Texture2D));
                baglam.CopyResource(hazirlik, kp);
                Marshal.Release(kp);
                kareVar = true; yeni = true;
            }
        }
        finally
        {
            if (kay != null) Marshal.ReleaseComObject(kay);
            kopya.ReleaseFrame();
        }
        return TAMAM;
    }

    // Son karenin BGRA piksellerine erisim (Birak'a kadar gecerli)
    public bool Harita(out IntPtr veri, out int satir)
    {
        veri = IntPtr.Zero; satir = 0;
        if (!kareVar || hazirlik == IntPtr.Zero) return false;
        D3dHarita h;
        if (baglam.Map(hazirlik, 0, 1 /* READ */, 0, out h) < 0) return false;
        haritali = true; veri = h.Veri; satir = (int)h.Satir;
        return true;
    }

    public void Birak() { if (haritali) { baglam.Unmap(hazirlik, 0); haritali = false; } }

    public void Dispose()
    {
        try { Birak(); } catch { }
        try { if (hazirlik != IntPtr.Zero) Marshal.Release(hazirlik); } catch { }
        hazirlik = IntPtr.Zero;
        try { if (kopya != null) Marshal.ReleaseComObject(kopya); } catch { }
        try { if (baglam != null) Marshal.ReleaseComObject(baglam); } catch { }
        try { if (aygitNesne != null) Marshal.ReleaseComObject(aygitNesne); } catch { }
        kopya = null; baglam = null; aygit = null; aygitNesne = null;
    }
}
