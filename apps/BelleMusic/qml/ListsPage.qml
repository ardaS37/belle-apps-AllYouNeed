import QtQuick 1.1

// mode: "favlists" (kaydedilen sunucu listeleri) | "mylists" (kendi listelerim)
Rectangle {
    id: page
    anchors.fill: parent
    color: app.bg
    property string mode: "mylists"

    function takeFocus() { list.forceActiveFocus(); }
    function load() {
        lm.clear();
        var arr, i;
        if (mode === "favlists") {
            arr = app.favLists();
            for (i = 0; i < arr.length; i++) lm.append({ listKey: arr[i].listKey, name: arr[i].name, singer: arr[i].singer, image: arr[i].image, service: arr[i].service, pid: 0, n: 0 });
        } else {
            arr = app.myPlaylists();
            for (i = 0; i < arr.length; i++) {
                var tr = app.playlistTracks(arr[i].id);
                lm.append({ listKey: "", name: arr[i].name, singer: "", image: tr.length > 0 ? tr[0].image : "", service: "", pid: arr[i].id, n: arr[i].n });
            }
        }
    }
    Component.onCompleted: load()
    Connections { target: app; onPlVersionChanged: if (page.mode === "mylists") page.load() }
    Connections { target: app; onFavListsVersionChanged: if (page.mode === "favlists") page.load() }

    function newList() {
        app.askText(qsTr("Yeni liste adı"), "", qsTr("Oluştur"), function (n) {
            n = n.replace(/^\s+|\s+$/g, "");
            if (n === "") return;
            app.createPlaylist(n);
            app.showToast("\"" + n + qsTr("\" oluşturuldu"));
        });
    }
    function itemAt(i) { var m = lm.get(i); return { listKey: m.listKey, name: m.name, singer: m.singer, image: m.image, service: m.service, pid: m.pid }; }
    function open(i) {
        var it = itemAt(i);
        if (mode === "favlists") app.openList(it);
        else app.openTracks("playlist", it.name, { plId: it.pid });
    }
    function playIt(i, sh) {
        var it = itemAt(i);
        if (mode === "favlists") app.playRemoteList(it, sh);
        else { var tr = app.playlistTracks(it.pid); if (tr.length === 0) app.showToast(qsTr("Liste boş")); else player.playTracks(tr, 0, sh); }
    }
    function menu(i) {
        var it = itemAt(i);
        if (mode === "favlists") { app.listMenu(it); return; }
        app.openSheet(it.name, [
            { label: qsTr("Çal"), icon: "play", act: "play" },
            { label: qsTr("Karışık çal"), icon: "shuffle", act: "shuffle" },
            { label: qsTr("Kuyruğa ekle"), icon: "queue", act: "queue" },
            { label: qsTr("Yeniden adlandır"), icon: "list", act: "rename" },
            { label: qsTr("Listeyi sil"), icon: "trash", act: "delete" }
        ], function (a) {
            if (a === "play") playIt(i, false);
            else if (a === "shuffle") playIt(i, true);
            else if (a === "queue") { var tr = app.playlistTracks(it.pid); player.enqueue(tr); app.showToast(tr.length + qsTr(" şarkı kuyruğa eklendi")); }
            else if (a === "rename") app.askText(qsTr("Liste adı"), it.name, qsTr("Kaydet"), function (n) { n = n.replace(/^\s+|\s+$/g, ""); if (n !== "") app.renamePlaylist(it.pid, n); });
            else if (a === "delete") app.openSheet("\"" + it.name + qsTr("\" silinsin mi?"), [{ label: qsTr("Evet, sil"), icon: "trash", act: "yes" }, { label: qsTr("Vazgeç"), icon: "close", act: "no" }], function (b) {
                if (b === "yes") { app.deletePlaylist(it.pid); app.showToast(qsTr("Liste silindi")); }
            });
        });
    }

    ListModel { id: lm }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        showBack: true
        title: page.mode === "favlists" ? qsTr("Favori listeler") : qsTr("Listelerim")
        subtitle: lm.count + (page.mode === "favlists" ? qsTr(" liste") : qsTr(" liste  •  ••• ile yönet"))
        onBack: app.pop()
        IconButton { icon: "plus"; onClicked: { if (page.mode === "mylists") page.newList(); else app.addListByLink(); } }
    }
    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        clip: true
        model: lm
        delegate: ListRow {
            lKey: model.listKey; lName: model.name; lSinger: model.singer; lImage: model.image
            showFav: page.mode === "favlists"
            info: page.mode === "mylists" ? model.n + qsTr(" şarkı") : (model.singer !== "" ? model.singer + "  •  " : "") + app.api().serviceName(model.service)
            isCurrent: ListView.isCurrentItem && list.activeFocus
            onClicked: { list.currentIndex = index; page.open(index); }
            onPressAndHold: page.menu(index)
            onMoreClicked: page.menu(index)
        }
        Keys.onReturnPressed: page.open(currentIndex)
        Keys.onEnterPressed: page.open(currentIndex)
        Keys.onSelectPressed: page.open(currentIndex)
    }
    Column {
        anchors.centerIn: list
        visible: lm.count === 0
        spacing: 16
        width: parent.width - 100
        Text {
            width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
            text: page.mode === "favlists" ? qsTr("Kaydedilmiş liste yok.\nBir listeyi açıp kalp simgesine dokunun ya da + ile YouTube Music liste bağlantısı ekleyin.") : qsTr("Henüz listeniz yok.")
            color: app.textSecondary; font.pixelSize: 18
        }
        Btn { visible: page.mode === "mylists"; anchors.horizontalCenter: parent.horizontalCenter; text: qsTr("Yeni liste"); icon: "plus"; primary: true; onClicked: page.newList() }
    }
    Keys.onLeftPressed: { app.pop(); event.accepted = true; }
    Keys.onPressed: if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Back) { app.pop(); event.accepted = true; }
}
