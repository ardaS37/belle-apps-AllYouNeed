// BelleRemote PC - ağ: çerçeveler, oturum (akış denetimi, girdi), LAN dinleyici, sunucu aktarıcısında bekleme.
// Protokol: ..\PROTOKOL.md
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
using System.Threading;

static class Cerceve
{
    public static byte[] Oku(Stream s, int n)
    {
        var b = new byte[n]; int off = 0;
        while (off < n) { int r = s.Read(b, off, n - off); if (r <= 0) return null; off += r; }
        return b;
    }
    // false: bağlantı bitti
    public static bool Al(Stream s, out char tur, out byte[] veri)
    {
        tur = '\0'; veri = null;
        var h = Oku(s, 5); if (h == null) return false;
        tur = (char)h[0];
        long len = ((long)h[1] << 24) | ((long)h[2] << 16) | ((long)h[3] << 8) | h[4];
        if (len < 0 || len > 16 * 1024 * 1024) return false;
        veri = len == 0 ? new byte[0] : Oku(s, (int)len);
        return len == 0 || veri != null;
    }
    public static void Gonder(Stream s, object kilit, char tur, byte[] veri)
    {
        if (veri == null) veri = new byte[0];
        int len = veri.Length;
        var buf = new byte[5 + len];
        buf[0] = (byte)tur; buf[1] = (byte)(len >> 24); buf[2] = (byte)(len >> 16); buf[3] = (byte)(len >> 8); buf[4] = (byte)len;
        Buffer.BlockCopy(veri, 0, buf, 5, len);
        lock (kilit) { s.Write(buf, 0, buf.Length); s.Flush(); }
    }
    public static void Gonder(Stream s, object kilit, char tur, string metin) { Gonder(s, kilit, tur, Encoding.UTF8.GetBytes(metin ?? "")); }
}

// Bir telefon/istemci bağlantısı
class Oturum
{
    public readonly string Yol;                 // "LAN" | "Sunucu"
    public string IstemciAdi = "?", Kip = "paket";
    public volatile bool Bitti;
    public int Fps = 1, Genislik = 640;
    public long Kalite = 40;
    public string Codec = "jpeg";               // web paneli "h264" isteyebilir (WebCodecs); Nokia hep JPEG
    public long GonderilenBayt, KareSayisi;
    public Action<string> Gunluk;
    public Action<byte[]> Onizleme;
    public Func<string> Anahtar;                // geçerli sunucu parolası
    public Func<string> PcAdi;

    readonly TcpClient tcp;
    readonly Stream st;
    readonly object yazKilit = new object();
    readonly Kaynak kaynak = new Kaynak();
    readonly int[] bolge = { 0, 0, 10000, 10000 };
    List<WinInfo> sonListe = new List<WinInfo>();
    readonly AutoResetEvent kareIste = new AutoResetEvent(false);
    volatile bool zorla;            // sırayı atla, hemen kare
    volatile bool anahtarIste;      // H.264: sonraki kare anahtar (IDR) olsun
    int bekleyen;                   // onaylanmamış kare sayısı
    string sonOzet;
    bool yaziImleci;
    readonly char ilkTur; readonly byte[] ilkVeri;

    public Oturum(TcpClient c, Stream s, string yol, char ilkTur, byte[] ilkVeri)
    {
        tcp = c; st = s; Yol = yol; this.ilkTur = ilkTur; this.ilkVeri = ilkVeri;
        c.NoDelay = true;
    }

    void Log(string s) { if (Gunluk != null) Gunluk(s); }

    public void Kapat()
    {
        Bitti = true;
        kareIste.Set();
        try { tcp.Close(); } catch { }
    }

    public void Baslat()
    {
        new Thread(OkumaDongusu) { IsBackground = true, Name = "oturum-oku" }.Start();
    }

