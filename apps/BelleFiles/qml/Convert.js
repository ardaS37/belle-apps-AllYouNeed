.pragma library

// Uzanti degistirme ve icerik donusturme, yeni dosya sablonlari, metin araclari.
// Her donusturucu: fn(metin, baslik) -> { text, note } (note: kullaniciya kisa bilgi)

function esc(s) {
    return ("" + s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}
function z(n) { return (n < 10 ? "0" : "") + n; }

// ---- Hedefler (Uzanti / donustur menusu) ----
// conv: icerik donusturucu adi (bos: yalnizca uzanti degisir). open: donusunce sistemde acmayi oner.
var targets = [
    { ext: "html", label: qsTr("Web sayfası"), conv: "html", open: true, info: qsTr("Tarayıcıda açılır") },
    { ext: "txt",  label: qsTr("Düz metin"), conv: "text", open: false, info: qsTr("HTML / JSON / CSV düz metne") },
    { ext: "vcf",  label: qsTr("Kişi kartı"), conv: "vcf", open: true, info: qsTr("Rehbere eklenir") },
    { ext: "vcs",  label: qsTr("Takvim etkinliği"), conv: "vcs", open: true, info: qsTr("Takvime eklenir") },
    { ext: "m3u",  label: qsTr("Çalma listesi"), conv: "m3u", open: true, info: qsTr("Müzik çalarda açılır") },
    { ext: "md",   label: qsTr("Markdown"), conv: "", open: false, info: "" },
    { ext: "csv",  label: qsTr("Tablo (CSV)"), conv: "csv", open: false, info: qsTr("Sütunlar virgülle") },
    { ext: "json", label: "JSON", conv: "json", open: false, info: qsTr("anahtar: değer → nesne") },
    { ext: "xml",  label: "XML", conv: "xml", open: false, info: "" },
    { ext: "ini",  label: qsTr("Ayar dosyası (INI)"), conv: "", open: false, info: "" },
    { ext: "js",   label: qsTr("JavaScript"), conv: "", open: false, info: "" },
    { ext: "css",  label: qsTr("Stil (CSS)"), conv: "", open: false, info: "" },
    { ext: "svg",  label: qsTr("SVG resim"), conv: "", open: true, info: "" },
    { ext: "srt",  label: qsTr("Altyazı (SRT)"), conv: "srt", open: false, info: qsTr("Her satır 3 sn") },
    { ext: "log",  label: qsTr("Günlük (LOG)"), conv: "", open: false, info: "" },
    { ext: "py",   label: qsTr("Python"), conv: "", open: false, info: "" },
    { ext: "sh",   label: qsTr("Kabuk betiği"), conv: "", open: false, info: "" },
    { ext: "bat",  label: qsTr("Toplu iş (BAT)"), conv: "", open: false, info: "" },
    { ext: "",     label: qsTr("Uzantısız"), conv: "", open: false, info: "" }
];

function targetFor(ext) {
    for (var i = 0; i < targets.length; i++) if (targets[i].ext === ext) return targets[i];
    return { ext: ext, label: "." + ext, conv: "", open: false, info: "" };
}

function convert(conv, text, title, srcExt) {
    if (conv === "html") return toHtml(text, title);
    if (conv === "text") return toText(text, srcExt);
    if (conv === "vcf") return toVcf(text);
    if (conv === "vcs") return toVcs(text);
    if (conv === "m3u") return toM3u(text);
    if (conv === "csv") return toCsv(text);
    if (conv === "json") return toJson(text);
    if (conv === "xml") return toXml(text, title);
    if (conv === "srt") return toSrt(text);
    return { text: text, note: "" };
}

// ---- HTML ----
function looksHtml(t) { return /<\s*(html|body|head|div|p|table|!doctype)\b/i.test(t); }

function linkify(s) {
    return s.replace(/(https?:\/\/[^\s<]+)/g, '<a href="$1">$1</a>');
}

function inline(s) {
    s = esc(s);
    s = s.replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>");
    s = s.replace(/(^|[^*])\*([^*\s][^*]*)\*/g, "$1<i>$2</i>");
    s = s.replace(/`([^`]+)`/g, "<code>$1</code>");
    return linkify(s);
}

function htmlPage(title, body) {
    return qsTr("<!DOCTYPE html>\n<html lang=\"tr\">\n<head>\n<meta charset=\"utf-8\">\n") +
        qsTr("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n") +
        "<title>" + esc(title) + "</title>\n<style>\n" +
        "body{font-family:sans-serif;margin:12px;line-height:1.5;color:#222;background:#fdfdfd}\n" +
        qsTr("h1,h2,h3{color:#1E6FB8}pre,code{background:#eef3f7;padding:2px 4px}pre{padding:8px;white-space:pre-wrap}\n") +
        qsTr("table{border-collapse:collapse}td,th{border:1px solid #bbb;padding:3px 6px}a{color:#1E6FB8}\n") +
        "</style>\n</head>\n<body>\n" + body + "\n</body>\n</html>\n";
}

// Basit isaretler: # baslik, - madde, 1. madde, ``` kod ```, bos satir paragraf, adresler baglanti
function toHtml(text, title) {
    if (looksHtml(text)) return { text: text, note: qsTr("Zaten HTML, içerik korundu") };
    var lines = text.split("\n");
    var out = [], para = [], list = "", inCode = false;
    function flushPara() { if (para.length) { out.push("<p>" + para.join("<br>\n") + "</p>"); para = []; } }
    function closeList() { if (list) { out.push("</" + list + ">"); list = ""; } }
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i];
        if (/^\s*```/.test(l)) {
            flushPara(); closeList();
            out.push(inCode ? "</pre>" : "<pre>");
            inCode = !inCode;
            continue;
        }
        if (inCode) { out.push(esc(l)); continue; }
        var m;
        if ((m = /^(#{1,3})\s+(.*)$/.exec(l))) {
            flushPara(); closeList();
            var n = m[1].length;
            out.push("<h" + n + ">" + inline(m[2]) + "</h" + n + ">");
        } else if ((m = /^\s*[-*•]\s+(.*)$/.exec(l))) {
            flushPara();
            if (list !== "ul") { closeList(); out.push("<ul>"); list = "ul"; }
            out.push("<li>" + inline(m[1]) + "</li>");
        } else if ((m = /^\s*\d+[.)]\s+(.*)$/.exec(l))) {
            flushPara();
            if (list !== "ol") { closeList(); out.push("<ol>"); list = "ol"; }
            out.push("<li>" + inline(m[1]) + "</li>");
        } else if (/^\s*(-{3,}|_{3,})\s*$/.test(l)) {
            flushPara(); closeList();
            out.push("<hr>");
        } else if (/^\s*$/.test(l)) {
            flushPara(); closeList();
        } else {
            closeList();
            para.push(inline(l));
        }
    }
    if (inCode) out.push("</pre>");
    flushPara(); closeList();
    return { text: htmlPage(title, out.join("\n")), note: "" };
}

