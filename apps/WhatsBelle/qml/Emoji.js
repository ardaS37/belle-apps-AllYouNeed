// Emoji destegi: Belle'in yazi tipinde renkli emoji yok (kutu gorunur).
// En yaygin 59 emoji uygulamanin icinde kucuk resim olarak var (Twemoji, CC-BY 4.0).
// Mesajlardaki bu emojiler resimle gosterilir; panelden secilen emoji metne gercek
// Unicode karakter olarak eklenir (karsi taraf normal emoji gorur).
.pragma library

var codes = ["1f600", "1f603", "1f604", "1f601", "1f606", "1f605", "1f602", "1f923", "1f60a", "1f607",
             "1f642", "1f609", "1f60d", "1f970", "1f618", "1f60b", "1f61c", "1f914", "1f610", "1f611",
             "1f644", "1f60f", "1f612", "1f614", "1f61e", "1f622", "1f62d", "1f624", "1f621", "1f631",
             "1f633", "1f97a", "1f62e", "1f634", "1f60e", "1f917", "1f92d", "1f62c", "1f910", "1f637",
             "1f912", "1f648", "1f44d", "1f44e", "1f44f", "1f64f", "1f44b", "1f4aa", "1f44c", "270c",
             "2764", "1f494", "1f4af", "1f525", "1f389", "1f339", "2705", "274c", "2b50"];

var known = {};
for (var i = 0; i < codes.length; i++) known[codes[i]] = true;

function charFor(hex) {
    var cp = parseInt(hex, 16);
    if (cp <= 0xFFFF) return String.fromCharCode(cp);
    cp -= 0x10000;
    return String.fromCharCode(0xD800 + (cp >> 10), 0xDC00 + (cp & 0x3FF));
}

function imgPath(hex) { return "qrc:/images/emoji/" + hex + ".png"; }

// Metinde emoji olabilecek karakter var mi (hizli on kontrol)
function has(s) {
    return /[\uD800-\uDBFF]|[☀-➿]|⭐|⭕|〰|〽/.test(s);
}

function esc(c) {
    if (c === "&") return "&amp;";
    if (c === "<") return "&lt;";
    if (c === ">") return "&gt;";
    if (c === "\"") return "&quot;";
    if (c === "\n") return "<br>";
    return c;
}

// Duz metni, bilinen emojileri <img> olan zengin metne cevirir
function rich(s, size) {
    var px = size ? size : 24;
    var out = "";
    for (var i = 0; i < s.length; i++) {
        var c = s.charCodeAt(i);
        var cp = c;
        var len = 1;
        if (c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length) {
            var lo = s.charCodeAt(i + 1);
            if (lo >= 0xDC00 && lo <= 0xDFFF) { cp = (c - 0xD800) * 0x400 + (lo - 0xDC00) + 0x10000; len = 2; }
        }
        // Gorunmez yardimci karakterler: varyasyon secici, ten rengi, birlestirici
        if (cp === 0xFE0F || cp === 0x200D || (cp >= 0x1F3FB && cp <= 0x1F3FF)) { i += len - 1; continue; }
        var hex = cp.toString(16);
        if (known[hex]) {
            out += qsTr("<img src=\"") + imgPath(hex) + qsTr("\" width=\"") + px + qsTr("\" height=\"") + px + "\">";
        } else {
            out += len === 2 ? s.substr(i, 2) : esc(s.charAt(i));
        }
        i += len - 1;
    }
    return out;
}
