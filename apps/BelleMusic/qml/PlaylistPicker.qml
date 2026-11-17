import QtQuick 1.1

// "Listeye ekle": kendi listelerimden biri ya da yeni liste
Rectangle {
    id: root
    color: "#99000000"

    function reload() {
        lists.clear();
        lists.append({ pid: 0, name: "Yeni liste oluştur", n: -1 });
        var arr = app.myPlaylists();
        for (var i = 0; i < arr.length; i++) lists.append({ pid: arr[i].id, name: arr[i].name, n: arr[i].n });
        list.currentIndex = 0;
        focusTimer.restart();
    }
    Timer { id: focusTimer; interval: 30; onTriggered: list.forceActiveFocus() }
    ListModel { id: lists }
    function close() { app.pickerOpen = false; app.focusTop(); }

    MouseArea { anchors.fill: parent; onClicked: root.close() }
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Math.min(parent.height - 40, 70 + lists.count * 62)
        radius: 16
        color: app.surface
        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 16; color: app.surface }
        MouseArea { anchors.fill: parent }
        Text { id: ttl; anchors { left: parent.left; leftMargin: 20; top: parent.top; topMargin: 18 } text: qsTr("Listeye ekle"); color: app.textPrimary; font.pixelSize: 21; font.bold: true }
        ListView {
            id: list
            anchors { left: parent.left; right: parent.right; top: ttl.bottom; topMargin: 10; bottom: parent.bottom }
            clip: true
            model: lists
            keyNavigationWraps: true
            delegate: Item {
                width: list.width
                height: 62
                Rectangle { anchors.fill: parent; color: ma.pressed ? app.pressed : (ListView.isCurrentItem && list.activeFocus ? app.surface2 : "transparent") }
                Rectangle {
                    id: ic
                    anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                    width: 44; height: 44; radius: 6
                    color: model.pid === 0 ? app.accent : app.surface2
                    Image { anchors.centerIn: parent; width: 26; height: 26; smooth: true; source: model.pid === 0 ? "../images/plus_w.png" : "../images/list_w.png" }
                }
                Column {
                    anchors { left: ic.right; leftMargin: 14; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    Text { width: parent.width; text: model.name; color: app.textPrimary; font.pixelSize: 19; elide: Text.ElideRight }
                    Text { visible: model.n >= 0; text: model.n + qsTr(" şarkı"); color: app.textSecondary; font.pixelSize: 14 }
                }
                MouseArea { id: ma; anchors.fill: parent; onClicked: app.pickedPlaylist(model.pid) }
            }
            Keys.onReturnPressed: app.pickedPlaylist(lists.get(currentIndex).pid)
            Keys.onEnterPressed: app.pickedPlaylist(lists.get(currentIndex).pid)
            Keys.onSelectPressed: app.pickedPlaylist(lists.get(currentIndex).pid)
            Keys.onPressed: if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Escape) { root.close(); event.accepted = true; }
        }
    }
}
