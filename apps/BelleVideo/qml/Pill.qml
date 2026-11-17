import QtQuick 1.1

// Yuvarlak kenarli kucuk dugme
Rectangle {
    id: root
    property string label: ""
    property string icon: ""
    property bool accent: false
    property bool selected: false        // klavye ile secili
    signal clicked

    width: row.width + 30
    height: 40
    radius: 20
    color: accent ? (ma.pressed ? app.brandPressed : app.brand) : (ma.pressed ? app.pressed : app.fieldBg)
    border.width: selected ? 2 : 0
    border.color: accent ? "#FFFFFF" : app.brand
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Image {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: 22; height: 22; smooth: true
            source: root.icon === "" ? "" : "../images/" + root.icon + "_" + (root.accent ? "w" : "a") + ".png"
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.accent ? "#101418" : app.textPrimary
            font.pixelSize: 16
            font.bold: root.accent
        }
    }
    MouseArea { id: ma; anchors.fill: parent; onClicked: root.clicked() }
}
