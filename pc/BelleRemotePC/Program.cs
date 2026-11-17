// BelleRemote PC - kendi bilgisayarını kendi telefonundan kullanmak için kişisel uzak masaüstü (sunucu tarafı).
// Görünür bir uygulamadır: pencere + bildirim alanı simgesi; oturum açılınca/kapanınca balon bildirimi gösterir.
// Derleme: derle.bat
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

[assembly: System.Reflection.AssemblyTitle("BelleRemote PC")]
[assembly: System.Reflection.AssemblyVersion("1.1.0.0")]

static class Ayarlar
{
    public static string Klasor = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "BelleRemote");
    static string Dosya { get { return Path.Combine(Klasor, "ayarlar.txt"); } }
    static string AnahtarDosya { get { return Path.Combine(Klasor, "anahtar.bin"); } }

    public static string Sunucu = "";
    public static string PcAdi = Environment.MachineName;
    public static int Port = 5680;
    public static bool LanAcik = true, SunucuAcik = true, Tepsiye = true;
    public static string Anahtar = "";

    public static void Yukle()
    {
        try
        {
            if (File.Exists(Dosya))
                foreach (var s in File.ReadAllLines(Dosya))
                {
                    int i = s.IndexOf('='); if (i <= 0) continue;
                    string k = s.Substring(0, i), v = s.Substring(i + 1);
                    if (k == "sunucu") Sunucu = v;
                    else if (k == "ad") PcAdi = v;
                    else if (k == "port") int.TryParse(v, out Port);
                    else if (k == "lan") LanAcik = v == "1";
                    else if (k == "sunucuacik") SunucuAcik = v == "1";
                    else if (k == "tepsi") Tepsiye = v == "1";
                }
        }
        catch { }
        try { Anahtar = Encoding.UTF8.GetString(ProtectedData.Unprotect(File.ReadAllBytes(AnahtarDosya), null, DataProtectionScope.CurrentUser)); }
        catch { Anahtar = ""; }
        // Drive Yükleyici'nin kaydettiği sunucu parolası varsa onu öner (aynı parola)
        if (Anahtar.Length == 0)
        {
            try
            {
                var dy = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "E6DriveYukleyici", "anahtar.bin");
                if (File.Exists(dy)) Anahtar = Encoding.UTF8.GetString(ProtectedData.Unprotect(File.ReadAllBytes(dy), null, DataProtectionScope.CurrentUser));
            }
            catch { }
        }
    }

    public static void Kaydet()
    {
        Directory.CreateDirectory(Klasor);
        File.WriteAllLines(Dosya, new[] {
            "sunucu=" + Sunucu, "ad=" + PcAdi, "port=" + Port,
            "lan=" + (LanAcik ? "1" : "0"), "sunucuacik=" + (SunucuAcik ? "1" : "0"), "tepsi=" + (Tepsiye ? "1" : "0") });
        File.WriteAllBytes(AnahtarDosya, ProtectedData.Protect(Encoding.UTF8.GetBytes(Anahtar), null, DataProtectionScope.CurrentUser));
    }

    // Windows açılışında başlatma: yalnızca kullanıcı bu kutuyu işaretleyince (HKCU\...\Run)
    const string RunYol = @"Software\Microsoft\Windows\CurrentVersion\Run";
    public static bool Acilista
    {
        get { using (var k = Registry.CurrentUser.OpenSubKey(RunYol)) return k != null && k.GetValue("BelleRemote") != null; }
        set
        {
            using (var k = Registry.CurrentUser.CreateSubKey(RunYol))
            {
                if (value) k.SetValue("BelleRemote", "\"" + Application.ExecutablePath + "\" /tepsi");
                else k.DeleteValue("BelleRemote", false);
            }
        }
    }

    public static List<string> LanAdresleri()
    {
        var l = new List<string>();
        foreach (var ni in NetworkInterface.GetAllNetworkInterfaces())
        {
            if (ni.OperationalStatus != OperationalStatus.Up || ni.NetworkInterfaceType == NetworkInterfaceType.Loopback) continue;
            string ad = (ni.Description + " " + ni.Name).ToLowerInvariant();
            if (ad.Contains("virtualbox") || ad.Contains("vmware") || ad.Contains("hyper-v") || ad.Contains("vethernet")) continue;
            foreach (var ua in ni.GetIPProperties().UnicastAddresses)
                if (ua.Address.AddressFamily == AddressFamily.InterNetwork) l.Add(ua.Address.ToString());
        }
        return l;
    }
}

