// Belle sunucu web paneli: /panel
// Her yerden IP + parola ile giris; tum E6/Belle uygulamalarinin web arayuzleri ve basit sunucu yonetimi.
//   /panel/giris          parola sayfasi (cerez verir; parolanin kendisi degil, ondan turetilmis anahtar)
//   /panel                durum + uygulamalar
//   /panel/youtube        BelleTube: arama ve izleme (sunucudaki donusturucuyle)
//   /panel/ai             ApiLauncher: sohbet (sunucudaki anahtarlarla)
//   /panel/tarayici       Belle Browser katmani: okuma modu / vekil / canli sunucu tarayicisi
//   /panel/uzak           Belle Remote: PC'ler ve sunucu tarayicisi canli (WebSocket kopru: /panel/ws)
//   /panel/paketler       Nokia E6 SIS dosyalari (Drive "Nokia E6 SIS")
//   /panel/raporlar       uygulamalardan gelen hata raporlari
//   /panel/yonetim        gunluk, yeniden baslatma, disk
const express = require("express");
const crypto = require("crypto");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFile } = require("child_process");
const { Duplex } = require("stream");

const DATA = path.join(__dirname, "data");
const RAPOR = path.join(DATA, "reports");
const esc = (s) => ("" + (s == null ? "" : s)).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const calistir = (cmd, args, ms) => new Promise((ok) => execFile(cmd, args, { timeout: ms || 8000, maxBuffer: 4 * 1024 * 1024 }, (e, out, err) => ok({ e, out: "" + (out || ""), err: "" + (err || "") })));

const UYGULAMALAR = [
    { ad: "WhatsBelle", alt: "WhatsApp sohbetleri (telefondaki gibi)", url: "/panel/whatsapp", ikon: "💬", renk: "#25D366" },
    { ad: "BelleMail", alt: "Gmail / e-posta", url: "/mail", ikon: "✉️", renk: "#EA4335" },
    { ad: "Drive", alt: "Google Drive dosyaları", url: "/drive", ikon: "☁️", renk: "#4285F4" },
    { ad: "BelleTube", alt: "Ara, akış, abonelikler, listeler", url: "/panel/youtube", ikon: "▶️", renk: "#FF0000" },
    { ad: "ApiLauncher", alt: "GPT, Claude, Gemini, Grok • foto, çizim", url: "/panel/ai", ikon: "✨", renk: "#8E44AD" },
    { ad: "Belle Browser", alt: "Okuma modu, vekil, sunucu tarayıcısı", url: "/panel/tarayici", ikon: "🌐", renk: "#00ACC1" },
    { ad: "Belle Remote", alt: "PC'lerim ve sunucu tarayıcısı (canlı)", url: "/panel/uzak", ikon: "🖥️", renk: "#5BC0EB" },
    { ad: "BelleAppCenter", alt: "Nokia SIS paketleri", url: "/panel/paketler", ikon: "📦", renk: "#FF9800" },
    { ad: "Raporlar", alt: "Uygulama hata raporları", url: "/panel/raporlar", ikon: "🧾", renk: "#795548" },
    { ad: "Yönetim", alt: "Günlük, yeniden başlat, disk", url: "/panel/yonetim", ikon: "⚙️", renk: "#607D8B" }
];

