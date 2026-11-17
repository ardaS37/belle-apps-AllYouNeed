import QtQuick 1.1

// Metinli dugme. primary: dolu mavi, aksi halde cerceveli
Rectangle {
    id: root
    property alias text: label.text
    property bool primary: false
    property bool danger: false
    property bool flat: false
    property int fontSize: 20
    signal clicked

    width: Math.max(label.paintedWidth + 28, 56)
    height: 44
    radius: 6
    color: mouse.pressed ? (primary ? "#1558b0" : "#e3e8ef") : (primary ? app.brand : (flat ? "transparent" : "#ffffff"))
    border.width: primary || flat ? 0 : 1
    border.color: "#c4c7c5"
    opacity: enabled ? 1 : 0.45

    Text {
        id: label
        anchors.centerIn: parent
        color: root.primary ? "#ffffff" : (root.danger ? "#c5221f" : (root.flat ? app.textPrimary : app.brand))
        font.pixelSize: root.fontSize
        font.bold: root.primary || root.flat
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
