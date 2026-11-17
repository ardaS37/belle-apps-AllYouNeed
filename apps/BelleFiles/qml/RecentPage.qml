import QtQuick 1.1
import "Util.js" as U

// Favoriler ve son acilanlar. Enter ac • Bosluk menu • F favori • G klasorune git • D listeden kaldir
Rectangle {
    id: root
    color: app.bg

    function takeFocus() { list.forceActiveFocus(); }
    function reload() {
        var keep = list.currentIndex;
        rmodel.clear();
        var favs = app.favList(), seen = {};
        for (var i = 0; i < favs.length; i++) {
            seen[favs[i]] = true;
            add(favs[i], qsTr("Favoriler"), true, 0);
        }
        var rec = app.recentList();
        for (i = 0; i < rec.length; i++) if (!seen[rec[i].path]) add(rec[i].path, qsTr("Son açılanlar"), false, rec[i].t);
        list.currentIndex = rmodel.count ? Math.max(0, Math.min(keep, rmodel.count - 1)) : -1;
    }
    function add(p, sec, fav, t) {
        var ex = fs.exists(p), dir = ex && fs.isDir(p);
        var sub = (ex ? "" : qsTr("bulunamadı  •  ")) + fs.folderOf(p) + (t ? "  •  " + U.dateText(Math.floor(t / 1000)) : "");
        rmodel.append({ fpath: p, name: fs.fileName(p) || p, sub: sub, sec: sec, fav: fav, isDir: dir, ext: fs.suffix(p) });
    }
    function cur() { return list.currentIndex >= 0 && list.currentIndex < rmodel.count ? rmodel.get(list.currentIndex) : null; }
    function menuAt() {
        var it = cur();
        var items = [];
        if (it) {
            items.push({ label: qsTr("Aç"), icon: it.isDir ? "folder" : "edit", key: "open", hint: qsTr("Enter") });
            items.push({ label: qsTr("Klasörüne git"), icon: "folder", key: "show", hint: "G" });
            items.push({ label: it.fav ? qsTr("Favoriden çıkar") : qsTr("Favorilere ekle"), icon: it.fav ? "star" : "star_o", key: "fav", hint: "F" });
            if (!it.fav) items.push({ label: qsTr("Listeden kaldır"), icon: "close", key: "forget", hint: "D" });
        }
        items.push({ label: qsTr("Son açılanları temizle"), icon: "trash", key: "clear", danger: true });
        sheet.open(it ? it.name : "Son", items, function (k) {
            if (k === "open") app.openFile(it.fpath, "edit");
            else if (k === "show") app.showFolder(it.isDir ? it.fpath : fs.folderOf(it.fpath), it.fpath);
            else if (k === "fav") { app.toggleFav(it.fpath); root.reload(); }
            else if (k === "forget") { app.forgetRecent(it.fpath); root.reload(); }
            else if (k === "clear") { app.clearRecent(); root.reload(); }
        });
    }

    ListModel { id: rmodel }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: qsTr("Son ve favoriler")
        subtitle: rmodel.count + qsTr(" öğe")
        IconButton { icon: "more"; tone: "w"; iconSize: 24; onClicked: root.menuAt() }
    }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        clip: true
        model: rmodel
        focus: true
        section.property: "sec"
        section.delegate: Rectangle {
            width: list.width; height: 30; color: app.bg
            Text { anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter } text: section; color: app.brand; font.pixelSize: 15; font.bold: true }
        }
        delegate: FileRow {
            width: list.width
            icon: U.iconFor(ext, isDir)
            title: name
            sub: model.sub
            fav: model.fav
            selected: ListView.isCurrentItem && list.activeFocus
            onClicked: { list.currentIndex = index; app.openFile(fpath, "edit"); }
            onPressAndHold: { list.currentIndex = index; root.menuAt(); }
            onAction: { list.currentIndex = index; root.menuAt(); }
        }
        Keys.onPressed: {
            var k = event.key, t = U.tus(event), it = root.cur();
            if (U.ctrl(event) && (k === Qt.Key_Q || t === "q")) { app.quit(); event.accepted = true; }
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) { if (it) app.openFile(it.fpath, "edit"); event.accepted = true; }
            else if (k === Qt.Key_Left) { app.stepTab(-1); event.accepted = true; }
            else if (k === Qt.Key_Right) { app.stepTab(1); event.accepted = true; }
            else if (k === Qt.Key_Space || k === Qt.Key_Menu || k === Qt.Key_Context1) { root.menuAt(); event.accepted = true; }
            else if (t === "f" && it) { app.toggleFav(it.fpath); root.reload(); event.accepted = true; }
            else if (t === "g" && it) { app.showFolder(it.isDir ? it.fpath : fs.folderOf(it.fpath), it.fpath); event.accepted = true; }
            else if ((t === "d" || k === Qt.Key_Backspace) && it && !it.fav) { app.forgetRecent(it.fpath); root.reload(); event.accepted = true; }
            else if (t === "w" && it) { app.openFile(it.fpath, "view"); event.accepted = true; }
            else if (t === "y" && it) { app.copyTextOf(it.fpath); event.accepted = true; }
            else if (t === "h" || t === "?") { help.open(); event.accepted = true; }
        }
    }
    Text {
        anchors.centerIn: list
        visible: rmodel.count === 0
        text: qsTr("Henüz açılan dosya yok")
        color: app.textSecondary
        font.pixelSize: 18
    }
}
