import QtQuick 1.1

// Akis: abone olunan kanallarin son videolari (yeniden eskiye)
Rectangle {
    id: root
    color: app.bg
    property bool busy: false
    property bool loaded: false
    property int page: 0
    property bool more: false
    property string error: ""

    function activate() {
        if (!loaded && !busy) load(false);
    }

    function load(refresh) {
        if (busy) return;
        busy = true;
        error = "";
        page = 0;
        app.api().feed(0, refresh, function (d) {
            busy = false;
            loaded = true;
            model.clear();
            append(d);
            list.positionViewAtIndex(0, ListView.Beginning);
        }, fail);
    }

    function loadMore() {
        if (busy || !more) return;
        busy = true;
        app.api().feed(page + 1, false, function (d) { busy = false; page++; append(d); }, fail);
    }

    function fail(msg, status, login) {
        busy = false;
        error = msg;
        app.showToast(msg);
    }

    function append(d) {
        more = !!d.more;
        var items = d.items || [];
        for (var i = 0; i < items.length; i++) {
            var v = items[i];
            model.append({ vid: v.id, title: v.title, channel: v.channel, channelId: v.channelId || "",
                           length: v.length || "", meta: [v.published, v.views].filter(function (x) { return x; }).join(" • ") });
        }
    }

    // Abonelik eklenip cikarilinca akis yeniden olusturulur
    Connections {
        target: app
        onSubsVersionChanged: { root.loaded = false; if (app.tab === 0) root.load(false); }
    }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: qsTr("Akış")
        subtitle: qsTr("Abone olduğunuz kanallar")
        busy: root.busy
        IconButton {
            source: "../images/reload" + app.iconTone + ".png"
            iconSize: 30
            onClicked: root.load(true)
        }
    }

    ListModel { id: model }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        clip: true
        model: model
        delegate: VideoRow {
            width: list.width
            vid: model.vid
            title: model.title
            channel: model.channel
            meta: model.meta
            length: model.length
            onClicked: app.openVideo({ id: model.vid, title: model.title, channel: model.channel, channelId: model.channelId, length: model.length })
            onPressAndHold: app.openChannel(model.channelId, model.channel)
        }
        footer: Item {
            width: list.width
            height: root.more ? 80 : 0
            visible: root.more
            Rectangle {
                anchors.centerIn: parent
                width: 230; height: 50; radius: 25
                color: moreMa.pressed ? app.pressed : app.pill
                Text { anchors.centerIn: parent; text: root.busy ? qsTr("Yükleniyor...") : qsTr("Daha fazla"); color: app.accentText; font.pixelSize: 20; font.bold: true }
                MouseArea { id: moreMa; anchors.fill: parent; onClicked: root.loadMore() }
            }
        }
    }

    Column {
        anchors.centerIn: list
        width: parent.width - 80
        spacing: 16
        visible: model.count === 0 && !root.busy && (root.loaded || root.error !== "")
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: root.error !== "" ? root.error
                : qsTr("Henüz abone olduğunuz kanal yok.\nAra sekmesinde bir kanal bulun ya da bir videodaki \"Kanal\" düğmesine basın, sonra \"Abone ol\"a dokunun. Kanalların yeni videoları burada görünür.")
            color: app.textSecondary
            font.pixelSize: 19
        }
        Rectangle {
            visible: root.error === ""
            anchors.horizontalCenter: parent.horizontalCenter
            width: findText.paintedWidth + 40; height: 52; radius: 26
            color: findMa.pressed ? app.brandPressed : app.brand
            Text { id: findText; anchors.centerIn: parent; text: qsTr("Kanal ara"); color: "#FFFFFF"; font.pixelSize: 19; font.bold: true }
            MouseArea { id: findMa; anchors.fill: parent; onClicked: app.selectTab(2) }
        }
    }
}
