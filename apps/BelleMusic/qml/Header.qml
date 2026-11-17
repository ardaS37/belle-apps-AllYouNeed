import QtQuick 1.1

// Ince ust cubuk: geri dugmesi (istege bagli), baslik ve alt baslik YAN YANA, sagda dugmeler (cocuklar)
Rectangle {
    id: root
    property string title: ""
    property string subtitle: ""
    property bool showBack: false
    default property alias actions: actionRow.children
    signal back
    height: 46
    color: app.bg

    IconButton {
        id: backBtn
        visible: root.showBack
        anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
        icon: "back"; iconSize: 26
        onClicked: root.back()
    }
    Text { id: measure; visible: false; text: root.title; font.pixelSize: 22; font.bold: true }
    Text {
        id: titleText
        anchors { left: root.showBack ? backBtn.right : parent.left; leftMargin: root.showBack ? 2 : 16; verticalCenter: parent.verticalCenter }
        width: Math.min(measure.paintedWidth + 2, Math.max(60, (actionRow.x - x) * 0.6))
        text: root.title; color: app.textPrimary; font.pixelSize: 22; font.bold: true; elide: Text.ElideRight
    }
    Text {
        anchors { left: titleText.right; leftMargin: 10; right: actionRow.left; rightMargin: 6; baseline: titleText.baseline }
        visible: root.subtitle !== ""
        text: root.subtitle; color: app.textSecondary; font.pixelSize: 15; elide: Text.ElideRight
    }
    Row {
        id: actionRow
        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
        spacing: 0
    }
    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
}
