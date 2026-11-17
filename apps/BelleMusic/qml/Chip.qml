import QtQuick 1.1

// Secilebilir kucuk etiket
Rectangle {
    id: root
    property string text: ""
    property bool selected: false
    signal clicked
    height: 40
    width: label.paintedWidth + 32
    radius: 20
    color: selected ? app.accent : (ma.pressed ? app.pressed : app.surface2)
    Text { id: label; anchors.centerIn: parent; text: root.text; color: root.selected ? app.onAccent : app.textPrimary; font.pixelSize: 17; font.bold: root.selected }
    MouseArea { id: ma; anchors.fill: parent; onClicked: root.clicked() }
}