function decodeEntities(s) {
    return s.replace(/&nbsp;/g, " ").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"")
        .replace(/&#39;|&apos;/g, "'").replace(/&#(\d+);/g, function (a, n) { return String.fromCharCode(parseInt(n, 10)); })
        .replace(/&#x([0-9a-f]+);/gi, function (a, n) { return String.fromCharCode(parseInt(n, 16)); })
        .replace(/&amp;/g, "&");
}

function htmlToText(t) {
    var s = t.replace(/\r/g, "");
    s = s.replace(/<(script|style|head)[^>]*>[\s\S]*?<\/\1>/gi, "");
    s = s.replace(/<br\s*\/?>/gi, "\n");
    s = s.replace(/<li[^>]*>/gi, "\n- ");
    s = s.replace(/<h[1-6][^>]*>/gi, "\n\n# ");
    s = s.replace(/<\/(p|div|h[1-6]|tr|table|ul|ol|pre|blockquote)>/gi, "\n");
    s = s.replace(/<(p|div|tr|table|pre|blockquote)[^>]*>/gi, "\n");
    s = s.replace(/<\/t[dh]>/gi, "\t");
    s = s.replace(/<[^>]+>/g, "");
    s = decodeEntities(s);
    s = s.replace(/[ \t]+\n/g, "\n").replace(/\n{3,}/g, "\n\n");
    return s.replace(/^\s+|\s+$/g, "") + "\n";
}

// Kaynak turune gore duz metin
function toText(text, srcExt) {
    srcExt = (srcExt || "").toLowerCase();
    if (/^(html?|xhtml|xml|svg)$/.test(srcExt) || looksHtml(text)) return { text: htmlToText(text), note: qsTr("Etiketler temizlendi") };
    if (srcExt === "json") {
        try { return { text: jsonToText(JSON.parse(text), 0), note: qsTr("JSON düz metne çevrildi") }; } catch (e) { }
    }
    if (srcExt === "csv" || srcExt === "tsv") return { text: csvToText(text, srcExt === "tsv" ? "\t" : ""), note: qsTr("Tablo hizalandı") };
    if (srcExt === "vcf") return { text: vcfToText(text), note: qsTr("Kişiler listelendi") };
    return { text: text, note: "" };
}

function jsonToText(v, depth) {
    var pad = new Array(depth + 1).join("  ");
    if (v === null) return qsTr("boş");
    if (typeof v !== "object") return "" + v;
    var out = [];
    if (v instanceof Array) {
        for (var i = 0; i < v.length; i++) {
            if (typeof v[i] === "object" && v[i] !== null) out.push(pad + "-\n" + jsonToText(v[i], depth + 1));
            else out.push(pad + "- " + jsonToText(v[i], 0));
        }
    } else {
        for (var k in v) {
            if (typeof v[k] === "object" && v[k] !== null) out.push(pad + k + ":\n" + jsonToText(v[k], depth + 1));
            else out.push(pad + k + ": " + jsonToText(v[k], 0));
        }
    }
    return out.join("\n");
}

// ---- CSV ----
function splitLine(l) {
    if (l.indexOf("\t") >= 0) return l.split("\t");
    if (l.indexOf(";") >= 0) return l.split(";");
    if (l.indexOf("|") >= 0) return l.replace(/^\s*\||\|\s*$/g, "").split("|");
    if (/\S\s{2,}\S/.test(l)) return l.split(/\s{2,}/);
    if (l.indexOf(",") >= 0) return parseCsvLine(l);
    return [l];
}
function csvField(f) {
    f = ("" + f).replace(/^\s+|\s+$/g, "");
    if (/[",\n]/.test(f)) return "\"" + f.replace(/"/g, "\"\"") + "\"";
    return f;
}
function toCsv(text) {
    var lines = text.split("\n"), out = [];
    for (var i = 0; i < lines.length; i++) {
        if (/^\s*$/.test(lines[i])) continue;
        var cells = splitLine(lines[i]);
        for (var j = 0; j < cells.length; j++) cells[j] = csvField(cells[j]);
        out.push(cells.join(","));
    }
    return { text: out.join("\n") + "\n", note: out.length + qsTr(" satır") };
}
function parseCsvLine(l, sep) {
    sep = sep || ",";
    var out = [], cur = "", q = false;
    for (var i = 0; i < l.length; i++) {
        var c = l.charAt(i);
        if (q) {
            if (c === "\"") { if (l.charAt(i + 1) === "\"") { cur += "\""; i++; } else q = false; }
            else cur += c;
        } else if (c === "\"") q = true;
        else if (c === sep) { out.push(cur); cur = ""; }
        else cur += c;
    }
    out.push(cur);
    return out;
}
function csvToText(text, sep) {
    var lines = text.split("\n"), rows = [], widths = [];
    if (!sep) sep = (lines[0] || "").indexOf(";") >= 0 && (lines[0] || "").indexOf(",") < 0 ? ";" : ",";
    for (var i = 0; i < lines.length; i++) {
        if (/^\s*$/.test(lines[i])) continue;
        var r = parseCsvLine(lines[i], sep);
        rows.push(r);
        for (var j = 0; j < r.length; j++) widths[j] = Math.max(widths[j] || 0, Math.min(30, r[j].length));
    }
    var out = [];
    for (i = 0; i < rows.length; i++) {
        var s = "";
        for (j = 0; j < rows[i].length; j++) {
            var c = rows[i][j];
            s += c + (j < rows[i].length - 1 ? new Array(Math.max(1, widths[j] - c.length + 2) + 1).join(" ") : "");
        }
        out.push(s);
    }
    return out.join("\n") + "\n";
}

// ---- JSON ----
function toJson(text) {
    try { return { text: JSON.stringify(JSON.parse(text), null, 2) + "\n", note: qsTr("Geçerli JSON, düzenlendi") }; } catch (e) { }
    var lines = text.split("\n"), obj = {}, arr = [], kv = 0, n = 0;
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i].replace(/^\s+|\s+$/g, "");
        if (l === "" || l.charAt(0) === "#") continue;
        n++;
        arr.push(l);
        var m = /^([^:=]{1,60}?)\s*[:=]\s*(.*)$/.exec(l);
        if (m) { kv++; obj[m[1]] = value(m[2]); }
    }
    if (n > 0 && kv === n) return { text: JSON.stringify(obj, null, 2) + "\n", note: kv + qsTr(" anahtar") };
    return { text: JSON.stringify(arr, null, 2) + "\n", note: n + qsTr(" satırlık dizi") };
}
function value(s) {
    if (/^-?\d+(\.\d+)?$/.test(s)) return parseFloat(s);
    if (s === "true" || s === "evet") return true;
    if (s === "false" || s === "hayır") return false;
    return s;
}

// ---- XML ----
function toXml(text, title) {
    if (/^\s*</.test(text)) return { text: text, note: qsTr("Zaten XML, içerik korundu") };
    var lines = text.split("\n"), out = [qsTr("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"), qsTr("<belge ad=\"") + esc(title) + "\">"];
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i].replace(/^\s+|\s+$/g, "");
        if (l === "") continue;
        var m = /^([A-Za-z_][\w.\-]{0,40})\s*[:=]\s*(.*)$/.exec(l);
        if (m) out.push("  <" + m[1] + ">" + esc(m[2]) + "</" + m[1] + ">");
        else out.push(qsTr("  <satir>") + esc(l) + "</satir>");
    }
    out.push("</belge>");
    return { text: out.join("\n") + "\n", note: "" };
}

