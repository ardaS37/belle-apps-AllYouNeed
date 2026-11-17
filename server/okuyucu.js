// Belle Browser: okuma modu (Mozilla Readability) ve sade gorunum (gercek tarayicida acilip sadelestirilmis sayfa).
//   GET /tb/oku?u=URL    makalenin kendisi (Firefox okuma moduyla ayni algoritma); bos cikarsa sayfa Chrome'da
//                        acilip (JavaScript ile dolan siteler) yeniden denenir
//   GET /tb/sade?u=URL   sayfa sunucudaki Chrome'da acilir, betikler calisir; sonra tum yerlesim (float, flex, grid,
//                        sabit konum) tek sutuna indirilir, modern CSS atilir, gerekli renk/kalinlik/hiza her ogeye
//                        yazilir, resimler kucultulur. Okuma modundan esnek: menuler, listeler, tablolar, galeriler kalir.
// Telefon (QtWebKit 2.2) modern yerlesimi cizemedigi icin satirlar ust uste biniyor, medya gorunmuyordu.
const express = require("express");
const { Readability } = require("@mozilla/readability");
const { parseHTML } = require("linkedom");
const router = express.Router();

const MOBIL_UA = "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36";
const CHROME_PATH = process.env.CHROME_PATH || "/usr/bin/google-chrome";

