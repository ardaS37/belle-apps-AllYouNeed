// Dil destegi (Turkce / English) - PC uygulamalari (Belle Remote PC, Drive Yukleyici) icin.
// Kaynak metinler Turkcedir; Windows arayuz dili Turkce degilse gomulu "en.txt" sozlugu kullanilir.
// Elle secim: uygulama klasorundeki dil.txt dosyasina "tr" ya da "en" yazin.
// Kullanim: L.T("Kaydet")  ->  "Save"   (csc ... /resource:dil\en.txt,en.txt Dil.cs)
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Reflection;
using System.Text;

static class L
{
    static Dictionary<string, string> sozluk;
    public static bool Ingilizce { get; private set; }

    static L()
    {
        string secim = "";
        try
        {
            string f = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "dil.txt");
            if (File.Exists(f)) secim = File.ReadAllText(f).Trim().ToLowerInvariant();
        }
        catch { }
        if (secim != "tr" && secim != "en") secim = CultureInfo.CurrentUICulture.TwoLetterISOLanguageName == "tr" ? "tr" : "en";
        Ingilizce = secim == "en";
        sozluk = new Dictionary<string, string>();
        if (!Ingilizce) return;
        try
        {
            using (Stream s = Assembly.GetExecutingAssembly().GetManifestResourceStream("en.txt"))
            using (var r = new StreamReader(s, Encoding.UTF8))
            {
                string satir;
                while ((satir = r.ReadLine()) != null)
                {
                    if (satir.Length == 0 || satir[0] == '#') continue;
                    int k = satir.IndexOf('\t');
                    if (k <= 0 || k == satir.Length - 1) continue;
                    sozluk[Coz(satir.Substring(0, k))] = Coz(satir.Substring(k + 1));
                }
            }
        }
        catch { }
    }

    static string Coz(string s)
    {
        if (s.IndexOf('\\') < 0) return s;
        var o = new StringBuilder(s.Length);
        for (int i = 0; i < s.Length; i++)
        {
            if (s[i] == '\\' && i + 1 < s.Length)
            {
                char c = s[++i];
                o.Append(c == 'n' ? '\n' : c == 't' ? '\t' : c == 'r' ? '\r' : c);
            }
            else o.Append(s[i]);
        }
        return o.ToString();
    }

    public static string T(string tr)
    {
        string en;
        return tr != null && sozluk.TryGetValue(tr, out en) ? en : tr;
    }
}
