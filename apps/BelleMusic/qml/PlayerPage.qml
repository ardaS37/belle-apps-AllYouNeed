import QtQuick 1.1
import "Util.js" as U

// Tam ekran calar + calma kuyrugu
Rectangle {
    id: root
    color: app.bg
    property variant t: player.current
    property bool queueOpen: false
    property bool dragging: false
    property double dragPos: 0

    function takeFocus() { if (queueOpen) qlist.forceActiveFocus(); else root.forceActiveFocus(); }
    function back() { if (queueOpen) { queueOpen = false; takeFocus(); return true; } return false; }
    function showQueue() { queueOpen = true; qlist.currentIndex = Math.max(0, player.index); qlist.positionViewAtIndex(Math.max(0, player.index), ListView.Center); qFocus.restart(); }
    Timer { id: qFocus; interval: 50; onTriggered: qlist.forceActiveFocus() }

    MouseArea { anchors.fill: parent }      // alttaki sayfalara dokunmayi engelle

    function sleepMenu() {
        var acts = [
            { label: qsTr("15 dakika"), icon: "timer", act: "15" },
            { label: qsTr("30 dakika"), icon: "timer", act: "30" },
            { label: qsTr("45 dakika"), icon: "timer", act: "45" },
            { label: qsTr("60 dakika"), icon: "timer", act: "60" },
            { label: qsTr("90 dakika"), icon: "timer", act: "90" },
            { label: qsTr("Bu şarkı bitince"), icon: "note", act: "end" }
        ];
        if (player.sleepAt > 0 || player.sleepEndOfTrack) acts.push({ label: qsTr("Kapat"), icon: "close", act: "off" });
        app.openSheet(qsTr("Uyku zamanlayıcısı"), acts, function (a) {
            if (a === "off") { player.setSleep(0); player.sleepEndOfTrack = false; }
            else if (a === "end") player.sleepAfterTrack();
            else player.setSleep(parseInt(a, 10));
        });
    }

    // ---- Ust cubuk ----
    Item {
        id: topBar
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 60
        IconButton { id: closeBtn; anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter } icon: "back"; onClicked: app.closePlayer() }
        Column {
            anchors { left: closeBtn.right; leftMargin: 6; right: topBtns.left; verticalCenter: parent.verticalCenter }
            Text { text: qsTr("Çalıyor"); color: app.textPrimary; font.pixelSize: 20; font.bold: true }
            Text {
                text: (player.queue.count > 0 ? (player.index + 1) + " / " + player.queue.count : "")
                      + (root.t ? "  •  " + app.api().serviceName(root.t.service) : "")
                      + (app.isDownloaded(root.t ? root.t.key : "") && app.dlVersion >= 0 ? qsTr("  •  telefonda") : "")
                color: app.textSecondary; font.pixelSize: 14
            }
        }
        Row {
            id: topBtns
            anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
            IconButton { icon: "queue"; onClicked: root.showQueue() }
            IconButton { icon: "more"; onClicked: if (root.t) app.trackMenu(root.t) }
        }
    }

    // ---- Kapak ----
    Cover {
        id: bigCover
        anchors { left: parent.left; leftMargin: 26; top: topBar.bottom; topMargin: 14 }
        size: Math.min(root.height - topBar.height - 46, 300)
        radius: 12
        source: root.t ? root.t.image : ""
    }

    // ---- Bilgi ve kontroller ----
    Item {
        id: panel
        anchors { left: bigCover.right; leftMargin: 24; right: parent.right; rightMargin: 20; top: bigCover.top; bottom: bigCover.bottom }

        Column {
            id: info
            width: parent.width
            spacing: 4
            Text { width: parent.width; text: root.t ? root.t.name : ""; color: app.textPrimary; font.pixelSize: 24; font.bold: true; elide: Text.ElideRight }
            Text { width: parent.width; text: root.t ? root.t.singer : ""; color: app.textSecondary; font.pixelSize: 19; elide: Text.ElideRight }
            Text {
                visible: text !== ""
                text: player.loading ? qsTr("Yükleniyor...") : (player.status !== "" ? player.status : "")
                color: app.accent; font.pixelSize: 15
            }
        }

        // Ilerleme cubugu
        Item {
            id: seekArea
            anchors { left: parent.left; right: parent.right; bottom: controls.top; bottomMargin: 10 }
            height: 54
            property double frac: root.dragging ? root.dragPos : (player.duration > 0 ? Math.min(1, player.position / player.duration) : 0)
            Rectangle {
                id: track
                anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 12 }
                height: 6; radius: 3; color: "#3A3A46"
                Rectangle { width: parent.width * seekArea.frac; height: parent.height; radius: 3; color: app.accent }
                Rectangle { x: parent.width * seekArea.frac - width / 2; anchors.verticalCenter: parent.verticalCenter; width: root.dragging ? 22 : 16; height: width; radius: width / 2; color: "white" }
            }
            Text { anchors { left: parent.left; bottom: parent.bottom } text: U.dur((root.dragging ? root.dragPos * player.duration : player.position) / 1000); color: app.textSecondary; font.pixelSize: 15 }
            Text { anchors { right: parent.right; bottom: parent.bottom } text: U.dur(player.duration / 1000); color: app.textSecondary; font.pixelSize: 15 }
            MouseArea {
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; bottomMargin: 16 }
                function frac(x) { return Math.max(0, Math.min(1, x / width)); }
                onPressed: { root.dragging = true; root.dragPos = frac(mouse.x); }
                onPositionChanged: root.dragPos = frac(mouse.x)
                onReleased: { root.dragging = false; player.seek(root.dragPos * player.duration); }
                onCanceled: root.dragging = false
            }
        }

        // Ana kontroller
        Row {
            id: controls
            anchors { horizontalCenter: parent.horizontalCenter; bottom: extras.top; bottomMargin: 8 }
            spacing: 6
            IconButton { anchors.verticalCenter: parent.verticalCenter; icon: "shuffle"; tone: player.shuffle ? "a" : "g"; iconSize: 28; onClicked: { player.setShuffle(!player.shuffle); app.showToast(player.shuffle ? qsTr("Karışık çalma açık") : qsTr("Karışık çalma kapalı")); } }
            IconButton { anchors.verticalCenter: parent.verticalCenter; icon: "prev"; iconSize: 34; width: 64; height: 64; onClicked: player.prev() }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 76; height: 76; radius: 38
                color: pma.pressed ? app.accentPressed : app.accent
                Image { anchors.centerIn: parent; anchors.horizontalCenterOffset: player.playing || player.loading ? 0 : 3; width: 38; height: 38; smooth: true; source: player.playing || player.loading ? "../images/pause_w.png" : "../images/play_w.png" }
                MouseArea { id: pma; anchors.fill: parent; onClicked: player.toggle() }
            }
            IconButton { anchors.verticalCenter: parent.verticalCenter; icon: "next"; iconSize: 34; width: 64; height: 64; onClicked: player.next(true) }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: player.repeat === 2 ? "repeat1" : "repeat"; tone: player.repeat > 0 ? "a" : "g"; iconSize: 28
                onClicked: { player.cycleRepeat(); app.showToast(player.repeat === 0 ? qsTr("Tekrar kapalı") : (player.repeat === 1 ? qsTr("Listeyi tekrarla") : qsTr("Bu şarkıyı tekrarla"))); }
            }
        }

        // Ikincil dugmeler
        Row {
            id: extras
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
            spacing: 14
            property bool fav: root.t ? (app.favVersion >= 0 && app.isFav(root.t.key)) : false
            property bool dl: root.t ? (app.dlVersion >= 0 && app.isDownloaded(root.t.key)) : false
            IconButton { icon: extras.fav ? "heart" : "heart_o"; tone: extras.fav ? "a" : "w"; iconSize: 28; onClicked: { var on = !extras.fav; app.setFav(root.t, on); app.showToast(on ? qsTr("Favorilere eklendi") : qsTr("Favorilerden çıkarıldı")); } }
            IconButton { icon: "plus"; iconSize: 28; onClicked: app.pickPlaylist([root.t]) }
            IconButton { icon: extras.dl ? "done" : "download"; tone: extras.dl ? "a" : "w"; iconSize: 28; onClicked: { if (!extras.dl) app.download([root.t]); else app.showToast(qsTr("Bu şarkı telefonda kayıtlı")); } }
            Item {
                width: 56; height: 56
                IconButton { anchors.fill: parent; icon: "timer"; tone: player.sleepAt > 0 || player.sleepEndOfTrack ? "a" : "w"; iconSize: 28; onClicked: root.sleepMenu() }
                Text {
                    visible: player.sleepAt > 0
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.bottom; topMargin: -8 }
                    text: Math.ceil(player.sleepLeft / 60) + qsTr(" dk"); color: app.accent; font.pixelSize: 12
                }
            }
        }
    }

    // ---- Klavye ----
    Keys.onSpacePressed: player.toggle()
    Keys.onReturnPressed: player.toggle()
    Keys.onEnterPressed: player.toggle()
    Keys.onSelectPressed: player.toggle()
    Keys.onLeftPressed: player.seekBy(-10)
    Keys.onRightPressed: player.seekBy(10)
    Keys.onUpPressed: player.prev()
    Keys.onDownPressed: player.next(true)
    Keys.onPressed: {
        if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Back || event.key === Qt.Key_Escape) { app.closePlayer(); event.accepted = true; }
        else if (event.key === Qt.Key_Q) { root.showQueue(); event.accepted = true; }
        else if (event.key === Qt.Key_F) { if (root.t) { var on = !app.isFav(root.t.key); app.setFav(root.t, on); app.showToast(on ? qsTr("Favorilere eklendi") : qsTr("Favorilerden çıkarıldı")); } event.accepted = true; }
    }

    // ================= Calma kuyrugu =================
    Rectangle {
        id: queuePanel
        anchors.fill: parent
        visible: root.queueOpen
        color: app.bg
        MouseArea { anchors.fill: parent }
        Header {
            id: qh
            anchors { left: parent.left; right: parent.right; top: parent.top }
            showBack: true
            title: qsTr("Çalma kuyruğu")
            subtitle: player.queue.count + qsTr(" şarkı") + (player.shuffle ? qsTr("  •  karışık") : "")
            onBack: { root.queueOpen = false; root.takeFocus(); }
            IconButton { icon: "shuffle"; tone: player.shuffle ? "a" : "w"; onClicked: player.setShuffle(!player.shuffle) }
            IconButton { icon: "trash"; onClicked: app.openSheet(qsTr("Sıradaki şarkılar temizlensin mi?"), [{ label: qsTr("Evet, temizle"), icon: "trash", act: "yes" }, { label: qsTr("Vazgeç"), icon: "close", act: "no" }], function (a) { if (a === "yes") player.clearUpcoming(); }) }
        }
        ListView {
            id: qlist
            anchors { left: parent.left; right: parent.right; top: qh.bottom; bottom: parent.bottom }
            clip: true
            model: player.queue
            delegate: TrackRow {
                tKey: model.key; tName: model.name; tSinger: model.singer; tDuration: model.duration; tImage: model.image
                isCurrent: ListView.isCurrentItem && qlist.activeFocus
                opacity: index < player.index ? 0.55 : 1
                onClicked: player.jumpTo(index)
                onPressAndHold: root.queueMenu(index)
                onMoreClicked: root.queueMenu(index)
            }
            Keys.onReturnPressed: player.jumpTo(currentIndex)
            Keys.onEnterPressed: player.jumpTo(currentIndex)
            Keys.onSelectPressed: player.jumpTo(currentIndex)
            Keys.onPressed: {
                if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Back || event.key === Qt.Key_Escape) { root.queueOpen = false; root.takeFocus(); event.accepted = true; }
                else if (event.key === Qt.Key_Delete) { player.removeAt(currentIndex); event.accepted = true; }
            }
        }
    }
    function queueMenu(i) {
        var t = player.trackAt(i);
        if (!t) return;
        app.openSheet(t.name, [
            { label: qsTr("Şimdi çal"), icon: "play", act: "play" },
            { label: qsTr("Sıradaki yap"), icon: "next", act: "next" },
            { label: qsTr("Yukarı taşı"), icon: "back", act: "up" },
            { label: qsTr("Aşağı taşı"), icon: "back", act: "down" },
            { label: qsTr("Kuyruktan çıkar"), icon: "trash", act: "rm" },
            { label: app.isFav(t.key) ? qsTr("Favorilerden çıkar") : qsTr("Favorilere ekle"), icon: "heart_o", act: "fav" },
            { label: qsTr("Listeye ekle"), icon: "plus", act: "pl" }
        ], function (a) {
            if (a === "play") player.jumpTo(i);
            else if (a === "next") { var to = i < player.index ? player.index : player.index + 1; player.moveItem(i, to); }
            else if (a === "up") player.moveItem(i, Math.max(0, i - 1));
            else if (a === "down") player.moveItem(i, Math.min(player.queue.count - 1, i + 1));
            else if (a === "rm") player.removeAt(i);
            else if (a === "fav") { var on = !app.isFav(t.key); app.setFav(t, on); }
            else if (a === "pl") app.pickPlaylist([t]);
        });
    }
}
