import QtQuick 1.1
import "Posta.js" as P

// Posta okuma: basliklar, ekler, bicimli govde (HTML telefonda sade zengin metne cevrilir), islemler
Rectangle {
    id: page
    property string folder: "inbox"
    property int uid: 0
    property string subject: ""
    property string from: ""
    property string fromAddr: ""
    property string to: ""
    property string cc: ""
    property string date: ""
    property bool starred: false
    property string body: ""
    property bool loading: false
    property string error: ""
    property bool hasImages: false
    property bool imagesShown: false
    property bool showDetails: false
    property int seq: 0
    property string hamHtml: ""
    property string hamMetin: ""

    signal closed

    color: "#ffffff"
    visible: false
    z: 50

    ListModel { id: atts }

    function show(f, it, idx) {
        folder = f;
        uid = it.uid;
        subject = it.subject; from = it.from; fromAddr = it.fromAddr; date = it.date; starred = it.starred;
        to = ""; cc = ""; body = ""; error = ""; hasImages = false; imagesShown = false; showDetails = false; hamHtml = ""; hamMetin = "";
        atts.clear();
        flick.contentY = 0;
        visible = true;
        page.forceActiveFocus();
        load(false);
    }
    // resimler: uzak resimleri goster (posta yeniden indirilmez, yalnizca yeniden cizilir)
    function ciz(resimler) {
        if (hamHtml !== "") {
            var r = P.htmlToRich(hamHtml, resimler, Math.min(content.width, 600));
            body = r.html !== "" ? r.html : P.textToHtml(hamMetin !== "" ? hamMetin : P.htmlToText(hamHtml));
            hasImages = P.resimSay(hamHtml) > 0;
            imagesShown = r.resim > 0;
        } else {
            body = hamMetin !== "" ? P.textToHtml(hamMetin) : "<i>" + qsTr("(metin yok)") + "</i>";
        }
    }
    function load(withImages) {
        if (!withImages && body !== "" && hamHtml !== "") { ciz(false); return; }
        if (withImages && hamHtml !== "") { ciz(true); return; }
        var s = ++seq;
        loading = true;
        error = "";
        app.istek("mesaj", { f: folder, uid: uid, okundu: true }, function (ok, j) {
            if (s !== seq) return;
            loading = false;
            if (!ok) { error = j.error; return; }
            subject = j.subject; from = j.from || j.fromAddr; fromAddr = j.fromAddr; starred = j.starred;
            to = P.adresListesi(j.toAd, j.toAdr);
            cc = P.adresListesi(j.ccAd, j.ccAdr);
            date = P.uzunTarih(j.ts);
            hamHtml = j.html || "";
            hamMetin = j.text || "";
            ciz(withImages);
            atts.clear();
            for (var i = 0; i < j.att.length; i++) atts.append({ part: j.att[i].part, name: j.att[i].name, sizeText: app.sizeText(j.att[i].size), size: j.att[i].size });
        });
    }
    function close() { visible = false; closed(); }
    function doAct(a) {
        var u = uid;
        app.act(u, a, function () {
            if (a === "star" || a === "unstar") page.starred = (a === "star");
            else if (a === "archive" || a === "trash" || a === "unread" || a === "notspam") page.close();
        });
    }

    focus: visible
    Keys.onPressed: {
        if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Escape) { page.close(); event.accepted = true; }
        else if (event.key === Qt.Key_Down) { flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY + 140); event.accepted = true; }
        else if (event.key === Qt.Key_Up) { flick.contentY = Math.max(0, flick.contentY - 140); event.accepted = true; }
        else if (event.key === Qt.Key_Space) { flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY + flick.height - 60); event.accepted = true; }
    }
    MouseArea { anchors.fill: parent }

    // ---- Ust cubuk: geri + islemler ----
    Rectangle {
        id: bar
        width: parent.width
        height: 56
        color: app.brand
        Btn { id: backBtn; flat: true; text: qsTr("‹ Geri"); anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter } onClicked: page.close() }
        Row {
            anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
            spacing: 2
            Btn { flat: true; text: page.starred ? "★" : "☆"; fontSize: 24; onClicked: page.doAct(page.starred ? "unstar" : "star") }
            Btn { flat: true; text: qsTr("Okunmadı"); onClicked: page.doAct("unread") }
            Btn { flat: true; text: qsTr("Arşiv"); visible: page.folder === "inbox"; onClicked: page.doAct("archive") }
            Btn { flat: true; text: qsTr("Spam değil"); visible: page.folder === "spam"; onClicked: page.doAct("notspam") }
            Btn { flat: true; text: page.folder === "trash" ? qsTr("Kalıcı sil") : qsTr("Sil"); onClicked: page.doAct("trash") }
        }
    }

    Flickable {
        id: flick
        anchors { top: bar.bottom; left: parent.left; right: parent.right; bottom: replyBar.top }
        contentHeight: content.height + 24
        clip: true
        Column {
            id: content
            x: 16
            width: flick.width - 32
            spacing: 12

            Item { width: 1; height: 4 }
            Text {
                width: parent.width
                text: page.subject
                textFormat: Text.PlainText
                font.pixelSize: 24
                font.bold: true
                color: app.textPrimary
                wrapMode: Text.Wrap
            }

            // Gonderen satiri
            Item {
                width: parent.width
                height: 52
                Avatar { id: av; anchors.verticalCenter: parent.verticalCenter; name: page.from; size: 46 }
                Column {
                    anchors { left: av.right; leftMargin: 12; right: parent.right; verticalCenter: parent.verticalCenter }
                    Row {
                        width: parent.width
                        spacing: 8
                        Text { id: fromT; text: page.from; textFormat: Text.PlainText; font.pixelSize: 19; font.bold: true; color: app.textPrimary; elide: Text.ElideRight; width: parent.width - dateT.paintedWidth - 12 }
                        Text { id: dateT; text: page.date; font.pixelSize: 15; color: app.textSecondary; anchors.verticalCenter: fromT.verticalCenter }
                    }
                    Text {
                        width: parent.width
                        text: (page.showDetails ? page.fromAddr : qsTr("kime: ") + (page.to !== "" ? page.to : "…")) + (page.showDetails ? "" : "  ▾")
                        textFormat: Text.PlainText
                        font.pixelSize: 15; color: app.textSecondary; elide: Text.ElideRight
                    }
                }
                MouseArea { anchors.fill: parent; onClicked: page.showDetails = !page.showDetails }
            }
            Text {
                width: parent.width
                visible: page.showDetails
                text: qsTr("Kimden: ") + page.from + " <" + page.fromAddr + qsTr(">\nKime: ") + page.to + (page.cc !== "" ? qsTr("\nBilgi: ") + page.cc : "") + qsTr("\nTarih: ") + page.date
                textFormat: Text.PlainText
                font.pixelSize: 15; color: app.textSecondary; wrapMode: Text.Wrap
            }

            // Ekler
            Flow {
                width: parent.width
                spacing: 8
                visible: atts.count > 0
                Repeater {
                    model: atts
                    delegate: Rectangle {
                        width: Math.min(content.width, nameMeasure.paintedWidth + attSize.paintedWidth + 44)
                        height: 44; radius: 8
                        Text { id: nameMeasure; visible: false; text: model.name; font.pixelSize: 17 }
                        color: am.pressed ? "#e8eaed" : "#f1f3f4"
                        border.width: 1; border.color: "#dadce0"
                        Row {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            spacing: 10
                            Text { id: attName; text: model.name; textFormat: Text.PlainText; font.pixelSize: 17; color: app.textPrimary; elide: Text.ElideMiddle; width: Math.min(nameMeasure.paintedWidth, content.width - 120) }
                            Text { id: attSize; text: model.sizeText; font.pixelSize: 14; color: app.textSecondary; anchors.verticalCenter: attName.verticalCenter }
                        }
                        MouseArea {
                            id: am
                            anchors.fill: parent
                            onClicked: {
                                if (mail.busy) { app.toast(qsTr("Önce süren indirme bitsin")); return; }
                                app.xferText = qsTr("Ek: ") + model.name;
                                app.xferDone = 0; app.xferTotal = model.size;
                                if (!mail.downloadAttachment(page.folder, page.uid, model.part, model.name)) app.toast(qsTr("Telefona yazılamadı"));
                            }
                        }
                    }
                }
            }

            // Resimler gizli bildirimi
            Rectangle {
                width: parent.width
                height: 48
                radius: 8
                visible: page.hasImages && !page.imagesShown && !page.loading
                color: "#fef7e0"
                Text { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter } text: qsTr("Resimler gizlendi (veri tasarrufu)"); font.pixelSize: 16; color: "#5f4b00" }
                Btn { anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter } text: qsTr("Göster"); onClicked: page.load(true) }
            }

            Rectangle { width: parent.width; height: 1; color: app.divider }

            Text {
                width: parent.width
                visible: page.loading || page.error !== ""
                text: page.loading ? qsTr("Yükleniyor…") : page.error
                color: page.error !== "" ? "#c5221f" : app.textSecondary
                font.pixelSize: 18
                wrapMode: Text.Wrap
            }

            // Govde: bicimli metin; baglantilar tarayicida acilir
            Text {
                id: bodyText
                width: parent.width
                visible: page.body !== ""
                text: qsTr("<style>a{color:#1a73e8;} h3{font-size:large;} blockquote{color:#5f6368;}</style>") + page.body
                textFormat: Text.RichText
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                font.pixelSize: 18
                color: app.textPrimary
                onLinkActivated: {
                    if (link.indexOf("mailto:") === 0) compose.open("to", link.substring(7).split("?")[0], 0);
                    else Qt.openUrlExternally(link);
                }
            }
        }
    }

    // ---- Alt cubuk: yanitla / tumune / ilet ----
    Rectangle {
        id: replyBar
        anchors.bottom: parent.bottom
        width: parent.width
        height: 62
        color: "#f6f8fc"
        Rectangle { width: parent.width; height: 1; color: "#dadce0" }
        Row {
            anchors.centerIn: parent
            spacing: 10
            Btn { text: qsTr("↩ Yanıtla"); primary: true; onClicked: compose.open("re", page.folder, page.uid) }
            Btn { text: qsTr("Tümünü yanıtla"); onClicked: compose.open("all", page.folder, page.uid) }
            Btn { text: qsTr("İlet ↪"); onClicked: compose.open("fw", page.folder, page.uid) }
        }
    }
}
