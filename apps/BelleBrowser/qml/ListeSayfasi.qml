import QtQuick 1.1
import "Util.js" as U

// Tam ekran liste sayfasi (yer imleri, gecmis, indirilenler, sekmeler, ayarlar).
// Ogeler: { baslik, alt, ikon, anahtar, sag? }. secildi(anahtar) / uzunBasildi(anahtar) / sagTiklandi(anahtar)
// sag: satirin sagindaki ikon (ornek "kapat": sekmeyi kapat). Klavyede C ya da X tusu ayni isi yapar.
Rectangle {
    id: root
    anchors.fill: parent
    color: app.cZemin
    visible: false
    z: 60
    property bool acik: visible
    property string baslik: ""
    property string tur: ""
    property alias model: lm
    property string ekDugme: ""          // sag ustte ek ikon (ornek "arti")
    signal secildi(string anahtar)
    signal uzunBasildi(string anahtar)
    signal ekTiklandi()
    signal sagTiklandi(string anahtar)
    function ac(b, t, ogeler) {
        baslik = b; tur = t;
        doldur(ogeler);
        liste.currentIndex = 0;
        visible = true;
        liste.forceActiveFocus();
    }
    function doldur(ogeler) {
        var k = liste.currentIndex;
        lm.clear();
        for (var i = 0; i < ogeler.length; i++) lm.append({ baslik: ogeler[i].baslik || "", alt: ogeler[i].alt || "", ikon: ogeler[i].ikon || "", anahtar: "" + ogeler[i].anahtar, sag: ogeler[i].sag || "", oran: ogeler[i].oran === undefined ? -1 : ogeler[i].oran });
        liste.currentIndex = Math.max(0, Math.min(k, lm.count - 1));
    }
    function kapat() { visible = false; app.odakla(); }
    MouseArea { anchors.fill: parent }
    Rectangle {
        id: ust
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 52; color: app.cZemin
        IkonDugme { id: g; anchors { left: parent.left; verticalCenter: parent.verticalCenter } ikon: "geri"; onClicked: root.kapat() }
        Text { anchors { left: g.right; leftMargin: 6; right: ek.left; verticalCenter: parent.verticalCenter } text: root.baslik; font.pixelSize: 25; font.bold: true; color: app.cYazi; elide: Text.ElideRight }
        IkonDugme { id: ek; anchors { right: parent.right; verticalCenter: parent.verticalCenter } ikon: root.ekDugme; visible: root.ekDugme !== ""; onClicked: root.ekTiklandi() }
        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: app.cCizgi }
    }
    ListView {
        id: liste
        anchors { left: parent.left; right: parent.right; top: ust.bottom; bottom: parent.bottom }
        clip: true
        model: ListModel { id: lm }
        highlightMoveDuration: 0
        delegate: Item {
            width: liste.width; height: alt !== "" ? 62 : 52
            Rectangle { anchors.fill: parent; color: app.cYuzey; visible: ma.pressed || (ListView.isCurrentItem && liste.activeFocus) }
            Image { anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter } width: 24; height: 24; smooth: true; visible: ikon !== ""
                source: ikon === "" ? "" : "../images/" + ikon + "_" + (app.gece ? "b" : "k") + ".png" }
            Column {
                anchors { left: parent.left; leftMargin: ikon !== "" ? 54 : 18; right: parent.right; rightMargin: sag !== "" ? 58 : 14; verticalCenter: parent.verticalCenter }
                spacing: 2
                Text { width: parent.width; text: baslik; color: app.cYazi; font.pixelSize: 21; elide: Text.ElideRight }
                Text { width: parent.width; text: alt; visible: alt !== ""; color: app.cIkinci; font.pixelSize: 16; elide: Text.ElideMiddle }
                Rectangle { width: parent.width; height: 4; radius: 2; color: app.cCizgi; visible: oran >= 0
                    Rectangle { height: parent.height; radius: 2; color: app.cVurgu; width: parent.width * Math.min(1, Math.max(0, oran)) } }
            }
            Rectangle { anchors { left: parent.left; leftMargin: 54; right: parent.right; bottom: parent.bottom } height: 1; color: app.cCizgi }
            MouseArea { id: ma; anchors.fill: parent; onClicked: { liste.currentIndex = index; root.secildi(anahtar); } onPressAndHold: { liste.currentIndex = index; root.uzunBasildi(anahtar); } }
            IkonDugme { anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter } visible: sag !== ""; ikon: sag !== "" ? sag : "kapat"
                onClicked: { liste.currentIndex = index; root.sagTiklandi(anahtar); } }
        }
        Text { anchors.centerIn: parent; visible: lm.count === 0; text: qsTr("Boş"); color: app.cIkinci; font.pixelSize: 21 }
        Keys.onPressed: {
            var k = event.key;
            if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) { if (lm.count) root.secildi(lm.get(currentIndex).anahtar); event.accepted = true; }
            else if (k === Qt.Key_Space || k === Qt.Key_Context1 || k === Qt.Key_Menu) { if (lm.count) root.uzunBasildi(lm.get(currentIndex).anahtar); event.accepted = true; }
            else if ((U.tus(event) === "c" || U.tus(event) === "x" || k === Qt.Key_Delete) && lm.count && lm.get(currentIndex).sag !== "") { root.sagTiklandi(lm.get(currentIndex).anahtar); event.accepted = true; }
            else if (k === Qt.Key_Escape || k === Qt.Key_Backspace || k === Qt.Key_Context2 || k === Qt.Key_Left) { root.kapat(); event.accepted = true; }
        }
    }
}
