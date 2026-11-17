import QtQuick 1.1
import "Api.js" as Api

Rectangle {
    id: app
    width: 640
    height: 480
    color: bg

    // ---- Tema (karanlik varsayilan, kirmizi vurgu) ----
    property bool dark: true
    property color brand: dark ? "#FF3B4E" : "#E8132B"
    property color brandPressed: dark ? "#D92F40" : "#C10F23"
    property color accentText: brand
    property color pill: dark ? "#3A1B20" : "#FDE3E6"
    property color bg: dark ? "#111B21" : "#FFFFFF"
    property color surface: dark ? "#1F2C34" : "#FFFFFF"
    property color textPrimary: dark ? "#E9EDEF" : "#111B21"
    property color textSecondary: dark ? "#8696A0" : "#667781"
    property color divider: dark ? "#222D34" : "#E9EDEF"
    property color pressed: dark ? "#202C33" : "#F0F2F5"
    property color fieldBg: dark ? "#2A3942" : "#F0F2F5"
    property color danger: dark ? "#F15C6D" : "#D93025"
    property color placeholder: "#8696A0"
    property string iconTone: dark ? "_light" : "_gray"

    // ---- Ayarlar ----
    property string server: "https://e6.msahincelen.xyz"
    property string apiKey: ""
    property string quality: "360"
    property int limitGB: 2
    property int volume: 70             // 0-100, ses tuslariyla degisir

    // ---- Sekmeler: 0 Akis, 1 Kanallar, 2 Ara, 3 Kitaplik, 4 Ayarlar ----
    property int tab: 0
    property bool videoOpen: false
    property bool browseOpen: false

    // Abonelikler degisince artar (Akis ve Kanallar yeniden yuklenir)
    property int subsVersion: 0
    function setSubscribed(cid, title, thumb, on, cb) {
        var ok = function (d) { subsVersion++; showToast(on ? qsTr("Abone olundu: ") + title : qsTr("Abonelikten çıkıldı")); if (cb) cb(!!d.subscribed); };
        var fail = function (msg) { showToast(msg); if (cb) cb(!on); };
        if (on) Api.subAdd(cid, title, thumb, ok, fail);
        else Api.subRemove(cid, ok, fail);
    }

    function avatarUrl(id) { return ""; }   // Header bileseni icin
    function thumbUrl(id) { return Api.thumbUrl(id); }
    function imgUrl(p) { return Api.imgUrl(p); }
    function mediaUrl(id, kind) { return Api.mediaUrl(id, kind); }
    function apiSearch(q, cont, ok, fail) { Api.search(q, cont, ok, fail); }
    function apiVideo(id, ok, fail) { Api.video(id, ok, fail); }
    function api() { return Api; }
    function configureApi() { Api.server = server; Api.key = apiKey; tube.setRemote(server, apiKey); }
    function limitBytes() { return limitGB * 1024 * 1024 * 1024; }
    function showToast(msg) { toast.show(msg); }

    function db() { return openDatabaseSync("E6Tube", "1.0", qsTr("BelleTube ayarlari"), 100000); }
    // Bos ya da eski IP adresi (203.0.113.10) -> https://e6.msahincelen.xyz
    function sunucuTasi(s) { s = ("" + (s || "")).replace(/^\s+|\s+$/g, "").replace(/\/+$/, ""); return (s === "" || s.indexOf("203.0.113.10") >= 0) ? "https://e6.msahincelen.xyz" : s; }
    function setting(k, def) {
        var v = def;
        db().transaction(function (tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS kv(k TEXT UNIQUE, v TEXT)");
            var rs = tx.executeSql("SELECT v FROM kv WHERE k = ?", [k]);
            if (rs.rows.length > 0) v = rs.rows.item(0).v;
        });
        if (k === "server") v = sunucuTasi(v);   // eski IP -> yeni adres
        return v;
    }
    function setSetting(k, v) {
        db().transaction(function (tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS kv(k TEXT UNIQUE, v TEXT)");
            tx.executeSql("INSERT OR REPLACE INTO kv(k, v) VALUES(?, ?)", [k, "" + v]);
        });
    }

    // ---- Video secimi: once secenek sayfasi, sonra oynatici ya da indirme ----
    // item: { id, title, channel, channelId?, seconds?, length? }
    property bool sheetOpen: false
    function openVideo(item) { sheet.show(item); }

    // mode: "video" | "audio"  (izleme = akis; telefonda tam inmis dosya varsa ondan)
    function play(item, mode) {
        videoPage.open(item, mode);
        videoOpen = true;
    }
    function closeVideo() {
        videoOpen = false;
        videoPage.leave();
        if (tab === 3) library.reloadDownloads();
    }

    // ---- Indirme kuyrugu: izlemeden bagimsiz, ayri baglanti, ayri dosya ----
    property variant dlQueue: []         // [{ id, kind, title, channel, seconds }]
    property string dlTitle: ""          // inen videonun basligi
    property string dlKey: ""            // "id_tur"
    property int dlPercent: 0
    property int dlSpeed: 0
    property int dlVersion: 0            // indirme bitince/eklenince artar (ekranlar guncellensin)

    function secondsOf(item) {
        if (item.seconds) return item.seconds;
        if (!item.length) return 0;
        var p = ("" + item.length).split(":"), s = 0;
        for (var i = 0; i < p.length; i++) s = s * 60 + (parseInt(p[i], 10) || 0);
        return s;
    }
    function isQueued(id, kind) {
        if (dlKey === id + "_" + kind) return true;
        for (var i = 0; i < dlQueue.length; i++) if (dlQueue[i].id === id && dlQueue[i].kind === kind) return true;
        return false;
    }
    // Durum metni: "" (yok) | "İniyor %40" | "Sırada" | "Telefonda"
    function dlState(id, kind) {
        if (tube.isComplete(id, kind)) return qsTr("Telefonda");
        if (dlKey === id + "_" + kind) return qsTr("İniyor %") + dlPercent;
        if (isQueued(id, kind)) return qsTr("Sırada");
        return "";
    }
    function download(item, kind) {
        if (tube.isComplete(item.id, kind)) { showToast(qsTr("Zaten telefonda")); return; }
        if (isQueued(item.id, kind)) { showToast(qsTr("Zaten indiriliyor")); return; }
        var q = dlQueue;
        q.push({ id: item.id, kind: kind, title: item.title || "", channel: item.channel || "", seconds: secondsOf(item) });
        dlQueue = q;
        dlVersion++;
        showToast((kind === "audio" ? qsTr("Ses") : qsTr("Video")) + qsTr(" indirilecek") + (tube.downloading ? qsTr(" (sırada)") : ""));
        pumpDownloads();
    }
    function pumpDownloads() {
        if (tube.downloading || dlQueue.length === 0) return;
        var q = dlQueue;
        var it = q.shift();
        dlQueue = q;
        dlKey = it.id + "_" + it.kind;
        dlTitle = it.title;
        dlPercent = 0;
        dlSpeed = 0;
        tube.download(Api.mediaUrl(it.id, it.kind), apiKey, it.id, it.kind, it.title, it.channel, it.seconds);
    }
    function cancelDownload() { if (tube.downloading) tube.cancel(); }
    Connections {
        target: tube
        onProgress: {
            if (videoId + "_" + kind !== app.dlKey) return;
            app.dlPercent = total > 0 ? Math.floor(100 * received / total) : 0;
            app.dlSpeed = speedKBs;
        }
        onFinished: {
            app.showToast(ok ? qsTr("İndirildi: ") + app.dlTitle : app.dlTitle + ": " + message);
            app.dlKey = "";
            app.dlTitle = "";
            if (ok) tube.enforceLimit(app.limitBytes(), videoId);
            app.dlVersion++;
            if (app.tab === 3) library.reloadDownloads();
            pumpTimer.start();
        }
    }
    Timer { id: pumpTimer; interval: 300; onTriggered: app.pumpDownloads() }
    function openChannel(cid, title) {
        if (!cid) return;
        if (videoOpen) closeVideo();
        browse.openChannel(cid, title);
        browseOpen = true;
    }
    function closeBrowse() { browseOpen = false; }
    function selectTab(i) {
        tab = i;
        setSetting("tab", i);
        if (i === 3) library.activate();
        if (i === 0) feed.activate();
        if (i === 1) channels.activate();
    }

    Component.onCompleted: {
        dark = setting("dark", "1") === "1";
        server = setting("server", "https://e6.msahincelen.xyz");
        apiKey = setting("key", "");
        quality = setting("quality", "360");
        limitGB = parseInt(setting("limitGB", "2"), 10);
        volume = parseInt(setting("volume", "70"), 10);
        configureApi();
        if (apiKey === "") { tab = 4; return; }      // ilk acilista parola girilsin
        selectTab(parseInt(setting("tab", "0"), 10));
    }

    Item {
        anchors.fill: parent
        FeedPage {
            id: feed
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: nav.top }
            visible: app.tab === 0
        }
        ChannelsPage {
            id: channels
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: nav.top }
            visible: app.tab === 1
        }
        SearchPage {
            id: searchPage
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: nav.top }
            visible: app.tab === 2
        }
        LibraryPage {
            id: library
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: nav.top }
            visible: app.tab === 3
        }
        SettingsPage {
            id: settingsPage
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: nav.top }
            visible: app.tab === 4
        }
        BottomNav {
            id: nav
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            current: app.tab
            onSelected: app.selectTab(index)
        }
    }

    // Kanal / oynatma listesi sayfasi (sekmelerin ustunde)
    BrowsePage {
        id: browse
        anchors.fill: parent
        visible: app.browseOpen && !app.videoOpen
    }

    VideoPage {
        id: videoPage
        width: parent.width
        height: parent.height
        // Kayma animasyonu yok: Symbian'da video ayri bir donanim katmaninda cizilir ve
        // konumu oynatma basladiginda sabitlenir; sayfa hareket ederken baslarsa goruntu cikmaz.
        x: app.videoOpen ? 0 : app.width
        visible: app.videoOpen
    }

    // Secenek sayfasi (tum sayfalarin ustunde)
    ChoiceSheet {
        id: sheet
        anchors.fill: parent
        z: 50
    }

    // Ses tuslari (uygulama ondeyken)
    function changeVolume(d) {
        volume = Math.max(0, Math.min(100, volume + d));
        volSave.restart();
        if (videoOpen) videoPage.showVolume();
        else showToast(qsTr("Ses: %") + volume);
    }
    Timer { id: volSave; interval: 1500; onTriggered: app.setSetting("volume", app.volume) }
    Connections {
        target: volumeKeys
        onUp: app.changeVolume(10)
        onDown: app.changeVolume(-10)
    }

    Toast { id: toast; z: 100 }
}