// ---- M3U ----
function toM3u(text) {
    var lines = text.split("\n"), out = ["#EXTM3U"], n = 0;
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i].replace(/^\s+|\s+$/g, "");
        if (l === "" || l === "#EXTM3U") continue;
        if (l.charAt(0) === "#") { out.push(l); continue; }
        var isUrl = /^[a-z]+:\/\//i.test(l);
        var p = isUrl ? l : l.replace(/\//g, "\\");
        var name = l.replace(/^.*[\/\\]/, "").replace(/\.[^.]*$/, "");
        out.push("#EXTINF:-1," + (name || l));
        out.push(p);
        n++;
    }
    return { text: out.join("\n") + "\n", note: n + qsTr(" parça") };
}

// ---- vCard ----
var phoneRe = /(\+?\d[\d\s\-().]{6,}\d)/;
var mailRe = /([\w.+\-]+@[\w\-]+\.[\w.\-]+)/;

function vcard(name, phones, mails, extra) {
    name = name.replace(/^\s+|\s+$/g, "") || (phones[0] || mails[0] || qsTr("Kişi"));
    var parts = name.split(/\s+/), last = parts.length > 1 ? parts.pop() : "", first = parts.join(" ");
    var c = ["BEGIN:VCARD", "VERSION:2.1",
             "N;CHARSET=UTF-8:" + last + ";" + first + ";;;",
             "FN;CHARSET=UTF-8:" + name];
    for (var i = 0; i < phones.length; i++) c.push((i === 0 ? "TEL;CELL:" : "TEL;VOICE:") + phones[i].replace(/[^\d+]/g, ""));
    for (i = 0; i < mails.length; i++) c.push("EMAIL;INTERNET:" + mails[i]);
    if (extra) c.push("NOTE;CHARSET=UTF-8:" + extra);
    c.push("END:VCARD");
    return c.join("\r\n");
}

