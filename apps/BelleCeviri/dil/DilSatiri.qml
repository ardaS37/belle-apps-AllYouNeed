import QtQuick 1.1

// Ayarlar sayfalari icin "Dil / Language" satiri (kutuphane/dil/DilSatiri.qml; uygulamanin qml klasorune kopyalanir).
// Dokununca Turkce <-> English; secim tum uygulamalarda ortaktir ve uygulama yeniden acilinca gecerli olur.
//   DilSatiri { width: parent.width; yazi: app.textPrimary; ikinci: app.textSecondary; vurgu: app.brand }
Item {
    id: root
    property color yazi: "#E9EDEF"
    property color ikinci: "#8696A0"
    property color vurgu: "#21C063"
    property int boyut: 22
    property string hedef: dil.secim === "auto" ? dil.kod : dil.secim
    signal degisti
    height: Math.max(64, metinler.height + 20)

    Column {
        id: metinler
        anchors { left: parent.left; right: hap.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
        Text { text: "Dil / Language"; color: root.yazi; font.pixelSize: root.boyut }
        Text {
            width: parent.width
            visible: dil.yenidenBaslat
            wrapMode: Text.Wrap
            text: "Yeniden açınca geçerli olur / Restart the app to apply"
            color: root.ikinci
            font.pixelSize: root.boyut - 6
        }
    }
    Rectangle {
        id: hap
        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
        width: hapMetin.paintedWidth + 32; height: 40; radius: 20
        color: "transparent"
        border.width: 2; border.color: root.vurgu
        Text { id: hapMetin; anchors.centerIn: parent; text: root.hedef === "en" ? "English" : "Türkçe"; color: root.vurgu; font.pixelSize: root.boyut - 3; font.bold: true }
    }
    MouseArea {
        anchors.fill: parent
        onClicked: { dil.sec(root.hedef === "en" ? "tr" : "en"); root.degisti(); }
    }
}
