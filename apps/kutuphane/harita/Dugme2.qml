import QtQuick 1.1

// Harita ekranlarinin dugmesi (uygulamalarin kendi Dugme bilesenleriyle karismasin diye ayri ad)
Rectangle {
    id: d
    property string metin: ""
    property bool ana: false
    property bool koyuZemin: false
    signal tik()
    width: Math.max(t.paintedWidth + 32, 90); height: 48; radius: 24
    color: ana ? (m.pressed ? "#008f6f" : "#00a884") : (m.pressed ? "#22000000" : "#11000000")
    border.width: ana ? 0 : 1
    border.color: "#3300a884"
    smooth: true
    Text { id: t; anchors.centerIn: parent; text: d.metin; font.pixelSize: 18; font.bold: true; color: d.ana ? "white" : "#00a884" }
    MouseArea { id: m; anchors.fill: parent; onClicked: d.tik() }
}
