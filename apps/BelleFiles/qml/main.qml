import QtQuick 1.1
import "Util.js" as U
import "Convert.js" as C
import "IsDurum.js" as ID

Rectangle {
    id: app
    width: 640
    height: 480
    color: bg

    // ---- Tema: koyu zemin, her sekmeye ayri pastel renk (yazi hep acik renk: okunur) ----
    //  sira: Notlar (sari), Dosyalar (mavi), Drive (yesil), Son (lila), Yedek (seftali), Ayarlar (pembe)
    //  her renk: [vurgu, vurgu basili, zemin, yuzey, secili satir, basili, isaretli, hap, kutu, cizgi]
    property variant renkler: [
        ["#F7D794", "#E0BC6E", "#17150F", "#231F15", "#3A321F", "#2C2618", "#2A2416", "#4A3F22", "#2E2919", "#332D1E"],
        ["#9CCBEF", "#7BB2DD", "#0F151B", "#172029", "#253546", "#1C2834", "#16262F", "#1F3B52", "#1F2A35", "#22303C"],
        ["#A8E0C0", "#86C9A3", "#0F1713", "#16221C", "#22372C", "#1B2A22", "#16281F", "#1E4030", "#1D2B24", "#21312A"],
        ["#C9B6F0", "#AE98DE", "#14111B", "#1F1A29", "#30283F", "#251F31", "#221C2E", "#372C50", "#271F33", "#2D2538"],
        ["#F8BC9A", "#E3A07B", "#1A1310", "#261C17", "#3B2B22", "#2E221B", "#2B1F18", "#4B3122", "#30241D", "#382A21"],
        ["#F2A8C4", "#DC8CAB", "#1A1015", "#26171F", "#3B2530", "#2E1C25", "#2B1822", "#4C2639", "#301E27", "#38232D"]
    ]
    property int renkSekme: tab < 0 || tab > 5 ? 1 : tab
    property color brand: renkler[renkSekme][0]
    property color brandPressed: renkler[renkSekme][1]
    property color bg: renkler[renkSekme][2]
    property color surface: renkler[renkSekme][3]
    property color highlight: renkler[renkSekme][4]
    property color pressed: renkler[renkSekme][5]
    property color markBg: renkler[renkSekme][6]
    property color pill: renkler[renkSekme][7]
    property color fieldBg: renkler[renkSekme][8]
    property color divider: renkler[renkSekme][9]
    property color textPrimary: "#F2F4F5"
    property color textSecondary: "#A3ADB6"
    property color danger: "#F47C8A"
    property color editorBg: "#0C1013"
    // Yazi boyutu (Ayarlar): duzenleyicide piksel, listelerde/menulerde oran olarak (19 = 1.0)
    property real yazi: Math.max(0.8, Math.min(1.7, fontSize / 19))
    property string version: "1.6"           // Belle Files (E6Metin + dosya yoneticisi + Drive)

    // ---- Ayarlar ----
    property int fontSize: 19
    property bool wrap: true
    property string defaultEncoding: ""      // "" otomatik
    property string newEol: "crlf"
    property bool makeBackup: false
    property bool autoSave: false
    property bool draftGuard: true
    property bool showAll: false
    property bool lineNumbers: false
    property int bigFileKB: 384
    property string notesSort: "date"
    property string filesSort: "name"
    // Varsayilan programlar: "dahili" (Belle Files) | "sistem" (telefonun uygulamasi) | "sor"
    property string acMetin: "dahili"
    property string acResim: "dahili"
    property string acVideo: "sistem"
    property string acSes: "dahili"

    // ---- Durum ----
    property int tab: 0                      // 0 Notlar, 1 Dosyalar, 2 Drive, 3 Son, 4 Yedek, 5 Ayarlar
    property bool editorOpen: false
    property variant clipPaths: []           // dosya panosu
    property string clipMode: ""             // "copy" | "cut"

    function showToast(m) { toast.show(m); }

    // ---- Kalici ayarlar (LocalStorage) ----
    function db() { return openDatabaseSync("BelleFiles", "1.0", qsTr("BelleFiles"), 200000); }
    function initDb() {
        db().transaction(function (tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS kv(k TEXT UNIQUE, v TEXT)");
            tx.executeSql("CREATE TABLE IF NOT EXISTS recent(path TEXT UNIQUE, t INTEGER, pos INTEGER)");
            tx.executeSql("CREATE TABLE IF NOT EXISTS fav(path TEXT UNIQUE, t INTEGER)");
        });
    }
    function setting(k, def) {
        var v = def;
        db().readTransaction(function (tx) {
            var rs = tx.executeSql("SELECT v FROM kv WHERE k = ?", [k]);
            if (rs.rows.length > 0) v = rs.rows.item(0).v;
        });
        return v;
    }
    function setSetting(k, v) {
        db().transaction(function (tx) { tx.executeSql("INSERT OR REPLACE INTO kv(k, v) VALUES(?, ?)", [k, "" + v]); });
    }

    // ---- Son acilanlar ve favoriler ----
    function addRecent(path, pos) {
        db().transaction(function (tx) {
            tx.executeSql("INSERT OR REPLACE INTO recent(path, t, pos) VALUES(?, ?, ?)", [path, new Date().getTime(), pos || 0]);
            tx.executeSql("DELETE FROM recent WHERE path NOT IN (SELECT path FROM recent ORDER BY t DESC LIMIT 40)");
        });
    }
    function recentPos(path) {
        var p = 0;
        db().readTransaction(function (tx) {
            var rs = tx.executeSql("SELECT pos FROM recent WHERE path = ?", [path]);
            if (rs.rows.length > 0) p = rs.rows.item(0).pos;
        });
        return p;
    }
    function recentList() {
        var out = [];
        db().readTransaction(function (tx) {
            var rs = tx.executeSql("SELECT path, t FROM recent ORDER BY t DESC");
            for (var i = 0; i < rs.rows.length; i++) out.push({ path: rs.rows.item(i).path, t: rs.rows.item(i).t });
        });
        return out;
    }
    function forgetRecent(path) { db().transaction(function (tx) { tx.executeSql("DELETE FROM recent WHERE path = ?", [path]); }); }
    function clearRecent() { db().transaction(function (tx) { tx.executeSql("DELETE FROM recent"); }); }
    function isFav(path) {
        var f = false;
        db().readTransaction(function (tx) { f = tx.executeSql("SELECT 1 FROM fav WHERE path = ?", [path]).rows.length > 0; });
        return f;
    }
    function favList() {
        var out = [];
        db().readTransaction(function (tx) {
            var rs = tx.executeSql("SELECT path FROM fav ORDER BY t DESC");
            for (var i = 0; i < rs.rows.length; i++) out.push(rs.rows.item(i).path);
        });
        return out;
    }
    function favSil(path) { db().transaction(function (tx) { tx.executeSql("DELETE FROM fav WHERE path = ?", [path]); }); }
    function favorilereEkle(ps) {
        var n = 0;
        db().transaction(function (tx) {
            for (var i = 0; i < ps.length; i++) { tx.executeSql("INSERT OR REPLACE INTO fav(path, t) VALUES(?, ?)", [ps[i], new Date().getTime()]); n++; }
        });
        showToast(n + qsTr(" öğe favorilere eklendi"));
        refreshAll();
    }
    // Arsive ekle (sikistirmasiz): yeni arsiv ya da ayni klasordeki bir zip'e ekleme
    function arsiveEkle(ps) {
        if (!ps.length) return;
        var dir = fs.folderOf(ps[0]), l = fs.listDir(dir, true, "", "date"), secili = {}, items = [];
        for (var s = 0; s < ps.length; s++) secili[ps[s]] = true;
        items.push({ label: qsTr("Yeni arşiv oluştur…"), icon: "plus", key: "yeni" });
        var n = 0;
        for (var i = 0; i < l.length && n < 10; i++) {
            if (l[i].dir || l[i].ext !== "zip" || secili[l[i].path]) continue;
            items.push({ label: qsTr("Şuna ekle: ") + l[i].name, icon: "zip", key: "z" + l[i].path });
            n++;
        }
        var ad = ps.length === 1 ? fs.fileName(ps[0]).replace(/\.[^.\/]*$/, "") : (fs.fileName(dir) || qsTr("arsiv"));
        sheet.open(qsTr("Arşive ekle (sıkıştırmasız) • ") + (ps.length === 1 ? fs.fileName(ps[0]) : ps.length + qsTr(" öğe")), items, function (k) {
            if (k === "yeni") {
                input.open({ title: qsTr("Yeni arşiv (sıkıştırmasız)"), label1: qsTr("Arşiv adı (") + dir + ")", text1: ad.replace(/[\\\/:*?"<>|]/g, "_") + ".zip", ok: qsTr("Oluştur"), selectBase: true }, function (nm) {
                    nm = nm.replace(/^\s+|\s+$/g, "");
                    if (!fs.validName(nm)) { showToast(qsTr("Geçersiz ad")); return; }
                    if (!/\.zip$/i.test(nm)) nm += ".zip";
                    var hedef = isci.benzersiz(dir, nm);
                    isBaslat("zipsakla", ps, hedef, [], qsTr("Arşivleniyor: ") + fs.fileName(hedef), function (ok, sonuc) { if (ok) showFolder(fs.folderOf(sonuc), sonuc); });
                });
                return;
            }
            var zp = k.substring(1);
            isBaslat("zipekle", ps, zp, [], qsTr("Arşive ekleniyor: ") + fs.fileName(zp), function (ok, sonuc) { if (ok) showFolder(fs.folderOf(sonuc), sonuc); });
        });
    }
    function toggleFav(path) {
        var f = isFav(path);
        db().transaction(function (tx) {
            if (f) tx.executeSql("DELETE FROM fav WHERE path = ?", [path]);
            else tx.executeSql("INSERT OR REPLACE INTO fav(path, t) VALUES(?, ?)", [path, new Date().getTime()]);
        });
        showToast(f ? qsTr("Favorilerden çıkarıldı") : qsTr("Favorilere eklendi"));
        refreshAll();
        return !f;
    }
    // Ad degisince / tasininca kayitlari guncelle
    function pathMoved(from, to) {
        db().transaction(function (tx) {
            tx.executeSql("UPDATE OR REPLACE recent SET path = ? WHERE path = ?", [to, from]);
            tx.executeSql("UPDATE OR REPLACE fav SET path = ? WHERE path = ?", [to, from]);
        });
        if (editorOpen && editor.path === from) editor.path = to;
    }

    // ---- Sekmeler ve odak ----
    function notAyarlari() {
        if (tab !== 0) { tab = 0; setSetting("tab", 0); }
        notAyar.visible = true;
        notAyar.takeFocus();
    }
    function selectTab(i) {
        if (i < 0 || i > 5) i = 0;
        if (i !== 0) notAyar.visible = false;
        tab = i;
        setSetting("tab", i);
        if (i === 3) recentPage.reload();
        if (i === 4) yedekPage.reload();
        if (i === 2) drivePage.ilkAcilis();
        focusCurrent();
    }
    function stepTab(d) { selectTab((tab + d + 6) % 6); }
    function currentPage() { return tab === 0 ? notesPage : tab === 1 ? filesPage : tab === 2 ? drivePage : tab === 3 ? recentPage : tab === 4 ? yedekPage : settingsPage; }
    function focusCurrent() {
        if (sheet.shown || input.shown) return;
        if (isPanel.shown) { isPanel.goster(); return; }
        if (help.shown) { help.takeFocus(); return; }
        if (galeri.shown) { galeri.takeFocus(); return; }
        if (notAyar.visible && !editorOpen) { notAyar.takeFocus(); return; }
        if (zipPage.shown && !editorOpen) { zipPage.takeFocus(); return; }
        if (editorOpen) { editor.takeFocus(); return; }
        currentPage().takeFocus();
    }
    function refreshAll() {
        notesPage.reload();
        filesPage.reload();
        favPanel.reload();
        if (tab === 3) recentPage.reload();
    }

    // ---- Dosya acma ----
    // mode: "edit" | "view"
    function openFile(path, mode) {
        if (!fs.exists(path)) { showToast(qsTr("Dosya bulunamadı")); forgetRecent(path); recentPage.reload(); return; }
        if (fs.isDir(path)) { showFolder(path); return; }
        if (!editor.open(path, mode === "view", "")) return;
        editorOpen = true;
        editor.takeFocus();
    }
    function newDocument(dir, templateKey) {
        var t = null;
        for (var i = 0; i < C.templates.length; i++) if (C.templates[i].key === templateKey) t = C.templates[i];
        if (!t) t = C.templates[0];
        var base = templateKey === "blank" || templateKey === "todo" || templateKey === "diary"
                 ? qsTr("Not ") + fs.now("yyyy-MM-dd HH.mm") : "yeni";
        input.open({ title: qsTr("Yeni dosya: ") + t.label, label1: qsTr("Dosya adı (") + dir + ")", text1: base + "." + t.ext, ok: qsTr("Oluştur"), selectBase: true },
                   function (name) {
            name = name.replace(/[\\\/:*?"<>|\x00-\x1f]/g, " ").replace(/\s+/g, " ").replace(/^\s+|\s+$/g, "");
            if (name.indexOf(".") < 0) name += "." + t.ext;
            if (name.charAt(0) === "."  /* ad kismi bos kaldi (".txt") */ || !fs.validName(name)) name = base + "." + t.ext;
            var p = fs.join(dir, name);
            if (fs.exists(p)) {
                // ayni adda dosya varsa yenisini olusturmak yerine onu ac
                if (!fs.isDir(p)) { showToast(qsTr("Bu adda dosya zaten vardı, o açıldı")); openFile(p, "edit"); return; }
                p = fs.uniquePath(dir, name);
            }
            var body = C.template(templateKey, fs.now("dd.MM.yyyy"), fs.now("HH:mm"));
            var eol = /^(vcf|vcs)$/.test(t.ext) ? "crlf" : newEol;
            var w = fs.writeText(p, body, "UTF-8", eol, false, false);
            if (!w.ok) { showToast(qsTr("Oluşturulamadı: ") + w.error); return; }
            fs.log("yeni " + p);
            refreshAll();
            openFile(p, "edit");
            if (templateKey === "diary" || templateKey === "blank") editor.cursorToEnd();
        });
    }
    function newFileMenu(dir) {
        var items = [];
        for (var i = 0; i < C.templates.length; i++)
            items.push({ label: C.templates[i].label, icon: C.templates[i].icon, key: C.templates[i].key, hint: "." + C.templates[i].ext });
        items.push({ label: qsTr("Panodaki yazıdan"), icon: "paste", key: "clip" });
        sheet.open(qsTr("Yeni dosya • ") + dir, items, function (k) {
            if (k === "clip") newFromClipboard(dir);
            else newDocument(dir, k);
        });
    }
    function newFromClipboard(dir) {
        var t = fs.clipboardText();
        if (!t) { showToast(qsTr("Pano boş")); return; }
        var first = t.replace(/^\s+/, "").split("\n")[0].replace(/[\\\/:*?"<>|]/g, " ").substring(0, 30).replace(/\s+$/, "");
        var p = fs.uniquePath(dir, (first || qsTr("Pano")) + ".txt");
        var w = fs.writeText(p, t.replace(/\r\n?/g, "\n"), "UTF-8", newEol, false, false);
        if (!w.ok) { showToast(qsTr("Kaydedilemedi: ") + w.error); return; }
        showToast(qsTr("Panodan oluşturuldu: ") + fs.fileName(p));
        refreshAll();
        openFile(p, "edit");
    }
    function newFolder(dir) {
        input.open({ title: qsTr("Yeni klasör"), label1: dir, text1: qsTr("Yeni klasör"), ok: qsTr("Oluştur") }, function (name) {
            if (!fs.validName(name)) { showToast(qsTr("Geçersiz ad")); return; }
            if (fs.makeDir(fs.join(dir, name))) { showToast(qsTr("Klasör oluşturuldu")); refreshAll(); }
            else showToast(fs.lastError());
        });
    }

    // ---- Dosya islemleri ----
    function renameItem(path) {
        input.open({ title: qsTr("Yeniden adlandır"), label1: fs.folderOf(path), text1: fs.fileName(path), ok: qsTr("Değiştir"), selectBase: !fs.isDir(path) },
                   function (name) {
            var np = fs.renamePath(path, name);
            if (np === "") { showToast(fs.lastError()); return; }
            pathMoved(path, np);
            showToast(qsTr("Adı değişti"));
            refreshAll();
        });
    }
    function duplicateItem(path) {
        var np = fs.copyPath(path, fs.folderOf(path));
        if (np === "") showToast(fs.lastError()); else { showToast(qsTr("Kopya: ") + fs.fileName(np)); refreshAll(); }
    }
    function copyItems(paths, cut) {
        if (!paths.length) return;
        clipPaths = paths;
        clipMode = cut ? "cut" : "copy";
        showToast((paths.length === 1 ? fs.fileName(paths[0]) : paths.length + qsTr(" öğe")) + (cut ? qsTr(" kesildi") : qsTr(" kopyalandı")) + qsTr(" • hedef klasörde V"));
        refreshAll();
    }
    function pasteInto(dir) {
        if (!clipPaths.length) { showToast(qsTr("Dosya panosu boş (önce C ya da X)")); return; }
        if (dir === "") { showToast(qsTr("Önce bir klasöre girin")); return; }
        var mode = clipMode, kaynak = clipPaths;
        isBaslat(mode === "cut" ? "tasi" : "kopyala", kaynak, dir, [],
                 (mode === "cut" ? qsTr("Taşınıyor → ") : qsTr("Kopyalanıyor → ")) + fs.fileName(dir), function (ok, sonuc) {
            if (mode === "cut") {
                for (var i = 0; i < kaynak.length; i++) if (!fs.exists(kaynak[i])) pathMoved(kaynak[i], fs.join(dir, fs.fileName(kaynak[i])));
                app.clipPaths = []; app.clipMode = "";
            }
        });
    }
    // ---- Arka plan isleri (donmayi onler) ----
    function isBaslat(tur, kaynaklar, hedef, secili, baslik, sonra) {
        if (isci.calisiyor) { showToast(qsTr("Başka bir dosya işi sürüyor")); isPanel.goster(); return false; }
        ID.sonra = sonra || null;
        isPanel.ac(baslik);
        if (!isci.baslat(tur, kaynaklar, hedef, secili)) { isPanel.kapat(); showToast(qsTr("İş başlatılamadı")); ID.sonra = null; return false; }
        return true;
    }
    function boyutYazi(b) { return U.sizeText(b); }
    Connections {
        target: isci
        onIlerleme: {
            var d = toplamAdet > 0 ? adet + " / " + toplamAdet + qsTr(" dosya") : "";
            if (toplam > 0) d += (d ? "  •  " : "") + U.sizeText(bitti) + " / " + U.sizeText(toplam);
            isPanel.guncelle(ad, toplam > 0 ? bitti / toplam : -1, d);
        }
        onBitti: {
            isPanel.kapat();
            fs.log("is: " + mesaj);
            app.showToast(mesaj);
            var f = ID.sonra;
            ID.sonra = null;
            app.refreshAll();
            if (f) f(ok, sonuc);
        }
    }
    function isIptalSor() {
        if (drive.isAktif && !isci.calisiyor) { drive.isIptal(); return; }
        sheet.open(qsTr("İş durdurulsun mu?"), [
            { label: qsTr("Evet, durdur"), icon: "close", key: "y", danger: true },
            { label: qsTr("Hayır, sürsün"), icon: "check", key: "n" }
        ], function (k) { if (k === "y") { isci.iptal(); drive.isIptal(); } else isPanel.goster(); });
    }
    // Zip
    function zipYap(paths, varsayilanAd) {
        if (!paths.length) return;
        var ad = (varsayilanAd || (paths.length === 1 ? fs.fileName(paths[0]).replace(/\.[^.\/]*$/, "") : fs.fileName(fs.folderOf(paths[0])) || "arsiv")).replace(/[\\\/:*?"<>|]/g, "_");
        input.open({ title: qsTr("Zip'e sıkıştır"), label1: qsTr("Arşiv adı (") + fs.folderOf(paths[0]) + ")", text1: ad + ".zip", ok: qsTr("Sıkıştır"), selectBase: true }, function (n) {
            n = n.replace(/^\s+|\s+$/g, "");
            if (!fs.validName(n)) { showToast(qsTr("Geçersiz ad")); return; }
            if (!/\.zip$/i.test(n)) n += ".zip";
            var hedef = isci.benzersiz(fs.folderOf(paths[0]), n);
            isBaslat("zip", paths, hedef, [], qsTr("Sıkıştırılıyor: ") + fs.fileName(hedef), function (ok, sonuc) { if (ok) showFolder(fs.folderOf(sonuc), sonuc); });
        });
    }
    function zipGoster(path) { zipPage.ac(path); }
    function zipTumunuAc(path) {
        var hedef = isci.benzersiz(fs.folderOf(path), fs.baseName(path));
        zipAc(path, hedef, [], qsTr("Çıkarılıyor: ") + fs.fileName(path), function (ok, sonuc) { if (ok) showFolder(hedef, ""); });
    }
    // Zip cikarma: sifreli ogeler varsa parola sorar (ZipCrypto / AES); yanlissa yeniden sorar
    function zipAc(arsiv, hedef, secili, baslik, sonra) {
        if (!isci.zipSifreli(arsiv, secili)) { isci.parolaAyarla(""); return isBaslat("zipac", [arsiv], hedef, secili, baslik, sonra); }
        var bilinen = ID.zipParola[arsiv];
        if (bilinen) { zipAcParola(arsiv, hedef, secili, baslik, sonra, bilinen); return true; }
        zipParolaSor(arsiv, hedef, secili, baslik, sonra, "");
        return true;
    }
    function zipParolaSor(arsiv, hedef, secili, baslik, sonra, uyari) {
        input.open({ title: qsTr("Şifreli zip: ") + fs.fileName(arsiv), label1: uyari !== "" ? uyari : qsTr("Arşivin parolasını yazın"), text1: "", ok: qsTr("Aç"), password: true }, function (p) {
            if (p === "") return;
            zipAcParola(arsiv, hedef, secili, baslik, sonra, p);
        });
    }
    function zipAcParola(arsiv, hedef, secili, baslik, sonra, p) {
        isci.parolaAyarla(p);
        isBaslat("zipac", [arsiv], hedef, secili, baslik, function (ok, sonuc) {
            isci.parolaAyarla("");
            if (ok) { ID.zipParola[arsiv] = p; if (sonra) sonra(ok, sonuc); return; }
            if (isci.parolaSorunu()) {
                delete ID.zipParola[arsiv];
                zipParolaSor(arsiv, hedef, secili, baslik, sonra, qsTr("Parola yanlış, yeniden deneyin"));
                return;
            }
            if (sonra) sonra(ok, sonuc);
        });
    }
    // Dahili ses calar (QtMultimediaKit; yuklenemezse harici oynatici)
    function sesCal(path) {
        if (oynatici.source == "") oynatici.source = "Oynatici.qml";
        if (oynatici.status !== Loader.Ready || !oynatici.item) { showToast(qsTr("Dahili çalar açılamadı, harici oynatıcıya gönderiliyor")); openExternal(path); return; }
        var dir = fs.folderOf(path), l = fs.listDir(dir, true, "", "name"), sesler = [];
        for (var i = 0; i < l.length; i++) if (!l[i].dir && /^(mp3|aac|m4a|wav|amr|ogg|wma|flac|mid|midi|awb|3ga)$/.test(l[i].ext)) sesler.push(l[i].path);
        if (sesler.indexOf(path) < 0) sesler = [path];
        oynatici.item.cal(path, sesler);
    }
    function sesKapat() { if (oynatici.item) oynatici.item.durdur(); oynatici.source = ""; focusCurrent(); }
    function deleteItems(paths) {
        if (!paths.length) return;
        var name = paths.length === 1 ? fs.fileName(paths[0]) : paths.length + qsTr(" öğe");
        var hasDir = false;
        for (var i = 0; i < paths.length; i++) if (fs.isDir(paths[i])) hasDir = true;
        sheet.open(qsTr("Silinsin mi? ") + name + (hasDir ? qsTr(" (klasör içeriğiyle)") : ""), [
            { label: qsTr("Evet, kalıcı olarak sil"), icon: "trash", key: "yes", danger: true },
            { label: qsTr("Vazgeç"), icon: "close", key: "no" }
        ], function (k) {
            if (k !== "yes") return;
            isBaslat("sil", paths, "", [], qsTr("Siliniyor: ") + name, function (ok, sonuc) {
                for (var i = 0; i < paths.length; i++) {
                    if (fs.exists(paths[i])) continue;
                    var pp = paths[i];
                    forgetRecent(pp);
                    if (isFav(pp)) db().transaction(function (tx) { tx.executeSql("DELETE FROM fav WHERE path = ?", [pp]); });
                }
            });
        });
    }
    function copyTextOf(path) {
        var r = fs.readText(path, defaultEncoding);
        if (!r.ok) { showToast(qsTr("Okunamadı: ") + r.error); return; }
        fs.setClipboardText(r.text);
        showToast(qsTr("Yazı panoya kopyalandı (") + r.text.length + qsTr(" karakter)"));
    }
    function copyPathText(path) {
        fs.setClipboardText(path);
        showToast(qsTr("Yol panoya kopyalandı"));
    }
    function openExternal(path) {
        if (!fs.openExternally(path)) showToast(qsTr("Bu dosyayı açacak uygulama bulunamadı"));
    }
    // ---- Varsayilan programlar ----
    function dosyaTuru(path) {
        var e = fs.suffix(path);
        if (/^(jpg|jpeg|png|gif|bmp)$/.test(e)) return "resim";
        if (/^(mp4|3gp|3g2|avi|mkv|mov|wmv|flv|m4v|webm)$/.test(e)) return "video";
        if (/^(mp3|aac|m4a|wav|amr|ogg|wma|flac|awb|3ga|mid|midi)$/.test(e)) return "ses";
        if (fs.isText(path)) return "metin";
        return "";
    }
    function turAdi(t) { return t === "metin" ? qsTr("Metin dosyaları") : t === "resim" ? qsTr("Fotoğraflar") : t === "video" ? qsTr("Videolar") : qsTr("Müzik ve ses"); }
    function dahiliAdi(t) { return t === "metin" ? qsTr("Belle Files düzenleyici") : t === "resim" ? qsTr("Belle galeri") : t === "ses" ? qsTr("Belle çalar") : ""; }
    function sistemAdi(t) { return t === "metin" ? qsTr("Telefonun not uygulaması") : t === "resim" ? qsTr("Telefonun galerisi") : t === "video" ? qsTr("Telefonun video oynatıcısı") : qsTr("Telefonun müzik çalarları"); }
    function varsayilan(t) { return t === "metin" ? acMetin : t === "resim" ? acResim : t === "video" ? acVideo : acSes; }
    function varsayilanAyarla(t, v) {
        if (t === "metin") acMetin = v; else if (t === "resim") acResim = v; else if (t === "video") acVideo = v; else acSes = v;
        setSetting("ac" + t.charAt(0).toUpperCase() + t.substring(1), v);
    }
    function secenekAdi(t, v) { return v === "dahili" ? dahiliAdi(t) : v === "sistem" ? sistemAdi(t) : qsTr("Her seferinde sor"); }
    // Bir turun secenekleri (videoda dahili oynatici yok)
    function secenekler(t) { var l = []; if (dahiliAdi(t) !== "") l.push("dahili"); l.push("sistem"); l.push("sor"); return l; }
    function birlikteAc(path, t, v) {
        if (v === "sistem") { openExternal(path); return; }
        if (t === "metin") openFile(path, "edit");
        else if (t === "resim") galeri.ac(path);
        else if (t === "ses") sesCal(path);
        else openExternal(path);
    }
    // Dosyayi turune gore ac: SIS/JAR kurulum ekrani, zip icerigi, metin/resim/video/ses varsayilan
    // programla (Ayarlar > Varsayılan programlar), diger kucuk dosyalar metin olarak goruntulenir
    function akilliAc(path) {
        if (fs.isDir(path)) { showFolder(path, ""); return; }
        var e = fs.suffix(path);
        if (/^(sis|sisx|jar|jad)$/.test(e)) { showToast(qsTr("Kurulum açılıyor…")); openExternal(path); return; }
        if (e === "zip") { zipGoster(path); return; }
        var t = dosyaTuru(path);
        if (t !== "") {
            var v = varsayilan(t);
            if (v !== "sor") { birlikteAc(path, t, v); return; }
            var ls = secenekler(t), items = [];
            for (var i = 0; i < ls.length - 1; i++) items.push({ label: secenekAdi(t, ls[i]), icon: ls[i] === "dahili" ? "eye" : "globe", key: ls[i] });
            items.push({ label: qsTr("Varsayılanı değiştir…"), icon: "gear", key: "ayar" });
            sheet.open(qsTr("Birlikte aç • ") + fs.fileName(path), items, function (k) {
                if (k === "ayar") { varsayilanSec(t); return; }
                birlikteAc(path, t, k);
            });
            return;
        }
        if (/^(svg|pdf|doc|docx|xls|xlsx|ppt|pptx|rar|swf)$/.test(e)) { openExternal(path); return; }
        var inf = fs.info(path);
        if (inf.size < 512 * 1024) openFile(path, "view"); else openExternal(path);
    }
    function varsayilanSec(t, sonra) {
        var ls = secenekler(t), items = [], cur = varsayilan(t);
        for (var i = 0; i < ls.length; i++) items.push({ label: (ls[i] === cur ? "● " : "") + secenekAdi(t, ls[i]), icon: ls[i] === "dahili" ? "eye" : (ls[i] === "sistem" ? "globe" : "info"), key: ls[i] });
        sheet.open(turAdi(t) + qsTr(" • varsayılan program"), items, function (k) {
            varsayilanAyarla(t, k);
            showToast(turAdi(t) + ": " + secenekAdi(t, k));
            if (sonra) sonra();
        });
    }
    // ---- Drive ----
    function driveHazirMi() {
        if (drive.hazir) return true;
        showToast(qsTr("Önce Drive sekmesinden bağlantıyı kurun (Sunucu ya da Google hesabı)"));
        selectTab(2);
        drivePage.ayarlar();
        return false;
    }
    property string driveIs: ""               // file manager/editor'dan baslatilan yukleme
    property variant driveKuyruk: []          // coklu yukleme sirasi
    property int driveTamam: 0
    // Birden cok dosya/klasor: Drive'im kokune (klasorler alt klasorleriyle)
    function driveYukleCok(ps) { driveIsBaslat(ps, "", false, false, qsTr("Drive'a yükleniyor")); }
    // Klasor(ler)i "Belle Files Yedek" altina yedekle
    function driveKlasorYedekle(ps) { driveIsBaslat(ps, driveYedekKlasoru, false, false, qsTr("Drive'a yedekleniyor")); }
    property string driveYedekKlasoru: qsTr("Belle Files Yedek")
    property string driveNotKlasoru: qsTr("Belle Files Notlar")
    property bool otoEsitle: true            // not kaydedilince Drive'a esitle
    property variant otoKlasorler: []        // otomatik esitlenen ek klasorler (kart dahil her yer)
    property bool driveIsSessiz: false
    // icerik=true: dir'in ici dogrudan hedefe (notlar); false: her oge kendi adiyla hedefin altina
    function driveIsBaslat(yollar, hedef, degisen, icerik, baslik, sessiz) {
        if (!driveHazirMi()) return false;
        if (drive.isAktif || drive.busy) { if (!sessiz) { showToast(qsTr("Drive'da başka bir aktarım sürüyor")); isPanel.goster(); } return false; }
        driveIsSessiz = !!sessiz;
        var ok = icerik ? drive.klasorYedekle(yollar[0], hedef, degisen) : drive.cokluYedekle(yollar, hedef, degisen);
        if (!ok) { if (!sessiz) showToast(qsTr("Drive işi başlatılamadı")); return false; }
        drivePage.harici = true;
        if (!sessiz) isPanel.ac(baslik + (hedef ? " → " + hedef : ""));
        return true;
    }
    // Notlar ekranindaki senkron dugmesi: tum notlar + otomatik klasorler, yalnizca degisenler
    function notlariEsitle(sessiz) {
        var ek = otoKlasorler, q = [];
        for (var i = 0; i < ek.length; i++) if (fs.isDir(ek[i])) q.push({ yollar: [ek[i]], hedef: driveYedekKlasoru, degisen: true, icerik: false });
        ID.driveKuyruk = q;
        driveIsBaslat([fs.notesDir()], driveNotKlasoru, true, true, qsTr("Notlar eşitleniyor"), sessiz);
    }
    function otoKlasorVar(dir) { var l = otoKlasorler; for (var i = 0; i < l.length; i++) if (l[i].toLowerCase() === dir.toLowerCase()) return true; return false; }
    function otoKlasorDegistir(dir) {
        var l = otoKlasorler, y = [], vardi = false;
        for (var i = 0; i < l.length; i++) { if (l[i].toLowerCase() === dir.toLowerCase()) vardi = true; else y.push(l[i]); }
        if (!vardi) y.push(dir);
        otoKlasorler = y;
        setSetting("otoKlasorler", y.join("|"));
        showToast(vardi ? qsTr("Otomatik eşitlemeden çıkarıldı: ") + fs.fileName(dir) : qsTr("Otomatik Drive eşitlemesine eklendi: ") + fs.fileName(dir) + qsTr(" (Notlar > bulut-senkron)"));
    }
    Connections {
        target: drive
        onIsIlerleme: if (!app.driveIsSessiz) isPanel.guncelle(ad, toplam > 0 ? bitti / toplam : -1, toplam > 0 ? (bitti + 1) + " / " + toplam + qsTr(" dosya") : "");
        onProgress: if (drive.isAktif && !app.driveIsSessiz && total > 0) isPanel.detay = isPanel.detay.replace(/  •  .*$/, "") + "  •  %" + Math.round(done * 100 / total);
        onIsBitti: {
            fs.log("drive is: " + mesaj);
            var q = ID.driveKuyruk;
            if (q.length && ok) {
                var n = q[0];
                ID.driveKuyruk = q.slice(1);
                if (app.driveIsBaslat(n.yollar, n.hedef, n.degisen, n.icerik, qsTr("Klasör eşitleniyor"), app.driveIsSessiz)) return;
            }
            ID.driveKuyruk = [];
            drivePage.harici = false;
            isPanel.kapat();
            if (!app.driveIsSessiz || !ok || yuklenen > 0) app.showToast((ok ? qsTr("Drive: ") : qsTr("Drive hatası: ")) + mesaj);
            app.driveIsSessiz = false;
            var ds = ID.driveSonra;      // ardindan yapilacak is (or. inen zip'i acmak)
            ID.driveSonra = null;
            if (ds) ds(ok, mesaj);
        }
    }
    function driveYukle(path) {
        if (!driveHazirMi()) return;
        if (fs.isDir(path)) { showToast(qsTr("Klasör yüklenmez; içindeki dosyaları işaretleyip tek tek yükleyin")); return; }
        drivePage.harici = true;
        if (!drive.upload(path, "root")) { showToast(drive.busy ? qsTr("Başka bir aktarım sürüyor") : qsTr("Dosya okunamadı")); return; }
        driveIs = qsTr("Drive'a yüklendi: ") + fs.fileName(path);
        showToast(qsTr("Drive'a yükleniyor: ") + fs.fileName(path));
    }
    function notHedefi(path) {
        var nd = fs.notesDir(), dir = fs.folderOf(path);
        if (dir.toLowerCase().indexOf(nd.toLowerCase()) !== 0) return driveYedekKlasoru;
        var rel = dir.substring(nd.length).replace(/^\/+/, "");
        return driveNotKlasoru + (rel ? "/" + rel : "");
    }
    function notYedekle(path) {
        if (!path) { showToast(qsTr("Önce dosyayı kaydedin")); return; }
        if (!driveHazirMi()) return;
        var h = notHedefi(path);
        if (driveIsBaslat([path], h, false, false, qsTr("Yedekleniyor"), true)) showToast(qsTr("Drive'a yedekleniyor → ") + h);
    }
    // Not kaydedilince (ayar acikken) sessizce esitle
    function notKaydedildi(path) {
        if (!otoEsitle || !drive.hazir || drive.isAktif || drive.busy) return;
        if (fs.folderOf(path).toLowerCase().indexOf(fs.notesDir().toLowerCase()) !== 0) return;
        driveIsBaslat([path], notHedefi(path), true, false, "", true);
    }    Connections {
        target: drive
        onUploadFinished: {
            if (app.driveIs === "") return;          // Drive sekmesinden baslatildiysa o gosterir
            fs.log((ok ? "drive yuklendi " : "drive hata ") + message);
            var bilgi = app.driveIs;
            if (ok) app.driveTamam++;
            app.driveIs = "";
            drivePage.harici = false;
            var q = app.driveKuyruk;
            if (q.length) {
                var n = q[0];
                app.driveKuyruk = q.slice(1);
                app.driveYukle(n);
                if (!ok) app.showToast(qsTr("Yüklenemedi: ") + message + qsTr(" — sıradaki: ") + fs.fileName(n));
                return;
            }
            if (app.driveTamam > 1) app.showToast(app.driveTamam + qsTr(" dosya Drive'a yüklendi"));
            else app.showToast(ok ? bilgi : qsTr("Yüklenemedi: ") + message);
            app.driveTamam = 0;
        }
    }
    function fileInfo(path) {
        var i = fs.info(path);
        var lines = [];
        lines.push({ label: i.name, icon: i.dir ? "folder" : U.iconFor(i.ext, false), key: "x" });
        lines.push({ label: qsTr("Klasör: ") + i.folder, icon: "folder", key: "x" });
        if (i.dir) lines.push({ label: i.count + qsTr(" öğe"), icon: "lines", key: "x" });
        else {
            lines.push({ label: qsTr("Boyut: ") + U.sizeText(i.size) + " (" + i.size + qsTr(" bayt)"), icon: "info", key: "x" });
            if (fs.isText(path) && i.size < 2 * 1024 * 1024) {
                var r = fs.readText(path, "");
                if (r.ok) {
                    var s = U.stats(r.text);
                    lines.push({ label: s.lines + qsTr(" satır, ") + s.words + qsTr(" kelime, ") + s.chars + qsTr(" karakter"), icon: "lines", key: "x" });
                    lines.push({ label: qsTr("Kodlama: ") + U.encodingLabel(r.encoding) + (r.bom ? qsTr(" + BOM") : "") + " • " + U.eolLabel(r.eol), icon: "font", key: "x" });
                }
            }
        }
        lines.push({ label: qsTr("Değişiklik: ") + U.dateText(i.time), icon: "clock", key: "x" });
        if (i.readOnly) lines.push({ label: qsTr("Salt okunur"), icon: "eye", key: "x" });
        lines.push({ label: qsTr("Yolu panoya kopyala"), icon: "copy", key: "path" });
        sheet.open(qsTr("Bilgi"), lines, function (k) { if (k === "path") copyPathText(path); });
    }
    function showFolder(dir, selectPath) {
        if (dir.toLowerCase().indexOf(fs.notesDir().toLowerCase()) === 0) {
            selectTab(0);
            notesPage.openPath(dir, selectPath || "");
        } else {
            selectTab(1);
            filesPage.openPath(dir, selectPath || "");
        }
    }

    // ---- Uzanti degistirme / donusturme ----
    function extensionMenu(path) {
        var cur = fs.suffix(path);
        var items = [];
        for (var i = 0; i < C.targets.length; i++) {
            var t = C.targets[i];
            if (t.ext === cur) continue;
            items.push({ label: t.label + (t.ext ? " (." + t.ext + ")" : ""), icon: U.iconFor(t.ext, false), key: "t" + i, hint: t.info });
        }
        items.push({ label: qsTr("Başka uzantı yaz…"), icon: "edit", key: "custom" });
        sheet.open(qsTr("Uzantı / dönüştür • ") + fs.fileName(path), items, function (k) {
            if (k === "custom") {
                input.open({ title: qsTr("Yeni uzantı"), label1: qsTr("Örnek: html, vcf, m3u (boş: uzantısız)"), text1: cur, ok: qsTr("Değiştir") }, function (e) {
                    e = e.replace(/^[\s.]+|\s+$/g, "").toLowerCase();
                    extensionAction(path, C.targetFor(e));
                });
                return;
            }
            extensionAction(path, C.targets[parseInt(k.substring(1), 10)]);
        });
    }
    function extensionAction(path, t) {
        var items = [];
        if (t.conv !== "") {
            items.push({ label: qsTr("İçeriği dönüştür, yeni dosya olarak kaydet"), icon: "swap", key: "convNew" });
            items.push({ label: qsTr("İçeriği dönüştür, bu dosyanın yerine"), icon: "swap", key: "convReplace" });
        }
        items.push({ label: qsTr("Yalnızca uzantıyı değiştir"), icon: "edit", key: "rename" });
        items.push({ label: qsTr("Uzantısı değişmiş kopya oluştur"), icon: "copy", key: "copy" });
        sheet.open(fs.fileName(path) + " → ." + (t.ext || "(yok)"), items, function (k) {
            var np = "";
            if (k === "rename" || k === "copy") {
                np = fs.changeExtension(path, t.ext, k === "copy");
                if (np === "") { showToast(fs.lastError()); return; }
                if (k === "rename") pathMoved(path, np);
                fs.log("uzanti " + path + " -> " + np);
            } else {
                var r = fs.readText(path, defaultEncoding);
                if (!r.ok) { showToast(qsTr("Okunamadı: ") + r.error); return; }
                var res = C.convert(t.conv, r.text, fs.baseName(path), fs.suffix(path));
                var name = fs.baseName(path) + (t.ext ? "." + t.ext : "");
                np = k === "convNew" ? fs.uniquePath(fs.folderOf(path), name) : fs.join(fs.folderOf(path), name);
                if (k === "convReplace" && np !== path && fs.exists(np)) np = fs.uniquePath(fs.folderOf(path), name);
                var eol = /^(vcf|vcs)$/.test(t.ext) ? "crlf" : (r.eol || newEol);
                var w = fs.writeText(np, res.text, "UTF-8", eol, false, false);
                if (!w.ok) { showToast(qsTr("Kaydedilemedi: ") + w.error); return; }
                if (k === "convReplace" && np !== path) { fs.removePath(path); pathMoved(path, np); }
                fs.log("donustur " + t.conv + " " + path + " -> " + np);
                if (res.note) showToast(res.note);
            }
            refreshAll();
            afterConvert(np, t);
        });
    }
    function afterConvert(np, t) {
        var items = [{ label: qsTr("Düzenleyicide aç"), icon: "edit", key: "edit" }];
        if (t.open) items.unshift({ label: qsTr("Sistemde aç (") + t.info.toLowerCase() + ")", icon: "globe", key: "ext" });
        else items.push({ label: qsTr("Sistemde aç"), icon: "globe", key: "ext" });
        items.push({ label: qsTr("Klasöründe göster"), icon: "folder", key: "show" });
        items.push({ label: qsTr("Kapat"), icon: "close", key: "no" });
        sheet.open(qsTr("Hazır: ") + fs.fileName(np), items, function (k) {
            if (k === "ext") openExternal(np);
            else if (k === "edit") openFile(np, "edit");
            else if (k === "show") showFolder(fs.folderOf(np), np);
        });
    }

    // ---- Disa aktarma ----
    function stamp() { return fs.now("yyyyMMdd_HHmm"); }
    function collectText(paths) {
        var out = [];
        for (var i = 0; i < paths.length; i++) {
            if (fs.isDir(paths[i])) out = out.concat(fs.textFilesIn(paths[i], false));
            else out.push(paths[i]);
        }
        return out;
    }
    function exportMenu(paths, label) {
        if (!paths.length) { showToast(qsTr("Dışa aktarılacak dosya yok")); return; }
        var files = collectText(paths);
        // her tur dosya: zip, Drive, kopya; yalnizca metin dosyalari icin: paket, HTML, pano
        var items = [
            { label: qsTr("Zip arşivi (sıkıştırılmış)"), icon: "zip", key: "zip" },
            { label: qsTr("Drive'a yükle → ") + driveYedekKlasoru, icon: "yukle", key: "drive" },
            { label: qsTr("Dışa aktarılanlar klasörüne kopyala"), icon: "copy", key: "copyall" }
        ];
        if (files.length) items = items.concat([
            { label: qsTr("Paket dosyası (.txt, geri yüklenebilir) • ") + files.length + qsTr(" metin"), icon: "export", key: "bundle" },
            { label: qsTr("Tek HTML sayfası (içindekilerle)"), icon: "code", key: "html" },
            { label: qsTr("Her biri ayrı HTML"), icon: "globe", key: "htmlEach" },
            { label: qsTr("Tümünün yazısını panoya kopyala"), icon: "paste", key: "clip" }
        ]);
        sheet.open(qsTr("Dışa aktar • ") + (paths.length === 1 ? fs.fileName(paths[0]) : paths.length + qsTr(" öğe") + (label ? " (" + label + ")" : "")), items, function (k) {
            var dir = fs.exportDir(), out = "", n = 0, i;
            var name = (label || (paths.length === 1 ? fs.baseName(paths[0]) : "notlar")).replace(/[\\\/:*?"<>|]/g, "_");
            if (k === "zip") {
                isBaslat("zip", paths, isci.benzersiz(dir, name + "_" + stamp() + ".zip"), [], qsTr("Zip arşivi hazırlanıyor"), function (ok, s) { if (ok) showFolder(fs.folderOf(s), s); });
                return;
            }
            if (k === "drive") { driveKlasorYedekle(paths); return; }
            if (k === "copyall") {
                var hedefK = paths.length === 1 ? dir : isci.benzersiz(dir, name + "_" + stamp());
                isBaslat("kopyala", paths, hedefK, [], qsTr("Kopyalanıyor → Dışa aktarılanlar"), function (ok, s) { if (ok) showFolder(hedefK, ""); });
                return;
            }
            if (k === "bundle") {
                out = fs.exportBundle(files, fs.uniquePath(dir, name + "_paket_" + stamp() + ".txt"));
                if (out === "") { showToast(fs.lastError()); return; }
                n = files.length;
            } else if (k === "html") {
                var toc = [], body = [];
                for (i = 0; i < files.length; i++) {
                    var r = fs.readText(files[i], "");
                    if (!r.ok) continue;
                    var html = C.toHtml(r.text, fs.fileName(files[i])).text;
                    var b = /<body>\n?([\s\S]*)\n?<\/body>/.exec(html);
                    toc.push(qsTr("<li><a href=\"#d") + i + "\">" + C.esc(fs.fileName(files[i])) + "</a></li>");
                    body.push(qsTr("<hr><h1 id=\"d") + i + "\">" + C.esc(fs.fileName(files[i])) + "</h1>\n" +
                              (C.looksHtml(r.text) ? "<pre>" + C.esc(r.text) + "</pre>" : (b ? b[1] : html)));
                    n++;
                }
                var page = C.htmlPage(name, "<h1>" + C.esc(name) + "</h1>\n<p>" + fs.now("") + " • " + n + qsTr(" dosya</p>\n<ol>\n") + toc.join("\n") + "\n</ol>\n" + body.join("\n"));
                out = fs.uniquePath(dir, name + "_" + stamp() + ".html");
                var w = fs.writeText(out, page, "UTF-8", "lf", false, false);
                if (!w.ok) { showToast(w.error); return; }
            } else if (k === "htmlEach") {
                var sub = fs.uniquePath(dir, name + "_html_" + stamp());
                fs.makeDir(sub);
                for (i = 0; i < files.length; i++) {
                    var rr = fs.readText(files[i], "");
                    if (!rr.ok) continue;
                    var ww = fs.writeText(fs.uniquePath(sub, fs.baseName(files[i]) + ".html"), C.toHtml(rr.text, fs.fileName(files[i])).text, "UTF-8", "lf", false, false);
                    if (ww.ok) n++;
                }
                out = sub;
            } else if (k === "copy") {
                var target = files.length === 1 ? dir : fs.uniquePath(dir, name + "_" + stamp());
                if (files.length > 1) fs.makeDir(target);
                for (i = 0; i < files.length; i++) if (fs.copyPath(files[i], target) !== "") n++;
                out = target;
            } else if (k === "clip") {
                var all = [];
                for (i = 0; i < files.length; i++) {
                    var rc = fs.readText(files[i], "");
                    if (rc.ok) { all.push((files.length > 1 ? "=== " + fs.fileName(files[i]) + " ===\n" : "") + rc.text); n++; }
                }
                fs.setClipboardText(all.join("\n\n"));
                showToast(n + qsTr(" dosyanın yazısı panoda"));
                return;
            }
            fs.log("disa aktar " + k + " " + n + " -> " + out);
            refreshAll();
            sheet.open(n + qsTr(" dosya dışa aktarıldı"), [
                { label: qsTr("Göster: ") + fs.fileName(out), icon: "folder", key: "show" },
                { label: qsTr("Sistemde aç"), icon: "globe", key: "ext" },
                { label: qsTr("Yolu panoya kopyala"), icon: "copy", key: "path" },
                { label: qsTr("Tamam"), icon: "check", key: "ok" }
            ], function (kk) {
                if (kk === "show") { if (fs.isDir(out)) showFolder(out, ""); else showFolder(fs.folderOf(out), out); }
                else if (kk === "ext") openExternal(out);
                else if (kk === "path") copyPathText(out);
            });
        });
    }

    // ---- Ice aktarma ----
    function importFile(path, targetDir) {
        targetDir = targetDir || fs.notesDir();
        if (fs.isBundle(path)) {
            sheet.open(qsTr("Bu bir Belle Files paketi: ") + fs.fileName(path), [
                { label: qsTr("Paketi aç (dosyalara ayır)"), icon: "import", key: "split" },
                { label: qsTr("Tek dosya olarak içe aktar"), icon: "doc", key: "single" }
            ], function (k) {
                if (k === "split") importBundle(path, targetDir);
                else importSingle(path, targetDir);
            });
            return;
        }
        importSingle(path, targetDir);
    }
    function importSingle(path, targetDir) {
        var ext = fs.suffix(path);
        var r = fs.readText(path, defaultEncoding);
        if (!r.ok) { showToast(qsTr("Okunamadı: ") + r.error); return; }
        var text = r.text, note = "";
        if (/^(html?|xhtml|vcf|json|csv|tsv)$/.test(ext)) {
            var c = C.toText(text, ext);
            text = c.text; note = c.note;
        }
        var p = fs.uniquePath(targetDir, fs.baseName(path) + ".txt");
        var w = fs.writeText(p, text, "UTF-8", newEol, false, false);
        if (!w.ok) { showToast(qsTr("Kaydedilemedi: ") + w.error); return; }
        fs.log("ice aktar " + path + " -> " + p);
        showToast(qsTr("İçe aktarıldı: ") + fs.fileName(p) + (note ? " • " + note : "") + (r.encoding !== "UTF-8" ? " • " + r.encoding + qsTr(" → UTF-8") : ""));
        refreshAll();
    }
    function importBundle(path, targetDir) {
        var dir = fs.uniquePath(targetDir, fs.baseName(path).replace(/_paket.*$/, "") + qsTr(" (içe aktarılan)"));
        var made = fs.importBundle(path, dir);
        if (!made.length) { showToast(fs.lastError()); return; }
        fs.log("paket ice aktar " + made.length + " -> " + dir);
        showToast(made.length + qsTr(" dosya içe aktarıldı"));
        refreshAll();
        showFolder(dir, "");
    }
    function importMenu(targetDir) {
        targetDir = targetDir || fs.notesDir();
        sheet.open(qsTr("İçe aktar → ") + targetDir, [
            { label: qsTr("Panodaki yazıdan yeni not"), icon: "paste", key: "clip" },
            { label: qsTr("Dosyalar sekmesinden seç (dosya menüsü > İçe aktar)"), icon: "folder", key: "browse" },
            { label: qsTr("Dışa aktarılanlar klasörünü aç (paketler)"), icon: "export", key: "exp" },
            { label: qsTr("Yedekler klasörünü aç"), icon: "save", key: "bak" }
        ], function (k) {
            if (k === "clip") newFromClipboard(targetDir);
            else if (k === "browse") { selectTab(1); showToast(qsTr("Bir dosya seçip menüden 'Notlarıma içe aktar'ı seçin")); }
            else if (k === "exp") showFolder(fs.exportDir(), "");
            else if (k === "bak") showFolder(fs.backupDir(), "");
        });
    }
    // "Klasörü yedekle" artik Drive'a (alt klasorleriyle, ilerlemeli); yerel kopya icin Kopyala/Taşı
    function backupFolder(dir) { driveKlasorYedekle([dir]); }

    // ---- Dosyalarda arama ----
    function searchIn(dir) {
        input.open({ title: qsTr("Ara • ") + dir, label1: qsTr("Aranacak yazı (ad ve içerik, alt klasörlerle)"), text1: "", ok: qsTr("Ara") }, function (q) {
            if (!q) return;
            showToast(qsTr("Aranıyor…"));
            searchTimer.dir = dir;
            searchTimer.q = q;
            searchTimer.restart();
        });
    }
    Timer {
        id: searchTimer
        property string dir: ""
        property string q: ""
        interval: 60
        onTriggered: {
            var res = fs.searchFiles(dir, q, true);
            if (!res.length) { app.showToast(qsTr("Bulunamadı: ") + q); return; }
            var items = [];
            for (var i = 0; i < res.length && i < 60; i++)
                items.push({ label: res[i].name + (res[i].lineNo ? "  " + res[i].lineNo + ": " + res[i].line : ""), icon: res[i].lineNo ? "doc" : "search", key: "" + i });
            sheet.open(res.length + qsTr(" sonuç • \"") + q + "\"", items, function (k) {
                var it = res[parseInt(k, 10)];
                app.openFile(it.path, "edit");
                if (it.lineNo) editor.findText(q, 0);
            });
        }
    }

    // ---- Taslak (kaydedilmemis degisiklik korumasi) ----
    function checkDraft() {
        if (!fs.exists(fs.draftPath())) return;
        var r = fs.readText(fs.draftPath(), "UTF-8");
        if (!r.ok || r.text.length === 0) { fs.removePath(fs.draftPath()); return; }
        var nl = r.text.indexOf("\n");
        var path = r.text.substring(0, nl), body = r.text.substring(nl + 1);
        sheet.open(qsTr("Kaydedilmemiş taslak bulundu") + (path ? ": " + fs.fileName(path) : ""), [
            { label: qsTr("Taslağı aç"), icon: "edit", key: "open" },
            { label: qsTr("Notlara ayrı dosya olarak kaydet"), icon: "save", key: "save" },
            { label: qsTr("Taslağı sil"), icon: "trash", key: "del", danger: true }
        ], function (k) {
            if (k === "open") {
                if (path && fs.exists(path)) openFile(path, "edit");
                else { editor.openText("", body); editorOpen = true; editor.takeFocus(); }
                editor.setText(body);
            } else if (k === "save") {
                var p = fs.uniquePath(fs.notesDir(), qsTr("Taslak ") + fs.now("yyyy-MM-dd HH.mm") + ".txt");
                fs.writeText(p, body, "UTF-8", newEol, false, false);
                fs.removePath(fs.draftPath());
                showToast(qsTr("Kaydedildi: ") + fs.fileName(p));
                refreshAll();
            } else if (k === "del") fs.removePath(fs.draftPath());
        });
    }

    function quit() {
        if (editorOpen && editor.dirty) { editor.askClose(function () { Qt.quit(); }); return; }
        Qt.quit();
    }

    Component.onCompleted: {
        initDb();
        fontSize = parseInt(setting("fontSize", "19"), 10);
        wrap = setting("wrap", "1") === "1";
        defaultEncoding = setting("encoding", "");
        newEol = setting("eol", "crlf");
        makeBackup = setting("backup", "0") === "1";
        autoSave = setting("autoSave", "0") === "1";
        draftGuard = setting("draft", "1") === "1";
        showAll = setting("showAll", "1") === "1";      // dosya yoneticisi: varsayilan tum dosyalar
        lineNumbers = setting("lineNumbers", "0") === "1";
        bigFileKB = parseInt(setting("bigFileKB", "384"), 10);
        notesSort = setting("notesSort", "date");
        filesSort = setting("filesSort", "name");
        acMetin = setting("acMetin", "dahili");
        acResim = setting("acResim", "dahili");
        acVideo = setting("acVideo", "sistem");
        acSes = setting("acSes", "dahili");
        var nd = setting("notesDir", "");
        if (nd !== "") fs.setNotesDir(nd);
        driveYedekKlasoru = setting("driveYedek", qsTr("Belle Files Yedek"));
        driveNotKlasoru = setting("driveNot", qsTr("Belle Files Notlar"));
        otoEsitle = setting("otoEsitle", "1") === "1";
        var ok2 = setting("otoKlasorler", "");
        otoKlasorler = ok2 === "" ? [] : ok2.split("|");
        fs.log("acildi v" + version);
        notesPage.openPath(fs.notesDir(), "");
        filesPage.openPath("", "");
        favPanel.reload();
        selectTab(parseInt(setting("tab", "0"), 10));
        draftTimer.start();
    }
    Timer { id: draftTimer; interval: 600; onTriggered: app.checkDraft() }

    // ---- Sayfalar ----
    Item {
        id: pages
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: oynatici.top }
        BrowserPage { id: notesPage; anchors.fill: parent; visible: app.tab === 0; notesMode: true }
        // Dosyalar sekmesi: sol yari dosyalar, sag yari favoriler
        BrowserPage { id: filesPage; anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: Math.round(parent.width / 2); visible: app.tab === 1; notesMode: false }
        FavoriPanel { id: favPanel; anchors { left: filesPage.right; right: parent.right; top: parent.top; bottom: parent.bottom } visible: app.tab === 1 }
        DrivePage { id: drivePage; anchors.fill: parent; visible: app.tab === 2; onSekme: app.stepTab(d); onYerelAc: app.akilliAc(yol) }
        RecentPage { id: recentPage; anchors.fill: parent; visible: app.tab === 3 }
        YedekPage { id: yedekPage; anchors.fill: parent; visible: app.tab === 4 }
        SettingsPage { id: settingsPage; anchors.fill: parent; visible: app.tab === 5 }
    }
    Loader {
        id: oynatici
        anchors { left: parent.left; right: parent.right; bottom: nav.top }
        height: item ? item.height : 0
        z: 12
    }
    BottomNav {
        id: nav
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        current: app.tab
        onSelected: app.selectTab(index)
    }

    EditorPage {
        id: editor
        anchors.fill: parent
        visible: app.editorOpen
        z: 20
    }

    ZipPage { id: zipPage }
    GaleriPage { id: galeri; z: 22 }
    SettingsPage {
        id: notAyar
        anchors.fill: parent
        anchors.bottomMargin: nav.height
        notKipi: true
        visible: false
        z: 16
        onKapat: { visible = false; app.selectTab(0); }
    }
    HelpPage { id: help; z: 50 }
    ActionSheet { id: sheet }
    InputDialog { id: input }
    IsPanel { id: isPanel; onIptalEt: app.isIptalSor() }
    Toast { id: toast; bottomGap: app.editorOpen ? 40 : 54 }
}
