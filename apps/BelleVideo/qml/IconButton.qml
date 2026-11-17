import QtQuick 1.1

// Dairesel basma efektli ikon dugmesi. icon: "play" gibi ad; tone: "w" | "g" | "a"
Item {
    id: root
    property string icon: ""
    property string tone: "w"
    property int iconSize: 30
    property bool active: false          // vurgulu (ac/kapa dugmeleri icin)
    signal clicked

    width: 52
    height: 52

    Rectangle {
        anchors.centerIn: parent
        width: 44; height: 44; radius: 22
        color: root.active ? app.pill : "#FFFFFF"
        opacity: root.active ? 1 : (mouse.pressed ? 0.14 : 0)
    }
    Image {
        anchors.centerIn: parent
        width: root.iconSize; height: root.iconSize
        smooth: true
        source: root.icon === "" ? "" : "../images/" + root.icon + "_" + (root.active ? "a" : root.tone) + ".png"
    }
    MouseArea { id: mouse; anchors.fill: parent; onClicked: root.clicked() }
}
