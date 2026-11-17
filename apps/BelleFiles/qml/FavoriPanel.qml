import QtQuick 1.1
import "Util.js" as U

// Dosyalar sekmesinin sag yarisi: favori klasorler ve dosyalar.
// Klasore dokun: sol tarafta acilir. Dosyaya dokun: varsayilan programla acilir.
// Basili tut: coklu secim. Klavye: Sol tus sol yariya, Sag tus sonraki sekmeye; F favoriden cikar.
Rectangle {
    id: root
    color: app.bg
    property int markedCount: 0

    function takeFocus() { list.forceActiveFocus(); }
    function reload() {
        var eski = {}, keep = list.currentIndex;
        for (var j = 0; j < fm.count; j++) if (fm.get(j).marked) eski[fm.get(j).fpath] = true;
        fm.clear();
        var l = app.favList(), dirs = [], files = [], mc = 0;
        for (var i = 0; i < l.length; i++) {
            var p = l[i], varmi = fs.exists(p), d = varmi && fs.isDir(p);
            var o = { fpath: p, name: fs.fileName(p) || p, isDir: d, ext: d ? "" : fs.suffix(p), yok: !varmi,
                      info: !varmi ? qsTr("bulunamadı  •  ") + fs.folderOf(p) : fs.folderOf(p), marked: !!eski[p] };
            if (o.marked) mc++;
            if (d) dirs.push(o); else files.push(o);
        }
        var cmp = function (a, b) { return a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1; };
        dirs.sort(cmp); files.sort(cmp);
        var all = dirs.concat(files);
        for (var k = 0; k < all.length; k++) fm.append(all[k]);
        markedCount = mc;
        list.currentIndex = fm.count ? Math.max(0, Math.min(keep, fm.count - 1)) : -1;
    }
    function secili() {
        var out = [];
        for (var i = 0; i < fm.count; i++) if (fm.get(i).marked) out.push(fm.get(i).fpath);
        if (!out.length && list.currentIndex >= 0 && list.currentIndex < fm.count) out.push(fm.get(list.currentIndex).fpath);
        return out;
    }
    function isaretle(i) {
        if (i < 0 || i >= fm.count) return;
        var m = !fm.get(i).marked;
        fm.setProperty(i, "marked", m);
        markedCount += m ? 1 : -1;
    }
    function temizle() { for (var j = 0; j < fm.count; j++) fm.setProperty(j, "marked", false); markedCount = 0; }
    function tumu() {
        var to = markedCount < fm.count;
        for (var j = 0; j < fm.count; j++) fm.setProperty(j, "marked", to);
        markedCount = to ? fm.count : 0;
    }
    function ac(i) {
        if (i < 0 || i >= fm.count) return;
        var o = fm.get(i);
        if (o.yok) { app.showToast(qsTr("Bulunamadı (taşınmış ya da silinmiş): ") + o.fpath); return; }
        if (o.isDir) { filesPage.openPath(o.fpath, ""); filesPage.takeFocus(); }
        else app.akilliAc(o.fpath);
    }
    function cikar(ps) {
        for (var i = 0; i < ps.length; i++) if (app.isFav(ps[i])) app.favSil(ps[i]);
        app.showToast(ps.length === 1 ? qsTr("Favorilerden çıkarıldı") : ps.length + qsTr(" öğe favorilerden çıkarıldı"));
        app.refreshAll();
    }
    function menu(i) {
        if (markedCount > 0) { seciliMenu(); return; }
        if (i < 0 || i >= fm.count) { genelMenu(); return; }
        var o = fm.get(i), p = o.fpath;
        var items = [{ label: o.isDir ? qsTr("Solda aç") : qsTr("Aç"), icon: o.isDir ? "folder" : "eye", key: "ac", hint: qsTr("Enter") }];
        if (!o.isDir) items.push({ label: qsTr("Klasöründe göster"), icon: "folder", key: "klasor" });
        items.push({ label: qsTr("Favoriden çıkar"), icon: "star_o", key: "cikar", hint: "F" });
        if (!o.yok) {
            items.push({ label: qsTr("Kopyala"), icon: "copy", key: "kopya", hint: "C" });
            items.push({ label: qsTr("Kes (taşımak için)"), icon: "cut", key: "kes", hint: "X" });
            if (o.isDir && app.clipPaths.length) items.push({ label: qsTr("Buraya yapıştır (") + app.clipPaths.length + ")", icon: "paste", key: "yapistir", hint: "V" });
            items.push({ label: qsTr("Arşive ekle (sıkıştırmasız)…"), icon: "zip", key: "arsiv" });
            items.push({ label: qsTr("Bilgi"), icon: "info", key: "bilgi", hint: "L" });
            items.push({ label: qsTr("İşaretle (çoklu seçim)"), icon: "mark", key: "isaret", hint: "M" });
            items.push({ label: qsTr("Sil"), icon: "trash", key: "sil", danger: true, hint: "D" });
        }
        sheet.open(o.name, items, function (k) {
            if (k === "ac") root.ac(i);
            else if (k === "klasor") app.showFolder(fs.folderOf(p), p);
            else if (k === "cikar") root.cikar([p]);
            else if (k === "kopya") app.copyItems([p], false);
            else if (k === "kes") app.copyItems([p], true);
            else if (k === "yapistir") app.pasteInto(p);
            else if (k === "arsiv") app.arsiveEkle([p]);
            else if (k === "bilgi") app.fileInfo(p);
            else if (k === "isaret") root.isaretle(i);
            else if (k === "sil") app.deleteItems([p]);
        });
    }
    function seciliMenu() {
        var ps = secili();
        sheet.open(ps.length + qsTr(" favori seçili"), [
            { label: qsTr("Favorilerden çıkar"), icon: "star_o", key: "cikar" },
            { label: qsTr("Kopyala"), icon: "copy", key: "kopya" },
            { label: qsTr("Kes (taşımak için)"), icon: "cut", key: "kes" },
            { label: qsTr("Arşive ekle (sıkıştırmasız)…"), icon: "zip", key: "arsiv" },
            { label: qsTr("Zip'e sıkıştır"), icon: "zip", key: "zip" },
            { label: qsTr("Drive'a yükle"), icon: "yukle", key: "drive" },
            { label: qsTr("İşaretleri kaldır"), icon: "unmark", key: "temizle" },
            { label: qsTr("Sil"), icon: "trash", key: "sil", danger: true }
        ], function (k) {
            if (k === "temizle") { root.temizle(); return; }
            root.temizle();
            if (k === "cikar") root.cikar(ps);
            else if (k === "kopya") app.copyItems(ps, false);
            else if (k === "kes") app.copyItems(ps, true);
            else if (k === "arsiv") app.arsiveEkle(ps);
            else if (k === "zip") app.zipYap(ps, "");
            else if (k === "drive") app.driveYukleCok(ps);
            else if (k === "sil") app.deleteItems(ps);
        });
    }
    function genelMenu() {
        sheet.open(qsTr("Favoriler"), [
            { label: qsTr("Soldaki klasörü favorilere ekle"), icon: "star", key: "sol" },
            { label: qsTr("Tümünü işaretle"), icon: "mark", key: "tumu", hint: "A" },
            { label: qsTr("Bulunamayanları temizle"), icon: "close", key: "yoklar" }
        ], function (k) {
            if (k === "sol") { if (filesPage.path === "") app.showToast(qsTr("Önce solda bir klasöre girin")); else if (!app.isFav(filesPage.path)) app.toggleFav(filesPage.path); }
            else if (k === "tumu") root.tumu();
            else if (k === "yoklar") {
                var ps = [];
                for (var i = 0; i < fm.count; i++) if (fm.get(i).yok) ps.push(fm.get(i).fpath);
                if (ps.length) root.cikar(ps); else app.showToast(qsTr("Hepsi yerinde"));
            }
        });
    }

    ListModel { id: fm }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: qsTr("Favoriler")
        subtitle: root.markedCount > 0 ? root.markedCount + qsTr(" seçili") : fm.count + qsTr(" öğe")
        IconButton { icon: "star"; tone: "a"; iconSize: 24; onClicked: { if (filesPage.path === "") app.showToast(qsTr("Önce solda bir klasöre girin")); else app.toggleFav(filesPage.path); } }
        IconButton { icon: "more"; tone: "w"; iconSize: 24; onClicked: root.genelMenu() }
    }
    SecimCubugu {
        id: cubuk
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        adet: root.markedCount
        onKopyala: { app.copyItems(root.secili(), false); root.temizle(); }
        onKes: { app.copyItems(root.secili(), true); root.temizle(); }
        onArsiv: { var ps = root.secili(); root.temizle(); app.arsiveEkle(ps); }
        onSil: { var ps = root.secili(); root.temizle(); app.deleteItems(ps); }
        onTumu: root.tumu()
        onDaha: root.seciliMenu()
        onKapat: root.temizle()
    }
    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: cubuk.visible ? cubuk.top : parent.bottom }
        clip: true
        model: fm
        highlightMoveDuration: 100
        delegate: FileRow {
            width: list.width
            icon: U.iconFor(ext, isDir)
            title: name
            sub: info
            marked: model.marked
            opacity: yok ? 0.5 : 1
            selected: ListView.isCurrentItem && list.activeFocus
            onClicked: { list.currentIndex = index; if (root.markedCount > 0) root.isaretle(index); else root.ac(index); }
            onPressAndHold: { list.currentIndex = index; root.isaretle(index); }
            onAction: { list.currentIndex = index; root.menu(index); }
        }
        Keys.onPressed: {
            var k = event.key, t = U.tus(event);
            var cur = currentIndex >= 0 && currentIndex < fm.count ? fm.get(currentIndex) : null;
            if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) root.ac(currentIndex);
            else if (k === Qt.Key_Left || k === Qt.Key_Backspace || k === Qt.Key_Escape || k === Qt.Key_Context2) { if (root.markedCount > 0 && k !== Qt.Key_Left) root.temizle(); else filesPage.takeFocus(); }
            else if (k === Qt.Key_Right) app.stepTab(1);
            else if (k === Qt.Key_Space || k === Qt.Key_Menu || k === Qt.Key_Context1) root.menu(currentIndex);
            else if (t === "m") { root.isaretle(currentIndex); if (currentIndex < fm.count - 1) currentIndex++; }
            else if (t === "a") root.tumu();
            else if (t === "f") { if (cur) root.cikar(root.markedCount ? root.secili() : [cur.fpath]); }
            else if (t === "c") app.copyItems(root.secili(), false);
            else if (t === "x") app.copyItems(root.secili(), true);
            else if (t === "v") { if (cur && cur.isDir) app.pasteInto(cur.fpath); }
            else if (t === "d") app.deleteItems(root.secili());
            else if (t === "l") { if (cur) app.fileInfo(cur.fpath); }
            else return;
            event.accepted = true;
        }
    }
    Column {
        anchors.centerIn: list
        width: list.width - 30
        visible: fm.count === 0
        spacing: 8
        Image { anchors.horizontalCenter: parent.horizontalCenter; width: 40; height: 40; smooth: true; source: "../images/star_o_a.png" }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: qsTr("Favori yok.\nSolda bir klasör ya da dosyanın … menüsünden \"Favorilere ekle\" deyin, ya da bir klasördeyken yukarıdaki ★'a basın.")
            color: app.textSecondary
            font.pixelSize: Math.round(15 * app.yazi)
        }
    }
    // sol yariyla aradaki cizgi
    Rectangle { anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 1; color: app.divider }
}