// Bicimler: her satirda bir kisi ("Ali Veli 0555 111 22 33", "Ali Veli; 0555...; ali@x.com")
// ya da bos satirla ayrilmis bloklar ("Ad: ..", "Tel: ..", "E-posta: ..")
function toVcf(text) {
    if (/BEGIN:VCARD/i.test(text)) return { text: text, note: qsTr("Zaten vCard") };
    var blocks = [], cards = [];
    var lines = text.split("\n");
    var perLine = true, nonEmpty = 0;
    for (var i = 0; i < lines.length; i++) {
        if (/^\s*$/.test(lines[i])) continue;
        nonEmpty++;
        if (!phoneRe.test(lines[i]) && !mailRe.test(lines[i])) perLine = false;
        if (/^\s*(ad|isim|name|tel|telefon|cep|e-?posta|mail|not)\s*[:=]/i.test(lines[i])) perLine = false;
    }
    if (perLine) {
        for (i = 0; i < lines.length; i++) if (!/^\s*$/.test(lines[i])) blocks.push([lines[i]]);
    } else {
        var cur = [];
        for (i = 0; i < lines.length; i++) {
            if (/^\s*$/.test(lines[i])) { if (cur.length) blocks.push(cur); cur = []; }
            else cur.push(lines[i]);
        }
        if (cur.length) blocks.push(cur);
    }
    for (var b = 0; b < blocks.length; b++) {
        var name = "", phones = [], mails = [], note = "";
        for (var j = 0; j < blocks[b].length; j++) {
            var l = blocks[b][j], m;
            if ((m = /^\s*(ad|isim|ad soyad|name)\s*[:=]\s*(.*)$/i.exec(l))) { name = m[2]; continue; }
            if ((m = /^\s*(not|note|açıklama)\s*[:=]\s*(.*)$/i.exec(l))) { note = m[2]; continue; }
            var rest = l.replace(/^\s*(tel|telefon|cep|ev|iş|gsm|e-?posta|mail)\s*[:=]\s*/i, "");
            var pm, mm;
            while ((mm = mailRe.exec(rest))) { mails.push(mm[1]); rest = rest.replace(mm[1], " "); }
            while ((pm = phoneRe.exec(rest))) { phones.push(pm[1]); rest = rest.replace(pm[1], " "); }
            rest = rest.replace(/https?:\/\/\S+/g, " ").replace(/[;,|]+/g, " ").replace(/^[\s#\-*•>]+|\s+$/g, "").replace(/\s{2,}/g, " ");
            if (rest && !name) name = rest;
        }
        if (name || phones.length || mails.length) cards.push(vcard(name, phones, mails, note));
    }
    return { text: cards.join("\r\n") + "\r\n", note: cards.length + qsTr(" kişi") };
}

function vcfToText(t) {
    var out = [], cur = null;
    var lines = t.replace(/\r/g, "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i];
        if (/^BEGIN:VCARD/i.test(l)) cur = { n: "", t: [], e: [] };
        else if (/^END:VCARD/i.test(l) && cur) { out.push([cur.n].concat(cur.t).concat(cur.e).join("; ")); cur = null; }
        else if (cur) {
            var v = l.substring(l.indexOf(":") + 1);
            if (/^FN[;:]/i.test(l)) cur.n = v;
            else if (/^TEL[;:]/i.test(l)) cur.t.push(v);
            else if (/^EMAIL[;:]/i.test(l)) cur.e.push(v);
        }
    }
    return out.join("\n") + "\n";
}

// ---- vCalendar (Symbian takvimi .vcs okur) ----
// Satir bicimi: "12.11.2026 14:30 Toplanti", "2026-11-12 09:00-10:30 Doktor", "12.11.2026 Dogum gunu" (tum gun)
function toVcs(text) {
    if (/BEGIN:VCALENDAR/i.test(text)) return { text: text, note: qsTr("Zaten takvim dosyası") };
    var lines = text.split("\n"), ev = [], skipped = 0;
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i].replace(/^\s+|\s+$/g, "");
        if (l === "") continue;
        var m = /^(\d{1,2})[.\/](\d{1,2})[.\/](\d{4})\s*(.*)$/.exec(l), y, mo, d, rest;
        if (m) { d = +m[1]; mo = +m[2]; y = +m[3]; rest = m[4]; }
        else if ((m = /^(\d{4})-(\d{1,2})-(\d{1,2})\s*(.*)$/.exec(l))) { y = +m[1]; mo = +m[2]; d = +m[3]; rest = m[4]; }
        else { skipped++; continue; }
        var t = /^(\d{1,2})[:.](\d{2})(?:\s*-\s*(\d{1,2})[:.](\d{2}))?\s*(.*)$/.exec(rest);
        var date = y + z(mo) + z(d), start, end, title;
        if (t) {
            var h1 = +t[1], m1 = +t[2], h2 = t[3] ? +t[3] : h1 + 1, m2 = t[3] ? +t[4] : m1;
            if (h2 > 23) { h2 = 23; m2 = 59; }
            start = date + "T" + z(h1) + z(m1) + "00";
            end = date + "T" + z(h2) + z(m2) + "00";
            title = t[5];
        } else {
            start = date + "T000000";
            end = date + "T235900";
            title = rest;
        }
        ev.push(["BEGIN:VEVENT", "SUMMARY;CHARSET=UTF-8:" + (title || qsTr("Etkinlik")), "DTSTART:" + start, "DTEND:" + end,
                 "AALARM:" + start, "END:VEVENT"].join("\r\n"));
    }
    var out = "BEGIN:VCALENDAR\r\nVERSION:1.0\r\n" + ev.join("\r\n") + (ev.length ? "\r\n" : "") + "END:VCALENDAR\r\n";
    return { text: out, note: ev.length + qsTr(" etkinlik") + (skipped ? ", " + skipped + qsTr(" satır tarihsiz atlandı") : "") };
}