static class Program
{
    [STAThread]
    static void Main(string[] args)
    {
        try { Native.SetProcessDPIAware(); } catch { }
        bool tepside = Array.Exists(args, a => a == "/tepsi");
        // /izle: yalnızca izleyici (başka PC'ye bağlan); ekran paylaşan kopya açıkken de çalışır
        if (Array.Exists(args, a => a == "/izle"))
        {
            try { Native.SetProcessDPIAware(); } catch { }
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Ayarlar.Yukle();
            var bf = new BaglanForm();
            bf.ShowDialog();
            if (bf.Acilan != null && !bf.Acilan.IsDisposed) Application.Run(bf.Acilan);
            return;
        }
        bool yeni;
        using (var m = new Mutex(true, "BelleRemotePC_tek", out yeni))
        {
            if (!yeni) { MessageBox.Show(L.T("BelleRemote PC zaten çalışıyor (bildirim alanında)."), L.T("BelleRemote PC")); return; }
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Ayarlar.Yukle();
            Application.Run(new AnaForm(tepside));
        }
    }
}

class AnaForm : Form
{
    TextBox sunucuBox, anahtarBox, adBox, portBox, gunlukBox, adresBox;
    CheckBox lanCb, sunucuCb, acilisCb, tepsiCb;
    Label lanDurum, sunucuDurum, oturumDurum;
    PictureBox onizleme;
    Button kesBtn, duvarBtn;

    // Windows Güvenlik Duvarı: gelen bağlantı kuralı yoksa telefon yerel ağdan bağlanamaz.
    // Kural yalnızca kullanıcı düğmeye basıp UAC'yi onaylarsa eklenir.
    const string DuvarKurali = "BelleRemote PC";
    static bool DuvarKuraliVar()
    {
        try
        {
            var psi = new System.Diagnostics.ProcessStartInfo("netsh", L.T("advfirewall firewall show rule name=\"") + DuvarKurali + "\"")
            { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true };
            using (var p = System.Diagnostics.Process.Start(psi)) { p.StandardOutput.ReadToEnd(); p.WaitForExit(5000); return p.ExitCode == 0; }
        }
        catch { return true; }
    }
    void DuvarDurumu()
    {
        bool izin = DuvarKuraliVar();
        duvarBtn.Enabled = !izin;
        duvarBtn.Text = izin ? L.T("Duvar izni var") : L.T("Güvenlik duvarı izni");
        if (!izin) Gunluk(L.T("Uyarı: Güvenlik duvarında BelleRemote izni yok; telefon yerel ağdan bağlanamaz. 'Güvenlik duvarı izni'ne basın (sunucu yolu etkilenmez)."));
    }
    void DuvarIzni()
    {
        string exe = Application.ExecutablePath;
        string komut = "/c netsh advfirewall firewall delete rule name=\"" + DuvarKurali + "\" >nul & netsh advfirewall firewall add rule name=\""
                       + DuvarKurali + "\" dir=in action=allow program=\"" + exe + "\" enable=yes profile=any protocol=tcp";
        try
        {
            var psi = new System.Diagnostics.ProcessStartInfo("cmd.exe", komut) { Verb = "runas", UseShellExecute = true, WindowStyle = System.Diagnostics.ProcessWindowStyle.Hidden };
            using (var p = System.Diagnostics.Process.Start(psi)) p.WaitForExit(15000);
            Gunluk(L.T("Güvenlik duvarı kuralı eklendi"));
        }
        catch (Exception ex) { Gunluk(L.T("Güvenlik duvarı izni verilmedi: ") + ex.Message); }
        DuvarDurumu();
    }
    NotifyIcon tepsi;
    System.Windows.Forms.Timer durumTimer;
    readonly bool basiTepside;
    bool gercektenCik;

    TcpListener lan;
    Thread lanThread, sunucuThread;
    volatile bool calisiyor;
    volatile Oturum oturum;
    volatile string sunucuDurumMetni = L.T("kapalı");
    TcpClient bekleyenSunucu;
    long sonBayt; DateTime sonOlcum = DateTime.Now; double kbps, kps; long sonKare;