    void OkumaDongusu()
    {
        bool dogrulandi = false;
        try
        {
            char tur = ilkTur; byte[] veri = ilkVeri;
            bool ilk = ilkTur != '\0';
            while (!Bitti)
            {
                if (!ilk) { if (!Cerceve.Al(st, out tur, out veri)) break; }
                ilk = false;
                if (!dogrulandi)
                {
                    if (tur == 'P') continue;
                    if (tur != 'H') break;
                    var a = Ayrisir(Encoding.UTF8.GetString(veri));
                    string k; a.TryGetValue("anahtar", out k);
                    if (string.IsNullOrEmpty(k) || !SabitZamanEsit(k, Anahtar()))
                    {
                        Cerceve.Gonder(st, yazKilit, 'N', L.T("Parola hatali"));
                        Log(L.T("Reddedildi: parola hatalı (") + Yol + ")");
                        break;
                    }
                    dogrulandi = true;
                    AyarUygula(a);
                    Cerceve.Gonder(st, yazKilit, 'O', "ad=" + PcAdi() + "\nekranlar=" + System.Windows.Forms.Screen.AllScreens.Length + "\nsurum=1\ncodec=" + Codec);
                    Log(L.T("Oturum açıldı: ") + IstemciAdi + " (" + Yol + ", " + Kip + ", " + Fps + L.T(" fps, ") + Genislik + " px, " + (Codec == "h264" ? "H.264" : "JPEG") + ")");
                    new Thread(KareDongusu) { IsBackground = true, Name = "oturum-kare" }.Start();
                    zorla = true; kareIste.Set();
                    continue;
                }
                Isle(tur, veri);
            }
        }
        catch (Exception ex) { if (!Bitti) Log(L.T("Bağlantı hatası: ") + ex.Message); }
        Kapat();
    }

    static bool SabitZamanEsit(string a, string b)
    {
        if (a == null || b == null) return false;
        var x = Encoding.UTF8.GetBytes(a); var y = Encoding.UTF8.GetBytes(b);
        int d = x.Length ^ y.Length;
        for (int i = 0; i < Math.Max(x.Length, y.Length); i++) d |= (i < x.Length ? x[i] : 0) ^ (i < y.Length ? y[i] : 0);
        return d == 0;
    }

    static Dictionary<string, string> Ayrisir(string metin)
    {
        var d = new Dictionary<string, string>();
        foreach (var satir in metin.Split('\n'))
        {
            int i = satir.IndexOf('=');
            if (i > 0) d[satir.Substring(0, i).Trim()] = satir.Substring(i + 1).Trim();
        }
        return d;
    }

    void AyarUygula(Dictionary<string, string> a)
    {
        string v; int n;
        if (a.TryGetValue("ad", out v) && v.Length > 0) IstemciAdi = v;
        if (a.TryGetValue("kip", out v) && (v == "paket" || v == "akis")) Kip = v;
        if (a.TryGetValue("fps", out v) && int.TryParse(v, out n)) Fps = Math.Max(0, Math.Min(60, n));      // web paneli 60 fps isteyebilir; Nokia 1-20 gonderir
        if (a.TryGetValue("genislik", out v) && int.TryParse(v, out n)) Genislik = Math.Max(160, Math.Min(1920, n));      // 1080p yeter
        if (a.TryGetValue("kalite", out v) && int.TryParse(v, out n)) Kalite = Math.Max(10, Math.Min(95, n));
        if (a.TryGetValue("codec", out v)) Codec = v == "h264" ? "h264" : "jpeg";
    }

