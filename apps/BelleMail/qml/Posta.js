// BelleMail QML yardimcilari: C++ "mail" isteklerinin geri cagirmalari, tarih bicimleri,
// e-posta HTML'ini Qt'nin zengin metnine (guvenli, sade) cevirme, yanit/iletme taslagi.
// Geri cagirmalar burada saklanir (property variant icinde islev tutmak QML 1.1'de calismaz).

var bekleyen = {};

function istek(tur, p, cb) {
    var id = mail.istek(tur, p || {});
    bekleyen[id] = cb;
    return id;
}

function yanitGeldi(id, ok, veri, hata) {
    var cb = bekleyen[id];
    if (cb === undefined) return;
    delete bekleyen[id];
    var j = veri;
    if (j === undefined || j === null || typeof j !== "object") j = {};
    if (!ok) j = { error: hata || qsTr("Hata") };
    cb(ok, j);
}

// ---------------------------------------------------------------- tarih
function pad(n) { return n < 10 ? "0" + n : "" + n; }

function kisaTarih(ts) {
    if (!ts) return "";
    var t = new Date(ts), now = new Date();
    if (t.toDateString() === now.toDateString()) return pad(t.getHours()) + ":" + pad(t.getMinutes());
    var dun = new Date(now.getTime() - 86400000);
    if (t.toDateString() === dun.toDateString()) return qsTr("Dün");
    if (now - t < 6 * 86400000 && now - t > 0) return [qsTr("Paz"), qsTr("Pzt"), qsTr("Sal"), qsTr("Çar"), qsTr("Per"), qsTr("Cum"), qsTr("Cmt")][t.getDay()];
    return pad(t.getDate()) + "." + pad(t.getMonth() + 1) + (t.getFullYear() !== now.getFullYear() ? "." + t.getFullYear() : "");
}

function uzunTarih(ts) {
    if (!ts) return "";
    var t = new Date(ts);
    return pad(t.getDate()) + "." + pad(t.getMonth() + 1) + "." + t.getFullYear() + " " + pad(t.getHours()) + ":" + pad(t.getMinutes());
}

// ---------------------------------------------------------------- adresler
function adresListesi(adlar, adresler) {
    var o = [];
    if (!adresler) return "";
    for (var i = 0; i < adresler.length; i++) {
        var ad = adlar && adlar[i] ? adlar[i] : "";
        o.push(ad !== "" && ad !== adresler[i] ? ad + " <" + adresler[i] + ">" : adresler[i]);
    }
    return o.join(", ");
}

// ---------------------------------------------------------------- HTML
function esc(s) {
    return ("" + (s === undefined || s === null ? "" : s)).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

function decodeEnt(s) {
    return s.replace(/&nbsp;/g, " ").replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
        .replace(/&#(\d+);/g, function (m, n) { return String.fromCharCode(+n); })
        .replace(/&#x([0-9a-f]+);/gi, function (m, n) { return String.fromCharCode(parseInt(n, 16)); })
        .replace(/&amp;/g, "&");
}

function htmlToText(html) {
    var s = ("" + html)
        .replace(/<(script|style|head|title)[\s\S]*?<\/\1>/gi, "")
        .replace(/<!--[\s\S]*?-->/g, "")
        .replace(/<a\s[^>]*href\s*=\s*["']?([^"' >]+)["']?[^>]*>([\s\S]*?)<\/a>/gi, function (m, href, txt) {
            var t = txt.replace(/<[^>]+>/g, "").replace(/^\s+|\s+$/g, "");
            if (!/^https?:/i.test(href)) return t;
            return t && t !== href ? t + " [" + href + "]" : href;
        })
        .replace(/<br\s*\/?>/gi, "\n")
        .replace(/<\/(p|div|tr|h[1-6]|li|table|blockquote)>/gi, "\n")
        .replace(/<li[^>]*>/gi, "• ")
        .replace(/<td[^>]*>/gi, " ")
        .replace(/<[^>]+>/g, "");
    s = decodeEnt(s);
    return s.replace(/[ \t\u00a0]+/g, " ").replace(/ *\n */g, "\n").replace(/\n{3,}/g, "\n\n").replace(/^\s+|\s+$/g, "");
}

// Duz metni guvenli HTML'e cevirir; adresleri tiklanabilir yapar, uzun alintilari kisaltir
function textToHtml(text) {
    var lines = ("" + text).replace(/\r/g, "").split("\n");
    var out = [], quoted = 0;
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i];
        if (/^\s*>/.test(l)) { quoted++; if (quoted <= 3) out.push(l); else if (quoted === 4) out.push("> …"); continue; }
        quoted = 0;
        out.push(l);
    }
    return esc(out.join("\n"))
        .replace(/(https?:\/\/[^\s<\]\)]+)/g, function (u) { return '<a href="' + u + '">' + (u.length > 60 ? u.slice(0, 57) + "…" : u) + "</a>"; })
        .replace(/\n/g, "<br>");
}

var RICH = { a: 1, b: 1, strong: 1, i: 1, em: 1, u: 1, br: 1, p: 1, h1: 1, h2: 1, h3: 1, h4: 1, ul: 1, ol: 1, li: 1, blockquote: 1, pre: 1, hr: 1, img: 1, s: 1, small: 1, code: 1 };

