import QtQuick 1.1

// Liste satiri: simge, baslik, alt bilgi, istege bagli ilerleme cubugu ve sag dugme.
// selected: klavye imleci bu satirda (liste odaktayken vurgulanir)
Item {
    id: root
    property string icon: "film"
    property string title: ""
    property string sub: ""
    property real progress: -1           // 0..1, <0 ise gizli
    property bool selected: false
    property bool playing: false         // su an oynatilan
    property string actionIcon: "more"
    signal clicked
    signal pressAndHold
    signal action

    width: parent ? parent.width : 400
    height: 62

    Rectangle {
        anchors.fill: parent
        color: ma.pressed ? app.pressed : (root.selected ? app.highlight : "transparent")
    }
    Rectangle {
        visible: root.selected
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: 4
        color: app.brand
    }
    Rectangle {
        id: badge
        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
        width: 42; height: 42; radius: 10
        color: root.playing ? app.pill : app.fieldBg
        Image {
            anchors.centerIn: parent
            width: 26; height: 26; smooth: true
            source: "../images/" + (root.playing ? "play" : root.icon) + (root.playing || root.icon === "folder" ? "_a" : "_w") + ".png"
        }
    }
    Column {
        anchors { left: badge.right; leftMargin: 12; right: actBtn.visible ? actBtn.left : parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
        spacing: 2
        Text {
            width: parent.width
            text: root.title
            textFormat: Text.PlainText
            color: root.playing ? app.brand : app.textPrimary
            font.pixelSize: 18
            font.bold: root.playing
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            visible: root.sub !== ""
            text: root.sub
            textFormat: Text.PlainText
            color: app.textSecondary
            font.pixelSize: 14
            elide: Text.ElideRight
        }
        Item {
            visible: root.progress >= 0
            width: parent.width; height: 6
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 3; radius: 1; color: app.divider }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * Math.max(0, Math.min(1, root.progress)); height: 3; radius: 1; color: app.brand }
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        onClicked: root.clicked()
        onPressAndHold: root.pressAndHold()
    }
    IconButton {
        id: actBtn
        visible: root.actionIcon !== ""
        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
        icon: root.actionIcon
        tone: "g"
        iconSize: 24
        onClicked: root.action()
    }
    Rectangle { anchors { left: badge.right; leftMargin: 12; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
}
