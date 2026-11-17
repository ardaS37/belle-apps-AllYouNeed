import QtQuick 1.1

Rectangle {
    id: root
    function show(msg) { label.text = msg; opacity = 1; hide.restart(); }
    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 150 }
    width: Math.min(parent.width - 60, label.paintedWidth + 44)
    height: label.paintedHeight + 24
    radius: 18
    color: "#F0303038"
    opacity: 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 200 } }
    Text {
        id: label
        anchors.centerIn: parent
        width: root.parent.width - 104
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        color: "white"
        font.pixelSize: 18
    }
    Timer { id: hide; interval: 2600; onTriggered: root.opacity = 0 }
    MouseArea { anchors.fill: parent; onClicked: root.opacity = 0 }
}
