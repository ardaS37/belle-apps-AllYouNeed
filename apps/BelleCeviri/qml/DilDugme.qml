import QtQuick 1.1

// Dil secme dugmesi: dil adi + ▾
Rectangle {
    id: root
    property string yazi: ""
    signal tiklandi
    height: 40
    radius: 10
    color: ma.pressed ? app.pressed : app.fieldBg
    Text {
        anchors { left: parent.left; leftMargin: 10; right: ok.left; rightMargin: 4; verticalCenter: parent.verticalCenter }
        text: root.yazi
        color: app.textPrimary
        font.pixelSize: Math.round(16 * Math.min(app.yazi, 1.3))
        font.bold: true
        elide: Text.ElideRight
    }
    Text { id: ok; anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter } text: "▾"; color: app.brand; font.pixelSize: 16 }
    MouseArea { id: ma; anchors.fill: parent; onClicked: root.tiklandi() }
}
