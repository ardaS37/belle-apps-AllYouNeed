import QtQuick 1.1

// Ince alt cubuk: simge ve ad yan yana
Rectangle {
    id: root
    property int current: 0
    signal selected(int index)
    height: 42
    color: app.surface
    Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: app.divider }
    Row {
        anchors.fill: parent
        Repeater {
            model: [[qsTr("Keşfet"), "discover"], [qsTr("Ara"), "search"], [qsTr("Kitaplık"), "library"], [qsTr("Ayarlar"), "gear"]]
            Item {
                width: root.width / 4
                height: root.height
                property bool sel: index === root.current
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 6, content.width + 22); height: 32; radius: 16
                    color: ma.pressed ? app.pressed : (sel ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                }
                Row {
                    id: content
                    anchors.centerIn: parent
                    spacing: 6
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24; height: 24; smooth: true
                        source: "../images/" + modelData[1] + (sel ? "_a" : "_g") + ".png"
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData[0]
                        color: sel ? app.accent : app.textSecondary
                        font.pixelSize: 15
                        font.bold: sel
                    }
                }
                MouseArea { id: ma; anchors.fill: parent; onClicked: root.selected(index) }
            }
        }
    }
}
