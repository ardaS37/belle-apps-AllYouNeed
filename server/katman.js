// Belle Browser sunucu katmani (istege bagli).
// Telefon tarayicisi (QtWebKit 2.2, TLS 1.0, eski sertifikalar) modern siteleri dogrudan acamaz ya da yavas acar.
// Bu katman:
//   ALL /tb/g?u=URL[&img=1&w=640&q=45]  seffaf vekil: istegi siteye iletir (cerez, POST, Range dahil), yonlendirmeleri
//                                        telefona birakir; resimleri ffmpeg ile kucultur, WebP/AVIF'i JPEG'e cevirir.
//   GET /tb/oku?u=URL                    okuma modu: sayfanin yalin, hafif hali (betik/reklam yok, resimler kucuk)
//   GET /tb/durum                        istatistik (tasarruf), ffmpeg var mi
// Parola: X-Api-Key basligi ya da ?key= (video oynatici baslik gonderemez); /tb sayfalari icin cerez de gecerli.
const express = require("express");
const { spawn, execFile } = require("child_process");
const router = express.Router();

let reklamMi = () => false;
function reklamBagla(f) { if (typeof f === "function") reklamMi = f; }

const MOBIL_UA = "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36";
const MASA_UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36";

const ist = { istek: 0, resim: 0, orijinal: 0, giden: 0, okuma: 0, engellenen: 0, hata: 0, basla: Date.now() };

let ffmpegVar = null;
execFile("ffmpeg", ["-version"], { timeout: 5000 }, (e) => { ffmpegVar = !e; });

function gecerliUrl(u) {
    try { const x = new URL(u); return (x.protocol === "http:" || x.protocol === "https:") ? x : null; } catch (e) { return null; }
}
function ozelAdres(host) {
    // SSRF: sunucunun kendi agina / metadata adresine gidilmesin
    return /^(localhost|127\.|10\.|192\.168\.|169\.254\.|0\.|\[?::1\]?$|metadata\.google\.internal)/i.test(host) ||
        /^172\.(1[6-9]|2\d|3[01])\./.test(host);
}

// ---- resim kucultme (ffmpeg, en fazla 3 es zamanli) ----
let calisan = 0;
const bekleyen = [];
function sira(fn) {
    return new Promise((ok, red) => {
        const is = () => { calisan++; fn().then(ok, red).finally(() => { calisan--; const n = bekleyen.shift(); if (n) n(); }); };
        if (calisan < 3) is(); else bekleyen.push(is);
    });
}
function kucult(buf, w, q, png) {
    return sira(() => new Promise((ok, red) => {
        const args = ["-hide_banner", "-loglevel", "error", "-i", "pipe:0", "-frames:v", "1",
            "-vf", `scale='min(${w},iw)':-2:flags=bilinear`];
        if (png) args.push("-f", "image2", "-vcodec", "png", "-compression_level", "9", "pipe:1");
        else args.push("-f", "image2", "-vcodec", "mjpeg", "-q:v", String(q), "-pix_fmt", "yuvj420p", "pipe:1");
        const p = spawn("ffmpeg", args, { stdio: ["pipe", "pipe", "ignore"] });
        const out = [];
        const zaman = setTimeout(() => { p.kill("SIGKILL"); red(new Error("zaman asimi")); }, 15000);
        p.stdout.on("data", (d) => out.push(d));
        p.on("error", (e) => { clearTimeout(zaman); red(e); });
        p.on("close", (code) => { clearTimeout(zaman); code === 0 && out.length ? ok(Buffer.concat(out)) : red(new Error("ffmpeg " + code)); });
        p.stdin.on("error", () => { });
        p.stdin.end(buf);
    }));
}
// kucuk onbellek (sik kullanilan logolar vb.)
const onbellek = new Map();
let onbellekBoy = 0;
function onbellekKoy(k, v) {
    if (v.govde.length > 2 * 1024 * 1024) return;
    onbellek.set(k, v); onbellekBoy += v.govde.length;
    while (onbellekBoy > 40 * 1024 * 1024) { const [ilk, d] = onbellek.entries().next().value; onbellek.delete(ilk); onbellekBoy -= d.govde.length; }
}

