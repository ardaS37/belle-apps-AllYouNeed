import QtQuick 1.1

// Calma listesi / albüm satiri. Model alanlari: listKey, name, singer, image, service (ya da yerel liste: n)
Item {
    id: row
    property string lKey: ""
    property string lName: ""
    property string lSinger: ""
    property string lImage: ""
    property bool isCurrent: false
    property string info: ""
    property bool showFav: true
    signal clicked
    signal pressAndHold
    signal moreClicked
    width: ListView.view ? ListView.view.width : 400
    height: 80
    property bool fav: showFav && app.favListsVersion >= 0 && row.lKey !== "" && app.isFavList(row.lKey)

    Rectangle { anchors.fill: parent; color: ma.pressed ? app.pressed : (row.isCurrent ? app.surface : "transparent") }
    Rectangle { visible: row.isCurrent; width: 4; height: parent.height; color: app.accent }
    Cover { id: cv; anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter } size: 64; source: row.lImage }
    Column {
        anchors { left: cv.right; leftMargin: 14; right: more.left; rightMargin: 4; verticalCenter: parent.verticalCenter }
        spacing: 3
        Text { width: parent.width; text: row.lName; color: app.textPrimary; font.pixelSize: 19; font.bold: true; elide: Text.ElideRight }
        Text {
            width: parent.width
            text: row.info !== "" ? row.info : row.lSinger
            color: app.textSecondary; font.pixelSize: 15; elide: Text.ElideRight
            visible: text !== ""
        }
    }
    Image { visible: row.fav; anchors { right: more.left; verticalCenter: parent.verticalCenter } width: 20; height: 20; smooth: true; source: "../images/heart_a.png" }
    IconButton { id: more; anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter } icon: "more"; tone: "g"; iconSize: 24; width: 48; onClicked: row.moreClicked() }
    Rectangle { anchors { left: cv.right; leftMargin: 14; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
    MouseArea { id: ma; anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: more.left } onClicked: row.clicked(); onPressAndHold: row.pressAndHold() }
}
