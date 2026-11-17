// BelleMusic muzik servisleri. Tum yanitlar {Items:[...]} bicimindedir.
//   Liste:  {ListKey, Name, Singer, Image}
//   Sarki:  {Name, Url, Singer, Duration, Image}
// Iki derleme (main.qml her erisimde "kisisel"i buraya yazar; C++: BM_KISISEL):
//  - Yayin (kisisel = false): s60tube muzik servisi (MIDPlay'in kullandigi sunucu), E6Muzik ile ayni.
//  - Kisisel (kisisel = true): yalnizca kendi Belle sunucumuz (/muzik/..., ses /yt/audio/<id>.mp3).
.pragma library

var kisisel = false;
var BASE = "http://music.s60tube.io.vn";
var server = "https://e6.msahincelen.xyz";   // kisisel: Belle sunucusu (main.qml ayarlardan doldurur)
var key = "";
var SERVICES = [
    { id: "ytmusic", name: "YouTube Music" },
    { id: "nct", name: "NhacCuaTui" },
    { id: "spotify", name: "Spotify" },
    { id: "soundcloud", name: "SoundCloud" }
];

function serviceName(id) {
    if (kisisel) return "Belle";
    for (var i = 0; i < SERVICES.length; i++) if (SERVICES[i].id === id) return SERVICES[i].name;
    return id;
}

function svc(service) { return (!kisisel && service && service !== "nct") ? "&service=" + service : ""; }

// ---- kisisel: Belle sunucusu ----
function sunucu() { return ("" + server).replace(/\/+$/, ""); }
// Yerlesik oynatici TLS 1.2 bilmez: ses adresleri duz HTTP (sunucuda http://e6 yonlendirmesiz)
function duzHttp(u) { return u.indexOf("https://e6.msahincelen.xyz") === 0 ? "http://" + u.substring(8) : u; }
// Eski kayitli adresler (s60tube YouTube) -> sunucumuzdaki ses adresi; YouTube disi olanlar ""
function normalize(u) {
    u = "" + (u || "");
    if (/^\/yt\/audio\/[A-Za-z0-9_\-]{11}\.mp3$/.test(u)) return u;
    var m = /[?&]v=([A-Za-z0-9_\-]{11})/.exec(u);
    if (m && /s60tube|youtube/.test(u)) return "/yt/audio/" + m[1] + ".mp3";
    return "";
}
function isBelle(u) { return kisisel && normalize(u) !== ""; }
function mediaUrl(u) { var n = kisisel ? normalize(u) : ""; return n !== "" ? duzHttp(sunucu()) + n + "?key=" + encodeURIComponent(key) : u; }
// Sunucu sesi ilk kez hazirlarken (yt-dlp) 30-60 sn surebilir: oynaticidan once beklenir
function prepare(u, onOk, onFail) {
    var m = /\/yt\/audio\/([A-Za-z0-9_\-]{11})\.mp3/.exec(normalize(u));
    if (!m) { onFail(qsTr("Şarkı adresi geçersiz")); return; }
    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        if (xhr.status === 200) onOk();
        else if (xhr.status === 401 || xhr.status === 403) onFail(qsTr("Sunucu parolası hatalı (Ayarlar)."));
        else onFail(xhr.status === 0 ? qsTr("Sunucuya ulaşılamadı.") : qsTr("Şarkı sunucuda hazırlanamadı (") + xhr.status + ")");
    };
    xhr.open("GET", sunucu() + "/yt/prepare/" + m[1] + "?k=audio");
    xhr.setRequestHeader("X-Api-Key", key);
    xhr.send();
}

// Bekleyen istekler: ayni ekrandan yeni istek gelince eskisinin sonucu yok sayilir
var seq = 0;

function get(path, onOk, onFail) {
    if (kisisel && key === "") { onFail(qsTr("Ayarlar'dan sunucu parolasını girin.")); return; }
    var xhr = new XMLHttpRequest();
    var started = new Date().getTime();
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        var ms = new Date().getTime() - started;
        if (xhr.status === 200) {
            var j = null;
            try { j = JSON.parse(xhr.responseText); } catch (e) { onFail(qsTr("Sunucu yanıtı okunamadı")); return; }
            onOk(j && j.Items ? j.Items : [], ms);
        } else if (xhr.status === 0) {
            onFail(qsTr("Bağlantı kurulamadı. İnternet bağlantısını kontrol edin."));
        } else if (kisisel && (xhr.status === 401 || xhr.status === 403)) {
            onFail(qsTr("Sunucu parolası hatalı (Ayarlar)."));
        } else {
            onFail(qsTr("Sunucu hatası (") + xhr.status + ")");
        }
    };
    xhr.open("GET", (kisisel ? sunucu() + "/muzik" : BASE) + path);
    if (kisisel) xhr.setRequestHeader("X-Api-Key", key);
    xhr.send();
}

