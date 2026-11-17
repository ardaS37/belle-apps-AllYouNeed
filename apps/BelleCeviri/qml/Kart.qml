import QtQuick 1.1

// Bir servisin sonuc karti: baslik + etiketler, sonuc (secilebilir), ek bilgi, Kopyala / ★ dugmeleri.
// durum: "bekliyor" | "tamam" | "hata"
Rectangle {
    id: root
    property string ad: ""
    property string etiket: ""
    property string durum: "bekliyor"
    property string metin: ""
    property string ek: ""
    property string hata: ""
    property string alg: ""
    property bool secili: false
    property bool yildizVar: true
    signal kopyala
    signal yildiz

    height: kol.height + 20
    radius: 12
    color: app.surface
    border.width: secili ? 2 : 0
    border.color: app.brand

    Column {
        id: kol
        x: 12; y: 10
        width: root.width - 24
        spacing: 6
        Row {
            width: parent.width
            spacing: 8
            Text { text: root.ad; color: app.brand; font.pixelSize: Math.round(16 * Math.min(app.yazi, 1.3)); font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            Text { text: root.etiket; color: app.textSecondary; font.pixelSize: Math.round(12 * Math.min(app.yazi, 1.3)); anchors.verticalCenter: parent.verticalCenter }
            Text { visible: root.alg !== ""; text: "· " + qsTr("algılanan: ") + app.dilAdi(root.alg); color: app.textSecondary; font.pixelSize: Math.round(12 * Math.min(app.yazi, 1.3)); anchors.verticalCenter: parent.verticalCenter }
        }
        TextEdit {
            id: sonuc
            width: parent.width
            readOnly: true
            selectByMouse: true
            wrapMode: TextEdit.Wrap
            text: root.durum === "bekliyor" ? qsTr("Çevriliyor…") : (root.durum === "hata" ? root.hata : root.metin)
            color: root.durum === "hata" ? app.danger : (root.durum === "bekliyor" ? app.textSecondary : app.textPrimary)
            font.pixelSize: Math.round(19 * app.yazi)
            selectionColor: app.brand
            selectedTextColor: "#101418"
        }
        Text {
            visible: root.ek !== "" && root.durum === "tamam"
            width: parent.width
            text: root.ek
            color: app.textSecondary
            font.pixelSize: Math.round(14 * app.yazi)
            wrapMode: Text.Wrap
        }
        Row {
            visible: root.durum === "tamam" && root.metin !== ""
            spacing: 8
            Rectangle {
                width: kt.paintedWidth + 34; height: 34; radius: 17
                color: kma.pressed ? app.brandPressed : app.brand
                Text { id: kt; anchors.centerIn: parent; text: qsTr("Kopyala"); color: "#101418"; font.pixelSize: 15; font.bold: true }
                MouseArea { id: kma; anchors.fill: parent; onClicked: root.kopyala() }
            }
            Rectangle {
                visible: root.yildizVar
                width: 44; height: 34; radius: 17
                color: yma.pressed ? app.pressed : app.fieldBg
                Text { anchors.centerIn: parent; text: "★"; color: app.brand; font.pixelSize: 18 }
                MouseArea { id: yma; anchors.fill: parent; onClicked: root.yildiz() }
            }
        }
    }
}