function attr(tag, name) {
    var m = new RegExp("\\s" + name + "\\s*=\\s*(\"([^\"]*)\"|'([^']*)'|([^\\s>]+))", "i").exec(tag);
    return m ? (m[2] !== undefined && m[2] !== "" ? m[2] : (m[3] !== undefined && m[3] !== "" ? m[3] : (m[4] || ""))) : "";
}

function resimSay(html) { return (("" + html).match(/<img\s[^>]*src\s*=\s*["']?https?:/gi) || []).length; }

// HTML posta -> Qt zengin metni. resimler: uzak resimler gosterilsin mi (veri tasarrufu)
function htmlToRich(html, resimler, genislik) {
    var s = ("" + html)
        .replace(/<(script|style|head|title|noscript)[\s\S]*?<\/\1>/gi, "")
        .replace(/<!--[\s\S]*?-->/g, "")
        .replace(/<![^>]*>|<\?[^>]*>/g, "")
        .replace(/<\/?(table|tbody|thead|tfoot|center|font|span|section|article|header|footer|main|o:p)[^>]*>/gi, "")
        .replace(/<\/tr>/gi, "<br>").replace(/<tr[^>]*>/gi, "")
        .replace(/<\/td>|<\/th>/gi, " ").replace(/<t[dh][^>]*>/gi, "")
        .replace(/<div[^>]*>/gi, "").replace(/<\/div>/gi, "<br>");
    var adet = 0;
    var gmax = genislik || 330;
    s = s.replace(/<\/?([a-zA-Z0-9:]+)([^>]*)>/g, function (tag, name) {
        var n = name.toLowerCase();
        if (!RICH[n]) return "";
        if (tag.charAt(1) === "/") return n === "br" || n === "img" || n === "hr" ? "" : "</" + n + ">";
        if (n === "a") {
            var href = attr(tag, "href");
            return /^(https?:|mailto:)/i.test(href) ? '<a href="' + esc(decodeEnt(href)) + '">' : "<a>";
        }
        if (n === "img") {
            var src = decodeEnt(attr(tag, "src"));
            var w = parseInt(attr(tag, "width") || "0", 10), h = parseInt(attr(tag, "height") || "0", 10);
            if ((w && w <= 3) || (h && h <= 3)) return "";                  // izleme pikselleri
            if (!resimler || !/^https?:/i.test(src) || adet >= 25) return "";
            adet++;
            var boyut = "";
            if (w > gmax) boyut = ' width="' + gmax + '"' + (h ? ' height="' + Math.round(h * gmax / w) + '"' : "");
            else if (w) boyut = ' width="' + w + '"' + (h ? ' height="' + h + '"' : "");
            else boyut = ' width="' + gmax + '"';
            return '<img src="' + esc(src) + '"' + boyut + "><br>";
        }
        if (n === "h1" || n === "h2") return "<h3>";
        return "<" + n + ">";
    }).replace(/<\/h[12]>/g, "</h3>");
    s = s.replace(/[ \t\r\n]+/g, " ").replace(/(<br>\s*){3,}/g, "<br><br>").replace(/^(\s|<br>)+/, "").replace(/^\s+|\s+$/g, "");
    return { html: s.slice(0, 200000), resim: adet };
}

// ---------------------------------------------------------------- yanit / iletme taslagi
// kip: re | all | fw ; m: "mesaj" isteginin sonucu ; ben: kendi adresimiz
function taslak(kip, m, ben) {
    var r = { to: "", subject: "", body: "", ref: "" };
    var konu = m.subject || "";
    var metin = m.text && m.text !== "" ? m.text : htmlToText(m.html || "");
    if (kip === "re" || kip === "all") {
        var liste = (m.replyToAdr && m.replyToAdr.length ? m.replyToAdr : m.fromAdr) || [];
        liste = liste.slice(0);
        if (kip === "all") liste = liste.concat(m.toAdr || []).concat(m.ccAdr || []);
        var gorulen = {}, sonuc = [];
        var b = ("" + ben).toLowerCase();
        for (var i = 0; i < liste.length; i++) {
            var x = ("" + liste[i]).toLowerCase();
            if (x === "" || x === b || gorulen[x]) continue;
            gorulen[x] = 1;
            sonuc.push(liste[i]);
        }
        r.to = sonuc.join(", ");
        r.subject = /^re:/i.test(konu) ? konu : "Re: " + konu;
        r.ref = m.messageId || "";
        var satirlar = metin.split("\n").slice(0, 40);
        for (var j = 0; j < satirlar.length; j++) satirlar[j] = "> " + satirlar[j];
        r.body = "\n\n" + qsTr("%1 tarihinde %2 yazdı:").arg(uzunTarih(m.ts)).arg(m.from || m.fromAddr) + "\n" + satirlar.join("\n");
    } else {
        r.subject = /^(fw|fwd|ilt):/i.test(konu) ? konu : "Fwd: " + konu;
        r.body = "\n\n" + qsTr("---------- İletilen posta ----------") + "\n" + qsTr("Kimden: ") + adresListesi(m.fromAd, m.fromAdr) + "\n" +
                 qsTr("Tarih: ") + uzunTarih(m.ts) + "\n" + qsTr("Konu: ") + konu + "\n\n" + metin.slice(0, 20000);
    }
    return r;
}
