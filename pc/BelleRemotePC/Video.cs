// BelleRemote PC - H.264 kodlama (Windows Media Foundation, Windows'un kendi kodlayicisi; ek dosya gerekmez).
// Web paneli (WebCodecs) icin: JPEG yerine video akisi -> ayni internette cok daha az veri, daha yuksek fps.
// Nokia uygulamasi bunu istemez (el sikismada codec=h264 yok) ve JPEG almaya devam eder.
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

[ComImport, Guid("44ae0fa8-ea31-4109-8d2e-4cae4997c555"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMFMediaType
{
    void a01(); void a02(); void a03(); void a04(); void a05(); void a06(); void a07(); void a08(); void a09(); void a10();
    void a11(); void a12(); void a13(); void a14(); void a15(); void a16(); void a17(); void a18();
    [PreserveSig] int SetUINT32([In] ref Guid k, uint v);
    [PreserveSig] int SetUINT64([In] ref Guid k, ulong v);
    void a21();
    [PreserveSig] int SetGUID([In] ref Guid k, [In] ref Guid v);
}

[ComImport, Guid("045FA593-8799-42b8-BC8D-8968C6453507"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMFMediaBuffer
{
    [PreserveSig] int Lock(out IntPtr p, out uint max, out uint cur);
    [PreserveSig] int Unlock();
    [PreserveSig] int GetCurrentLength(out uint n);
    [PreserveSig] int SetCurrentLength(uint n);
    [PreserveSig] int GetMaxLength(out uint n);
}

[ComImport, Guid("c40a00f2-b93a-4d80-ae8c-5a1c634f58e4"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMFSample
{
    void a01(); void a02(); void a03(); void a04(); void a05(); void a06(); void a07(); void a08(); void a09(); void a10();
    void a11(); void a12(); void a13(); void a14(); void a15(); void a16(); void a17(); void a18(); void a19(); void a20();
    void a21(); void a22(); void a23(); void a24(); void a25(); void a26(); void a27(); void a28(); void a29(); void a30();
    [PreserveSig] int GetSampleFlags(out uint f);
    [PreserveSig] int SetSampleFlags(uint f);
    [PreserveSig] int GetSampleTime(out long t);
    [PreserveSig] int SetSampleTime(long t);
    [PreserveSig] int GetSampleDuration(out long t);
    [PreserveSig] int SetSampleDuration(long t);
    [PreserveSig] int GetBufferCount(out uint n);
    [PreserveSig] int GetBufferByIndex(uint i, out IMFMediaBuffer b);
    [PreserveSig] int ConvertToContiguousBuffer(out IMFMediaBuffer b);
    [PreserveSig] int AddBuffer(IMFMediaBuffer b);
    [PreserveSig] int RemoveBufferByIndex(uint i);
    [PreserveSig] int RemoveAllBuffers();
}

[StructLayout(LayoutKind.Sequential)]
struct MftCikisBilgi { public uint Bayrak; public uint Boyut; public uint Hiza; }

[StructLayout(LayoutKind.Sequential)]
struct MftCikisTampon { public uint Akis; public IntPtr Ornek; public uint Durum; public IntPtr Olaylar; }

[ComImport, Guid("bf94c121-5b05-4e6f-8000-ba598961414d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMFTransform
{
    void a01(); void a02(); void a03(); void a04();
    [PreserveSig] int GetOutputStreamInfo(uint id, out MftCikisBilgi bilgi);
    void a06(); void a07(); void a08(); void a09(); void a10(); void a11(); void a12();
    [PreserveSig] int SetInputType(uint id, IMFMediaType t, uint bayrak);
    [PreserveSig] int SetOutputType(uint id, IMFMediaType t, uint bayrak);
    void a15(); void a16(); void a17(); void a18(); void a19(); void a20();
    [PreserveSig] int ProcessMessage(uint mesaj, IntPtr p);
    [PreserveSig] int ProcessInput(uint id, IMFSample s, uint bayrak);
    [PreserveSig] int ProcessOutput(uint bayrak, uint n, [In, Out, MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 1)] MftCikisTampon[] t, out uint durum);
}

[ComImport, Guid("901db4c7-31ce-41a2-85dc-8fa0bf41b8da"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface ICodecAPI
{
    void a01(); void a02(); void a03(); void a04(); void a05(); void a06();
    [PreserveSig] int SetValue([In] ref Guid api, [In, MarshalAs(UnmanagedType.Struct)] ref object deger);
}

class H264Kodlayici : IDisposable
{
    [DllImport("mfplat.dll")] static extern int MFStartup(uint ver, uint flags);
    [DllImport("mfplat.dll")] static extern int MFCreateMediaType(out IMFMediaType t);
    [DllImport("mfplat.dll")] static extern int MFCreateSample(out IMFSample s);
    [DllImport("mfplat.dll")] static extern int MFCreateMemoryBuffer(uint n, out IMFMediaBuffer b);

    static Guid MT_MAJOR = new Guid("48eba18e-f8c9-4687-bf11-0a74c9f96a8f");
    static Guid MT_SUBTYPE = new Guid("f7e34c9a-42e8-4714-b74b-cb29d72c35e5");
    static Guid MT_FRAME_SIZE = new Guid("1652c33d-d6b2-4012-b834-72030849a37d");
    static Guid MT_FRAME_RATE = new Guid("c459a2e8-3d2c-4e44-b132-fee5156c7bb0");
    static Guid MT_BITRATE = new Guid("20332624-fb0d-4d9e-bd0d-cbf6786c102e");
    static Guid MT_INTERLACE = new Guid("e2724bb8-e676-4806-b4b2-a8d6efb44ccd");
    static Guid MT_PAR = new Guid("c6376a1e-8d0a-4027-be45-6d9a0ad39bb6");
    static Guid MT_PROFILE = new Guid("ad76a80b-2d5c-4e0b-b375-64e520137036");
    static Guid VIDEO = new Guid("73646976-0000-0010-8000-00AA00389B71");
    static Guid H264 = new Guid("34363248-0000-0010-8000-00AA00389B71");
    static Guid NV12 = new Guid("3231564E-0000-0010-8000-00AA00389B71");
    static Guid API_DUSUK_GECIKME = new Guid("9c27891a-ed7a-40e1-88e8-b22727a024ee");
    static Guid API_HIZ_KIPI = new Guid("1c0608e9-370c-4710-8a58-cb6181c42423");
    static Guid API_KALITE = new Guid("fcbf57a3-7ea5-4b0c-9644-69b40c39c391");
    static Guid API_GOP = new Guid("95f31b26-95a4-41aa-9303-246a7fc6eef1");
    static Guid API_ANAHTAR = new Guid("398c1b98-8353-475a-9ef2-8f265d260345");
    static Guid API_ORT_HIZ = new Guid("f7222374-2144-4815-b550-a37f8e12ee52");
    static Guid MS_H264_KODLAYICI = new Guid("6CA50344-051A-4DED-9779-A43305165E35");

    const int NEED_MORE_INPUT = unchecked((int)0xC00D6D72);
    static bool basladi;

    public readonly int W, H, Fps, Kalite;
    IMFTransform mft;
    ICodecAPI api;
    IMFSample cikisOrnek; IMFMediaBuffer cikisTampon;
    bool kendiOrnegi;
    uint cikisBoyut;
    long zaman;
    public string Bilgi = "";

    static void D(int hr, string ne) { if (hr < 0) throw new Exception(ne + " 0x" + hr.ToString("X8")); }

    public H264Kodlayici(int w, int h, int fps, int kalite)
    {
        W = w; H = h; Fps = Math.Max(1, fps); Kalite = kalite;
        if (!basladi) { D(MFStartup(0x00020070, 0), "MFStartup"); basladi = true; }
        mft = (IMFTransform)Activator.CreateInstance(Type.GetTypeFromCLSID(MS_H264_KODLAYICI));
        api = mft as ICodecAPI;
        // Ekran icerigi: dusuk gecikme, kaliteye gore degisken hiz (duragan ekran az veri), 4 sn'de bir anahtar kare
        int kbps = Kbps();
        Ayar(API_DUSUK_GECIKME, true);
        bool kaliteKipi = Ayar(API_HIZ_KIPI, 3u) && Ayar(API_KALITE, (uint)Math.Max(30, Math.Min(95, kalite)));
        if (!kaliteKipi) { Ayar(API_HIZ_KIPI, 1u); Ayar(API_ORT_HIZ, (uint)(kbps * 1000)); }
        Ayar(API_GOP, (uint)(Fps * 4));
        Bilgi = kaliteKipi ? L.T("kalite ") + kalite : kbps + L.T(" kbps");

        IMFMediaType o; D(MFCreateMediaType(out o), "tur");
        o.SetGUID(ref MT_MAJOR, ref VIDEO); o.SetGUID(ref MT_SUBTYPE, ref H264);
        o.SetUINT32(ref MT_BITRATE, (uint)(kbps * 1000));
        o.SetUINT64(ref MT_FRAME_RATE, ((ulong)(uint)Fps << 32) | 1);
        o.SetUINT64(ref MT_FRAME_SIZE, ((ulong)(uint)W << 32) | (uint)H);
        o.SetUINT32(ref MT_INTERLACE, 2);
        o.SetUINT64(ref MT_PAR, (1UL << 32) | 1);
        o.SetUINT32(ref MT_PROFILE, 66);            // Baseline: B-kare yok (gecikme), her tarayici cozer
        D(mft.SetOutputType(0, o, 0), "SetOutputType");
        Marshal.ReleaseComObject(o);

        IMFMediaType g; D(MFCreateMediaType(out g), "tur");
        g.SetGUID(ref MT_MAJOR, ref VIDEO); g.SetGUID(ref MT_SUBTYPE, ref NV12);
        g.SetUINT64(ref MT_FRAME_RATE, ((ulong)(uint)Fps << 32) | 1);
        g.SetUINT64(ref MT_FRAME_SIZE, ((ulong)(uint)W << 32) | (uint)H);
        g.SetUINT32(ref MT_INTERLACE, 2);
        g.SetUINT64(ref MT_PAR, (1UL << 32) | 1);
        D(mft.SetInputType(0, g, 0), "SetInputType");
        Marshal.ReleaseComObject(g);

        MftCikisBilgi bi; D(mft.GetOutputStreamInfo(0, out bi), "OutputStreamInfo");
        kendiOrnegi = (bi.Bayrak & 0x100) != 0;      // MFT_OUTPUT_STREAM_PROVIDES_SAMPLES
        cikisBoyut = Math.Max(bi.Boyut, (uint)(W * H * 3 / 2 + 65536));
        if (!kendiOrnegi)
        {
            D(MFCreateSample(out cikisOrnek), "ornek");
            D(MFCreateMemoryBuffer(cikisBoyut, out cikisTampon), "tampon");
            cikisOrnek.AddBuffer(cikisTampon);
        }
        mft.ProcessMessage(0x10000000, IntPtr.Zero);   // NOTIFY_BEGIN_STREAMING
        mft.ProcessMessage(0x10000003, IntPtr.Zero);   // NOTIFY_START_OF_STREAM
    }

    int Kbps()
    {
        // kalite 30..92 -> piksel basina 0.04..0.16 bit; 1080p60'ta en fazla 12 Mbit/s
        double bpp = 0.04 + Math.Max(0, Math.Min(62, Kalite - 30)) / 62.0 * 0.12;
        return (int)Math.Max(300, Math.Min(12000, W * (double)H * Fps * bpp / 1000));
    }

    bool Ayar(Guid g, object v)
    {
        if (api == null) return false;
        try { return api.SetValue(ref g, ref v) >= 0; } catch { return false; }
    }

    // Kare kodlanir; Annex B (00 00 00 01 ...) bayt dizisi doner (bos olabilir). anahtar: IDR iste.
    public byte[] Kodla(Bitmap bmp, bool anahtar)
    {
        var bd = bmp.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.ReadOnly, PixelFormat.Format32bppRgb);
        try { return KodlaHam(bd.Scan0, bd.Stride, 0, 0, W, H, -1, -1, anahtar); }
        finally { bmp.UnlockBits(bd); }
    }

    // BGRA kaynagin (rx,ry,rw,rh) bolgesini W x H'ye olcekleyip kodlar; (ix,iy) kaynakta imlec (yoksa -1)
    public byte[] KodlaHam(IntPtr kaynak, int satir, int rx, int ry, int rw, int rh, int ix, int iy, bool anahtar)
    {
        if (anahtar && !Ayar(API_ANAHTAR, 1u)) { }
        IMFMediaBuffer gb; D(MFCreateMemoryBuffer((uint)(W * H * 3 / 2), out gb), "giris");
        IntPtr p; uint max, cur;
        D(gb.Lock(out p, out max, out cur), "lock");
        try
        {
            Nv12(kaynak, satir, rx, ry, rw, rh, p, W, H);
            if (ix >= rx && iy >= ry && ix < rx + rw && iy < ry + rh) Imlec(p, W, H, (ix - rx) * W / rw, (iy - ry) * H / rh, Math.Max(1.0, (double)W / rw));
        }
        finally { gb.Unlock(); }
        gb.SetCurrentLength((uint)(W * H * 3 / 2));
        IMFSample gs; D(MFCreateSample(out gs), "ornek");
        gs.AddBuffer(gb);
        long sure = 10000000L / Fps;
        gs.SetSampleTime(zaman); gs.SetSampleDuration(sure); zaman += sure;
        int hr = mft.ProcessInput(0, gs, 0);
        Marshal.ReleaseComObject(gs); Marshal.ReleaseComObject(gb);
        var cikti = new System.IO.MemoryStream();
        Cek(cikti);
        if (hr == unchecked((int)0xC00D36B5)) { }       // MF_E_NOTACCEPTING: cikis bosaltildi, kare atlandi
        else D(hr, "ProcessInput");
        return cikti.ToArray();
    }

    void Cek(System.IO.MemoryStream cikti)
    {
        for (int tur = 0; tur < 8; tur++)
        {
            var t = new MftCikisTampon[1];
            IntPtr ip = IntPtr.Zero;
            if (!kendiOrnegi)
            {
                cikisTampon.SetCurrentLength(0);
                ip = Marshal.GetComInterfaceForObject(cikisOrnek, typeof(IMFSample));
                t[0].Ornek = ip;
            }
            uint durum;
            int hr = mft.ProcessOutput(0, 1, t, out durum);
            if (t[0].Olaylar != IntPtr.Zero) Marshal.Release(t[0].Olaylar);
            IMFSample s = null;
            if (kendiOrnegi && t[0].Ornek != IntPtr.Zero) { s = (IMFSample)Marshal.GetObjectForIUnknown(t[0].Ornek); Marshal.Release(t[0].Ornek); }
            else if (!kendiOrnegi) s = cikisOrnek;
            if (ip != IntPtr.Zero) Marshal.Release(ip);
            if (hr == NEED_MORE_INPUT) { if (kendiOrnegi && s != null) Marshal.ReleaseComObject(s); return; }
            D(hr, "ProcessOutput");
            if (s != null)
            {
                IMFMediaBuffer b;
                if (s.ConvertToContiguousBuffer(out b) >= 0 && b != null)
                {
                    IntPtr bp; uint bmax, bcur;
                    if (b.Lock(out bp, out bmax, out bcur) >= 0)
                    {
                        var arr = new byte[bcur]; Marshal.Copy(bp, arr, 0, (int)bcur); b.Unlock();
                        cikti.Write(arr, 0, arr.Length);
                    }
                    if (!object.ReferenceEquals(b, cikisTampon)) Marshal.ReleaseComObject(b);
                }
                if (kendiOrnegi) Marshal.ReleaseComObject(s);
            }
        }
    }

    // Fare imleci (ok) NV12 uzerine; k: buyutme
    static readonly string[] OK = {
        "B...........", "BB..........", "BWB.........", "BWWB........", "BWWWB.......", "BWWWWB......", "BWWWWWB.....",
        "BWWWWWWB....", "BWWWWWWWB...", "BWWWWWWWWB..", "BWWWWWWWWWB.", "BWWWWWWBBBBB", "BWWWBWWB....", "BWWBBWWB....",
        "BWB..BWWB...", "BB...BWWB...", "B.....BWWB..", "......BWWB..", ".......BB..." };
    static unsafe void Imlec(IntPtr hedef, int w, int h, int ox, int oy, double k)
    {
        byte* Y = (byte*)hedef, UV = Y + w * h;
        int ow = (int)(12 * k), oh = (int)(19 * k);
        for (int j = 0; j < oh; j++)
        {
            int y = oy + j; if (y < 0 || y >= h) continue;
            string s = OK[Math.Min(18, (int)(j / k))];
            for (int i = 0; i < ow; i++)
            {
                int x = ox + i; if (x < 0 || x >= w) continue;
                char c = s[Math.Min(11, (int)(i / k))];
                if (c == '.') continue;
                Y[y * w + x] = (byte)(c == 'W' ? 235 : 16);
                byte* uv = UV + (y / 2) * w + (x & ~1); uv[0] = 128; uv[1] = 128;
            }
        }
    }

    // BGRA bolge -> NV12 (BT.601 sinirli aralik); boyut farkliysa ikidogrusal olcekleme ayni gecide
    unsafe void Nv12(IntPtr kaynak, int satir, int rx, int ry, int rw, int rh, IntPtr hedef, int w, int h)
    {
        if (rw != w || rh != h) { Nv12Olcekli((byte*)kaynak, satir, rx, ry, rw, rh, (byte*)hedef, w, h); return; }
        {
            byte* Y = (byte*)hedef, UV = Y + w * h;
            for (int y = 0; y < h; y += 2)
            {
                byte* r0 = (byte*)kaynak + (ry + y) * satir + rx * 4, r1 = r0 + satir;
                byte* y0 = Y + y * w, y1 = y0 + w, uv = UV + (y / 2) * w;
                for (int x = 0; x < w; x += 2)
                {
                    int b00 = r0[0], g00 = r0[1], R00 = r0[2], b01 = r0[4], g01 = r0[5], R01 = r0[6];
                    int b10 = r1[0], g10 = r1[1], R10 = r1[2], b11 = r1[4], g11 = r1[5], R11 = r1[6];
                    y0[0] = (byte)(((66 * R00 + 129 * g00 + 25 * b00 + 128) >> 8) + 16);
                    y0[1] = (byte)(((66 * R01 + 129 * g01 + 25 * b01 + 128) >> 8) + 16);
                    y1[0] = (byte)(((66 * R10 + 129 * g10 + 25 * b10 + 128) >> 8) + 16);
                    y1[1] = (byte)(((66 * R11 + 129 * g11 + 25 * b11 + 128) >> 8) + 16);
                    int R = (R00 + R01 + R10 + R11) >> 2, G = (g00 + g01 + g10 + g11) >> 2, B = (b00 + b01 + b10 + b11) >> 2;
                    uv[0] = (byte)(((-38 * R - 74 * G + 112 * B + 128) >> 8) + 128);
                    uv[1] = (byte)(((112 * R - 94 * G - 18 * B + 128) >> 8) + 128);
                    r0 += 8; r1 += 8; y0 += 2; y1 += 2; uv += 2;
                }
            }
        }
    }

    int[] xo, xf, yo, yf;     // olcekleme tablolari (oturum basina)
    int sonW, sonH, sonRw, sonRh, sonRx, sonRy, sonSatir;
    unsafe void Nv12Olcekli(byte* src, int satir, int rx, int ry, int rw, int rh, byte* Y, int w, int h)
    {
        if (xo == null || sonW != w || sonH != h || sonRw != rw || sonRh != rh || sonRx != rx || sonRy != ry || sonSatir != satir)
        {
            xo = new int[w]; xf = new int[w]; yo = new int[h]; yf = new int[h];
            for (int x = 0; x < w; x++) { double s = (x + 0.5) * rw / w - 0.5; if (s < 0) s = 0; int i = (int)s; int f = (int)((s - i) * 256); if (i >= rw - 1) { i = Math.Max(0, rw - 2); f = rw > 1 ? 256 : 0; } xo[x] = (rx + i) * 4; xf[x] = f; }
            for (int y = 0; y < h; y++) { double s = (y + 0.5) * rh / h - 0.5; if (s < 0) s = 0; int i = (int)s; int f = (int)((s - i) * 256); if (i >= rh - 1) { i = Math.Max(0, rh - 2); f = rh > 1 ? 256 : 0; } yo[y] = (ry + i) * satir; yf[y] = f; }
            sonW = w; sonH = h; sonRw = rw; sonRh = rh; sonRx = rx; sonRy = ry; sonSatir = satir;
        }
        byte* UV = Y + w * h;
        for (int y = 0; y < h; y += 2)
        {
            byte* s0 = src + yo[y], s1 = src + yo[y + 1];
            int fy0 = yf[y], fy1 = yf[y + 1];
            byte* y0 = Y + y * w, y1 = y0 + w, uv = UV + (y / 2) * w;
            for (int x = 0; x < w; x += 2)
            {
                int Rt = 0, Gt = 0, Bt = 0;
                for (int q = 0; q < 4; q++)
                {
                    int xx = x + (q & 1);
                    byte* a = (q < 2 ? s0 : s1) + xo[xx];
                    int fx = xf[xx], fy = q < 2 ? fy0 : fy1, gx = 256 - fx, gy = 256 - fy;
                    byte* c = a + satir;
                    int B = ((a[0] * gx + a[4] * fx) * gy + (c[0] * gx + c[4] * fx) * fy) >> 16;
                    int G = ((a[1] * gx + a[5] * fx) * gy + (c[1] * gx + c[5] * fx) * fy) >> 16;
                    int R = ((a[2] * gx + a[6] * fx) * gy + (c[2] * gx + c[6] * fx) * fy) >> 16;
                    byte yv = (byte)(((66 * R + 129 * G + 25 * B + 128) >> 8) + 16);
                    if (q == 0) y0[0] = yv; else if (q == 1) y0[1] = yv; else if (q == 2) y1[0] = yv; else y1[1] = yv;
                    Rt += R; Gt += G; Bt += B;
                }
                Rt >>= 2; Gt >>= 2; Bt >>= 2;
                uv[0] = (byte)(((-38 * Rt - 74 * Gt + 112 * Bt + 128) >> 8) + 128);
                uv[1] = (byte)(((112 * Rt - 94 * Gt - 18 * Bt + 128) >> 8) + 128);
                y0 += 2; y1 += 2; uv += 2;
            }
        }
    }

    // Degisim denetimi icin hizli ozet (tum pikseller)
    public static unsafe ulong Ozet(Bitmap bmp)
    {
        var bd = bmp.LockBits(new Rectangle(0, 0, bmp.Width, bmp.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppRgb);
        try
        {
            ulong h = 1469598103934665603UL;
            for (int y = 0; y < bmp.Height; y++)
            {
                ulong* p = (ulong*)((byte*)bd.Scan0 + y * bd.Stride);
                int n = bmp.Width / 2;
                for (int i = 0; i < n; i++) { h ^= p[i]; h *= 1099511628211UL; }
            }
            return h;
        }
        finally { bmp.UnlockBits(bd); }
    }

    public static bool AnahtarMi(byte[] d)
    {
        for (int i = 0; i + 4 < d.Length; i++)
            if (d[i] == 0 && d[i + 1] == 0 && d[i + 2] == 1) { int t = d[i + 3] & 31; if (t == 5 || t == 7) return true; }
        return false;
    }

    public void Dispose()
    {
        try { if (mft != null) { mft.ProcessMessage(0x10000001, IntPtr.Zero); Marshal.ReleaseComObject(mft); } } catch { }   // NOTIFY_END_STREAMING
        try { if (cikisTampon != null) Marshal.ReleaseComObject(cikisTampon); if (cikisOrnek != null) Marshal.ReleaseComObject(cikisOrnek); } catch { }
        mft = null; api = null;
    }
}
