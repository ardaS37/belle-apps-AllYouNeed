import QtQuick 1.1
import "Db.js" as Db
import "Util.js" as U

// Adres / arama girisi: tam ekran, yazarken gecmis ve yer imlerinden oneriler
Rectangle {
    id: root
    anchors.fill: parent
    color: app.cZemin
    visible: false
    z: 70
    property bool acik: visible
    function ac(baslangic) {
        alan.text = baslangic || "";
        doldur();
        visible = true;
        alan.forceActiveFocus();
        alan.selectAll();
        alan.openSoftwareInputPanel();
    }
    function kapat() { visible = false; alan.closeSoftwareInputPanel(); app.odakla(); }
    function git(t) {
        t = (t || "").replace(/^\s+|\s+$/g, "");
        if (t === "") return;
        kapat();
        app.git(t);
    }
    function doldur() {
        om.clear();
        var q = alan.text.replace(/^\s+|\s+$/g, "");
        if (q !== "") {
            if (!U.adresMi(q)) om.append({ baslik: q, url: "", alt: qsTr("Ara: ") + U.MOTORLAR[app.arama].ad, ikon: "ara", tur: "ara" });
            else om.append({ baslik: q, url: q, alt: qsTr("Adrese git"), ikon: "dunya", tur: "git" });
        }
        var l = Db.oner(q);
        for (var i = 0; i < l.length; i++) om.append({ baslik: l[i].baslik, url: l[i].url, alt: l[i].url, ikon: l[i].fav ? "yildizd" : "gecmis", tur: "git" });
        if (q !== "" && !U.adresMi(q)) {
            om.append({ baslik: q, url: U.MOTORLAR.frogfind.url + encodeURIComponent(q), alt: qsTr("FrogFind ile ara (HTTP, sunucusuz çalışır)"), ikon: "ara", tur: "git" });
            om.append({ baslik: q, url: U.MOTORLAR.wiki.url + encodeURIComponent(q), alt: qsTr("Vikipedi'de ara"), ikon: "kitap", tur: "git" });
        }
        liste.currentIndex = -1;
    }
    Rectangle {
        id: ust
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 56
        color: app.cZemin
        IkonDugme { id: geri; anchors { left: parent.left; verticalCenter: parent.verticalCenter } ikon: "geri"; onClicked: root.kapat() }
        Rectangle {
            anchors { left: geri.right; right: temizle.left; verticalCenter: parent.verticalCenter; rightMargin: 4 }
            height: 42; radius: 21; color: app.cYuzey
            border.width: 2; border.color: app.cVurgu
            TextInput {
                id: alan
                anchors { left: parent.left; right: parent.right; leftMargin: 16; rightMargin: 12; verticalCenter: parent.verticalCenter }
                font.pixelSize: 22; color: app.cYazi
                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase | Qt.ImhUrlCharactersOnly
                onTextChanged: if (root.visible) aramaZamani.restart()
                onAccepted: root.git(text)
                Keys.onPressed: {
                    // Ctrl+V yapistir / Ctrl+A tumunu sec (E6: Ctrl+V "7" ya da kod 22 gonderir)
                    if (((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_V || event.text === "7" || event.text === "v")) || event.text === "\u0016") { pano.yapistir(alan); event.accepted = true; return; }
                    if (((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_A || event.text === "a")) || event.text === "\u0001") { alan.selectAll(); event.accepted = true; return; }
                    if (event.text === "\r" || event.text === "\n" || event.key === Qt.Key_Select) {
                        alan.focus = false; ust.forceActiveFocus();
                        if (liste.currentIndex >= 0) liste.sec(liste.currentIndex); else root.git(alan.text);
                        event.accepted = true;
                    }
                    else if (event.key === Qt.Key_Down && om.count) { liste.currentIndex = Math.min(om.count - 1, liste.currentIndex + 1); event.accepted = true; }
                    else if (event.key === Qt.Key_Up && liste.currentIndex >= 0) { liste.currentIndex--; event.accepted = true; }
                    else if (event.key === Qt.Key_Escape) { root.kapat(); event.accepted = true; }
                }
            }
        }
        IkonDugme { id: temizle; anchors { right: parent.right; verticalCenter: parent.verticalCenter } ikon: "kapat"; onClicked: { alan.text = ""; alan.forceActiveFocus(); } }
    }
    Timer { id: aramaZamani; interval: 180; onTriggered: root.doldur() }
    Row {
        id: kisayol
        anchors { left: parent.left; right: parent.right; top: ust.bottom; leftMargin: 10 }
        height: 44; spacing: 8
        Repeater {
            model: ["https://", "www.", ".com", ".com.tr", ".org", "/"]
            Rectangle {
                width: kt.paintedWidth + 22; height: 34; radius: 17; anchors.verticalCenter: parent.verticalCenter
                color: km.pressed ? app.cCizgi : app.cYuzey
                Text { id: kt; anchors.centerIn: parent; text: modelData; color: app.cYazi; font.pixelSize: 19 }
                MouseArea { id: km; anchors.fill: parent; onClicked: { var p = alan.cursorPosition; alan.text = alan.text.substring(0, p) + modelData + alan.text.substring(p); alan.cursorPosition = p + modelData.length; alan.forceActiveFocus(); } }
            }
        }
        Rectangle {
            width: yt.paintedWidth + 22; height: 34; radius: 17; anchors.verticalCenter: parent.verticalCenter
            color: ym.pressed ? app.cCizgi : app.cYuzey
            Text { id: yt; anchors.centerIn: parent; text: qsTr("Yapıştır"); color: app.cVurgu; font.pixelSize: 19 }
            MouseArea { id: ym; anchors.fill: parent; onClicked: { alan.text = tb.pano().replace(/[\r\n\t]/g, ""); alan.forceActiveFocus(); } }
        }
    }
    ListView {
        id: liste
        anchors { left: parent.left; right: parent.right; top: kisayol.bottom; bottom: parent.bottom }
        clip: true
        model: ListModel { id: om }
        function sec(i) { var o = om.get(i); if (o.tur === "ara") root.git(o.baslik); else root.git(o.url); }
        delegate: Item {
            width: liste.width; height: 58
            Rectangle { anchors.fill: parent; color: app.cYuzey; visible: ma.pressed || ListView.isCurrentItem }
            Image { anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter } width: 22; height: 22; smooth: true
                source: "../images/" + ikon + "_" + (app.gece ? "b" : "k") + ".png" }
            Column {
                anchors { left: parent.left; leftMargin: 52; right: parent.right; rightMargin: 50; verticalCenter: parent.verticalCenter }
                Text { width: parent.width; text: baslik; color: app.cYazi; font.pixelSize: 21; elide: Text.ElideRight }
                Text { width: parent.width; text: alt; color: app.cIkinci; font.pixelSize: 16; elide: Text.ElideMiddle }
            }
            IkonDugme { anchors { right: parent.right; verticalCenter: parent.verticalCenter } ikon: "yukari"; boy: 20; rotation: -45; visible: tur === "git"
                onClicked: { alan.text = url; alan.forceActiveFocus(); } }
            MouseArea { id: ma; anchors { fill: parent; rightMargin: 50 } onClicked: liste.sec(index) }
        }
    }
}