const STIL = `:root{--bg:#f4f6f9;--kart:#fff;--yazi:#1d2330;--ikinci:#6b7385;--cizgi:#e3e7ee;--vurgu:#0b8ad8;--tehlike:#d93025}
@media(prefers-color-scheme:dark){:root{--bg:#0f1318;--kart:#181e26;--yazi:#e8edf3;--ikinci:#8c98a6;--cizgi:#26303b;--vurgu:#5bc0eb}}
*{box-sizing:border-box}body{margin:0;font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;background:var(--bg);color:var(--yazi)}
a{color:var(--vurgu);text-decoration:none}header{position:sticky;top:0;z-index:5;background:var(--kart);border-bottom:1px solid var(--cizgi);display:flex;align-items:center;gap:12px;padding:10px 16px}
header b{font-size:18px}header nav{margin-left:auto;display:flex;gap:14px;flex-wrap:wrap;font-size:14px}main{max-width:1100px;margin:0 auto;padding:16px}
.izgara{display:grid;grid-template-columns:repeat(auto-fill,minmax(210px,1fr));gap:12px}.kart{background:var(--kart);border:1px solid var(--cizgi);border-radius:14px;padding:14px}
a.uyg{display:flex;gap:12px;align-items:center;color:var(--yazi)}a.uyg:hover{border-color:var(--vurgu)}.ik{width:44px;height:44px;border-radius:12px;display:flex;align-items:center;justify-content:center;font-size:22px;flex:none}
.alt{color:var(--ikinci);font-size:13px}h2{font-size:17px;margin:22px 0 10px}.say{font-size:26px;font-weight:600}.cubuk{height:8px;background:var(--cizgi);border-radius:4px;overflow:hidden;margin-top:6px}.cubuk i{display:block;height:100%;background:var(--vurgu)}
input,select,textarea,button{font:inherit;color:inherit}input,select,textarea{background:var(--kart);border:1px solid var(--cizgi);border-radius:10px;padding:9px 11px;width:100%}
button,.btn{background:var(--vurgu);color:#fff;border:0;border-radius:10px;padding:9px 14px;cursor:pointer;display:inline-block}button.ikinci,.btn.ikinci{background:transparent;color:var(--vurgu);border:1px solid var(--cizgi)}button.tehlike{background:var(--tehlike)}
table{width:100%;border-collapse:collapse;font-size:14px}td,th{padding:7px 6px;border-bottom:1px solid var(--cizgi);text-align:left}pre{white-space:pre-wrap;word-break:break-word;font-size:12.5px;background:var(--kart);border:1px solid var(--cizgi);border-radius:10px;padding:10px;max-height:70vh;overflow:auto}
.satir{display:flex;gap:8px;align-items:center}.satir>*{flex:1}.satir>button{flex:none}.rozet{font-size:12px;padding:2px 8px;border-radius:20px;background:var(--cizgi)}.ok{color:#1e9e4a}.hata{color:var(--tehlike)}`;

function sayfa(baslik, icerik, ek) {
    return `<!DOCTYPE html><html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(baslik)} • Belle Sunucu</title><link rel="stylesheet" href="/panel/stil.css"></head><body>
<header><b>Belle Sunucu</b><span class="alt">${esc(baslik)}</span><nav><a href="/panel">Ana sayfa</a><a href="/panel/whatsapp">WhatsBelle</a><a href="/panel/ai">ApiLauncher</a><a href="/panel/uzak">Uzak</a><a href="/panel/yonetim">Yönetim</a><a href="/panel/cikis">Çıkış</a></nav></header>
<main>${icerik}</main>${ek || ""}</body></html>`;
}

