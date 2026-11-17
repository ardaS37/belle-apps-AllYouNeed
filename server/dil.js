// Sunucu metinleri icin dil destegi (Turkce kaynak -> English).
// Dil secimi (oncelik sirasiyla): ?lang=en|tr, "X-Lang" basligi (telefon uygulamalari gonderir),
// BELLE_LANG ortam degiskeni, tarayicinin Accept-Language basligi (yalnizca HTML sayfalar), varsayilan "tr".
// Cevrilen yerler: JSON yanitlardaki "error" / "statusDesc" alanlari ve HTML sayfalar (panel, kurulum, giris).
// Kullanici verisi (mesajlar, e-postalar, dosya adlari) JSON icinde oldugu gibi kalir.
// Sozluk: dil/en.txt, her satir "Turkce ¦ English" (uygulamalardaki sozluk bicimiyle ayni).
const fs = require("fs");
const path = require("path");

const sozluk = new Map();
let anahtarlar = [];      // uzundan kisaya (HTML'de once uzun ifadeler degissin)

function yukle() {
    sozluk.clear();
    try {
        const satirlar = fs.readFileSync(path.join(__dirname, "dil", "en.txt"), "utf8").split(/\r?\n/);
        for (const s of satirlar) {
            if (!s || s.charAt(0) === "#") continue;
            const k = s.indexOf(" ¦ ");
            if (k <= 0) continue;
            const tr = s.substring(0, k).replace(/\\n/g, "\n"), en = s.substring(k + 3).replace(/\\n/g, "\n");
            if (en) sozluk.set(tr, en);
        }
    } catch (e) { }
    anahtarlar = Array.from(sozluk.keys()).sort((a, b) => b.length - a.length);
}
yukle();

function dilOf(req, html) {
    const q = req.query && typeof req.query.lang === "string" ? req.query.lang : "";
    if (q === "en" || q === "tr") return q;
    const h = (req.get && req.get("x-lang")) || "";
    if (h === "en" || h === "tr") return h;
    const env = process.env.BELLE_LANG || process.env.E6_LANG || "";   // E6_LANG: eski ad
    if (env === "en" || env === "tr") return env;
    if (html) {
        const al = (req.get && req.get("accept-language")) || "";
        if (al && !/^\s*tr\b/i.test(al)) return "en";
    }
    return "tr";
}

// Tek metin: once tam eslesme, sonra "Önek: ayrinti" bicimi (sozlukteki en uzun onek)
function t(s, dil) {
    if (dil !== "en" || typeof s !== "string" || !s) return s;
    const tam = sozluk.get(s);
    if (tam) return tam;
    for (const k of anahtarlar) {
        if (k.length >= 4 && s.startsWith(k) && /[\s:(\-—]$/.test(k)) return sozluk.get(k) + s.substring(k.length);
    }
    return s;
}

// HTML'de ifadeler kelime sinirinda degistirilir ("gün" -> "day" degisirken "günlük" bozulmasin)
const harf = /\p{L}/u;
const kaliplar = new Map();
function kalip(k) {
    let r = kaliplar.get(k);
    if (!r) {
        const kac = k.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        r = new RegExp((harf.test(k.charAt(0)) ? "(?<!\\p{L})" : "") + kac + (harf.test(k.charAt(k.length - 1)) ? "(?!\\p{L})" : ""), "gu");
        kaliplar.set(k, r);
    }
    r.lastIndex = 0;
    return r;
}
function htmlCevir(html) {
    let out = html;
    for (const k of anahtarlar) {
        if (k.length < 3 || out.indexOf(k) < 0) continue;
        const en = sozluk.get(k);
        out = out.replace(kalip(k), () => en);
    }
    return out.replace(/<html lang="tr"/i, '<html lang="en"');
}

// Express ara katmani: yanitlari istegin diline cevirir
function araKatman(req, res, next) {
    const json = res.json.bind(res);
    res.json = (b) => {
        const d = dilOf(req, false);
        if (d === "en" && b && typeof b === "object") {
            if (typeof b.error === "string") b.error = t(b.error, d);
            if (typeof b.statusDesc === "string") b.statusDesc = t(b.statusDesc, d);
            if (typeof b.reason === "string") b.reason = t(b.reason, d);
        }
        return json(b);
    };
    const send = res.send.bind(res);
    res.send = (b) => {
        if (typeof b === "string" && /^\s*</.test(b) && dilOf(req, true) === "en") b = htmlCevir(b);
        return send(b);
    };
    req.dil = () => dilOf(req, false);
    next();
}

// HTML dosyasini (login.html gibi) istegin diline cevirip gonder
function dosyaGonder(req, res, dosya) {
    const html = fs.readFileSync(dosya, "utf8");
    res.type("html").send(dilOf(req, true) === "en" ? htmlCevir(html) : html);
}

module.exports = { t, araKatman, dosyaGonder, dilOf, yukle };
