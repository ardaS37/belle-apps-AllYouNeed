import QtQuick 1.1
import "Durum.js" as D

// Metin girisi penceresi: ac(baslik, aciklama, deger, gizli, function(metin))
Rectangle {
    id: root
    anchors.fill: parent
    color: "#80000000"
    visible: false
    z: 85
    property bool acik: visible
    property string baslik: ""
    property string aciklama: ""
    function ac(b, a, deger, gizli, cb) {
        baslik = b; aciklama = a || "";
        alan.echoMode = gizli ? TextInput.Password : TextInput.Normal;
        alan.text = deger || "";
        D.girdi = cb;
        visible = true;
        alan.forceActiveFocus();
        alan.selectAll();
        alan.openSoftwareInputPanel();
    }
    function kapat() { visible = false; alan.closeSoftwareInputPanel(); app.odakla(); }
    function tamam() {
        alan.focus = false; kutu.forceActiveFocus();     // E6: tahminli yazidaki son sozcugu isle
        var t = alan.text.replace(/[\r\n\t]/g, "");
        var f = D.girdi; D.girdi = null;
        kapat();
        if (f) f(t);
    }
    MouseArea { anchors.fill: parent; onClicked: root.kapat() }
    Rectangle {
        id: kutu
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 560)
        height: kol.height + 32
        radius: 14
        color: app.cZemin
        MouseArea { anchors.fill: parent }
        Keys.onPressed: {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) { root.tamam(); event.accepted = true; }
            else if (event.key === Qt.Key_Escape) { root.kapat(); event.accepted = true; }
        }
        Column {
            id: kol
            x: 18; y: 16; width: parent.width - 36; spacing: 12
            Text { width: parent.width; text: root.baslik; font.pixelSize: 25; font.bold: true; color: app.cYazi; wrapMode: Text.Wrap }
            Text { width: parent.width; text: root.aciklama; visible: text !== ""; font.pixelSize: 19; color: app.cIkinci; wrapMode: Text.Wrap }
            Rectangle {
                width: parent.width; height: 46; radius: 10; color: app.cYuzey
                border.width: 2; border.color: alan.activeFocus ? app.cVurgu : "transparent"
                TextInput {
                    id: alan
                    anchors { left: parent.left; right: parent.right; margins: 12; verticalCenter: parent.verticalCenter }
                    font.pixelSize: 24; color: app.cYazi
                    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    onAccepted: root.tamam()
                    Keys.onPressed: {
                        // Ctrl+V yapistir / Ctrl+A tumunu sec (E6: Ctrl+V "7" ya da kod 22 gonderir)
                        if (((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_V || event.text === "7" || event.text === "v")) || event.text === "\u0016") { pano.yapistir(alan); event.accepted = true; return; }
                        if (((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_A || event.text === "a")) || event.text === "\u0001") { alan.selectAll(); event.accepted = true; return; }
                        if (event.text === "\r" || event.text === "\n" || event.key === Qt.Key_Select) { root.tamam(); event.accepted = true; }
                        else if (event.key === Qt.Key_Escape) { root.kapat(); event.accepted = true; }
                    }
                }
                MouseArea { anchors.fill: parent; enabled: !alan.activeFocus; onClicked: { alan.forceActiveFocus(); alan.openSoftwareInputPanel(); } }
            }
            Row {
                anchors.right: parent.right; spacing: 10
                Dugme { metin: qsTr("Yapıştır"); onClicked: { alan.text = alan.text + tb.pano().replace(/[\r\n\t]/g, ""); alan.forceActiveFocus(); } }
                Dugme { metin: qsTr("Vazgeç"); onClicked: root.kapat() }
                Dugme { metin: qsTr("Tamam"); ana: true; onClicked: root.tamam() }
            }
        }
    }
}
