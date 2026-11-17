// BelleRemote PC - izleyici: bu bilgisayardan başka bir BelleRemote PC'ye bağlanıp onu kontrol etmek.
// Yol: yerel ağ (doğrudan IP:port) ya da sunucu aktarıcısı (/uzak/baglan?rol=tel&hedef=<ad>). Protokol: ..\PROTOKOL.md
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;

class UzakPc { public string Ad, Lan; public int Sure; public override string ToString() { return Ad; } }

// ---------------- Bağlanılacak PC'yi seçme ----------------
class BaglanForm : Form
{
    ListView liste;
    TextBox elleBox;
    ComboBox yolCb, kaliteCb;
    Label durum;
    public IzleyiciForm Acilan;

    public BaglanForm()
    {
        SuspendLayout();
        AutoScaleDimensions = new SizeF(96F, 96F); AutoScaleMode = AutoScaleMode.Dpi;   // %125/%150 ekranda denetimler de büyüsün
        Text = L.T("Başka bir PC'ye bağlan");
        Width = 560; Height = 430;
        StartPosition = FormStartPosition.CenterParent;
        Font = new Font("Segoe UI", 9);
        FormBorderStyle = FormBorderStyle.FixedDialog; MaximizeBox = false; MinimizeBox = false;

        var l1 = new Label { Left = 12, Top = 12, Width = 520, Text = L.T("Sunucuda çevrimiçi PC'ler (o PC'de BelleRemote PC açık ve \"Sunucu üzerinden\" işaretli olmalı):") };
        Controls.Add(l1);
        liste = new ListView { Left = 12, Top = 34, Width = 520, Height = 180, View = View.Details, FullRowSelect = true, HideSelection = false, MultiSelect = false };
        liste.Columns.Add(L.T("PC adı"), 190); liste.Columns.Add(L.T("Yerel ağ adresi"), 170); liste.Columns.Add(L.T("Çevrimiçi"), 130);
        liste.DoubleClick += (s, e) => Baglan();
        Controls.Add(liste);

        var yenile = new Button { Left = 12, Top = 220, Width = 100, Height = 26, Text = L.T("Listeyi yenile") };
        yenile.Click += (s, e) => Yukle(); Controls.Add(yenile);
        durum = new Label { Left = 120, Top = 225, Width = 412, ForeColor = Color.DimGray }; Controls.Add(durum);

        Controls.Add(new Label { Left = 12, Top = 258, Width = 520, Text = L.T("Ya da yerel ağdaki bir PC'nin adresini yazın (listede olmasa da olur):") });
        elleBox = new TextBox { Left = 12, Top = 280, Width = 250 };
        elleBox.KeyDown += (s, e) => { if (e.KeyCode == Keys.Enter) { e.SuppressKeyPress = true; Baglan(); } };
        Controls.Add(elleBox);
        Controls.Add(new Label { Left = 270, Top = 283, Width = 262, ForeColor = Color.DimGray, Text = L.T("örnek: 192.168.1.107  ya da  192.168.1.107:5680") });

        Controls.Add(new Label { Left = 12, Top = 317, Width = 60, Text = L.T("Yol:") });
        yolCb = new ComboBox { Left = 75, Top = 314, Width = 230, DropDownStyle = ComboBoxStyle.DropDownList };
        yolCb.Items.AddRange(new object[] { L.T("Otomatik (önce yerel ağ, olmazsa sunucu)"), L.T("Yalnızca yerel ağ"), L.T("Yalnızca sunucu") });
        yolCb.SelectedIndex = 0; Controls.Add(yolCb);
        Controls.Add(new Label { Left = 315, Top = 317, Width = 50, Text = L.T("Görüntü:") });
        kaliteCb = new ComboBox { Left = 368, Top = 314, Width = 164, DropDownStyle = ComboBoxStyle.DropDownList };
        kaliteCb.Items.AddRange(new object[] { L.T("Otomatik"), L.T("Hızlı (düşük kalite)"), L.T("Dengeli"), L.T("Net (yüksek kalite)") });
        kaliteCb.SelectedIndex = 0; Controls.Add(kaliteCb);

        var baglan = new Button { Left = 352, Top = 352, Width = 90, Height = 28, Text = L.T("Bağlan") };
        baglan.Click += (s, e) => Baglan(); Controls.Add(baglan); AcceptButton = null;
        var kapat = new Button { Left = 448, Top = 352, Width = 84, Height = 28, Text = L.T("Kapat") };
        kapat.Click += (s, e) => Close(); Controls.Add(kapat);

        Shown += (s, e) => Yukle();
        ResumeLayout(false);
    }

