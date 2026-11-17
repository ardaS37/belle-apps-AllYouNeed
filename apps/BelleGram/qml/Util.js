.pragma library
// BelleGram yardimcilari (saf fonksiyonlar). Zamanlar milisaniye (sayi).

var palette = ["#E17076", "#7BC862", "#65AADD", "#A695E7", "#EE7AAE", "#6EC9CB", "#FAA774", "#5288C1"];

function pad(n) { return n < 10 ? "0" + n : "" + n; }

function initials(name) {
    if (!name) return "?";
    var s = ("" + name).replace(/^\s+|\s+$/g, "");
    if (s.length === 0) return "?";
    if (/^[0-9+@.]+$/.test(s)) return "#";
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

function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

function saat(ms) {
    if (!ms) return "";
    var d = new Date(ms);
    return pad(d.getHours()) + ":" + pad(d.getMinutes());
}

// Sohbet listesi: bugun saat, dun "Dun", bu hafta gun adi, degilse tarih
function listeZamani(ms) {
    if (!ms) return "";
    var d = new Date(ms);
    var now = new Date();
    if (sameDay(d, now)) return saat(ms);
    var y = new Date(now.getTime() - 86400000);
    if (sameDay(d, y)) return qsTr("Dün");
    return pad(d.getDate()) + "." + pad(d.getMonth() + 1) + "." + (d.getFullYear() % 100);
}

function gunEtiketi(ms) {
    if (!ms) return "";
    var d = new Date(ms);
    var now = new Date();
    if (sameDay(d, now)) return qsTr("Bugün");
    var y = new Date(now.getTime() - 86400000);
    if (sameDay(d, y)) return qsTr("Dün");
    var aylar = [qsTr("Ocak"), qsTr("Şubat"), qsTr("Mart"), qsTr("Nisan"), qsTr("Mayıs"), qsTr("Haziran"), qsTr("Temmuz"), qsTr("Ağustos"), qsTr("Eylül"), qsTr("Ekim"), qsTr("Kasım"), qsTr("Aralık")];
    return d.getDate() + " " + aylar[d.getMonth()] + (d.getFullYear() !== now.getFullYear() ? " " + d.getFullYear() : "");
}

function ayniGun(a, b) {
    if (!a || !b) return false;
    return sameDay(new Date(a), new Date(b));
}

function sure(sn) {
    sn = Math.max(0, Math.round(sn || 0));
    return Math.floor(sn / 60) + ":" + pad(sn % 60);
}

function boyut(b) {
    if (!b) return "";
    if (b < 1024) return b + " B";
    if (b < 1048576) return Math.round(b / 1024) + " KB";
    return (b / 1048576).toFixed(1) + " MB";
}

// Mesaj turunun etiketi (Symbian fontlarinda emoji yok: duz metin)
function turEtiketi(m) {
    var t = m.tur;
    if (t === "foto") return qsTr("Fotoğraf");
    if (t === "ses") return qsTr("Sesli mesaj") + " " + sure(m.sure);
    if (t === "video") return qsTr("Video") + (m.sure ? " " + sure(m.sure) : "");
    if (t === "yuvarlak") return qsTr("Görüntülü mesaj") + (m.sure ? " " + sure(m.sure) : "");
    if (t === "gif") return "GIF";
    if (t === "muzik") return qsTr("Müzik") + (m.dosyaAdi ? ": " + m.dosyaAdi : "");
    if (t === "konum") return qsTr("Konum") + (m.konumAd ? ": " + m.konumAd : "");
    if (t === "kisi") return qsTr("Kişi") + ": " + m.dosyaAdi;
    if (t === "anket") return qsTr("Anket") + ": " + m.dosyaAdi;
    if (t === "cikartma") return (m.dosyaAdi ? m.dosyaAdi + " " : "") + qsTr("Çıkartma");
    if (t === "zar") return m.dosyaAdi + " " + qsTr("Zar");
    if (t === "dosya") return (m.dosyaAdi ? m.dosyaAdi : qsTr("Dosya")) + (m.boyut ? " (" + boyut(m.boyut) + ")" : "");
    if (t === "diger") return qsTr("Desteklenmeyen mesaj");
    return "";
}

// ListModel'de her ogede ayni roller olmali: eksik alanlari doldur
function mesajNorm(h) {
    return {
        mid: "" + (h.id || ""),
        metin: h.metin || "",
        benden: !!h.benden,
        zaman: h.zaman || 0,
        tur: h.tur || "metin",
        gonderen: h.gonderen || "",
        gonderenId: h.gonderenId || "",
        bekliyor: !!h.bekliyor,
        hata: !!h.hata,
        lat: h.lat || 0,
        lng: h.lng || 0,
        konumAd: h.konumAd || "",
        adres: h.adres || "",
        dosyaAdi: h.dosyaAdi || "",
        sure: h.sure || 0,
        boyut: h.boyut || 0,
        iletildi: !!h.iletildi,
        iletenAd: h.iletenAd || "",
        duzenlendi: !!h.duzenlendi,
        yanitId: h.yanitId || "",
        yanitAd: h.yanitAd || "",
        yanitOzet: h.yanitOzet || "",
        okundu: !!h.okundu,
        medya: h.medya || "",
        buyukMedya: h.buyukMedya || "",
        onizleme: h.onizleme || "",
        en: h.en || 0,
        boy: h.boy || 0,
        yol: h.yerel || "",
        oYol: "",
        yuzde: -1,
        tepki: h.tepki || "",
        benimTepki: h.benimTepki || "",
        genis: false
    };
}

// Mesaj kimligi gecici mi ("g123")
function gecici(mid) { return ("" + mid).charAt(0) === "g"; }

function turEtiketiKisa(t) {
    if (t === "yuvarlak") return qsTr("Görüntülü mesaj");
    return "";
}
