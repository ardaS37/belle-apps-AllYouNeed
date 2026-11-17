import QtQuick 1.1

// Yuvarlak kenarli kucuk dugme (oynatici sayfasindaki secenekler)
Rectangle {
    id: root
    property string label: ""
    property bool accent: false
    property bool dim: false
    signal clicked

    width: txt.paintedWidth + 28
    height: 42
    radius: 21
    color: accent ? (ma.pressed ? app.brandPressed : app.brand) : (ma.pressed ? app.pressed : app.fieldBg)
    opacity: dim ? 0.75 : 1
    Text {
        id: txt
        anchors.centerIn: parent
        text: root.label
        color: root.accent ? "#FFFFFF" : app.textPrimary
        font.pixelSize: 17
        font.bold: root.accent
    }
    MouseArea { id: ma; anchors.fill: parent; onClicked: root.clicked() }
}
