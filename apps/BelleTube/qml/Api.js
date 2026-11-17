// BelleTube ag katmani (kendi sunucumuzdaki /yt/... uc noktalari)
var server = "https://e6.msahincelen.xyz";
var key = "";

function errorText(xhr) {
    if (xhr.status === 0) return qsTr("Sunucuya bağlanılamadı. İnternet bağlantısını kontrol edin.");
    if (xhr.status === 401 || xhr.status === 403) return qsTr("Sunucu parolası hatalı. Ayarlardan kontrol edin.");
    try {
        var j = JSON.parse(xhr.responseText);
        if (j.error) return j.error;
    } catch (e) { }
    return qsTr("Sunucu hatası (") + xhr.status + ")";
}

// onFail(mesaj, durumKodu, hesapGerekli)
function request(method, path, body, onOk, onFail) {
    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        if (xhr.status >= 200 && xhr.status < 300) {
            var d = null;
            try { d = JSON.parse(xhr.responseText); } catch (e) { if (onFail) onFail(qsTr("Geçersiz yanıt"), xhr.status, false); return; }
            if (onOk) onOk(d);
        } else if (onFail) {
            var needLogin = false;
            try { needLogin = !!JSON.parse(xhr.responseText).needLogin; } catch (e2) { }
            onFail(errorText(xhr), xhr.status, needLogin);
        }
    };
    xhr.open(method, server + path);
    if (key !== "") xhr.setRequestHeader("X-Api-Key", key);
    if (typeof dil !== "undefined") xhr.setRequestHeader("X-Lang", dil.kod);
    if (body !== null && body !== undefined) {
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.send(JSON.stringify(body));
    } else {
        xhr.send();
    }
}

function get(path, onOk, onFail) { request("GET", path, null, onOk, onFail); }
function post(path, body, onOk, onFail) { request("POST", path, body || {}, onOk, onFail); }

function search(q, cont, onOk, onFail) {
    var p = cont ? "cont=" + encodeURIComponent(cont) : "q=" + encodeURIComponent(q);
    get("/yt/search?" + p, onOk, onFail);
}

function video(id, onOk, onFail) { get("/yt/video/" + id, onOk, onFail); }

// Parola kontrolu icin hafif istek
function authStatus(onOk, onFail) { get("/yt/auth/status", onOk, onFail); }

// ---- Abonelikler (sunucudaki yerel liste) ----
function feed(page, refresh, onOk, onFail) { get("/yt/feed?page=" + page + (refresh ? "&refresh=1" : ""), onOk, onFail); }
function subs(refresh, onOk, onFail) { get("/yt/subs" + (refresh ? "?refresh=1" : ""), onOk, onFail); }
// Uygulama icinden abone ol / cik (sunucudaki yerel liste; Google hesabi gerekmez)
function subAdd(id, title, thumb, onOk, onFail) { post("/yt/subs/add", { id: id, title: title, thumb: thumb || "" }, onOk, onFail); }
function subRemove(id, onOk, onFail) { post("/yt/subs/remove", { id: id }, onOk, onFail); }
function channel(cid, pageToken, onOk, onFail) { get("/yt/channel/" + cid + (pageToken ? "?pageToken=" + encodeURIComponent(pageToken) : ""), onOk, onFail); }

function keyParam(first) { return key !== "" ? (first ? "?" : "&") + "key=" + encodeURIComponent(key) : ""; }

function thumbUrl(id) { return server + "/yt/thumb/" + id + ".jpg" + keyParam(true); }

// Sunucunun verdigi "/yt/img?..." yolunu tam adrese cevirir
function imgUrl(p) { return p ? server + p + keyParam(p.indexOf("?") < 0) : ""; }

// Izleme (akis): oynatici dogrudan sunucudan okur; parola adreste (oynatici baslik gonderemez)
// Telefonun yerlesik oynaticisi TLS 1.2 bilmez: bizim sunucuya duz HTTP ile gider
function duzHttp(u) { return u.indexOf("https://e6.msahincelen.xyz") === 0 ? "http://" + u.substring(8) : u; }
function playUrl(id, kind) {
    if (kind === "audio") return duzHttp(server + "/yt/audio/" + id + ".mp3" + keyParam(true));
    return duzHttp(server + "/yt/stream/" + id + ".mp4?q=" + kind + keyParam(false));
}
// Sunucu dosyayi hazirlayinca doner (oynatici zaman asimina dusmesin)
function prepare(id, kind, onOk, onFail) { get("/yt/prepare/" + id + "?k=" + kind, onOk, onFail); }
function comments(id, cont, onOk, onFail) { get("/yt/comments/" + id + (cont ? "?cont=" + encodeURIComponent(cont) : ""), onOk, onFail); }

// Indirme (ayri, normal indirme): Tube parolayi baslikta gonderir
function mediaUrl(id, kind) {
    if (kind === "audio") return server + "/yt/audio/" + id + ".mp3";
    return server + "/yt/stream/" + id + ".mp4?q=" + kind;
}
