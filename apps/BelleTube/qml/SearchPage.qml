import QtQuick 1.1

Rectangle {
    id: root
    color: app.bg
    property bool busy: false
    property string query: ""
    property string continuation: ""
    property string lastError: ""

    function doSearch() {
        var q = field.text.replace(/^\s+|\s+$/g, "");
        if (q === "" || busy) return;
        query = q;
        continuation = "";
        lastError = "";
        busy = true;
        resultModel.clear();
        app.apiSearch(q, "", function (d) {
            busy = false;
            append(d);
            list.positionViewAtIndex(0, ListView.Beginning);
        }, function (msg) { busy = false; lastError = msg; app.showToast(msg); });
    }

    function more() {
        if (busy || continuation === "") return;
        busy = true;
        app.apiSearch(query, continuation, function (d) { busy = false; append(d); },
                      function (msg) { busy = false; app.showToast(msg); });
    }

    function append(d) {
        continuation = d.continuation ? d.continuation : "";
        // Kanal sonuclari en ustte (kanal sayfasindan abone olunabilir)
        var chans = d.channels ? d.channels : [];
        for (var c = 0; c < chans.length; c++) {
            var ch = chans[c];
            resultModel.append({ isChannel: true, vid: "", cid: ch.id, title: ch.title, channel: "", length: "",
                                 thumb: ch.thumb || "", meta: ch.subscribers || qsTr("Kanal") });
        }
        var items = d.items ? d.items : [];
        for (var i = 0; i < items.length; i++) {
            var v = items[i];
            resultModel.append({ isChannel: false, vid: v.id, cid: v.channelId || "", title: v.title, channel: v.channel, length: v.length,
                                 thumb: "", meta: [v.views, v.published].filter(function (x) { return x; }).join(" • ") });
        }
    }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: "BelleTube"
        brandTitle: true
        busy: root.busy
    }

    Item {
        id: bar
        anchors { left: parent.left; right: parent.right; top: header.bottom }
        height: 72
        TextField {
            id: field
            anchors { left: parent.left; leftMargin: 14; right: goBtn.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
            placeholder: qsTr("YouTube'da ara")
            onAccepted: root.doSearch()
        }
        Rectangle {
            id: goBtn
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            width: 56; height: 56; radius: 28
            color: goMa.pressed ? app.brandPressed : app.brand
            Image { anchors.centerIn: parent; width: 30; height: 30; smooth: true; source: "../images/search_light.png" }
            MouseArea { id: goMa; anchors.fill: parent; onClicked: root.doSearch() }
        }
    }

    ListModel { id: resultModel }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: bar.bottom; bottom: parent.bottom }
        clip: true
        model: resultModel
        delegate: Item {
            width: list.width
            height: model.isChannel ? 84 : 104
            // Kanal satiri
            Item {
                anchors.fill: parent
                visible: model.isChannel
                Rectangle { anchors.fill: parent; color: cma.pressed ? app.pressed : "transparent" }
                Rectangle {
                    id: cav
                    anchors { left: parent.left; leftMargin: 62; verticalCenter: parent.verticalCenter }
                    width: 64; height: 64; radius: 32
                    color: app.pressed
                    clip: true
                    Image { anchors.fill: parent; asynchronous: true; smooth: true; source: model.isChannel ? app.imgUrl(model.thumb) : "" }
                }
                Column {
                    anchors { left: cav.right; leftMargin: 62; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    Text { width: parent.width; text: model.title; textFormat: Text.PlainText; color: app.textPrimary; font.pixelSize: 21; font.bold: true; elide: Text.ElideRight }
                    Text { width: parent.width; text: model.meta + qsTr("  •  Kanalı aç"); color: app.textSecondary; font.pixelSize: 16; elide: Text.ElideRight }
                }
                Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
                MouseArea { id: cma; anchors.fill: parent; enabled: model.isChannel; onClicked: app.openChannel(model.cid, model.title) }
            }
            VideoRow {
                anchors.fill: parent
                visible: !model.isChannel
                vid: model.isChannel ? "" : model.vid
                title: model.title
                channel: model.channel
                meta: model.meta
                length: model.length
                onClicked: app.openVideo({ id: model.vid, title: model.title, channel: model.channel, channelId: model.cid, length: model.length })
                onPressAndHold: app.openChannel(model.cid, model.channel)
            }
        }
        footer: Item {
            width: list.width
            height: root.continuation !== "" ? 80 : 0
            visible: height > 0
            Rectangle {
                anchors.centerIn: parent
                width: 230; height: 50; radius: 25
                color: moreMa.pressed ? app.pressed : app.pill
                Text { anchors.centerIn: parent; text: root.busy ? qsTr("Yükleniyor...") : qsTr("Daha fazla"); color: app.accentText; font.pixelSize: 20; font.bold: true }
                MouseArea { id: moreMa; anchors.fill: parent; onClicked: root.more() }
            }
        }
    }

    Text {
        anchors.centerIn: list
        width: parent.width - 80
        visible: resultModel.count === 0 && !root.busy
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: root.lastError !== "" ? root.lastError : qsTr("Video ya da kanal adı yazın.\nİzlediğiniz her video telefona iner; ileri-geri sarma internetsiz çalışır. Bir videoya basılı tutunca kanalı açılır.")
        color: app.textSecondary
        font.pixelSize: 19
    }
}
