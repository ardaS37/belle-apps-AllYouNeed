import QtQuick 1.1

// Kitaplik: favoriler, listeler, son calinanlar, indirilenler, calma kuyrugu
Rectangle {
    id: page
    color: app.bg

    function takeFocus() { list.forceActiveFocus(); }
    function reload() {
        var mine = app.myPlaylists();
        var dls = app.downloads();
        var size = 0;
        for (var i = 0; i < dls.length; i++) size += music.fileSize(app.downloadPath(dls[i].key));
        var rows = [
            { act: "fav", icon: "heart", title: qsTr("Favori şarkılar"), info: app.favCount() + qsTr(" şarkı") },
            { act: "favlists", icon: "list", title: qsTr("Favori listeler"), info: app.favLists().length + qsTr(" liste") },
            { act: "mylists", icon: "note", title: qsTr("Listelerim"), info: mine.length + qsTr(" liste") },
            { act: "recent", icon: "timer", title: qsTr("Son çalınanlar"), info: qsTr("En son dinlediğiniz 150 şarkı") },
            { act: "downloads", icon: "download", title: qsTr("İndirilenler"), info: dls.length + qsTr(" şarkı") + (size > 0 ? "  •  " + music.sizeText(size) : "") + (music.queueCount > 0 ? "  •  " + music.queueCount + qsTr(" iniyor") : "") },
            { act: "queue", icon: "queue", title: qsTr("Çalma kuyruğu"), info: player.queue.count > 0 ? player.queue.count + qsTr(" şarkı") : qsTr("Boş") },
            { act: "link", icon: "plus", title: qsTr("YouTube Music listesi ekle"), info: qsTr("Herkese açık listenizin bağlantısını yapıştırın") }
        ];
        for (i = 0; i < mine.length && i < 30; i++) rows.push({ act: "pl:" + mine[i].id, icon: "list", title: mine[i].name, info: mine[i].n + qsTr(" şarkı  •  Listem") });
        var cur = list.currentIndex;
        lm.clear();
        for (i = 0; i < rows.length; i++) lm.append(rows[i]);
        list.currentIndex = Math.min(Math.max(0, cur), lm.count - 1);
    }
    onVisibleChanged: if (visible) reload()
    Component.onCompleted: reload()
    Connections { target: app; onFavVersionChanged: if (page.visible) page.reload() }
    Connections { target: app; onPlVersionChanged: if (page.visible) page.reload() }
    Connections { target: app; onDlVersionChanged: if (page.visible) page.reload() }
    Connections { target: app; onFavListsVersionChanged: if (page.visible) page.reload() }

    function open(i) {
        var a = lm.get(i).act;
        if (a === "fav") app.openTracks("fav", qsTr("Favori şarkılar"));
        else if (a === "favlists") app.openLists("favlists");
        else if (a === "mylists") app.openLists("mylists");
        else if (a === "recent") app.openTracks("recent", qsTr("Son çalınanlar"));
        else if (a === "downloads") app.openTracks("downloads", qsTr("İndirilenler"));
        else if (a === "queue") { if (player.current) { app.openPlayer(); playerPage.showQueue(); } else app.showToast(qsTr("Kuyruk boş")); }
        else if (a === "link") app.addListByLink();
        else if (a.indexOf("pl:") === 0) { var id = parseInt(a.substring(3), 10); app.openTracks("playlist", lm.get(i).title, { plId: id }); }
    }
    function newList() {
        app.askText(qsTr("Yeni liste adı"), "", qsTr("Oluştur"), function (n) {
            n = n.replace(/^\s+|\s+$/g, "");
            if (n === "") return;
            app.createPlaylist(n);
            app.showToast("\"" + n + qsTr("\" oluşturuldu"));
        });
    }

    ListModel { id: lm }
    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: qsTr("Kitaplık")
        subtitle: music.queueCount > 0 ? qsTr("İndiriliyor: ") + music.queueCount + qsTr(" şarkı (%") + app.dlPercent + ")" : qsTr("Favoriler, listeler ve indirilenler")
        IconButton { icon: "plus"; onClicked: page.newList() }
    }
    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        clip: true
        model: lm
        delegate: Item {
            width: list.width
            height: 72
            property bool cur: ListView.isCurrentItem && list.activeFocus
            Rectangle { anchors.fill: parent; color: ma.pressed ? app.pressed : (parent.cur ? app.surface : "transparent") }
            Rectangle { visible: parent.cur; width: 4; height: parent.height; color: app.accent }
            Rectangle {
                id: tile
                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                width: 50; height: 50; radius: 10
                color: model.act === "fav" ? app.accent : app.surface2
                Image { anchors.centerIn: parent; width: 28; height: 28; smooth: true; source: "../images/" + model.icon + "_w.png" }
            }
            Column {
                anchors { left: tile.right; leftMargin: 14; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                spacing: 2
                Text { width: parent.width; text: model.title; color: app.textPrimary; font.pixelSize: 20; font.bold: model.act.indexOf("pl:") !== 0; elide: Text.ElideRight }
                Text { width: parent.width; text: model.info; color: app.textSecondary; font.pixelSize: 15; elide: Text.ElideRight }
            }
            Rectangle { anchors { left: tile.right; leftMargin: 14; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
            MouseArea { id: ma; anchors.fill: parent; onClicked: { list.currentIndex = index; page.open(index); } }
        }
        Keys.onReturnPressed: page.open(currentIndex)
        Keys.onEnterPressed: page.open(currentIndex)
        Keys.onSelectPressed: page.open(currentIndex)
    }
    Keys.onLeftPressed: { app.stepTab(-1); event.accepted = true; }
    Keys.onRightPressed: { app.stepTab(1); event.accepted = true; }
}
