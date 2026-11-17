// Ag katmani: WhatsBelle sunucusunun REST API'si
// Bu dosya .pragma library DEGIL; XMLHttpRequest'e erisebilmesi icin main.qml'e import ediliyor.
//
// Uc noktalar (messageRouter.js):
//   GET  /api/login/:user                      -> {pushname, user, platform} | 401
//   GET  /api/chats/:receiver?page_size&page   -> {chats:[{_id,sender,senderName,message,status,createdAt}]}
//   GET  /api/messages/:receiver/:sender       -> {messages:[{_id,sender,receiver,message,senderName,chatType,createdAt}]} (yeniden eskiye, 20 adet)
//   POST /api/messages  {sender, receiver, message}
//   GET  /api/contacts/:user?search_term&page_size&page -> {contacts:[{id,name}], count}
//   GET  /api/mediafile/:filename

var server = "https://e6.msahincelen.xyz";
var me = "";            // ornek: 905321234567
var key = "";           // sunucu parolasi (X-Api-Key)
var pending = 0;
var chatSize = 20;      // sohbet listesinde istenen sayi; "Daha eski sohbetler" ile 20 artar

function errorText(xhr) {
    if (xhr.status === 0) return qsTr("Sunucuya bağlanılamadı. İnternet bağlantısını kontrol edin.");
    if (xhr.status === 401) return qsTr("Oturum bulunamadı. ") + server + qsTr("/login adresinden QR kodu okutun.");
    if (xhr.status === 403) return qsTr("Sunucu parolası hatalı. Ayarlardan parolayı kontrol edin.");
    try {
        var j = JSON.parse(xhr.responseText);
        if (j.error) return j.error;
        if (j.statusDesc) return j.statusDesc;
    } catch (e) { }
    return qsTr("Sunucu hatası (") + xhr.status + ")";
}

function request(method, path, body, onOk, onFail) {
    var xhr = new XMLHttpRequest();
    pending++;
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        pending--;
        if (xhr.status >= 200 && xhr.status < 300) {
            var data = null;
            try {
                data = JSON.parse(xhr.responseText);
            } catch (e) {
                if (onFail) onFail(qsTr("Sunucudan geçersiz yanıt geldi."), xhr.status);
                return;
            }
            if (onOk) onOk(data);
        } else {
            if (onFail) onFail(errorText(xhr), xhr.status);
        }
    };
    xhr.open(method, server + path);
    if (key !== "") xhr.setRequestHeader("X-Api-Key", key);
    if (typeof dil !== "undefined") xhr.setRequestHeader("X-Lang", dil.kod);   // sunucu hata mesajlari uygulamanin dilinde
    if (body !== null) {
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.send(JSON.stringify(body));
    } else {
        xhr.send();
    }
}

// num: islem yapilacak hesap (bos: etkin hesap). Ikinci hesap eklenirken etkin hesap degismeden denenir.
function login(onOk, onFail, num) {
    request("GET", "/api/login/" + (num || me), null, onOk, onFail);
}

function chats(onOk, onFail) {
    request("GET", "/api/chats/" + me + "@c.us?page_size=" + chatSize + "&page=0", null, function (d) {
        onOk(d.chats ? d.chats : [], !!d.more);
    }, onFail);
}

function messages(peer, limit, onOk, onFail) {
    request("GET", "/api/messages/" + me + "@c.us/" + peer + "?limit=" + limit, null, function (d) {
        onOk(d.messages ? d.messages : []);
    }, onFail);
}

function send(peer, text, onOk, onFail) {
    request("POST", "/api/messages", { sender: me, receiver: peer, message: text }, onOk, onFail);
}

// Konum: sunucu WhatsApp konum mesaji + Google Maps baglantisi olarak iletir
function sendLocation(peer, lat, lng, name, address, onOk, onFail) {
    request("POST", "/api/location", { sender: me, receiver: peer, lat: lat, lng: lng, name: name || "", address: address || "" }, onOk, onFail);
}

// Mesaja ifade (tepki); emoji "" ise kaldirir
function react(waId, emoji, onOk, onFail) {
    request("POST", "/api/react", { sender: me, waId: waId, emoji: emoji }, onOk, onFail);
}

function contacts(search, page, onOk, onFail) {
    var q = "?search_term=" + encodeURIComponent(search) + "&page_size=30&page=" + page;
    request("GET", "/api/contacts/" + me + q, null, function (d) {
        onOk(d.contacts ? d.contacts : [], d.count ? d.count : 0);
    }, onFail);
}

// QR ile eslestirme: sunucuda bu numara icin oturum baslat (yoksa) ve QR'i goster
//   GET /TR/:numara/start  -> {valid, formatted, durum: hazir|qr|yeni}
//   GET /login-status/:numara -> {isAuthenticated, hasQr}
//   GET /qr/:numara.png
function pair(onOk, onFail, num) {
    // numara ulke koduyla yazildigi icin basina + konur: her ulke icin gecerli (TR yalnizca varsayilan bolge)
    request("GET", "/TR/" + encodeURIComponent("+" + (num || me)) + "/start", null, onOk, onFail);
}
function loginStatus(onOk, onFail, num) {
    request("GET", "/login-status/" + (num || me), null, onOk, onFail);
}
function qrUrl(t, num) {
    return server + "/qr/" + (num || me) + ".png?t=" + t + (key !== "" ? "&key=" + encodeURIComponent(key) : "");
}

function avatarUrl(id) {
    return server + "/api/avatar/" + me + "/" + id + ".png" + (key !== "" ? "?key=" + encodeURIComponent(key) : "");
}

function mediaUrl(file) {
    // Resim/medya istekleri baslik gonderemedigi icin parola adreste gider
    return server + "/api/mediafile/" + file + (key !== "" ? "?key=" + encodeURIComponent(key) : "");
}

// Arka plan bildirimleri: since (sunucu saati, ms) sonrasinda gelen mesajlar
function notifications(since, bg, onOk, onFail, num) {
    request("GET", "/api/notify/" + (num || me) + "?since=" + since + "&bg=" + (bg ? "1" : "0"), null, onOk, onFail);
}

// Posta: gelen kutusunun ilk sayfasi (sunucudaki mail.js)
function mail(onOk, onFail) {
    request("GET", "/mail/api/list?f=inbox&p=0", null, onOk, function (msg, status) {
        if (status === 502 || status === 400) msg = qsTr("Sunucuda posta hesabı ayarlı değil ya da bağlanılamadı.");
        onFail(msg, status);
    });
}

// Drive'a son yuklenen dosyalar (Posta sekmesinde e-posta gibi gosterilir)
function driveRecent(onOk, onFail) {
    request("GET", "/drive/api/recent", null, function (d) { onOk(d.items ? d.items : []); }, onFail);
}

// Hata raporu: sunucuda data/reports altina kaydedilir
function report(appName, version, note, text, onOk, onFail) {
    request("POST", "/api/report", { app: appName, version: version, note: note, text: text }, onOk, onFail);
}
