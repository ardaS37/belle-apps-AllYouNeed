import QtQuick 1.1

// Kanal veya oynatma listesi sayfasi
Rectangle {
    id: root
    color: app.bg
    property string mode: "channel"      // "channel" | "playlist"
    property string itemId: ""
    property string title: ""
    property string subtitle: ""
    property string thumb: ""
    property string next: ""
    property bool busy: false
    property string error: ""
    property bool subscribed: false
    property bool subKnown: false
    property bool subBusy: false

    function toggleSub() {
        if (subBusy || !subKnown) return;
        subBusy = true;
        var want = !subscribed;
        subscribed = want;      // hemen goster, hata olursa geri alinir
        app.setSubscribed(itemId, title, thumb, want, function (now) { subBusy = false; root.subscribed = now; });
    }

    function reset(m, id, t) {
        mode = m; itemId = id; title = t ? t : ""; subtitle = ""; thumb = ""; next = ""; error = "";
        subscribed = false; subKnown = false; subBusy = false;
        model.clear();
        list.positionViewAtIndex(0, ListView.Beginning);
    }

    function openChannel(cid, t) { reset("channel", cid, t); load(""); }

    function load(token) {
        if (busy) return;
        busy = true;
        var ok = function (d) {
            busy = false;
            if (d.channel) {
                if (d.channel.title) root.title = d.channel.title;
                if (d.channel.subscribers) root.subtitle = d.channel.subscribers;
                if (d.channel.thumb) root.thumb = d.channel.thumb;
                if (d.channel.subscribed !== undefined) { root.subscribed = !!d.channel.subscribed; root.subKnown = true; }
            }
            root.next = d.next ? d.next : "";
            var items = d.items || [];
            for (var i = 0; i < items.length; i++) {
                var v = items[i];
                model.append({ vid: v.id, title: v.title, channel: v.channel || "", channelId: v.channelId || "",
                               length: v.length || "", meta: [v.published, v.views].filter(function (x) { return x; }).join(" • ") });
            }
        };
        var fail = function (msg) { busy = false; error = msg; app.showToast(msg); };
        app.api().channel(itemId, token, ok, fail);
    }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        showBack: true
        title: root.title
        subtitle: root.mode === "playlist" ? qsTr("Oynatma listesi") : root.subtitle
        busy: root.busy
        onBack: app.closeBrowse()
    }

    ListModel { id: model }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        clip: true
        model: model
        header: Item {
            width: list.width
            height: root.mode === "channel" && (root.thumb !== "" || root.subKnown) ? 96 : 0
            visible: height > 0
            Rectangle {
                id: big
                anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                width: 72; height: 72; radius: 36
                color: app.pressed
                clip: true
                Image { anchors.fill: parent; smooth: true; asynchronous: true; source: app.imgUrl(root.thumb) }
            }
            Column {
                anchors { left: big.right; leftMargin: 16; right: subBtn.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                Text { width: parent.width; text: root.title; textFormat: Text.PlainText; color: app.textPrimary; font.pixelSize: 23; font.bold: true; elide: Text.ElideRight }
                Text { width: parent.width; text: root.subtitle; color: app.textSecondary; font.pixelSize: 17; visible: root.subtitle !== "" }
            }
            // Abone ol / Abonesin
            Rectangle {
                id: subBtn
                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                visible: root.subKnown
                width: visible ? subText.paintedWidth + 36 : 0; height: 48; radius: 24
                color: root.subscribed ? (subMa.pressed ? app.pressed : app.fieldBg) : (subMa.pressed ? app.brandPressed : app.brand)
                opacity: root.subBusy ? 0.6 : 1
                Text {
                    id: subText
                    anchors.centerIn: parent
                    text: root.subscribed ? qsTr("Abonesin") : qsTr("Abone ol")
                    color: root.subscribed ? app.textPrimary : "#FFFFFF"
                    font.pixelSize: 18; font.bold: true
                }
                MouseArea { id: subMa; anchors.fill: parent; onClicked: root.toggleSub() }
            }
        }
        delegate: VideoRow {
            width: list.width
            vid: model.vid
            title: model.title
            channel: root.mode === "channel" ? "" : model.channel
            meta: model.meta
            length: model.length
            onClicked: app.openVideo({ id: model.vid, title: model.title, channel: model.channel || root.title, channelId: model.channelId, length: model.length })
            onPressAndHold: if (root.mode === "playlist") app.openChannel(model.channelId, model.channel)
        }
        footer: Item {
            width: list.width
            height: root.next !== "" ? 80 : 0
            visible: root.next !== ""
            Rectangle {
                anchors.centerIn: parent
                width: 230; height: 50; radius: 25
                color: moreMa.pressed ? app.pressed : app.pill
                Text { anchors.centerIn: parent; text: root.busy ? qsTr("Yükleniyor...") : qsTr("Daha fazla"); color: app.accentText; font.pixelSize: 20; font.bold: true }
                MouseArea { id: moreMa; anchors.fill: parent; onClicked: root.load(root.next) }
            }
        }
    }

    Text {
        anchors.centerIn: list
        width: parent.width - 80
        visible: model.count === 0 && !root.busy
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: root.error !== "" ? root.error : qsTr("Video yok.")
        color: app.textSecondary
        font.pixelSize: 19
    }
}