    void Yukle()
    {
        durum.Text = L.T("Yükleniyor…");
        liste.Items.Clear();
        new Thread(() =>
        {
            string hata; var l = Izleyici.SunucuListesi(out hata);
            try
            {
                BeginInvoke((Action)(() =>
                {
                    liste.Items.Clear();
                    foreach (var p in l)
                    {
                        bool bu = string.Equals(p.Ad, Ayarlar.PcAdi, StringComparison.OrdinalIgnoreCase);
                        string ad = p.Ad == "tarayici" ? L.T("tarayici (sunucu tarayıcısı)") : p.Ad + (bu ? " (bu PC)" : "");
                        var it = new ListViewItem(new[] { ad, p.Lan, p.Ad == "tarayici" ? L.T("her zaman") : (p.Sure / 60) + " dk" }) { Tag = p };
                        liste.Items.Add(it);
                    }
                    durum.Text = hata != null ? L.T("Liste alınamadı: ") + hata : (liste.Items.Count <= 2 ? L.T("Başka çevrimiçi PC yok. Yerel ağ adresini elle yazabilirsiniz.") : (liste.Items.Count + L.T(" hedef")));
                    foreach (ListViewItem it in liste.Items) if (!it.Text.EndsWith("(bu PC)") && ((UzakPc)it.Tag).Ad != "tarayici") { it.Selected = true; break; }
                }));
            }
            catch { }
        }) { IsBackground = true }.Start();
    }

    void Baglan()
    {
        if (Ayarlar.Anahtar.Length == 0) { MessageBox.Show(this, L.T("Önce ana pencerede sunucu parolasını girip 'Kaydet ve uygula'ya basın."), L.T("BelleRemote PC")); return; }
        UzakPc hedef = null;
        string elle = elleBox.Text.Trim();
        if (elle.Length > 0)
        {
            if (elle.IndexOf(':') < 0) elle += ":5680";
            hedef = new UzakPc { Ad = elle, Lan = elle };
        }
        else if (liste.SelectedItems.Count > 0) hedef = (UzakPc)liste.SelectedItems[0].Tag;
        if (hedef == null) { MessageBox.Show(this, L.T("Listeden bir PC seçin ya da adres yazın."), L.T("BelleRemote PC")); return; }
        int yol = elle.Length > 0 ? 1 : yolCb.SelectedIndex;
        if (hedef.Ad == "tarayici") yol = 2;
        if (yol == 1 && string.IsNullOrEmpty(hedef.Lan)) { MessageBox.Show(this, L.T("Bu PC yerel ağ adresi bildirmemiş; 'Otomatik' ya da 'Yalnızca sunucu' seçin."), L.T("BelleRemote PC")); return; }
        var f = new IzleyiciForm(hedef, yol, kaliteCb.SelectedIndex);
        Acilan = f;
        f.Show();
        Close();
    }
}

