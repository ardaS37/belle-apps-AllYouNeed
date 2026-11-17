import QtQuick 1.1

// Harita uzerindeki yuvarlak dugme. Simgeler cizilir (Belle yazi tipinde ◎ ▤ ✕ gibi isaretler bos kutu cikiyor).
//  tur: "konum" (nisangah) | "katman" (ust uste katmanlar)
Rectangle {
    id: dg
    property string tur: "konum"
    property bool vurgu: false
    property color renk: vurgu ? app.cVurgu : app.cYazi
    signal tik()
    width: 52; height: 52; radius: 26
    color: m.pressed ? app.cYuzey : app.cZemin
    border.color: app.cCizgi; border.width: 1
    smooth: true

    Item {
        anchors.fill: parent
        visible: dg.tur === "konum"
        Rectangle { anchors.centerIn: parent; width: 26; height: 26; radius: 13; color: "transparent"; border.width: 3; border.color: dg.renk; smooth: true }
        Rectangle { anchors.centerIn: parent; width: 10; height: 10; radius: 5; color: dg.renk; smooth: true }
        Rectangle { anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 8 } width: 3; height: 8; color: dg.renk }
        Rectangle { anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 8 } width: 3; height: 8; color: dg.renk }
        Rectangle { anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 8 } width: 8; height: 3; color: dg.renk }
        Rectangle { anchors { verticalCenter: parent.verticalCenter; right: parent.right; rightMargin: 8 } width: 8; height: 3; color: dg.renk }
    }
    Item {
        anchors.fill: parent
        visible: dg.tur === "katman"
        Repeater {
            model: 3
            Rectangle {
                x: 14; y: 13 + index * 8
                width: 24; height: 10; radius: 2
                color: index === 0 ? dg.renk : "transparent"
                border.width: 2; border.color: dg.renk
                smooth: true
            }
        }
    }
    // + / - (yakinlastir, uzaklastir)
    Rectangle { anchors.centerIn: parent; width: 22; height: 4; radius: 1; color: dg.renk; visible: dg.tur === "arti" || dg.tur === "eksi" }
    Rectangle { anchors.centerIn: parent; width: 4; height: 22; radius: 1; color: dg.renk; visible: dg.tur === "arti" }
    MouseArea { id: m; anchors.fill: parent; onClicked: dg.tik() }
}
