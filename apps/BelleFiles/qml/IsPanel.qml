import QtQuick 1.1

// Uzun islerde ilerleme penceresi (kopyala / tasi / sil / zip / Drive yedegi).
// "Arka planda" ile gizlenir, is surer; bitince bildirim gelir. Geri / Esc: iptal sorar.
Rectangle {
    id: root
    anchors.fill: parent
    color: "#B0000000"
    visible: false
    z: 60
    property bool shown: visible
    property string baslik: ""
    property string ad: ""
    property double oran: -1          // 0..1, -1 belirsiz
    property string detay: ""
    property bool arkada: false       // kullanici gizledi
    signal iptalEt

    function ac(b) { baslik = b; ad = ""; oran = -1; detay = qsTr("Hazırlanıyor…"); arkada = false; visible = true; kutu.forceActiveFocus(); }
    function guncelle(a, o, d) { ad = a; oran = o; detay = d; }
    function kapat() { var v = visible; visible = false; if (v) app.focusCurrent(); }
    function gizle() { arkada = true; visible = false; app.showToast(qsTr("İş arka planda sürüyor")); app.focusCurrent(); }
    function goster() { if (baslik !== "") { arkada = false; visible = true; kutu.forceActiveFocus(); } }

    MouseArea { anchors.fill: parent }

    Rectangle {
        id: kutu
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 560)
        height: col.height + 36
        radius: 12
        color: app.surface
        focus: true
        Keys.onPressed: {
            var k = event.key;
            if (k === Qt.Key_Escape || k === Qt.Key_Backspace || k === Qt.Key_Context2) { root.iptalEt(); event.accepted = true; }
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) { root.gizle(); event.accepted = true; }
            else event.accepted = true;
        }
        Column {
            id: col
            x: 20; y: 18
            width: parent.width - 40
            spacing: 12
            Text { width: parent.width; text: root.baslik; color: app.textPrimary; font.pixelSize: 21; font.bold: true; elide: Text.ElideRight }
            Text { width: parent.width; text: root.ad || " "; color: app.textSecondary; font.pixelSize: 17; elide: Text.ElideMiddle }
            Rectangle {
                id: bar
                width: parent.width; height: 14; radius: 7
                color: app.divider
                clip: true
                Rectangle {
                    height: parent.height; radius: 7; color: app.brand
                    width: root.oran < 0 ? parent.width * 0.3 : Math.max(parent.height, parent.width * Math.min(1, root.oran))
                    x: root.oran < 0 ? kayan.x : 0
                }
                Item {
                    id: kayan
                    width: 1; height: 1
                    SequentialAnimation on x {
                        running: root.visible && root.oran < 0
                        loops: Animation.Infinite
                        NumberAnimation { from: -bar.width * 0.3; to: bar.width; duration: 1200 }
                    }
                }
            }
            Text { width: parent.width; text: root.detay; color: app.textSecondary; font.pixelSize: 15; wrapMode: Text.Wrap }
            Row {
                anchors.right: parent.right
                spacing: 10
                Dugme { text: qsTr("Arka planda"); onClicked: root.gizle() }
                Dugme { text: qsTr("İptal"); danger: true; onClicked: root.iptalEt() }
            }
        }
    }
}