function enc(s) { return encodeURIComponent(s); }

// Kesfet: type "new" | "hot"
function discover(service, type, page, onOk, onFail) {
    get("/playlist?type=" + type + "&page=" + page + svc(service), onOk, onFail);
}
// Liste/albüm aramasi: type "playlist" | "album"
function searchLists(q, type, service, onOk, onFail) {
    get("/search?q=" + enc(q) + "&type=" + type + svc(service), onOk, onFail);
}
function searchTracks(q, service, onOk, onFail) {
    get("/tracks/search?q=" + enc(q) + svc(service), onOk, onFail);
}
function tracks(listKey, service, onOk, onFail) {
    var k = "" + listKey;
    if (kisisel) { var m = /^ytmusic:playlist:(.+)$/.exec(k); if (m) k = "yt:" + m[1]; }   // eski kayitli listeler
    get("/tracks?listkey=" + enc(k) + svc(service), onOk, onFail);
}

// ---- Sarki nesnesi ----
function norm(s) { return ("" + (s || "")).toLowerCase().replace(/^\s+|\s+$/g, ""); }

function makeKey(service, name, singer, duration) {
    return service + "|" + norm(name) + "|" + norm(singer) + "|" + (duration || 0);
}

function varsayilanServis(service) { return kisisel ? "belle" : (service || "nct"); }

function toTrack(item, service) {
    var t = {
        name: item.Name || "",
        singer: item.Singer || "",
        url: item.Url || "",
        image: item.Image || "",
        duration: item.Duration || 0,
        service: varsayilanServis(service)
    };
    t.key = makeKey(t.service, t.name, t.singer, t.duration);
    return t;
}

function toList(item, service) {
    return { listKey: item.ListKey || "", name: item.Name || "", singer: item.Singer || "", image: item.Image || "", service: varsayilanServis(service) };
}

// YouTube Music liste baglantisi ya da kimligi -> liste bilgisi (yoksa null)
//   https://music.youtube.com/playlist?list=PL...   /  youtube.com/watch?v=..&list=OLAK5uy_...  /  PL...  /  VLPL...
function ytListFromText(text) {
    var s = ("" + (text || "")).replace(/^\s+|\s+$/g, "");
    var m = /[?&]list=([A-Za-z0-9_\-]+)/.exec(s);
    var id = m ? m[1] : "";
    if (!id && /^(VL)?(PL|OLAK5uy_|RD|LM|FL|UU)[A-Za-z0-9_\-]{8,}$/.test(s)) id = s;
    if (!id) return null;
    if (id.indexOf("VL") === 0) id = id.substring(2);
    if (kisisel) return { listKey: "yt:" + id, name: "YouTube listesi", singer: "", image: "", service: "belle", askName: true };
    return { listKey: "ytmusic:playlist:" + id, name: "YouTube Music listesi", singer: "", image: "", service: "ytmusic", askName: true };
}

// NhacCuaTui adresleri imzali ve ~7 gun gecerli (&e=<unix saniye>). Suresi dolmussa yenilenmeli.
// Kisisel: sunucumuzda olmayan (eski s60tube NhacCuaTui/Spotify/SoundCloud) adresler sunucuda adla yeniden aranir
function isExpired(url) {
    if (kisisel) return !isBelle(url);
    var m = /[?&]e=(\d+)/.exec(url || "");
    if (!m) return false;
    return parseInt(m[1], 10) < new Date().getTime() / 1000 + 120;
}

// Kayitli bir sarkinin guncel adresini bulur: ayni servis icinde ad+sanatci ile arar
function refresh(t, onOk, onFail) {
    searchTracks(t.name + " " + t.singer, t.service, function (items) {
        var best = null, bestScore = -1;
        for (var i = 0; i < items.length; i++) {
            var c = toTrack(items[i], t.service);
            var score = 0;
            if (norm(c.name) === norm(t.name)) score += 4;
            else if (norm(c.name).indexOf(norm(t.name)) >= 0 || norm(t.name).indexOf(norm(c.name)) >= 0) score += 2;
            if (norm(c.singer) === norm(t.singer)) score += 3;
            if (Math.abs((c.duration || 0) - (t.duration || 0)) <= 3) score += 2;
            if (score > bestScore) { bestScore = score; best = c; }
        }
        if (best && bestScore >= 5) onOk(best.url);
        else onFail(qsTr("Şarkının güncel adresi bulunamadı"));
    }, onFail);
}
