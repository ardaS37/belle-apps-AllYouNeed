import QtQuick 1.1

// Posta: gelen kutusundaki son 5 e-postanin basligi (sunucudaki /mail/api/list).
// Dokununca kisa onizleme acilir/kapanir. Yeni posta bildirimi gelince kendiliginden yenilenir.
Rectangle {
    id: root
    color: app.bg
    property bool busy: false
    property bool loadedOnce: false
    property string lastError: ""
    property string account: ""
    property int unseen: 0
    property int openIndex: -1

    function takeFocus() { list.forceActiveFocus(); if (list.currentIndex < 0 && mailModel.count > 0) list.currentIndex = 0; }
    function loadIfEmpty() { if (!loadedOnce) refresh(true); }

    // E-postalar ve Drive'a yuklenen dosyalar zamana gore karisik; en yeni 5'i gosterilir
    property variant mails: []
    property variant drives: []
    property int pending: 0

    function pad2(n) { return n < 10 ? "0" + n : "" + n; }
    function shortTime(ts) {
        var d = new Date(ts), now = new Date();
        if (d.toDateString() === now.toDateString()) return pad2(d.getHours()) + ":" + pad2(d.getMinutes());
        return pad2(d.getDate()) + "." + pad2(d.getMonth() + 1);
    }
    function sizeText(b) { return b >= 1048576 ? (b / 1048576).toFixed(1) + qsTr(" MB") : (b > 0 ? Math.max(1, Math.round(b / 1024)) + qsTr(" KB") : ""); }

    function rebuild() {
        var all = [];
        var i;
        for (i = 0; i < mails.length; i++) all.push(mails[i]);
        for (i = 0; i < drives.length; i++) all.push(drives[i]);
        all.sort(function (a, b) { return b.ts - a.ts; });
        mailModel.clear();
        openIndex = -1;
        for (i = 0; i < all.length && i < 5; i++) mailModel.append(all[i]);
        if (list.activeFocus && mailModel.count > 0 && list.currentIndex < 0) list.currentIndex = 0;
    }
    function doneOne() {
        pending--;
        if (pending > 0) return;
        busy = false;
        loadedOnce = true;
        rebuild();
    }

    function refresh(silent) {
        if (busy) return;
        busy = true;
        pending = 2;
        app.apiMail(function (d) {
            lastError = "";
            account = d.user ? d.user : "";
            unseen = d.unseen ? d.unseen : 0;
            var items = d.items ? d.items : [];
            var arr = [];
            for (var i = 0; i < items.length && i < 5; i++) {
                var m = items[i];
                arr.push({ from: m.from ? m.from : (m.fromAddr ? m.fromAddr : "?"), subject: m.subject ? m.subject : qsTr("(konu yok)"),
                           snippet: m.snippet ? m.snippet : "", date: m.date ? m.date : "", unread: m.unread ? true : false,
                           ts: m.ts ? m.ts : 0, drive: false });
            }
            mails = arr;
            doneOne();
        }, function (msg) {
            lastError = msg;
            if (!silent) app.showToast(msg);
            doneOne();
        });
        app.apiDriveRecent(function (items) {
            var arr = [];
            for (var i = 0; i < items.length && i < 5; i++) {
                var f = items[i];
                arr.push({ from: qsTr("Google Drive"), subject: qsTr("Dosya yüklendi: ") + f.name, snippet: sizeText(f.size),
                           date: shortTime(f.ts), unread: false, ts: f.ts, drive: true });
            }
            drives = arr;
            doneOne();
        }, function () { doneOne(); });
    }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: qsTr("Posta")
        subtitle: root.account !== "" ? root.account + (root.unseen > 0 ? "  •  " + root.unseen + qsTr(" okunmamış") : "") : ""
        busy: root.busy
        IconButton { source: "../images/refresh" + app.iconTone + ".png"; onClicked: root.refresh(false) }
    }

    ListModel { id: mailModel }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        model: mailModel
        clip: true
        currentIndex: -1
        keyNavigationWraps: false
        Keys.onLeftPressed: { app.stepTab(-1); event.accepted = true; }
        Keys.onRightPressed: { app.stepTab(1); event.accepted = true; }
        Keys.onReturnPressed: root.openIndex = (root.openIndex === currentIndex ? -1 : currentIndex)
        Keys.onEnterPressed: root.openIndex = (root.openIndex === currentIndex ? -1 : currentIndex)
        Keys.onSelectPressed: root.openIndex = (root.openIndex === currentIndex ? -1 : currentIndex)
        delegate: Item {
            id: row
            width: list.width
            height: col.height + 28
            property bool expanded: root.openIndex === index
            property bool cur: ListView.isCurrentItem && list.activeFocus

            Rectangle { anchors.fill: parent; color: ma.pressed || row.cur ? app.pressed : app.bg }
            Rectangle { visible: row.cur; width: 4; height: parent.height; color: app.brand }
            Column {
                id: col
                x: 20; y: 14
                width: parent.width - 40
                spacing: 4
                Item {
                    width: parent.width
                    height: fromText.height
                    Text {
                        id: fromText
                        anchors { left: parent.left; right: dateText.left; rightMargin: 10 }
                        text: from
                        textFormat: Text.PlainText
                        color: app.textPrimary
                        font.pixelSize: 21
                        font.bold: unread
                        elide: Text.ElideRight
                    }
                    Text {
                        id: dateText
                        anchors { right: parent.right; verticalCenter: fromText.verticalCenter }
                        text: date
                        color: unread ? app.brand : app.textSecondary
                        font.pixelSize: 16
                        font.bold: unread
                    }
                }
                Text {
                    width: parent.width
                    text: subject
                    textFormat: Text.PlainText
                    color: unread ? app.textPrimary : app.textSecondary
                    font.pixelSize: 19
                    font.bold: unread
                    wrapMode: Text.Wrap
                    maximumLineCount: row.expanded ? 4 : 1
                    elide: Text.ElideRight
                }
                Text {
                    visible: snippet !== ""
                    width: parent.width
                    text: snippet
                    textFormat: Text.PlainText
                    color: app.textSecondary
                    font.pixelSize: 17
                    wrapMode: Text.Wrap
                    maximumLineCount: row.expanded ? 8 : 1
                    elide: Text.ElideRight
                }
            }
            Rectangle { anchors { left: parent.left; leftMargin: 20; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
            MouseArea {
                id: ma
                anchors.fill: parent
                onClicked: { list.currentIndex = index; root.openIndex = row.expanded ? -1 : index; }
            }
        }
        footer: Item {
            width: list.width
            height: mailModel.count > 0 ? 70 : 0
            Text {
                visible: mailModel.count > 0
                anchors.centerIn: parent
                width: parent.width - 60
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: qsTr("Son 5 e-posta ve Drive yüklemesi. Tamamı için Mail ve Drive uygulamalarını kullanın.")
                color: app.textSecondary
                font.pixelSize: 16
            }
        }
    }

    Column {
        anchors.centerIn: list
        width: parent.width - 80
        spacing: 10
        visible: mailModel.count === 0
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.busy ? qsTr("Yükleniyor...") : (root.lastError !== "" ? qsTr("Posta alınamadı") : (root.loadedOnce ? qsTr("Gelen kutusu boş") : ""))
            color: app.textPrimary
            font.pixelSize: 22
            font.bold: true
        }
        Text {
            visible: root.lastError !== "" && !root.busy
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: root.lastError
            color: app.textSecondary
            font.pixelSize: 18
        }
    }
}