// ---- SRT ----
function toSrt(text) {
    if (/^\s*1\s*\n\d\d:\d\d:\d\d,\d{3} -->/.test(text)) return { text: text, note: qsTr("Zaten SRT") };
    var lines = text.split("\n"), out = [], n = 0;
    function ts(s) { var h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, x = s % 60; return z(h) + ":" + z(m) + ":" + z(x) + ",000"; }
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i].replace(/^\s+|\s+$/g, "");
        if (l === "") continue;
        out.push((n + 1) + "\n" + ts(n * 3) + " --> " + ts(n * 3 + 3) + "\n" + l + "\n");
        n++;
    }
    return { text: out.join("\n"), note: n + qsTr(" altyazı") };
}

// ---- Yeni dosya sablonlari ----
var templates = [
    { key: "blank", label: qsTr("Boş not"), ext: "txt", icon: "doc" },
    { key: "todo", label: qsTr("Yapılacaklar listesi"), ext: "txt", icon: "check" },
    { key: "diary", label: qsTr("Günlük (tarihli)"), ext: "txt", icon: "clock" },
    { key: "html", label: qsTr("Web sayfası (HTML)"), ext: "html", icon: "code" },
    { key: "vcf", label: qsTr("Kişi kartı (vCard)"), ext: "vcf", icon: "person" },
    { key: "vcs", label: qsTr("Takvim etkinliği (vcs)"), ext: "vcs", icon: "cal" },
    { key: "m3u", label: qsTr("Çalma listesi (M3U)"), ext: "m3u", icon: "note" },
    { key: "csv", label: qsTr("Tablo (CSV)"), ext: "csv", icon: "table" },
    { key: "json", label: "JSON", ext: "json", icon: "code" },
    { key: "ini", label: qsTr("Ayar dosyası (INI)"), ext: "ini", icon: "gear" },
    { key: "md", label: qsTr("Markdown"), ext: "md", icon: "doc" }
];

