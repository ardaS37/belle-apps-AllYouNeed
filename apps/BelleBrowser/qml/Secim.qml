import QtQuick 1.1
import "Durum.js" as D
import "Util.js" as U

// Alttan acilan secenek listesi. ac(baslik, [{ad, ikon, anahtar, tehlike}], function(anahtar))
Rectangle {
    id: root
    anchors.fill: parent
    color: "#80000000"
    visible: false
    z: 80
    property bool acik: visible
    property string baslik: ""
    function ac(b, ogeler, cb) {
        baslik = b;
        lm.clear();
        for (var i = 0; i < ogeler.length; i++) lm.append({ ad: ogeler[i].ad, ikon: ogeler[i].ikon || "", anahtar: ogeler[i].anahtar, tehlike: !!ogeler[i].tehlike });
        D.secim = cb;
        liste.currentIndex = 0;
        visible = true;
        liste.forceActiveFocus();
    }
    function kapat() { visible = false; app.odakla(); }
    function sec(i) {
        var k = lm.get(i).anahtar, f = D.secim;
        D.secim = null;
        visible = false;
        app.odakla();
        if (f) f(k);
    }
    MouseArea { anchors.fill: parent; onClicked: root.kapat() }
    Rectangle {
        id: kutu
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Math.min(root.height * 0.85, lm.count * 50 + bas.height + 20)
        color: app.cZemin
        radius: 14
        MouseArea { anchors.fill: parent }
        Text {
            id: bas
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            text: root.baslik; visible: text !== ""; height: visible ? paintedHeight + 6 : 0
            color: app.cIkinci; font.pixelSize: 19; elide: Text.ElideMiddle
        }
        ListView {
            id: liste
            anchors { left: parent.left; right: parent.right; top: bas.bottom; bottom: parent.bottom; topMargin: 4 }
            clip: true
            model: ListModel { id: lm }
            highlightMoveDuration: 0
            delegate: Item {
                width: liste.width; height: 50
                Rectangle { anchors.fill: parent; color: app.cYuzey; visible: ma.pressed || (ListView.isCurrentItem && liste.activeFocus) }
                Image { id: ik; anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter } width: 24; height: 24; smooth: true; visible: ikon !== ""
                    source: ikon === "" ? "" : "../images/" + ikon + "_" + (app.gece ? "b" : "k") + ".png" }
                Text { anchors { left: parent.left; leftMargin: ikon !== "" ? 54 : 18; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    text: ad; elide: Text.ElideRight; font.pixelSize: 22; color: tehlike ? "#d93025" : app.cYazi }
                MouseArea { id: ma; anchors.fill: parent; onClicked: root.sec(index) }
            }
            Keys.onPressed: {
                var k = event.key;
                if (k === Qt.Key_Down) { currentIndex = (currentIndex + 1) % lm.count; event.accepted = true; }
                else if (k === Qt.Key_Up) { currentIndex = (currentIndex - 1 + lm.count) % lm.count; event.accepted = true; }
                else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) { root.sec(currentIndex); event.accepted = true; }
                else if (k === Qt.Key_Escape || k === Qt.Key_Backspace || k === Qt.Key_Context2 || k === Qt.Key_Left) { root.kapat(); event.accepted = true; }
                else if (U.tus(event) !== "") {
                    var c = U.tus(event);
                    for (var n = 1; n <= lm.count; n++) { var j = (currentIndex + n) % lm.count; if (lm.get(j).ad.charAt(0).toLowerCase() === c) { currentIndex = j; break; } }
                    event.accepted = true;
                }
            }
        }
    }
}
