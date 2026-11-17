import QtQuick 1.1

// Dairesel basma efektli ikon butonu
Item {
    id: root
    property alias source: icon.source
    property int iconSize: 36
    signal clicked

    width: 60
    height: 60

    Rectangle {
        anchors.centerIn: parent
        width: 52
        height: 52
        radius: 26
        color: app.dark ? "#FFFFFF" : "#000000"
        opacity: mouse.pressed ? 0.12 : 0
    }
    Image {
        id: icon
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        smooth: true
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
