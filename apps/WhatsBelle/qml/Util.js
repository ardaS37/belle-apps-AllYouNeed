.pragma library
// Yardimci fonksiyonlar (ag erisimi yok, saf fonksiyonlar)

var palette = ["#00A884", "#53BDEB", "#FF6B6B", "#A78BFA", "#F59E0B", "#10B981", "#EC4899", "#6366F1", "#14B8A6", "#F97316"];

function pad(n) { return n < 10 ? "0" + n : "" + n; }

// "905321234567@c.us" -> "905321234567"
function bareId(id) {
    if (!id) return "";
    var s = "" + id;
    var at = s.indexOf("@");
    return at >= 0 ? s.substring(0, at) : s;
}

function isGroup(id) {
    return ("" + id).indexOf("@g.us") >= 0;
}

// Kullanici numarasini sunucunun bekledigi kimlige cevirir
function toJid(id) {
    var s = "" + id;
    if (s.indexOf("@") >= 0) return s;
    return s + "@c.us";
}

function initials(name) {
    if (!name) return "?";
    var s = ("" + name).replace(/^\s+|\s+$/g, "");
    if (s.length === 0) return "?";
    if (/^[0-9+@.a-z]+$/.test(s)) return "#";
    var parts = s.split(/\s+/);
    var a = parts[0].charAt(0);
    var b = parts.length > 1 ? parts[parts.length - 1].charAt(0) : "";
    return (a + b).toUpperCase();
}

function colorFor(key) {
    var s = "" + key;
    var h = 0;
    for (var i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) % 100000;
    return palette[h % palette.length];
}

// Sunucu SQLite CURRENT_TIMESTAMP kullaniyor: "YYYY-MM-DD HH:MM:SS" (UTC)
function parseTs(ts) {
    if (!ts) return null;
    var m = ("" + ts).match(/(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})/);
    if (!m) return null;
    return new Date(Date.UTC(parseInt(m[1], 10), parseInt(m[2], 10) - 1, parseInt(m[3], 10),
                             parseInt(m[4], 10), parseInt(m[5], 10), parseInt(m[6], 10)));
}

function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

function timeText(ts) {
    var d = parseTs(ts);
    if (!d) return "";
    return pad(d.getHours()) + ":" + pad(d.getMinutes());
}

// Sohbet listesindeki saat: bugun ise saat, dun ise "Dün", degilse tarih
function listTime(ts) {
    var d = parseTs(ts);
    if (!d) return "";
    var now = new Date();
    if (sameDay(d, now)) return timeText(ts);
    var y = new Date(now.getTime() - 86400000);
    if (sameDay(d, y)) return qsTr("Dün");
    return pad(d.getDate()) + "." + pad(d.getMonth() + 1) + "." + d.getFullYear();
}

// Mesaj ekranindaki gun ayiraci
function dayLabel(ts) {
    var d = parseTs(ts);
    if (!d) return "";
    var now = new Date();
    if (sameDay(d, now)) return qsTr("BUGÜN");
    var y = new Date(now.getTime() - 86400000);
    if (sameDay(d, y)) return qsTr("DÜN");
    var months = [qsTr("Ocak"), qsTr("Şubat"), qsTr("Mart"), qsTr("Nisan"), qsTr("Mayıs"), qsTr("Haziran"), qsTr("Temmuz"), qsTr("Ağustos"), qsTr("Eylül"), qsTr("Ekim"), qsTr("Kasım"), qsTr("Aralık")];
    return d.getDate() + " " + months[d.getMonth()] + " " + d.getFullYear();
}

// Medya mesajlari icin sunucudaki dosya adi (WhatsappClient.js ile ayni kural)
function mediaFile(chatType, id) {
    if (chatType === "image") return id + ".jpg";
    if (chatType === "audio" || chatType === "ptt") return id + ".mp3";
    if (chatType === "video") return id + ".3gp";
    return "";
}

function mediaLabel(chatType) {
    // Symbian fontlarinda emoji yok, duz metin kullaniliyor
    if (chatType === "image") return qsTr("Fotoğraf");
    if (chatType === "audio" || chatType === "ptt") return qsTr("Sesli mesaj");
    if (chatType === "video") return qsTr("Video");
    if (chatType === "sticker") return qsTr("Çıkartma");
    if (chatType === "document") return qsTr("Belge");
    return "";
}

function trimServer(url) {
    var s = ("" + url).replace(/^\s+|\s+$/g, "");
    if (s.length === 0) return s;
    if (s.indexOf("://") < 0) s = "http://" + s;
    while (s.charAt(s.length - 1) === "/") s = s.substring(0, s.length - 1);
    return s;
}

function cleanNumber(n) {
    var s = ("" + n).replace(/[^0-9]/g, "");
    if (s.indexOf("00") === 0) s = s.substring(2);
    return s;
}
