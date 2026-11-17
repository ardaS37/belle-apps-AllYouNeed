import QtQuick 1.1
import "Util.js" as Util

// Sohbet listesi
Rectangle {
    id: root
    color: app.bg
    property bool busy: false
    property bool loadedOnce: false
    property string lastError: ""
    property string filter: ""
    property bool more: false           // sunucuda daha eski sohbet var
    function loadMore() { if (busy || !more) return; app.moreChats(); refresh(false); }

    function clear() { chatModel.clear(); loadedOnce = false; }
    function takeFocus() { list.forceActiveFocus(); if (list.currentIndex < 0 && chatModel.count > 0) list.currentIndex = 0; }
    function openAt(i) {
        if (i < 0 || i >= chatModel.count) return;
        var c = chatModel.get(i);
        app.markSeen(c.peer, c.ts);
        chatModel.setProperty(i, "unread", false);
        app.openChat(c.peer, c.name);
    }

    function refresh(silent) {
        if (busy) return;
        busy = true;
        app.apiChats(function (chats, hasMore) {
            busy = false;
            more = !!hasMore;
            loadedOnce = true;
            lastError = "";
            fill(chats);
        }, function (msg, status) {
            busy = false;
            loadedOnce = true;
            lastError = msg;
            if (!silent || status === 401) app.showToast(msg);
        });
    }

    function fill(chats) {
        var seen = {};
        var rows = [];
        for (var i = 0; i < chats.length; i++) {
            var c = chats[i];
            if (seen[c.sender]) continue;
            seen[c.sender] = true;
            rows.push(c);
        }
        var keep = list.currentIndex;
        chatModel.clear();
        for (var j = 0; j < rows.length; j++) {
            var r = rows[j];
            var name = r.senderName ? r.senderName : Util.bareId(r.sender);
            var unread;
            if (r.unreadCount !== undefined) unread = r.unreadCount > 0;
            else unread = !r.fromMe && r.createdAt && r.createdAt > app.seenTs(r.sender);
            chatModel.append({
                peer: r.sender,
                name: name,
                preview: r.message ? r.message : "",
                ts: r.createdAt ? r.createdAt : "",
                unread: unread ? true : false,
                unreadCount: r.unreadCount ? r.unreadCount : 0
            });
        }
        if (keep >= 0) list.currentIndex = Math.min(keep, chatModel.count - 1);
    }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: qsTr("WhatsBelle")
        subtitle: app.ikiHesap ? app.hesapAd(app.aktif) : ""
        brandTitle: true
        busy: root.busy
        onTitleClicked: if (app.ikiHesap) app.hesapDegistir()
        // Iki hesap: W² dugmesi etkin hesabi degistirir
        Rectangle {
            visible: app.ikiHesap
            anchors.verticalCenter: parent.verticalCenter
            width: 70; height: 44; radius: 22
            color: w2Ma.pressed ? app.pressed : app.pill
            Text { anchors.centerIn: parent; text: "W²"; color: app.accentText; font.pixelSize: 24; font.bold: true }
            Text { anchors { right: parent.right; rightMargin: 6; bottom: parent.bottom; bottomMargin: 2 } text: "" + app.aktif; color: app.textSecondary; font.pixelSize: 12; font.bold: true }
            MouseArea { id: w2Ma; anchors.fill: parent; onClicked: app.hesapDegistir() }
        }
        IconButton { source: "../images/search" + app.iconTone + ".png"; onClicked: { searchBar.visible = !searchBar.visible; if (searchBar.visible) searchField.focusInput(); else root.filter = ""; } }
        IconButton { source: "../images/refresh" + app.iconTone + ".png"; onClicked: root.refresh(false) }
    }

    Rectangle {
        id: searchBar
        anchors { left: parent.left; right: parent.right; top: header.bottom }
        height: visible ? 72 : 0
        visible: false
        color: app.bg
        TextField {
            id: searchField
            anchors { fill: parent; leftMargin: 16; rightMargin: 16; topMargin: 8; bottomMargin: 8 }
            placeholder: qsTr("Ara...")
            onTextChanged: root.filter = text.toLowerCase()
        }
    }

    ListModel { id: chatModel }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: searchBar.bottom; bottom: parent.bottom }
        model: chatModel
        clip: true
        currentIndex: -1
        Keys.onLeftPressed: { app.stepTab(-1); event.accepted = true; }
        Keys.onRightPressed: { app.stepTab(1); event.accepted = true; }
        // Son sohbetteyken asagi: daha eski sohbetleri getir
        Keys.onDownPressed: {
            if (currentIndex >= chatModel.count - 1) root.loadMore();
            else currentIndex = currentIndex + 1;
            event.accepted = true;
        }
        Keys.onReturnPressed: root.openAt(currentIndex)
        Keys.onEnterPressed: root.openAt(currentIndex)
        Keys.onSelectPressed: root.openAt(currentIndex)
        footer: Item {
            width: list.width
            height: root.more && root.filter === "" ? 84 : 0
            visible: height > 0
            Rectangle {
                anchors.centerIn: parent
                width: moreText.paintedWidth + 48; height: 52; radius: 26
                color: moreMa.pressed ? app.pressed : app.surface
                border.width: 1; border.color: app.divider
                Text { id: moreText; anchors.centerIn: parent; text: root.busy ? qsTr("Yükleniyor...") : qsTr("Daha eski sohbetler"); color: app.brand; font.pixelSize: 20; font.bold: true }
                MouseArea { id: moreMa; anchors.fill: parent; onClicked: root.loadMore() }
            }
        }
        delegate: Item {
            property bool match: root.filter === "" || name.toLowerCase().indexOf(root.filter) >= 0 || preview.toLowerCase().indexOf(root.filter) >= 0
            width: list.width
            height: match ? 88 : 0
            visible: match

            Rectangle { anchors.fill: parent; color: ma.pressed || (parent.ListView.isCurrentItem && list.activeFocus) ? app.pressed : app.bg }
            Rectangle { visible: parent.ListView.isCurrentItem && list.activeFocus; width: 4; height: parent.height; color: app.brand }
            Avatar {
                id: av
                anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                name: model.name
                key: peer
                peer: model.peer
                size: 58
            }
            Text {
                id: timeText
                anchors { right: parent.right; rightMargin: 20; top: parent.top; topMargin: 18 }
                text: Util.listTime(ts)
                color: unread ? app.brand : app.textSecondary
                font.pixelSize: 17
                font.bold: unread
            }
            Text {
                anchors { left: av.right; leftMargin: 16; right: timeText.left; rightMargin: 10; top: parent.top; topMargin: 15 }
                text: model.name
                color: app.textPrimary
                font.pixelSize: 24
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                anchors { left: av.right; leftMargin: 16; right: badge.left; rightMargin: 10; bottom: parent.bottom; bottomMargin: 16 }
                text: preview.replace(/\n/g, " ")
                textFormat: Text.PlainText
                color: unread ? app.textPrimary : app.textSecondary
                font.pixelSize: 20
                elide: Text.ElideRight
            }
            Rectangle {
                id: badge
                anchors { right: parent.right; rightMargin: 18; bottom: parent.bottom; bottomMargin: 14 }
                width: unread ? Math.max(26, badgeText.paintedWidth + 14) : 0
                height: 26
                radius: 13
                color: app.brand
                visible: unread
                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: unreadCount > 99 ? "99+" : (unreadCount > 0 ? unreadCount : "")
                    color: app.dark ? "#0B141A" : "#FFFFFF"
                    font.pixelSize: 15
                    font.bold: true
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
                onClicked: {
                    app.markSeen(peer, ts);
                    chatModel.setProperty(index, "unread", false);
                    app.openChat(peer, model.name);
                }
            }
        }
    }

    Column {
        anchors.centerIn: list
        width: parent.width - 80
        spacing: 10
        visible: root.loadedOnce && chatModel.count === 0
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.lastError !== "" ? qsTr("Sohbetler yüklenemedi") : qsTr("Henüz sohbet yok")
            color: app.textPrimary
            font.pixelSize: 24
            font.bold: true
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: root.lastError !== "" ? root.lastError : qsTr("Yeni sohbet başlatmak için sağ alttaki düğmeye dokunun.")
            color: app.textSecondary
            font.pixelSize: 19
        }
    }

    Rectangle {
        anchors { right: parent.right; bottom: parent.bottom; rightMargin: 22; bottomMargin: 18 }
        width: 68
        height: 68
        radius: 18
        color: fab.pressed ? app.brandPressed : app.brand
        smooth: true
        Image {
            anchors.centerIn: parent
            width: 38
            height: 38
            smooth: true
            source: "../images/newchat.png"
        }
        MouseArea {
            id: fab
            anchors.fill: parent
            onClicked: { app.tab = 1; contactsPage.loadIfEmpty(); }
        }
    }
}
