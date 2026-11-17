import QtQuick 1.1
import "Posta.js" as P

// Yeni posta / yanit / iletme. Yanit ve iletme taslagi (alintili metin) asil postadan telefonda hazirlanir.
Rectangle {
    id: page
    property string ref: ""
    property string fromText: ""
    property bool loading: false
    property bool sending: false
    property string original: ""        // degisiklik var mi kontrolu icin
    property string title: qsTr("Yeni posta")

    signal closed

    color: "#ffffff"
    visible: false
    z: 60

    function current() { return toField.text + "\u0001" + subjField.text + "\u0001" + bodyEdit.text; }

    // mode: "new" | "re" | "all" | "fw" | "to" (f: alici adresi)
    function open(mode, f, uid) {
        ref = ""; toField.text = ""; subjField.text = ""; bodyEdit.text = ""; sending = false;
        title = mode === "re" ? qsTr("Yanıtla") : (mode === "all" ? qsTr("Tümünü yanıtla") : (mode === "fw" ? qsTr("İlet") : qsTr("Yeni posta")));
        if (mode === "to") toField.text = f;
        visible = true;
        var h = mail.hesap();
        fromText = h.name && h.name !== "" ? h.name + " <" + h.user + ">" : h.user;
        original = current();
        if (mode === "new" || mode === "to") {
            loading = false;
            if (mode === "new") { toField.forceActiveFocus(); toField.openSoftwareInputPanel(); }
            else focusEditor();
            return;
        }
        loading = true;
        app.istek("mesaj", { f: f, uid: uid, okundu: false }, function (ok, j) {
            loading = false;
            if (!ok) { app.toast(j.error); return; }
            var t = P.taslak(mode === "all" ? "all" : (mode === "fw" ? "fw" : "re"), j, mail.kullanici);
            toField.text = t.to; subjField.text = t.subject; bodyEdit.text = t.body; ref = t.ref;
            original = current();
            bodyEdit.cursorPosition = 0;
            if (toField.text === "") { toField.forceActiveFocus(); toField.openSoftwareInputPanel(); }
            else focusEditor();
        });
    }
    function focusEditor() { bodyEdit.forceActiveFocus(); }
    function close() {
        toField.closeSoftwareInputPanel();
        visible = false;
        closed();
    }
    function tryClose() {
        if (current() !== original && (bodyEdit.text.replace(/\s+/g, "") !== "" || subjField.text !== "")) dialog.open(qsTr("Taslak silinsin mi?"), qsTr("Yazdıklarınız kaydedilmeyecek."), qsTr("Sil"), false, "discard", true);
        else close();
    }
    function send() {
        if (sending) return;
        mail.girisiTamamla();
        var to = toField.text.replace(/^\s+|\s+$/g, "");
        if (to.indexOf("@") < 0) { app.toast(qsTr("Alıcı adresi girin")); toField.forceActiveFocus(); return; }
        sending = true;
        app.istek("gonder", { to: to, subject: subjField.text, body: bodyEdit.text, ref: ref }, function (ok, j) {
            sending = false;
            if (!ok) { app.toast(qsTr("Gönderilemedi: ") + j.error); return; }
            app.toast(qsTr("Gönderildi"));
            page.close();
        });
    }

    MouseArea { anchors.fill: parent }

    Rectangle {
        id: bar
        width: parent.width
        height: 56
        color: app.brand
        Btn { id: cancelBtn; flat: true; text: "✕"; fontSize: 22; anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter } onClicked: page.tryClose() }
        Text { anchors { left: cancelBtn.right; leftMargin: 8; verticalCenter: parent.verticalCenter } text: page.title; color: "#ffffff"; font.pixelSize: 22; font.bold: true }
        Rectangle {
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            width: sendT.paintedWidth + 32; height: 42; radius: 21
            color: sm.pressed ? "#f1f3f4" : "#ffffff"
            opacity: page.sending ? 0.6 : 1
            Text { id: sendT; anchors.centerIn: parent; text: page.sending ? qsTr("Gönderiliyor…") : qsTr("Gönder ➤"); color: app.brand; font.pixelSize: 19; font.bold: true }
            MouseArea { id: sm; anchors.fill: parent; onClicked: page.send() }
        }
    }

    // Kimden / Kime / Konu
    Column {
        id: fields
        anchors { top: bar.bottom; left: parent.left; right: parent.right }
        Item {
            width: parent.width; height: 40
            visible: page.fromText !== ""
            Text { anchors { left: parent.left; leftMargin: 16; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter } text: qsTr("Kimden: ") + page.fromText; textFormat: Text.PlainText; font.pixelSize: 15; color: app.textSecondary; elide: Text.ElideRight }
        }
        Rectangle { width: parent.width; height: 1; color: app.divider }
        Item {
            width: parent.width; height: 50
            Text { id: toL; anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter } text: qsTr("Kime"); font.pixelSize: 17; color: app.textSecondary; width: 64 }
            TextInput {
                id: toField
                anchors { left: toL.right; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                font.pixelSize: 19; color: app.textPrimary
                inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                KeyNavigation.down: subjField
                Keys.onReturnPressed: subjField.forceActiveFocus()
                Keys.onEscapePressed: page.tryClose()
            }
            MouseArea { anchors.fill: parent; enabled: !toField.activeFocus; onClicked: { toField.forceActiveFocus(); toField.openSoftwareInputPanel(); } }
        }
        Rectangle { width: parent.width; height: 1; color: app.divider }
        Item {
            width: parent.width; height: 50
            Text { id: sbL; anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter } text: qsTr("Konu"); font.pixelSize: 17; color: app.textSecondary; width: 64 }
            TextInput {
                id: subjField
                anchors { left: sbL.right; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                font.pixelSize: 19; color: app.textPrimary
                KeyNavigation.up: toField
                Keys.onReturnPressed: { bodyEdit.cursorPosition = 0; bodyEdit.forceActiveFocus(); }
                Keys.onEscapePressed: page.tryClose()
            }
            MouseArea { anchors.fill: parent; enabled: !subjField.activeFocus; onClicked: { subjField.forceActiveFocus(); subjField.openSoftwareInputPanel(); } }
        }
        Rectangle { width: parent.width; height: 1; color: app.divider }
    }

    // Metin
    Flickable {
        id: bodyFlick
        anchors { top: fields.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; margins: 14 }
        contentWidth: width
        contentHeight: Math.max(height, bodyEdit.paintedHeight + 40)
        clip: true
        function ensureVisible(r) {
            if (contentY >= r.y) contentY = r.y;
            else if (contentY + height <= r.y + r.height) contentY = r.y + r.height - height;
        }
        TextEdit {
            id: bodyEdit
            width: bodyFlick.width
            height: Math.max(bodyFlick.height, paintedHeight + 40)
            font.pixelSize: 19
            color: app.textPrimary
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.PlainText
            selectByMouse: false
            onCursorRectangleChanged: bodyFlick.ensureVisible(cursorRectangle)
            Keys.onEscapePressed: page.tryClose()
            Keys.onPressed: {
                // Ust satirdayken yukari ok: konu alanina gec
                if (event.key === Qt.Key_Up && cursorRectangle.y < 4) { subjField.forceActiveFocus(); event.accepted = true; }
            }
        }
        Text {
            visible: bodyEdit.text === "" && !bodyEdit.activeFocus
            text: page.loading ? qsTr("Hazırlanıyor…") : qsTr("Postanızı yazın")
            color: "#9aa0a6"; font.pixelSize: 19
        }
        MouseArea {
            anchors.fill: parent
            enabled: !bodyEdit.activeFocus
            onClicked: { bodyEdit.forceActiveFocus(); bodyEdit.openSoftwareInputPanel(); }
        }
    }
}