    void Isle(char tur, byte[] veri)
    {
        string metin = tur == 'J' ? null : Encoding.UTF8.GetString(veri);
        switch (tur)
        {
            case 'G': lock (this) { if (bekleyen > 0) bekleyen--; } kareIste.Set(); break;
            case 'F': zorla = true; anahtarIste = true; sonOzet = null; kareIste.Set(); break;
            case 'P': Cerceve.Gonder(st, yazKilit, 'P', veri); break;
            case 'A': AyarUygula(Ayrisir(metin)); Log("Ayar: " + Kip + ", " + Fps + " fps, " + Genislik + " px, kalite " + Kalite); zorla = true; kareIste.Set(); break;
            case 'L':
                sonListe = Masaustu.Pencereler();
                var sb = new StringBuilder();
                for (int i = 0; i < sonListe.Count; i++) sb.Append(i).Append('\t').Append(sonListe[i].Title.Replace('\n', ' ')).Append('\n');
                Cerceve.Gonder(st, yazKilit, 'L', sb.ToString());
                break;
            case 'S': KaynakSec(metin.Trim()); bolge[0] = 0; bolge[1] = 0; bolge[2] = 10000; bolge[3] = 10000; zorla = true; sonOzet = null; kareIste.Set(); break;
            case 'Z':
                var p = metin.Trim().Split(' ');
                int x1, y1, x2, y2;
                if (p.Length == 4 && int.TryParse(p[0], out x1) && int.TryParse(p[1], out y1) && int.TryParse(p[2], out x2) && int.TryParse(p[3], out y2) && x2 > x1 + 50 && y2 > y1 + 50)
                { bolge[0] = Math.Max(0, x1); bolge[1] = Math.Max(0, y1); bolge[2] = Math.Min(10000, x2); bolge[3] = Math.Min(10000, y2); }
                zorla = true; kareIste.Set();
                break;
            case 'I': Girdi(metin); if (Kip == "paket") { zorla = true; } kareIste.Set(); break;
            case 'Y': Masaustu.OneGetir(kaynak); Masaustu.Yaz(metin); Log("Yazı gönderildi (" + metin.Length + " karakter)"); zorla = true; kareIste.Set(); break;
        }
    }

    void KaynakSec(string s)
    {
        if (s.StartsWith("pencere:"))
        {
            int i;
            if (int.TryParse(s.Substring(8), out i) && i >= 0 && i < sonListe.Count)
            {
                kaynak.Pencere = true; kaynak.H = sonListe[i].H; kaynak.Ad = sonListe[i].Title;
                Masaustu.OneGetir(kaynak);
            }
        }
        else
        {
            int n = 0;
            if (s.StartsWith("ekran:")) int.TryParse(s.Substring(6), out n);
            kaynak.Pencere = false; kaynak.H = IntPtr.Zero; kaynak.Ekran = n;
            kaynak.Ad = L.T("Masaüstü") + (System.Windows.Forms.Screen.AllScreens.Length > 1 ? " " + (n + 1) : "");
        }
        Log(L.T("Kaynak: ") + kaynak.Ad);
        Cerceve.Gonder(st, yazKilit, 'M', L.T("Kaynak: ") + kaynak.Ad);
    }

    void Girdi(string metin)
    {
        foreach (var ham in metin.Split('\n'))
        {
            var s = ham.Trim(); if (s.Length == 0) continue;
            var a = s.Split(' ');
            int x, y;
            try
            {
                switch (a[0])
                {
                    case "M": if (a.Length >= 3 && int.TryParse(a[1], out x) && int.TryParse(a[2], out y)) Masaustu.Git(kaynak, x, y); break;
                    case "C": if (a.Length >= 4 && int.TryParse(a[2], out x) && int.TryParse(a[3], out y)) Masaustu.Tik(kaynak, a[1], x, y); break;
                    case "D": if (a.Length >= 4 && int.TryParse(a[2], out x) && int.TryParse(a[3], out y)) Masaustu.Bas(kaynak, a[1], x, y, true); break;
                    case "U": if (a.Length >= 4 && int.TryParse(a[2], out x) && int.TryParse(a[3], out y)) Masaustu.Bas(kaynak, a[1], x, y, false); break;
                    case "W": if (a.Length >= 2 && int.TryParse(a[1], out x)) Masaustu.Teker(x); break;
                    case "X": if (a.Length >= 2 && int.TryParse(a[1], out x)) Masaustu.YatayTeker(x); break;
                    case "K": if (a.Length >= 2) { Masaustu.OneGetir(kaynak); Masaustu.Kisayol(a[1]); } break;
                }
            }
            catch { }
            Thread.Sleep(4);
        }
    }

