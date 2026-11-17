import QtQuick 1.1

// Kesfet: servis ve "Yeni / Populer" secimine gore calma listeleri (sayfa sayfa yuklenir)
Rectangle {
    id: page
    color: app.bg
    property string svc: app.service
    property string kind: "new"
    property int pageNo: 0
    property bool loading: false
    property bool more: true
    property string error: ""
    property int seq: 0

    function takeFocus() { list.forceActiveFocus(); }
    function reload() {
        lm.clear();
        pageNo = 0;
        more = true;
        error = "";
        loadMore();
    }
    function loadMore() {
        if (loading || !more) return;
        loading = true;
        var my = ++seq;
        var p = pageNo + 1;
        app.api().discover(svc, kind, p, function (items) {
            if (my !== seq) return;
            loading = false;
            pageNo = p;
            for (var i = 0; i < items.length; i++) {
                var l = app.api().toList(items[i], svc);
                lm.append(l);
            }
            if (items.length < 10) more = false;
            if (lm.count === 0) error = qsTr("Liste bulunamadı.");
        }, function (msg) {
            if (my !== seq) return;
            loading = false;
            more = false;
            if (lm.count === 0) error = msg;
        });
    }
    Component.onCompleted: reload()
    onSvcChanged: reload()
    onKindChanged: reload()

    function item(i) { var m = lm.get(i); return { listKey: m.listKey, name: m.name, singer: m.singer, image: m.image, service: m.service }; }

    ListModel { id: lm }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: qsTr("Keşfet")
        subtitle: app.api().serviceName(page.svc) + "  •  " + (page.kind === "new" ? qsTr("Yeni listeler") : qsTr("Popüler listeler"))
        IconButton { icon: "search"; onClicked: app.selectTab(1) }
    }
    Flickable {
        id: chipsFlick
        anchors { left: parent.left; right: parent.right; top: header.bottom }
        height: 58
        contentWidth: chips.width + 28
        clip: true
        Row {
            id: chips
            x: 14; anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Chip { text: qsTr("Yeni"); selected: page.kind === "new"; onClicked: page.kind = "new" }
            Chip { text: qsTr("Popüler"); selected: page.kind === "hot"; onClicked: page.kind = "hot" }
            Rectangle { width: 1; height: 28; color: app.divider; anchors.verticalCenter: parent.verticalCenter }
            Repeater {
                model: app.belleModu ? [] : app.api().SERVICES   // kendi sunucumuzda tek kaynak: servis secimi yok
                Chip { text: modelData.name; selected: page.svc === modelData.id; onClicked: page.svc = modelData.id }
            }
        }
    }
    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: chipsFlick.bottom; bottom: parent.bottom }
        clip: true
        model: lm
        cacheBuffer: 480
        delegate: ListRow {
            lKey: model.listKey; lName: model.name; lSinger: model.singer; lImage: model.image
            isCurrent: ListView.isCurrentItem && list.activeFocus
            onClicked: { list.currentIndex = index; app.openList(page.item(index)); }
            onPressAndHold: app.listMenu(page.item(index))
            onMoreClicked: app.listMenu(page.item(index))
        }
        footer: Item {
            width: list.width; height: 60
            Text { anchors.centerIn: parent; visible: page.loading && lm.count > 0; text: qsTr("Yükleniyor..."); color: app.textSecondary; font.pixelSize: 16 }
        }
        onAtYEndChanged: if (atYEnd && lm.count > 0) page.loadMore()
        onCurrentIndexChanged: if (currentIndex >= lm.count - 3) page.loadMore()
        Keys.onReturnPressed: app.openList(page.item(currentIndex))
        Keys.onEnterPressed: app.openList(page.item(currentIndex))
        Keys.onSelectPressed: app.openList(page.item(currentIndex))
    }
    Column {
        anchors.centerIn: list
        spacing: 14
        visible: lm.count === 0
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: page.loading ? qsTr("Yükleniyor...") : page.error; color: app.textSecondary; font.pixelSize: 18; width: page.width - 80; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap }
        Btn { visible: !page.loading && page.error !== ""; anchors.horizontalCenter: parent.horizontalCenter; text: qsTr("Yeniden dene"); onClicked: page.reload() }
    }

    // Klavye: sol/sag sekme degistirir
    Keys.onLeftPressed: { app.stepTab(-1); event.accepted = true; }
    Keys.onRightPressed: { app.stepTab(1); event.accepted = true; }
}
