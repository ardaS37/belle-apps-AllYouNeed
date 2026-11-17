import QtQuick 1.1

// Kucuk secim hapi (sekme ici gorunum secimi)
Rectangle {
    id: root
    property string yazi: ""
    property bool secili: false
    signal tiklandi
    height: 32
    width: t.paintedWidth + 26
    radius: 16
    color: secili ? app.brand : (ma.pressed ? app.pressed : app.fieldBg)
    Text { id: t; anchors.centerIn: parent; text: root.yazi; color: root.secili ? "#101418" : app.textPrimary; font.pixelSize: Math.round(15 * Math.min(app.yazi, 1.3)); font.bold: root.secili }
    MouseArea { id: ma; anchors.fill: parent; onClicked: root.tiklandi() }
}