    // Kare gönderici: fps sınırı + en fazla 2 onaylanmamış kare + değişmeyen kare atlanır
    void KareDongusu()
    {
        var md5 = MD5.Create();
        // 60 fps icin: hassas saat (DateTime ~15 ms adimli) ve 1 ms zamanlayici cozunurlugu
        var saat = System.Diagnostics.Stopwatch.StartNew();
        double sonMs = -100000;
        bool hassas = false;
        DateTime sonImlecDenetim = DateTime.MinValue;
        while (!Bitti)
        {
            if (Fps > 20 && !hassas) { try { timeBeginPeriod(1); hassas = true; } catch { } }
            int bekleme = Fps > 0 ? Math.Max(4, 1000 / Fps / 2) : 1000;
            kareIste.WaitOne(Math.Min(bekleme, 300));
            if (Bitti) break;

            // Yazı imleci (metin kutusu) değişimi
            if ((DateTime.Now - sonImlecDenetim).TotalMilliseconds > 300)
            {
                sonImlecDenetim = DateTime.Now;
                bool yi = false;
                try { yi = Masaustu.YaziImleci(); } catch { }
                if (yi != yaziImleci) { yaziImleci = yi; try { Cerceve.Gonder(st, yazKilit, 'T', yi ? "1" : "0"); } catch { break; } }
            }

            bool simdiZorla = zorla;
            bool zamanGeldi = Fps > 0 && saat.Elapsed.TotalMilliseconds - sonMs >= 1000.0 / Fps - 1;
            if (!simdiZorla && !zamanGeldi) continue;
            // yolda en fazla kac onaylanmamis kare: yuksek fps'te gecikme (sunucu uzerinden) hizi kesmesin
            int enFazla = Math.Max(2, Fps / 10);
            lock (this) { if (!simdiZorla && bekleyen >= enFazla) continue; }
            zorla = false;
            if (simdiZorla) Thread.Sleep(Kip == "paket" ? 250 : 30);   // tıklamanın etkisi ekrana yansısın
            if (Codec == "h264")
            {
                byte[] paket = null;
                try { paket = VideoKare(simdiZorla); }
                catch (Exception ex)
                {
                    Log(L.T("H.264 kullanılamadı, JPEG'e geçildi: ") + ex.Message);
                    Codec = "jpeg"; if (kod != null) { kod.Dispose(); kod = null; }
                    try { Cerceve.Gonder(st, yazKilit, 'M', L.T("H.264 kullanılamadı, JPEG")); } catch { break; }
                    zorla = true; continue;
                }
                sonMs = saat.Elapsed.TotalMilliseconds;
                if (paket == null) continue;
                try
                {
                    int ix, iy;
                    bool gor = Masaustu.ImlecKaynakta(kaynak, out ix, out iy);
                    Cerceve.Gonder(st, yazKilit, 'K', gor ? ix + " " + iy + " 1" : "-1 -1 0");
                    Cerceve.Gonder(st, yazKilit, 'V', paket);
                    lock (this) bekleyen++;
                    GonderilenBayt += paket.Length; KareSayisi++;
                }
                catch { break; }
                continue;
            }
            byte[] jpeg = null;
            try { jpeg = Masaustu.Yakala(kaynak, (int[])bolge.Clone(), Genislik, Kalite); } catch (Exception ex) { Log(L.T("Yakalama: ") + ex.Message); }
            sonMs = saat.Elapsed.TotalMilliseconds;
            if (jpeg == null) continue;
            string ozet = Convert.ToBase64String(md5.ComputeHash(jpeg));
            if (!simdiZorla && ozet == sonOzet) continue;   // değişmedi
            sonOzet = ozet;
            try
            {
                int ix, iy;
                bool gor = Masaustu.ImlecKaynakta(kaynak, out ix, out iy);
                Cerceve.Gonder(st, yazKilit, 'K', gor ? ix + " " + iy + " 1" : "-1 -1 0");
                Cerceve.Gonder(st, yazKilit, 'J', jpeg);
                lock (this) bekleyen++;
                GonderilenBayt += jpeg.Length; KareSayisi++;
                if (Onizleme != null) Onizleme(jpeg);
            }
            catch { break; }
        }
        if (hassas) { try { timeEndPeriod(1); } catch { } }
        if (kod != null) { kod.Dispose(); kod = null; }
        if (ekranKopya != null) { ekranKopya.Dispose(); ekranKopya = null; }
        Kapat();
    }

