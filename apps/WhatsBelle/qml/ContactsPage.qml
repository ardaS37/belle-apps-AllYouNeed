import QtQuick 1.1
import "Util.js" as Util

// Kisiler (sunucudaki secili kisiler listesi)
Rectangle {
    id: root
    color: app.bg
    property bool busy: false
    property int page: 0
    property int total: 0
    property string query: ""
    property string lastError: ""
    property bool loadedOnce: false

    function takeFocus() { list.forceActiveFocus(); if (list.currentIndex < 0 && contactModel.count > 0) list.currentIndex = 0; }
    function openAt(i) { if (i >= 0 && i < contactModel.count) app.openChat(contactModel.get(i).cid, contactModel.get(i).name); }

    function clear() { contactModel.clear(); page = 0; total = 0; loadedOnce = false; }   // hesap degisince
    function loadIfEmpty() {
        if (contactModel.count === 0 && !busy) load(true);
    }

    function load(fresh) {
        if (busy) return;
        if (fresh) { page = 0; }
        busy = true;
        var q = query;
        app.apiContacts(q, page, function (contacts, count) {
            busy = false;
            loadedOnce = true;
            lastError = "";
            if (q !== query) return;
            if (fresh) contactModel.clear();
            total = count;
            for (var i = 0; i < contacts.length; i++) {
                var c = contacts[i];
                contactModel.append({ cid: c.id, name: c.name ? c.name : Util.bareId(c.id) });
            }
        }, function (msg) {
            busy = false;
            loadedOnce = true;
            lastError = msg;
            app.showToast(msg);
        });
    }

    Timer { id: searchDelay; interval: 600; onTriggered: root.load(true) }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: qsTr("Kişiler")
        subtitle: root.total > 0 ? root.total + qsTr(" kişi") : ""
        busy: root.busy
        IconButton { source: "../images/refresh" + app.iconTone + ".png"; onClicked: root.load(true) }
    }

    Item {
        id: searchBar
        anchors { left: parent.left; right: parent.right; top: header.bottom }
        height: 72
        TextField {
            id: searchField
            anchors { fill: parent; leftMargin: 16; rightMargin: 16; topMargin: 8; bottomMargin: 8 }
            placeholder: qsTr("İsim ara...")
            onTextChanged: { root.query = text; searchDelay.restart(); }
            onAccepted: { searchDelay.stop(); root.load(true); }
            Keys.onDownPressed: root.takeFocus()
        }
    }

    ListModel { id: contactModel }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: searchBar.bottom; bottom: parent.bottom }
        model: contactModel
        clip: true
        currentIndex: -1
        Keys.onLeftPressed: { app.stepTab(-1); event.accepted = true; }
        Keys.onRightPressed: { app.stepTab(1); event.accepted = true; }
        Keys.onUpPressed: { if (currentIndex <= 0) searchField.focusInput(); else decrementCurrentIndex(); event.accepted = true; }
        Keys.onReturnPressed: root.openAt(currentIndex)
        Keys.onEnterPressed: root.openAt(currentIndex)
        Keys.onSelectPressed: root.openAt(currentIndex)
        // Harf yazilinca arama kutusuna gec
        Keys.onPressed: {
            if (event.text.length === 1 && event.text > " " && !(event.modifiers & Qt.ControlModifier)) {
                searchField.input.forceActiveFocus();
                searchField.text = searchField.text + event.text;
                searchField.input.cursorPosition = searchField.text.length;
                event.accepted = true;
            }
        }
        delegate: Item {
            width: list.width
            height: 80
            Rectangle { anchors.fill: parent; color: ma.pressed || (parent.ListView.isCurrentItem && list.activeFocus) ? app.pressed : app.bg }
            Rectangle { visible: parent.ListView.isCurrentItem && list.activeFocus; width: 4; height: parent.height; color: app.brand }
            Avatar {
                id: av
                anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                name: model.name
                key: cid
                peer: cid
                size: 54
            }
            Column {
                anchors { left: av.right; leftMargin: 16; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                Text {
                    width: parent.width
                    text: model.name
                    color: app.textPrimary
                    font.pixelSize: 23
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: "+" + Util.bareId(cid)
                    color: app.textSecondary
                    font.pixelSize: 18
                    elide: Text.ElideRight
                }
            }
            Rectangle {
                anchors { left: av.right; leftMargin: 16; right: parent.right; bottom: parent.bottom }
                height: 1
                color: app.divider
            }
            MouseArea {
                id: ma
                anchors.fill: parent
                onClicked: app.openChat(cid, model.name)
            }
        }
        footer: Item {
            width: list.width
            height: contactModel.count < root.total ? 80 : 0
            visible: height > 0
            Rectangle {
                anchors.centerIn: parent
                width: 240
                height: 52
                radius: 26
                color: moreMa.pressed ? app.pressed : app.pill
                Text {
                    anchors.centerIn: parent
                    text: root.busy ? qsTr("Yükleniyor...") : qsTr("Daha fazla göster")
                    color: app.accentText
                    font.pixelSize: 20
                    font.bold: true
                }
                MouseArea {
                    id: moreMa
                    anchors.fill: parent
                    onClicked: { root.page = root.page + 1; root.load(false); }
                }
            }
        }
    }

    Text {
        anchors.centerIn: list
        width: parent.width - 80
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        visible: root.loadedOnce && contactModel.count === 0 && !root.busy
        text: root.lastError !== "" ? root.lastError : qsTr("Kişi bulunamadı.")
        color: app.textSecondary
        font.pixelSize: 20
    }
}
