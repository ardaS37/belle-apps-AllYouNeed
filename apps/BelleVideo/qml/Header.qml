import QtQuick 1.1

// Ince ust cubuk: baslik ve alt baslik yan yana; sag tarafa dugmeler verilir
Rectangle {
    id: root
    property string title: ""
    property string subtitle: ""
    property bool showBack: false
    property bool busy: false
    default property alias actions: actionRow.children
    signal back

    height: 54
    color: app.surface

    IconButton {
        id: backBtn
        visible: root.showBack
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        icon: "back"
        onClicked: root.back()
    }
    Text { id: measure; visible: false; text: root.title; font.pixelSize: 22; font.bold: true }
    Text {
        id: titleText
        anchors { left: root.showBack ? backBtn.right : parent.left; leftMargin: root.showBack ? 2 : 16; verticalCenter: parent.verticalCenter }
        width: Math.min(measure.paintedWidth + 2, (actionRow.x - x) * 0.62)
        text: root.title
        color: app.textPrimary
        font.pixelSize: 22
        font.bold: true
        elide: Text.ElideRight
    }
    Text {
        anchors { left: titleText.right; leftMargin: 10; right: actionRow.left; rightMargin: 8; baseline: titleText.baseline }
        visible: root.subtitle !== ""
        text: root.subtitle
        color: app.textSecondary
        font.pixelSize: 15
        elide: Text.ElideLeft
    }
    Row {
        id: actionRow
        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
    }
    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
    Item {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 3
        clip: true
        visible: root.busy
        Rectangle {
            id: bar
            width: parent.width / 3; height: parent.height
            color: app.brand
            SequentialAnimation on x {
                running: root.busy
                loops: Animation.Infinite
                NumberAnimation { from: -bar.width; to: root.width; duration: 1100; easing.type: Easing.InOutQuad }
            }
        }
    }
}