    // ---- H.264 (web paneli) ----
    H264Kodlayici kod;
    Bitmap vKare, vAra;
    ulong vOzet;
    int vSay, vIx = -9, vIy = -9, dxgiHata;
    EkranKopya ekranKopya;
    bool dxgiYok;

    // Kareyi yakalar ve kodlar; gonderilecek paket ([bayrak][Annex B]) ya da degismediyse null
    byte[] VideoKare(bool simdiZorla)
    {
        var b = (int[])bolge.Clone();
        int bw, bh;
        if (!Masaustu.BolgeBoyutu(kaynak, b, out bw, out bh)) return null;
        double olcek = Math.Min(1.0, (double)Genislik / bw);
        int vw = Math.Max(64, (int)(bw * olcek) & ~15), vh = Math.Max(64, (int)(bh * olcek) & ~1);
        int fps = Math.Max(1, Fps);
        if (kod == null || kod.W != vw || kod.H != vh || kod.Fps != fps || kod.Kalite != (int)Kalite)
        {
            if (kod != null) kod.Dispose();
            kod = null;
            kod = new H264Kodlayici(vw, vh, fps, (int)Kalite);
            if (vKare != null) vKare.Dispose();
            vKare = new Bitmap(vw, vh, PixelFormat.Format32bppRgb);
            vOzet = 0; anahtarIste = false; vSay = 0;
            Log("H.264: " + vw + "×" + vh + ", " + fps + L.T(" fps, ") + kod.Bilgi);
        }
        byte[] v = null;
        bool anahtar = anahtarIste;
        // Ekran kaynagi: DXGI (hizli, degismeyen ekrani kendisi bildirir); pencere ya da hata: GDI
        if (!kaynak.Pencere && !dxgiYok)
        {
            Rectangle sinir;
            kaynak.Dikdortgen(out sinir);
            if (ekranKopya != null && ekranKopya.Sinir != sinir) { ekranKopya.Dispose(); ekranKopya = null; }
            if (ekranKopya == null)
            {
                string h;
                ekranKopya = EkranKopya.Ac(sinir, out h);
                if (ekranKopya == null) { dxgiHata++; Log(L.T("Hızlı yakalama (DXGI) yok: ") + h + (dxgiHata >= 3 ? L.T(" — GDI kullanılıyor") : "")); if (dxgiHata >= 3) dxgiYok = true; }
                else { anahtar = true; Log(L.T("Hızlı yakalama: DXGI")); }
            }
            if (ekranKopya != null)
            {
                bool yeni; string h;
                int r = ekranKopya.Al(0, out yeni, out h);
                if (r != EkranKopya.TAMAM) { Log(L.T("DXGI yeniden kuruluyor: ") + h); ekranKopya.Dispose(); ekranKopya = null; return null; }
                Native.POINT cp; int ix = -1, iy = -1;
                if (Native.GetCursorPos(out cp)) { ix = cp.X - sinir.X; iy = cp.Y - sinir.Y; }
                bool imlecDegisti = ix != vIx || iy != vIy;
                if (!yeni && !imlecDegisti && !simdiZorla && !anahtar) return null;   // degismedi
                vIx = ix; vIy = iy; anahtarIste = false;
                int rx = sinir.Width * b[0] / 10000, ry = sinir.Height * b[1] / 10000;
                int rw = Math.Min(bw, ekranKopya.W - rx), rh = Math.Min(bh, ekranKopya.H - ry);
                IntPtr veri; int satir;
                if (!ekranKopya.Harita(out veri, out satir)) return null;
                try { v = kod.KodlaHam(veri, satir, rx, ry, rw, rh, ix, iy, anahtar); }
                finally { ekranKopya.Birak(); }
            }
        }
        if (v == null)
        {
            if (ekranKopya != null) { ekranKopya.Dispose(); ekranKopya = null; }
            if (!Masaustu.YakalaHam(kaynak, b, vKare, ref vAra)) return null;
            ulong oz = H264Kodlayici.Ozet(vKare);
            if (!simdiZorla && !anahtar && oz == vOzet) return null;   // degismedi
            vOzet = oz; anahtarIste = false;
            v = kod.Kodla(vKare, anahtar);
        }
        if (v.Length == 0) return null;
        var paket = new byte[v.Length + 1];
        paket[0] = (byte)(H264Kodlayici.AnahtarMi(v) ? 1 : 0);
        Buffer.BlockCopy(v, 0, paket, 1, v.Length);
        vSay++;
        return paket;
    }

