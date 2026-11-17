import QtQuick 1.1
import "Util.js" as U

// Dosya gezgini. notesMode: Notlar sekmesi (notlar klasorunun disina cikmaz, tarihe gore siralar).
// Klavye (harfler buyuk/kucuk fark etmez):
//   Enter ac • Geri/Esc ust klasor • Bosluk / sol yazilim tusu: secenekler • Sol/Sag: sekme
//   N yeni dosya • K yeni klasor • C kopyala • X kes • V yapistir • R yeniden adlandir
//   U uzanti / donustur • D sil • M isaretle • A tumunu isaretle • F favori • Y yazisini panoya
//   P panodan yeni not • E disa aktar • I ice aktar • S siralama • T tum dosyalar • G metin olarak ac
//   W goruntule (salt okunur) • O sistemde ac • B dosyalarda ara • / adla suz • L bilgi • H yardim
Rectangle {
    id: root
    color: app.bg
    clip: true

    property bool notesMode: false
    property string path: ""             // "" = kokler (yalnizca Dosyalar sekmesinde)
    property string filter: ""
    property int markedCount: 0
    property string sortMode: notesMode ? app.notesSort : app.filesSort

    function takeFocus() { list.forceActiveFocus(); }
    function rootPath() { return notesMode ? fs.notesDir() : ""; }
    function reload() { load(path, list.currentIndex >= 0 && list.currentIndex < fmodel.count ? fmodel.get(list.currentIndex).fpath : ""); }

    function openPath(p, selectPath) {
        filter = "";
        load(p, selectPath);
    }
    function load(p, selectPath) {
        if (p !== "" && !fs.isDir(p)) p = rootPath();
        path = p;
        var old = {};
        for (var j = 0; j < fmodel.count; j++) if (fmodel.get(j).marked) old[fmodel.get(j).fpath] = true;
        fmodel.clear();
        var items = fs.listDir(p, app.showAll, filter, sortMode);
        var sel = 0, mc = 0;
        var cutSet = {};
        if (app.clipMode === "cut") for (var c = 0; c < app.clipPaths.length; c++) cutSet[app.clipPaths[c]] = true;
        var favs = app.favList(), favSet = {};
        for (var f = 0; f < favs.length; f++) favSet[favs[f]] = true;
        for (var i = 0; i < items.length; i++) {
            var it = items[i];
            var info;
            if (it.dir) info = p === "" ? it.path : qsTr("Klasör");
            else info = U.sizeText(it.size) + "  •  " + U.dateText(it.time) + (it.text ? "" : qsTr("  •  metin değil"));
            var m = !!old[it.path];
            if (m) mc++;
            fmodel.append({ name: it.name, fpath: it.path, isDir: it.dir, ext: it.ext, isText: it.text, info: info,
                            marked: m, cutting: !!cutSet[it.path], fav: !!favSet[it.path] });
            if (selectPath && it.path === selectPath) sel = i;
        }
        markedCount = mc;
        list.currentIndex = fmodel.count > 0 ? Math.min(sel, fmodel.count - 1) : -1;
        if (list.currentIndex >= 0) list.positionViewAtIndex(list.currentIndex, ListView.Contain);
    }
    function current() { return list.currentIndex >= 0 && list.currentIndex < fmodel.count ? fmodel.get(list.currentIndex) : null; }
    function selectedPaths() {
        var out = [];
        for (var i = 0; i < fmodel.count; i++) if (fmodel.get(i).marked) out.push(fmodel.get(i).fpath);
        if (!out.length && current() && path !== "") out.push(current().fpath);
        return out;
    }
    function allPaths() {
        var out = [];
        for (var i = 0; i < fmodel.count; i++) out.push(fmodel.get(i).fpath);
        return out;
    }
    function allTextPaths() {
        var out = [];
        for (var i = 0; i < fmodel.count; i++) if (!fmodel.get(i).isDir && fmodel.get(i).isText) out.push(fmodel.get(i).fpath);
        return out;
    }
    function enter(i) {
        if (i < 0 || i >= fmodel.count) return;
        var it = fmodel.get(i);
        if (it.isDir) load(it.fpath, "");
        else app.akilliAc(it.fpath);         // varsayilan programla (Ayarlar > Varsayılan programlar); SIS/JAR yukleyici, zip icerigi
    }
    function up() {
        if (path === "" || (notesMode && path.toLowerCase() === fs.notesDir().toLowerCase())) return false;
        var from = path;
        var parent = fs.parentDir(path);
        if (notesMode && parent.toLowerCase().indexOf(fs.notesDir().toLowerCase()) !== 0) parent = fs.notesDir();
        filter = "";
        load(parent, from);
        return true;
    }
    function toggleMark(i) {
        if (i < 0 || i >= fmodel.count || path === "") return;
        var m = !fmodel.get(i).marked;
        fmodel.setProperty(i, "marked", m);
        markedCount += m ? 1 : -1;
    }
    function temizle() {
        for (var j = 0; j < fmodel.count; j++) if (fmodel.get(j).marked) fmodel.setProperty(j, "marked", false);
        markedCount = 0;
    }
    function markAll() {
        if (path === "") return;
        var to = markedCount < fmodel.count;
        for (var i = 0; i < fmodel.count; i++) fmodel.setProperty(i, "marked", to);
        markedCount = to ? fmodel.count : 0;
        app.showToast(to ? fmodel.count + qsTr(" öğe işaretlendi") : qsTr("İşaretler kaldırıldı"));
    }
    function cycleSort() {
        var next = sortMode === "name" ? "date" : sortMode === "date" ? "size" : "name";
        if (notesMode) { app.notesSort = next; app.setSetting("notesSort", next); }
        else { app.filesSort = next; app.setSetting("filesSort", next); }
        reload();
        app.showToast(qsTr("Sıralama: ") + (next === "name" ? qsTr("ada göre") : next === "date" ? qsTr("tarihe göre (yeni önce)") : qsTr("boyuta göre")));
    }
    function setFilter() {
        input.open({ title: qsTr("Adla süz"), label1: qsTr("Ad içinde geçen yazı (boş: hepsi)"), text1: filter, ok: qsTr("Süz") }, function (t) {
            root.filter = t;
            root.load(root.path, "");
        });
    }

    // ---- Menuler ----
    function menuAt(i) {
        if (i < 0 || i >= fmodel.count) { backgroundMenu(); return; }
        var it = fmodel.get(i);
        if (markedCount > 0) { markedMenu(); return; }
        if (path === "") { rootMenu(it); return; }
        if (it.isDir) folderMenu(it); else fileMenu(it);
    }
    function rootMenu(it) {
        sheet.open(it.name, [
            { label: qsTr("Aç"), icon: "folder", key: "open", hint: qsTr("Enter") },
            { label: qsTr("Yeni dosya burada"), icon: "plus", key: "new" },
            { label: qsTr("Dosyalarda ara"), icon: "search", key: "search" },
            { label: qsTr("Drive'a yedekle (alt klasörlerle)"), icon: "yukle", key: "backup" },
            { label: it.fav ? qsTr("Favoriden çıkar") : qsTr("Favorilere ekle"), icon: it.fav ? "star" : "star_o", key: "fav" }
        ], function (k) {
            if (k === "open") root.load(it.fpath, "");
            else if (k === "new") app.newFileMenu(it.fpath);
            else if (k === "search") app.searchIn(it.fpath);
            else if (k === "backup") app.backupFolder(it.fpath);
            else if (k === "fav") app.toggleFav(it.fpath);
        });
    }
    function fileMenu(it) {
        var p = it.fpath;
        var items = [
            { label: it.isText ? qsTr("Düzenle") : qsTr("Aç (uygun uygulamayla)"), icon: it.isText ? "edit" : "globe", key: it.isText ? "edit" : "smart", hint: qsTr("Enter") },
            { label: qsTr("Drive'a yükle"), icon: "yukle", key: "drive", hint: "Q" },
            { label: it.isText ? qsTr("Görüntüle (salt okunur)") : qsTr("Metin olarak aç"), icon: "eye", key: it.isText ? "view" : "edit", hint: it.isText ? "W" : "G" },
            { label: qsTr("Sistemde aç"), icon: "globe", key: "ext", hint: "O" },
            { label: qsTr("Uzantıyı değiştir / dönüştür…"), icon: "swap", key: "extn", hint: "U" },
            { label: qsTr("Yazısını panoya kopyala"), icon: "paste", key: "clip", hint: "Y" },
            { label: qsTr("Kopyala (dosya)"), icon: "copy", key: "copy", hint: "C" },
            { label: qsTr("Kes (taşımak için)"), icon: "cut", key: "cut", hint: "X" },
            { label: qsTr("Çoğalt (aynı klasöre kopya)"), icon: "copy", key: "dup" },
            { label: qsTr("Yeniden adlandır"), icon: "edit", key: "ren", hint: "R" },
            { label: qsTr("İşaretle (çoklu seçim)"), icon: "mark", key: "mark", hint: "M" }
        ];
        var ex = (it.ext || "").toLowerCase();
        if (ex === "zip") { items.splice(1, 0, { label: qsTr("Zip içeriğini göster"), icon: "zip", key: "zipgor" }, { label: qsTr("Buraya çıkar (klasöre)"), icon: "zip", key: "zipac" }); }
        else items.push({ label: qsTr("Zip'e sıkıştır"), icon: "zip", key: "zip", hint: "Z" });
        items.push({ label: qsTr("Arşive ekle (sıkıştırmasız)…"), icon: "zip", key: "arsiv" });
        if (/^(mp3|aac|m4a|wav|amr|ogg|wma|flac|awb|3ga)$/.test(ex)) items.splice(1, 0, { label: qsTr("Harici oynatıcıda aç"), icon: "globe", key: "ext" });
        if (/^(mp4|3gp|3g2|avi|m4v|mov)$/.test(ex)) items.splice(1, 0, { label: qsTr("Ses olarak çal (dahili, deneysel)"), icon: "muzik", key: "ses" });
        if (!notesMode) items.push({ label: qsTr("Notlarıma içe aktar"), icon: "import", key: "imp" });
        if (fs.isBundle(p)) items.push({ label: qsTr("Paketi aç (dosyalara ayır)"), icon: "import", key: "bundle" });
        items.push({ label: qsTr("Dışa aktar…"), icon: "export", key: "exp", hint: "E" });
        items.push({ label: it.fav ? qsTr("Favoriden çıkar") : qsTr("Favorilere ekle"), icon: it.fav ? "star" : "star_o", key: "fav", hint: "F" });
        items.push({ label: qsTr("Bilgi"), icon: "info", key: "info", hint: "L" });
        items.push({ label: qsTr("Sil"), icon: "trash", key: "del", danger: true, hint: "D" });
        sheet.open(it.name, items, function (k) {
            if (k === "edit") app.openFile(p, "edit");
            else if (k === "smart") app.akilliAc(p);
            else if (k === "zip") app.zipYap([p], "");
            else if (k === "zipgor") app.zipGoster(p);
            else if (k === "zipac") app.zipTumunuAc(p);
            else if (k === "arsiv") app.arsiveEkle([p]);
            else if (k === "ses") app.sesCal(p);
            else if (k === "drive") app.driveYukle(p);
            else if (k === "view") app.openFile(p, "view");
            else if (k === "ext") app.openExternal(p);
            else if (k === "extn") app.extensionMenu(p);
            else if (k === "clip") app.copyTextOf(p);
            else if (k === "copy") app.copyItems([p], false);
            else if (k === "cut") app.copyItems([p], true);
            else if (k === "dup") app.duplicateItem(p);
            else if (k === "ren") app.renameItem(p);
            else if (k === "mark") root.toggleMark(list.currentIndex);
            else if (k === "imp") app.importFile(p, fs.notesDir());
            else if (k === "bundle") app.importBundle(p, root.path);
            else if (k === "exp") app.exportMenu([p], "");
            else if (k === "fav") app.toggleFav(p);
            else if (k === "info") app.fileInfo(p);
            else if (k === "del") app.deleteItems([p]);
        });
    }
    function folderMenu(it) {
        var p = it.fpath;
        sheet.open(it.name, [
            { label: qsTr("Aç"), icon: "folder", key: "open", hint: qsTr("Enter") },
            { label: qsTr("Kopyala"), icon: "copy", key: "copy", hint: "C" },
            { label: qsTr("Kes (taşımak için)"), icon: "cut", key: "cut", hint: "X" },
            { label: qsTr("Yeniden adlandır"), icon: "edit", key: "ren", hint: "R" },
            { label: qsTr("İçindekileri dışa aktar…"), icon: "export", key: "exp", hint: "E" },
            { label: qsTr("Drive'a yedekle (alt klasörlerle)"), icon: "yukle", key: "backup" },
            { label: app.otoKlasorVar(p) ? qsTr("Otomatik Drive eşitlemesinden çıkar") : qsTr("Otomatik Drive eşitlemesine ekle"), icon: "senkron", key: "oto" },
            { label: qsTr("Zip'e sıkıştır"), icon: "zip", key: "zip", hint: "Z" },
            { label: qsTr("Arşive ekle (sıkıştırmasız)…"), icon: "zip", key: "arsiv" },
            { label: qsTr("Bu klasörde ara"), icon: "search", key: "search" },
            { label: qsTr("İşaretle (çoklu seçim)"), icon: "mark", key: "mark", hint: "M" },
            { label: qsTr("Notlar klasörü yap"), icon: "home", key: "notes" },
            { label: it.fav ? qsTr("Favoriden çıkar") : qsTr("Favorilere ekle"), icon: it.fav ? "star" : "star_o", key: "fav", hint: "F" },
            { label: qsTr("Bilgi"), icon: "info", key: "info", hint: "L" },
            { label: qsTr("Sil (içindekilerle)"), icon: "trash", key: "del", danger: true, hint: "D" }
        ], function (k) {
            if (k === "open") root.load(p, "");
            else if (k === "copy") app.copyItems([p], false);
            else if (k === "cut") app.copyItems([p], true);
            else if (k === "ren") app.renameItem(p);
            else if (k === "exp") app.exportMenu([p], it.name);
            else if (k === "backup") app.backupFolder(p);
            else if (k === "search") app.searchIn(p);
            else if (k === "oto") app.otoKlasorDegistir(p);
            else if (k === "zip") app.zipYap([p], "");
            else if (k === "arsiv") app.arsiveEkle([p]);
            else if (k === "mark") root.toggleMark(list.currentIndex);
            else if (k === "notes") { fs.setNotesDir(p); app.setSetting("notesDir", p); notesPage.openPath(p, ""); app.showToast(qsTr("Notlar klasörü: ") + p); }
            else if (k === "fav") app.toggleFav(p);
            else if (k === "info") app.fileInfo(p);
            else if (k === "del") app.deleteItems([p]);
        });
    }
    function markedMenu() {
        var ps = selectedPaths();
        sheet.open(ps.length + qsTr(" öğe işaretli"), [
            { label: qsTr("Kopyala"), icon: "copy", key: "copy", hint: "C" },
            { label: qsTr("Kes (taşımak için)"), icon: "cut", key: "cut", hint: "X" },
            { label: qsTr("Dışa aktar…"), icon: "export", key: "exp", hint: "E" },
            { label: qsTr("Drive'a yükle (klasörler dahil)"), icon: "yukle", key: "drive" },
            { label: qsTr("Zip'e sıkıştır"), icon: "zip", key: "zip", hint: "Z" },
            { label: qsTr("Arşive ekle (sıkıştırmasız)…"), icon: "zip", key: "arsiv" },
            { label: qsTr("Favorilere ekle"), icon: "star", key: "fav" },
            { label: qsTr("Tümünün yazısını panoya kopyala"), icon: "paste", key: "clip" },
            { label: qsTr("İşaretleri kaldır"), icon: "unmark", key: "clear", hint: "A" },
            { label: qsTr("Sil"), icon: "trash", key: "del", danger: true, hint: "D" }
        ], function (k) {
            if (k === "copy") app.copyItems(ps, false);
            else if (k === "cut") app.copyItems(ps, true);
            else if (k === "exp") app.exportMenu(ps, "");
            else if (k === "drive") app.driveYukleCok(ps);
            else if (k === "zip") app.zipYap(ps, "");
            else if (k === "arsiv") { root.temizle(); app.arsiveEkle(ps); }
            else if (k === "fav") { app.favorilereEkle(ps); root.temizle(); }
            else if (k === "clip") {
                var all = [];
                for (var i = 0; i < ps.length; i++) {
                    if (fs.isDir(ps[i])) continue;
                    var r = fs.readText(ps[i], app.defaultEncoding);
                    if (r.ok) all.push(r.text);
                }
                fs.setClipboardText(all.join("\n\n"));
                app.showToast(all.length + qsTr(" dosyanın yazısı panoda"));
            }
            else if (k === "clear") { for (var j = 0; j < fmodel.count; j++) fmodel.setProperty(j, "marked", false); root.markedCount = 0; }
            else if (k === "del") app.deleteItems(ps);
        });
    }
    function backgroundMenu() {
        var items = [];
        if (path !== "") {
            items.push({ label: qsTr("Yeni dosya"), icon: "plus", key: "new", hint: "N" });
            items.push({ label: qsTr("Yeni klasör"), icon: "newfolder", key: "folder", hint: "K" });
            if (app.clipPaths.length) items.push({ label: qsTr("Yapıştır (") + app.clipPaths.length + ")", icon: "paste", key: "paste", hint: "V" });
            items.push({ label: qsTr("Panodaki yazıdan yeni not"), icon: "paste", key: "clip", hint: "P" });
            items.push({ label: qsTr("Tümünü işaretle"), icon: "mark", key: "all", hint: "A" });
            items.push({ label: qsTr("Tümünü dışa aktar…"), icon: "export", key: "exp", hint: "E" });
            items.push({ label: qsTr("İçe aktar…"), icon: "import", key: "imp", hint: "I" });
            items.push({ label: qsTr("Bu klasörü Drive'a yedekle"), icon: "yukle", key: "backup" });
            if (root.notesMode) items.push({ label: qsTr("Tüm notları Drive'a eşitle"), icon: "senkron", key: "esitle" });
            items.push({ label: qsTr("Tümünü zip'e sıkıştır"), icon: "zip", key: "zipall" });
            items.push({ label: qsTr("Dosyalarda ara"), icon: "search", key: "search", hint: "B" });
            items.push({ label: qsTr("Adla süz"), icon: "search", key: "filter", hint: "/" });
        }
        items.push({ label: qsTr("Sıralama: ") + (sortMode === "name" ? "ad" : sortMode === "date" ? "tarih" : "boyut"), icon: "sort", key: "sort", hint: "S" });
        items.push({ label: app.showAll ? qsTr("Yalnızca metin dosyaları") : qsTr("Tüm dosyaları göster"), icon: "file", key: "all2", hint: "T" });
        items.push({ label: qsTr("Kısayollar / yardım"), icon: "help", key: "help", hint: "H" });
        items.push({ label: qsTr("Çıkış"), icon: "quit", key: "quit", hint: qsTr("Ctrl+Q") });
        sheet.open(path === "" ? qsTr("Dosyalar") : path, items, function (k) {
            if (k === "new") app.newFileMenu(root.path);
            else if (k === "folder") app.newFolder(root.path);
            else if (k === "paste") app.pasteInto(root.path);
            else if (k === "clip") app.newFromClipboard(root.path);
            else if (k === "all") root.markAll();
            else if (k === "exp") app.exportMenu(root.allPaths(), fs.fileName(root.path));
            else if (k === "imp") app.importMenu(root.path);
            else if (k === "backup") app.backupFolder(root.path);
            else if (k === "esitle") app.notlariEsitle(false);
            else if (k === "zipall") app.zipYap([root.path], fs.fileName(root.path));
            else if (k === "search") app.searchIn(root.path);
            else if (k === "filter") root.setFilter();
            else if (k === "sort") root.cycleSort();
            else if (k === "all2") root.toggleShowAll();
            else if (k === "help") help.open();
            else if (k === "quit") app.quit();
        });
    }
    function toggleShowAll() {
        app.showAll = !app.showAll;
        app.setSetting("showAll", app.showAll ? "1" : "0");
        app.refreshAll();
        app.showToast(app.showAll ? qsTr("Tüm dosyalar gösteriliyor") : qsTr("Yalnızca metin dosyaları"));
    }

    ListModel { id: fmodel }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        showBack: root.path !== "" && !(root.notesMode && root.path.toLowerCase() === fs.notesDir().toLowerCase())
        title: root.notesMode && root.path.toLowerCase() === fs.notesDir().toLowerCase() ? qsTr("Notlarım")
             : (root.path === "" ? qsTr("Dosyalar") : fs.fileName(root.path) || root.path)
        subtitle: (root.markedCount > 0 ? root.markedCount + qsTr(" işaretli  ") : "")
                  + (root.filter !== "" ? qsTr("süzgeç: ") + root.filter + "  " : "")
                  + (app.clipPaths.length ? (app.clipMode === "cut" ? "✂ " : "⧉ ") + app.clipPaths.length + "  " : "")
                  + root.path
        onBack: root.up()
        IconButton {
            visible: root.path !== "" && app.clipPaths.length > 0
            icon: "paste"; tone: "a"; iconSize: 24
            onClicked: app.pasteInto(root.path)
        }
        IconButton {
            visible: root.notesMode
            icon: "senkron"; tone: drive.isAktif ? "a" : "w"; iconSize: 30
            onClicked: app.notlariEsitle(false)          // tum notlari Drive'a esitle
        }
        IconButton {
            visible: root.notesMode && root.markedCount === 0
            icon: "gear"; tone: "w"; iconSize: 24
            onClicked: app.notAyarlari()                 // not ayarlari (duzenleyici, klasor, esitleme)
        }
        IconButton {
            visible: root.path !== ""
            icon: "plus"; tone: "a"; iconSize: 26
            onClicked: app.newFileMenu(root.path)
        }
        IconButton {
            icon: "more"; tone: "w"; iconSize: 24
            onClicked: root.backgroundMenu()
        }
    }

    // Secim cubugu: isaretli oge varken altta
    SecimCubugu {
        id: secimCubugu
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        adet: root.markedCount
        onKopyala: { app.copyItems(root.selectedPaths(), false); root.temizle(); }
        onKes: { app.copyItems(root.selectedPaths(), true); root.temizle(); }
        onArsiv: { var ps = root.selectedPaths(); root.temizle(); app.arsiveEkle(ps); }
        onSil: { var ps = root.selectedPaths(); root.temizle(); app.deleteItems(ps); }
        onTumu: root.markAll()
        onDaha: root.markedMenu()
        onKapat: root.temizle()
    }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: secimCubugu.visible ? secimCubugu.top : parent.bottom }
        clip: true
        model: fmodel
        focus: true
        highlightMoveDuration: 100
        delegate: FileRow {
            width: list.width
            icon: U.iconFor(ext, isDir)
            title: name
            sub: info
            marked: model.marked
            cut: cutting
            fav: model.fav
            selected: ListView.isCurrentItem && list.activeFocus
            // secim varken dokunus secime ekler/cikarir; basili tut secimi baslatir; sagdaki ... menu
            onClicked: { list.currentIndex = index; if (root.markedCount > 0 && root.path !== "") root.toggleMark(index); else root.enter(index); }
            onPressAndHold: {
                list.currentIndex = index;
                if (root.path === "") { root.menuAt(index); return; }
                if (root.markedCount === 0) app.showToast(qsTr("Seçim: dokunarak ekleyin, alttaki çubuktan işlem yapın"));
                root.toggleMark(index);
            }
            onAction: { list.currentIndex = index; root.menuAt(index); }
        }
        Keys.onPressed: {
            var k = event.key, t = U.tus(event);
            var cur = root.current();
            var ctrl = U.ctrl(event);
            if (ctrl && (k === Qt.Key_Q || t === "q")) { app.quit(); event.accepted = true; return; }
            if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) { root.enter(currentIndex); event.accepted = true; }
            else if (k === Qt.Key_Backspace || k === Qt.Key_Escape || k === Qt.Key_Context2) { if (!root.up() && root.filter !== "") { root.filter = ""; root.reload(); } event.accepted = true; }
            else if (k === Qt.Key_Left) { app.stepTab(-1); event.accepted = true; }
            else if (k === Qt.Key_Right) { if (!root.notesMode) favPanel.takeFocus(); else app.stepTab(1); event.accepted = true; }
            else if (k === Qt.Key_Space || k === Qt.Key_Menu || k === Qt.Key_Context1) { root.menuAt(currentIndex); event.accepted = true; }
            else if (!U.printable(event) && !ctrl) return;
            else {
                event.accepted = true;
                var inDir = root.path !== "";
                var file = cur && !cur.isDir && inDir;
                if (k === Qt.Key_C && ctrl || t === "c") { if (inDir) app.copyItems(root.selectedPaths(), false); }
                else if (k === Qt.Key_X && ctrl || t === "x") { if (inDir) app.copyItems(root.selectedPaths(), true); }
                else if (k === Qt.Key_V && ctrl || t === "v") app.pasteInto(root.path);
                else if (t === "n") { if (inDir) app.newFileMenu(root.path); }
                else if (t === "k") { if (inDir) app.newFolder(root.path); }
                else if (t === "r") { if (cur && inDir) app.renameItem(cur.fpath); }
                else if (t === "u") { if (file) app.extensionMenu(cur.fpath); }
                else if (t === "d") { if (inDir) app.deleteItems(root.selectedPaths()); }
                else if (t === "m") { root.toggleMark(currentIndex); if (currentIndex < fmodel.count - 1) currentIndex++; }
                else if (t === "a") root.markAll();
                else if (t === "f") { if (cur) app.toggleFav(cur.fpath); }
                else if (t === "y") { if (file) app.copyTextOf(cur.fpath); }
                else if (t === "p") { if (inDir) app.newFromClipboard(root.path); }
                else if (t === "e") { if (inDir) app.exportMenu(root.markedCount ? root.selectedPaths() : root.allPaths(), fs.fileName(root.path)); }
                else if (t === "i") { if (file && !root.notesMode) app.importFile(cur.fpath, fs.notesDir()); else app.importMenu(inDir ? root.path : ""); }
                else if (t === "s") root.cycleSort();
                else if (t === "t") root.toggleShowAll();
                else if (t === "g") { if (file) app.openFile(cur.fpath, "edit"); }
                else if (t === "w") { if (file) app.openFile(cur.fpath, "view"); }
                else if (t === "o") { if (file) app.openExternal(cur.fpath); }
                else if (t === "q") { if (file) app.driveYukle(cur.fpath); }
                else if (t === "b") app.searchIn(inDir ? root.path : fs.notesDir());
                else if (t === "/") root.setFilter();
                else if (t === "l") { if (cur && inDir) app.fileInfo(cur.fpath); }
                else if (t === "h" || t === "?") help.open();
                else if (t === "j") { currentIndex = Math.min(fmodel.count - 1, currentIndex + 8); }
                else if (t === "z") { if (cur && inDir) app.zipYap(root.markedCount ? root.selectedPaths() : [cur.fpath], ""); }
            }
        }
    }

    Column {
        anchors.centerIn: list
        width: list.width - 24
        visible: fmodel.count === 0
        spacing: 6
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: root.filter !== "" ? qsTr("Süzgece uyan dosya yok") : (root.notesMode ? qsTr("Henüz not yok") : qsTr("Bu klasör boş"))
            color: app.textSecondary
            font.pixelSize: Math.round(18 * app.yazi)
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: qsTr("N: yeni dosya  •  P: panodan  •  T: tüm dosyalar  •  H: yardım")
            color: app.textSecondary
            font.pixelSize: Math.round(14 * app.yazi)
        }
    }
}
