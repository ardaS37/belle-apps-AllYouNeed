import QtQuick 1.1

// Liste satiri: solda harf/simge rozeti, baslik, alt bilgi, sagda ... dugmesi.
// aktif: su an calan (vurgulu), soluk: dinlenmis/okunmus
Item {
    id: root
    property string baslik: ""
    property string alt: ""
    property string simge: ""            // images/<simge>_w.png; bossa basligin ilk harfi
    property string harf: baslik.length ? baslik.charAt(0).toUpperCase() : "?"
    property bool secili: false           // klavye imleci
    property bool aktif: false
    property bool soluk: false
    property bool yeni: false             // okunmamis/yeni noktasi
    property string sagYazi: ""
    signal tiklandi
    signal basiliTutuldu
    signal menu

    width: parent ? parent.width : 400
    height: Math.round(36 * app.yazi + 24)

    Rectangle { anchors.fill: parent; color: ma.pressed ? app.pressed : (root.secili ? app.highlight : (root.aktif ? app.markBg : "transparent")) }
    Rectangle { visible: root.secili || root.aktif; anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 4; color: app.brand }
    Rectangle {
        id: rozet
        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
        width: 40; height: 40; radius: 10
        color: root.aktif ? app.pill : app.fieldBg
        Image { visible: root.simge !== ""; anchors.centerIn: parent; width: 24; height: 24; smooth: true; source: root.simge === "" ? "" : "../images/" + (root.aktif ? "play" : root.simge) + (root.aktif ? "_a" : "_w") + ".png" }
        Text { visible: root.simge === ""; anchors.centerIn: parent; text: root.aktif ? "▶" : root.harf; color: root.aktif ? app.brand : app.textPrimary; font.pixelSize: 19; font.bold: true }
    }
    Column {
        anchors { left: rozet.right; leftMargin: 12; right: sag.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
        spacing: 2
        Row {
            width: parent.width
            spacing: 6
            Rectangle { visible: root.yeni; width: 8; height: 8; radius: 4; color: app.brand; anchors.verticalCenter: parent.verticalCenter }
            Text {
                width: parent.width - (root.yeni ? 14 : 0)
                text: root.baslik
                textFormat: Text.PlainText
                color: root.aktif ? app.brand : (root.soluk ? app.textSecondary : app.textPrimary)
                font.pixelSize: Math.round(18 * app.yazi)
                font.bold: root.yeni
                elide: Text.ElideRight
            }
        }
        Text {
            width: parent.width
            visible: root.alt !== ""
            text: root.alt
            textFormat: Text.PlainText
            color: app.textSecondary
            font.pixelSize: Math.round(14 * app.yazi)
            elide: Text.ElideRight
        }
    }
    Row {
        id: sag
        anchors { right: parent.right; rightMargin: 2; verticalCenter: parent.verticalCenter }
        Text { visible: root.sagYazi !== ""; anchors.verticalCenter: parent.verticalCenter; text: root.sagYazi; color: app.textSecondary; font.pixelSize: Math.round(13 * app.yazi) }
        IconButton { icon: "more"; tone: "g"; iconSize: 24; onClicked: root.menu() }
    }
    MouseArea { id: ma; anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: sag.left } onClicked: root.tiklandi(); onPressAndHold: root.basiliTutuldu() }
    Rectangle { anchors { left: rozet.right; leftMargin: 12; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
}