function gecerliUrl(u) {
    try { const x = new URL(u); return (x.protocol === "http:" || x.protocol === "https:") ? x : null; } catch (e) { return null; }
}
function ozelAdres(host) {
    return /^(localhost|127\.|10\.|192\.168\.|169\.254\.|0\.|\[?::1\]?$|metadata\.google\.internal)/i.test(host) ||
        /^172\.(1[6-9]|2\d|3[01])\./.test(host);
}
// "haberler.com", kendi /tb/ sayfamiz, yuzde kodlu adres: hepsini asil adrese indir
function hedefCoz(q) {
    let ham = ("" + (q || "")).trim();
    for (let i = 0; i < 3; i++) {
        const m = /\/tb\/(?:oku|g|sade)\?(?:[^#]*&)?u=([^&#]+)/.exec(ham);
        if (!m) break;
        try { ham = decodeURIComponent(m[1]); } catch (e) { break; }
    }
    if (/^https?%3A/i.test(ham)) { try { ham = decodeURIComponent(ham); } catch (e) { } }
    if (ham && !/^[a-z][a-z0-9+.-]*:\/\//i.test(ham)) ham = "http://" + ham.replace(/^\/+/, "");
    const h = gecerliUrl(ham);
    return h && !ozelAdres(h.hostname) ? h : null;
}
const esc = (s) => ("" + s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
const resimAdres = (u, w) => "/tb/g?img=1&w=" + (w || 480) + "&q=9&u=" + encodeURIComponent(u);
const yeniAdres = (yol, u) => yol + "?u=" + encodeURIComponent(u);

function cozHtml(buf, tur) {
    let cs = (/charset=([\w-]+)/i.exec(tur || "") || [])[1];
    if (!cs) { const m = /<meta[^>]+charset=["']?([\w-]+)/i.exec(buf.slice(0, 4096).toString("latin1")); if (m) cs = m[1]; }
    try { return new TextDecoder((cs || "utf-8").toLowerCase()).decode(buf); } catch (e) { return buf.toString("utf8"); }
}
async function htmlAl(url) {
    const r = await fetch(url, { headers: { "user-agent": MOBIL_UA, "accept-language": "tr-TR,tr;q=0.9,en;q=0.6" }, redirect: "follow", signal: AbortSignal.timeout(25000) });
    return { html: cozHtml(Buffer.from(await r.arrayBuffer()), r.headers.get("content-type")), base: r.url || url };
}

// ---- paylasilan Chrome (ilk istekte acilir, 3 dk bos kalinca kapanir) ----
let tarayici = null, acilis = null, bosZaman = null, calisan = 0;
async function chrome() {
    clearTimeout(bosZaman);
    if (tarayici && tarayici.isConnected()) return tarayici;
    if (!acilis) {
        const puppeteer = require("puppeteer");
        acilis = puppeteer.launch({
            headless: true, executablePath: CHROME_PATH,
            args: ["--no-sandbox", "--disable-dev-shm-usage", "--disable-gpu", "--no-first-run", "--mute-audio", "--blink-settings=imagesEnabled=true"]
        }).then((b) => { tarayici = b; acilis = null; b.on("disconnected", () => { tarayici = null; }); return b; }, (e) => { acilis = null; throw e; });
    }
    return acilis;
}
function bosaGec() {
    clearTimeout(bosZaman);
    bosZaman = setTimeout(() => { if (calisan === 0 && tarayici) { tarayici.close().catch(() => { }); tarayici = null; } }, 180000);
}
// Sayfayi Chrome'da ac, betikler calissin, gec yuklenen resimler gelsin; sonra fn(page) sonucunu dondur
async function chromedaAc(url, fn) {
    if (calisan >= 3) throw new Error("Sunucu meşgul, biraz sonra tekrar deneyin");
    calisan++;
    let page = null;
    try {
        const b = await chrome();
        page = await b.newPage();
        await page.setUserAgent(MOBIL_UA);
        await page.setViewport({ width: 480, height: 800, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
        await page.setExtraHTTPHeaders({ "accept-language": "tr-TR,tr;q=0.9,en;q=0.6" });
        await page.setRequestInterception(true);
        page.on("request", (r) => {
            const t = r.resourceType();
            // yazi tipi / video / izleme betikleri gerekmez: hiz
            if (t === "font" || t === "media" || /doubleclick|googlesyndication|google-analytics|googletagmanager|adservice|facebook\.net|hotjar|criteo|taboola|outbrain/i.test(r.url())) r.abort().catch(() => { });
            else r.continue().catch(() => { });
        });
        try { await page.goto(url, { waitUntil: "networkidle2", timeout: 25000 }); }
        catch (e) { if (!/timeout/i.test(e.message)) throw e; }     // yavas site: o ana kadar yuklenen yeter
        // gec yuklenen (lazy) resimler icin asagi kaydir
        await page.evaluate(async () => {
            for (let y = 0; y < Math.min(document.body ? document.body.scrollHeight : 0, 12000); y += 700) { window.scrollTo(0, y); await new Promise((r) => setTimeout(r, 120)); }
            window.scrollTo(0, 0);
        }).catch(() => { });
        return await fn(page);
    } finally {
        calisan--;
        if (page) page.close().catch(() => { });
        bosaGec();
    }
}

// ---- okuma modu ----
function okumaSayfasi(hedef, base, makale, kaynak) {
    const { document } = parseHTML("<html><body>" + (makale.content || "") + "</body></html>");
    document.querySelectorAll("img").forEach((img) => {
        const s = img.getAttribute("data-src") || img.getAttribute("data-lazy-src") || img.getAttribute("src") || "";
        if (!s || /^data:/.test(s)) { img.remove(); return; }
        let mutlak = s; try { mutlak = new URL(s, base).href; } catch (e) { }
        for (const a of Array.from(img.attributes)) if (a.name !== "alt") img.removeAttribute(a.name);
        img.setAttribute("src", resimAdres(mutlak, 600));
    });
    document.querySelectorAll("a[href]").forEach((a) => { try { a.setAttribute("href", new URL(a.getAttribute("href"), base).href); } catch (e) { } });
    document.querySelectorAll("iframe,video,audio,script,style,form,button").forEach((e) => e.remove());
    const govde = document.body.innerHTML;
    const ust = [makale.byline, makale.siteName].filter(Boolean).map(esc).join(" • ");
    return `<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>${esc(makale.title || hedef.hostname)}</title><style>body{font-family:sans-serif;font-size:19px;line-height:1.55;margin:0;padding:12px 14px;background:#fbfaf7;color:#222}
img{max-width:100%;height:auto;display:block;margin:10px 0}a{color:#1565c0}pre{white-space:pre-wrap}table{border-collapse:collapse;max-width:100%}td,th{border:1px solid #ccc;padding:3px}
h1{font-size:25px;line-height:1.25;margin:6px 0 4px}h2{font-size:21px}h3{font-size:19px}blockquote{margin:8px 0;padding-left:12px;border-left:3px solid #ccc;color:#555}
.ust{font-size:14px;color:#777;border-bottom:1px solid #ddd;padding-bottom:7px;margin-bottom:8px}.ust a{margin-right:12px}.bilgi{font-size:14px;color:#777}</style></head><body>
<div class="ust">Okuma modu${kaynak ? " (" + kaynak + ")" : ""} • <a href="${esc(base)}">Asıl sayfa</a><a href="${esc(yeniAdres("/tb/sade", base))}">Sade görünüm</a></div>
<h1>${esc(makale.title || "")}</h1>${ust ? `<div class="bilgi">${ust}</div>` : ""}${govde}</body></html>`;
}
function readability(html, base) {
    const { document } = parseHTML(html);
    try { const b = document.createElement("base"); b.setAttribute("href", base); if (document.head) document.head.appendChild(b); } catch (e) { }
    return new Readability(document, { charThreshold: 300, keepClasses: false }).parse();
}

router.get("/tb/oku", async (req, res) => {
    const hedef = hedefCoz(req.query.u);
    if (!hedef) return res.status(400).type("text/html; charset=utf-8").send("<p>Geçersiz adres: " + esc(req.query.u || "") + "</p>");
    try {
        let { html, base } = await htmlAl(hedef.href);
        let m = null;
        try { m = readability(html, base); } catch (e) { }
        let kaynak = "";
        if (!m || (m.textContent || "").trim().length < 400) {
            // JavaScript ile dolan sayfa: Chrome'da acip yeniden dene
            try {
                const r = await chromedaAc(hedef.href, async (p) => ({ html: await p.content(), base: p.url() }));
                const m2 = readability(r.html, r.base);
                if (m2 && (!m || (m2.textContent || "").length > (m.textContent || "").length)) { m = m2; base = r.base; kaynak = "tarayıcıyla açıldı"; }
            } catch (e) { console.log("okuma: chrome denemesi olmadi: " + e.message); }
        }
        if (!m || (m.textContent || "").trim().length < 80) {
            return res.redirect(yeniAdres("/tb/sade", hedef.href));     // makale yok (ana sayfa, liste): sade gorunum
        }
        res.type("text/html; charset=utf-8").send(okumaSayfasi(hedef, base, m, kaynak));
    } catch (e) {
        res.status(502).type("text/html; charset=utf-8").send("<p>Sayfa okunamadı: " + esc(e.message) + `</p><p><a href="${esc(yeniAdres("/tb/sade", hedef.href))}">Sade görünümü dene</a> • <a href="${esc(hedef.href)}">Asıl sayfa</a></p>`);
    }
});

// ---- sade gorunum ----
// Sayfanin icinde calisir: yerlesimi tek sutuna indirir, gereken stili ogeye yazar, sonra HTML dondurur
function sadelestir() {
    const IZIN = /^(a|abbr|b|blockquote|br|caption|code|dd|del|div|dl|dt|em|figcaption|figure|h[1-6]|hr|i|img|li|main|mark|ol|p|pre|q|s|section|article|aside|header|footer|nav|small|span|strong|sub|sup|table|tbody|td|tfoot|th|thead|tr|u|ul|label|time|cite|center|font)$/;
    const SIL = /^(script|style|noscript|template|link|meta|iframe|object|embed|canvas|svg|form|input|select|textarea|button|dialog)$/;
    const out = [];
    const bas = Date.now();
    let adet = 0;
    function renk(c) { return c && c !== "rgba(0, 0, 0, 0)" && c !== "transparent" ? c : ""; }
    function yaz(el, derinlik) {
        if (adet++ > 6000 || Date.now() - bas > 6000) return;
        for (const n of Array.from(el.childNodes)) {
            if (n.nodeType === 3) { const t = n.textContent; if (t) out.push(t.replace(/[&<>]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" }[c]))); continue; }
            if (n.nodeType !== 1) continue;
            const ad = n.tagName.toLowerCase();
            if (SIL.test(ad)) {
                if (ad === "svg" && n.getAttribute("aria-label")) out.push(n.getAttribute("aria-label"));
                continue;
            }
            const cs = getComputedStyle(n);
            if (cs.display === "none" || cs.visibility === "hidden" || (cs.position === "fixed" && !/^(main|article)$/.test(ad))) continue;
            const r = n.getBoundingClientRect();
            if ((r.width < 2 || r.height < 2) && ad !== "br" && !n.querySelector("img")) { if (!n.textContent.trim()) continue; }
            if (ad === "video" || ad === "audio") {
                const src = n.currentSrc || n.src || (n.querySelector("source") || {}).src || "";
                out.push(`<p class="m"><a href="${src}">▶ ${ad === "video" ? "Video" : "Ses"}</a></p>`);
                continue;
            }
            if (ad === "img") {
                const src = n.currentSrc || n.src || n.getAttribute("data-src") || "";
                if (!src || /^data:/.test(src) || r.width < 24 || r.height < 24) continue;
                const w = Math.round(Math.min(r.width, 460));
                out.push(`<img src="${src.replace(/"/g, "&quot;")}" width="${w}" alt="${(n.alt || "").replace(/"/g, "&quot;")}">`);
                continue;
            }
            const etiket = IZIN.test(ad) ? (/^(main|section|article|aside|header|footer|nav|figure|center|font|label|time|cite)$/.test(ad) ? "div" : ad) : (cs.display === "inline" ? "span" : "div");
            const st = [];
            const blok = /^(block|flex|grid|table|list-item|flow-root)/.test(cs.display) && etiket !== "span";
            const fw = parseInt(cs.fontWeight, 10); if (fw >= 600 && !/^(b|strong|h[1-6]|th)$/.test(etiket)) st.push("font-weight:bold");
            if (cs.fontStyle === "italic" && !/^(i|em)$/.test(etiket)) st.push("font-style:italic");
            const fs = parseFloat(cs.fontSize); if (fs && Math.abs(fs - 16) > 2 && !/^h[1-6]$/.test(etiket)) st.push("font-size:" + Math.max(12, Math.min(30, Math.round(fs))) + "px");
            const c = renk(cs.color); if (c && c !== "rgb(0, 0, 0)" && c !== "rgb(33, 33, 33)") st.push("color:" + c);
            const bg = renk(cs.backgroundColor); if (bg && blok) st.push("background:" + bg);
            if (blok && cs.textAlign === "center") st.push("text-align:center");
            if (cs.textDecorationLine && cs.textDecorationLine.indexOf("line-through") >= 0) st.push("text-decoration:line-through");
            if (blok && parseFloat(cs.borderTopWidth) > 0 && cs.borderTopStyle !== "none") st.push("border-top:1px solid #ddd");
            // yatay dizilmis kucuk ogeler (menu, etiket) yan yana kalsin, kalanlar tek sutun
            const yatay = (cs.display === "flex" || cs.display === "inline-flex") && (cs.flexDirection || "row").indexOf("row") === 0 && r.height < 70;
            if (yatay) st.push("line-height:2");
            let oz = "";
            if (etiket === "a") {
                const h = n.href || "";
                if (h && !/^javascript:/i.test(h)) oz += ` href="${h.replace(/"/g, "&quot;")}"`;
                if (blok && !yatay) st.push("display:block");
            }
            if (etiket === "td" || etiket === "th") { if (n.colSpan > 1) oz += ` colspan="${n.colSpan}"`; }
            if (st.length) oz += ` style="${st.join(";")}"`;
            out.push(`<${etiket}${oz}>`);
            yaz(n, derinlik + 1);
            if (yatay) out.push(" ");
            if (!/^(br|hr|img)$/.test(etiket)) out.push(`</${etiket}>`);
        }
    }
    yaz(document.body, 0);
    const bg = getComputedStyle(document.body).backgroundColor;
    return { govde: out.join(""), baslik: document.title || "", bg: bg && bg !== "rgba(0, 0, 0, 0)" ? bg : "#ffffff", adres: location.href };
}

router.get("/tb/sade", async (req, res) => {
    const hedef = hedefCoz(req.query.u);
    if (!hedef) return res.status(400).type("text/html; charset=utf-8").send("<p>Geçersiz adres: " + esc(req.query.u || "") + "</p>");
    try {
        const s = await chromedaAc(hedef.href, (p) => p.evaluate(sadelestir));
        // resimler: kucultulmus JPEG; baglantilar: tiklaninca yine sade gorunum
        let g = s.govde
            .replace(/<img src="([^"]+)"/g, (t, u) => '<img src="' + resimAdres(u.replace(/&quot;/g, '"'), 460) + '"')
            .replace(/<a href="(https?:[^"]+)"/g, (t, u) => '<a href="' + esc(yeniAdres("/tb/sade", u.replace(/&quot;/g, '"').replace(/&amp;/g, "&"))) + '"')
            .replace(/<(div|span)>\s*<\/\1>/g, "").replace(/(<div>\s*){3,}/g, "<div>").replace(/\n\s*\n+/g, "\n");
        if (g.length > 900000) g = g.slice(0, 900000) + "<p>… (sayfanın devamı kesildi)</p>";
        res.type("text/html; charset=utf-8").send(`<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>${esc(s.baslik || hedef.hostname)}</title><style>body{font-family:sans-serif;font-size:17px;line-height:1.45;margin:0;padding:8px 10px;background:${s.bg};color:#202124;word-wrap:break-word}
div,p,ul,ol,table,section{max-width:100%}img{max-width:100%;height:auto;display:block;margin:6px 0}a{color:#1565c0}table{border-collapse:collapse}td,th{border:1px solid #ddd;padding:3px;vertical-align:top}
h1{font-size:24px}h2{font-size:21px}h3{font-size:19px}li{margin:3px 0}pre{white-space:pre-wrap}.m{background:#eee;padding:8px;border-radius:6px}
.ust{font-size:14px;color:#777;border-bottom:1px solid #ddd;padding-bottom:7px;margin-bottom:6px;background:#fff}.ust a{margin-right:12px}</style></head><body>
<div class="ust">Sade görünüm • <a href="${esc(s.adres)}">Asıl sayfa</a><a href="${esc(yeniAdres("/tb/oku", s.adres))}">Okuma modu</a></div>${g}</body></html>`);
    } catch (e) {
        res.status(502).type("text/html; charset=utf-8").send("<p>Sayfa açılamadı: " + esc(e.message) + `</p><p><a href="${esc(hedef.href)}">Asıl sayfa</a></p>`);
    }
});

module.exports = { router };
