import QtQuick 1.1

// Dairesel basma efektli ikon butonu
Item {
    id: root
    property alias source: icon.source
    property int iconSize: 36
    signal clicked

    width: 56
    height: 48

    Rectangle {
        anchors.centerIn: parent
        width: 44
        height: 44
        radius: 22
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
