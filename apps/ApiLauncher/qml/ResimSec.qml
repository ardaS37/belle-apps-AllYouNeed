import QtQuick 1.1

// Telefondaki fotograflari (E:/Images, kamera, C:/Data/Images) kucuk resimlerle gosterir.
// Yon tuslari ile gezilir, orta tus / Enter secer, geri / Esc kapatir. Dokunarak da secilir.
Rectangle {
    id: root
    color: app.bg
    visible: false
    signal secildi(string yol)
    signal kapandi()

    property variant liste: []

    function ac() {
        liste = yardim.resimler();
        visible = true;
        grid.currentIndex = 0;
        grid.forceActiveFocus();
        if (liste.length === 0) app.showToast(qsTr("Telefonda fotoğraf bulunamadı (E:/Images, C:/Data/Images)"));
    }
    function kapat() { visible = false; kapandi(); }
    function sec(i) {
        if (i < 0 || i >= liste.length) return;
        var y = liste[i].yol;
        visible = false;
        secildi(y);
    }

    Rectangle {
        id: ust
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 52
        color: app.surface
        Text {
            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
            text: qsTr("Fotoğraf seç  •  ") + root.liste.length + qsTr(" resim")
            color: app.textPrimary; font.pixelSize: 20; font.bold: true
        }
        Text {
            anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
            text: qsTr("Kapat")
            color: app.accentText; font.pixelSize: 18
            MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: root.kapat() }
        }
    }

    GridView {
        id: grid
        anchors { left: parent.left; right: parent.right; top: ust.bottom; bottom: alt.top; margins: 6 }
        clip: true
        cellWidth: Math.floor(width / 5)
        cellHeight: cellWidth
        cacheBuffer: 0
        model: root.liste.length
        delegate: Item {
            width: grid.cellWidth; height: grid.cellHeight
            Rectangle {
                anchors { fill: parent; margins: 3 }
                color: app.surface
                border.width: GridView.isCurrentItem && grid.activeFocus ? 3 : 0
                border.color: app.brand
                Image {
                    anchors { fill: parent; margins: 3 }
                    fillMode: Image.PreserveAspectCrop
                    clip: true
                    asynchronous: true
                    sourceSize.width: 140
                    source: root.liste[index] ? root.liste[index].url : ""
                }
            }
            MouseArea { anchors.fill: parent; onClicked: root.sec(index) }
        }
        Keys.onPressed: {
            var k = event.key;
            if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) { root.sec(currentIndex); event.accepted = true; }
            else if (k === Qt.Key_Escape || k === Qt.Key_Backspace || k === Qt.Key_Context2) { root.kapat(); event.accepted = true; }
        }
    }

    Rectangle {
        id: alt
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 34
        color: app.surface
        Text {
            anchors.centerIn: parent
            text: grid.currentIndex >= 0 && root.liste[grid.currentIndex] ? root.liste[grid.currentIndex].ad + "  •  " + root.liste[grid.currentIndex].tarih : ""
            color: app.textSecondary; font.pixelSize: 14
        }
    }
}
