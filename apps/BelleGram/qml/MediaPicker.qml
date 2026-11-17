import QtQuick 1.1

// Telefondaki fotograf / video / ses dosyalarindan secim
Rectangle {
    id: root
    property string kind: "image"      // image | video | audio
    property string selected: ""
    signal picked(string path)
    signal closed

    color: app.bg
    visible: false

    function open(k) {
        kind = k;
        selected = "";
        fileModel.clear();
        empty.text = qsTr("Telefon taranıyor...");
        empty.visible = true;
        visible = true;
        loadTimer.start();     // once ekran acilsin, sonra dosyalar taransin
    }
    function close() { visible = false; fileModel.clear(); closed(); }

    Timer {
        id: loadTimer
        interval: 150
        onTriggered: {
            var files = cihaz.dosyalar(root.kind, root.kind === "image" ? 40 : 60);
            for (var i = 0; i < files.length; i++) fileModel.append({ path: files[i] });
            empty.text = qsTr("Telefonda dosya bulunamadı.");
            empty.visible = files.length === 0;
        }
    }

    MouseArea { anchors.fill: parent }   // alttaki ekrana dokunmayi engelle

    ListModel { id: fileModel }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        showBack: true
        title: root.kind === "image" ? qsTr("Fotoğraf seç") : (root.kind === "video" ? qsTr("Video seç") : (root.kind === "audio" ? qsTr("Ses dosyası seç") : qsTr("Dosya seç")))
        subtitle: qsTr("Gönderilecek kişi: ") + app.acikAd
        onBack: root.close()
    }

    GridView {
        id: grid
        visible: root.kind === "image"
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: bar.top; leftMargin: 4 }
        cellWidth: Math.floor((root.width - 8) / 4)
        cellHeight: cellWidth
        clip: true
        model: root.kind === "image" ? fileModel : null
        delegate: Item {
            width: grid.cellWidth
            height: grid.cellHeight
            Rectangle {
                anchors { fill: parent; margins: 3 }
                color: app.pressed
                clip: true
                Image {
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: false
                    sourceSize.width: 160
                    source: cihaz.url(path)
                }
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: root.selected === path ? 5 : 0
                    border.color: app.brand
                }
                Rectangle {
                    visible: root.selected === path
                    anchors { right: parent.right; top: parent.top; margins: 8 }
                    width: 30; height: 30; radius: 15
                    color: app.brand
                    border.width: 3
                    border.color: "#FFFFFF"
                }
            }
            MouseArea { anchors.fill: parent; onClicked: root.selected = path }
        }
    }

    ListView {
        id: list
        visible: root.kind !== "image"
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: bar.top }
        clip: true
        model: root.kind !== "image" ? fileModel : null
        delegate: Item {
            width: list.width
            height: 80
            Rectangle { anchors.fill: parent; color: root.selected === path ? app.chip : (rowMa.pressed ? app.pressed : app.bg) }
            Rectangle {
                id: ic
                anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                width: 54; height: 54; radius: 27
                color: root.kind === "video" ? "#FF2E74" : (root.kind === "audio" ? "#FF7F21" : "#5288C1")
                Image { anchors.centerIn: parent; width: 30; height: 30; smooth: true; source: root.kind === "video" ? "../images/video.png" : (root.kind === "audio" ? "../images/music.png" : "../images/file.png") }
            }
            Column {
                anchors { left: ic.right; leftMargin: 16; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                Text { width: parent.width; text: cihaz.dosyaAdi(path); color: app.textPrimary; font.pixelSize: 21; elide: Text.ElideMiddle }
                Text { width: parent.width; text: cihaz.boyutMetni(path); color: app.textSecondary; font.pixelSize: 17 }
            }
            Rectangle { anchors { left: ic.right; leftMargin: 16; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
            MouseArea { id: rowMa; anchors.fill: parent; onClicked: root.selected = path }
        }
    }

    Text {
        id: empty
        visible: false
        anchors.centerIn: parent
        width: parent.width - 80
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: ""
        color: app.textSecondary
        font.pixelSize: 18
    }

    Rectangle {
        id: bar
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 76
        color: app.surface
        Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: app.divider }
        Text {
            anchors { left: parent.left; leftMargin: 20; right: sendBtn.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
            text: root.selected === "" ? qsTr("Bir dosya seçin") : cihaz.dosyaAdi(root.selected) + "  (" + cihaz.boyutMetni(root.selected) + ")"
            color: root.selected === "" ? app.textSecondary : app.textPrimary
            font.pixelSize: 19
            elide: Text.ElideMiddle
        }
        Rectangle {
            id: sendBtn
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            width: 140
            height: 54
            radius: 27
            color: root.selected === "" ? app.pressed : (sMa.pressed ? app.brandPressed : app.brand)
            Text { anchors.centerIn: parent; text: qsTr("Gönder"); color: root.selected === "" ? app.textSecondary : "#FFFFFF"; font.pixelSize: 22; font.bold: true }
            MouseArea {
                id: sMa
                anchors.fill: parent
                enabled: root.selected !== ""
                onClicked: { var p = root.selected; root.close(); root.picked(p); }
            }
        }
    }
}
