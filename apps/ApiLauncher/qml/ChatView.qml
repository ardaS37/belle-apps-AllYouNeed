import QtQuick 1.1
import "Md.js" as Md

// Bir saglayicinin sohbet ekrani: mesajlar, yazma kutusu, gecmis ve yeni sohbet
Rectangle {
    id: root
    color: app.bg
    property string provider: "claude"
    property string label: qsTr("Claude")
    property string badge: ""
    property int convId: 0
    property bool busy: false
    property bool historyOpen: false
    property string modelName: app.modelFor(provider)
    property string ekResim: ""          // gonderilecek fotografin yolu (bossa yok)
    property bool menuAcik: false

    // Odak once sohbettedir: yukari/asagi mesajlari kaydirir. Bir harfe basilinca yazma kutusuna
    // gecilir ve o harf yazilir. Yarim kalmis bir yazi varsa dogrudan yazma kutusuna donulur.
    function focusInput() { focusTimer.restart(); }
    Timer {
        id: focusTimer; interval: 200
        onTriggered: {
            if (!root.visible || root.historyOpen) return;
            if (composer.text.length > 0) composer.forceActiveFocus();
            else root.forceActiveFocus();
        }
    }
    onVisibleChanged: if (visible) focusInput()
    function startTyping(ch) {
        composer.forceActiveFocus();
        var pos = composer.text.length;
        composer.text = composer.text + ch;
        composer.cursorPosition = pos + ch.length;
    }
    Keys.onPressed: {
        if (event.text.length === 1 && event.text >= " " && event.text !== "\u007f"
                && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
            root.startTyping(event.text);
            event.accepted = true;
        } else if (event.key === Qt.Key_Backspace && composer.text.length > 0) {
            composer.forceActiveFocus();
            composer.cursorPosition = composer.text.length;
            event.accepted = true;
        }
    }

    function newChat() {
        if (busy) return;
        convId = 0;
        msgModel.clear();
        historyOpen = false;
        focusInput();
    }

    function openConv(id) {
        convId = id;
        msgModel.clear();
        var rows = app.loadMsgs(id);
        for (var i = 0; i < rows.length; i++) {
            var info = "";
            if (rows[i].role === "assistant") {
                info = rows[i].model;
                if (rows[i].ms) info += "  •  " + (rows[i].ms / 1000).toFixed(1) + qsTr(" sn");
            }
            msgModel.append({ role: rows[i].role, body: rows[i].text, info: info, img: rows[i].img || "" });
        }
        historyOpen = false;
        scrollEnd.restart();
        focusInput();
    }

    // Gecmis: yalnizca SON kullanici mesajindaki foto gonderilir (eski fotolar her seferinde tekrar yuklenmesin)
    function history() {
        var out = [];
        var sonFoto = -1;
        for (var i = 0; i < msgModel.count; i++) if (msgModel.get(i).role === "user" && msgModel.get(i).img !== "") sonFoto = i;
        for (i = 0; i < msgModel.count; i++) {
            var m = msgModel.get(i);
            if (m.role !== "user" && m.role !== "assistant") continue;
            var t = m.body;
            if (m.role === "assistant" && m.img !== "" && t === "") t = qsTr("(resim oluşturuldu)");
            var o = { role: m.role, text: t };
            if (i === sonFoto && i === msgModel.count - 1) {
                var b = yardim.resimBase64(m.img, 1024, 70);
                if (b !== "") o.img = b;
            } else if (m.role === "user" && m.img !== "" && t === "") o.text = qsTr("(fotoğraf)");
            out.push(o);
        }
        return out;
    }

    // E6'da tahminli yazmada son sozcuk kutuya islenmemis bekler: odagi alip birakinca islenir
    function yaziyiIsle() {
        if (!composer.activeFocus) return;
        composer.focus = false;
        root.forceActiveFocus();
    }

    function send(textArg) {
        if (textArg === undefined) yaziyiIsle();
        var text = (textArg !== undefined ? textArg : composer.text).replace(/^\s+|\s+$/g, "");
        if ((text === "" && ekResim === "") || busy) return;
        if (textArg === undefined) composer.text = "";
        var foto = ekResim;
        ekResim = "";
        if (convId === 0) convId = app.newConv(provider, (text !== "" ? text : qsTr("Fotoğraf")).substring(0, 60), modelName);
        msgModel.append({ role: "user", body: text, info: foto !== "" ? qsTr("fotoğraf") : "", img: foto });
        app.addMsg(convId, "user", text, "", 0, foto);
        yardim.log(provider + " gonder " + text.length + " karakter" + (foto !== "" ? " + foto" : ""));
        root.forceActiveFocus();          // gonderince odak sohbete: yanit yon tuslariyla okunur
        ask();
    }

    function ask() {
        busy = true;
        scrollEnd.restart();
        var conv = convId;
        app.ai().chat(provider, modelName, history(), function (r) {
            busy = false;
            if (conv !== root.convId) return;
            if (r.refusal) {
                msgModel.append({ role: "note", body: r.refusal, info: "", img: "" });
            } else {
                var info = (r.model || modelName) + "  •  " + ((r.ms || 0) / 1000).toFixed(1) + qsTr(" sn") + (r.relay ? qsTr("  •  sunucu") : "");
                msgModel.append({ role: "assistant", body: r.text !== "" ? r.text : qsTr("(boş yanıt)"), info: info, img: "" });
                app.addMsg(conv, "assistant", r.text, r.model || modelName, r.ms || 0);
            }
            scrollEnd.restart();
        }, function (msg) {
            busy = false;
            if (conv !== root.convId) return;
            yardim.log(provider + " hata: " + msg);
            msgModel.append({ role: "error", body: msg, info: qsTr("Yeniden denemek için dokunun"), img: "" });
            scrollEnd.restart();
        });
    }

    // Hata balonuna dokununca son soruyu yeniden sor
    function retry(index) {
        if (busy) return;
        msgModel.remove(index);
        ask();
    }

    // Yukari/asagi yon tuslari: mesaj listesini sayfa sayfa kaydir
    function scrollBy(dir) {
        if (dir < 0 && list.atYBeginning) return;
        if (dir > 0 && list.atYEnd) return;
        list.contentY += dir * Math.round(list.height * 0.6);
        try { list.returnToBounds(); } catch (e) { if (dir > 0 && msgModel.count > 0 && list.atYEnd) list.positionViewAtIndex(msgModel.count - 1, ListView.End); }
    }
    Keys.onUpPressed: { scrollBy(-1); event.accepted = true; }
    Keys.onDownPressed: { scrollBy(1); event.accepted = true; }
    Keys.onLeftPressed: { app.stepTab(-1); event.accepted = true; }
    Keys.onRightPressed: { app.stepTab(1); event.accepted = true; }

    Timer { id: scrollEnd; interval: 60; onTriggered: if (msgModel.count > 0) list.positionViewAtIndex(msgModel.count - 1, ListView.End) }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: root.label
        subtitle: root.modelName
        busy: root.busy
        onTitleClicked: app.selectTab(app.settingsTab)
        IconButton { source: "../images/history" + app.iconTone + ".png"; iconSize: 28; onClicked: { histPage.reload(); root.historyOpen = true; } }
        IconButton { source: "../images/plus" + app.iconTone + ".png"; iconSize: 28; onClicked: root.newChat() }
    }

    ListModel { id: msgModel }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: ekCubuk.visible ? ekCubuk.top : inputBar.top }
        clip: true
        model: msgModel
        spacing: 8
        header: Item { width: list.width; height: 8 }
        footer: Item {
            width: list.width
            height: root.busy ? 56 : 10
            Text {
                visible: root.busy
                anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                text: root.label + qsTr(" yazıyor...")
                color: app.textSecondary
                font.pixelSize: 18
                font.italic: true
            }
        }
        delegate: Item {
            id: row
            width: list.width
            height: bubble.height
            property bool mine: role === "user"
            property int maxW: Math.round(list.width * (mine ? 0.78 : 0.92))
            Text { id: measure; visible: false; text: body.substring(0, 300); font.pixelSize: 20; textFormat: Text.PlainText }
            property int resimG: img !== "" ? Math.min(maxW - 28, 360) : 0

            Rectangle {
                id: bubble
                x: row.mine ? row.width - width - 14 : 14
                width: Math.min(row.maxW, Math.max(measure.paintedWidth, infoText.paintedWidth, row.resimG) + 28)
                height: col.height + 18
                radius: 14
                color: role === "user" ? app.userBubble : (role === "error" ? (app.dark ? "#3A1D22" : "#FDE7E9") : (role === "note" ? app.pill : app.aiBubble))
                Column {
                    id: col
                    x: 14; y: 9
                    width: bubble.width - 28
                    spacing: 4
                    Image {
                        visible: img !== ""
                        width: row.resimG
                        height: visible ? Math.max(40, paintedHeight) : 0
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: 360
                        asynchronous: true
                        smooth: true
                        source: img !== "" ? yardim.dosyaUrl(img) : ""
                    }
                    Text {
                        visible: body !== ""
                        width: parent.width
                        text: role === "assistant" ? Md.toRich(body, app.codeBg) : body
                        textFormat: role === "assistant" ? Text.RichText : Text.PlainText
                        wrapMode: Text.Wrap
                        color: role === "error" ? app.danger : app.textPrimary
                        font.pixelSize: 20
                    }
                    Text {
                        id: infoText
                        visible: info !== ""
                        text: info
                        color: app.textSecondary
                        font.pixelSize: 14
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: { if (role === "error") root.retry(index); else if (img !== "") app.showToast(qsTr("Kayıtlı: ") + img); }
                    onPressAndHold: app.copyText(body)
                }
            }
        }
    }

    Column {
        anchors.centerIn: list
        visible: msgModel.count === 0 && !root.busy
        spacing: 12
        width: parent.width - 100
        Image { anchors.horizontalCenter: parent.horizontalCenter; width: 64; height: 64; smooth: true; source: "../images/" + root.badge + ".png" }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: root.label + qsTr(" ile yeni sohbet.\nYazmak için bir harfe basın; Enter gönderir.\n+ : fotoğraf ekle") + (app.ai().canDraw(root.provider) ? qsTr(", resim çiz") : "") + qsTr(", yapıştır.\nMesaja basılı tutunca kopyalanır.\nSol/sağ tuş sekme değiştirir, yukarı/aşağı kaydırır.")
            color: app.textSecondary
            font.pixelSize: 18
        }
    }

    // ---- Yazma cubugu ----
    Item {
        id: inputBar
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Math.max(76, box.height + 18)
        // "+" : fotograf ekle, resim ciz, yapistir
        IconButton {
            id: pasteBtn
            anchors { left: parent.left; leftMargin: 2; bottom: parent.bottom; bottomMargin: 8 }
            source: "../images/plus" + app.iconTone + ".png"
            iconSize: 32
            onClicked: root.arti()
        }        Rectangle {
            id: box
            anchors { left: pasteBtn.right; leftMargin: 2; right: sendBtn.left; rightMargin: 10; bottom: parent.bottom; bottomMargin: 9 }
            height: Math.min(170, Math.max(58, composer.paintedHeight + 28))
            radius: 29
            color: app.fieldBg
            border.width: composer.activeFocus ? 2 : 0
            border.color: app.brand
            Flickable {
                id: flick
                anchors { fill: parent; leftMargin: 22; rightMargin: 18; topMargin: 14; bottomMargin: 14 }
                contentWidth: width
                contentHeight: composer.paintedHeight
                clip: true
                function ensureVisible(r) {
                    if (contentY >= r.y) contentY = r.y;
                    else if (contentY + height <= r.y + r.height) contentY = r.y + r.height - height;
                }
                TextEdit {
                    id: composer
                    width: flick.width
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    font.pixelSize: 21
                    color: app.textPrimary
                    selectionColor: app.brand
                    onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
                    // Enter gonderir; Shift+Enter yeni satir
                    Keys.onReturnPressed: {
                        if (event.modifiers & Qt.ShiftModifier) { composer.text = composer.text.substring(0, composer.cursorPosition) + "\n" + composer.text.substring(composer.cursorPosition); }
                        else root.send();
                        event.accepted = true;
                    }
                    Keys.onEnterPressed: { root.send(); event.accepted = true; }
                    // Yazi bossa sol/sag sekme degistirir; yazi varken imleci oynatir.
                    // Yukari/asagi imlec ilk/son satirdayken mesajlari kaydirir.
                    Keys.onLeftPressed: {
                        if (composer.text.length === 0) { app.stepTab(-1); event.accepted = true; }
                        else event.accepted = composer.cursorPosition === 0;   // basta: yazarken yanlislikla sekme degismesin
                    }
                    Keys.onRightPressed: {
                        if (composer.text.length === 0) { app.stepTab(1); event.accepted = true; }
                        else event.accepted = composer.cursorPosition >= composer.text.length;
                    }
                    // Bos kutuda Escape/geri: odak sohbete doner
                    Keys.onEscapePressed: { root.forceActiveFocus(); event.accepted = true; }
                    Keys.onUpPressed: { if (composer.cursorRectangle.y < 4) { root.scrollBy(-1); event.accepted = true; } else event.accepted = false; }
                    Keys.onDownPressed: { if (composer.cursorRectangle.y + composer.cursorRectangle.height >= composer.paintedHeight - 4) { root.scrollBy(1); event.accepted = true; } else event.accepted = false; }
                }
            }
            Text {
                anchors { left: parent.left; leftMargin: 22; verticalCenter: parent.verticalCenter }
                text: root.label + qsTr("'a yazın")
                color: app.placeholder
                font.pixelSize: 21
                visible: composer.text.length === 0
            }
            MouseArea {
                anchors.fill: parent
                enabled: !composer.activeFocus
                onClicked: { composer.forceActiveFocus(); composer.openSoftwareInputPanel(); }
            }
        }
        Rectangle {
            id: sendBtn
            anchors { right: parent.right; rightMargin: 12; bottom: parent.bottom; bottomMargin: 9 }
            width: 58; height: 58; radius: 29
            color: sMa.pressed ? app.brandPressed : app.brand
            opacity: root.busy ? 0.5 : 1
            Image { anchors.centerIn: parent; anchors.horizontalCenterOffset: 2; width: 32; height: 32; smooth: true; source: "../images/send.png" }
            MouseArea { id: sMa; anchors.fill: parent; onClicked: root.send() }
        }
    }

    // ---- "+" menusu, resim cizme, foto ekleme ----
    function arti() {
        yaziyiIsle();
        menuModel.clear();
        menuModel.append({ k: "foto", t: qsTr("Fotoğraf ekle") });
        if (app.ai().canDraw(provider)) menuModel.append({ k: "ciz", t: qsTr("Resim çiz (yazdığın metinle)") });
        menuModel.append({ k: "yapistir", t: qsTr("Yapıştır") });
        if (ekResim !== "") menuModel.append({ k: "kaldir", t: qsTr("Eklenen fotoğrafı kaldır") });
        menuAcik = true;
        menuList.currentIndex = 0;
        menuList.forceActiveFocus();
    }
    function menuSec(k) {
        menuAcik = false;
        if (k === "foto") { resimSec.ac(); }
        else if (k === "ciz") ciz();
        else if (k === "yapistir") { composer.forceActiveFocus(); composer.paste(); }
        else if (k === "kaldir") { ekResim = ""; focusInput(); }
        else focusInput();
    }
    function ciz() {
        var t = composer.text.replace(/^\s+|\s+$/g, "");
        if (busy) return;
        if (t === "") { app.showToast(qsTr("Önce ne çizileceğini yazın, sonra + > Resim çiz")); composer.forceActiveFocus(); return; }
        composer.text = "";
        if (convId === 0) convId = app.newConv(provider, (qsTr("Resim: ") + t).substring(0, 60), modelName);
        msgModel.append({ role: "user", body: qsTr("Çiz: ") + t, info: "", img: "" });
        app.addMsg(convId, "user", qsTr("Çiz: ") + t, "", 0, "");
        busy = true;
        scrollEnd.restart();
        root.forceActiveFocus();
        var conv = convId;
        yardim.log(provider + " ciz " + t.length + " karakter");
        app.ai().draw(provider, t, function (r) {
            busy = false;
            var yol = yardim.resimKaydet(r.b64, r.ext);
            var info = r.model + "  •  " + ((r.ms || 0) / 1000).toFixed(1) + qsTr(" sn") + (r.relay ? qsTr("  •  sunucu") : "");
            if (yol === "") { if (conv === root.convId) msgModel.append({ role: "error", body: qsTr("Resim kaydedilemedi"), info: "", img: "" }); return; }
            app.addMsg(conv, "assistant", r.text || "", r.model, r.ms || 0, yol);
            if (conv !== root.convId) return;
            msgModel.append({ role: "assistant", body: r.text || "", info: info, img: yol });
            scrollEnd.restart();
        }, function (m) {
            busy = false;
            yardim.log(provider + " ciz hata: " + m);
            if (conv !== root.convId) return;
            msgModel.append({ role: "error", body: m, info: "", img: "" });
            scrollEnd.restart();
        });
    }

    // Eklenen foto seridi (yazma kutusunun ustunde)
    Rectangle {
        id: ekCubuk
        visible: root.ekResim !== ""
        anchors { left: parent.left; right: parent.right; bottom: inputBar.top }
        height: visible ? 74 : 0
        color: app.surface
        Image {
            id: ekKucuk
            x: 14; anchors.verticalCenter: parent.verticalCenter
            width: 60; height: 60; fillMode: Image.PreserveAspectCrop; clip: true
            sourceSize.width: 120; asynchronous: true; smooth: true
            source: root.ekResim !== "" ? yardim.dosyaUrl(root.ekResim) : ""
        }
        Text {
            anchors { left: ekKucuk.right; leftMargin: 12; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            text: qsTr("Fotoğraf eklendi; mesajla birlikte gider.\nKaldırmak için dokunun.")
            color: app.textSecondary; font.pixelSize: 15; wrapMode: Text.Wrap
        }
        MouseArea { anchors.fill: parent; onClicked: { root.ekResim = ""; app.showToast(qsTr("Fotoğraf kaldırıldı")); } }
    }

    // "+" menusu
    ListModel { id: menuModel }
    Rectangle {
        anchors.fill: parent
        visible: root.menuAcik
        color: "#99000000"
        z: 20
        MouseArea { anchors.fill: parent; onClicked: { root.menuAcik = false; root.focusInput(); } }
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 24; bottomMargin: 84 }
            height: menuModel.count * 54 + 16
            radius: 16
            color: app.surface
            MouseArea { anchors.fill: parent }
            ListView {
                id: menuList
                anchors { fill: parent; margins: 8 }
                model: menuModel
                interactive: false
                delegate: Rectangle {
                    width: menuList.width; height: 54; radius: 12
                    color: mMa.pressed || ListView.isCurrentItem ? app.pill : "transparent"
                    Text { anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter } text: t; color: app.textPrimary; font.pixelSize: 19 }
                    MouseArea { id: mMa; anchors.fill: parent; onClicked: root.menuSec(k) }
                }
                Keys.onPressed: {
                    if (event.key === Qt.Key_Down) { currentIndex = (currentIndex + 1) % menuModel.count; event.accepted = true; }
                    else if (event.key === Qt.Key_Up) { currentIndex = (currentIndex - 1 + menuModel.count) % menuModel.count; event.accepted = true; }
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) { root.menuSec(menuModel.get(currentIndex).k); event.accepted = true; }
                    else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace || event.key === Qt.Key_Context2 || event.key === Qt.Key_Left) { root.menuAcik = false; root.focusInput(); event.accepted = true; }
                }
            }
        }
    }

    ResimSec {
        id: resimSec
        anchors.fill: parent
        z: 25
        onSecildi: { root.ekResim = yol; yardim.log("foto secildi " + yol); app.showToast(qsTr("Fotoğraf eklendi")); root.focusInput(); }
        onKapandi: root.focusInput()
    }
    HistoryPage {
        id: histPage
        anchors.fill: parent
        visible: root.historyOpen
        provider: root.provider
        label: root.label
        currentConv: root.convId
        onOpenConv: root.openConv(id)
        onClose: { root.historyOpen = false; root.focusInput(); }
        onNewChat: root.newChat()
        onDeleted: if (id === root.convId) { root.convId = 0; msgModel.clear(); }
    }
}
