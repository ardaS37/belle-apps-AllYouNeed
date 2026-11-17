.pragma library
// On tanimli yer imleri. 13.11.2026'da bilgisayardan tek tek denendi:
//  HTTP grubu: sifresiz http:// ile dogrudan aciliyor (sunucu katmani gerekmez, eski TLS sorunu yok)
//  Symbian grubu: hafif / metin agirlikli siteler; HTTPS olduklari icin "Akilli" modda sunucudan gecer
var SYMBIAN = [
    { b: qsTr("DuckDuckGo (hafif)"), u: "https://html.duckduckgo.com/html/" },
    { b: qsTr("Vikipedi (mobil)"), u: "https://tr.m.wikipedia.org/" },
    { b: qsTr("NPR metin haber"), u: "https://text.npr.org/" },
    { b: qsTr("CNN Lite"), u: "https://lite.cnn.com/" },
    { b: qsTr("CBC Lite"), u: "https://www.cbc.ca/lite" },
    { b: qsTr("Legible News"), u: "https://legiblenews.com/" },
    { b: qsTr("Hacker News"), u: "https://news.ycombinator.com/" },
    { b: qsTr("Reddit (eski)"), u: "https://old.reddit.com/" },
    { b: qsTr("Nitter (Twitter)"), u: "https://nitter.net/" },
    { b: qsTr("VK mobil"), u: "https://m.vk.com/" },
    { b: qsTr("TDK Sözlük"), u: "https://sozluk.gov.tr/" },
    { b: qsTr("BBC Türkçe"), u: "https://www.bbc.com/turkce" },
    { b: qsTr("Döviz (mobil)"), u: "https://m.doviz.com/" },
    { b: qsTr("Gutenberg kitaplar"), u: "https://www.gutenberg.org/" },
    { b: qsTr("NNProject (Symbian)"), u: "http://nnproject.cc/" },
    { b: qsTr("Symbian TLS 1.2 yaması"), u: "http://nnproject.cc/tls/" },
    { b: qsTr("All About Symbian"), u: "https://www.allaboutsymbian.com/" },
    { b: qsTr("Symbian-Freak"), u: "https://www.symbian-freak.com/" }
];
var HTTP = [
    { b: qsTr("FrogFind (arama + sade web)"), u: "http://frogfind.com/" },
    { b: qsTr("68k.news Türkiye"), u: "http://68k.news/index.php?section=nation&loc=TR" },
    { b: qsTr("Wiby (hafif siteler)"), u: "http://wiby.me/" },
    { b: qsTr("Hava: İstanbul (wttr.in)"), u: "http://wttr.in/Istanbul?lang=tr" },
    { b: qsTr("Bing arama"), u: "http://www.bing.com/" },
    { b: qsTr("Wayback Machine"), u: "http://web.archive.org/" },
    { b: qsTr("The Old Net (arşiv)"), u: "http://theoldnet.com/" },
    { b: qsTr("NNProject (uygulamalar)"), u: "http://nnproject.cc/" },
    { b: qsTr("Throwback yer imleri"), u: "http://throwback.kirsle.net/bookmarks" },
    { b: qsTr("TextFiles arşivi"), u: "http://www.textfiles.com/" },
    { b: qsTr("Floodgap (gopher ağ geçidi)"), u: "http://gopher.floodgap.com/" },
    { b: "SDF", u: "http://sdf.org/" },
    { b: "tilde.club", u: "http://tilde.club/" },
    { b: qsTr("İlk web sitesi (CERN)"), u: "http://info.cern.ch/" },
    { b: qsTr("IP adresim"), u: "http://ifconfig.me/" }
];
// Hizli erisim (bos baslangic sayfasi): ilk acilista gosterilen kutular
var HIZLI = [
    { b: qsTr("DuckDuckGo"), u: "https://html.duckduckgo.com/html/" },
    { b: qsTr("Vikipedi"), u: "https://tr.m.wikipedia.org/" },
    { b: "68k.news", u: "http://68k.news/index.php?section=nation&loc=TR" },
    { b: qsTr("Hava"), u: "http://wttr.in/Istanbul?lang=tr" },
    { b: qsTr("FrogFind"), u: "http://frogfind.com/" },
    { b: qsTr("Hacker News"), u: "https://news.ycombinator.com/" },
    { b: "NNProject", u: "http://nnproject.cc/" },
    { b: qsTr("YouTube"), u: "https://m.youtube.com/" }
];
