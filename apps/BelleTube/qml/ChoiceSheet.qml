import QtQuick 1.1

// Videoya basinca acilan secenekler: izle / dinle / indir. Secim yapilmadan oynatici ve indirme baslamaz.
Item {
    id: root
    visible: app.sheetOpen
    property variant item: ({})
    property string vid: ""
    property string title: ""
    property string channel: ""
    property string channelId: ""
    property int stateTick: 0            // indirme durumu degisince metinler yenilensin

    function show(it) {
        item = it;
        vid = it.id;
        title = it.title ? it.title : "";
        channel = it.channel ? it.channel : "";
        channelId = it.channelId ? it.channelId : "";
        stateTick++;
        app.sheetOpen = true;
    }
    function close() { app.sheetOpen = false; }

    function localVideoKind() {
        var t = stateTick + app.dlVersion;   // bagimlilik
        if (tube.isComplete(vid, app.quality)) return app.quality;
        if (tube.isComplete(vid, "360")) return "360";
        if (tube.isComplete(vid, "480")) return "480";
        return "";
    }
    function dl(kind) { var t = stateTick + app.dlVersion + app.dlPercent; return app.dlState(vid, kind); }

    // Karartma: disina dokununca kapanir
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.55
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Rectangle {
        id: panel
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: col.height + 24
        color: app.surface
        MouseArea { anchors.fill: parent }   // panelin ici karartmaya tiklamasin

        Column {
            id: col
            x: 16; y: 14
            width: parent.width - 32
            spacing: 10

            Row {
                width: parent.width
                spacing: 12
                Rectangle {
                    width: 112; height: 63; color: app.pressed; clip: true
                    Image { anchors.fill: parent; asynchronous: true; smooth: true; fillMode: Image.PreserveAspectCrop; source: root.vid !== "" ? app.thumbUrl(root.vid) : "" }
                }
                Column {
                    width: parent.width - 124
                    anchors.verticalCenter: parent.verticalCenter
                    Text { width: parent.width; text: root.title; textFormat: Text.PlainText; color: app.textPrimary; font.pixelSize: 19; font.bold: true; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight }
                    Text { width: parent.width; text: root.channel; textFormat: Text.PlainText; color: app.textSecondary; font.pixelSize: 16; elide: Text.ElideRight }
                }
            }

            // 2 x 2 ana secenekler
            Grid {
                id: grid
                columns: 2
                spacing: 10
                width: parent.width
                property int bw: (width - spacing) / 2

                SheetButton {
                    width: grid.bw
                    primary: true
                    label: qsTr("Videoyu oynat")
                    sub: root.localVideoKind() !== "" ? qsTr("Telefondan") : qsTr("İnternetten izle")
                    onClicked: { root.close(); app.play(root.item, "video"); }
                }
                SheetButton {
                    width: grid.bw
                    primary: true
                    label: qsTr("Sadece sesi oynat")
                    sub: root.dl("audio") === "Telefonda" ? qsTr("Telefondan") : qsTr("Ekran kapalıyken de çalar")
                    onClicked: { root.close(); app.play(root.item, "audio"); }
                }
                SheetButton {
                    width: grid.bw
                    label: qsTr("Videoyu indir")
                    sub: root.dl(app.quality) !== "" ? root.dl(app.quality) : app.quality + qsTr("p, telefona kaydet")
                    dim: root.dl(app.quality) !== ""
                    onClicked: { app.download(root.item, app.quality); root.stateTick++; }
                }
                SheetButton {
                    width: grid.bw
                    label: qsTr("Sesi indir")
                    sub: root.dl("audio") !== "" ? root.dl("audio") : qsTr("mp3, telefona kaydet")
                    dim: root.dl("audio") !== ""
                    onClicked: { app.download(root.item, "audio"); root.stateTick++; }
                }
            }

            Row {
                spacing: 10
                SheetButton {
                    visible: root.channelId !== ""
                    width: visible ? 180 : 0
                    label: qsTr("Kanalı aç")
                    onClicked: { root.close(); app.openChannel(root.channelId, root.channel); }
                }
                SheetButton {
                    width: 150
                    label: qsTr("Vazgeç")
                    onClicked: root.close()
                }
            }
        }
    }
}
