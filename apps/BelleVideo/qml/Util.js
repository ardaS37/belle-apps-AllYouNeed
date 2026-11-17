.pragma library

// ms -> "1:23" / "1:02:03"
function fmt(ms) {
    var s = Math.max(0, Math.floor(ms / 1000));
    var m = Math.floor(s / 60), h = Math.floor(m / 60);
    s = s % 60;
    if (h > 0) { m = m % 60; return h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s; }
    return m + ":" + (s < 10 ? "0" : "") + s;
}

// unix saniye -> "09.11.2026"
function dateText(t) {
    if (!t) return "";
    var d = new Date(t * 1000);
    var dd = d.getDate(), mm = d.getMonth() + 1;
    return (dd < 10 ? "0" : "") + dd + "." + (mm < 10 ? "0" : "") + mm + "." + d.getFullYear();
}

function sizeText(b) {
    if (b >= 1073741824) return (b / 1073741824).toFixed(2) + qsTr(" GB");
    if (b >= 1048576) return (b / 1048576).toFixed(1) + qsTr(" MB");
    return Math.ceil(b / 1024) + qsTr(" KB");
}

// Turkce kucuk harf + aksan sadelestirme (arama icin)
function fold(s) {
    s = ("" + s).toLowerCase();
    var a = qsTr("çğıöşüâîû"), b = "cgiosuaiu";
    var out = "";
    for (var i = 0; i < s.length; i++) {
        var k = a.indexOf(s.charAt(i));
        out += k >= 0 ? b.charAt(k) : s.charAt(i);
    }
    return out.replace(/İ/g, "i");
}

// Klavyeden gelen yazdirilabilir karakter mi (harf/rakam/noktalama)
function printable(event) {
    return event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127;
}
