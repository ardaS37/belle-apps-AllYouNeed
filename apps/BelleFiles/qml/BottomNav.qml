import QtQuick 1.1

// Ince alt cubuk: simge ve ad yan yana. Sol/Sag tuslari sekme degistirir.
Rectangle {
    id: root
    property int current: 0
    signal selected(int index)

    height: 44
    color: app.surface

    Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: app.divider }

    ListModel {
        id: items
        ListElement { label: QT_TR_NOOP("Notlar"); icon: "home" }
        ListElement { label: QT_TR_NOOP("Dosyalar"); icon: "folder" }
        ListElement { label: QT_TR_NOOP("Drive"); icon: "drive" }
        ListElement { label: QT_TR_NOOP("Son"); icon: "clock" }
        ListElement { label: QT_TR_NOOP("Yedek"); icon: "backup" }
        ListElement { label: QT_TR_NOOP("Ayarlar"); icon: "gear" }
    }

    Row {
        anchors.fill: parent
        Repeater {
            model: items
            delegate: Item {
                width: root.width / 6
                height: root.height
                property bool active: index === root.current
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 6, content.width + 22)
                    height: 32; radius: 16
                    color: active ? app.pill : (ma.pressed ? app.pressed : "transparent")
                }
                Row {
                    id: content
                    anchors.centerIn: parent
                    spacing: 4
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22; smooth: true
                        source: "../images/" + icon + (active ? "_a" : "_g") + ".png"
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr(label)
                        color: active ? app.brand : app.textPrimary
                        font.pixelSize: 13
                        font.bold: active
                    }
                }
                MouseArea { id: ma; anchors.fill: parent; onClicked: root.selected(index) }
            }
        }
    }
}
