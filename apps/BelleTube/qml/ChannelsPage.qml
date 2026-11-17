import QtQuick 1.1

// Kanallar: abonelikler (alfabetik). Uste yazinca suzulur (fiziksel klavye).
Rectangle {
    id: root
    color: app.bg
    property bool busy: false
    property bool loaded: false
    property bool needLogin: false
    property string error: ""
    property variant all: []

    function activate() {
        if (!loaded && !busy) load(false);
    }

    function load(refresh) {
        if (busy) return;
        busy = true;
        error = "";
        app.api().subs(refresh, function (d) {
            busy = false;
            loaded = true;
            all = d.items || [];
            applyFilter();
        }, function (msg, status, login) {
            busy = false;
            error = msg;
            app.showToast(msg);
        });
    }

    function applyFilter() {
        var q = filter.text.toLowerCase();
        model.clear();
        for (var i = 0; i < all.length; i++) {
            var c = all[i];
            if (q !== "" && c.title.toLowerCase().indexOf(q) < 0) continue;
            model.append({ cid: c.id, title: c.title, thumb: c.thumb || "" });
        }
    }

    Connections {
        target: app
        onSubsVersionChanged: { root.loaded = false; if (app.tab === 1) root.activate(); }
    }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: qsTr("Kanallar")
        subtitle: root.loaded ? root.all.length + qsTr(" abonelik") : ""
        busy: root.busy
        IconButton {
            source: "../images/reload" + app.iconTone + ".png"
            iconSize: 30
            onClicked: root.load(true)
        }
    }

    Item {
        id: bar
        anchors { left: parent.left; right: parent.right; top: header.bottom }
        height: root.needLogin ? 0 : 66
        visible: !root.needLogin
        TextField {
            id: filter
            anchors { left: parent.left; right: parent.right; margins: 14; verticalCenter: parent.verticalCenter }
            placeholder: qsTr("Kanal ara")
            onTextChanged: root.applyFilter()
        }
    }

    ListModel { id: model }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: bar.bottom; bottom: parent.bottom }
        clip: true
        model: model
        visible: !root.needLogin
        delegate: Item {
            width: list.width
            height: 72
            Rectangle { anchors.fill: parent; color: ma.pressed ? app.pressed : "transparent" }
            Rectangle {
                id: av
                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                width: 52; height: 52; radius: 26
                color: app.pressed
                clip: true
                Image { anchors.fill: parent; asynchronous: true; smooth: true; source: app.imgUrl(model.thumb) }
            }
            Text {
                anchors { left: av.right; leftMargin: 16; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                text: model.title
                textFormat: Text.PlainText
                color: app.textPrimary
                font.pixelSize: 20
                elide: Text.ElideRight
            }
            Rectangle { anchors { left: av.right; leftMargin: 16; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
            MouseArea { id: ma; anchors.fill: parent; onClicked: app.openChannel(model.cid, model.title) }
        }
    }

    Text {
        anchors.centerIn: list
        width: parent.width - 80
        visible: !root.needLogin && model.count === 0 && !root.busy && root.loaded
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: root.error !== "" ? root.error : (filter.text !== "" ? qsTr("Eşleşen kanal yok.")
              : qsTr("Abonelik yok.\nAra sekmesinden bir kanal bulup \"Abone ol\"a dokunun."))
        color: app.textSecondary
        font.pixelSize: 19
    }
}
