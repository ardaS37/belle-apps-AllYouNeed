import QtQuick 1.1

// Alt cubugun ustundeki kucuk calar: dokununca tam ekran calar acilir
Rectangle {
    id: root
    color: app.surface2
    clip: true
    property variant t: player.current

    Rectangle {   // ilerleme
        anchors { left: parent.left; top: parent.top }
        height: 3
        width: player.duration > 0 ? parent.width * Math.min(1, player.position / player.duration) : 0
        color: app.accent
    }
    // Ince cubuk; kontrol dugmeleri buyuk (onceki, cal/duraklat, sonraki, favori)
    Cover { id: cv; anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter } size: 40; source: root.t ? root.t.image : "" }
    Column {
        anchors { left: cv.right; leftMargin: 10; right: btns.left; rightMargin: 4; verticalCenter: parent.verticalCenter }
        Text { width: parent.width; text: root.t ? root.t.name : ""; color: app.textPrimary; font.pixelSize: 17; font.bold: true; elide: Text.ElideRight }
        Text {
            width: parent.width
            text: player.loading ? qsTr("Yükleniyor...") : (player.status !== "" ? player.status : (root.t ? root.t.singer : ""))
            color: player.loading ? app.accent : app.textSecondary
            font.pixelSize: 13; elide: Text.ElideRight
        }
    }
    MouseArea { anchors { left: parent.left; right: btns.left; top: parent.top; bottom: parent.bottom } onClicked: app.openPlayer() }
    Row {
        id: btns
        anchors { right: parent.right; rightMargin: 2; verticalCenter: parent.verticalCenter }
        IconButton { width: 50; height: 54; icon: root.t && app.favVersion >= 0 && app.isFav(root.t.key) ? "heart" : "heart_o"; tone: root.t && app.favVersion >= 0 && app.isFav(root.t.key) ? "a" : "w"; iconSize: 28; onClicked: if (root.t) { var on = !app.isFav(root.t.key); app.setFav(root.t, on); app.showToast(on ? qsTr("Favorilere eklendi") : qsTr("Favorilerden çıkarıldı")); } }
        IconButton { width: 56; height: 54; icon: "prev"; iconSize: 36; onClicked: player.prev() }
        IconButton { width: 62; height: 54; icon: player.playing || player.loading ? "pause" : "play"; iconSize: 44; onClicked: player.toggle() }
        IconButton { width: 56; height: 54; icon: "next"; iconSize: 36; onClicked: player.next(true) }
    }
}
