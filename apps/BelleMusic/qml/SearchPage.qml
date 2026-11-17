import QtQuick 1.1

// Arama: sarki / liste / albüm, servis secimi, son aramalar. Sarki sonuclarinda coklu secim.
Rectangle {
    id: page
    color: app.bg
    property string svc: app.service
    property string kind: "track"          // track | playlist | album
    property string query: ""
    property bool loading: false
    property string error: ""
    property int seq: 0

    function takeFocus() {
        if (query === "" || (kind === "track" ? tl.model.count === 0 : lm.count === 0)) field.focusInput();
        else focusResults();
    }
    function focusResults() { if (kind === "track") tl.takeFocus(); else list.forceActiveFocus(); }

    function search(q) {
        q = (q || "").replace(/^\s+|\s+$/g, "");
        field.text = q;
        if (q === "") return;
        // YouTube Music liste baglantisi yapistirildiysa listeyi dogrudan ac
        var yl = app.api().ytListFromText(q);
        if (yl && (q.indexOf("list=") >= 0 || q.indexOf(" ") < 0 && q.length > 15)) { field.text = ""; app.openList(yl); return; }
        query = q;
        app.addSearch(q);
        reloadHistory();
        run();
    }
    function run() {
        if (query === "") return;
        error = "";
        loading = true;
        tl.setTracks([]);
        lm.clear();
        var my = ++seq;
        var s = svc;
        if (kind === "track") {
            app.api().searchTracks(query, s, function (items) {
                if (my !== seq) return;
                loading = false;
                var arr = [];
                for (var i = 0; i < items.length; i++) arr.push(app.api().toTrack(items[i], s));
                tl.setTracks(arr);
                if (arr.length === 0) error = qsTr("Sonuç bulunamadı.");
                else tl.takeFocus();
            }, function (msg) { if (my !== seq) return; loading = false; error = msg; });
        } else {
            app.api().searchLists(query, kind, s, function (items) {
                if (my !== seq) return;
                loading = false;
                for (var i = 0; i < items.length; i++) lm.append(app.api().toList(items[i], s));
                if (lm.count === 0) error = qsTr("Sonuç bulunamadı.");
                else list.forceActiveFocus();
            }, function (msg) { if (my !== seq) return; loading = false; error = msg; });
        }
    }
    onSvcChanged: run()
    onKindChanged: run()

    function reloadHistory() {
        hm.clear();
        var arr = app.recentSearches();
        for (var i = 0; i < arr.length; i++) hm.append({ q: arr[i] });
    }
    Component.onCompleted: reloadHistory()

    function item(i) { var m = lm.get(i); return { listKey: m.listKey, name: m.name, singer: m.singer, image: m.image, service: m.service }; }

    ListModel { id: lm }
    ListModel { id: hm }

    // ---- Ust kisim: arama kutusu + secimler ----
    Rectangle {
        id: topBar
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: tl.selectMode ? 64 : 120
        color: app.bg
        Item {
            visible: !tl.selectMode
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
            height: 52
            TextField {
                id: field
                anchors { left: parent.left; leftMargin: 12; right: goBtn.left; rightMargin: 6 }
                icon: "search"
                placeholder: qsTr("Şarkı, sanatçı, albüm ara")
                onAccepted: page.search(text)
                onDownPressed: page.focusResults()
            }
            IconButton { id: goBtn; anchors { right: parent.right; rightMargin: 6; verticalCenter: field.verticalCenter } icon: field.text.length > 0 ? "close" : "search"; onClicked: { if (field.text.length > 0) { field.text = ""; field.focusInput(); } else page.search(field.text); } }
        }
        Flickable {
            visible: !tl.selectMode
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 6 }
            height: 48
            contentWidth: chips.width + 28
            clip: true
            Row {
                id: chips
                x: 12; anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Chip { text: qsTr("Şarkı"); selected: page.kind === "track"; onClicked: page.kind = "track" }
                Chip { text: qsTr("Liste"); selected: page.kind === "playlist"; onClicked: page.kind = "playlist" }
                Chip { text: qsTr("Albüm"); selected: page.kind === "album"; onClicked: page.kind = "album" }
                Rectangle { width: 1; height: 28; color: app.divider; anchors.verticalCenter: parent.verticalCenter }
                Repeater {
                    model: app.belleModu ? [] : app.api().SERVICES   // kendi sunucumuzda tek kaynak: servis secimi yok
                    Chip { text: modelData.name; selected: page.svc === modelData.id; onClicked: page.svc = modelData.id }
                }
            }
        }
        // Secim modunda baslik
        Header {
            visible: tl.selectMode
            anchors.fill: parent
            showBack: true
            title: tl.selCount + qsTr(" şarkı seçildi")
            subtitle: qsTr("Uzun basın ya da Boşluk ile işaretleyin")
            onBack: tl.endSelect()
            IconButton { icon: "select"; onClicked: tl.selectAll(tl.selCount < tl.model.count) }
        }
        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
    }

    // ---- Sarki sonuclari ----
    TrackList {
        id: tl
        visible: page.kind === "track" && page.query !== ""
        anchors { left: parent.left; right: parent.right; top: topBar.bottom; bottom: parent.bottom }
        busy: page.loading
        onTopReached: if (!tl.selectMode) field.focusInput()
        header: Item {
            width: page.width
            height: tl.model.count > 0 && !tl.selectMode ? 62 : 0
            visible: height > 0
            Row {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 10
                Btn { text: qsTr("Tümünü çal"); icon: "play"; primary: true; onClicked: player.playTracks(tl.allTracks(), 0, false) }
                Btn { text: qsTr("Karışık"); icon: "shuffle"; onClicked: player.playTracks(tl.allTracks(), 0, true) }
                Btn { text: qsTr("Seç"); icon: "select"; onClicked: tl.startSelect(-1) }
            }
        }
    }

    // ---- Liste / albüm sonuclari ----
    ListView {
        id: list
        visible: page.kind !== "track" && page.query !== ""
        anchors { left: parent.left; right: parent.right; top: topBar.bottom; bottom: parent.bottom }
        clip: true
        model: lm
        delegate: ListRow {
            lKey: model.listKey; lName: model.name; lSinger: model.singer; lImage: model.image
            isCurrent: ListView.isCurrentItem && list.activeFocus
            onClicked: { list.currentIndex = index; app.openList(page.item(index)); }
            onPressAndHold: app.listMenu(page.item(index))
            onMoreClicked: app.listMenu(page.item(index))
        }
        Keys.onReturnPressed: app.openList(page.item(currentIndex))
        Keys.onEnterPressed: app.openList(page.item(currentIndex))
        Keys.onSelectPressed: app.openList(page.item(currentIndex))
        Keys.onUpPressed: { if (currentIndex <= 0) field.focusInput(); else decrementCurrentIndex(); event.accepted = true; }
    }

    // ---- Son aramalar (sorgu yokken) ----
    Item {
        visible: page.query === ""
        anchors { left: parent.left; right: parent.right; top: topBar.bottom; bottom: parent.bottom }
        Text {
            id: hTitle
            visible: hm.count > 0
            anchors { left: parent.left; leftMargin: 18; top: parent.top; topMargin: 14 }
            text: qsTr("Son aramalar"); color: app.textSecondary; font.pixelSize: 16
        }
        Text {
            visible: hm.count > 0
            anchors { right: parent.right; rightMargin: 18; verticalCenter: hTitle.verticalCenter }
            text: qsTr("Temizle"); color: app.accent; font.pixelSize: 16
            MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: { app.clearSearches(); page.reloadHistory(); } }
        }
        Flow {
            anchors { left: parent.left; leftMargin: 14; right: parent.right; rightMargin: 14; top: hTitle.bottom; topMargin: 12 }
            spacing: 8
            Repeater { model: hm; Chip { text: model.q; onClicked: page.search(model.q) } }
        }
        Text {
            visible: hm.count === 0
            anchors.centerIn: parent
            width: parent.width - 80
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: qsTr("Aramak istediğinizi yazıp Enter'a basın.\nSonuçlarda uzun basarak birden çok şarkı seçebilirsiniz.")
            color: app.textSecondary; font.pixelSize: 18
        }
    }

    Text {
        anchors { horizontalCenter: parent.horizontalCenter; top: topBar.bottom; topMargin: 80 }
        visible: page.query !== "" && (page.loading || page.error !== "") && (page.kind === "track" ? tl.model.count === 0 : lm.count === 0)
        text: page.loading ? qsTr("Aranıyor...") : page.error
        color: app.textSecondary; font.pixelSize: 18
    }

    Keys.onLeftPressed: { app.stepTab(-1); event.accepted = true; }
    Keys.onRightPressed: { app.stepTab(1); event.accepted = true; }
}
