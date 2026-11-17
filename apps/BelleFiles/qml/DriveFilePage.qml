import QtQuick 1.1

// Dosya ayrintisi: onizleme, indir/ac, metin olarak oku, yildiz, cop
Rectangle {
    id: page
    property variant item: null
    property string local: ""
    property bool hasLocal: false
    property bool textMode: false
    property bool textLoading: false
    property string textBody: ""
    property bool starred: false

    signal closed
    signal trashed(string id)

    color: "#ffffff"
    visible: false
    z: 50

    function show(it) {
        item = it;
        starred = it.starred;
        textMode = false;
        textBody = "";
        local = drive.localPath(it.google ? it.name + "." + it.dlExt.toLowerCase() : it.name);
        refreshLocal();
        flick.contentY = 0;
        visible = true;
        page.forceActiveFocus();
    }
    // Telefondaki kopya Drive'dakinden farkliysa (boyut farkli ya da Drive'daki daha yeni) eski sayilir
    property bool outdated: false
    function refreshLocal() {
        hasLocal = item !== null && drive.fileExists(local);
        outdated = false;
        if (!hasLocal || item.google) return;
        var sz = parseInt(item.size || "0", 10);
        if (sz > 0 && drive.fileSize(local) !== sz) { outdated = true; return; }
        var t = Date.parse(item.modified);
        if (!isNaN(t) && t > drive.fileTime(local) + 60000) outdated = true;
    }
    function close() {
        if (textMode) { textMode = false; return; }
        visible = false;
        closed();
    }
    function readText() {
        textMode = true;
        textLoading = true;
        textBody = "";
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== 4) return;
            textLoading = false;
            var t = x.status === 200 ? x.responseText : (qsTr("Okunamadı (") + x.status + ")");
            if (t.length > 60000) t = t.substring(0, 60000) + qsTr("\n\n… (devamı için dosyayı indirin)");
            textBody = t;
            textFlick.contentY = 0;
        };
        x.open("GET", drive.server + "/drive/api/text/" + item.id);
        x.send();
    }
    function toggleStar() {
        var on = !starred;
        app.post("/drive/api/star/" + item.id + "?on=" + (on ? "1" : "0"), function (ok, j) {
            if (ok) { starred = on; app.toast(on ? qsTr("Yıldızlandı") : qsTr("Yıldız kaldırıldı")); app.markStar(item.id, on); }
            else app.toast(j.error || qsTr("Olmadı"));
        });
    }

    focus: visible
    Keys.onPressed: {
        if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Escape) { page.close(); event.accepted = true; }
        else if (event.key === Qt.Key_Down) { var f = textMode ? textFlick : flick; f.contentY = Math.min(Math.max(0, f.contentHeight - f.height), f.contentY + 120); event.accepted = true; }
        else if (event.key === Qt.Key_Up) { var g = textMode ? textFlick : flick; g.contentY = Math.max(0, g.contentY - 120); event.accepted = true; }
    }
    MouseArea { anchors.fill: parent }

    // Ust cubuk
    Rectangle {
        id: bar
        width: parent.width
        height: 56
        color: app.brand
        DriveBtn { id: backBtn; flat: true; text: qsTr("‹ Geri"); anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter } onClicked: page.close() }
        Text {
            anchors { left: backBtn.right; leftMargin: 8; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            text: page.item ? page.item.name : ""
            color: "#ffffff"
            font.pixelSize: 22
            font.bold: true
            elide: Text.ElideMiddle
        }
    }

    // Ayrinti
    Flickable {
        id: flick
        anchors { top: bar.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        visible: !page.textMode
        contentHeight: content.height + 30
        clip: true
        Column {
            id: content
            x: 16; y: 14
            width: flick.width - 32
            spacing: 12

            Row {
                spacing: 14
                DriveFileIcon { kind: page.item ? page.item.kind : ""; ext: page.item ? page.item.ext : ""; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    width: content.width - 70
                    Text { width: parent.width; text: page.item ? page.item.name : ""; font.pixelSize: 21; font.bold: true; color: app.textPrimary; wrapMode: Text.WrapAnywhere }
                    Text {
                        width: parent.width
                        color: app.textSecondary
                        font.pixelSize: 17
                        wrapMode: Text.Wrap
                        text: page.item ? [page.item.sizeText, app.fullDate(page.item.modified), page.item.owner, page.starred ? qsTr("yıldızlı") : ""].filter(function (s) { return s !== ""; }).join("  ·  ") : ""
                    }
                }
            }

            Flow {
                width: parent.width
                spacing: 8
                DriveBtn { visible: page.hasLocal; primary: !page.outdated; text: page.outdated ? qsTr("Eski kopyayı aç") : qsTr("Aç"); onClicked: app.yerelAc(page.local) }
                DriveBtn {
                    primary: !page.hasLocal || page.outdated
                    enabled: !drive.busy
                    text: page.outdated ? qsTr("Yeni sürümü indir") + (page.item && page.item.size ? " (" + page.item.sizeText + ")" : "")
                        : (page.hasLocal ? qsTr("Yeniden indir") : ((page.item && page.item.google ? page.item.dlExt + qsTr(" olarak indir") : qsTr("İndir")) + (page.item && page.item.size ? " (" + page.item.sizeText + ")" : "")))
                    onClicked: app.startDownload(page.item, page.local)
                }
                DriveBtn { visible: !!page.item && page.item.canText; text: qsTr("Metin olarak oku"); onClicked: page.readText() }
                DriveBtn { text: page.starred ? qsTr("Yıldızı kaldır") : qsTr("Yıldızla"); onClicked: page.toggleStar() }
                DriveBtn { danger: true; text: qsTr("Çöpe at"); onClicked: app.askTrash(page.item) }
            }

            Text {
                width: parent.width
                visible: page.hasLocal
                text: (page.outdated ? qsTr("Telefondaki kopya ESKİ — Drive'da daha yeni sürüm var.\n") : "") + qsTr("Telefonda: ") + page.local
                font.pixelSize: 15
                color: app.textSecondary
                wrapMode: Text.WrapAnywhere
            }

            Image {
                id: preview
                width: parent.width
                visible: !!page.item && page.item.kind === "image"
                source: visible ? drive.server + "/drive/img/" + page.item.id + "?w=600" : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                sourceSize.width: 600
                height: status === Image.Ready ? Math.min(paintedHeight > 0 ? paintedHeight : 300, 900) : 60
                Text { anchors.centerIn: parent; visible: preview.status === Image.Loading; text: qsTr("Önizleme yükleniyor…"); color: app.textSecondary; font.pixelSize: 17 }
            }
        }
    }

    // Metin okuma
    Flickable {
        id: textFlick
        anchors { top: bar.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        visible: page.textMode
        contentHeight: body.paintedHeight + 30
        clip: true
        Text {
            id: body
            x: 14; y: 12
            width: textFlick.width - 28
            text: page.textLoading ? qsTr("Yükleniyor…") : page.textBody
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            font.pixelSize: 18
            color: app.textPrimary
        }
    }
}
