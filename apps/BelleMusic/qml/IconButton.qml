import QtQuick 1.1

// Simge dugmesi. icon: images/<icon>_<tone>.png  (tone: w beyaz, g gri, a turuncu)
Item {
    id: root
    property string icon: ""
    property string tone: "w"
    property int iconSize: 30
    property bool round: true
    signal clicked
    signal pressAndHold
    width: 56
    height: 56
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(root.width, root.height) - 4; height: width; radius: root.round ? width / 2 : 10
        color: ma.pressed ? app.pressed : "transparent"
    }
    Image {
        anchors.centerIn: parent
        width: root.iconSize; height: root.iconSize
        smooth: true
        source: root.icon !== "" ? "../images/" + root.icon + "_" + root.tone + ".png" : ""
        opacity: root.enabled ? 1 : 0.35
    }
    MouseArea { id: ma; anchors.fill: parent; onClicked: root.clicked(); onPressAndHold: root.pressAndHold() }
}
