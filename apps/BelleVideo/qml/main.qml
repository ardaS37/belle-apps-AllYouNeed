import QtQuick 1.1
import "Util.js" as U

Rectangle {
    id: app
    width: 640
    height: 480
    color: bg

    // ---- Tema (karanlik, kehribar vurgu) ----
    property color brand: "#FFB300"
    property color brandPressed: "#E09E00"
    property color pill: "#3A2E10"
    property color bg: "#101418"
    property color surface: "#1A2026"
    property color textPrimary: "#ECEFF1"
    property color textSecondary: "#8C98A4"
    property color divider: "#252D35"
    property color pressed: "#232B33"
    property color highlight: "#26303A"
    property color fieldBg: "#252E37"
    property color danger: "#F15C6D"
    property string version: "1.1"

    // ---- Ayarlar ----
    property bool resume: true          // kaldigi yerden devam
    property bool bgAudio: true         // kilitte / arka planda sesle devam
    property bool autoNext: false       // klasor/video listesinde bitince sonrakine gec (Liste'de hep gecer)
    property int seekStep: 10           // sn
    property bool directFile: false     // yerel sunucuyu atla (sorun giderme)
    property int volume: 60             // 0-100
    property int repeatMode: 0          // 0 kapali, 1 tumu, 2 tek
    property bool shuffle: false

    // ---- Durum ----
    property int tab: 0                 // 0 Videolar, 1 Klasorler, 2 Liste, 3 Akis, 4 Ayarlar
    property bool playerOpen: false
    property string nowPath: ""         // oynatilan dosya/adres
    property string nowSource: ""       // "list" | "folder" | "videos" | "stream" | "single"
    property bool sheetShown: sheet.shown

    function showToast(m) { toast.show(m); }

    // ---- Kalici ayarlar (LocalStorage) ----
    function db() { return openDatabaseSync("E6Video", "1.0", "BelleVideo", 200000); }
    function initDb() {
        db().transaction(function (tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS kv(k TEXT UNIQUE, v TEXT)");
            tx.executeSql("CREATE TABLE IF NOT EXISTS list(pos INTEGER, path TEXT, title TEXT)");
            tx.executeSql("CREATE TABLE IF NOT EXISTS fav(pos INTEGER, title TEXT, url TEXT)");
        });
    }
    function setting(k, def) {
        var v = def;
        db().readTransaction(function (tx) {
            var rs = tx.executeSql("SELECT v FROM kv WHERE k = ?", [k]);
            if (rs.rows.length > 0) v = rs.rows.item(0).v;
        });
        return v;
    }
    function setSetting(k, v) {
        db().transaction(function (tx) { tx.executeSql("INSERT OR REPLACE INTO kv(k, v) VALUES(?, ?)", [k, "" + v]); });
    }

    // ---- Calma listesi ----
    ListModel { id: playlistModel }
    property alias playlist: playlistModel
    function loadPlaylist() {
        playlistModel.clear();
        db().readTransaction(function (tx) {
            var rs = tx.executeSql("SELECT path, title FROM list ORDER BY pos");
            for (var i = 0; i < rs.rows.length; i++) playlistModel.append({ path: rs.rows.item(i).path, title: rs.rows.item(i).title });
        });
    }
    function savePlaylist() {
        db().transaction(function (tx) {
            tx.executeSql("DELETE FROM list");
            for (var i = 0; i < playlistModel.count; i++)
                tx.executeSql("INSERT INTO list(pos, path, title) VALUES(?, ?, ?)", [i, playlistModel.get(i).path, playlistModel.get(i).title]);
        });
    }
    function listIndexOf(path) {
        for (var i = 0; i < playlistModel.count; i++) if (playlistModel.get(i).path === path) return i;
        return -1;
    }
    function addToList(path, title) {
        if (listIndexOf(path) >= 0) { showToast(qsTr("Zaten listede")); return; }
        playlistModel.append({ path: path, title: title || lib.baseName(path) });
        savePlaylist();
        showToast(qsTr("Listeye eklendi (") + playlistModel.count + ")");
    }
    function addManyToList(paths) {
        var n = 0;
        for (var i = 0; i < paths.length; i++) {
            if (listIndexOf(paths[i]) >= 0) continue;
            playlistModel.append({ path: paths[i], title: lib.baseName(paths[i]) });
            n++;
        }
        savePlaylist();
        showToast(n + qsTr(" dosya listeye eklendi"));
    }
    function removeFromList(i) { if (i >= 0 && i < playlistModel.count) { playlistModel.remove(i); savePlaylist(); } }
    function moveInList(i, d) {
        var j = i + d;
        if (j < 0 || j >= playlistModel.count) return i;
        playlistModel.move(i, j, 1);
        savePlaylist();
        return j;
    }
    function clearList() { playlistModel.clear(); savePlaylist(); }
    function playList(index, audioOnly) {
        if (playlistModel.count === 0) { showToast(qsTr("Liste boş")); return; }
        var paths = [], titles = [];
        for (var i = 0; i < playlistModel.count; i++) { paths.push(playlistModel.get(i).path); titles.push(playlistModel.get(i).title); }
        play(paths, titles, index < 0 ? 0 : index, "list", audioOnly);
    }

    // ---- Favori akislar ----
    ListModel { id: favModel }
    property alias favs: favModel
    function loadFavs() {
        favModel.clear();
        db().readTransaction(function (tx) {
            var rs = tx.executeSql("SELECT title, url FROM fav ORDER BY pos");
            for (var i = 0; i < rs.rows.length; i++) favModel.append({ title: rs.rows.item(i).title, url: rs.rows.item(i).url });
        });
    }
    function saveFavs() {
        db().transaction(function (tx) {
            tx.executeSql("DELETE FROM fav");
            for (var i = 0; i < favModel.count; i++)
                tx.executeSql("INSERT INTO fav(pos, title, url) VALUES(?, ?, ?)", [i, favModel.get(i).title, favModel.get(i).url]);
        });
    }
    function addFav(title, url) {
        for (var i = 0; i < favModel.count; i++) if (favModel.get(i).url === url) { showToast(qsTr("Zaten favorilerde")); return; }
        favModel.append({ title: title || lib.baseName(url), url: url });
        saveFavs();
        showToast(qsTr("Favorilere eklendi"));
    }
    function removeFav(i) { if (i >= 0 && i < favModel.count) { favModel.remove(i); saveFavs(); } }

    // ---- Oynatma ----
    // paths: dosya yollari / adresler; titles: ayni sirada basliklar (bos olabilir)
    function play(paths, titles, index, source, audioOnly) {
        player.open(paths, titles, index, source, !!audioOnly);
        playerOpen = true;
        player.forceActiveFocus();
    }
    function playOne(path, title, audioOnly) { play([path], [title || ""], 0, "single", audioOnly); }
    function closePlayer() {
        player.leave();
        playerOpen = false;
        nowPath = "";
        focusTab();
        if (tab === 0) videosPage.refreshRecent();
    }

    // Dosya secenekleri (Videolar, Klasorler, Akis/indirilenler)
    function fileMenu(path, title, queuePaths, queueTitles, index, source) {
        var inList = listIndexOf(path) >= 0;
        var items = [
            { label: qsTr("Oynat"), icon: "play", key: "play" },
            { label: qsTr("Sadece ses (arka planda)"), icon: "phones", key: "audio" },
            inList ? { label: qsTr("Listeden çıkar"), icon: "queue", key: "unlist" } : { label: qsTr("Listeye ekle"), icon: "plus", key: "list" },
            { label: qsTr("Dış oynatıcıda aç"), icon: "bg", key: "ext" }
        ];
        if (lib.savedPosition(path) > 0) items.push({ label: qsTr("Baştan oynat"), icon: "refresh", key: "fresh" });
        items.push({ label: qsTr("Dosyayı sil"), icon: "trash", key: "del", danger: true });
        sheet.open(title || lib.baseName(path), items, function (k) {
            if (k === "play") app.play(queuePaths, queueTitles, index, source, false);
            else if (k === "audio") app.play(queuePaths, queueTitles, index, source, true);
            else if (k === "list") app.addToList(path, title);
            else if (k === "unlist") { app.removeFromList(app.listIndexOf(path)); app.showToast(qsTr("Listeden çıkarıldı")); }
            else if (k === "ext") { if (!lib.openExternally(path)) app.showToast(qsTr("Açılamadı")); }
            else if (k === "fresh") { lib.clearPosition(path); app.play(queuePaths, queueTitles, index, source, false); }
            else if (k === "del") app.confirmDelete(path, title);
        });
    }
    function confirmDelete(path, title) {
        sheet.open(qsTr("Silinsin mi? ") + (title || lib.baseName(path)), [
            { label: qsTr("Evet, dosyayı sil"), icon: "trash", key: "yes", danger: true },
            { label: qsTr("Vazgeç"), icon: "close", key: "no" }
        ], function (k) {
            if (k !== "yes") return;
            if (lib.removeFile(path)) {
                app.removeFromList(app.listIndexOf(path));
                app.showToast(qsTr("Silindi"));
                foldersPage.reload();
                streamPage.reloadDownloads();
            } else app.showToast(qsTr("Silinemedi"));
        });
    }

    // ---- Indirme durumu ----
    property int dlPercent: 0
    property int dlSpeed: 0
    property real dlReceived: 0
    Connections {
        target: lib
        onDownloadProgress: {
            app.dlReceived = received;
            app.dlPercent = total > 0 ? Math.floor(100 * received / total) : 0;
            app.dlSpeed = speedKBs;
        }
        onDownloadFinished: {
            app.showToast(message);
            app.dlPercent = 0;
            streamPage.reloadDownloads();
        }
    }

    // ---- Sekmeler ----
    function selectTab(i) {
        tab = i;
        setSetting("tab", i);
        if (i === 0) videosPage.refreshRecent();
        if (i === 3) streamPage.reloadDownloads();
        focusTab();
    }
    function stepTab(d) { selectTab((tab + d + 5) % 5); }
    function focusTab() {
        if (sheet.shown) return;
        if (playerOpen) { player.forceActiveFocus(); return; }
        if (tab === 0) videosPage.takeFocus();
        else if (tab === 1) foldersPage.takeFocus();
        else if (tab === 2) playlistPage.takeFocus();
        else if (tab === 3) streamPage.takeFocus();
        else settingsPage.takeFocus();
    }

    // ---- Ses ----
    function changeVolume(d) {
        volume = Math.max(0, Math.min(100, volume + d));
        volSave.restart();
        if (playerOpen) player.showVolume();
        else showToast(qsTr("Ses: %") + volume);
    }
    Timer { id: volSave; interval: 1500; onTriggered: app.setSetting("volume", app.volume) }
    Connections {
        target: keys
        onUp: app.changeVolume(10)
        onDown: app.changeVolume(-10)
        onPlayPause: if (app.playerOpen) player.togglePlay()
        onNext: if (app.playerOpen) player.next()
        onPrevious: if (app.playerOpen) player.prev()
        onStop: if (app.playerOpen) app.closePlayer()
    }

    Component.onCompleted: {
        initDb();
        resume = setting("resume", "1") === "1";
        bgAudio = setting("bgAudio", "1") === "1";
        autoNext = setting("autoNext", "0") === "1";
        seekStep = parseInt(setting("seekStep", "10"), 10);
        directFile = setting("directFile", "0") === "1";
        volume = parseInt(setting("volume", "60"), 10);
        repeatMode = parseInt(setting("repeat", "0"), 10);
        shuffle = setting("shuffle", "0") === "1";
        loadPlaylist();
        loadFavs();
        lib.log("acildi v" + version);
        // Ilk acilista ya da onbellek bossa tara; aksi halde 4 sn sonra sessizce guncelle
        if (lib.videos().length === 0) lib.rescan(); else scanLater.start();
        selectTab(parseInt(setting("tab", "0"), 10));
    }
    Timer { id: scanLater; interval: 4000; onTriggered: if (!app.playerOpen) lib.rescan() }

    // ---- Sayfalar ----
    Item {
        id: pages
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: nav.top }
        VideosPage { id: videosPage; anchors.fill: parent; visible: app.tab === 0 }
        FoldersPage { id: foldersPage; anchors.fill: parent; visible: app.tab === 1 }
        PlaylistPage { id: playlistPage; anchors.fill: parent; visible: app.tab === 2 }
        StreamPage { id: streamPage; anchors.fill: parent; visible: app.tab === 3 }
        SettingsPage { id: settingsPage; anchors.fill: parent; visible: app.tab === 4 }
    }
    BottomNav {
        id: nav
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        current: app.tab
        onSelected: app.selectTab(index)
    }

    PlayerPage {
        id: player
        anchors.fill: parent
        visible: app.playerOpen
        z: 20
    }

    ActionSheet { id: sheet }
    // Oynaticida video penceresi QML'in ustunde durdugu icin balon alttaki kontrol seridine biner
    Toast { id: toast; bottomGap: app.playerOpen ? 6 : 54 }
}