    public AnaForm(bool tepside)
    {
        basiTepside = tepside;
        Text = L.T("BelleRemote PC");
        Width = 640; Height = 722;
        StartPosition = FormStartPosition.CenterScreen;
        Font = new Font("Segoe UI", 9);
        Icon = SimgeYap(Color.FromArgb(91, 192, 235));
        Kur();
        DuvarDurumu();
        tepsi = new NotifyIcon { Icon = Icon, Text = L.T("BelleRemote PC"), Visible = true };
        var menu = new ContextMenu();
        menu.MenuItems.Add(L.T("Göster"), (s, e) => Goster());
        menu.MenuItems.Add(L.T("Oturumu kes"), (s, e) => OturumuKes());
        menu.MenuItems.Add("-");
        menu.MenuItems.Add(L.T("Çıkış"), (s, e) => { gercektenCik = true; Close(); });
        tepsi.ContextMenu = menu;
        tepsi.DoubleClick += (s, e) => Goster();
        FormClosing += (s, e) =>
        {
            if (!gercektenCik && Ayarlar.Tepsiye && e.CloseReason == CloseReason.UserClosing)
            {
                e.Cancel = true; Hide();
                tepsi.ShowBalloonTip(3000, L.T("BelleRemote PC"), L.T("Arka planda çalışmaya devam ediyor. Çıkmak için simgeye sağ tıklayın."), ToolTipIcon.Info);
                return;
            }
            Durdur(); tepsi.Visible = false;
        };
        durumTimer = new System.Windows.Forms.Timer { Interval = 1000 };
        durumTimer.Tick += (s, e) => DurumYenile();
        durumTimer.Start();
        Shown += (s, e) => { if (basiTepside) Hide(); };
        Baslat();
    }

