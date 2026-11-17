import QtQuick 1.1

// Modern tarayici menusu: alttan acilan ikon izgarasi. secildi(anahtar)
Rectangle {
    id: root
    anchors.fill: parent
    color: "#80000000"
    visible: false
    z: 75
    property bool acik: visible
    signal secildi(string anahtar)
    function ac() { izgara.currentIndex = 0; visible = true; izgara.forceActiveFocus(); }
    function kapat() { visible = false; app.odakla(); }
    function sec(k) { visible = false; app.odakla(); secildi(k); }
    ListModel {
        id: mm
        ListElement { ad: QT_TR_NOOP("Yeni sekme"); ikon: "arti"; k: "yeni" }
        ListElement { ad: QT_TR_NOOP("Sekmeler"); ikon: "sekme"; k: "sekmeler" }
        ListElement { ad: QT_TR_NOOP("Yer imleri"); ikon: "yildiz"; k: "favlar" }
        ListElement { ad: QT_TR_NOOP("Geçmiş"); ikon: "gecmis"; k: "gecmis" }
        ListElement { ad: QT_TR_NOOP("İndirilenler"); ikon: "indir"; k: "indirilen" }
        ListElement { ad: QT_TR_NOOP("Yer imi ekle"); ikon: "yildizd"; k: "favekle" }
        ListElement { ad: QT_TR_NOOP("Sayfada bul"); ikon: "bul"; k: "bul" }
        ListElement { ad: QT_TR_NOOP("Okuma modu"); ikon: "kitap"; k: "oku" }
        ListElement { ad: QT_TR_NOOP("Sade görünüm"); ikon: "yazi"; k: "sade" }
        ListElement { ad: QT_TR_NOOP("Masaüstü sitesi"); ikon: "masa"; k: "masa" }
        ListElement { ad: QT_TR_NOOP("Bağlantı modu"); ikon: "simsek"; k: "mod" }
        ListElement { ad: QT_TR_NOOP("Belle Remote'ta aç"); ikon: "uzak"; k: "uzak" }
        ListElement { ad: QT_TR_NOOP("Videolar"); ikon: "video"; k: "videolar" }
        ListElement { ad: QT_TR_NOOP("Gece modu"); ikon: "gece"; k: "gece" }
        ListElement { ad: QT_TR_NOOP("Yazı boyutu"); ikon: "yazi"; k: "yazi" }
        ListElement { ad: QT_TR_NOOP("Adresi kopyala"); ikon: "kopya"; k: "kopya" }
        ListElement { ad: QT_TR_NOOP("Başka uygulamada"); ikon: "paylas"; k: "dis" }
        ListElement { ad: QT_TR_NOOP("İmleç"); ikon: "imlec"; k: "imlec" }
        ListElement { ad: QT_TR_NOOP("Ana sayfa"); ikon: "ev"; k: "ev" }
        ListElement { ad: QT_TR_NOOP("Hata bildir"); ikon: "paylas"; k: "rapor" }
        ListElement { ad: QT_TR_NOOP("Ayarlar"); ikon: "ayar"; k: "ayarlar" }
        ListElement { ad: QT_TR_NOOP("Çıkış"); ikon: "cikis"; k: "cikis" }
    }
    MouseArea { anchors.fill: parent; onClicked: root.kapat() }
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        property int sutun: Math.max(4, Math.min(6, Math.floor(root.width / 104)))
        height: Math.min(root.height - 30, Math.ceil(mm.count / sutun) * 84 + 30)
        radius: 16
        color: app.cZemin
        MouseArea { anchors.fill: parent }
        GridView {
            id: izgara
            anchors { fill: parent; margins: 8; topMargin: 14 }
            clip: true
            cellWidth: width / parent.sutun
            cellHeight: 84
            model: mm
            highlightMoveDuration: 0
            delegate: Item {
                width: izgara.cellWidth; height: izgara.cellHeight
                Rectangle { anchors { fill: parent; margins: 3 } radius: 12; color: app.cYuzey; visible: ma.pressed || (GridView.isCurrentItem && izgara.activeFocus) }
                Image { anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 12 } width: 28; height: 28; smooth: true
                    source: "../images/" + ikon + "_" + (app.gece ? "b" : "k") + ".png" }
                Text { anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 10 } width: parent.width - 6
                    horizontalAlignment: Text.AlignHCenter; text: qsTr(ad); font.pixelSize: 16; color: app.cYazi; elide: Text.ElideRight }
                MouseArea { id: ma; anchors.fill: parent; onClicked: root.sec(k) }
            }
            Keys.onPressed: {
                var key = event.key;
                if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Select) { root.sec(mm.get(currentIndex).k); event.accepted = true; }
                else if (key === Qt.Key_Escape || key === Qt.Key_Backspace || key === Qt.Key_Context2 || key === Qt.Key_Context1 || key === Qt.Key_Menu) { root.kapat(); event.accepted = true; }
            }
        }
    }
}
