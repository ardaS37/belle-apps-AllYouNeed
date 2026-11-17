import QtQuick 1.1

// Ince alt cubuk: simge ve ad yan yana
Rectangle {
    id: root
    property int current: 0
    signal selected(int index)

    height: 46
    color: app.surface

    Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: app.divider }

    ListModel {
        id: items
        ListElement { label: QT_TR_NOOP("Videolar"); icon: "film" }
        ListElement { label: QT_TR_NOOP("Klasörler"); icon: "folder" }
        ListElement { label: QT_TR_NOOP("Liste"); icon: "queue" }
        ListElement { label: QT_TR_NOOP("Akış"); icon: "globe" }
        ListElement { label: QT_TR_NOOP("Ayarlar"); icon: "gear" }
    }

    Row {
        anchors.fill: parent
        Repeater {
            model: items
            delegate: Item {
                width: root.width / 5
                height: root.height
                property bool active: index === root.current
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 6, content.width + 20)
                    height: 34; radius: 17
                    color: active ? app.pill : (ma.pressed ? app.pressed : "transparent")
                }
                Row {
                    id: content
                    anchors.centerIn: parent
                    spacing: 6
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22; smooth: true
                        source: "../images/" + icon + (active ? "_a" : "_g") + ".png"
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr(label)
                        color: active ? app.brand : app.textPrimary
                        font.pixelSize: 15
                        font.bold: active
                    }
                }
                MouseArea { id: ma; anchors.fill: parent; onClicked: root.selected(index) }
            }
        }
    }
}
