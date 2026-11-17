// BelleRemote PC - ekran yakalama ve girdi (fare, klavye, yazı imleci).
// Kendi bilgisayarını kendi telefonundan kullanmak için; görünür bir uygulamadır.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;

static class Native
{
    public delegate bool EnumProc(IntPtr h, IntPtr p);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern bool ScreenToClient(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
    [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint flags);
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool GetGUIThreadInfo(uint tid, ref GUITHREADINFO info);
    [DllImport("user32.dll")] public static extern uint SendInput(uint n, INPUT[] inputs, int size);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern short VkKeyScanW(char c);
    [DllImport("user32.dll")] public static extern uint MapVirtualKeyW(uint code, uint mapType);
    [DllImport("user32.dll")] public static extern bool LockWorkStation();
    [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int attr, out int val, int size);

    // Windows'un gizlediği (cloaked) pencere mi (arka plandaki UWP / sistem pencereleri)
    public static bool Gizli(IntPtr h)
    {
        int v = 0;
        try { return DwmGetWindowAttribute(h, 14, out v, 4) == 0 && v != 0; } catch { return false; }
    }

    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)]
    public struct GUITHREADINFO
    {
        public int cbSize, flags;
        public IntPtr hwndActive, hwndFocus, hwndCapture, hwndMenuOwner, hwndMoveSize, hwndCaret;
        public RECT rcCaret;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr extra; }
    [StructLayout(LayoutKind.Sequential)]
    public struct KEYBDINPUT { public ushort wVk, wScan; public uint dwFlags, time; public IntPtr extra; }
    [StructLayout(LayoutKind.Explicit)]
    public struct INPUT
    {
        [FieldOffset(0)] public uint type;
        [FieldOffset(8)] public MOUSEINPUT mi;   // 64 bit: hizalama 8
        [FieldOffset(8)] public KEYBDINPUT ki;
    }

    public const uint INPUT_MOUSE = 0, INPUT_KEYBOARD = 1;
    public const uint MOUSEEVENTF_LEFTDOWN = 0x02, MOUSEEVENTF_LEFTUP = 0x04, MOUSEEVENTF_RIGHTDOWN = 0x08, MOUSEEVENTF_RIGHTUP = 0x10;
    public const uint MOUSEEVENTF_MIDDLEDOWN = 0x20, MOUSEEVENTF_MIDDLEUP = 0x40, MOUSEEVENTF_WHEEL = 0x0800;
    public const uint KEYEVENTF_EXTENDEDKEY = 0x1, KEYEVENTF_KEYUP = 0x2, KEYEVENTF_UNICODE = 0x4;
    public const int GWL_EXSTYLE = -20, WS_EX_TOOLWINDOW = 0x80;
}

class WinInfo { public IntPtr H; public string Title; }

// Paylaşılan kaynak: tüm masaüstü (ekran n) ya da tek pencere
class Kaynak
{
    public bool Pencere;
    public int Ekran;            // masaüstünde ekran indeksi
    public IntPtr H;             // pencere
    public string Ad = L.T("Masaüstü");

    // Kaynağın ekran (fiziksel piksel) dikdörtgeni
    public bool Dikdortgen(out Rectangle r)
    {
        r = Rectangle.Empty;
        if (!Pencere)
        {
            var scr = Screen.AllScreens;
            r = scr[Math.Max(0, Math.Min(Ekran, scr.Length - 1))].Bounds;
            return true;
        }
        if (H == IntPtr.Zero || !Native.IsWindow(H)) return false;
        Native.RECT cr;
        if (!Native.GetClientRect(H, out cr)) return false;
        var p = new Native.POINT();
        if (!Native.ClientToScreen(H, ref p)) return false;
        r = new Rectangle(p.X, p.Y, cr.R - cr.L, cr.B - cr.T);
        return r.Width > 1 && r.Height > 1;
    }
}