function template(key, dateStr, timeStr) {
    var d = dateStr || "", t = timeStr || "";
    if (key === "todo") return qsTr("Yapılacaklar - ") + d + "\n\n[ ] \n[ ] \n[ ] \n";
    if (key === "diary") return d + " " + t + "\n------------------\n\n";
    if (key === "html") return htmlPage(qsTr("Yeni sayfa"), qsTr("<h1>Başlık</h1>\n<p>Metin buraya.</p>\n<ul>\n<li>Madde</li>\n</ul>"));
    if (key === "vcf") return qsTr("BEGIN:VCARD\r\nVERSION:2.1\r\nN;CHARSET=UTF-8:Soyad;Ad;;;\r\nFN;CHARSET=UTF-8:Ad Soyad\r\nTEL;CELL:+90\r\nEMAIL;INTERNET:\r\nEND:VCARD\r\n");
    if (key === "vcs") {
        var p = d.split("."), dd = p.length === 3 ? p[2] + p[1] + p[0] : "20260101";
        return "BEGIN:VCALENDAR\r\nVERSION:1.0\r\nBEGIN:VEVENT\r\nSUMMARY;CHARSET=UTF-8:Etkinlik\r\nDTSTART:" + dd + "T090000\r\nDTEND:" + dd + "T100000\r\nAALARM:" + dd + "T090000\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n";
    }
    if (key === "m3u") return "#EXTM3U\n#EXTINF:-1,Parça adı\nE:\\Music\\parca.mp3\n";
    if (key === "csv") return "Ad,Telefon,Not\n,,\n";
    if (key === "json") return qsTr("{\n  \"ad\": \"\",\n  \"liste\": []\n}\n");
    if (key === "ini") return qsTr("[Genel]\nanahtar=değer\n");
    if (key === "md") return "# Başlık\n\n- madde\n- madde\n\n**kalın** *eğik*\n";
    return "";
}

