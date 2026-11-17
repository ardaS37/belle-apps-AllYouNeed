import QtQuick 1.1

// Kisa sure gorunen bildirim
Rectangle {
    id: root
    property string message: ""
    function show(msg) { message = msg; opacity = 1; hideTimer.restart(); }

    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 30 }
    width: Math.min(parent.width - 60, label.paintedWidth + 40)
    height: label.paintedHeight + 24
    radius: 10
    color: "#323639"
    opacity: 0
    visible: opacity > 0
    z: 200
    Behavior on opacity { NumberAnimation { duration: 200 } }

    Text {
        id: label
        anchors.centerIn: parent
        width: root.parent.width - 100
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: root.message
        color: "#ffffff"
        font.pixelSize: 19
    }
    Timer { id: hideTimer; interval: 3500; onTriggered: root.opacity = 0 }
    MouseArea { anchors.fill: parent; onClicked: root.opacity = 0 }
}