static class Masaustu
{
    public static List<WinInfo> Pencereler()
    {
        var outp = new List<WinInfo>();
        Native.EnumWindows((h, p) =>
        {
            if (!Native.IsWindowVisible(h)) return true;
            if ((Native.GetWindowLong(h, Native.GWL_EXSTYLE) & Native.WS_EX_TOOLWINDOW) != 0) return true;
            if (Native.Gizli(h)) return true;
            int len = Native.GetWindowTextLength(h);
            if (len == 0) return true;
            Native.RECT r;
            if (!Native.GetWindowRect(h, out r) || (r.R - r.L) < 80 || (r.B - r.T) < 40) return true;
            var sb = new StringBuilder(len + 2);
            Native.GetWindowTextW(h, sb, sb.Capacity);
            string t = sb.ToString();
            if (t.Length == 0 || t.StartsWith("BelleRemote PC")) return true;
            outp.Add(new WinInfo { H = h, Title = t });
            return true;
        }, IntPtr.Zero);
        return outp;
    }

    static ImageCodecInfo _jpeg;
    static ImageCodecInfo Jpeg()
    {
        if (_jpeg == null) foreach (var c in ImageCodecInfo.GetImageEncoders()) if (c.FormatID == ImageFormat.Jpeg.Guid) _jpeg = c;
        return _jpeg;
    }

    // Kaynağı (ve varsa yakınlaştırma bölgesini) yakalar, genişliğe küçültür, JPEG döner.
    // bolge: onbinde bir (x, y, x2, y2). Fare imleci kareye çizilir.
    public static byte[] Yakala(Kaynak k, int[] bolge, int genislik, long kalite)
    {
        Rectangle src;
        if (!k.Dikdortgen(out src)) return null;
        int bx = src.Width * bolge[0] / 10000, by = src.Height * bolge[1] / 10000;
        int bw = Math.Max(8, src.Width * (bolge[2] - bolge[0]) / 10000), bh = Math.Max(8, src.Height * (bolge[3] - bolge[1]) / 10000);
        using (var full = new Bitmap(src.Width, src.Height, PixelFormat.Format24bppRgb))
        {
            using (var g = Graphics.FromImage(full))
            {
                bool ok = false;
                if (k.Pencere && !Native.IsIconic(k.H))
                {
                    IntPtr hdc = g.GetHdc();
                    ok = Native.PrintWindow(k.H, hdc, 0x3);   // PW_CLIENTONLY | PW_RENDERFULLCONTENT
                    g.ReleaseHdc(hdc);
                }
                if (!ok) g.CopyFromScreen(src.X, src.Y, 0, 0, src.Size, CopyPixelOperation.SourceCopy);
                // İmleç (ekranda görünen fare)
                Native.POINT cp;
                if (Native.GetCursorPos(out cp) && src.Contains(cp.X, cp.Y))
                {
                    try { Cursors.Arrow.Draw(g, new Rectangle(cp.X - src.X, cp.Y - src.Y, 32, 32)); } catch { }
                }
            }
            double olcek = Math.Min(1.0, (double)genislik / bw);
            int ow = Math.Max(1, (int)(bw * olcek)), oh = Math.Max(1, (int)(bh * olcek));
            using (var kucuk = new Bitmap(ow, oh, PixelFormat.Format24bppRgb))
            {
                using (var g = Graphics.FromImage(kucuk))
                {
                    g.InterpolationMode = olcek < 0.6 ? System.Drawing.Drawing2D.InterpolationMode.HighQualityBilinear : System.Drawing.Drawing2D.InterpolationMode.Bilinear;
                    g.DrawImage(full, new Rectangle(0, 0, ow, oh), new Rectangle(bx, by, bw, bh), GraphicsUnit.Pixel);
                }
                var ps = new EncoderParameters(1);
                ps.Param[0] = new EncoderParameter(System.Drawing.Imaging.Encoder.Quality, kalite);
                using (var ms = new MemoryStream())
                {
                    kucuk.Save(ms, Jpeg(), ps);
                    return ms.ToArray();
                }
            }
        }
    }

