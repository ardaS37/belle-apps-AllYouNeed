import QtQuick 1.1
import "Util.js" as U

// Sarki satiri (degerler acikca verilir: tKey, tName, tSinger, tDuration, tImage)
Item {
    id: row
    property string tKey: ""
    property string tName: ""
    property string tSinger: ""
    property int tDuration: 0
    property string tImage: ""
    property bool selectMode: false
    property bool selected: false
    property bool isCurrent: false        // klavye vurgusu
    property int number: 0                // >0 ise kapak yerine sira numarasi
    property bool showCover: true
    signal clicked
    signal pressAndHold
    signal moreClicked

    width: ListView.view ? ListView.view.width : 400
    height: 68

    property bool playingNow: player.current ? player.current.key === row.tKey : false
    property bool fav: app.favVersion >= 0 && app.isFav(row.tKey)
    property bool downloaded: app.dlVersion >= 0 && app.isDownloaded(row.tKey)
    property bool queued: app.dlVersion >= 0 && !downloaded && music.isQueued(row.tKey)

    Rectangle {
        anchors.fill: parent
        color: ma.pressed ? app.pressed : (row.selected ? app.highlight : (row.isCurrent ? app.surface : "transparent"))
    }
    Rectangle { visible: row.isCurrent; width: 4; height: parent.height; color: app.accent }

    Image {
        id: check
        visible: row.selectMode
        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
        width: 30; height: 30; smooth: true
        source: row.selected ? "../images/boxon_a.png" : "../images/box_g.png"
    }
    Item {
        id: lead
        anchors { left: row.selectMode ? check.right : parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
        width: row.showCover ? 52 : 34; height: 52
        Cover { visible: row.showCover; anchors.centerIn: parent; size: 52; source: row.tImage }
        Text {
            visible: !row.showCover
            anchors.centerIn: parent
            text: row.number > 0 ? row.number : ""
            color: row.playingNow ? app.accent : app.textSecondary
            font.pixelSize: 17
        }
        Rectangle {
            visible: row.playingNow && row.showCover
            anchors.fill: parent; radius: 6; color: "#88000000"
            Image { anchors.centerIn: parent; width: 26; height: 26; smooth: true; source: player.playing ? "../images/pause_a.png" : "../images/play_a.png" }
        }
    }
    Column {
        anchors { left: lead.right; leftMargin: 12; right: icons.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
        spacing: 2
        Text {
            width: parent.width
            text: row.tName
            color: row.playingNow ? app.accent : app.textPrimary
            font.pixelSize: 19
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: (row.queued ? (app.dlKey === row.tKey ? qsTr("İniyor %") + app.dlPercent + "  •  " : qsTr("İndirme sırada  •  ")) : "")
                  + row.tSinger + (row.tDuration > 0 ? "  •  " + U.dur(row.tDuration) : "")
            color: row.queued ? app.accent : app.textSecondary
            font.pixelSize: 15
            elide: Text.ElideRight
        }
    }
    Row {
        id: icons
        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
        spacing: 0
        Image { visible: row.downloaded; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; smooth: true; source: "../images/download_g.png" }
        Item { width: 6; height: 1; visible: row.downloaded }
        Image { visible: row.fav; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; smooth: true; source: "../images/heart_a.png" }
        IconButton { visible: !row.selectMode; icon: "more"; tone: "g"; iconSize: 24; width: 48; height: 56; onClicked: row.moreClicked() }
        Item { width: 10; height: 1; visible: row.selectMode }
    }
    Rectangle { anchors { left: lead.right; leftMargin: 12; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
    MouseArea {
        id: ma
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: icons.left }
        onClicked: row.clicked()
        onPressAndHold: row.pressAndHold()
    }
}
