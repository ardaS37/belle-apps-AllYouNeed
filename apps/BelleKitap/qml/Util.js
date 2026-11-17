.pragma library

// unix saniye -> "09.11.2026 14:05"
function dateText(t) {
    if (!t) return "";
    var d = new Date(t * 1000);
    function z(n) { return (n < 10 ? "0" : "") + n; }
    return z(d.getDate()) + "." + z(d.getMonth() + 1) + "." + d.getFullYear() + " " + z(d.getHours()) + ":" + z(d.getMinutes());
}

function sizeText(b) {
    if (b >= 1073741824) return (b / 1073741824).toFixed(2) + qsTr(" GB");
    if (b >= 1048576) return (b / 1048576).toFixed(1) + qsTr(" MB");
    if (b < 1024) return b + " B";
    return Math.ceil(b / 1024) + qsTr(" KB");
}

// Uzunlugu koruyan sadelestirme (arama icin): kucuk harf, Turkce harfler -> Latin.
// Her karakter tek karaktere donusur, boylece bulunan konum asil metinde de gecerlidir.
function fold(s) {
    s = "" + s;
    var a = qsTr("çÇğĞıIİöÖşŞüÜâÂîÎûÛ"), b = "ccggiiioossuuaaiiuu";
    var out = "";
    for (var i = 0; i < s.length; i++) {
        var c = s.charAt(i);
        var k = a.indexOf(c);
        if (k >= 0) out += b.charAt(k);
        else {
            var l = c.toLowerCase();
            out += l.length === 1 ? l : c;
        }
    }
    return out;
}

// Turkce buyuk / kucuk harf
function upperTr(s) {
    var out = "";
    for (var i = 0; i < s.length; i++) {
        var c = s.charAt(i);
        if (c === "i") out += "İ"; else if (c === "ı") out += "I";
        else { var u = c.toUpperCase(); out += u.length === 1 ? u : c; }
    }
    return out;
}
function lowerTr(s) {
    var out = "";
    for (var i = 0; i < s.length; i++) {
        var c = s.charAt(i);
        if (c === "I") out += "ı"; else if (c === "İ") out += "i";
        else { var l = c.toLowerCase(); out += l.length === 1 ? l : c; }
    }
    return out;
}
// Her kelimenin ilk harfi buyuk
function titleTr(s) {
    var out = "", start = true;
    for (var i = 0; i < s.length; i++) {
        var c = s.charAt(i);
        out += start ? upperTr(c) : lowerTr(c);
        start = /[\s\-\(\["'\/]/.test(c);
    }
    return out;
}

// Klavyeden gelen yazdirilabilir karakter mi
function printable(event) {
    if (tus(event) !== "") return true;
    return event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127;
}

// Ctrl+harf E6'da denetim karakteri (1-26) olarak gelir; Enter(13), Tab(9), LF(10), Backspace(8) haric
function ctrlKod(event) {
    var c = event.text && event.text.length === 1 ? event.text.charCodeAt(0) : 0;
    return c >= 1 && c <= 26 && c !== 8 && c !== 9 && c !== 10 && c !== 13 ? c : 0;
}
function ctrl(event) {
    return (event.modifiers & 0x04000000) !== 0 || ctrlKod(event) !== 0;   // Qt.ControlModifier
}

// Kisayol harfi: E6'da yazi kutusu disinda harf tuslari Qt.Key_A..Z yerine kucuk harf kodu (97-122)
// ya da tusun ustundeki rakami/isareti gonderir (R=1, T=2, F=4, D=-, X=% ...). Hepsini tusun harfine cevirir.
var E6TUS = { "1": "r", "2": "t", "3": "y", "4": "f", "5": "g", "6": "h", "7": "v", "8": "b", "9": "n", "0": "m",
              "-": "d", "%": "x", "#": "j", "ş": "k", "ğ": "i" };
function tus(event) {
    var k = event.key;
    var cc = ctrlKod(event);
    if (cc) return String.fromCharCode(96 + cc);
    if (k >= 0x41 && k <= 0x5a) return String.fromCharCode(k + 32);     // Qt.Key_A..Z
    if (k >= 97 && k <= 122) return String.fromCharCode(k);
    var t = event.text || "";
    if (t.length !== 1) return "";
    var l = t.toLowerCase();
    if (E6TUS[l] !== undefined) return E6TUS[l];
    return fold(l);
}

// Dosya turune gore simge adi
function iconFor(ext, isDir) {
    if (isDir) return "folder";
    ext = (ext || "").toLowerCase();
    if (/^(html?|xhtml|shtml|css|js|mjs|ts|json|xml|qml|py|c|cpp|cc|h|hpp|java|php|rb|sh|bat|cmd|ps1|sql|svg|yaml|yml|lua|pl|go|rs)$/.test(ext)) return "code";
    if (/^(vcf)$/.test(ext)) return "person";
    if (/^(vcs|ics)$/.test(ext)) return "cal";
    if (/^(m3u|m3u8|pls|lrc)$/.test(ext)) return "note";
    if (/^(zip|rar|7z|jar|sis|sisx|gz|tar)$/.test(ext)) return "zip";
    if (/^(mp3|aac|m4a|wav|amr|ogg|wma|flac|mid|midi|awb|3ga)$/.test(ext)) return "muzik";
    if (/^(mp4|3gp|3g2|avi|mkv|mov|wmv|flv|m4v|webm)$/.test(ext)) return "play";
    if (/^(csv|tsv)$/.test(ext)) return "table";
    if (/^(txt|text|log|md|ini|cfg|conf|nfo|srt|sub|rtf|markdown|todo|readme|)$/.test(ext)) return "doc";
    return "file";
}

function encodingLabel(e) {
    if (!e) return qsTr("Otomatik");
    if (e === "windows-1254") return qsTr("Türkçe (Windows-1254)");
    if (e === "ISO-8859-9") return qsTr("Türkçe (ISO-8859-9)");
    if (e === "ISO-8859-1") return qsTr("Batı (ISO-8859-1)");
    return e;
}

function eolLabel(e) {
    if (e === "crlf") return qsTr("CRLF (Windows)");
    if (e === "lf") return qsTr("LF (Unix)");
    if (e === "cr") return qsTr("CR (eski Mac)");
    return "-";
}

// Satir ve kelime sayisi
function stats(t) {
    var lines = t.length === 0 ? 0 : t.split("\n").length;
    var words = 0;
    var m = t.match(/[^\s]+/g);
    if (m) words = m.length;
    var nospace = t.replace(/\s/g, "").length;
    return { lines: lines, words: words, chars: t.length, nospace: nospace };
}