    // Video icin: bolgenin en/boy degerleri (kaynak pikselleri)
    public static bool BolgeBoyutu(Kaynak k, int[] bolge, out int bw, out int bh)
    {
        Rectangle src; bw = bh = 0;
        if (!k.Dikdortgen(out src)) return false;
        bw = Math.Max(8, src.Width * (bolge[2] - bolge[0]) / 10000); bh = Math.Max(8, src.Height * (bolge[3] - bolge[1]) / 10000);
        return true;
    }

    // Video icin: bolgeyi dogrudan hedef bitmap boyutuna (32bpp) yakalar; ara bitmap yeniden kullanilir
    public static bool YakalaHam(Kaynak k, int[] bolge, Bitmap hedef, ref Bitmap ara)
    {
        Rectangle src;
        if (!k.Dikdortgen(out src)) return false;
        int bx = src.Width * bolge[0] / 10000, by = src.Height * bolge[1] / 10000;
        int bw = Math.Max(8, src.Width * (bolge[2] - bolge[0]) / 10000), bh = Math.Max(8, src.Height * (bolge[3] - bolge[1]) / 10000);
        bool pencere = k.Pencere && !Native.IsIconic(k.H);
        int aw = pencere ? src.Width : bw, ah = pencere ? src.Height : bh;
        bool dogrudan = !pencere && aw == hedef.Width && ah == hedef.Height;
        Bitmap yer = hedef;
        if (!dogrudan)
        {
            if (ara == null || ara.Width != aw || ara.Height != ah) { if (ara != null) ara.Dispose(); ara = new Bitmap(aw, ah, PixelFormat.Format32bppRgb); }
            yer = ara;
        }
        int ox = pencere ? src.X : src.X + bx, oy = pencere ? src.Y : src.Y + by;
        using (var g = Graphics.FromImage(yer))
        {
            bool ok = false;
            if (pencere) { IntPtr hdc = g.GetHdc(); ok = Native.PrintWindow(k.H, hdc, 0x3); g.ReleaseHdc(hdc); }
            if (!ok) g.CopyFromScreen(ox, oy, 0, 0, new Size(aw, ah), CopyPixelOperation.SourceCopy);
            Native.POINT cp;
            if (Native.GetCursorPos(out cp) && cp.X >= ox && cp.Y >= oy && cp.X < ox + aw && cp.Y < oy + ah)
            { try { Cursors.Arrow.Draw(g, new Rectangle(cp.X - ox, cp.Y - oy, 32, 32)); } catch { } }
        }
        if (!dogrudan)
        {
            using (var g = Graphics.FromImage(hedef))
            {
                g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.Bilinear;
                g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.Half;
                g.CompositingMode = System.Drawing.Drawing2D.CompositingMode.SourceCopy;
                g.DrawImage(ara, new Rectangle(0, 0, hedef.Width, hedef.Height), pencere ? new Rectangle(bx, by, bw, bh) : new Rectangle(0, 0, bw, bh), GraphicsUnit.Pixel);
            }
        }
        return true;
    }

    // Onbinde bir kaynak koordinatı -> ekran
    public static bool Ekrana(Kaynak k, int x, int y, out int sx, out int sy)
    {
        sx = sy = 0;
        Rectangle r;
        if (!k.Dikdortgen(out r)) return false;
        sx = r.X + (int)((long)r.Width * Math.Max(0, Math.Min(10000, x)) / 10000);
        sy = r.Y + (int)((long)r.Height * Math.Max(0, Math.Min(10000, y)) / 10000);
        return true;
    }