// ---------------- Bağlantı ve protokol ----------------
static class Izleyici
{
    public static List<UzakPc> SunucuListesi(out string hata)
    {
        hata = null;
        var l = new List<UzakPc>();
        try
        {
            using (var wc = new WebClient())
            {
                wc.Encoding = Encoding.UTF8;
                wc.Headers["X-Api-Key"] = Ayarlar.Anahtar;
                string j = wc.DownloadString(Ayarlar.Sunucu.TrimEnd('/') + "/uzak/liste");
                foreach (Match m in Regex.Matches(j, "\\{\"ad\":\"((?:[^\"\\\\]|\\\\.)*)\",\"lan\":\"((?:[^\"\\\\]|\\\\.)*)\",\"sure\":(\\d+)"))
                    l.Add(new UzakPc { Ad = Regex.Unescape(m.Groups[1].Value), Lan = Regex.Unescape(m.Groups[2].Value), Sure = int.Parse(m.Groups[3].Value) });
            }
        }
        catch (WebException ex)
        {
            var r = ex.Response as HttpWebResponse;
            hata = r != null && r.StatusCode == HttpStatusCode.Forbidden ? L.T("sunucu parolası hatalı") : ex.Message;
        }
        catch (Exception ex) { hata = ex.Message; }
        return l;
    }

    // Yerel ağ: doğrudan TCP
    public static TcpClient LanBagla(string adres, int msn, out string hata)
    {
        hata = null;
        string host = adres; int port = 5680;
        int i = adres.LastIndexOf(':');
        if (i > 0) { host = adres.Substring(0, i); int.TryParse(adres.Substring(i + 1), out port); }
        var c = new TcpClient();
        try
        {
            var ar = c.BeginConnect(host, port, null, null);
            if (!ar.AsyncWaitHandle.WaitOne(msn)) { c.Close(); hata = L.T("yerel ağda yanıt yok (") + adres + ")"; return null; }
            c.EndConnect(ar);
            c.NoDelay = true;
            return c;
        }
        catch (Exception ex) { try { c.Close(); } catch { } hata = ex.Message; return null; }
    }

    // Hedefin LAN adresi bu PC ile aynı /24 ağda mı (otomatik kipte önce LAN denemek için)
    public static bool AyniAg(string lan)
    {
        if (string.IsNullOrEmpty(lan)) return false;
        string ip = lan.Split(':')[0];
        int k = ip.LastIndexOf('.'); if (k < 0) return false;
        string onek = ip.Substring(0, k + 1);
        foreach (var a in Ayarlar.LanAdresleri()) if (a.StartsWith(onek)) return true;
        return false;
    }
}

// Ekran tuvali: tüm tuşları kendisi alır (Tab, oklar, Alt+F4 dahil karşıya gider)
class Tuval : Control
{
    public Tuval()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.Selectable | ControlStyles.ResizeRedraw, true);
        TabStop = true;
        BackColor = Color.Black;
    }
    protected override bool IsInputKey(Keys k) { return true; }
    protected override void OnMouseDown(MouseEventArgs e) { Focus(); base.OnMouseDown(e); }
}

// ---------------- İzleyici penceresi ----------------
class IzleyiciForm : Form
{
    readonly UzakPc hedef;
    readonly int yolSecim, kaliteSecim;
    Tuval tuval;
    ToolStrip arac;
    ToolStripDropDownButton kaynakBtn, kisayolBtn;
    ToolStripLabel durumLbl;
    ToolStripButton tamBtn;

    TcpClient tcp; Stream st;
    readonly object yazKilit = new object();
    readonly BlockingCollection<KeyValuePair<char, byte[]>> giden = new BlockingCollection<KeyValuePair<char, byte[]>>();
    volatile bool bitti;
    string yol = "";                 // "LAN" | "Sunucu"
    string uzakAd = "";
    Bitmap kare; readonly object kareKilit = new object();
    Size kaynakBoyut;
    long alinanBayt, kareSay, sonBayt, sonKare; DateTime sonOlcum = DateTime.Now;
    DateTime sonHareket = DateTime.MinValue;
    Point sonNokta = new Point(-1, -1);
    System.Windows.Forms.Timer zaman, genislikZaman;
    int istenenGenislik;
    FormWindowState eskiDurum; bool tamEkran;