    [System.Runtime.InteropServices.DllImport("winmm.dll")] static extern uint timeBeginPeriod(uint ms);
    [System.Runtime.InteropServices.DllImport("winmm.dll")] static extern uint timeEndPeriod(uint ms);
}

// Sunucu (aktarıcı) üzerinden bekleme: /uzak/baglan?rol=pc (HTTP Upgrade: e6uzak)
static class Aktarici
{
    // Bağlantıyı kurar, 101 yanıtını okur; başarısızsa null ve hata metni
    public static TcpClient Bagla(string sunucu, string anahtar, string pcAdi, string lan, out Stream st, out string hata)
    {
        string yol = "/uzak/baglan?rol=pc&ad=" + Uri.EscapeDataString(pcAdi) + "&lan=" + Uri.EscapeDataString(lan);
        var c = Ac(sunucu, anahtar, yol, out st, out hata);
        if (c == null && hata != null)
            hata = hata.IndexOf(" 403 ") >= 0 ? L.T("sunucu parolası hatalı") : hata.IndexOf(" 404 ") >= 0 ? L.T("sunucuda BelleRemote aktarıcısı yok (uzak_sunucuya_yukle.ps1)") : hata;
        return c;
    }

    // Genel: verilen yola HTTP Upgrade (e6uzak) isteği; 101 gelirse ham akış. İzleyici (rol=tel) de bunu kullanır.
    public static TcpClient Ac(string sunucu, string anahtar, string yol, out Stream st, out string hata)
    {
        st = null; hata = null;
        var u = new Uri(sunucu.StartsWith("http") ? sunucu : "http://" + sunucu);
        var c = new TcpClient();
        var ar = c.BeginConnect(u.Host, u.Port, null, null);
        if (!ar.AsyncWaitHandle.WaitOne(10000)) { c.Close(); hata = L.T("zaman aşımı"); return null; }
        c.EndConnect(ar);
        c.NoDelay = true;
        var s = c.GetStream();
        var req = "GET " + yol + " HTTP/1.1\r\nHost: " + u.Host + "\r\nConnection: Upgrade\r\nUpgrade: e6uzak\r\nX-Api-Key: " + anahtar + "\r\n\r\n";
        var b = Encoding.UTF8.GetBytes(req);
        s.Write(b, 0, b.Length);
        // Başlıkları bayt bayt oku (101'den sonrası ham protokol)
        var hdr = new StringBuilder();
        s.ReadTimeout = 15000;
        while (!hdr.ToString().EndsWith("\r\n\r\n"))
        {
            int x = s.ReadByte(); if (x < 0) { hata = L.T("bağlantı kapandı"); c.Close(); return null; }
            hdr.Append((char)x);
            if (hdr.Length > 8192) { hata = L.T("geçersiz yanıt"); c.Close(); return null; }
        }
        string ilk = hdr.ToString().Split('\n')[0].Trim();
        if (ilk.IndexOf(" 101 ") < 0)
        {
            hata = ilk.IndexOf(" 403 ") >= 0 ? L.T("sunucu parolası hatalı (403)") : ilk;
            c.Close(); return null;
        }
        s.ReadTimeout = Timeout.Infinite;
        st = s;
        return c;
    }
}