    // Ekrandaki imleç -> onbinde bir kaynak koordinatı (kaynakta değilse false)
    public static bool ImlecKaynakta(Kaynak k, out int x, out int y)
    {
        x = y = -1;
        Rectangle r; Native.POINT p;
        if (!k.Dikdortgen(out r) || !Native.GetCursorPos(out p) || !r.Contains(p.X, p.Y)) return false;
        x = (int)((long)(p.X - r.X) * 10000 / r.Width);
        y = (int)((long)(p.Y - r.Y) * 10000 / r.Height);
        return true;
    }

    // Ön plandaki pencerede yazı imleci (metin kutusu odağı) var mı
    public static bool YaziImleci()
    {
        IntPtr fg = Native.GetForegroundWindow();
        if (fg == IntPtr.Zero) return false;
        uint pid;
        uint tid = Native.GetWindowThreadProcessId(fg, out pid);
        var gi = new Native.GUITHREADINFO();
        gi.cbSize = Marshal.SizeOf(typeof(Native.GUITHREADINFO));
        if (!Native.GetGUIThreadInfo(tid, ref gi)) return false;
        return gi.hwndCaret != IntPtr.Zero || (gi.flags & 0x1) != 0;   // GUI_CARETBLINKING
    }

    // ---------- Fare ----------
    static void Fare(uint flags, int data)
    {
        var inp = new Native.INPUT[1];
        inp[0].type = Native.INPUT_MOUSE;
        inp[0].mi.dwFlags = flags;
        inp[0].mi.mouseData = (uint)data;
        Native.SendInput(1, inp, Marshal.SizeOf(typeof(Native.INPUT)));
    }

    public static void OneGetir(Kaynak k)
    {
        if (!k.Pencere) return;
        IntPtr root = Native.GetAncestor(k.H, 2);
        IntPtr h = root == IntPtr.Zero ? k.H : root;
        if (Native.IsIconic(h)) Native.ShowWindow(h, 9);   // SW_RESTORE
        if (Native.GetForegroundWindow() != h) Native.SetForegroundWindow(h);
    }

    public static void Git(Kaynak k, int x, int y)
    {
        int sx, sy; if (Ekrana(k, x, y, out sx, out sy)) Native.SetCursorPos(sx, sy);
    }

    public static void Tik(Kaynak k, string dugme, int x, int y)
    {
        int sx, sy; if (!Ekrana(k, x, y, out sx, out sy)) return;
        OneGetir(k);
        Native.SetCursorPos(sx, sy);
        Thread.Sleep(8);
        uint d = Native.MOUSEEVENTF_LEFTDOWN, u = Native.MOUSEEVENTF_LEFTUP;
        if (dugme == "R") { d = Native.MOUSEEVENTF_RIGHTDOWN; u = Native.MOUSEEVENTF_RIGHTUP; }
        else if (dugme == "M") { d = Native.MOUSEEVENTF_MIDDLEDOWN; u = Native.MOUSEEVENTF_MIDDLEUP; }
        Fare(d, 0); Thread.Sleep(12); Fare(u, 0);
    }

    public static void Bas(Kaynak k, string dugme, int x, int y, bool asagi)
    {
        int sx, sy; if (!Ekrana(k, x, y, out sx, out sy)) return;
        if (asagi) OneGetir(k);
        Native.SetCursorPos(sx, sy);
        bool sag = dugme == "R";
        Fare(asagi ? (sag ? Native.MOUSEEVENTF_RIGHTDOWN : Native.MOUSEEVENTF_LEFTDOWN) : (sag ? Native.MOUSEEVENTF_RIGHTUP : Native.MOUSEEVENTF_LEFTUP), 0);
    }

    public static void Teker(int n) { Fare(Native.MOUSEEVENTF_WHEEL, n * 120); }
    // Yatay tekerlek: + sağa, − sola
    public static void YatayTeker(int n) { Fare(0x1000 /* MOUSEEVENTF_HWHEEL */, n * 120); }

