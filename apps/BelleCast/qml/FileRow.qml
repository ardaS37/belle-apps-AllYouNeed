import QtQuick 1.1

// Liste satiri: simge, baslik, alt bilgi, isaret kutusu ve sag dugme.
// selected: klavye imleci bu satirda (liste odaktayken vurgulanir)
Item {
    id: root
    property string icon: "doc"
    property string title: ""
    property string sub: ""
    property bool selected: false
    property bool marked: false
    property bool cut: false              // kesilmek uzere (soluk)
    property bool fav: false
    property string actionIcon: "more"
    signal clicked
    signal pressAndHold
    signal action

    width: parent ? parent.width : 400
    height: Math.round(36 * app.yazi + 22)
    opacity: cut ? 0.5 : 1

    Rectangle {
        anchors.fill: parent
        color: ma.pressed ? app.pressed : (root.selected ? app.highlight : (root.marked ? app.markBg : "transparent"))
    }
    Rectangle {
        visible: root.selected
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: 4
        color: app.brand
    }
    Rectangle {
        id: badge
        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
        width: 40; height: 40; radius: 10
        color: root.marked ? app.pill : app.fieldBg
        Image {
            anchors.centerIn: parent
            width: 24; height: 24; smooth: true
            source: "../images/" + (root.marked ? "mark" : root.icon) + (root.marked || root.icon === "folder" ? "_a" : "_w") + ".png"
        }
    }
    Column {
        anchors { left: badge.right; leftMargin: 12; right: actBtn.visible ? actBtn.left : parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
        spacing: 2
        Row {
            width: parent.width
            spacing: 6
            Image {
                visible: root.fav
                anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 16; smooth: true
                source: "../images/star_a.png"
            }
            Text {
                width: parent.width - (root.fav ? 22 : 0)
                text: root.title
                textFormat: Text.PlainText
                color: root.marked ? app.brand : app.textPrimary
                font.pixelSize: Math.round(18 * app.yazi)
                elide: Text.ElideMiddle
            }
        }
        Text {
            width: parent.width
            visible: root.sub !== ""
            text: root.sub
            textFormat: Text.PlainText
            color: app.textSecondary
            font.pixelSize: Math.round(14 * app.yazi)
            elide: Text.ElideRight
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
        anchors { right: parent.right; rightMargin: 2; verticalCenter: parent.verticalCenter }
        icon: root.actionIcon
        tone: "g"
        iconSize: 24
        onClicked: root.action()
    }
    Rectangle { anchors { left: badge.right; leftMargin: 12; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
}