    public IzleyiciForm(UzakPc h, int yolSecim, int kaliteSecim)
    {
        hedef = h; this.yolSecim = yolSecim; this.kaliteSecim = kaliteSecim;
        Text = L.T("BelleRemote - ") + h.Ad + L.T(" (bağlanıyor…)");
        Width = 1100; Height = 720;
        StartPosition = FormStartPosition.CenterScreen;
        Font = new Font("Segoe UI", 9);
        KeyPreview = false;

        arac = new ToolStrip { GripStyle = ToolStripGripStyle.Hidden, Dock = DockStyle.Top };
        kaynakBtn = new ToolStripDropDownButton(L.T("Kaynak"));
        kaynakBtn.DropDownOpening += (s, e) => { Gonder('L', ""); };
        kaynakBtn.DropDownItems.Add(L.T("Masaüstü"), null, (s, e) => Gonder('S', "masaustu"));
        kisayolBtn = new ToolStripDropDownButton(L.T("Kısayollar"));
        foreach (var k in new[] { "win", "win+d", "win+e", "alt+tab", "alt+f4", "ctrl+shift+esc", "win+l", "prtsc", "volup", "voldown", "mute", "play" })
        {
            string kk = k;
            kisayolBtn.DropDownItems.Add(k, null, (s, e) => { Girdi("K " + kk); tuval.Focus(); });
        }
        var yaziBtn = new ToolStripButton(L.T("Metin gönder"));
        yaziBtn.Click += (s, e) => MetinGonder();
        tamBtn = new ToolStripButton(L.T("Tam ekran (F11)"));
        tamBtn.Click += (s, e) => TamEkran(!tamEkran);
        var yenileBtn = new ToolStripButton(L.T("Yenile"));
        yenileBtn.Click += (s, e) => { Gonder('F', ""); tuval.Focus(); };
        var kesBtn = new ToolStripButton(L.T("Bağlantıyı kes"));
        kesBtn.Click += (s, e) => Close();
        durumLbl = new ToolStripLabel(L.T("Bağlanıyor…")) { Alignment = ToolStripItemAlignment.Right, ForeColor = Color.DimGray };
        arac.Items.AddRange(new ToolStripItem[] { kaynakBtn, kisayolBtn, yaziBtn, new ToolStripSeparator(), yenileBtn, tamBtn, kesBtn, durumLbl });

        tuval = new Tuval { Dock = DockStyle.Fill };
        tuval.Paint += Ciz;
        tuval.MouseMove += (s, e) => Fare("M", e);
        tuval.MouseDown += (s, e) => { if (e.Button == MouseButtons.Middle) Fare("CM", e); else Fare("D", e); };
        tuval.MouseUp += (s, e) => { if (e.Button != MouseButtons.Middle) Fare("U", e); };
        tuval.MouseWheel += (s, e) => { int n = e.Delta / 120; if (n == 0) n = Math.Sign(e.Delta); if (n != 0) Girdi(((ModifierKeys & Keys.Shift) != 0 ? "X " : "W ") + n); };
        tuval.KeyDown += TusAsagi;
        tuval.KeyUp += (s, e) => { e.Handled = true; e.SuppressKeyPress = true; };
        tuval.KeyPress += (s, e) => { e.Handled = true; if (e.KeyChar >= ' ' && e.KeyChar != (char)127) Gonder('Y', e.KeyChar.ToString()); };
        tuval.Resize += (s, e) => { if (genislikZaman != null) { genislikZaman.Stop(); genislikZaman.Start(); } };
        Controls.Add(tuval);
        Controls.Add(arac);

        zaman = new System.Windows.Forms.Timer { Interval = 1000 };
        zaman.Tick += (s, e) => DurumYenile();
        zaman.Start();
        genislikZaman = new System.Windows.Forms.Timer { Interval = 600 };
        genislikZaman.Tick += (s, e) =>
        {
            genislikZaman.Stop();
            int g = Genislik();
            if (st != null && Math.Abs(g - istenenGenislik) > 80) { istenenGenislik = g; Gonder('A', "genislik=" + g); }
        };

        FormClosed += (s, e) => Kapat();
        Shown += (s, e) => { tuval.Focus(); new Thread(Calis) { IsBackground = true, Name = "izleyici" }.Start(); };
    }

