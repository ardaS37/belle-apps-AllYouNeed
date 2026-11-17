import QtQuick 1.1

// Alttan acilan secenek listesi. Klavye: yukari/asagi, Enter/orta tus secer, Geri kapatir.
Rectangle {
    id: root
    color: "#99000000"
    property string title: ""

    function show(t, actions) {
        title = t;
        acts.clear();
        for (var i = 0; i < actions.length; i++) acts.append({ label: actions[i].label, icon: actions[i].icon || "", act: actions[i].act });
        list.currentIndex = 0;
        focusTimer.restart();
    }
    Timer { id: focusTimer; interval: 30; onTriggered: list.forceActiveFocus() }

    ListModel { id: acts }
    MouseArea { anchors.fill: parent; onClicked: app.closeSheet() }

    Rectangle {
        id: panel
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Math.min(parent.height - 40, 64 + acts.count * 58 + 10)
        color: app.surface
        radius: 16
        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 16; color: app.surface }
        MouseArea { anchors.fill: parent }
        Text {
            id: ttl
            anchors { left: parent.left; leftMargin: 20; right: parent.right; rightMargin: 20; top: parent.top; topMargin: 18 }
            text: root.title; color: app.textSecondary; font.pixelSize: 17; elide: Text.ElideRight
        }
        ListView {
            id: list
            anchors { left: parent.left; right: parent.right; top: ttl.bottom; topMargin: 10; bottom: parent.bottom }
            clip: true
            model: acts
            keyNavigationWraps: true
            delegate: Item {
                width: list.width
                height: 58
                Rectangle { anchors.fill: parent; color: ma.pressed ? app.pressed : (ListView.isCurrentItem && list.activeFocus ? app.surface2 : "transparent") }
                Image { id: ic; visible: model.icon !== ""; anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter } width: 26; height: 26; smooth: true; source: model.icon !== "" ? "../images/" + model.icon + "_w.png" : "" }
                Text { anchors { left: parent.left; leftMargin: 62; right: parent.right; verticalCenter: parent.verticalCenter } text: model.label; color: app.textPrimary; font.pixelSize: 19; elide: Text.ElideRight }
                MouseArea { id: ma; anchors.fill: parent; onClicked: app.sheetChosen(model.act) }
            }
            Keys.onReturnPressed: app.sheetChosen(acts.get(currentIndex).act)
            Keys.onEnterPressed: app.sheetChosen(acts.get(currentIndex).act)
            Keys.onSelectPressed: app.sheetChosen(acts.get(currentIndex).act)
            Keys.onBackPressed: app.closeSheet()
            Keys.onPressed: if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Escape) { app.closeSheet(); event.accepted = true; }
        }
    }
}
