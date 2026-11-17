import QtQuick 1.1

// Yuvarlak kenarli metin dugmesi
Rectangle {
    id: root
    property string text: ""
    property bool birincil: true
    property bool etkin: true
    signal clicked

    height: 56
    radius: height / 2
    color: !etkin ? app.fieldBg : (birincil ? (fare.pressed ? app.brandPressed : app.brand) : (fare.pressed ? app.pressed : "transparent"))
    border.width: birincil ? 0 : 2
    border.color: app.brand

    Text {
        anchors.centerIn: parent
        text: root.text
        color: !root.etkin ? app.textSecondary : (root.birincil ? "#FFFFFF" : app.accentText)
        font.pixelSize: 22
        font.bold: true
    }
    MouseArea {
        id: fare
        anchors.fill: parent
        enabled: root.etkin
        onClicked: root.clicked()
    }
}
