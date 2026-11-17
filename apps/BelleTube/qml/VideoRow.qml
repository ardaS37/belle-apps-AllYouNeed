import QtQuick 1.1

// Liste satiri: kucuk resim + baslik + kanal/izlenme
Item {
    id: root
    property string vid: ""
    property string title: ""
    property string channel: ""
    property string meta: ""
    property string length: ""
    property string badge: ""          // "360p", "Ses" gibi
    signal clicked
    signal pressAndHold

    height: 104

    Rectangle { anchors.fill: parent; color: ma.pressed ? app.pressed : "transparent" }

    Rectangle {
        id: thumbBox
        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
        width: 160; height: 90
        color: app.pressed
        clip: true
        Image {
            anchors.fill: parent
            asynchronous: true
            smooth: true
            fillMode: Image.PreserveAspectCrop
            source: root.vid !== "" ? app.thumbUrl(root.vid) : ""
        }
        Rectangle {
            visible: root.length !== ""
            anchors { right: parent.right; bottom: parent.bottom; margins: 4 }
            width: lenText.paintedWidth + 10; height: 22; radius: 4
            color: "#CC000000"
            Text { id: lenText; anchors.centerIn: parent; text: root.length; color: "#FFFFFF"; font.pixelSize: 14; font.bold: true }
        }
        Rectangle {
            visible: root.badge !== ""
            anchors { left: parent.left; top: parent.top; margins: 4 }
            width: badgeText.paintedWidth + 10; height: 22; radius: 4
            color: app.brand
            Text { id: badgeText; anchors.centerIn: parent; text: root.badge; color: "#FFFFFF"; font.pixelSize: 14; font.bold: true }
        }
    }

    Column {
        anchors { left: thumbBox.right; leftMargin: 14; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
        spacing: 4
        Text {
            width: parent.width
            text: root.title
            textFormat: Text.PlainText
            color: app.textPrimary
            font.pixelSize: 20
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: root.channel + (root.meta !== "" ? "  •  " + root.meta : "")
            textFormat: Text.PlainText
            color: app.textSecondary
            font.pixelSize: 16
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        onClicked: root.clicked()
        onPressAndHold: root.pressAndHold()
    }
}
