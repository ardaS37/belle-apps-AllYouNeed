import QtQuick 1.1
import "Util.js" as Util
import "Api.js" as Api

Rectangle {
    id: app
    width: 640
    height: 480
    color: bg

    // ---- Tema (modern WhatsApp tarzi; karanlik varsayilan) ----
    property bool dark: true
    property color brand: dark ? "#21C063" : "#1DAA61"
    property color brandPressed: dark ? "#1A9E52" : "#148A4E"
    property color accentText: dark ? "#21C063" : "#008069"
    property color pill: dark ? "#103529" : "#D8FDD2"
    property color bg: dark ? "#111B21" : "#FFFFFF"
    property color surface: dark ? "#1F2C34" : "#FFFFFF"
    property color textPrimary: dark ? "#E9EDEF" : "#111B21"
    property color textSecondary: dark ? "#8696A0" : "#667781"
    property color divider: dark ? "#222D34" : "#E9EDEF"
    property color pressed: dark ? "#202C33" : "#F0F2F5"
    property color fieldBg: dark ? "#2A3942" : "#F0F2F5"
    property color chatBg: dark ? "#0B141A" : "#EFEAE2"
    property color bubbleOut: dark ? "#005C4B" : "#D9FDD3"
    property color bubbleIn: dark ? "#202C33" : "#FFFFFF"
    property color chip: dark ? "#182229" : "#FFFFFF"
    property color noteBg: dark ? "#182229" : "#FFF3C4"
    property color noteText: dark ? "#FFD279" : "#54656F"
    property color danger: dark ? "#F15C6D" : "#D93025"
    property color placeholder: dark ? "#8696A0" : "#8696A0"
    property string iconTone: dark ? "_light" : "_gray"

    // ---- Uygulama durumu ----
    property bool loggedIn: false
    property string me: ""
    property string myName: ""
    property string server: "https://e6.msahincelen.xyz"
    property string apiKey: ""
    property int refreshSec: 15
    property int tab: 0            // 0 sohbetler, 1 kisiler, 2 ayarlar
    property bool chatOpen: false
    property string peerId: ""
    property string peerName: ""
    property int notifyMin: 2          // arka plan bildirim araligi (dk), 0 = kapali
    property double notifySince: 0     // 1. hesabin bildirim sayaci
    property double notifySince2: 0    // 2. hesabin

    // ---- Hesaplar: en fazla 2 WhatsApp numarasi. "me" etkin hesabin numarasi ----
    property string hesap1: ""
    property string ad1: ""
    property string hesap2: ""
    property string ad2: ""
    property int aktif: 1
    property bool ikiHesap: hesap2 !== ""
    property bool ekle2: false         // giris ekrani "2. hesabi ekle" kipinde
    property bool mailOn: true         // Posta sekmesi acik mi

    // ---- Ayar deposu (LocalStorage) ----
    function db() { return openDatabaseSync("WhatsE6", "1.0", qsTr("WhatsBelle ayarlari"), 200000); }
    function initDb() {
        db().transaction(function (tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS kv(k TEXT UNIQUE, v TEXT)");
        });
    }
    // Bos ya da eski IP adresi (203.0.113.10) -> https://e6.msahincelen.xyz
    // Telefonun kendi uygulamalari (tarayici, oynatici) TLS 1.2 bilmez: bizim sunucuya duz HTTP
    function duzHttp(u) { u = "" + (u || ""); return u.indexOf("https://e6.msahincelen.xyz") === 0 ? "http://" + u.substring(8) : u; }
    function sunucuTasi(s) { s = ("" + (s || "")).replace(/^\s+|\s+$/g, "").replace(/\/+$/, ""); return (s === "" || s.indexOf("203.0.113.10") >= 0) ? "https://e6.msahincelen.xyz" : s; }
    function setting(k, def) {
        var v = def;
        db().readTransaction(function (tx) {
            var rs = tx.executeSql("SELECT v FROM kv WHERE k = ?", [k]);
            if (rs.rows.length > 0) v = rs.rows.item(0).v;
        });
        if (k === "server") v = sunucuTasi(v);   // eski IP -> yeni adres
        return v;
    }
    function setSetting(k, v) {
        db().transaction(function (tx) {
            tx.executeSql("INSERT OR REPLACE INTO kv(k, v) VALUES(?, ?)", [k, "" + v]);
        });
    }

    function seenTs(peer) { return setting("seen:" + peer, ""); }
    function markSeen(peer, ts) { if (ts) setSetting("seen:" + peer, ts); }

    function setDark(on) { dark = on; setSetting("dark", on ? "1" : "0"); }

    // ---- Ag (Api.js sarmalayicilari) ----
    function configureApi() { Api.server = server; Api.me = me; Api.key = apiKey; }
    // num: islem yapilacak numara (bos: etkin hesap)
    function apiLogin(ok, fail, num) { configureApi(); Api.login(ok, fail, num); }
    function apiPair(ok, fail, num) { configureApi(); Api.pair(ok, fail, num); }
    function apiLoginStatus(ok, fail, num) { configureApi(); Api.loginStatus(ok, fail, num); }
    function qrUrl(t, num) { return Api.qrUrl(t, num); }
    function apiChats(ok, fail) { Api.chats(ok, fail); }
    function moreChats() { Api.chatSize = Math.min(100, Api.chatSize + 20); }
    function resetChats() { Api.chatSize = 20; }
    function apiMessages(peer, limit, ok, fail) { Api.messages(peer, limit, ok, fail); }
    function apiSend(peer, text, ok, fail) { Api.send(peer, text, ok, fail); }
    function apiSendLocation(peer, lat, lng, name, address, ok, fail) { Api.sendLocation(peer, lat, lng, name, address, ok, fail); }
    function apiReact(waId, emoji, ok, fail) { Api.react(waId, emoji, ok, fail); }
    function apiContacts(search, page, ok, fail) { Api.contacts(search, page, ok, fail); }
    function mediaUrl(file) { return Api.mediaUrl(file); }
    function avatarUrl(id) { return loggedIn && id ? Api.avatarUrl(id) : ""; }
    function uploadUrl() { return server + "/api/upload"; }

    function showToast(msg) { toast.show(msg); }

    // ---- Sekmeler ve klavye: sol/sag sekme degistirir, yukari/asagi sayfa icinde gezer ----
    function apiMail(ok, fail) { Api.mail(ok, fail); }
    function apiDriveRecent(ok, fail) { Api.driveRecent(ok, fail); }
    function selectTab(i) {
        if (i === 2 && !mailOn) i = 3;
        tab = i;
        if (i === 0) chatList.refresh(true);
        if (i === 1) contactsPage.loadIfEmpty();
        if (i === 2) mailPage.refresh(true);
        focusTab();
    }
    function stepTab(d) {
        var t = (tab + d + 4) % 4;
        if (t === 2 && !mailOn) t = (t + d + 4) % 4;     // Posta kapaliysa atla
        selectTab(t);
    }
    function setMailOn(on) {
        mailOn = on;
        setSetting("mail", on ? "1" : "0");
        if (!on && tab === 2) selectTab(3);
    }

    // ---- Hesap islemleri ----
    function hesapNo(h) { return h === 2 ? hesap2 : hesap1; }
    function hesapAd(h) { var a = h === 2 ? ad2 : ad1; return a !== "" ? a : "+" + hesapNo(h); }
    function hesapSec(h) {
        if (h === aktif || hesapNo(h) === "") return;
        if (chatOpen) { chatPage.stopVoice(); chatOpen = false; }
        aktif = h;
        setSetting("aktif", h);
        me = hesapNo(h);
        myName = h === 2 ? ad2 : ad1;
        configureApi();
        resetChats();
        chatList.clear();
        contactsPage.clear();
        if (tab === 0) chatList.refresh(false);
        showToast(qsTr("Etkin hesap: ") + hesapAd(h));
    }
    function hesapDegistir() { hesapSec(aktif === 1 ? 2 : 1); }
    function ikinciEkleBasla() { loginPage.ekleBasla(); ekle2 = true; }
    function ikinciVazgec() { loginPage.qrKapat(); ekle2 = false; focusTab(); }
    function ikinciEklendi(no, ad) {
        ekle2 = false;
        hesap2 = no; ad2 = ad;
        setSetting("me2", no); setSetting("name2", ad);
        notifySince2 = 0; setSetting("notifySince2", 0);
        hesapSec(2);
        showToast(qsTr("2. hesap eklendi (W²): ") + hesapAd(2));
        if (notifyMin > 0) checkNotify();
    }
    function ikinciKaldir() {
        if (aktif === 2) hesapSec(1);
        hesap2 = ""; ad2 = "";
        setSetting("me2", ""); setSetting("name2", "");
        showToast(qsTr("2. hesap kaldırıldı"));
    }
    function focusTab() {
        if (!loggedIn || chatOpen) return;
        if (tab === 0) chatList.takeFocus();
        else if (tab === 1) contactsPage.takeFocus();
        else if (tab === 2) mailPage.takeFocus();
        else settingsPage.takeFocus();
    }

    // ---- Arka plan bildirimleri ----
    // Uygulama acikken (arka planda da) belli araliklarla sunucuya yeni mesaj var mi diye sorar.
    // Uygulama ondeyse liste yenilenir; arka plandaysa ekranin kosesinde bildirim cikar.
    // Zamanlayici C++ tarafinda (notify.tick): QML Timer'i arka planda durabiliyor.
    property string lastNotifyInfo: ""
    property string lastNotifyInfo2: ""
    function checkNotify() {
        if (!loggedIn) return;
        notifyFor(1);
        if (ikiHesap) notifyFor(2);
    }
    function notifyFor(h) {
        var no = hesapNo(h);
        if (no === "") return;
        var bg = !Qt.application.active;
        var since = h === 2 ? notifySince2 : notifySince;
        var etiket = ikiHesap ? (h === 2 ? qsTr("2. hesap ") : qsTr("1. hesap ")) : "";
        Api.notifications(since, bg, function (d) {
            if (hesapNo(h) !== no) return;          // bu arada hesap degisti
            var first = since === 0;
            if (h === 2) { notifySince2 = d.now; setSetting("notifySince2", d.now); }
            else { notifySince = d.now; setSetting("notifySince", d.now); }
            var raw = d.items ? d.items : [];
            var items = [];
            for (var r = 0; r < raw.length; r++) {
                var it = raw[r];
                // posta bildirimi her hesabin kuyruguna eklenir: yalnizca 1. hesaptan al; Posta kapaliysa hic alma
                if (it.chat === "mail" && (h === 2 || !mailOn)) continue;
                items.push({ chat: it.chat, ad: it.title, text: it.text,
                             title: (ikiHesap && it.chat !== "mail" ? "[" + hesapAd(h) + "] " : "") + it.title });
            }
            var info = Qt.formatTime(new Date(), "hh:mm:ss") + (bg ? qsTr(" (arka plan)") : "") + ": " + etiket + items.length + qsTr(" yeni")
                       + (d.session === false ? qsTr(", WhatsApp oturumu yok") : "");
            if (h === 1) lastNotifyInfo = info; else lastNotifyInfo2 = info;
            if (items.length > 0 || bg) notify.log("bildirim kontrolu " + etiket + (bg ? "arka" : "on") + ": " + items.length + " yeni" + (first ? " (ilk)" : ""));
            if (first || items.length === 0) return;
            var shown = [];
            for (var i = 0; i < items.length; i++)
                if (!(Qt.application.active && chatOpen && h === aktif && items[i].chat === peerId)) shown.push(items[i]);
            var hasMail = false;
            for (var k = 0; k < items.length; k++) if (items[k].chat === "mail") hasMail = true;
            if (hasMail && mailPage.loadedOnce) mailPage.refresh(true);
            if (Qt.application.active) {
                if (h === aktif) { if (chatOpen) chatPage.refresh(true); else if (tab === 0) chatList.refresh(true); }
                if (shown.length > 0) { showToast(shown[shown.length - 1].title + ": " + shown[shown.length - 1].text); notify.vibrate(150); }
                return;
            }
            if (shown.length === 0) return;
            var last = shown[shown.length - 1];
            var title = shown.length > 1 ? last.title + "  (+" + (shown.length - 1) + qsTr(" mesaj)") : last.title;
            notify.show(title, last.text);
            if (drawerNotify) {
                var chats = [], mails = [];
                for (var s = 0; s < shown.length; s++) (shown[s].chat === "mail" ? mails : chats).push(shown[s]);
                if (chats.length > 0) {
                    var lc = chats[chats.length - 1];
                    lastTapChat = lc.chat; lastTapName = lc.ad; lastTapHesap = h;
                    notify.postKind("chat", lc.title, lc.text, chats.length);
                }
                if (mails.length > 0) {
                    var lm = mails[mails.length - 1];
                    notify.postKind("mail", lm.title, lm.text, mails.length);
                }
            }
            // Nokia "yeni sohbet mesaji" notu: sadece ekran kapaliyken (kontrol C++ tarafinda).
            // Pigler yoksa postKind zaten bu notu kullanir; iki kez eklenmesin.
            if (nokiaNote && notify.piglerReady()) notify.post(last.title, last.text, shown.length);
            notify.vibrate(350);
        }, function (msg, status) {
            var info = Qt.formatTime(new Date(), "hh:mm:ss") + (bg ? qsTr(" (arka plan)") : "") + ": " + etiket + qsTr("HATA ") + msg;
            if (h === 1) lastNotifyInfo = info; else lastNotifyInfo2 = info;
            notify.log("bildirim kontrolu hatasi " + etiket + "(" + status + "): " + msg);
        }, no);
    }    function setNotifyMin(m) { notifyMin = m; setSetting("notifyMin", m); }
    function applyTicker() {
        if (loggedIn && notifyMin > 0) notify.startTicker(Math.max(1, notifyMin) * 60000);
        else notify.stopTicker();
    }
    onNotifyMinChanged: applyTicker()
    onLoggedInChanged: { applyTicker(); if (loggedIn) focusTab(); }
    property bool drawerNotify: true
    function setDrawerNotify(on) { drawerNotify = on; setSetting("drawer", on ? "1" : "0"); if (!on) notify.clearPosted(); }
    property bool nokiaNote: true
    function setNokiaNote(on) { nokiaNote = on; setSetting("nokianote", on ? "1" : "0"); }

    // ---- Ses duzeyi (sesli mesajlar): ses tuslari ----
    property int volume: 80
    function stepVolume(d) {
        volume = Math.max(0, Math.min(100, volume + d));
        setSetting("volume", volume);
        volOverlay.show();
    }
    Connections {
        target: keys
        onUp: if (Qt.application.active) app.stepVolume(10)
        onDown: if (Qt.application.active) app.stepVolume(-10)
        onPlayPause: if (app.chatOpen) chatPage.togglePlaying()
    }

    // ---- Hata raporu: Ayarlar > "Rapor gönder" ----
    property string version: "1.12"
    function sendReport(note, onDone) {
        var t = qsTr("Surum: WhatsBelle ") + version + qsTr("\nNumara: ") + me + (ikiHesap ? qsTr(" (etkin ") + aktif + qsTr(". hesap; 1: ") + hesap1 + ", 2: " + hesap2 + ")" : "")
                + qsTr("\nSunucu: ") + server + qsTr("\nPosta sekmesi: ") + (mailOn ? "acik" : "kapali")
                + qsTr("\nBildirim araligi: ") + notifyMin + qsTr(" dk, cekmece: ") + (drawerNotify ? "acik" : "kapali")
                + qsTr(", acilista baslat: ") + (notify.autostart ? "acik" : "kapali")
                + qsTr("\nSon bildirim kontrolu: ") + lastNotifyInfo + (ikiHesap ? " | " + lastNotifyInfo2 : "")
                + "\n" + notify.postInfo() + qsTr("\nPigler: ") + notify.piglerInfo()
                + qsTr("\nSes kaydi: ") + device.recordInfo()
                + qsTr("\nGaleri: ") + device.scanInfo()
                + qsTr("\n\n--- Gunluk ---\n") + notify.logText();
        Api.report(qsTr("WhatsBelle"), version, note, t, function () { notify.log("rapor gonderildi"); onDone(true, "Rapor gönderildi"); },
                   function (msg) { onDone(false, msg); });
    }

    function openChat(id, name) {
        peerId = id;
        peerName = name;
        chatPage.reset();
        chatOpen = true;
        chatPage.refresh(false);
    }
    function closeChat() {
        chatPage.stopVoice();
        chatOpen = false;
        chatList.refresh(true);
        focusTab();
    }

    function onLoggedIn(number, srv, name) {
        me = number;
        server = srv;
        myName = name;
        hesap1 = number; ad1 = name; aktif = 1;
        setSetting("aktif", 1);
        setSetting("me", number);
        setSetting("server", srv);
        setSetting("key", apiKey);
        setSetting("name", name);
        configureApi();
        loggedIn = true;
        tab = 0;
        chatList.refresh(false);
    }
    function logout() {
        if (ikiHesap) {
            // Etkin hesaptan cik, oteki hesap 1. hesap olarak kalir
            if (aktif === 1) {
                hesap1 = hesap2; ad1 = ad2; notifySince = notifySince2;
                setSetting("me", hesap1); setSetting("name", ad1); setSetting("notifySince", notifySince);
            }
            hesap2 = ""; ad2 = "";
            setSetting("me2", ""); setSetting("name2", "");
            aktif = 1; setSetting("aktif", 1);
            me = hesap1; myName = ad1;
            configureApi(); resetChats();
            if (chatOpen) { chatPage.stopVoice(); chatOpen = false; }
            chatList.clear(); contactsPage.clear();
            chatList.refresh(false);
            showToast(qsTr("Çıkış yapıldı, etkin hesap: ") + hesapAd(1));
            return;
        }
        hesap1 = ""; ad1 = "";
        setSetting("me", "");
        loggedIn = false;
        chatOpen = false;
        chatList.clear();
    }

    Component.onCompleted: {
        initDb();
        dark = setting("dark", "1") === "1";
        server = setting("server", "https://e6.msahincelen.xyz");

        apiKey = setting("key", "");
        refreshSec = parseInt(setting("refresh", "15"), 10);
        notifyMin = parseInt(setting("notifyMin", "2"), 10);
        notifySince = parseFloat(setting("notifySince", "0"));
        drawerNotify = setting("drawer", "1") === "1";
        nokiaNote = setting("nokianote", "1") === "1";
        volume = parseInt(setting("volume", "80"), 10);
        mailOn = setting("mail", "1") === "1";
        notifySince2 = parseFloat(setting("notifySince2", "0"));
        notify.log("WhatsBelle " + version + " basladi" + (startedAtBoot ? " (telefon acilisi)" : "") + "; " + notify.piglerInfo());
        var bootTap = notify.takeBootTap();
        var savedMe = setting("me", "");
        hesap1 = savedMe;
        ad1 = setting("name", "");
        hesap2 = savedMe !== "" ? setting("me2", "") : "";
        ad2 = setting("name2", "");
        aktif = parseInt(setting("aktif", "1"), 10) === 2 && hesap2 !== "" ? 2 : 1;
        myName = aktif === 2 ? ad2 : ad1;
        if (aktif === 2) savedMe = hesap2;
        loginPage.mobile = hesap1;
        loginPage.serverUrl = server;
        loginPage.serverKey = apiKey;
        if (savedMe !== "") {
            me = savedMe;
            configureApi();
            loggedIn = true;
            chatList.refresh(false);
        }
        applyTicker();
        if (loggedIn && notifyMin > 0) checkNotify();
        if (bootTap !== "") openFromNotification(bootTap);
    }
    Timer { interval: 400; running: true; onTriggered: app.focusTab() }

    Timer {
        interval: app.refreshSec * 1000
        repeat: true
        running: app.loggedIn && Qt.application.active && !device.recording
        onTriggered: {
            if (app.chatOpen) chatPage.refresh(true);
            else if (app.tab === 0) chatList.refresh(true);
        }
    }

    Connections { target: notify; onTick: app.checkNotify(); onTapped: app.openFromNotification(kind) }
    // Cekmecedeki bildirime dokununca: posta -> Posta sekmesi; mesaj -> son mesajin sohbeti
    property string lastTapChat: ""
    property string lastTapName: ""
    property int lastTapHesap: 1
    function openFromNotification(kind) {
        if (!loggedIn) return;
        if (ekle2) ikinciVazgec();
        if (kind !== "mail" && lastTapChat !== "" && lastTapChat !== "mail" && lastTapHesap !== aktif) hesapSec(lastTapHesap);
        if (kind === "mail") {
            if (chatOpen) closeChat();
            selectTab(mailOn ? 2 : 0);
        } else if (lastTapChat !== "" && lastTapChat !== "mail") {
            openChat(lastTapChat, lastTapName);
        } else {
            if (chatOpen) closeChat();
            selectTab(0);
        }
    }
    // One donunce hemen bir kez bak, cekmecedeki bildirimi kaldir
    Connections {
        target: Qt.application
        onActiveChanged: {
            notify.log(Qt.application.active ? "uygulama one geldi" : "uygulama arka plana gecti");
            if (Qt.application.active) {
                notify.clearPosted();
                if (app.loggedIn && app.notifyMin > 0) app.checkNotify();
            }
        }
    }

    LoginPage {
        id: loginPage
        anchors.fill: parent
        visible: !app.loggedIn || app.ekle2
        ekleMod: app.ekle2
    }

    Item {
        id: home
        anchors.fill: parent
        visible: app.loggedIn && !app.ekle2

        ChatListPage {
            id: chatList
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: nav.top }
            visible: app.tab === 0
        }
        ContactsPage {
            id: contactsPage
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: nav.top }
            visible: app.tab === 1
        }
        MailPage {
            id: mailPage
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: nav.top }
            visible: app.tab === 2
        }
        SettingsPage {
            id: settingsPage
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: nav.top }
            visible: app.tab === 3
        }
        BottomNav {
            id: nav
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            current: app.tab
            onSelected: app.selectTab(index)
        }
    }

    ChatPage {
        id: chatPage
        width: parent.width
        height: parent.height
        y: 0
        x: app.chatOpen ? 0 : app.width
        visible: x < app.width
        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }

    // Ses duzeyi gostergesi
    Rectangle {
        id: volOverlay
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 70 }
        width: 300; height: 64; radius: 14
        color: app.surface
        border.width: app.dark ? 0 : 1
        border.color: app.divider
        opacity: 0
        visible: opacity > 0
        z: 20
        function show() { opacity = 1; volHide.restart(); }
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Timer { id: volHide; interval: 1400; onTriggered: volOverlay.opacity = 0 }
        Text { id: volLabel; anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter } text: qsTr("Ses"); color: app.textPrimary; font.pixelSize: 18; font.bold: true }
        Rectangle {
            id: volTrack
            anchors { left: volLabel.right; leftMargin: 14; right: volNum.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
            height: 8; radius: 4
            color: app.dark ? "#55FFFFFF" : "#22000000"
            Rectangle { width: parent.width * app.volume / 100; height: parent.height; radius: 4; color: app.brand }
        }
        Text { id: volNum; anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter } text: "%" + app.volume; color: app.textSecondary; font.pixelSize: 17; width: 46; horizontalAlignment: Text.AlignRight }
    }

    Toast { id: toast }
}
