import QtQuick 1.1
import "Util.js" as U
import "Servis.js" as S
import "Durum.js" as D

// Dil secici: arama kutusu, ustte son kullanilanlar, sonra tum diller (Turkce ve Ingilizce adla aranir).
Rectangle {
    id: root
    color: app.bg
    property bool kaynak: true
    property string secili: ""

    function ac(kaynakMi, mevcut, cb) {
        kaynak = kaynakMi;
        secili = mevcut;
        D.dilSecildi = cb;
        ara.text = "";
        doldur("");
        visible = true;
        ara.focusInput();
    }
    function kapat() { visible = false; ara.input.closeSoftwareInputPanel(); app.focusCurrent(); }
    function takeFocus() { ara.focusInput(); }
    function doldur(q) {
        dm.clear();
        q = U.fold(q.replace(/^\s+|\s+$/g, ""));
        var eklendi = {};
        if (q === "") {
            if (kaynak) { dm.append({ kod: "auto", ad: S.dilAdi("auto", app.ing), bolum: qsTr("Son kullanılanlar") }); eklendi["auto"] = true; }
            var son = app.ayar("sonDiller", "tr,en").split(",");
            for (var s = 0; s < son.length; s++) if (son[s] && !eklendi[son[s]]) { dm.append({ kod: son[s], ad: S.dilAdi(son[s], app.ing), bolum: qsTr("Son kullanılanlar") }); eklendi[son[s]] = true; }
        }
        var l = S.diller.slice(0);
        l.sort(function (a, b) { var x = U.fold(a[app.ing ? 2 : 1]), y = U.fold(b[app.ing ? 2 : 1]); return x < y ? -1 : (x > y ? 1 : 0); });
        for (var i = 0; i < l.length; i++) {
            var d = l[i];
            if (d[0] === "auto" && (!kaynak || q === "")) continue;
            if (q === "" && eklendi[d[0]]) continue;
            if (q !== "" && U.fold(d[1]).indexOf(q) < 0 && U.fold(d[2]).indexOf(q) < 0 && d[0].toLowerCase().indexOf(q) !== 0) continue;
            dm.append({ kod: d[0], ad: d[app.ing ? 2 : 1], bolum: q === "" ? qsTr("Tüm diller") : qsTr("Sonuçlar") });
        }
        liste.currentIndex = 0;
    }
    function sec(i) {
        if (i < 0 || i >= dm.count) return;
        var k = dm.get(i).kod, cb = D.dilSecildi;
        D.dilSecildi = null;
        kapat();
        if (cb) cb(k);
    }

    MouseArea { anchors.fill: parent }
    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        showBack: true
        onBack: root.kapat()
        title: root.kaynak ? qsTr("Kaynak dil") : qsTr("Hedef dil")
        subtitle: S.diller.length - 1 + qsTr(" dil")
    }
    TextField {
        id: ara
        anchors { left: parent.left; right: parent.right; top: header.bottom; margins: 8 }
        placeholder: qsTr("Dil ara (ör. alman, german, de)")
        onTextChanged: root.doldur(text)
        onAccepted: root.sec(liste.currentIndex)
        onEscaped: root.kapat()
        onTabbed: liste.forceActiveFocus()
    }
    ListModel { id: dm }
    ListView {
        id: liste
        anchors { left: parent.left; right: parent.right; top: ara.bottom; topMargin: 6; bottom: parent.bottom }
        clip: true
        model: dm
        highlightMoveDuration: 80
        section.property: "bolum"
        section.delegate: Item {
            width: liste.width; height: 30
            Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: section; color: app.brand; font.pixelSize: 14; font.bold: true }
        }
        delegate: Rectangle {
            width: liste.width
            height: Math.round(26 * app.yazi + 18)
            color: dma.pressed ? app.pressed : ((ListView.isCurrentItem && liste.activeFocus) ? app.highlight : (kod === root.secili ? app.markBg : "transparent"))
            Text { x: 18; anchors.verticalCenter: parent.verticalCenter; text: ad; color: kod === root.secili ? app.brand : app.textPrimary; font.pixelSize: Math.round(18 * app.yazi); font.bold: kod === root.secili }
            Text { anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter } text: kod === "auto" ? "" : kod; color: app.textSecondary; font.pixelSize: 13 }
            Rectangle { anchors { left: parent.left; leftMargin: 18; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
            MouseArea { id: dma; anchors.fill: parent; onClicked: root.sec(index) }
        }
        Keys.onPressed: {
            var k = event.key;
            if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) { root.sec(currentIndex); event.accepted = true; }
            else if (k === Qt.Key_Escape || k === Qt.Key_Backspace || k === Qt.Key_Context2) { root.kapat(); event.accepted = true; }
            else if (U.printable(event)) { ara.focusInput(); ara.text += event.text; event.accepted = true; }
        }
    }
}
