import QtQuick 1.1
import "Util.js" as U

// Internet akisi: adres yaz, izle / sadece ses / indir / favorilere ekle.
// Altta favori akislar ve indirilen dosyalar.
// Klavye: harfe basinca adres kutusuna gecer; listede Enter oynatir, Bosluk secenekler.
Rectangle {
    id: root
    color: app.bg

    function takeFocus() { if (!url.input.activeFocus) list.forceActiveFocus(); }

    function cleanUrl() {
        var u = url.text.replace(/^\s+|\s+$/g, "");
        if (u !== "" && u.indexOf("://") < 0) u = "http://" + u;
        return u;
    }
    function watch(audio) {
        var u = cleanUrl();
        if (u === "") { url.focusInput(); return; }
        app.playOne(u, lib.baseName(u), audio);
    }
    function download() {
        var u = cleanUrl();
        if (u === "") { url.focusInput(); return; }
        lib.download(u, "");
        app.showToast(qsTr("İndirme başladı"));
    }

    function reloadDownloads() {
        // favoriler ve indirilenler tek listede (bolumlu)
        smodel.clear();
        for (var i = 0; i < app.favs.count; i++)
            smodel.append({ sec: qsTr("Favori akışlar"), kind: "fav", idx: i, name: app.favs.get(i).title, target: app.favs.get(i).url, info: app.favs.get(i).url });
        var d = lib.downloads();
        for (var j = 0; j < d.length; j++)
            smodel.append({ sec: qsTr("İndirilenler (") + lib.downloadDir() + ")", kind: "file", idx: j, name: d[j].name, target: d[j].path,
                            info: U.sizeText(d[j].size) + "  •  " + U.dateText(d[j].time) });
        if (list.currentIndex >= smodel.count) list.currentIndex = smodel.count - 1;
    }
    Connections { target: app.favs; onCountChanged: root.reloadDownloads() }
    Component.onCompleted: reloadDownloads()

    function fileQueue() {
        var p = [], t = [];
        for (var i = 0; i < smodel.count; i++) if (smodel.get(i).kind === "file") { p.push(smodel.get(i).target); t.push(smodel.get(i).name); }
        return { paths: p, titles: t };
    }
    function playAt(i, audio) {
        if (i < 0 || i >= smodel.count) return;
        var it = smodel.get(i);
        if (it.kind === "fav") { app.play([it.target], [it.name], 0, "stream", audio); return; }
        var q = fileQueue();
        var k = 0;
        for (var n = 0; n < q.paths.length; n++) if (q.paths[n] === it.target) k = n;
        app.play(q.paths, q.titles, k, "folder", audio);
    }
    function menuAt(i) {
        if (i < 0 || i >= smodel.count) return;
        var it = smodel.get(i);
        if (it.kind === "file") {
            var q = fileQueue(), k = 0;
            for (var n = 0; n < q.paths.length; n++) if (q.paths[n] === it.target) k = n;
            app.fileMenu(it.target, it.name, q.paths, q.titles, k, "folder");
            return;
        }
        var favIndex = it.idx, favUrl = it.target;
        sheet.open(it.name, [
            { label: qsTr("İzle"), icon: "play", key: "play" },
            { label: qsTr("Sadece ses"), icon: "phones", key: "audio" },
            { label: qsTr("İndir"), icon: "download", key: "dl" },
            { label: qsTr("Adresi kutuya al"), icon: "globe", key: "edit" },
            { label: qsTr("Favorilerden sil"), icon: "trash", key: "rm", danger: true }
        ], function (k) {
            if (k === "play") root.playAt(i, false);
            else if (k === "audio") root.playAt(i, true);
            else if (k === "dl") { lib.download(favUrl, ""); app.showToast(qsTr("İndirme başladı")); }
            else if (k === "edit") { url.text = favUrl; url.focusInput(); }
            else if (k === "rm") app.removeFav(favIndex);
        });
    }

    ListModel { id: smodel }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: qsTr("Akış")
        subtitle: qsTr("internet videosu izle ya da indir")
        busy: lib.downloading
    }

    Column {
        id: topBox
        anchors { left: parent.left; right: parent.right; top: header.bottom; margins: 10 }
        spacing: 8
        TextField {
            id: url
            width: parent.width
            placeholder: "Adres (http://...mp4, rtsp://...)"
            inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
            onAccepted: root.watch(false)
            onEscaped: list.forceActiveFocus()
        }
        Row {
            spacing: 8
            Pill { label: qsTr("İzle"); icon: "play"; accent: true; onClicked: root.watch(false) }
            Pill { label: qsTr("Ses"); icon: "phones"; onClicked: root.watch(true) }
            Pill { label: qsTr("İndir"); icon: "download"; onClicked: root.download() }
            Pill {
                label: qsTr("Favori"); icon: "star"
                onClicked: { var u = root.cleanUrl(); if (u === "") url.focusInput(); else app.addFav(lib.baseName(u), u); }
            }
        }
        // Indirme durumu
        Rectangle {
            width: parent.width
            height: lib.downloading ? 58 : 0
            visible: lib.downloading
            radius: 10
            color: app.surface
            Text {
                anchors { left: parent.left; right: cancelBtn.left; top: parent.top; leftMargin: 12; topMargin: 8 }
                text: (lib.downloadName !== "" ? lib.downloadName : qsTr("İndiriliyor")) + "   %" + app.dlPercent + (app.dlSpeed > 0 ? "  •  " + app.dlSpeed + qsTr(" KB/s") : "")
                textFormat: Text.PlainText
                color: app.textPrimary; font.pixelSize: 15
                elide: Text.ElideMiddle
            }
            Rectangle {
                anchors { left: parent.left; right: cancelBtn.left; bottom: parent.bottom; leftMargin: 12; bottomMargin: 12; rightMargin: 4 }
                height: 5; radius: 2; color: app.divider
                Rectangle { height: parent.height; radius: 2; color: app.brand; width: parent.width * app.dlPercent / 100 }
            }
            IconButton { id: cancelBtn; anchors { right: parent.right; verticalCenter: parent.verticalCenter } icon: "close"; tone: "g"; iconSize: 22; onClicked: lib.cancelDownload() }
        }
    }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: topBox.bottom; bottom: parent.bottom; topMargin: 6 }
        clip: true
        model: smodel
        focus: true
        highlightMoveDuration: 120
        section.property: "sec"
        section.delegate: Rectangle {
            width: list.width; height: 28
            color: app.bg
            Text { anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter } text: section; color: app.brand; font.pixelSize: 14; font.bold: true }
        }
        delegate: FileRow {
            width: list.width
            icon: kind === "fav" ? "star" : (lib.isAudio(target) ? "note" : "film")
            title: name
            sub: info
            selected: ListView.isCurrentItem && list.activeFocus
            playing: app.playerOpen && app.nowPath === target
            onClicked: { list.currentIndex = index; root.playAt(index, false); }
            onPressAndHold: { list.currentIndex = index; root.menuAt(index); }
            onAction: { list.currentIndex = index; root.menuAt(index); }
        }
        Keys.onPressed: {
            var k = event.key;
            if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) { root.playAt(currentIndex, false); event.accepted = true; }
            else if (k === Qt.Key_Left) { app.stepTab(-1); event.accepted = true; }
            else if (k === Qt.Key_Right) { app.stepTab(1); event.accepted = true; }
            else if (k === Qt.Key_Up && (currentIndex <= 0 || count === 0)) { url.focusInput(); event.accepted = true; }
            else if (k === Qt.Key_Space || k === Qt.Key_Menu || k === Qt.Key_Context1) { root.menuAt(currentIndex); event.accepted = true; }
            else if (U.printable(event)) {
                url.text = url.text + event.text;
                url.focusInput();
                url.input.cursorPosition = url.text.length;
                event.accepted = true;
            }
        }
    }

    Text {
        anchors.centerIn: list
        width: parent.width - 80
        visible: smodel.count === 0
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: qsTr("Favori akış ya da indirilen dosya yok.\nAdresi yazıp İzle ya da İndir'e basın.")
        color: app.textSecondary
        font.pixelSize: 17
    }
}
