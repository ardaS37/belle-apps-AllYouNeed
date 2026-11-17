// Sunucu tarayicisi: sunucuda tek sayfali, basliksiz Chrome; telefon BelleRemote protokoluyle kullanir.
// Baglanti: uzak.js aktaricisinda hedef=tarayici. Protokol: Kaynak kod\BelleRemote\PROTOKOL.md (+ tarayici ekleri)
//   Istemci -> sunucu ekleri:  U <adres ya da arama>   B geri|ileri|yenile|dur|ana|reklam1|reklam0|reklamdurum   d telefon|drive|sil <id>
//   Sunucu -> istemci ekleri:  R <adres>\n<baslik>\n<geri:0|1>\n<ileri:0|1>\n<yukleniyor:0|1>
//                              D <id>\t<ad>\t<bayt>   (indirme bitti; istemci telefon / Drive secer)
// Indirilen dosyalar: data/tarayici-indir (24 saat sonra silinir). Telefon icin GET /uzak/indir/<id>.
// Tarayici ilk baglantida acilir, son oturumdan 15 dk sonra kapanir (cerezler data/tarayici-profil'de kalir).
"use strict";
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const express = require("express");

const DATA = path.join(__dirname, "data");
const PROFIL = path.join(DATA, "tarayici-profil");
const INDIR = path.join(DATA, "tarayici-indir");
const CHROME = fs.existsSync("/usr/bin/google-chrome") ? "/usr/bin/google-chrome" : undefined;
// Ana sayfa ve arama: DuckDuckGo. Google, sunucunun veri merkezi IP'sinden gelen aramalara surekli
// "robot degilim" soruyor; google.com adresine yine dogrudan gidilebilir.
const ANA = "https://duckduckgo.com/?kl=tr-tr";
const ARAMA = "https://duckduckgo.com/?kl=tr-tr&q=";
const BOS_KAPAT_MS = 15 * 60 * 1000;
const PAYLASIM_SURE_MS = 24 * 3600 * 1000;

