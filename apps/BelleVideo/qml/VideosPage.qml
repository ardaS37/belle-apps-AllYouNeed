import QtQuick 1.1
import "Util.js" as U

// Telefondaki tum videolar (tarama sonucu) + ustte "Kaldigin yerden" (son izlenenler).
// Klavye: yukari/asagi gezinir, Enter oynatir, harfe basinca arama kutusuna gecer ve o harfi yazar.
// Bosluk: secenekler   +: listeye ekle   Sol/Sag: sekme
Rectangle {
    id: root
    color: app.bg

    property string filter: ""
    property variant allPaths: []        // "Tum videolar" bolumundeki sirali yollar (kuyruk icin)
    property variant allTitles: []
    property variant recentPaths: []
    property variant recentTitles: []

    function takeFocus() { if (filter === "" || !search.input.activeFocus) list.forceActiveFocus(); }

    function rebuild() {
        var keepPath = list.currentIndex >= 0 && list.currentIndex < vmodel.count ? vmodel.get(list.currentIndex).path : "";
        vmodel.clear();
        var f = U.fold(filter);
        // Son izlenenler (arama yokken)
        var rp = [], rt = [];
        if (filter === "") {
            var rec = lib.recent();
            for (var i = 0; i < rec.length && rp.length < 4; i++) {
                var p = rec[i];
                if (lib.isRemote(p)) continue;
                var pos = lib.savedPosition(p), dur = lib.savedDuration(p);
                var name = titleFor(p);
                rp.push(p); rt.push(name);
                vmodel.append({ sec: qsTr("Kaldığın yerden"), path: p, name: name,
                               info: lib.folderName(p) + (pos > 0 ? "  •  " + U.fmt(pos) + (dur > 0 ? " / " + U.fmt(dur) : "") : qsTr("  •  izlendi")),
                               prog: dur > 0 && pos > 0 ? pos / dur : -1, recentRow: true });
            }
        }
        recentPaths = rp; recentTitles = rt;
        var vids = lib.videos();
        var ap = [], at = [];
        for (var j = 0; j < vids.length; j++) {
            var v = vids[j];
            if (f !== "" && U.fold(v.name + " " + v.folder).indexOf(f) < 0) continue;
            ap.push(v.path); at.push(v.name);
            vmodel.append({ sec: filter === "" ? qsTr("Tüm videolar") : qsTr("Arama sonuçları"), path: v.path, name: v.name,
                           info: v.folder + "  •  " + U.sizeText(v.size) + "  •  " + U.dateText(v.time),
                           prog: -1, recentRow: false });
        }
        allPaths = ap; allTitles = at;
        var idx = 0;
        if (keepPath !== "") for (var k = 0; k < vmodel.count; k++) if (vmodel.get(k).path === keepPath) { idx = k; break; }
        list.currentIndex = vmodel.count > 0 ? idx : -1;
    }
    property bool dirty: true
    function titleFor(p) {
        var vids = lib.videos();
        for (var i = 0; i < vids.length; i++) if (vids[i].path === p) return vids[i].name;
        return lib.baseName(p);
    }
    function refreshRecent() { rebuild(); }

    Connections { target: lib; onLibraryChanged: root.rebuild() }
    Component.onCompleted: rebuild()

    function queueFor(i) {
        var it = vmodel.get(i);
        if (it.recentRow) return { paths: recentPaths, titles: recentTitles, index: indexIn(recentPaths, it.path), source: "videos" };
        return { paths: allPaths, titles: allTitles, index: indexIn(allPaths, it.path), source: "videos" };
    }
    function indexIn(arr, p) { for (var i = 0; i < arr.length; i++) if (arr[i] === p) return i; return 0; }
    function playAt(i, audio) {
        if (i < 0 || i >= vmodel.count) return;
        var q = queueFor(i);
        app.play(q.paths, q.titles, q.index, q.source, audio);
    }
    function menuAt(i) {
        if (i < 0 || i >= vmodel.count) return;
        var q = queueFor(i);
        app.fileMenu(vmodel.get(i).path, vmodel.get(i).name, q.paths, q.titles, q.index, q.source);
    }

    ListModel { id: vmodel }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: qsTr("Videolar")
        subtitle: lib.scanning ? qsTr("Taranıyor... ") + lib.scanFound + qsTr(" bulundu") : lib.videos().length + qsTr(" video") + (lib.libraryVersion < 0 ? "" : "")
        busy: lib.scanning
        IconButton { icon: "search"; tone: "g"; iconSize: 26; onClicked: search.focusInput() }
        IconButton { icon: "refresh"; tone: "g"; iconSize: 26; onClicked: { lib.rescan(); app.showToast(qsTr("Videolar yeniden taranıyor")); } }
    }

    TextField {
        id: search
        anchors { left: parent.left; right: parent.right; top: header.bottom; margins: 8 }
        visible: root.filter !== "" || input.activeFocus
        height: visible ? 42 : 0
        placeholder: qsTr("Video ara")
        onTextChanged: { root.filter = text; filterTimer.restart(); }
        onEscaped: { text = ""; list.forceActiveFocus(); }
        onAccepted: list.forceActiveFocus()
    }
    Timer { id: filterTimer; interval: 250; onTriggered: root.rebuild() }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: search.visible ? search.bottom : header.bottom; bottom: parent.bottom; topMargin: search.visible ? 6 : 0 }
        clip: true
        model: vmodel
        focus: true
        highlightMoveDuration: 120
        section.property: "sec"
        section.delegate: Rectangle {
            width: list.width; height: 30
            color: app.bg
            Text {
                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                text: section
                color: app.brand
                font.pixelSize: 14
                font.bold: true
            }
        }
        delegate: FileRow {
            width: list.width
            icon: "film"
            title: name
            sub: info
            progress: prog
            selected: ListView.isCurrentItem && list.activeFocus
            playing: app.playerOpen && app.nowPath === path
            onClicked: { list.currentIndex = index; root.playAt(index, false); }
            onPressAndHold: { list.currentIndex = index; root.menuAt(index); }
            onAction: { list.currentIndex = index; root.menuAt(index); }
        }

        Keys.onPressed: {
            var k = event.key, t = event.text ? event.text.toLowerCase() : "";
            if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) { root.playAt(currentIndex, false); event.accepted = true; }
            else if (k === Qt.Key_Left) { app.stepTab(-1); event.accepted = true; }
            else if (k === Qt.Key_Right) { app.stepTab(1); event.accepted = true; }
            else if (k === Qt.Key_Backspace && root.filter !== "") { search.text = ""; event.accepted = true; }
            else if (t === "+" ) { if (currentIndex >= 0) app.addToList(vmodel.get(currentIndex).path, vmodel.get(currentIndex).name); event.accepted = true; }
            else if (k === Qt.Key_Space || k === Qt.Key_Menu || k === Qt.Key_Context1) { root.menuAt(currentIndex); event.accepted = true; }
            else if (U.printable(event)) {
                // Ilk harf arama kutusuna yazilir
                search.text = event.text;
                search.focusInput();
                search.input.cursorPosition = search.text.length;
                event.accepted = true;
            }
        }
    }

    Text {
        anchors.centerIn: list
        width: parent.width - 80
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        visible: vmodel.count === 0
        text: lib.scanning ? qsTr("Videolar aranıyor...") : (root.filter !== "" ? qsTr("Eşleşen video yok") : qsTr("Telefonda video bulunamadı.\nYenile düğmesiyle yeniden taratabilir ya da Klasörler'den gezebilirsiniz."))
        color: app.textSecondary
        font.pixelSize: 18
    }
}
