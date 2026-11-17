import QtQuick 1.1

// Koyu temaya uygun metinli dugme
Rectangle {
    id: root
    property alias text: label.text
    property bool primary: false
    property bool danger: false
    signal clicked
    width: Math.max(label.paintedWidth + 30, 64)
    height: 46
    radius: 8
    color: ma.pressed ? app.pressed : (primary ? app.brand : app.fieldBg)
    Text {
        id: label
        anchors.centerIn: parent
        color: root.primary ? "#0C1013" : (root.danger ? app.danger : app.textPrimary)
        font.pixelSize: 18
        font.bold: root.primary
    }
    MouseArea { id: ma; anchors.fill: parent; onClicked: root.clicked() }
}