// ---------------- Reklam engelleyici ----------------
// Alan adi listesi: StevenBlack/hosts (reklam + izleme, acik kaynak). 3 gunde bir yenilenir, data/'da saklanir.
// Istek, alan adi ya da ust alan adi listedeyse engellenir. Komutlar: B reklam1 | reklam0 | reklamdurum
const REKLAM_DOSYA = path.join(DATA, "reklam-alanlari.txt");
const REKLAM_KAYNAK = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts";
let reklamAlanlari = new Set();
let reklamAcik = true;
let reklamEngellenen = 0;
function reklamDosyadanYukle() {
    try {
        const satirlar = fs.readFileSync(REKLAM_DOSYA, "utf8").split("\n");
        reklamAlanlari = new Set(satirlar.filter((s) => s));
        log("reklam listesi: " + reklamAlanlari.size + " alan");
    } catch (e) { }
}
async function reklamListesiHazirla() {
    let taze = false;
    try { taze = Date.now() - fs.statSync(REKLAM_DOSYA).mtimeMs < 3 * 86400000; } catch (e) { }
    if (!taze) {
        try {
            const r = await fetch(REKLAM_KAYNAK);
            if (!r.ok) throw new Error("HTTP " + r.status);
            const out = [];
            for (const s of (await r.text()).split("\n")) {
                const m = s.match(/^0\.0\.0\.0\s+([^\s#]+)/);
                if (m && m[1] !== "0.0.0.0") out.push(m[1].toLowerCase());
            }
            if (out.length > 1000) { fs.mkdirSync(DATA, { recursive: true }); fs.writeFileSync(REKLAM_DOSYA, out.join("\n")); }
        } catch (e) { log("reklam listesi indirilemedi: " + e.message); }
    }
    reklamDosyadanYukle();
}
function reklamMi(host) {
    let h = (host || "").toLowerCase();
    while (h) {
        if (reklamAlanlari.has(h)) return true;
        const i = h.indexOf(".");
        if (i < 0) break;
        h = h.slice(i + 1);
    }
    return false;
}

let puppeteer = null;
let browser = null, page = null, cdp = null, bcdp = null;
let aciliyor = null;
let kapatZamanlayici = null;
let oturum = null;                       // tek etkin oturum (yeni baglanti eskisini kapatir)
const indirmeler = new Map();            // guid -> { ad, yol, boyut, tamam, zaman }
let drive = null;                        // drive.js router (uploadOne, apiJson, bagli)
let vw = 800, vh = 600;
let tabanW = 800, tabanH = 600;          // istemcinin istedigi pencere; genis sitelerde vw/vh buyutulur (sigdir)

// Sayfa pencereden genisse (ornegin 1100 px masaustu duzeni) pencereyi sayfa genisligine buyut, oran ayni kalsin
async function sigdir() {
    if (!page) return;
    let sw = 0;
    try { sw = await zamanli(page.evaluate(() => Math.max(document.documentElement.scrollWidth, document.body ? document.body.scrollWidth : 0)), 1500); } catch (e) { return; }
    const enCok = Math.min(1600, Math.round(tabanW * 1.8));
    const hedef = Math.min(enCok, sw);
    if (hedef > vw + 16) {
        vw = hedef; vh = Math.round(hedef * tabanH / tabanW);
        log("sigdir " + vw + "x" + vh + " (sayfa " + sw + ")");
        await page.setViewport({ width: vw, height: vh }).catch(() => { });
        if (oturum) oturum.zorla();
    }
}
async function tabanaDon() {
    if (!page || (vw === tabanW && vh === tabanH)) return;
    vw = tabanW; vh = tabanH;
    await page.setViewport({ width: vw, height: vh }).catch(() => { });
}

function log(s) { console.log("[tarayici] " + s); }

// ---------------- Tarayici yasam dongusu ----------------

async function hazirla() {
    if (browser && browser.isConnected() && page && !page.isClosed()) return;
    if (aciliyor) return aciliyor;
    aciliyor = (async () => {
        if (!puppeteer) puppeteer = require("puppeteer");
        fs.mkdirSync(PROFIL, { recursive: true });
        fs.mkdirSync(INDIR, { recursive: true });
        browser = await puppeteer.launch({
            executablePath: CHROME,
            headless: true,
            userDataDir: PROFIL,
            defaultViewport: { width: vw, height: vh },
            args: ["--no-sandbox", "--disable-dev-shm-usage", "--disable-gpu", "--no-first-run", "--no-default-browser-check",
                   "--mute-audio", "--disable-features=Translate,MediaRouter", "--disable-smooth-scrolling", "--window-size=" + vw + "," + vh, "--lang=tr-TR"]
        });
        const sayfalar = await browser.pages();
        page = sayfalar[0] || await browser.newPage();
        for (let i = 1; i < sayfalar.length; i++) sayfalar[i].close().catch(() => { });
        const ua = (await browser.userAgent()).replace(/HeadlessChrome/g, "Chrome");
        await page.setUserAgent(ua);
        // Turkce siteler ve saat (sunucu Belcika'da; Google Ingilizce/Belcika aciliyordu)
        await page.setExtraHTTPHeaders({ "Accept-Language": "tr-TR,tr;q=0.9,en;q=0.7" });
        await page.emulateTimezone("Europe/Istanbul").catch(() => { });
        // Tek sayfa: yeni sekme acan baglantilar ve window.open ayni sekmede acilsin
        await page.evaluateOnNewDocument(() => {
            document.addEventListener("click", (e) => {
                const a = e.target && e.target.closest ? e.target.closest("a[target]") : null;
                if (a && a.target !== "_self") a.target = "_self";
            }, true);
            // Reklam kutularini gizle (engellenen reklamin bos yeri kalmasin) — genel, dar kapsamli kurallar
            const css = 'ins.adsbygoogle,.adsbygoogle,[id^="div-gpt-ad"],[id^="google_ads"],[id*="_ad_container"],[class*="ad-slot"],[class*="adslot"],' +
                '[class*="ad-container"],[class*="ad-wrapper"],[class*="reklam-alani"],[id*="reklam"],[class*="reklam"],' +
                'iframe[src*="doubleclick"],iframe[src*="googlesyndication"],iframe[id^="google_ads_iframe"],[data-ad-slot],[data-google-query-id]' +
                '{display:none!important;height:0!important;min-height:0!important}';
            const ekle = () => { if (!document.getElementById("__br_reklam")) { const s = document.createElement("style"); s.id = "__br_reklam"; s.textContent = css; (document.head || document.documentElement).appendChild(s); } };
            if (document.documentElement) ekle(); else document.addEventListener("DOMContentLoaded", ekle);
            document.addEventListener("DOMContentLoaded", ekle);
            const eski = window.open;
            window.open = function (u) { if (u) { location.href = u; return window; } return eski.apply(window, arguments); };
        });
        await page.setViewport({ width: vw, height: vh });
        // Reklam engelleyici: istekleri alan adi listesine gore engelle
        if (!reklamAlanlari.size) await reklamListesiHazirla();
        await page.setRequestInterception(true);
        page.on("request", (req) => {
            if (req.isInterceptResolutionHandled && req.isInterceptResolutionHandled()) return;
            if (reklamAcik && reklamAlanlari.size) {
                let host = "";
                try { host = new URL(req.url()).hostname; } catch (e) { }
                if (host && reklamMi(host)) { reklamEngellenen++; req.abort("blockedbyclient").catch(() => { }); return; }
            }
            req.continue().catch(() => { });
        });
        cdp = await page.target().createCDPSession();
        bcdp = await browser.target().createCDPSession();
        await bcdp.send("Browser.setDownloadBehavior", { behavior: "allowAndName", downloadPath: INDIR, eventsEnabled: true });
        bcdp.on("Browser.downloadWillBegin", (e) => {
            indirmeler.set(e.guid, { ad: guvenliAd(e.suggestedFilename || "dosya"), yol: path.join(INDIR, e.guid), boyut: 0, tamam: false, zaman: Date.now() });
            if (oturum) oturum.mesaj("Ä°ndiriliyor: " + (e.suggestedFilename || "dosya"));
        });
        bcdp.on("Browser.downloadProgress", (e) => {
            const d = indirmeler.get(e.guid);
            if (!d) return;
            if (e.state === "completed") {
                d.tamam = true;
                try { d.boyut = fs.statSync(d.yol).size; } catch (x) { d.boyut = e.receivedBytes || 0; }
                log("indirme bitti " + d.ad + " " + d.boyut);
                if (oturum) oturum.gonder("D", e.guid + "\t" + d.ad + "\t" + d.boyut);
            } else if (e.state === "canceled") {
                indirmeler.delete(e.guid);
                if (oturum) oturum.mesaj("Ä°ndirme iptal edildi");
            }
        });
        // Tek sayfa: yeni pencere / sekme acilirsa adresini ana sayfada ac
        browser.on("targetcreated", async (t) => {
            if (t.type() !== "page") return;
            let p = null;
            try { p = await t.page(); } catch (x) { }
            if (!p || p === page) return;
            // yedek: yeni sekmenin adresi belli olana kadar bekle (en cok 8 sn), sonra ana sayfada ac
            let u = "";
            for (let i = 0; i < 16; i++) {
                await bekle(500);
                try { u = p.url(); } catch (x) { break; }
                if (u && u !== "about:blank") break;
            }
            try { await p.close(); } catch (x) { }
            if (u && u !== "about:blank") page.goto(u, { waitUntil: "domcontentloaded", timeout: 45000 }).catch(() => { });
        });
        page.on("framenavigated", (f) => { if (f === page.mainFrame()) { tabanaDon(); if (oturum) oturum.adresBildir(true); } });
        page.on("domcontentloaded", () => { setTimeout(sigdir, 300); });
        page.on("load", () => { sigdir(); if (oturum) { oturum.adresBildir(false); oturum.zorla(); } });
        page.on("dialog", (d) => { if (oturum) oturum.mesaj("Sayfa iletiÅŸim kutusu: " + d.message().substring(0, 120)); d.accept().catch(() => { }); });
        if (page.url() === "about:blank") page.goto(ANA, { waitUntil: "domcontentloaded", timeout: 45000 }).catch(() => { });
        browser.on("disconnected", () => { browser = null; page = null; log("tarayici kapandi"); });
        log("tarayici acildi");
    })();
    try { await aciliyor; } finally { aciliyor = null; }
}

function bosKapatmayiKur() {
    if (kapatZamanlayici) clearTimeout(kapatZamanlayici);
    kapatZamanlayici = setTimeout(async () => {
        if (oturum || !browser) return;
        log("bos, kapatiliyor");
        try { await browser.close(); } catch (e) { }
        browser = null; page = null;
    }, BOS_KAPAT_MS);
}

function guvenliAd(s) { return ("" + s).replace(/[\\/:*?"<>|\x00-\x1f]/g, "_").slice(0, 120) || "dosya"; }

function eskiIndirmeleriSil() {
    const simdi = Date.now();
    for (const [id, d] of indirmeler) if (simdi - d.zaman > PAYLASIM_SURE_MS) { try { fs.unlinkSync(d.yol); } catch (e) { } indirmeler.delete(id); }
}
setInterval(eskiIndirmeleriSil, 3600 * 1000).unref();

// ---------------- Cerceve ----------------

function cerceve(tur, veri) {
    const b = Buffer.isBuffer(veri) ? veri : Buffer.from(veri || "", "utf8");
    const h = Buffer.alloc(5);
    h[0] = tur.charCodeAt(0);
    h.writeUInt32BE(b.length, 1);
    return Buffer.concat([h, b]);
}

// ---------------- Oturum ----------------

class Oturum {
    constructor(sock, KEY) {
        this.sock = sock; this.KEY = KEY;
        this.buf = Buffer.alloc(0);
        this.dogrulandi = false; this.bitti = false;
        this.kip = "paket"; this.fps = 1; this.genislik = 640; this.kalite = 40;
        this.bolge = [0, 0, 10000, 10000];
        this.bekleyen = 0; this.zorlaBayrak = true; this.sonOzet = ""; this.sonKare = 0;
        this.yaziAlani = false; this.fx = vw / 2; this.fy = vh / 2;
        this.kuyruk = Promise.resolve();
        sock.setNoDelay(true);
        sock.on("data", (d) => this.veri(d));
        sock.on("close", () => this.kapat("soket kapandi"));
        sock.on("error", () => this.kapat("soket hatasi"));
    }
    gonder(tur, veri) { if (!this.bitti) { try { this.sock.write(cerceve(tur, veri)); } catch (e) { this.kapat("yazma"); } } }
    mesaj(m) { this.gonder("M", m); }
    zorla() { this.zorlaBayrak = true; this.sonOzet = ""; }
    kapat(neden) {
        if (this.bitti) return;
        this.bitti = true;
        clearInterval(this.zaman);
        try { this.sock.destroy(); } catch (e) { }
        if (oturum === this) { oturum = null; bosKapatmayiKur(); }
        log("oturum bitti: " + neden);
    }
    veri(d) {
        this.buf = Buffer.concat([this.buf, d]);
        while (this.buf.length >= 5) {
            const n = this.buf.readUInt32BE(1);
            if (n > 4 * 1024 * 1024) { this.kapat("bozuk cerceve"); return; }
            if (this.buf.length < 5 + n) break;
            const tur = String.fromCharCode(this.buf[0]);
            const v = this.buf.slice(5, 5 + n);
            this.buf = this.buf.slice(5 + n);
            // girdiler sirayla islensin (tiklama, yazi, kare)
            this.kuyruk = this.kuyruk.then(() => this.isle(tur, v)).catch((e) => log("isle hatasi " + tur + ": " + e.message));
        }
    }
    ayar(metin) {
        for (const s of metin.split("\n")) {
            const i = s.indexOf("="); if (i < 0) continue;
            const k = s.slice(0, i).trim(), v = s.slice(i + 1).trim(), n = parseInt(v, 10);
            if (k === "kip" && (v === "paket" || v === "akis")) this.kip = v;
            else if (k === "fps" && !isNaN(n)) this.fps = Math.max(0, Math.min(60, n));     // web paneli 60 fps isteyebilir (Nokia 1-8 gonderir)
            else if (k === "genislik" && !isNaN(n)) this.genislik = Math.max(160, Math.min(1920, n));
            else if (k === "kalite" && !isNaN(n)) this.kalite = Math.max(10, Math.min(95, n));
            else if (k === "gorunum") {   // istemcinin ekran alanina uygun tarayici penceresi: GxY
                const m = v.match(/^(\d+)x(\d+)$/);
                if (m) {
                    const w = Math.max(320, Math.min(1920, +m[1])), h = Math.max(240, Math.min(2400, +m[2]));
                    if (w !== tabanW || h !== tabanH) {
                        tabanW = w; tabanH = h; vw = w; vh = h;
                        log("gorunum " + vw + "x" + vh);
                        if (page) page.setViewport({ width: vw, height: vh }).then(() => { this.zorla(); return sigdir(); }).catch(() => { });
                    }
                }
            }
        }
    }
    px(x, y) {   // onbinde bir (bolgeye gore degil, tum sayfaya gore) -> piksel
        return [Math.round(x * vw / 10000), Math.round(y * vh / 10000)];
    }
    async isle(tur, v) {
        const metin = tur === "J" ? "" : v.toString("utf8");
        if (!this.dogrulandi) {
            if (tur !== "H") return;
            const a = {};
            for (const s of metin.split("\n")) { const i = s.indexOf("="); if (i > 0) a[s.slice(0, i)] = s.slice(i + 1); }
            const k = a.anahtar || "";
            const ok = require("./anahtar.js").ok(k);     // asil ya da ikinci parola
            if (!ok) { this.gonder("N", "Parola hatalÄ±"); setTimeout(() => this.kapat("parola"), 300); return; }
            this.dogrulandi = true;
            this.ayar(metin);
            if (oturum && oturum !== this) oturum.kapat("yeni baglanti");
            oturum = this;
            if (kapatZamanlayici) { clearTimeout(kapatZamanlayici); kapatZamanlayici = null; }
            this.gonder("O", "ad=Sunucu TarayÄ±cÄ±\nekranlar=1\nsurum=1\ntarayici=1");
            log("oturum: " + (a.ad || "?") + " " + this.kip + " " + this.fps + "fps " + this.genislik + "px");
            this.mesaj("TarayÄ±cÄ± aÃ§Ä±lÄ±yorâ€¦");
            try { await hazirla(); } catch (e) { this.mesaj("TarayÄ±cÄ± aÃ§Ä±lamadÄ±: " + e.message); log("acilamadi " + e.stack); this.kapat("acilamadi"); return; }
            this.mesaj("Kaynak: Sunucu TarayÄ±cÄ±");
            this.adresBildir(false);
            // bekleyen (bitmis) indirmeleri hatirlat
            for (const [id, d] of indirmeler) if (d.tamam) this.gonder("D", id + "\t" + d.ad + "\t" + d.boyut);
            this.zaman = setInterval(() => { this.kareDongusu().catch(() => { }); }, 120);
            return;
        }
        if (!page) { try { await hazirla(); } catch (e) { return; } }
        switch (tur) {
            case "G": if (this.bekleyen > 0) this.bekleyen--; break;
            case "F": this.zorla(); break;
            case "P": this.gonder("P", v); break;
            case "A": this.ayar(metin); this.zorla(); break;
            case "L": this.gonder("L", "0\t" + (await page.title().catch(() => "Sayfa"))); break;
            case "S": this.bolge = [0, 0, 10000, 10000]; this.zorla(); break;
            case "Z": {
                const p = metin.trim().split(" ").map((x) => parseInt(x, 10));
                if (p.length === 4 && p.every((x) => !isNaN(x)) && p[2] > p[0] + 50 && p[3] > p[1] + 50)
                    this.bolge = [Math.max(0, p[0]), Math.max(0, p[1]), Math.min(10000, p[2]), Math.min(10000, p[3])];
                this.zorla();
                break;
            }
            case "I":
                await this.girdi(metin);
                if (this.kip === "paket") { await bekle(350); this.zorla(); }
                else if (this.kaydirildi) { this.kaydirildi = false; setTimeout(() => this.zorla(), 180); }   // kaydirmanin son hali
                break;
            case "Y": await this.yaz(metin); await bekle(200); this.zorla(); break;
            case "U": await this.git(metin.trim()); break;
            case "B": await this.komut(metin.trim()); break;
            case "d": await this.indirmeIslemi(metin.trim()); break;
        }
    }
    async girdi(metin) {
        for (const ham of metin.split("\n")) {
            const a = ham.trim().split(" "); if (!a[0]) continue;
            try {
                if (a[0] === "M") { [this.fx, this.fy] = this.px(+a[1], +a[2]); await page.mouse.move(this.fx, this.fy); }
                else if (a[0] === "C") {
                    [this.fx, this.fy] = this.px(+a[2], +a[3]);
                    const button = a[1] === "R" ? "right" : (a[1] === "M" ? "middle" : "left");
                    await page.mouse.click(this.fx, this.fy, { button });
                }
                else if (a[0] === "D" || a[0] === "U") {
                    [this.fx, this.fy] = this.px(+a[2], +a[3]);
                    await page.mouse.move(this.fx, this.fy);
                    const button = a[1] === "R" ? "right" : "left";
                    if (a[0] === "D") await page.mouse.down({ button }); else await page.mouse.up({ button });
                }
                else if (a[0] === "W") { await page.mouse.wheel({ deltaY: -(+a[1]) * 120 }); this.kaydirildi = true; }
                else if (a[0] === "X") { await page.mouse.wheel({ deltaX: (+a[1]) * 120 }); this.kaydirildi = true; }
                else if (a[0] === "K") await this.tus(a[1] || "");
            } catch (e) { log("girdi " + ham + ": " + e.message); }
        }
    }
    async tus(kombo) {
        const ad = {
            enter: "Enter", esc: "Escape", tab: "Tab", backspace: "Backspace", delete: "Delete", insert: "Insert", space: " ",
            home: "Home", end: "End", pgup: "PageUp", pgdn: "PageDown", up: "ArrowUp", down: "ArrowDown", left: "ArrowLeft", right: "ArrowRight",
            ctrl: "Control", shift: "Shift", alt: "Alt", win: "Meta"
        };
        const p = kombo.toLowerCase().split("+");
        if (kombo === "f5" || kombo === "ctrl+r") { await this.komut("yenile"); return; }
        if (kombo === "alt+left") { await this.komut("geri"); return; }
        if (kombo === "alt+right") { await this.komut("ileri"); return; }
        const tuslar = p.map((x) => ad[x] || (/^f\d{1,2}$/.test(x) ? x.toUpperCase() : (x.length === 1 ? x : null))).filter((x) => x);
        if (!tuslar.length) return;
        for (let i = 0; i < tuslar.length - 1; i++) await page.keyboard.down(tuslar[i]);
        await page.keyboard.press(tuslar[tuslar.length - 1]);
        for (let i = tuslar.length - 2; i >= 0; i--) await page.keyboard.up(tuslar[i]);
    }
    async yaz(metin) {
        const parcalar = metin.replace(/\r\n/g, "\n").split("\n");
        for (let i = 0; i < parcalar.length; i++) {
            if (parcalar[i]) await page.keyboard.sendCharacter(parcalar[i]);
            if (i < parcalar.length - 1) await page.keyboard.press("Enter");
        }
    }
    async git(s) {
        if (!s) return;
        let url = s;
        if (!/^[a-z]+:\/\//i.test(s)) {
            if (/\s/.test(s) || !/\.[a-z]{2,}/i.test(s)) url = ARAMA + encodeURIComponent(s);
            else url = "https://" + s;
        }
        this.mesaj("AÃ§Ä±lÄ±yor: " + url);
        this.bolge = [0, 0, 10000, 10000];
        try { await page.goto(url, { waitUntil: "domcontentloaded", timeout: 45000 }); }
        catch (e) { if (!/net::ERR_ABORTED/.test(e.message)) this.mesaj("AÃ§Ä±lamadÄ±: " + e.message.substring(0, 140)); }
        this.zorla();
    }
    async komut(k) {
        try {
            if (k === "geri") await page.goBack({ waitUntil: "domcontentloaded", timeout: 30000 });
            else if (k === "ileri") await page.goForward({ waitUntil: "domcontentloaded", timeout: 30000 });
            else if (k === "yenile") await page.reload({ waitUntil: "domcontentloaded", timeout: 45000 });
            else if (k === "dur") await cdp.send("Page.stopLoading");
            else if (k === "ana") await page.goto(ANA, { waitUntil: "domcontentloaded", timeout: 45000 });
            else if (k === "reklam1" || k === "reklam0") { reklamAcik = k === "reklam1"; this.mesaj("Reklam engelleyici " + (reklamAcik ? "açık" : "kapalı")); await page.reload({ waitUntil: "domcontentloaded", timeout: 45000 }).catch(() => { }); }
            else if (k === "reklamdurum") this.mesaj("Reklam engelleyici " + (reklamAcik ? "açık" : "kapalı") + " • " + reklamAlanlari.size + " alan • " + reklamEngellenen + " istek engellendi");
        } catch (e) { if (!/net::ERR_ABORTED/.test(e.message)) this.mesaj(e.message.substring(0, 140)); }
        this.zorla();
    }
    async adresBildir(yukleniyor) {
        if (!page) return;
        let baslik = "";
        try { baslik = await page.title(); } catch (e) { }
        let geri = 0, ileri = 0;
        try {
            const h = await cdp.send("Page.getNavigationHistory");
            geri = h.currentIndex > 0 ? 1 : 0;
            ileri = h.currentIndex < h.entries.length - 1 ? 1 : 0;
        } catch (e) { }
        this.gonder("R", page.url() + "\n" + baslik + "\n" + geri + "\n" + ileri + "\n" + (yukleniyor ? 1 : 0));
    }
    async indirmeIslemi(s) {
        const [islem, id] = s.split(" ");
        const d = indirmeler.get(id);
        if (!d || !d.tamam) { this.mesaj("Ä°ndirme bulunamadÄ± (sÃ¼resi geÃ§miÅŸ olabilir)"); return; }
        if (islem === "sil") { try { fs.unlinkSync(d.yol); } catch (e) { } indirmeler.delete(id); this.mesaj("Silindi: " + d.ad); return; }
        if (islem === "telefon") { this.gonder("M", "Telefona indiriliyor: " + d.ad); return; }   // istemci /uzak/indir/<id> ile alir
        if (islem === "drive") {
            if (!drive || !drive.bagli()) { this.mesaj("Drive sunucuya baÄŸlÄ± deÄŸil (/drive/setup)"); return; }
            if (d.boyut > 300 * 1024 * 1024) { this.mesaj("Dosya Drive'a gÃ¶ndermek iÃ§in Ã§ok bÃ¼yÃ¼k (300 MB Ã¼stÃ¼)"); return; }
            this.mesaj("Drive'a yÃ¼kleniyor: " + d.ad);
            try {
                const klasor = await driveKlasoru();
                const r = await drive.uploadOne({ name: d.ad, mimetype: "application/octet-stream", data: fs.readFileSync(d.yol) }, klasor);
                this.mesaj("Drive'a yÃ¼klendi: " + (r.name || d.ad) + " (Belle Remote klasÃ¶rÃ¼)");
                log("drive'a yuklendi " + d.ad);
            } catch (e) { this.mesaj("Drive'a yÃ¼klenemedi: " + e.message); }
        }
    }
    async kareDongusu() {
        if (this.bitti || !page || this.mesgul) return;
        // yazi alani (metin kutusu) degisimi
        const simdi = Date.now();
        if (!this.sonImlec || simdi - this.sonImlec > 500) {
            this.sonImlec = simdi;
            try {
                const ya = await zamanli(page.evaluate(() => {
                    const e = document.activeElement;
                    if (!e) return false;
                    if (e.isContentEditable) return true;
                    const t = (e.tagName || "").toLowerCase();
                    if (t === "textarea") return true;
                    if (t === "input") return !/^(button|submit|checkbox|radio|range|color|file|image|reset|hidden)$/i.test(e.type || "");
                    return false;
                }), 2000);
                if (ya !== this.yaziAlani) { this.yaziAlani = ya; this.gonder("T", ya ? "1" : "0"); }
            } catch (e) { }
        }
        const zorla = this.zorlaBayrak;
        const zamanGeldi = this.fps > 0 && simdi - this.sonKare >= 1000 / this.fps;
        if (!zorla && !zamanGeldi) return;
        if (!zorla && this.bekleyen >= 2) return;
        this.zorlaBayrak = false;
        this.mesgul = true;
        try {
            // tarayici kareyi cizmeyi bitirsin (kaydirmadan sonra bos/eski bolge yakalanmasin)
            try { await zamanli(page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)))), 600); } catch (e) { }
            // Kirpma kutusu SAYFANIN basina gore olculur: o anki kaydirma konumunu ekle
            // (yoksa asagi kaydirinca ekran disindaki cizilmemis ust bolge yakalaniyordu)
            let ox = 0, oy = 0;
            try { const lm = await zamanli(cdp.send("Page.getLayoutMetrics"), 1500); const v = lm.cssVisualViewport || lm.visualViewport; ox = v.pageX || 0; oy = v.pageY || 0; } catch (e) { }
            const b = this.bolge;
            const x = ox + b[0] * vw / 10000, y = oy + b[1] * vh / 10000, w = (b[2] - b[0]) * vw / 10000, h = (b[3] - b[1]) * vh / 10000;
            const olcek = Math.min(2, this.genislik / w);
            const r = await zamanli(cdp.send("Page.captureScreenshot", { format: "jpeg", quality: this.kalite, clip: { x, y, width: w, height: h, scale: olcek }, fromSurface: true, captureBeyondViewport: false }), 6000);
            this.sonKare = Date.now();
            const jpeg = Buffer.from(r.data, "base64");
            const ozet = crypto.createHash("md5").update(jpeg).digest("hex");
            if (!zorla && ozet === this.sonOzet) return;
            this.sonOzet = ozet;
            this.gonder("K", "-1 -1 0");
            this.gonder("J", jpeg);
            this.bekleyen++;
        } catch (e) {
            if (!/Target closed|Session closed/.test(e.message)) log("kare: " + e.message);
            this.zorlaBayrak = true;   // olmadiysa bir sonraki turda yeniden dene
        } finally { this.mesgul = false; }
    }
}

function bekle(ms) { return new Promise((r) => setTimeout(r, ms)); }
// Sayfa yuklenirken CDP cagrilari takilabiliyor: zaman siniri (takilan yakalama sonraki kareleri durdurmasin)
function zamanli(p, ms) { return Promise.race([p, new Promise((_, ret) => setTimeout(() => ret(new Error("zaman asimi")), ms))]); }

async function driveKlasoru() {
    const ad = "Belle Remote";
    const q = `name='${ad}' and mimeType='application/vnd.google-apps.folder' and 'root' in parents and trashed=false`;
    const j = await drive.apiJson("GET", "files", { q, fields: "files(id)", pageSize: "1" });
    if (j.files && j.files.length) return j.files[0].id;
    const c = await drive.apiJson("POST", "files", { fields: "id" }, JSON.stringify({ name: ad, mimeType: "application/vnd.google-apps.folder", parents: ["root"] }), { "Content-Type": "application/json" });
    return c.id;
}

// uzak.js'den: 101 yanitindan sonra soket buraya devredilir
function baglan(sock, head, KEY) {
    const o = new Oturum(sock, KEY);
    if (head && head.length) o.veri(head);
}

// ---------------- HTTP: telefona indirme ----------------
const router = express.Router();
router.get("/uzak/indir/:id", (req, res) => {
    const d = indirmeler.get(req.params.id);
    if (!d || !d.tamam || !fs.existsSync(d.yol)) return res.status(404).send("Yok");
    res.setHeader("Content-Type", "application/octet-stream");
    res.setHeader("Content-Length", fs.statSync(d.yol).size);
    res.setHeader("Content-Disposition", "attachment; filename*=UTF-8''" + encodeURIComponent(d.ad));
    fs.createReadStream(d.yol).pipe(res);
});

function driveBagla(d) { drive = d; }

// Belle Browser katmani da ayni listeyi kullanir (liste bossa ilk cagrida hazirlanir)
function reklamMiDis(host) { if (!reklamAlanlari.size && !reklamHazirlaniyor) { reklamHazirlaniyor = true; reklamListesiHazirla().catch(() => { }); } return reklamAlanlari.size > 0 && reklamMi(host); }
let reklamHazirlaniyor = false;
module.exports = { baglan, router, driveBagla, reklamMi: reklamMiDis };
