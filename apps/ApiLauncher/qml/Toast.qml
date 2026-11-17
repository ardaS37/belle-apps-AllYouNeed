import QtQuick 1.1

// Kisa sure gorunen bildirim balonu
Rectangle {
    id: root
    property string message: ""

    function show(msg) {
        message = msg;
        opacity = 1;
        hideTimer.restart();
    }

    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 90 }
    width: Math.min(parent.width - 60, label.paintedWidth + 48)
    height: label.paintedHeight + 28
    radius: 14
    color: app.dark ? "#E9EDEF" : "#323739"
    opacity: 0
    visible: opacity > 0
    z: 100

    Behavior on opacity { NumberAnimation { duration: 200 } }

    Text {
        id: label
        anchors.centerIn: parent
        width: root.parent.width - 108
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: root.message
        color: app.dark ? "#111B21" : "#FFFFFF"
        font.pixelSize: 20
    }

    Timer {
        id: hideTimer
        interval: 3500
        onTriggered: root.opacity = 0
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.opacity = 0
    }
}
