import QtQuick 1.1

Rectangle {
    id: root
    property alias metin: t.text
    property bool ana: false
    signal clicked
    width: Math.max(t.paintedWidth + 28, 60); height: 44; radius: 22
    color: ma.pressed ? (ana ? "#1557b0" : app.cCizgi) : (ana ? app.cVurgu : app.cYuzey)
    Text { id: t; anchors.centerIn: parent; font.pixelSize: 21; font.bold: root.ana; color: root.ana ? "#ffffff" : app.cVurgu }
    MouseArea { id: ma; anchors.fill: parent; onClicked: root.clicked() }
}
