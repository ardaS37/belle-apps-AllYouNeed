import QtQuick 1.1
import "Util.js" as U

// Klasor gezgini: hafiza karti ve telefon bellegi. Video ve ses dosyalarini gosterir.
// Klavye: Enter klasore girer / oynatir, Geri ust klasore cikar, Bosluk secenekler,
// +: listeye ekle, Sol/Sag: sekme
Rectangle {
    id: root
    color: app.bg

    property string path: ""             // "" = kokler
    property variant stack: []           // ust klasorlerde secili satir
    property variant mediaPaths: []
    property variant mediaTitles: []

    function takeFocus() { list.forceActiveFocus(); }

    function reload() { open(path, list.currentIndex); }

    function open(p, selectIndex) {
        path = p;
        fmodel.clear();
        var items = lib.listDir(p);
        var mp = [], mt = [];
        for (var i = 0; i < items.length; i++) {
            var it = items[i];
            var info = it.dir ? (p === "" ? it.path : "") : (U.sizeText(it.size) + "  •  " + U.dateText(it.time));
            if (!it.dir) {
                var sp = lib.savedPosition(it.path);
                if (sp > 0) info += "  •  " + U.fmt(sp) + qsTr("'de kaldı");
            }
            fmodel.append({ name: it.name, fpath: it.path, isDir: it.dir, kind: it.kind, info: info });
            if (!it.dir) { mp.push(it.path); mt.push(lib.baseName(it.path)); }
        }
        mediaPaths = mp; mediaTitles = mt;
        list.currentIndex = fmodel.count > 0 ? Math.max(0, Math.min(selectIndex || 0, fmodel.count - 1)) : -1;
        if (list.currentIndex >= 0) list.positionViewAtIndex(list.currentIndex, ListView.Contain);
    }
    function enter(i) {
        if (i < 0 || i >= fmodel.count) return;
        var it = fmodel.get(i);
        if (it.isDir) {
            var s = stack; s.push(i); stack = s;
            open(it.fpath, 0);
        } else {
            app.play(mediaPaths, mediaTitles, indexIn(it.fpath), "folder", false);
        }
    }
    function up() {
        if (path === "") return false;
        var s = stack;
        var sel = s.length > 0 ? s.pop() : 0;
        stack = s;
        open(lib.parentDir(path), sel);
        return true;
    }
    function indexIn(p) { for (var i = 0; i < mediaPaths.length; i++) if (mediaPaths[i] === p) return i; return 0; }
    function menuAt(i) {
        if (i < 0 || i >= fmodel.count) return;
        var it = fmodel.get(i);
        if (it.isDir) {
            var media = lib.mediaInDir(it.fpath);
            sheetFolder(it.fpath, it.name, media);
            return;
        }
        app.fileMenu(it.fpath, lib.baseName(it.fpath), mediaPaths, mediaTitles, indexIn(it.fpath), "folder");
    }
    function sheetFolder(fp, name, media) {
        var items = [{ label: qsTr("Aç"), icon: "folder", key: "open" }];
        if (media.length > 0) {
            items.push({ label: qsTr("Tümünü oynat (") + media.length + ")", icon: "play", key: "play" });
            items.push({ label: qsTr("Tümünü sadece ses ile çal"), icon: "phones", key: "audio" });
            items.push({ label: qsTr("Tümünü listeye ekle"), icon: "plus", key: "list" });
        }
        sheet.open(name, items, function (k) {
            if (k === "open") root.enter(list.currentIndex);
            else if (k === "play") app.play(media, [], 0, "folder", false);
            else if (k === "audio") app.play(media, [], 0, "folder", true);
            else if (k === "list") app.addManyToList(media);
        });
    }

    Component.onCompleted: open("", 0)

    ListModel { id: fmodel }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        showBack: root.path !== ""
        title: root.path === "" ? qsTr("Klasörler") : (lib.folderName(root.path + "/x") || root.path)
        subtitle: root.path
        onBack: root.up()
        IconButton {
            visible: root.mediaPaths.length > 0
            icon: "plus"; tone: "g"; iconSize: 24
            onClicked: app.addManyToList(root.mediaPaths)
        }
        IconButton {
            visible: root.mediaPaths.length > 0
            icon: "play"; tone: "a"; iconSize: 26
            onClicked: app.play(root.mediaPaths, root.mediaTitles, 0, "folder", false)
        }
    }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        clip: true
        model: fmodel
        focus: true
        highlightMoveDuration: 120
        delegate: FileRow {
            width: list.width
            icon: isDir ? "folder" : (kind === "audio" ? "note" : "film")
            title: name
            sub: info
            selected: ListView.isCurrentItem && list.activeFocus
            playing: !isDir && app.playerOpen && app.nowPath === fpath
            actionIcon: isDir && root.path === "" ? "" : "more"
            onClicked: { list.currentIndex = index; root.enter(index); }
            onPressAndHold: { list.currentIndex = index; root.menuAt(index); }
            onAction: { list.currentIndex = index; root.menuAt(index); }
        }
        Keys.onPressed: {
            var k = event.key, t = event.text ? event.text : "";
            if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) { root.enter(currentIndex); event.accepted = true; }
            else if (k === Qt.Key_Backspace || k === Qt.Key_Escape) { root.up(); event.accepted = true; }
            else if (k === Qt.Key_Left) { app.stepTab(-1); event.accepted = true; }
            else if (k === Qt.Key_Right) { app.stepTab(1); event.accepted = true; }
            else if (k === Qt.Key_Space || k === Qt.Key_Menu || k === Qt.Key_Context1) { root.menuAt(currentIndex); event.accepted = true; }
            else if (t === "+" && currentIndex >= 0 && !fmodel.get(currentIndex).isDir) {
                app.addToList(fmodel.get(currentIndex).fpath, lib.baseName(fmodel.get(currentIndex).fpath));
                event.accepted = true;
            } else if (U.printable(event)) {
                // Harfe basinca o harfle baslayan bir sonraki satira atla
                var c = U.fold(t);
                for (var n = 1; n <= fmodel.count; n++) {
                    var j = (currentIndex + n) % fmodel.count;
                    if (U.fold(fmodel.get(j).name).charAt(0) === c) { currentIndex = j; break; }
                }
                event.accepted = true;
            }
        }
    }

    Text {
        anchors.centerIn: list
        visible: fmodel.count === 0
        text: qsTr("Bu klasörde video ya da ses dosyası yok")
        color: app.textSecondary
        font.pixelSize: 18
    }
}
