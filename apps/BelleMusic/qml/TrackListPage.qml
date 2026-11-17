import QtQuick 1.1
import "Util.js" as U

// Sarki listesi sayfasi. mode:
//   remote    - sunucudaki liste/albüm (listInfo)
//   fav       - favori sarkilar
//   recent    - son calinanlar
//   downloads - indirilenler
//   playlist  - kendi listem (plId)
//   results   - verilen sarkilar (tracksIn)
Rectangle {
    id: page
    anchors.fill: parent
    color: app.bg

    property string mode: "remote"
    property variant listInfo: null
    property int plId: 0
    property variant tracksIn: []
    property string title: ""
    property string subtitle: ""
    property string cover: ""
    property bool loading: false
    property string error: ""
    property int totalSec: 0

    function takeFocus() { tl.takeFocus(); }

    function load() {
        error = "";
        if (mode === "remote") {
            loading = true;
            var l = listInfo;
            app.api().tracks(l.listKey, l.service, function (items) {
                loading = false;
                var arr = [];
                for (var i = 0; i < items.length; i++) arr.push(app.api().toTrack(items[i], l.service));
                setTracks(arr);
                if (arr.length === 0) error = qsTr("Bu listede şarkı yok.");
            }, function (msg) { loading = false; error = msg; });
            return;
        }
        if (mode === "fav") setTracks(app.favTracks());
        else if (mode === "recent") setTracks(app.recentTracks());
        else if (mode === "downloads") setTracks(app.downloads());
        else if (mode === "playlist") { title = app.playlistName(plId); setTracks(app.playlistTracks(plId)); }
        else if (mode === "results") setTracks(tracksIn);
    }
    function setTracks(arr) {
        tl.setTracks(arr);
        var s = 0;
        for (var i = 0; i < arr.length; i++) s += arr[i].duration || 0;
        totalSec = s;
        if ((cover === "" || mode !== "remote") && arr.length > 0) cover = arr[0].image;
    }
    Component.onCompleted: load()

    // Yerel listeler degisince tazele (secim modundayken degil)
    Connections { target: app; onFavVersionChanged: if (page.mode === "fav" && !tl.selectMode) page.load() }
    Connections { target: app; onPlVersionChanged: if (page.mode === "playlist" && !tl.selectMode) page.load() }
    Connections { target: app; onDlVersionChanged: if (page.mode === "downloads" && !tl.selectMode) page.load() }

    property string removeLabel: mode === "fav" ? qsTr("Favorilerden çıkar") : (mode === "playlist" ? qsTr("Listeden çıkar") : (mode === "downloads" ? qsTr("Telefondan sil") : (mode === "recent" ? qsTr("Geçmişten sil") : "")))
    function removeKeys(keys) {
        if (mode === "fav") { var arr = []; for (var i = 0; i < keys.length; i++) arr.push({ key: keys[i] }); app.setFavMany(arr, false); app.showToast(keys.length + qsTr(" şarkı favorilerden çıkarıldı")); }
        else if (mode === "playlist") { app.removeFromPlaylist(plId, keys); app.showToast(keys.length + qsTr(" şarkı listeden çıkarıldı")); }
        else if (mode === "downloads") { app.removeDownloads(keys); app.showToast(keys.length + qsTr(" dosya silindi")); }
        else if (mode === "recent") { app.db().transaction(function (tx) { for (var j = 0; j < keys.length; j++) tx.executeSql("DELETE FROM recent WHERE key = ?", [keys[j]]); }); app.recentVersion++; }
        load();
    }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        showBack: true
        title: tl.selectMode ? tl.selCount + qsTr(" şarkı seçildi") : page.title
        subtitle: tl.selectMode ? qsTr("Uzun basın ya da Boşluk ile işaretleyin") : (tl.model.count + qsTr(" şarkı") + (page.totalSec > 0 ? "  •  " + U.totalDur(page.totalSec) : "") + (page.mode === "remote" && page.listInfo ? "  •  " + app.api().serviceName(page.listInfo.service) : ""))
        onBack: { if (tl.selectMode) tl.endSelect(); else app.pop(); }
        IconButton {
            visible: page.mode === "remote" && !tl.selectMode
            icon: page.listInfo && app.favListsVersion >= 0 && app.isFavList(page.listInfo.listKey) ? "heart" : "heart_o"
            tone: page.listInfo && app.favListsVersion >= 0 && app.isFavList(page.listInfo.listKey) ? "a" : "w"
            onClicked: {
                var on = !app.isFavList(page.listInfo.listKey);
                if (on && page.listInfo.askName) { app.saveListAsk(page.withCover(), function (c) { page.title = c.name; }); return; }
                app.setFavList(page.withCover(), on);
                app.showToast(on ? qsTr("Liste favorilere eklendi") : qsTr("Liste favorilerden çıkarıldı"));
            }
        }
        IconButton { visible: !tl.selectMode && tl.model.count > 0; icon: "select"; onClicked: tl.startSelect(-1) }
        IconButton { visible: !tl.selectMode && page.mode === "playlist"; icon: "more"; onClicked: page.playlistMenu() }
    }

    // Kaydederken kapak yoksa ilk sarkinin kapagini kullan
    function withCover() {
        var l = listInfo;
        return { listKey: l.listKey, name: title !== "" ? title : l.name, singer: l.singer, image: l.image !== "" ? l.image : cover, service: l.service, askName: l.askName === true };
    }

    function playlistMenu() {
        app.openSheet(title, [
            { label: qsTr("Yeniden adlandır"), icon: "list", act: "rename" },
            { label: qsTr("Listeyi sil"), icon: "trash", act: "delete" }
        ], function (a) {
            if (a === "rename") app.askText(qsTr("Liste adı"), title, qsTr("Kaydet"), function (n) { n = n.replace(/^\s+|\s+$/g, ""); if (n !== "") { app.renamePlaylist(plId, n); title = n; } });
            else if (a === "delete") app.openSheet("\"" + title + qsTr("\" silinsin mi?"), [{ label: qsTr("Evet, sil"), icon: "trash", act: "yes" }, { label: qsTr("Vazgeç"), icon: "close", act: "no" }], function (b) {
                if (b === "yes") { app.deletePlaylist(plId); app.showToast(qsTr("Liste silindi")); app.pop(); }
            });
        });
    }

    TrackList {
        id: tl
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        removeLabel: page.removeLabel
        busy: page.loading
        emptyText: page.error !== "" ? page.error
                   : (page.mode === "fav" ? qsTr("Henüz favori şarkı yok.\nŞarkıdaki ••• menüsünden ya da çoklu seçimle ekleyebilirsiniz.")
                   : (page.mode === "downloads" ? qsTr("İndirilen şarkı yok.") : (page.mode === "recent" ? qsTr("Henüz şarkı çalınmadı.") : qsTr("Liste boş."))))
        onRemoveRequested: page.removeKeys(keys)
        header: Item {
            width: page.width
            height: tl.model.count > 0 ? 92 : 0
            visible: tl.model.count > 0
            Cover { id: hc; anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter } size: 70; source: page.cover }
            Row {
                anchors { left: hc.right; leftMargin: 14; verticalCenter: parent.verticalCenter }
                spacing: 10
                Btn { text: qsTr("Çal"); icon: "play"; primary: true; onClicked: player.playTracks(tl.allTracks(), 0, false) }
                Btn { text: qsTr("Karışık"); icon: "shuffle"; onClicked: player.playTracks(tl.allTracks(), 0, true) }
                Btn {
                    text: page.mode === "fav" ? qsTr("Kuyruğa") : qsTr("Favori")
                    icon: page.mode === "fav" ? "queue" : "heart_o"
                    onClicked: {
                        if (page.mode === "fav") { player.enqueue(tl.allTracks()); app.showToast(tl.model.count + qsTr(" şarkı kuyruğa eklendi")); }
                        else { var n = app.setFavMany(tl.allTracks(), true); app.showToast(n > 0 ? n + qsTr(" şarkı favorilere eklendi") : qsTr("Hepsi zaten favorilerde")); }
                    }
                }
                Btn { visible: page.mode !== "downloads"; text: qsTr("İndir"); icon: "download"; onClicked: app.download(tl.allTracks()) }
            }
        }
    }

    Column {
        anchors.centerIn: parent
        visible: page.loading
        spacing: 10
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: qsTr("Yükleniyor..."); color: app.textSecondary; font.pixelSize: 19 }
    }
    Btn { visible: page.error !== "" && page.mode === "remote" && !page.loading; anchors { horizontalCenter: parent.horizontalCenter; top: parent.verticalCenter; topMargin: 40 } text: qsTr("Yeniden dene"); onClicked: page.load() }

    Keys.onLeftPressed: { if (!tl.selectMode) app.pop(); event.accepted = true; }
    Keys.onPressed: {
        if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Back) { if (tl.selectMode) tl.endSelect(); else app.pop(); event.accepted = true; }
    }
}
