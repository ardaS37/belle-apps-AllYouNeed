import QtQuick 1.1

// Sarki listesi + coklu secim. Secim modunda alttaki cubuk: Tumu, Favori, Listeye, Kuyruk, Indir, (Cikar)
// Uzun basma secim modunu acar. Klavye: yukari/asagi, Enter/orta tus calar (secimde isaretler), Bosluk isaretler.
Item {
    id: root
    property alias model: tm
    property alias view: list
    property alias header: list.header
    property bool selectMode: false
    property int selCount: 0
    property bool numbered: false          // kapak yerine sira numarasi
    property string removeLabel: ""        // bos degilse secim cubugunda "Cikar" dugmesi
    property string emptyText: ""
    property bool busy: false
    signal removeRequested(variant keys)
    signal topReached

    ListModel { id: tm }

    function setTracks(arr) {
        tm.clear();
        for (var i = 0; i < arr.length; i++) {
            var t = app.plain(arr[i]);
            t.sel = false;
            tm.append(t);
        }
        selCount = 0;
        if (tm.count === 0) selectMode = false;
        topTimer.restart();
    }
    // Liste dolunca basliktaki dugmeler de gorunsun (odak ilk satiri en uste kaydirmasin)
    Timer { id: topTimer; interval: 30; onTriggered: { list.currentIndex = 0; list.positionViewAtBeginning(); } }
    function allTracks() { var out = []; for (var i = 0; i < tm.count; i++) out.push(app.plain(tm.get(i))); return out; }
    function selectedTracks() { var out = []; for (var i = 0; i < tm.count; i++) if (tm.get(i).sel) out.push(app.plain(tm.get(i))); return out; }
    function selectedKeys() { var out = []; for (var i = 0; i < tm.count; i++) if (tm.get(i).sel) out.push(tm.get(i).key); return out; }
    function toggleSel(i) {
        if (i < 0 || i >= tm.count) return;
        var s = !tm.get(i).sel;
        tm.setProperty(i, "sel", s);
        selCount += s ? 1 : -1;
    }
    function selectAll(on) {
        for (var i = 0; i < tm.count; i++) tm.setProperty(i, "sel", on);
        selCount = on ? tm.count : 0;
    }
    function startSelect(i) { selectMode = true; selectAll(false); if (i >= 0) toggleSel(i); }
    function endSelect() { selectAll(false); selectMode = false; }
    function activate(i) {
        if (i < 0 || i >= tm.count) return;
        if (selectMode) toggleSel(i);
        else player.playTracks(allTracks(), i, false);
    }
    function takeFocus() { list.forceActiveFocus(); }

    function needSel() { if (selCount === 0) { app.showToast(qsTr("Önce şarkı seçin")); return false; } return true; }
    function doFav() {
        if (!needSel()) return;
        var arr = selectedTracks();
        var allFav = true;
        for (var i = 0; i < arr.length; i++) if (!app.isFav(arr[i].key)) { allFav = false; break; }
        var n = app.setFavMany(arr, !allFav);
        app.showToast(allFav ? n + qsTr(" şarkı favorilerden çıkarıldı") : n + qsTr(" şarkı favorilere eklendi"));
        endSelect();
    }
    function doList() { if (!needSel()) return; app.pickPlaylist(selectedTracks()); endSelect(); }
    function doQueue() { if (!needSel()) return; var a = selectedTracks(); player.enqueue(a); app.showToast(a.length + qsTr(" şarkı kuyruğa eklendi")); endSelect(); }
    function doPlay() { if (!needSel()) return; player.playTracks(selectedTracks(), 0, false); endSelect(); }
    function doDownload() { if (!needSel()) return; app.download(selectedTracks()); endSelect(); }
    function doRemove() { if (!needSel()) return; root.removeRequested(selectedKeys()); endSelect(); }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: selBar.visible ? selBar.top : parent.bottom }
        clip: true
        model: tm
        cacheBuffer: 400
        keyNavigationWraps: false
        delegate: TrackRow {
            tKey: model.key; tName: model.name; tSinger: model.singer; tDuration: model.duration; tImage: model.image
            selectMode: root.selectMode
            selected: model.sel
            isCurrent: ListView.isCurrentItem && list.activeFocus
            number: index + 1
            showCover: !root.numbered
            onClicked: { list.currentIndex = index; root.activate(index); }
            onPressAndHold: { if (!root.selectMode) root.startSelect(index); else root.toggleSel(index); }
            onMoreClicked: {
                var extra = root.removeLabel !== "" ? [{ label: root.removeLabel, icon: "trash", act: "remove" }] : null;
                var k = model.key;
                app.trackMenu(app.plain(tm.get(index)), extra, function (a) { if (a === "remove") root.removeRequested([k]); });
            }
        }
        footer: Item { width: list.width; height: 12 }
        Keys.onReturnPressed: root.activate(currentIndex)
        Keys.onEnterPressed: root.activate(currentIndex)
        Keys.onSelectPressed: root.activate(currentIndex)
        Keys.onUpPressed: { if (currentIndex <= 0) root.topReached(); else decrementCurrentIndex(); event.accepted = true; }
        Keys.onSpacePressed: { if (!root.selectMode) root.startSelect(currentIndex); else root.toggleSel(currentIndex); }
        Keys.onPressed: {
            if (event.key === Qt.Key_Escape && root.selectMode) { root.endSelect(); event.accepted = true; }
        }
    }
    Text {
        anchors.centerIn: list
        visible: tm.count === 0 && !root.busy && root.emptyText !== ""
        width: parent.width - 80
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: root.emptyText
        color: app.textSecondary
        font.pixelSize: 18
    }

    // ---- Secim cubugu ----
    Rectangle {
        id: selBar
        visible: root.selectMode
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 74
        color: app.surface2
        Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: app.divider }
        Row {
            anchors.fill: parent
            Repeater {
                model: root.removeLabel !== ""
                       ? [[qsTr("Tümü"), "select", "all"], [qsTr("Çal"), "play", "play"], [qsTr("Favori"), "heart_o", "fav"], [qsTr("Listeye"), "plus", "list"], [qsTr("Kuyruk"), "queue", "queue"], [qsTr("İndir"), "download", "dl"], [qsTr("Çıkar"), "trash", "rm"], [qsTr("Kapat"), "close", "x"]]
                       : [[qsTr("Tümü"), "select", "all"], [qsTr("Çal"), "play", "play"], [qsTr("Favori"), "heart_o", "fav"], [qsTr("Listeye"), "plus", "list"], [qsTr("Kuyruk"), "queue", "queue"], [qsTr("İndir"), "download", "dl"], [qsTr("Kapat"), "close", "x"]]
                Item {
                    width: selBar.width / (root.removeLabel !== "" ? 8 : 7)
                    height: selBar.height
                    Rectangle { anchors.fill: parent; color: bma.pressed ? app.pressed : "transparent" }
                    Image { id: bi; anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 10 } width: 28; height: 28; smooth: true; source: "../images/" + modelData[1] + "_w.png" }
                    Text { anchors { horizontalCenter: parent.horizontalCenter; top: bi.bottom; topMargin: 4 } text: modelData[0]; color: app.textPrimary; font.pixelSize: 14 }
                    MouseArea {
                        id: bma
                        anchors.fill: parent
                        onClicked: {
                            var a = modelData[2];
                            if (a === "all") root.selectAll(root.selCount < tm.count);
                            else if (a === "play") root.doPlay();
                            else if (a === "fav") root.doFav();
                            else if (a === "list") root.doList();
                            else if (a === "queue") root.doQueue();
                            else if (a === "dl") root.doDownload();
                            else if (a === "rm") root.doRemove();
                            else root.endSelect();
                        }
                    }
                }
            }
        }
    }
}