    // ---------- Klavye ----------
    static void Tus(ushort vk, bool up)
    {
        var inp = new Native.INPUT[1];
        inp[0].type = Native.INPUT_KEYBOARD;
        inp[0].ki.wVk = vk;
        // Tarama kodu da verilir: yalnız sanal kod alan bazı uygulamalar kısayolu görmüyordu
        inp[0].ki.wScan = (ushort)Native.MapVirtualKeyW(vk, 0);
        uint f = up ? Native.KEYEVENTF_KEYUP : 0;
        // Genişletilmiş tuşlar: yön, home/end, ins/del, pgup/pgdn, Win, menü, ses/medya tuşları
        if ((vk >= 0x21 && vk <= 0x2E) || (vk >= 0x5B && vk <= 0x5D) || (vk >= 0xA6 && vk <= 0xB7)) f |= Native.KEYEVENTF_EXTENDEDKEY;
        inp[0].ki.dwFlags = f;
        Native.SendInput(1, inp, Marshal.SizeOf(typeof(Native.INPUT)));
    }

    static readonly Dictionary<string, ushort> Vk = new Dictionary<string, ushort>
    {
        {"enter",0x0D},{"esc",0x1B},{"tab",0x09},{"backspace",0x08},{"delete",0x2E},{"insert",0x2D},{"space",0x20},
        {"home",0x24},{"end",0x23},{"pgup",0x21},{"pgdn",0x22},{"up",0x26},{"down",0x28},{"left",0x25},{"right",0x27},
        {"win",0x5B},{"ctrl",0x11},{"shift",0x10},{"alt",0x12},{"menu",0x5D},{"prtsc",0x2C},
        {"volup",0xAF},{"voldown",0xAE},{"mute",0xAD},{"play",0xB3},{"next",0xB0},{"prev",0xB1},{"stop",0xB2},
        {"f1",0x70},{"f2",0x71},{"f3",0x72},{"f4",0x73},{"f5",0x74},{"f6",0x75},{"f7",0x76},{"f8",0x77},{"f9",0x78},{"f10",0x79},{"f11",0x7A},{"f12",0x7B}
    };

    // "ctrl+shift+esc", "alt+tab", "enter", "win+d" ...
    public static void Kisayol(string kombo)
    {
        kombo = kombo.ToLowerInvariant().Trim();
        // Win+L SendInput ile gönderilemez (Windows güvenlik nedeniyle engeller): doğrudan kilitle
        if (kombo == "win+l") { Native.LockWorkStation(); return; }
        var parcalar = kombo.Split('+');
        var basili = new List<ushort>();
        foreach (var p in parcalar)
        {
            ushort vk;
            if (Vk.TryGetValue(p, out vk)) { }
            else if (p.Length == 1) { short s = Native.VkKeyScanW(p[0]); if (s == -1) continue; vk = (ushort)(s & 0xFF); }
            else continue;
            Tus(vk, false); basili.Add(vk);
            Thread.Sleep(15);
        }
        Thread.Sleep(30);
        for (int i = basili.Count - 1; i >= 0; i--) { Tus(basili[i], true); Thread.Sleep(10); }
    }

    // Unicode metin yazma (Türkçe karakterler dahil). \n -> Enter
    public static void Yaz(string metin)
    {
        foreach (char c in metin.Replace("\r\n", "\n"))
        {
            if (c == '\n') { Tus(0x0D, false); Tus(0x0D, true); continue; }
            var inp = new Native.INPUT[2];
            inp[0].type = inp[1].type = Native.INPUT_KEYBOARD;
            inp[0].ki.wScan = inp[1].ki.wScan = c;
            inp[0].ki.dwFlags = Native.KEYEVENTF_UNICODE;
            inp[1].ki.dwFlags = Native.KEYEVENTF_UNICODE | Native.KEYEVENTF_KEYUP;
            Native.SendInput(2, inp, Marshal.SizeOf(typeof(Native.INPUT)));
            Thread.Sleep(2);
        }
    }
}
