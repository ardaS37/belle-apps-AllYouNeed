import QtQuick 1.1

// Secenek sayfasindaki dugme: buyuk yazi + istege bagli aciklama satiri
Rectangle {
    id: root
    property string label: ""
    property string sub: ""
    property bool primary: false
    property bool dim: false
    signal clicked

    height: sub !== "" ? 62 : 48
    radius: 12
    color: primary ? (ma.pressed ? app.brandPressed : app.brand) : (ma.pressed ? app.pressed : app.fieldBg)
    opacity: dim ? 0.7 : 1

    Column {
        anchors.centerIn: parent
        width: parent.width - 16
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.label
            color: root.primary ? "#FFFFFF" : app.textPrimary
            font.pixelSize: 19
            font.bold: true
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            visible: root.sub !== ""
            horizontalAlignment: Text.AlignHCenter
            text: root.sub
            color: root.primary ? "#FFE3E6" : app.textSecondary
            font.pixelSize: 14
            elide: Text.ElideRight
        }
    }
    MouseArea { id: ma; anchors.fill: parent; onClicked: root.clicked() }
}
