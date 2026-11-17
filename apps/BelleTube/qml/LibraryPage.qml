import QtQuick 1.1

// Kitaplik: telefona inen videolar (internetsiz izlenebilir)
Rectangle {
    id: root
    color: app.bg
    property string totalText: ""

    function fmt(sec) {
        if (!sec) return "";
        var m = Math.floor(sec / 60), s = sec % 60, h = Math.floor(m / 60);
        if (h > 0) { m = m % 60; return h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s; }
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    function activate() { reloadDownloads(); }

    function reloadDownloads() {
        libModel.clear();
        var items = tube.library();
        for (var i = 0; i < items.length; i++) {
            var it = items[i];
            libModel.append({ vid: it.id, kind: it.kind, title: it.title, channel: it.channel,
                              seconds: it.seconds, sizeText: tube.sizeText(it.size) });
        }
        totalText = tube.sizeText(tube.totalBytes()) + " / " + app.limitGB + qsTr(" GB");
    }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: qsTr("Kitaplık")
        subtitle: libModel.count + qsTr(" video  •  ") + root.totalText
    }

    // Suren indirme (izlemeden bagimsiz)
    Rectangle {
        id: dlBar
        anchors { left: parent.left; right: parent.right; top: header.bottom }
        height: app.dlKey !== "" ? 64 : 0
        visible: height > 0
        color: app.surface
        Column {
            anchors { left: parent.left; leftMargin: 16; right: cancelBtn.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 4
            Text {
                width: parent.width
                text: qsTr("İniyor: ") + app.dlTitle
                textFormat: Text.PlainText
                color: app.textPrimary; font.pixelSize: 17; elide: Text.ElideRight
            }
            Rectangle {
                width: parent.width; height: 5; radius: 2; color: app.divider
                Rectangle { height: parent.height; radius: 2; color: app.brand; width: parent.width * app.dlPercent / 100 }
            }
            Text {
                text: "%" + app.dlPercent + "  •  " + app.dlSpeed + qsTr(" KB/sn") + (app.dlQueue.length > 0 ? qsTr("  •  sırada ") + app.dlQueue.length : "")
                color: app.textSecondary; font.pixelSize: 14
            }
        }
        Pill {
            id: cancelBtn
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            label: qsTr("İptal")
            onClicked: app.cancelDownload()
        }
    }

    ListModel { id: libModel }
    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: dlBar.bottom; bottom: parent.bottom }
        clip: true
        model: libModel
        delegate: Item {
            width: list.width
            height: 104
            VideoRow {
                anchors { left: parent.left; right: delBtn.left; top: parent.top; bottom: parent.bottom }
                vid: model.vid
                title: model.title
                channel: model.channel
                meta: model.sizeText
                length: root.fmt(model.seconds)
                badge: model.kind === "audio" ? qsTr("Ses") : model.kind + "p"
                onClicked: app.play({ id: model.vid, title: model.title, channel: model.channel, seconds: model.seconds }, model.kind === "audio" ? "audio" : "video")
            }
            IconButton {
                id: delBtn
                anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                source: "../images/trash" + app.iconTone + ".png"
                onClicked: { tube.removeItem(model.vid, model.kind); root.reloadDownloads(); app.showToast(qsTr("Silindi")); }
            }
        }
    }

    Text {
        anchors.centerIn: list
        width: parent.width - 80
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        color: app.textSecondary
        font.pixelSize: 19
        visible: libModel.count === 0
        text: qsTr("Henüz inen video yok. İzlediğiniz videolar burada saklanır; internetsiz izlenebilir.")
    }
}