    static Icon SimgeYap(Color renk)
    {
        var b = new Bitmap(32, 32);
        using (var g = Graphics.FromImage(b))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.Clear(Color.Transparent);
            using (var br = new SolidBrush(renk)) g.FillRectangle(br, 2, 4, 28, 19);
            g.FillRectangle(Brushes.White, 5, 7, 22, 13);
            using (var br = new SolidBrush(renk)) { g.FillRectangle(br, 13, 23, 6, 3); g.FillRectangle(br, 8, 26, 16, 3); }
            g.FillPolygon(Brushes.Black, new[] { new Point(12, 9), new Point(12, 18), new Point(15, 15), new Point(18, 19), new Point(19, 18), new Point(16, 14), new Point(20, 14) });
        }
        return Icon.FromHandle(b.GetHicon());
    }

    void Goster() { Show(); WindowState = FormWindowState.Normal; Activate(); }

    Label Etiket(string t, int x, int y, int w) { var l = new Label { Text = t, Left = x, Top = y + 3, Width = w }; Controls.Add(l); return l; }

    void Kur()
    {
        int y = 10;
        Etiket(L.T("Sunucu:"), 12, y, 90);
        sunucuBox = new TextBox { Left = 105, Top = y, Width = 250, Text = Ayarlar.Sunucu }; Controls.Add(sunucuBox);
        Etiket(L.T("PC adı:"), 365, y, 50);
        adBox = new TextBox { Left = 420, Top = y, Width = 190, Text = Ayarlar.PcAdi }; Controls.Add(adBox);
        y += 28;
        Etiket(L.T("Sunucu parolası:"), 12, y, 95);
        anahtarBox = new TextBox { Left = 105, Top = y, Width = 250, UseSystemPasswordChar = true, Text = Ayarlar.Anahtar }; Controls.Add(anahtarBox);
        var goster = new CheckBox { Left = 360, Top = y + 2, Width = 60, Text = L.T("göster") };
        goster.CheckedChanged += (s, e) => anahtarBox.UseSystemPasswordChar = !goster.Checked; Controls.Add(goster);
        Etiket(L.T("LAN portu:"), 425, y, 65);
        portBox = new TextBox { Left = 492, Top = y, Width = 60, Text = Ayarlar.Port.ToString() }; Controls.Add(portBox);
        y += 30;
        lanCb = new CheckBox { Left = 12, Top = y, Width = 200, Text = L.T("Yerel ağdan bağlantı kabul et"), Checked = Ayarlar.LanAcik }; Controls.Add(lanCb);
        sunucuCb = new CheckBox { Left = 220, Top = y, Width = 260, Text = L.T("Sunucu üzerinden her yerden erişilebilir ol"), Checked = Ayarlar.SunucuAcik }; Controls.Add(sunucuCb);
        y += 24;
        acilisCb = new CheckBox { Left = 12, Top = y, Width = 200, Text = L.T("Windows açılışında başlat") };
        try { acilisCb.Checked = Ayarlar.Acilista; } catch { }
        Controls.Add(acilisCb);
        tepsiCb = new CheckBox { Left = 220, Top = y, Width = 260, Text = L.T("Kapatınca bildirim alanında çalışsın"), Checked = Ayarlar.Tepsiye }; Controls.Add(tepsiCb);
        var uygula = new Button { Left = 492, Top = y - 4, Width = 118, Height = 28, Text = L.T("Kaydet ve uygula") };
        uygula.Click += (s, e) => Uygula(); Controls.Add(uygula);
        y += 32;

        // PC'den PC'ye: bu bilgisayardan başka bir BelleRemote PC'yi kontrol et (yerel ağ ya da sunucu)
        Etiket(L.T("Başka bir PC'yi bu bilgisayardan kontrol edin (yerel ağ ya da sunucu üzerinden):"), 12, y + 2, 470);
        var baglanBtn = new Button { Left = 492, Top = y, Width = 118, Height = 28, Text = L.T("Başka PC'ye bağlan") };
        baglanBtn.Click += (s, e) => { using (var f = new BaglanForm()) f.ShowDialog(this); };
        Controls.Add(baglanBtn);
        y += 34;

        Etiket(L.T("Telefona verilecek adres:"), 12, y, 150);
        adresBox = new TextBox { Left = 165, Top = y, Width = 445, ReadOnly = true }; Controls.Add(adresBox);
        y += 26;
        lanDurum = Etiket(L.T("LAN: -"), 12, y, 470);
        duvarBtn = new Button { Left = 492, Top = y - 2, Width = 118, Height = 26, Text = L.T("Güvenlik duvarı izni") };
        duvarBtn.Click += (s, e) => DuvarIzni(); Controls.Add(duvarBtn);
        y += 26;
        sunucuDurum = Etiket(L.T("Sunucu: -"), 12, y, 600); y += 20;
        oturumDurum = Etiket(L.T("Oturum: yok"), 12, y, 480);
        kesBtn = new Button { Left = 492, Top = y - 2, Width = 118, Height = 26, Text = L.T("Oturumu kes"), Enabled = false };
        kesBtn.Click += (s, e) => OturumuKes(); Controls.Add(kesBtn);
        y += 30;

        onizleme = new PictureBox { Left = 12, Top = y, Width = 598, Height = 280, BorderStyle = BorderStyle.FixedSingle, SizeMode = PictureBoxSizeMode.Zoom, BackColor = Color.Black };
        Controls.Add(onizleme); y += 286;
        gunlukBox = new TextBox { Left = 12, Top = y, Width = 598, Height = 96, Multiline = true, ScrollBars = ScrollBars.Vertical, ReadOnly = true };
        Controls.Add(gunlukBox);
    }

    void Gunluk(string s)
    {
        if (IsDisposed) return;
        if (InvokeRequired) { try { BeginInvoke((Action)(() => Gunluk(s))); } catch { } return; }
        if (gunlukBox.Lines.Length > 300) gunlukBox.Clear();
        gunlukBox.AppendText(DateTime.Now.ToString("HH:mm:ss ") + s + "\r\n");
        try { Directory.CreateDirectory(Ayarlar.Klasor); var gd = Path.Combine(Ayarlar.Klasor, "gunluk.txt");
              if (File.Exists(gd) && new FileInfo(gd).Length > 256 * 1024) File.Delete(gd);
              File.AppendAllText(gd, DateTime.Now.ToString("dd.MM HH:mm:ss ") + s + "\r\n", Encoding.UTF8); } catch { }
    }

    void Uygula()
    {
        Ayarlar.Sunucu = sunucuBox.Text.Trim().TrimEnd('/');
        Ayarlar.PcAdi = adBox.Text.Trim().Length > 0 ? adBox.Text.Trim() : Environment.MachineName;
        int p; Ayarlar.Port = int.TryParse(portBox.Text, out p) && p > 0 && p < 65536 ? p : 5680;
        Ayarlar.Anahtar = anahtarBox.Text.Trim();
        Ayarlar.LanAcik = lanCb.Checked; Ayarlar.SunucuAcik = sunucuCb.Checked; Ayarlar.Tepsiye = tepsiCb.Checked;
        try { Ayarlar.Acilista = acilisCb.Checked; } catch (Exception ex) { Gunluk(L.T("Açılış ayarı yazılamadı: ") + ex.Message); }
        try { Ayarlar.Kaydet(); } catch (Exception ex) { Gunluk(L.T("Ayarlar kaydedilemedi: ") + ex.Message); }
        Gunluk(L.T("Ayarlar kaydedildi, yeniden başlatılıyor"));
        Durdur();
        Baslat();
    }

    void Baslat()
    {
        if (Ayarlar.Anahtar.Length == 0) { Gunluk(L.T("Sunucu parolasını girip 'Kaydet ve uygula'ya basın (telefona da aynı parola girilir).")); }
        calisiyor = true;
        if (Ayarlar.LanAcik && Ayarlar.Anahtar.Length > 0)
        {
            try
            {
                lan = new TcpListener(IPAddress.Any, Ayarlar.Port);
                lan.Start();
                lanThread = new Thread(LanDongusu) { IsBackground = true };
                lanThread.Start();
                Gunluk(L.T("LAN dinleniyor: port ") + Ayarlar.Port);
            }
            catch (Exception ex) { Gunluk(L.T("LAN portu açılamadı: ") + ex.Message); lan = null; }
        }
        if (Ayarlar.SunucuAcik && Ayarlar.Anahtar.Length > 0)
        {
            int k = Interlocked.Increment(ref kusak);   // eski döngü kendi kuşağı geçince durur
            sunucuThread = new Thread(() => SunucuDongusu(k)) { IsBackground = true };
            sunucuThread.Start();
        }
        else sunucuDurumMetni = L.T("kapalı");
        DurumYenile();
    }

    void Durdur()
    {
        calisiyor = false;
        Interlocked.Increment(ref kusak);
        try { if (lan != null) lan.Stop(); } catch { }
        lan = null;
        try { if (bekleyenSunucu != null) bekleyenSunucu.Close(); } catch { }
        OturumuKes();
    }

    void OturumuKes()
    {
        var o = oturum;
        if (o != null) { o.Kapat(); Gunluk(L.T("Oturum kesildi")); }
    }

    string LanMetni()
    {
        var l = Ayarlar.LanAdresleri();
        return l.Count == 0 ? "" : l[0] + ":" + Ayarlar.Port;
    }

    void LanDongusu()
    {
        var dinleyici = lan;
        while (calisiyor && dinleyici != null)
        {
            TcpClient c;
            try { c = dinleyici.AcceptTcpClient(); } catch { break; }
            c.ReceiveTimeout = 0;
            Devral(new Oturum(c, c.GetStream(), "LAN", '\0', null), ((IPEndPoint)c.Client.RemoteEndPoint).Address.ToString());
        }
    }

    int kusak;
    void SunucuDongusu(int benim)
    {
        int bekle = 2000;
        while (calisiyor && Ayarlar.SunucuAcik && benim == kusak)
        {
            Stream st; string hata;
            TcpClient c = null;
            string kayitliLan = LanMetni();
            try { c = Aktarici.Bagla(Ayarlar.Sunucu, Ayarlar.Anahtar, Ayarlar.PcAdi, kayitliLan, out st, out hata); }
            catch (Exception ex) { st = null; hata = ex.Message; }
            if (benim != kusak) { if (c != null) { try { c.Close(); } catch { } } break; }
            if (c == null)
            {
                sunucuDurumMetni = L.T("bağlanamadı: ") + hata + L.T(" (yeniden denenecek)");
                Thread.Sleep(bekle); bekle = Math.Min(60000, bekle * 2);
                continue;
            }
            bekle = 2000;
            bekleyenSunucu = c;
            sunucuDurumMetni = L.T("hazır, telefon bekleniyor (") + Ayarlar.PcAdi + ")";
            Gunluk(L.T("Sunucuda hazır: ") + Ayarlar.Sunucu + " (" + Ayarlar.PcAdi + ")");
            try
            {
                st.ReadTimeout = 70000;   // aktarıcı 25 sn'de bir 'P' gönderir
                while (calisiyor && benim == kusak)
                {
                    char tur; byte[] veri;
                    if (!Cerceve.Al(st, out tur, out veri)) { sunucuDurumMetni = L.T("bağlantı koptu, yeniden bağlanıyor"); break; }
                    if (tur == 'P')
                    {
                        // Ağ değiştiyse (ev / dükkan) yeni yerel adresle yeniden kaydol
                        if (LanMetni() != kayitliLan) { Gunluk(L.T("Yerel ağ adresi değişti, sunucuya yeniden bildiriliyor")); break; }
                        continue;
                    }
                    st.ReadTimeout = Timeout.Infinite;
                    Devral(new Oturum(c, st, L.T("Sunucu"), tur, veri), L.T("sunucu üzerinden"));
                    c = null;
                    break;
                }
            }
            catch (Exception ex) { sunucuDurumMetni = L.T("zaman aşımı/kopma: ") + ex.Message; }
            if (c != null) { try { c.Close(); } catch { } }
            Thread.Sleep(300);
        }
    }

    void Devral(Oturum o, string nereden)
    {
        var eski = oturum;
        if (eski != null) { eski.Kapat(); Gunluk(L.T("Önceki oturum yeni bağlantı için kapatıldı")); }
        o.Gunluk = Gunluk;
        o.Anahtar = () => Ayarlar.Anahtar;
        o.PcAdi = () => Ayarlar.PcAdi;
        o.Onizleme = OnizlemeGoster;
        oturum = o;
        Gunluk(L.T("Bağlantı: ") + nereden + " (" + o.Yol + ")");
        o.Baslat();
        new Thread(() =>
        {
            bool bildirildi = false;
            while (!o.Bitti)
            {
                Thread.Sleep(500);
                if (!bildirildi && o.KareSayisi > 0)
                {
                    bildirildi = true;
                    try { BeginInvoke((Action)(() => tepsi.ShowBalloonTip(4000, L.T("BelleRemote PC"), L.T("Telefon bağlandı: ") + o.IstemciAdi + " (" + o.Yol + L.T(")\nEkran paylaşılıyor."), ToolTipIcon.Info))); } catch { }
                }
            }
            if (oturum == o) oturum = null;
            if (bildirildi) try { BeginInvoke((Action)(() => tepsi.ShowBalloonTip(3000, L.T("BelleRemote PC"), L.T("Oturum bitti: ") + o.IstemciAdi, ToolTipIcon.Info))); } catch { }
            Gunluk(L.T("Oturum bitti: ") + o.IstemciAdi);
        }) { IsBackground = true }.Start();
    }

    void OnizlemeGoster(byte[] jpeg)
    {
        if (!Visible || IsDisposed) return;
        try
        {
            var img = Image.FromStream(new MemoryStream(jpeg));
            BeginInvoke((Action)(() => { var old = onizleme.Image; onizleme.Image = img; if (old != null) old.Dispose(); }));
        }
        catch { }
    }

    void DurumYenile()
    {
        var adr = Ayarlar.LanAdresleri();
        adresBox.Text = (adr.Count > 0 ? L.T("LAN: ") + string.Join(", ", adr.ToArray()) + L.T("  port ") + Ayarlar.Port : L.T("LAN adresi yok")) +
                        L.T("   |   Sunucu: ") + Ayarlar.Sunucu + L.T("  PC adı: ") + Ayarlar.PcAdi;
        lanDurum.Text = L.T("LAN: ") + (lan != null ? L.T("dinleniyor (") + (adr.Count > 0 ? adr[0] : "?") + ":" + Ayarlar.Port + ")" : L.T("kapalı"));
        sunucuDurum.Text = L.T("Sunucu: ") + (Ayarlar.SunucuAcik ? sunucuDurumMetni : L.T("kapalı"));
        var o = oturum;
        if (o != null && !o.Bitti)
        {
            var simdi = DateTime.Now; double sn = Math.Max(0.5, (simdi - sonOlcum).TotalSeconds);
            kbps = (o.GonderilenBayt - sonBayt) / 1024.0 / sn; kps = (o.KareSayisi - sonKare) / sn;
            sonBayt = o.GonderilenBayt; sonKare = o.KareSayisi; sonOlcum = simdi;
            oturumDurum.Text = string.Format(L.T("Oturum: {0} ({1}, {2})  {3:0.0} kare/sn  {4:0} KB/sn"), o.IstemciAdi, o.Yol, o.Kip, kps, kbps);
            kesBtn.Enabled = true;
            tepsi.Text = L.T("BelleRemote PC - paylaşılıyor: ") + (o.IstemciAdi.Length > 30 ? o.IstemciAdi.Substring(0, 30) : o.IstemciAdi);
        }
        else
        {
            oturumDurum.Text = L.T("Oturum: yok");
            kesBtn.Enabled = false; sonBayt = 0; sonKare = 0;
            tepsi.Text = L.T("BelleRemote PC - hazır");
        }
    }
}