    int Genislik() { return Math.Max(640, Math.Min(2560, tuval.ClientSize.Width)); }

    // Kalite seçimi: 0 otomatik (yola göre), 1 hızlı, 2 dengeli, 3 net
    void Ayarlar_(bool lan, out int fps, out int kalite)
    {
        switch (kaliteSecim)
        {
            case 1: fps = lan ? 12 : 6; kalite = 30; break;
            case 2: fps = lan ? 15 : 8; kalite = 50; break;
            case 3: fps = lan ? 20 : 8; kalite = 75; break;
            default: fps = lan ? 15 : 8; kalite = lan ? 60 : 42; break;
        }
    }

    void Durum(string s)
    {
        if (IsDisposed) return;
        try { BeginInvoke((Action)(() => { durumLbl.Text = s; })); } catch { }
    }

    void Calis()
    {
        string hata = null;
        // 1) Yerel ağ (otomatik kipte yalnız aynı ağdaysa ya da adres elle verildiyse)
        bool lanDene = yolSecim == 1 || (yolSecim == 0 && !string.IsNullOrEmpty(hedef.Lan) && Izleyici.AyniAg(hedef.Lan));
        if (lanDene)
        {
            Durum(L.T("Yerel ağdan bağlanıyor: ") + hedef.Lan);
            tcp = Izleyici.LanBagla(hedef.Lan, yolSecim == 1 ? 6000 : 2500, out hata);
            if (tcp != null) { st = tcp.GetStream(); yol = "LAN"; }
        }
        // 2) Sunucu aktarıcısı
        if (tcp == null && yolSecim != 1)
        {
            Durum(L.T("Sunucu üzerinden bağlanıyor…"));
            string h2;
            Stream s2;
            try { tcp = Aktarici.Ac(Ayarlar.Sunucu, Ayarlar.Anahtar, "/uzak/baglan?rol=tel&hedef=" + Uri.EscapeDataString(hedef.Ad), out s2, out h2); }
            catch (Exception ex) { s2 = null; h2 = ex.Message; }
            if (tcp != null) { st = s2; yol = L.T("Sunucu"); }
            else hata = (hata != null ? hata + "; " : "") + (h2 != null && h2.IndexOf("404") >= 0 ? L.T("sunucuda bu adda bekleyen PC yok") : h2);
        }
        if (tcp == null) { Hata(L.T("Bağlanılamadı: ") + hata); return; }

        bool lan = yol == "LAN";
        int fps, kalite; Ayarlar_(lan, out fps, out kalite);
        int gen = 0;
        try { Invoke((Action)(() => gen = Genislik())); } catch { return; }
        istenenGenislik = gen;
        new Thread(Yazici) { IsBackground = true, Name = "izleyici-yaz" }.Start();
        Gonder('H', "anahtar=" + Ayarlar.Anahtar + "\nistemci=pc\nkip=akis\nfps=" + fps + "\nkalite=" + kalite + "\ngenislik=" + gen + "\nad=" + Ayarlar.PcAdi + " (PC)");
        Durum(L.T("Kimlik doğrulanıyor (") + yol + ")…");
        DateTime sonPing = DateTime.Now;
        try
        {
            while (!bitti)
            {
                char tur; byte[] veri;
                if (!Cerceve.Al(st, out tur, out veri)) break;
                switch (tur)
                {
                    case 'O':
                        var m = Regex.Match(Encoding.UTF8.GetString(veri), "ad=([^\n]*)");
                        uzakAd = m.Success ? m.Groups[1].Value : hedef.Ad;
                        try { BeginInvoke((Action)(() => Text = L.T("BelleRemote - ") + uzakAd + " (" + yol + ")")); } catch { }
                        Durum(L.T("Bağlı (") + yol + ")");
                        break;
                    case 'N': Hata("Karşı PC reddetti: " + Encoding.UTF8.GetString(veri) + "\n(İki PC'de de aynı sunucu parolası olmalı.)"); return;
                    case 'J':
                        Gonder('G', "");
                        alinanBayt += veri.Length; kareSay++;
                        try
                        {
                            var b = new Bitmap(new MemoryStream(veri));
                            lock (kareKilit) { var eski = kare; kare = b; kaynakBoyut = b.Size; if (eski != null) eski.Dispose(); }
                            tuval.Invalidate();
                        }
                        catch { }
                        break;
                    case 'L': PencereListesi(Encoding.UTF8.GetString(veri)); break;
                    case 'M': Durum(Encoding.UTF8.GetString(veri)); break;
                    case 'K': case 'T': case 'P': break;
                }
                if ((DateTime.Now - sonPing).TotalSeconds > 10) { sonPing = DateTime.Now; Gonder('P', DateTime.Now.Ticks.ToString()); }
            }
        }
        catch (Exception ex) { if (!bitti) Hata(L.T("Bağlantı koptu: ") + ex.Message); return; }
        if (!bitti) Hata(L.T("Bağlantı kapandı."));
    }

