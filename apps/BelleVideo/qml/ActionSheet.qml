import QtQuick 1.1
import "SheetState.js" as St

// Secenek listesi (alttan acilan). open(baslik, [{label, icon, key, danger}], geriCagirma(key))
// Klavye: yukari/asagi, Enter secer, Geri/Esc kapatir.
Rectangle {
    id: root
    property string title: ""
    property Item returnFocus: null
    property bool shown: false

    anchors.fill: parent
    color: "#99000000"
    visible: shown
    z: 60

    function open(t, items, cb) {
        returnFocus = null;
        title = t;
        sheetModel.clear();
        for (var i = 0; i < items.length; i++)
            sheetModel.append({ label: items[i].label, icon: items[i].icon || "", key: items[i].key, danger: !!items[i].danger });
        St.cb = cb;
        list.currentIndex = 0;
        shown = true;
        list.forceActiveFocus();
        topTimer.restart();
    }
    // Panel yuksekligi model dolunca degisiyor; liste en basa sonra alinir
    Timer { id: topTimer; interval: 30; onTriggered: { list.positionViewAtIndex(0, ListView.Beginning); list.currentIndex = 0; } }
    function close() {
        shown = false;
        app.focusTab();
    }
    function choose(i) {
        var k = sheetModel.get(i).key;
        var cb = St.cb;
        St.cb = null;
        close();
        if (cb) cb(k);
    }

    ListModel { id: sheetModel }

    MouseArea { anchors.fill: parent; onClicked: root.close() }

    Rectangle {
        id: panel
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 40; rightMargin: 40 }
        height: Math.min(root.height - 40, head.height + sheetModel.count * 50 + 8)
        radius: 14
        color: app.surface
        MouseArea { anchors.fill: parent }

        Text {
            id: head
            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 18; rightMargin: 18 }
            height: 46
            verticalAlignment: Text.AlignVCenter
            text: root.title
            textFormat: Text.PlainText
            color: app.textSecondary
            font.pixelSize: 16
            elide: Text.ElideMiddle
        }
        ListView {
            id: list
            anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; bottomMargin: 8 }
            clip: true
            model: sheetModel
            interactive: sheetModel.count * 50 > height
            delegate: Item {
                id: drow
                property bool cur: ListView.isCurrentItem
                width: list.width
                height: 50
                Rectangle {
                    anchors.fill: parent
                    color: rowMa.pressed ? app.pressed : (drow.cur ? app.highlight : "transparent")
                }
                Image {
                    id: ic
                    visible: icon !== ""
                    anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                    width: 24; height: 24; smooth: true
                    source: icon === "" ? "" : "../images/" + icon + (danger ? "_g" : "_a") + ".png"
                }
                Text {
                    anchors { left: parent.left; leftMargin: 56; verticalCenter: parent.verticalCenter }
                    text: label
                    color: danger ? app.danger : app.textPrimary
                    font.pixelSize: 18
                }
                MouseArea { id: rowMa; anchors.fill: parent; onClicked: root.choose(index) }
            }
            Keys.onPressed: {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) { root.choose(currentIndex); event.accepted = true; }
                else if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Escape || event.key === Qt.Key_Left) { root.close(); event.accepted = true; }
                else if (event.key === Qt.Key_Right) event.accepted = true;
            }
        }
    }
}