const ILET = ["accept", "accept-language", "cookie", "referer", "content-type", "range", "if-none-match", "if-modified-since", "origin", "x-requested-with"];
const GERI = ["content-type", "location", "cache-control", "expires", "last-modified", "etag", "content-range", "accept-ranges", "content-disposition", "content-language", "refresh"];

function cerezler(h) {
    if (typeof h.getSetCookie === "function") return h.getSetCookie();
    const v = h.get("set-cookie");
    return v ? v.split(/,(?=\s*[^;,=\s]+=)/) : [];
}

async function vekil(req, res) {
    const hedef = gecerliUrl("" + (req.query.u || ""));
    if (!hedef || ozelAdres(hedef.hostname)) return res.status(400).type("text/plain").send("Gecersiz adres");
    ist.istek++;
    if (reklamMi(hedef.hostname)) { ist.engellenen++; return res.status(204).end(); }
    const resimIste = req.query.img === "1";
    const w = Math.max(120, Math.min(1600, parseInt(req.query.w, 10) || 640));
    const q = Math.max(2, Math.min(20, parseInt(req.query.q, 10) || 7));     // ffmpeg -q:v (2 iyi, 20 kotu)
    const okey = req.method + " " + hedef.href + " " + w + " " + q;
    if (req.method === "GET" && resimIste && onbellek.has(okey)) {
        const c = onbellek.get(okey);
        res.set("Content-Type", c.tur).set("Cache-Control", "public, max-age=86400").set("X-Belle-Orijinal", String(c.orj));
        return res.end(c.govde);
    }
    const h = {};
    for (const k of ILET) { const v = req.get(k); if (v) h[k] = v; }
    // telefonun kendi kimligi (eski Android/WebKit) iletilir: siteler eski tarayicinin calistirabilecegi hafif sayfayi gonderir
    const ua = req.get("x-belle-ua");
    h["user-agent"] = ua === "masa" ? MASA_UA : (ua === "modern" ? MOBIL_UA : (req.get("user-agent") || MOBIL_UA));
    if (!h["accept-language"]) h["accept-language"] = "tr-TR,tr;q=0.9,en;q=0.6";
    if (resimIste) h["accept"] = "image/webp,image/avif,image/jpeg,image/png,image/*;q=0.8";   // webp gelirse JPEG'e cevrilir
    h["accept-encoding"] = "gzip, deflate, br";
    let govde;
    if (req.method !== "GET" && req.method !== "HEAD") {
        govde = await new Promise((ok) => { const p = []; req.on("data", (d) => p.push(d)); req.on("end", () => ok(Buffer.concat(p))); req.on("error", () => ok(Buffer.alloc(0))); });
    }
    let r;
    const kes = new AbortController();
    const zaman = setTimeout(() => kes.abort(), 45000);
    try {
        r = await fetch(hedef.href, { method: req.method, headers: h, body: govde && govde.length ? govde : undefined, redirect: "manual", signal: kes.signal });
    } catch (e) {
        clearTimeout(zaman);
        ist.hata++;
        return res.status(502).type("text/html; charset=utf-8").send(`<html><body style="font-family:sans-serif;padding:16px"><h3>Site açılamadı</h3><p>${("" + hedef.hostname).replace(/[<>&]/g, "")}: ${("" + e.message).replace(/[<>&]/g, "")}</p></body></html>`);
    }
    res.status(r.status);
    for (const k of GERI) { const v = r.headers.get(k); if (v) res.set(k, v); }
    const sc = cerezler(r.headers);
    if (sc.length) res.set("Set-Cookie", sc);
    res.set("X-Belle-Url", r.url || hedef.href);
    const tur = (r.headers.get("content-type") || "").toLowerCase();
    const resim = /^image\/(jpeg|jpg|png|webp|avif|bmp)/.test(tur);
    if (r.status === 200 && resim && ffmpegVar && req.method === "GET" && !req.get("range")) {
        try {
            const buf = Buffer.from(await r.arrayBuffer());
            clearTimeout(zaman);
            ist.resim++; ist.orijinal += buf.length;
            const cevir = /webp|avif|bmp/.test(tur);
            if (!cevir && buf.length < 12 * 1024) { ist.giden += buf.length; res.set("X-Belle-Orijinal", String(buf.length)); return res.end(buf); }
            const png = /png/.test(tur) && !cevir;
            let out = await kucult(buf, w, q, png);
            let otur = png ? "image/png" : "image/jpeg";
            if (!cevir && out.length >= buf.length) { out = buf; otur = tur; }
            ist.giden += out.length;
            onbellekKoy(okey, { tur: otur, govde: out, orj: buf.length });
            res.set("Content-Type", otur).set("X-Belle-Orijinal", String(buf.length)).set("Cache-Control", "public, max-age=86400");
            res.removeHeader("content-length");
            return res.end(out);
        } catch (e) {
            ist.hata++;
            if (!res.headersSent) return res.status(502).end();
            return res.end();
        }
    }
    // diger her sey: akit
    if (!r.body || req.method === "HEAD") { clearTimeout(zaman); return res.end(); }
    const len = r.headers.get("content-length");
    if (len && !r.headers.get("content-encoding")) res.set("Content-Length", len);
    try {
        const okuyucu = r.body.getReader();
        res.on("close", () => { try { okuyucu.cancel(); } catch (e) { } });
        clearTimeout(zaman);
        for (;;) {
            const { done, value } = await okuyucu.read();
            if (done) break;
            ist.orijinal += value.length; ist.giden += value.length;
            if (!res.write(Buffer.from(value))) await new Promise((ok) => res.once("drain", ok));
        }
    } catch (e) { /* baglanti kesildi */ }
    res.end();
}
router.all("/tb/g", vekil);