    void Yazici()
    {
        try
        {
            foreach (var c in giden.GetConsumingEnumerable())
            {
                if (bitti || st == null) break;
                Cerceve.Gonder(st, yazKilit, c.Key, c.Value);
            }
        }
        catch { if (!bitti) Hata(L.T("Bağlantı koptu (gönderilemedi).")); }
    }

    void Gonder(char tur, string metin)
    {
        if (bitti || st == null) return;
        try { giden.Add(new KeyValuePair<char, byte[]>(tur, Encoding.UTF8.GetBytes(metin ?? ""))); } catch { }
    }
    void Girdi(string satir) { Gonder('I', satir); }

    void Hata(string s)
    {
        bool ilk = !bitti;
        Kapat();
        if (!ilk || IsDisposed) return;
        try { BeginInvoke((Action)(() => { durumLbl.Text = L.T("Bağlantı yok"); MessageBox.Show(this, s, "BelleRemote"); Close(); })); } catch { }
    }

    void Kapat()
    {
        if (bitti) return;
        bitti = true;
        try { giden.CompleteAdding(); } catch { }
        try { if (tcp != null) tcp.Close(); } catch { }
    }

    void PencereListesi(string metin)
    {
        try
        {
            BeginInvoke((Action)(() =>
            {
                kaynakBtn.DropDownItems.Clear();
                kaynakBtn.DropDownItems.Add(L.T("Masaüstü (tüm ekran)"), null, (s, e) => Gonder('S', "masaustu"));
                kaynakBtn.DropDownItems.Add(L.T("Ekran 2"), null, (s, e) => Gonder('S', "ekran:1"));
                kaynakBtn.DropDownItems.Add(new ToolStripSeparator());
                foreach (var satir in metin.Split('\n'))
                {
                    int i = satir.IndexOf('\t'); if (i <= 0) continue;
                    string no = satir.Substring(0, i), baslik = satir.Substring(i + 1);
                    if (baslik.Length > 70) baslik = baslik.Substring(0, 70) + "…";
                    kaynakBtn.DropDownItems.Add(baslik, null, (s, e) => Gonder('S', "pencere:" + no));
                }
            }));
        }
        catch { }
    }