// ---- Metin araclari (satir islemleri) ----
function sortLines(t, desc) {
    var a = t.split("\n");
    var trailing = a.length > 1 && a[a.length - 1] === "";
    if (trailing) a.pop();
    a.sort(function (x, y) { return x.toLowerCase().localeCompare(y.toLowerCase()); });
    if (desc) a.reverse();
    return a.join("\n") + (trailing ? "\n" : "");
}
function uniqLines(t) {
    var a = t.split("\n"), seen = {}, out = [];
    for (var i = 0; i < a.length; i++) {
        if (a[i] !== "" && seen["k" + a[i]]) continue;
        seen["k" + a[i]] = true;
        out.push(a[i]);
    }
    return out.join("\n");
}
function removeBlank(t) { return t.replace(/\n[ \t]*(?=\n)/g, "").replace(/^[ \t]*\n/, ""); }
function trimLines(t) { return t.replace(/[ \t]+$/gm, ""); }
function numberLines(t) {
    var a = t.split("\n");
    for (var i = 0; i < a.length; i++) if (a[i] !== "" || i < a.length - 1) a[i] = (i + 1) + ". " + a[i];
    return a.join("\n");
}
function reverseLines(t) { return t.split("\n").reverse().join("\n"); }
function joinLines(t) { return t.replace(/\s*\n\s*/g, " "); }
function toggleTodo(line) {
    if (/^\s*\[x\]/i.test(line)) return line.replace(/\[x\]/i, "[ ]");
    if (/^\s*\[ \]/.test(line)) return line.replace("[ ]", "[x]");
    return "[ ] " + line;
}
