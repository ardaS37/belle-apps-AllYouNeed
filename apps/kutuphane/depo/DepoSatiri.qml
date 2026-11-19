import QtQuick 1.1

// Ayarlar sayfalari icin "Depolama yeri" satiri (kutuphane/depo/DepoSatiri.qml; depo.pri ile qrc:/qml altina girer).
// Dokununca: Otomatik -> saglam her surucu -> Telefon (C:) -> Otomatik. Uygulama yeniden acilinca gecerli olur.
//   DepoSatiri { width: parent.width; yazi: app.textPrimary; ikinci: app.textSecondary; vurgu: app.brand }
Item {
    id: root
    property color yazi: "#E9EDEF"
    property color ikinci: "#8696A0"
    property color vurgu: "#21C063"
    property int boyut: 22
    signal degisti
    height: Math.max(64, metinler.height + 20)

    Column {
        id: metinler
        anchors { left: parent.left; right: hap.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
        Text { text: qsTr("Depolama yeri"); color: root.yazi; font.pixelSize: root.boyut }
        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: qsTr("Önbellek ve indirmeler: ") + depo.etkinAd + (depo.yenidenBaslat ? qsTr(" → yeniden açınca: ") + depo.hedefAd : "")
            color: root.ikinci
            font.pixelSize: root.boyut - 6
        }
    }
    Rectangle {
        id: hap
        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
        width: Math.min(hapMetin.paintedWidth + 32, root.width * 0.55); height: 40; radius: 20
        color: "transparent"
        border.width: 2; border.color: root.vurgu
        Text {
            id: hapMetin
            anchors.centerIn: parent
            width: Math.min(paintedWidth, root.width * 0.55 - 24)
            elide: Text.ElideRight
            text: depo.ad(depo.secim)
            color: root.vurgu; font.pixelSize: root.boyut - 3; font.bold: true
        }
    }
    MouseArea {
        anchors.fill: parent
        onClicked: { depo.sec(depo.sonraki()); root.degisti(); }
    }
}