// ---- okuma modu ----
function cozHtml(buf, tur) {
    let cs = (/charset=([\w-]+)/i.exec(tur || "") || [])[1];
    if (!cs) { const m = /<meta[^>]+charset=["']?([\w-]+)/i.exec(buf.slice(0, 4096).toString("latin1")); if (m) cs = m[1]; }
    try { return new TextDecoder((cs || "utf-8").toLowerCase()).decode(buf); } catch (e) { return buf.toString("utf8"); }
}
function mutlak(base, u) { try { return new URL(u, base).href; } catch (e) { return ""; } }
const esc = (s) => ("" + s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));

router.get("/tb/oku", async (req, res) => {
    let ham = ("" + (req.query.u || "")).trim();
    // kendi okuma / vekil sayfamiz verildiyse asil adrese in; semasiz adrese http:// ekle
    for (let i = 0; i < 3; i++) {
        const m = /\/tb\/(?:oku|g)\?(?:[^#]*&)?u=([^&#]+)/.exec(ham);
        if (!m) break;
        try { ham = decodeURIComponent(m[1]); } catch (e) { break; }
    }
    if (ham && !/^[a-z][a-z0-9+.-]*:\/\//i.test(ham)) ham = "http://" + ham.replace(/^\/+/, "");
    const hedef = gecerliUrl(ham);
    if (!hedef || ozelAdres(hedef.hostname)) return res.status(400).send("Gecersiz adres");
    ist.okuma++;
    try {
        const r = await fetch(hedef.href, { headers: { "user-agent": MOBIL_UA, "accept-language": "tr-TR,tr;q=0.9,en;q=0.6" }, redirect: "follow", signal: AbortSignal.timeout(30000) });
        const base = r.url || hedef.href;
        let html = cozHtml(Buffer.from(await r.arrayBuffer()), r.headers.get("content-type"));
        const baslik = ((/<title[^>]*>([\s\S]*?)<\/title>/i.exec(html) || [])[1] || hedef.hostname).trim();
        html = html.replace(/<!--[\s\S]*?-->/g, "")
            .replace(/<(script|style|noscript|svg|iframe|form|nav|footer|header|aside|button|select|template|canvas|video|audio|object|embed)\b[\s\S]*?<\/\1>/gi, "")
            .replace(/<(link|meta|input|source|track)\b[^>]*>/gi, "");
        let ana = (/<article\b[\s\S]*<\/article>/i.exec(html) || /<main\b[\s\S]*<\/main>/i.exec(html) || /<body\b[\s\S]*<\/body>/i.exec(html) || [html])[0];
        // ozellikleri temizle: yalnizca href / src / alt kalsin
        ana = ana.replace(/<(\/?)([a-z0-9]+)([^>]*)>/gi, (t, k, ad, oz) => {
            ad = ad.toLowerCase();
            if (k) return "</" + ad + ">";
            if (!/^(p|br|h[1-6]|ul|ol|li|a|img|strong|b|em|i|blockquote|pre|code|table|tr|td|th|tbody|thead|figure|figcaption|hr|span|div|section|article|main|dl|dt|dd|sup|sub|small)$/.test(ad)) return "";
            let ek = "";
            if (ad === "a") { const m = /\shref\s*=\s*["']([^"']+)["']/i.exec(oz); if (m) ek = ' href="' + esc(mutlak(base, m[1])) + '"'; }
            if (ad === "img") {
                const m = /\s(?:data-src|data-lazy-src|src)\s*=\s*["']([^"']+)["']/i.exec(oz);
                if (!m || /^data:/.test(m[1])) return "";
                const a = /\salt\s*=\s*["']([^"']*)["']/i.exec(oz);
                ek = ' src="/tb/g?img=1&w=480&q=9&u=' + encodeURIComponent(mutlak(base, m[1])) + '"' + (a ? ' alt="' + esc(a[1]) + '"' : "");
            }
            return "<" + ad + ek + ">";
        }).replace(/(<div>\s*<\/div>|<span>\s*<\/span>)/g, "").replace(/\n\s*\n+/g, "\n");
        res.type("text/html; charset=utf-8").send(`<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>${esc(baslik)}</title><style>body{font-family:sans-serif;font-size:18px;line-height:1.5;margin:0;padding:12px 14px;background:#fbfaf7;color:#222}
img{max-width:100%;height:auto;display:block;margin:8px 0}a{color:#1565c0}pre{white-space:pre-wrap}table{border-collapse:collapse}td,th{border:1px solid #ccc;padding:3px}
.ust{font-size:13px;color:#777;border-bottom:1px solid #ddd;padding-bottom:6px;margin-bottom:8px}</style></head><body>
<div class="ust">Okuma modu • <a href="${esc(base)}">Asıl sayfaya git</a></div><h1 style="font-size:24px">${esc(baslik)}</h1>${ana}</body></html>`);
    } catch (e) {
        res.status(502).type("text/html; charset=utf-8").send("<p>Sayfa okunamadı: " + esc(e.message) + "</p>");
    }
});

router.get("/tb/durum", (req, res) => {
    res.json({ ffmpeg: ffmpegVar, istek: ist.istek, resim: ist.resim, okuma: ist.okuma, engellenen: ist.engellenen, hata: ist.hata,
        orijinalMB: +(ist.orijinal / 1048576).toFixed(1), gidenMB: +(ist.giden / 1048576).toFixed(1),
        tasarrufYuzde: ist.orijinal ? Math.round(100 - 100 * ist.giden / ist.orijinal) : 0, onbellekMB: +(onbellekBoy / 1048576).toFixed(1),
        dakika: Math.round((Date.now() - ist.basla) / 60000) });
});

module.exports = { router, reklamBagla, istatistik: () => ist };