    // Görüntünün tuvaldeki yeri (en-boy oranı korunur, ortalanır)
    Rectangle GoruntuAlani()
    {
        var c = tuval.ClientSize;
        if (kaynakBoyut.Width <= 0 || kaynakBoyut.Height <= 0) return new Rectangle(0, 0, c.Width, c.Height);
        double o = Math.Min((double)c.Width / kaynakBoyut.Width, (double)c.Height / kaynakBoyut.Height);
        int w = (int)(kaynakBoyut.Width * o), h = (int)(kaynakBoyut.Height * o);
        return new Rectangle((c.Width - w) / 2, (c.Height - h) / 2, w, h);
    }

    void Ciz(object s, PaintEventArgs e)
    {
        lock (kareKilit)
        {
            if (kare == null)
            {
                TextRenderer.DrawText(e.Graphics, durumLbl.Text, Font, tuval.ClientRectangle, Color.Gray, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
                return;
            }
            var r = GoruntuAlani();
            e.Graphics.InterpolationMode = r.Width >= kare.Width ? InterpolationMode.NearestNeighbor : InterpolationMode.Bilinear;
            e.Graphics.PixelOffsetMode = PixelOffsetMode.Half;
            e.Graphics.DrawImage(kare, r);
        }
    }

    bool Koordinat(Point p, out int x, out int y)
    {
        var r = GoruntuAlani();
        x = y = 0;
        if (kare == null || r.Width <= 0 || r.Height <= 0 || !r.Contains(p)) return false;
        x = (int)Math.Round((p.X - r.Left) * 10000.0 / r.Width);
        y = (int)Math.Round((p.Y - r.Top) * 10000.0 / r.Height);
        x = Math.Max(0, Math.Min(10000, x)); y = Math.Max(0, Math.Min(10000, y));
        return true;
    }

    void Fare(string olay, MouseEventArgs e)
    {
        int x, y;
        if (!Koordinat(e.Location, out x, out y)) return;
        string d = e.Button == MouseButtons.Right ? "R" : "L";
        if (olay == "M")
        {
            if (e.Location == sonNokta) return;
            if ((DateTime.Now - sonHareket).TotalMilliseconds < 30) return;
            sonHareket = DateTime.Now; sonNokta = e.Location;
            Girdi("M " + x + " " + y);
        }
        else if (olay == "CM") Girdi("C M " + x + " " + y);
        else Girdi(olay + " " + d + " " + x + " " + y);
    }

    static readonly Dictionary<Keys, string> Ozel = new Dictionary<Keys, string>
    {
        {Keys.Enter,"enter"},{Keys.Escape,"esc"},{Keys.Tab,"tab"},{Keys.Back,"backspace"},{Keys.Delete,"delete"},{Keys.Insert,"insert"},
        {Keys.Home,"home"},{Keys.End,"end"},{Keys.PageUp,"pgup"},{Keys.PageDown,"pgdn"},{Keys.Up,"up"},{Keys.Down,"down"},{Keys.Left,"left"},{Keys.Right,"right"},
        {Keys.Apps,"menu"},{Keys.PrintScreen,"prtsc"},{Keys.VolumeUp,"volup"},{Keys.VolumeDown,"voldown"},{Keys.VolumeMute,"mute"},
        {Keys.MediaPlayPause,"play"},{Keys.MediaNextTrack,"next"},{Keys.MediaPreviousTrack,"prev"},{Keys.MediaStop,"stop"},
        {Keys.F1,"f1"},{Keys.F2,"f2"},{Keys.F3,"f3"},{Keys.F4,"f4"},{Keys.F5,"f5"},{Keys.F6,"f6"},{Keys.F7,"f7"},{Keys.F8,"f8"},{Keys.F9,"f9"},{Keys.F10,"f10"},{Keys.F12,"f12"}
    };

    void TusAsagi(object s, KeyEventArgs e)
    {
        e.Handled = true;
        if (e.KeyCode == Keys.F11) { TamEkran(!tamEkran); e.SuppressKeyPress = true; return; }
        if (e.KeyCode == Keys.ControlKey || e.KeyCode == Keys.ShiftKey || e.KeyCode == Keys.Menu || e.KeyCode == Keys.LWin || e.KeyCode == Keys.RWin) { e.SuppressKeyPress = true; return; }
        bool ctrl = e.Control, alt = e.Alt, shift = e.Shift;
        bool altGr = ctrl && alt;          // Türkçe Q'da @, €, { gibi işaretler: karakter olarak yazılsın
        string ad;
        if (Ozel.TryGetValue(e.KeyCode, out ad))
        {
            string on = (ctrl ? "ctrl+" : "") + (alt ? "alt+" : "") + (shift ? "shift+" : "");
            Girdi("K " + on + ad);
            e.SuppressKeyPress = true;
            return;
        }
        if ((ctrl || alt) && !altGr)
        {
            string harf = null;
            if (e.KeyCode >= Keys.A && e.KeyCode <= Keys.Z) harf = ((char)('a' + (e.KeyCode - Keys.A))).ToString();
            else if (e.KeyCode >= Keys.D0 && e.KeyCode <= Keys.D9) harf = ((char)('0' + (e.KeyCode - Keys.D0))).ToString();
            else if (e.KeyCode == Keys.Space) harf = "space";
            if (harf != null)
            {
                Girdi("K " + (ctrl ? "ctrl+" : "") + (alt ? "alt+" : "") + (shift ? "shift+" : "") + harf);
                e.SuppressKeyPress = true;
                return;
            }
        }
        // Diğer her şey KeyPress ile karakter olarak gider (Y)
    }

    void MetinGonder()
    {
        using (var f = new Form { Text = "Karşı PC'ye metin gönder", Width = 460, Height = 220, StartPosition = FormStartPosition.CenterParent, Font = Font, FormBorderStyle = FormBorderStyle.FixedDialog, MaximizeBox = false, MinimizeBox = false })
        {
            var tb = new TextBox { Left = 10, Top = 10, Width = 424, Height = 120, Multiline = true, ScrollBars = ScrollBars.Vertical, AcceptsReturn = true };
            var ok = new Button { Left = 264, Top = 140, Width = 80, Text = L.T("Gönder"), DialogResult = DialogResult.OK };
            var ip = new Button { Left = 354, Top = 140, Width = 80, Text = L.T("Vazgeç"), DialogResult = DialogResult.Cancel };
            f.Controls.AddRange(new Control[] { tb, ok, ip }); f.CancelButton = ip;
            if (f.ShowDialog(this) == DialogResult.OK && tb.Text.Length > 0) Gonder('Y', tb.Text.Replace("\r\n", "\n"));
        }
        tuval.Focus();
    }

    void TamEkran(bool ac)
    {
        if (ac == tamEkran) return;
        tamEkran = ac;
        if (ac) { eskiDurum = WindowState; FormBorderStyle = FormBorderStyle.None; WindowState = FormWindowState.Normal; WindowState = FormWindowState.Maximized; arac.Visible = false; }
        else { FormBorderStyle = FormBorderStyle.Sizable; WindowState = eskiDurum; arac.Visible = true; }
        tuval.Focus();
    }

    void DurumYenile()
    {
        if (bitti || st == null || kareSay == 0) return;
        double sn = Math.Max(0.5, (DateTime.Now - sonOlcum).TotalSeconds);
        double kps = (kareSay - sonKare) / sn, kb = (alinanBayt - sonBayt) / 1024.0 / sn;
        sonKare = kareSay; sonBayt = alinanBayt; sonOlcum = DateTime.Now;
        durumLbl.Text = string.Format(L.T("{0} • {1:0.0} kare/sn • {2:0} KB/sn • {3}x{4}"), yol, kps, kb, kaynakBoyut.Width, kaynakBoyut.Height);
    }
}