module.exports = function (o) {
    const { KEY, TOKEN, safeEqual, katman, tarayici, uzak, drive } = o;
    const router = express.Router();
    const form = express.urlencoded({ extended: false, limit: "8kb" });
    const denemeler = new Map();   // ip -> { n, t }

    router.get("/panel/stil.css", (req, res) => res.type("text/css").set("Cache-Control", "public, max-age=3600").send(STIL));

    router.get("/panel/giris", (req, res) => {
        const hata = req.query.h ? '<p class="hata">Parola hatalı.</p>' : "";
        res.type("html").send(`<!DOCTYPE html><html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Giriş • Belle Sunucu</title>
<link rel="stylesheet" href="/panel/stil.css"></head><body><main style="max-width:380px;margin-top:12vh"><div class="kart"><h2 style="margin-top:0">Belle Sunucu</h2>
<p class="alt">Uygulamalarınıza ve sunucu yönetimine her yerden erişin. Parola, telefondaki uygulamalarda kullandığınız sunucu parolasıdır.</p>${hata}
<form method="post" action="/panel/giris"><input type="password" name="p" placeholder="Sunucu parolası" autofocus autocomplete="current-password"><br><br><button style="width:100%">Giriş</button></form></div></main></body></html>`);
    });
    router.post("/panel/giris", form, (req, res) => {
        const ip = req.ip || "?";
        const d = denemeler.get(ip) || { n: 0, t: Date.now() };
        if (Date.now() - d.t > 10 * 60000) { d.n = 0; d.t = Date.now(); }
        if (d.n >= 8) return res.status(429).type("text/plain").send("Çok fazla hatalı deneme. 10 dakika sonra tekrar deneyin.");
        if (!safeEqual("" + (req.body && req.body.p || ""), KEY)) { d.n++; denemeler.set(ip, d); return res.redirect("/panel/giris?h=1"); }
        denemeler.delete(ip);
        res.set("Set-Cookie", `e6m=${TOKEN}; Path=/; Max-Age=31536000; HttpOnly; SameSite=Lax`);
        res.redirect("/panel");
    });
    router.get("/panel/cikis", (req, res) => {
        res.set("Set-Cookie", "e6m=; Path=/; Max-Age=0; HttpOnly; SameSite=Lax");
        res.redirect("/panel/giris");
    });

    // ---------- durum ----------
    async function durum() {
        const [df, pm2, caddy] = await Promise.all([calistir("df", ["-k", "/"]), calistir("pm2", ["jlist"]), calistir("systemctl", ["is-active", "caddy"])]);
        let disk = null;
        const satir = df.out.trim().split("\n")[1];
        if (satir) { const a = satir.split(/\s+/); disk = { toplam: +a[1] * 1024, kullanilan: +a[2] * 1024 }; }
        let surecler = [];
        try { surecler = JSON.parse(pm2.out).map((p) => ({ ad: p.name, durum: p.pm2_env && p.pm2_env.status, cpu: p.monit && p.monit.cpu, bellek: p.monit && p.monit.memory, yeniden: p.pm2_env && p.pm2_env.restart_time, sure: p.pm2_env && p.pm2_env.pm_uptime })); } catch (e) { }
        return {
            makine: os.hostname(), cekirdek: os.cpus().length, yuk: os.loadavg(), bellek: { toplam: os.totalmem(), bos: os.freemem() },
            acikSure: os.uptime(), node: process.version, surecSure: process.uptime(), surecBellek: process.memoryUsage().rss,
            disk, surecler, caddy: caddy.out.trim() || "bilinmiyor",
            katman: katman && katman.istatistik ? katman.istatistik() : null,
            pcler: uzak && uzak.pcListesi ? uzak.pcListesi() : null
        };
    }
    router.get("/panel/api/durum", async (req, res) => res.json(await durum()));

    router.get("/panel", (req, res) => {
        const kartlar = UYGULAMALAR.map((u) => `<a class="kart uyg" href="${u.url}"><span class="ik" style="background:${u.renk}22">${u.ikon}</span><span><b>${esc(u.ad)}</b><br><span class="alt">${esc(u.alt)}</span></span></a>`).join("");
        res.type("html").send(sayfa("Ana sayfa", `<h2 style="margin-top:4px">Uygulamalar</h2><div class="izgara">${kartlar}</div>
<h2>Sunucu</h2><div class="izgara" id="durum"><div class="kart alt">Yükleniyor…</div></div>`, `<script>
function b(x){return x>1073741824?(x/1073741824).toFixed(1)+' GB':(x/1048576).toFixed(0)+' MB'}
function s(x){x=Math.round(x);var g=Math.floor(x/86400),h=Math.floor(x%86400/3600),d=Math.floor(x%3600/60);return (g?g+' gün ':'')+h+' sa '+d+' dk'}
function kart(t,v,a,o){return '<div class="kart"><div class="alt">'+t+'</div><div class="say">'+v+'</div>'+(a?'<div class="alt">'+a+'</div>':'')+(o!=null?'<div class="cubuk"><i style="width:'+Math.min(100,o)+'%"></i></div>':'')+'</div>'}
function yukle(){fetch('/panel/api/durum').then(function(r){return r.json()}).then(function(d){var h='';
var bk=d.bellek.toplam-d.bellek.bos;h+=kart('Bellek',b(bk)+' / '+b(d.bellek.toplam),'Sunucu süreci: '+b(d.surecBellek),100*bk/d.bellek.toplam);
h+=kart('İşlemci yükü',d.yuk[0].toFixed(2),d.cekirdek+' çekirdek • 5 dk: '+d.yuk[1].toFixed(2),100*d.yuk[0]/d.cekirdek);
if(d.disk)h+=kart('Disk',b(d.disk.kullanilan)+' / '+b(d.disk.toplam),'',100*d.disk.kullanilan/d.disk.toplam);
h+=kart('Açık kalma',s(d.acikSure),'Sunucu uygulaması: '+s(d.surecSure)+' • Node '+d.node);
h+=kart('Servisler',d.surecler.map(function(p){return '<span class="'+(p.durum=='online'?'ok':'hata')+'">●</span> '+p.ad}).join('<br>')||'-','Caddy: '+d.caddy);
if(d.katman)h+=kart('Tarayıcı katmanı',d.katman.istek+' istek',(d.katman.orijinal?'Tasarruf %'+Math.round(100-100*d.katman.giden/d.katman.orijinal):'')+' • '+d.katman.resim+' resim küçültüldü');
if(d.pcler)h+=kart('Belle Remote',d.pcler.pcler.length+' PC çevrimiçi',d.pcler.aktif+' aktif oturum');
document.getElementById('durum').innerHTML=h})}
yukle();setInterval(yukle,10000);</script>`));
    });

    // BelleTube, ApiLauncher ve WhatsBelle sayfalari: panel_uyg.js (telefon uygulamalariyla ayni ozellikler)
    require("./panel_uyg.js")({ router, sayfa });

    // ---------- Tarayici katmani ----------
    router.get("/panel/tarayici", (req, res) => {
        res.type("html").send(sayfa("Belle Browser", `<div class="kart"><form class="satir" onsubmit="return false"><input id="u" placeholder="https://… adres ya da arama"></form><br>
<div class="satir"><button onclick="ac('/tb/oku?u=')">Okuma modu (hafif)</button><button class="ikinci" onclick="ac('/tb/g?u=')">Vekil ile aç</button><button class="ikinci" onclick="location='/panel/uzak?hedef=tarayici'">Canlı sunucu tarayıcısı</button></div></div>
<h2>Katman istatistiği</h2><div class="kart"><pre id="ist">…</pre></div>
<p class="alt">Telefondaki Belle Browser'da "Bağlantı modu" Akıllı ya da Sıkıştırılmış seçilince HTTPS sayfaları ve resimler bu sunucudan geçer: eski TLS/sertifika sorunu kalmaz, resimler küçültülür, reklamlar engellenir.</p>`, `<script>
function hedef(){var u=document.getElementById('u').value.trim();if(!u)return '';if(!/^https?:\\/\\//.test(u))u=/\\s/.test(u)||u.indexOf('.')<0?'https://html.duckduckgo.com/html/?q='+encodeURIComponent(u):'https://'+u;return u}
function ac(p){var u=hedef();if(u)window.open(p+encodeURIComponent(u),'_blank')}
fetch('/tb/durum').then(function(r){return r.json()}).then(function(d){document.getElementById('ist').textContent=JSON.stringify(d,null,2)})</script>`));
    });

    // ---------- Uzak (PC'ler + sunucu tarayicisi) ----------
    router.get("/panel/uzak", (req, res) => {
        const hedef = ("" + (req.query.hedef || "")).replace(/[^\w .-]/g, "").slice(0, 60);
        if (!hedef) {
            const l = uzak && uzak.pcListesi ? uzak.pcListesi() : { pcler: [], aktif: 0 };
            const satirlar = l.pcler.map((p) => `<a class="kart uyg" href="/panel/uzak?hedef=${encodeURIComponent(p.ad)}"><span class="ik" style="background:#5BC0EB22">🖥️</span><span><b>${esc(p.ad)}</b><br><span class="alt">${esc(p.lan || "")} • ${Math.round(p.sure / 60)} dk çevrimiçi</span></span></a>`).join("");
            return res.type("html").send(sayfa("Belle Remote", `<h2 style="margin-top:4px">Bağlanılabilir</h2><div class="izgara">
<a class="kart uyg" href="/panel/uzak?hedef=tarayici"><span class="ik" style="background:#00ACC122">🌐</span><span><b>Sunucu tarayıcısı</b><br><span class="alt">Sunucudaki Chrome (her zaman hazır)</span></span></a>${satirlar}</div>
<p class="alt">PC görünmüyorsa PC'de Belle Remote PC uygulamasının açık ve "Sunucu" bağlantısının etkin olduğunu kontrol edin. Aktif oturum: ${l.aktif}</p>`));
        }
        const tar = hedef === "tarayici";
        // Yeni tam ekran istemci (mobil + PC, cozunurluk / fps secimi). Eskisi: ?eski=1
        if (!req.query.eski) return res.type("html").send(require("./panel_uzak.js").sayfa(hedef, tar));
        res.type("html").send(sayfa(tar ? "Sunucu tarayıcısı" : hedef, `${tar ? `<form class="satir" onsubmit="git();return false" style="margin-bottom:8px"><button type="button" class="ikinci" onclick="kom('geri')">‹</button><button type="button" class="ikinci" onclick="kom('ileri')">›</button><button type="button" class="ikinci" onclick="kom('yenile')">⟳</button><input id="adres" placeholder="Adres ya da arama"><button>Git</button></form>` : ""}
<div class="satir" style="margin-bottom:8px"><span class="alt" id="durum">Bağlanıyor…</span><input id="yazi" placeholder="Yazı gönder (Enter)" style="max-width:340px"><button class="ikinci" onclick="tus('ctrl+alt+delete')" ${tar ? "hidden" : ""}>Ctrl+Alt+Del</button><button class="ikinci" onclick="tam()">Tam ekran</button></div>
<div id="kutu" style="position:relative;background:#000;border-radius:10px;overflow:hidden;outline:none" tabindex="0"><img id="ekran" style="width:100%;display:block;user-select:none;-webkit-user-drag:none" draggable="false"></div>
<p class="alt">Fare: tıkla, sağ tık, tekerlek. Klavye: kutuya tıkladıktan sonra yazdıklarınız doğrudan gider.</p>`,
            `<script>
var HEDEF=${JSON.stringify(hedef)},TAR=${tar ? "true" : "false"};var ws,img=document.getElementById('ekran'),kutu=document.getElementById('kutu'),buf=new Uint8Array(0),eskiUrl=null,sonM=0;
function cer(t,s){var b=new TextEncoder().encode(s||'');var a=new Uint8Array(5+b.length);a[0]=t.charCodeAt(0);a[1]=b.length>>>24;a[2]=(b.length>>>16)&255;a[3]=(b.length>>>8)&255;a[4]=b.length&255;a.set(b,5);if(ws&&ws.readyState==1)ws.send(a)}
function durum(t){document.getElementById('durum').textContent=t}
function bagla(){ws=new WebSocket((location.protocol=='https:'?'wss://':'ws://')+location.host+'/panel/ws?hedef='+encodeURIComponent(HEDEF));ws.binaryType='arraybuffer';
ws.onopen=function(){var g=Math.min(1600,Math.round(kutu.clientWidth*(window.devicePixelRatio||1)));var h='istemci=web\\nkip=akis\\nkalite=65\\nfps=8\\nad=Web panel\\ngenislik='+(TAR?Math.min(g,1280):g);
if(TAR)h+='\\ngorunum='+Math.min(g,1280)+'x'+Math.round(Math.min(g,1280)*0.62);cer('H',h);durum('Kimlik doğrulanıyor…')};
ws.onclose=function(){durum('Bağlantı kapandı — yeniden bağlanmak için sayfayı yenileyin')};ws.onerror=function(){durum('Bağlantı hatası')};
ws.onmessage=function(ev){var g=new Uint8Array(ev.data),n=new Uint8Array(buf.length+g.length);n.set(buf);n.set(g,buf.length);buf=n;
while(buf.length>=5){var L=(buf[1]<<24|buf[2]<<16|buf[3]<<8|buf[4])>>>0;if(buf.length<5+L)break;var t=String.fromCharCode(buf[0]),v=buf.slice(5,5+L);buf=buf.slice(5+L);isle(t,v)}}}
function isle(t,v){var m=t=='J'?'':new TextDecoder().decode(v);
if(t=='J'){cer('G');var u=URL.createObjectURL(new Blob([v],{type:'image/jpeg'}));img.onload=function(){if(eskiUrl)URL.revokeObjectURL(eskiUrl);eskiUrl=u};img.src=u}
else if(t=='O'){durum('Bağlı: '+((/ad=([^\\n]*)/.exec(m)||[])[1]||HEDEF));cer('S','masaustu');cer('F')}
else if(t=='N')durum('Reddedildi: '+m);else if(t=='M')durum(m);
else if(t=='R'){var a=m.split('\\n');var ad=document.getElementById('adres');if(ad&&document.activeElement!=ad)ad.value=a[0]||'';document.title=(a[1]||'Sunucu tarayıcısı')+' • Belle'}
else if(t=='D'){var d=m.split('\\t');if(confirm('İndirme hazır: '+d[1]+'\\nDrive\\'a yüklensin mi?'))cer('d','drive '+d[0])}}
function xy(ev){var r=img.getBoundingClientRect();var x=Math.round(Math.max(0,Math.min(1,(ev.clientX-r.left)/r.width))*10000),y=Math.round(Math.max(0,Math.min(1,(ev.clientY-r.top)/r.height))*10000);return x+' '+y}
img.addEventListener('mousemove',function(ev){var t=Date.now();if(t-sonM<40)return;sonM=t;cer('I','M '+xy(ev))});
img.addEventListener('mousedown',function(ev){ev.preventDefault();kutu.focus();cer('I','D '+(ev.button==2?'R':ev.button==1?'M':'L')+' '+xy(ev))});
img.addEventListener('mouseup',function(ev){ev.preventDefault();cer('I','U '+(ev.button==2?'R':ev.button==1?'M':'L')+' '+xy(ev))});
img.addEventListener('contextmenu',function(ev){ev.preventDefault()});
img.addEventListener('wheel',function(ev){ev.preventDefault();cer('I',(ev.shiftKey?'X ':'W ')+(ev.deltaY>0?-1:1))},{passive:false});
var dokun=null;img.addEventListener('touchstart',function(ev){var t=ev.touches[0];dokun={x:t.clientX,y:t.clientY,z:Date.now()}},{passive:true});
img.addEventListener('touchend',function(ev){if(!dokun)return;var t=ev.changedTouches[0];var dy=t.clientY-dokun.y;if(Math.abs(dy)>30)cer('I','W '+(dy<0?-3:3));else cer('I','C L '+xy(t));dokun=null},{passive:true});
var OZEL={Enter:'enter',Backspace:'backspace',Tab:'tab',Escape:'esc',Delete:'delete',ArrowUp:'up',ArrowDown:'down',ArrowLeft:'left',ArrowRight:'right',Home:'home',End:'end',PageUp:'pageup',PageDown:'pagedown',F5:'f5'};
function tus(k){cer('I','K '+k)}
kutu.addEventListener('keydown',function(ev){var k=OZEL[ev.key];var mod=(ev.ctrlKey?'ctrl+':'')+(ev.altKey?'alt+':'')+(ev.metaKey?'win+':'');
if(k){ev.preventDefault();tus(mod+(ev.shiftKey&&mod?'shift+':'')+k)}else if(mod&&ev.key.length==1){ev.preventDefault();tus(mod+ev.key.toLowerCase())}else if(ev.key.length==1){ev.preventDefault();cer('Y',ev.key)}});
document.getElementById('yazi').addEventListener('keydown',function(ev){if(ev.key=='Enter'){ev.preventDefault();cer('Y',this.value+'\\n');this.value=''}});
function git(){var a=document.getElementById('adres');cer('U',a.value);a.blur();kutu.focus()}function kom(k){cer('B',k)}
function tam(){(kutu.requestFullscreen||kutu.webkitRequestFullscreen).call(kutu)}
setInterval(function(){cer('P',''+Math.floor(Date.now()/1000))},10000);bagla();</script>`));
    });

    // ---------- Paketler (Drive "Nokia E6 SIS") ----------
    router.get("/panel/paketler", async (req, res) => {
        let govde = "";
        try {
            if (!drive || !drive.apiJson) throw new Error("Drive modülü yok");
            const k = await drive.apiJson("GET", "files", { q: "name='Nokia E6 SIS' and mimeType='application/vnd.google-apps.folder' and trashed=false", fields: "files(id)", pageSize: 1 });
            if (!k.files || !k.files.length) throw new Error("Drive'da 'Nokia E6 SIS' klasörü yok");
            const l = await drive.apiJson("GET", "files", { q: `'${k.files[0].id}' in parents and trashed=false`, fields: "files(id,name,size,modifiedTime,description)", orderBy: "name", pageSize: 200 });
            govde = `<div class="kart"><table><tr><th>Paket</th><th>Boyut</th><th>Güncellendi</th><th></th></tr>${(l.files || []).map((f) => `<tr><td><b>${esc(f.name)}</b>${f.description ? `<br><span class="alt">${esc(f.description)}</span>` : ""}</td><td>${f.size ? Math.round(f.size / 1024) + " KB" : ""}</td><td class="alt">${esc((f.modifiedTime || "").replace("T", " ").slice(0, 16))}</td><td><a class="btn ikinci" href="/drive/dl/${encodeURIComponent(f.id)}">İndir</a></td></tr>`).join("")}</table></div>`;
        } catch (e) { govde = `<div class="kart hata">${esc(e.message)}</div>`; }
        res.type("html").send(sayfa("BelleAppCenter paketleri", `<p class="alt">Telefona kurmak için SIS dosyasını indirip telefona aktarın ya da telefonda BelleAppCenter'i kullanın.</p>${govde}`));
    });

    // ---------- Raporlar ----------
    router.get("/panel/raporlar", (req, res) => {
        let l = [];
        try { l = fs.readdirSync(RAPOR).filter((f) => f.endsWith(".txt")).sort().reverse(); } catch (e) { }
        res.type("html").send(sayfa("Raporlar", `<div class="kart"><table>${l.map((f) => `<tr><td><a href="/panel/raporlar/${encodeURIComponent(f)}">${esc(f.replace(/\.txt$/, "").replace(/_/, " • "))}</a></td><td class="alt">${Math.round(fs.statSync(path.join(RAPOR, f)).size / 1024)} KB</td></tr>`).join("") || "<tr><td class='alt'>Rapor yok</td></tr>"}</table></div>`));
    });
    router.get("/panel/raporlar/:ad", (req, res) => {
        const ad = path.basename("" + req.params.ad);
        if (!/^[\w.-]+\.txt$/.test(ad)) return res.status(400).end();
        let t = "";
        try { t = fs.readFileSync(path.join(RAPOR, ad), "utf8"); } catch (e) { return res.status(404).send("Yok"); }
        res.type("html").send(sayfa(ad, `<p><a href="/panel/raporlar">‹ Raporlar</a></p><pre>${esc(t)}</pre>`));
    });

    // ---------- Yonetim ----------
    router.get("/panel/yonetim", async (req, res) => {
        const [log, du] = await Promise.all([calistir("pm2", ["logs", "--nostream", "--lines", "150"], 10000), calistir("du", ["-sh", DATA, path.join(__dirname, "media"), os.tmpdir()], 15000)]);
        res.type("html").send(sayfa("Yönetim", `<div class="izgara"><div class="kart"><b>Sunucu uygulaması</b><p class="alt">Yeniden başlatma 10 saniye kadar sürer; telefon uygulamaları kendiliğinden yeniden bağlanır.</p>
<button class="tehlike" onclick="if(confirm('Sunucu uygulaması yeniden başlatılsın mı?'))fetch('/panel/api/yeniden',{method:'POST',headers:{'X-Panel':'1'}}).then(function(){document.body.innerHTML='<main><div class=kart>Yeniden başlatılıyor… <a href=/panel>Ana sayfa</a></div></main>'})">Yeniden başlat</button></div>
<div class="kart"><b>Disk kullanımı</b><pre>${esc(du.out || du.err)}</pre></div>
<div class="kart"><b>Kısayollar</b><p><a href="/listusers">WhatsApp oturumları</a><br><a href="/drive/setup">Drive bağlantısı</a><br><a href="/yt/setup">YouTube hesabı</a><br><a href="/tb/durum">Tarayıcı katmanı (JSON)</a><br><a href="/panel/api/durum">Sunucu durumu (JSON)</a></p></div></div>
<h2>Günlük (son 150 satır)</h2><pre>${esc((log.out + log.err).replace(/\x1b\[[0-9;]*m/g, ""))}</pre>`));
    });
    router.post("/panel/api/yeniden", (req, res) => {
        if (req.get("x-panel") !== "1") return res.status(400).end();
        console.log("[panel] yeniden baslatma istendi");
        res.json({ ok: true });
        setTimeout(() => process.exit(0), 600);     // pm2 yeniden baslatir
    });

    // ---------- WebSocket kopru: tarayicidaki panel <-> Belle Remote protokolu ----------
    function wsDuplex(sock) {
        let birikmis = Buffer.alloc(0);
        let hDuzeltildi = false, hBuf = Buffer.alloc(0);
        const d = new Duplex({
            read() { },
            write(chunk, enc, cb) { try { sock.write(cerceveWs(chunk, 2)); } catch (e) { } cb(); },
            final(cb) { try { sock.end(cerceveWs(Buffer.alloc(0), 8)); } catch (e) { } cb(); },
            destroy(err, cb) { try { sock.destroy(); } catch (e) { } cb(err); }
        });
        d.setNoDelay = () => { };
        d.remoteAddress = sock.remoteAddress;
        // Ilk cerceve 'H': anahtari sunucu ekler (tarayicidaki sayfa parolayi bilmez, cerezle girdi)
        function ilet(veri) {
            if (hDuzeltildi) return d.push(veri);
            hBuf = Buffer.concat([hBuf, veri]);
            if (hBuf.length < 5) return;
            const n = hBuf.readUInt32BE(1);
            if (hBuf.length < 5 + n) return;
            let ilk = hBuf.slice(0, 5 + n);
            const kalan = hBuf.slice(5 + n);
            if (String.fromCharCode(ilk[0]) === "H") {
                const metin = "anahtar=" + KEY + "\n" + ilk.slice(5).toString("utf8").split("\n").filter((s) => s.indexOf("anahtar=") !== 0).join("\n");
                const b = Buffer.from(metin, "utf8");
                ilk = Buffer.concat([Buffer.from([0x48, b.length >>> 24, (b.length >>> 16) & 255, (b.length >>> 8) & 255, b.length & 255]), b]);
            }
            hDuzeltildi = true;
            d.push(ilk);
            if (kalan.length) d.push(kalan);
        }
        sock.on("data", (c) => {
            birikmis = Buffer.concat([birikmis, c]);
            for (;;) {
                if (birikmis.length < 2) return;
                const op = birikmis[0] & 15, maskeli = birikmis[1] & 128;
                let len = birikmis[1] & 127, o = 2;
                if (len === 126) { if (birikmis.length < 4) return; len = birikmis.readUInt16BE(2); o = 4; }
                else if (len === 127) { if (birikmis.length < 10) return; len = Number(birikmis.readBigUInt64BE(2)); o = 10; }
                if (len > 16 * 1024 * 1024) { sock.destroy(); return; }
                const mo = o; if (maskeli) o += 4;
                if (birikmis.length < o + len) return;
                let veri = birikmis.slice(o, o + len);
                if (maskeli) { const m = birikmis.slice(mo, mo + 4); veri = Buffer.from(veri); for (let i = 0; i < veri.length; i++) veri[i] ^= m[i & 3]; }
                birikmis = birikmis.slice(o + len);
                if (op === 8) { try { sock.end(cerceveWs(Buffer.alloc(0), 8)); } catch (e) { } d.push(null); return; }
                if (op === 9) { try { sock.write(cerceveWs(veri, 10)); } catch (e) { } continue; }
                if (op === 2 || op === 1 || op === 0) ilet(veri);
            }
        });
        sock.on("close", () => { d.push(null); d.destroy(); });
        sock.on("error", () => { d.destroy(); });
        return d;
    }
    function cerceveWs(veri, op) {
        const n = veri.length;
        let bas;
        if (n < 126) bas = Buffer.from([0x80 | op, n]);
        else if (n < 65536) { bas = Buffer.alloc(4); bas[0] = 0x80 | op; bas[1] = 126; bas.writeUInt16BE(n, 2); }
        else { bas = Buffer.alloc(10); bas[0] = 0x80 | op; bas[1] = 127; bas.writeBigUInt64BE(BigInt(n), 2); }
        return Buffer.concat([bas, veri]);
    }
    function attach(server) {
        server.on("upgrade", (req, sock) => {
            let u;
            try { u = new URL(req.url, "http://x"); } catch (e) { return; }
            if (u.pathname !== "/panel/ws") return;
            sock.on("error", () => { });
            const m = /(?:^|;\s*)e6m=([0-9a-f]{64})/.exec(req.headers.cookie || "");
            const key = u.searchParams.get("key") || "";
            if (!((m && safeEqual(m[1], TOKEN)) || safeEqual(key, KEY))) { sock.end("HTTP/1.1 403 Forbidden\r\n\r\n"); return; }
            const wsKey = req.headers["sec-websocket-key"];
            if (!wsKey || ("" + req.headers.upgrade).toLowerCase() !== "websocket") { sock.end("HTTP/1.1 400 Bad Request\r\n\r\n"); return; }
            const hedef = ("" + (u.searchParams.get("hedef") || "")).slice(0, 60);
            const kabul = crypto.createHash("sha1").update(wsKey + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").digest("base64");
            if (hedef !== "tarayici") {
                const l = uzak && uzak.pcListesi ? uzak.pcListesi().pcler : [];
                if (!l.some((p) => p.ad === hedef)) { sock.end("HTTP/1.1 404 Not Found\r\n\r\n"); return; }
            }
            sock.write("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: " + kabul + "\r\n\r\n");
            sock.setNoDelay(true);
            const d = wsDuplex(sock);
            if (hedef === "tarayici") { tarayici.baglan(d, Buffer.alloc(0), KEY); console.log("[panel] web: sunucu tarayicisi"); }
            else if (!uzak.pcBagla(d, hedef, null, "web " + (req.socket.remoteAddress || "?"))) { try { sock.end(cerceveWs(Buffer.alloc(0), 8)); } catch (e) { } }
        });
    }

    return { router, attach };
};
