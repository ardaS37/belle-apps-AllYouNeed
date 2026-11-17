import QtQuick 1.1

// Ust cubuk. Sag taraftaki butonlar icerik olarak verilir.
Rectangle {
    id: root
    property string title: ""
    property string subtitle: ""
    property bool showBack: false
    property bool brandTitle: false
    property string avatarName: ""
    property string avatarKey: avatarName
    property string avatarPeer: ""
    property bool busy: false
    default property alias actions: actionRow.children
    signal back
    signal titleClicked

    // Ince ust cubuk: baslik ve alt baslik (model/surum) yan yana, sohbete daha cok yer kalsin
    height: 48
    color: app.surface

    Row {
        id: leftRow
        anchors { left: parent.left; leftMargin: root.showBack ? 0 : 20; verticalCenter: parent.verticalCenter }
        spacing: 8

        IconButton {
            visible: root.showBack
            source: "../images/back" + app.iconTone + ".png"
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.back()
        }
        Avatar {
            visible: root.avatarName !== ""
            name: root.avatarName
            key: root.avatarKey
            peer: root.avatarPeer
            size: 36
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Item {
        id: titleCol
        anchors {
            left: leftRow.right; leftMargin: root.avatarName !== "" ? 12 : (root.showBack ? 4 : 0)
            right: actionRow.left; rightMargin: 8
            top: parent.top; bottom: parent.bottom
        }
        Text {
            id: titleText
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: Math.min(paintedWidth, parent.width * 0.6)
            text: root.title
            color: root.brandTitle ? app.brand : app.textPrimary
            font.pixelSize: root.brandTitle ? 24 : 22
            font.bold: true
            elide: Text.ElideRight
        }
        Text {
            anchors { left: titleText.right; leftMargin: 10; right: parent.right; baseline: titleText.baseline }
            visible: root.subtitle !== ""
            text: root.subtitle
            color: app.textSecondary
            font.pixelSize: 16
            elide: Text.ElideRight
        }
    }
    MouseArea {
        anchors.fill: titleCol
        onClicked: root.titleClicked()
    }

    Row {
        id: actionRow
        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
        spacing: 0
        height: 48
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: app.divider
    }
    Item {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 3
        clip: true
        visible: root.busy
        Rectangle {
            id: bar
            width: parent.width / 3
            height: parent.height
            color: app.brand
            SequentialAnimation on x {
                running: root.busy
                loops: Animation.Infinite
                NumberAnimation { from: -bar.width; to: root.width; duration: 1100; easing.type: Easing.InOutQuad }
            }
        }
    }
}
