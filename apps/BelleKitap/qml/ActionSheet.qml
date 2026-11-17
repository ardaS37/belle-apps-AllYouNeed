import QtQuick 1.1
import "SheetState.js" as St
import "Util.js" as U

// Secenek listesi (alttan acilan). open(baslik, [{label, icon, key, danger, hint}], geriCagirma(key))
// hint: sagda gri kisayol yazisi (ornek "Ctrl+S"). Klavye: yukari/asagi, Enter secer, Geri/Esc kapatir.
// Satirin ilk harfine basmak o satira atlar.
Rectangle {
    id: root
    property string title: ""
    property bool shown: false
    property int satir: Math.round(30 * app.yazi + 18)

    anchors.fill: parent
    color: "#99000000"
    visible: shown
    z: 60

    function open(t, items, cb) {
        title = t;
        sheetModel.clear();
        for (var i = 0; i < items.length; i++)
            sheetModel.append({ label: items[i].label, icon: items[i].icon || "", key: items[i].key,
                                danger: !!items[i].danger, hint: items[i].hint || "" });
        St.cb = cb;
        list.currentIndex = 0;
        shown = true;
        list.forceActiveFocus();
        topTimer.restart();
    }
    Timer { id: topTimer; interval: 30; onTriggered: { list.positionViewAtIndex(0, ListView.Beginning); list.currentIndex = 0; } }
    function close() {
        shown = false;
        St.cb = null;
        app.focusCurrent();
    }
    function choose(i) {
        if (i < 0 || i >= sheetModel.count) return;
        var k = sheetModel.get(i).key;
        var cb = St.cb;
        St.cb = null;
        shown = false;
        app.focusCurrent();
        if (cb) cb(k);
    }

    ListModel { id: sheetModel }

    MouseArea { anchors.fill: parent; onClicked: root.close() }

    Rectangle {
        id: panel
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 36; rightMargin: 36 }
        height: Math.min(root.height - 30, head.height + sheetModel.count * root.satir + 8)
        radius: 14
        color: app.surface
        MouseArea { anchors.fill: parent }

        Text {
            id: head
            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 18; rightMargin: 18 }
            height: 42
            verticalAlignment: Text.AlignVCenter
            text: root.title
            textFormat: Text.PlainText
            color: app.textSecondary
            font.pixelSize: Math.round(16 * app.yazi)
            elide: Text.ElideMiddle
        }
        ListView {
            id: list
            anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; bottomMargin: 8 }
            clip: true
            model: sheetModel
            interactive: sheetModel.count * root.satir > height
            highlightMoveDuration: 80
            delegate: Item {
                id: drow
                property bool cur: ListView.isCurrentItem
                width: list.width
                height: root.satir
                Rectangle {
                    anchors.fill: parent
                    color: rowMa.pressed ? app.pressed : (drow.cur ? app.highlight : "transparent")
                }
                Rectangle {
                    visible: drow.cur
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: 4
                    color: app.brand
                }
                Image {
                    id: ic
                    visible: icon !== ""
                    anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                    width: 24; height: 24; smooth: true
                    source: icon === "" ? "" : "../images/" + icon + (danger ? "_g" : "_a") + ".png"
                }
                Text {
                    anchors { left: parent.left; leftMargin: 56; right: hintText.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    text: label
                    textFormat: Text.PlainText
                    color: danger ? app.danger : app.textPrimary
                    font.pixelSize: Math.round(18 * app.yazi)
                    elide: Text.ElideRight
                }
                Text {
                    id: hintText
                    anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    text: hint
                    color: app.textSecondary
                    font.pixelSize: Math.round(14 * app.yazi)
                }
                MouseArea { id: rowMa; anchors.fill: parent; onClicked: root.choose(index) }
            }
            Keys.onPressed: {
                var k = event.key;
                // Qt 4.7: interactive=false iken ListView ok tuslarini islemez, elle yapilir
                if (k === Qt.Key_Down) { currentIndex = (currentIndex + 1) % sheetModel.count; positionViewAtIndex(currentIndex, ListView.Contain); event.accepted = true; }
                else if (k === Qt.Key_Up) { currentIndex = (currentIndex - 1 + sheetModel.count) % sheetModel.count; positionViewAtIndex(currentIndex, ListView.Contain); event.accepted = true; }
                else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) { root.choose(currentIndex); event.accepted = true; }
                else if (k === Qt.Key_Backspace || k === Qt.Key_Escape || k === Qt.Key_Left || k === Qt.Key_Context2) { root.close(); event.accepted = true; }
                else if (k === Qt.Key_Right) event.accepted = true;
                else if (U.tus(event) !== "") {
                    var c = U.tus(event);
                    // once kisayol ipucu (hint "R", "Ctrl+S" degil) eslesirse dogrudan sec
                    for (var h = 0; h < sheetModel.count; h++) {
                        var hn = sheetModel.get(h).hint;
                        if (hn && hn.length === 1 && U.fold(hn) === c) { root.choose(h); event.accepted = true; return; }
                    }
                    for (var n = 1; n <= sheetModel.count; n++) {
                        var j = (currentIndex + n) % sheetModel.count;
                        if (U.fold(sheetModel.get(j).label.charAt(0)) === c) { currentIndex = j; break; }
                    }
                    event.accepted = true;
                }
            }
        }
    }
}
