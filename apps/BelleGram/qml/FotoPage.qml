import QtQuick 1.1

// Tam ekran fotograf: once kucuk hali, buyugu inince o. Dokun: kapat. "Kaydet": galeriye kopyala.
Rectangle {
    id: root
    visible: false
    color: "#000000"
    z: 25
    property string kucuk: ""
    property string anahtar: ""
    property string yol: ""
    property int yuzde: -1

    function ac(kucukYol, buyukAnahtar) {
        kucuk = kucukYol;
        anahtar = buyukAnahtar;
        yuzde = -1;
        yol = buyukAnahtar !== "" ? tg.medyaYolu(buyukAnahtar) : "";
        if (yol === "" && buyukAnahtar !== "") { yuzde = 0; tg.medyaIndir(buyukAnahtar); }
        visible = true;
    }
    function kapat() { visible = false; yol = ""; kucuk = ""; anahtar = ""; }

    Connections {
        target: tg
        onMedyaHazir: if (anahtar === root.anahtar && root.visible) { root.yol = yol; root.yuzde = -1; }
        onMedyaIlerleme: if (anahtar === root.anahtar) root.yuzde = yuzde
        onMedyaHata: if (anahtar === root.anahtar) { root.yuzde = -1; toast.show(mesaj); }
    }

    Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        sourceSize.width: 1280
        source: root.visible ? cihaz.url(root.yol !== "" ? root.yol : root.kucuk) : ""
    }
    MouseArea { anchors.fill: parent; onClicked: root.kapat() }

    Rectangle {
        visible: root.yuzde >= 0
        anchors.centerIn: parent
        width: 150; height: 50; radius: 25
        color: "#AA000000"
        Text { anchors.centerIn: parent; text: qsTr("Yükleniyor %1").arg(root.yuzde) + "%"; color: "white"; font.pixelSize: 18 }
    }

    Rectangle {
        anchors { right: parent.right; bottom: parent.bottom; margins: 16 }
        visible: root.yol !== ""
        width: kt.paintedWidth + 40; height: 52; radius: 26
        color: km.pressed ? "#555555" : "#AA222222"
        Text { id: kt; anchors.centerIn: parent; text: qsTr("Galeriye kaydet"); color: "white"; font.pixelSize: 19; font.bold: true }
        MouseArea {
            id: km
            anchors.fill: parent
            onClicked: {
                var p = tg.medyaKaydet(root.anahtar);
                toast.show(p !== "" ? qsTr("Kaydedildi: ") + p : qsTr("Kaydedilemedi"));
            }
        }
    }
}
