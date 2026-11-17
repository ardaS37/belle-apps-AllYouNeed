import QtQuick 1.1

// Coklu secim cubugu: isaretli oge varken listenin altinda. Dar alanda (yarim ekran) yalniz simgeler.
Rectangle {
    id: root
    property int adet: 0
    signal kopyala
    signal kes
    signal arsiv
    signal sil
    signal tumu
    signal daha
    signal kapat

    height: adet > 0 ? 50 : 0
    visible: adet > 0
    color: app.pill
    clip: true
    property bool dar: width < 420

    Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: app.brand; opacity: 0.6 }

    Text {
        id: sayi
        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
        text: root.adet
        color: app.brand
        font.pixelSize: 20
        font.bold: true
    }
    Row {
        anchors { left: sayi.right; leftMargin: 4; right: parent.right; verticalCenter: parent.verticalCenter }
        Repeater {
            model: [
                { i: "copy", t: QT_TR_NOOP("Kopyala"), s: 0 },
                { i: "cut", t: QT_TR_NOOP("Kes"), s: 1 },
                { i: "zip", t: QT_TR_NOOP("Arşiv"), s: 2 },
                { i: "trash", t: QT_TR_NOOP("Sil"), s: 3 },
                { i: "mark", t: QT_TR_NOOP("Tümü"), s: 4 },
                { i: "more", t: QT_TR_NOOP("Diğer"), s: 5 },
                { i: "close", t: QT_TR_NOOP("Bitir"), s: 6 }
            ]
            delegate: Item {
                width: (root.width - sayi.width - 14) / 7
                height: 50
                Rectangle { anchors.fill: parent; anchors.margins: 3; radius: 8; color: "#FFFFFF"; opacity: ma.pressed ? 0.15 : 0 }
                Column {
                    anchors.centerIn: parent
                    spacing: 1
                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 22; height: 22; smooth: true
                        source: "../images/" + modelData.i + (modelData.s === 3 ? "_g" : "_w") + ".png"
                    }
                    Text {
                        visible: !root.dar
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr(modelData.t)
                        color: modelData.s === 3 ? app.danger : app.textPrimary
                        font.pixelSize: 11
                    }
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    onClicked: {
                        var s = modelData.s;
                        if (s === 0) root.kopyala(); else if (s === 1) root.kes(); else if (s === 2) root.arsiv();
                        else if (s === 3) root.sil(); else if (s === 4) root.tumu(); else if (s === 5) root.daha(); else root.kapat();
                    }
                }
            }
        }
    }
}
