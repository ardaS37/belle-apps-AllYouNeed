import QtQuick 1.1

// Belle Files Drive sekmesi: Google Drive istemcisi. Liste verisi sunucudan JSON olarak gelir (/drive/api/list),
// her sey (dosya/klasor ayrimi olmadan) degistirme tarihine gore, en yeni ustte.
Rectangle {
    id: app
    width: 640
    height: 480
    color: "#ffffff"

    property string brand: "#1a73e8"
    property string textPrimary: "#202124"
    property string textSecondary: "#5f6368"
    property string divider: "#e8eaed"
    // indirilen / yerel dosyayi ana uygulamaya ac (varsayilan programlar)
    signal yerelAc(string yol)

    property string view: "all"      // all | my | shared | starred
    property string folder: "root"
    property string query: ""
    property string title: qsTr("Tümü")
    property string parentId: ""
    property string nextToken: ""
    property bool loading: false
    property string error: ""
    property variant history: []
    property int reqSeq: 0
    property bool searching: false
    property bool menuOpen: false

    // Aktarim (yukleme/indirme) durumu
    property string xferText: ""
    property double xferDone: 0
    property double xferTotal: 0

    ListModel { id: files }

    // ---------- Belle Files sekmesi ----------
    property bool harici: false            // yukleme dosya yoneticisinden / nottan baslatildi (bildirimi ana uygulama verir)
    property bool yuklendi: false
    signal sekme(int d)                    // sol/sag: Belle Files sekmeleri
    function takeFocus() { focusMain(); }
    function ilkAcilis() {
        if (!drive.hazir) { error = drive.mod === "google" ? qsTr("Google hesabı bağlı değil.") : qsTr("Sunucu parolası girilmedi."); files.clear(); ayarlar(); return; }
        if (!yuklendi) { yuklendi = true; load(true); }
    }
    function ayarlar() { ayarPanel.visible = true; ayarList.forceActiveFocus(); }

    // ---------- Yardimcilar ----------

    function toast(m) { toastBox.show(m); }
    function focusMain() { if (filePage.visible) filePage.forceActiveFocus(); else list.forceActiveFocus(); }
    function pad(n) { return (n < 10 ? "0" : "") + n; }
    function fullDate(iso) {
        var m = /^(\d+)-(\d+)-(\d+)T(\d+):(\d+)/.exec(iso || "");
        if (!m) return "";
        var d = new Date(Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5]));
        return pad(d.getDate()) + "." + pad(d.getMonth() + 1) + "." + d.getFullYear() + " " + pad(d.getHours()) + ":" + pad(d.getMinutes());
    }
    function sizeText(b) {
        if (b >= 1073741824) return (b / 1073741824).toFixed(1) + qsTr(" GB");
        if (b >= 1048576) return (b / 1048576).toFixed(1) + qsTr(" MB");
        return Math.max(1, Math.round(b / 1024)) + qsTr(" KB");
    }
    function errorText(x) {
        var j = {};
        try { j = JSON.parse(x.responseText); } catch (e) { }
        if (x.status === 0) return qsTr("Sunucuya ulaşılamadı. İnternet bağlantısını ya da sunucu adresini (Menü → Sunucu adresi) kontrol edin.");
        if (x.status === 401 || x.status === 403) return qsTr("Sunucu parolası hatalı. Menü → Parolayı sıfırla.");
        if (j.needSetup) return qsTr("Google Drive sunucuda bağlı değil. Menü → Web sürümü üzerinden yeniden bağlayın.");
        return j.error || (qsTr("Hata ") + x.status);
    }
    function post(path, cb) {
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== 4) return;
            var j = {};
            try { j = JSON.parse(x.responseText); } catch (e) { }
            if (x.status !== 200 && !j.error) j.error = errorText(x);
            cb(x.status === 200, j);
        };
        x.open("POST", drive.server + path);
        x.send();
    }

    // ---------- Listeleme ----------

    function load(reset) {
        if (!reset && (nextToken === "" || loading)) return;
        var seq = ++reqSeq;
        loading = true;
        if (reset) { error = ""; nextToken = ""; files.clear(); }
        var url = drive.server + "/drive/api/list?v=" + view + "&f=" + encodeURIComponent(folder);
        if (query !== "") url += "&q=" + encodeURIComponent(query);
        if (!reset) url += "&p=" + encodeURIComponent(nextToken);
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== 4 || seq !== reqSeq) return;
            loading = false;
            if (x.status !== 200) { error = errorText(x); return; }
            var j;
            try { j = JSON.parse(x.responseText); } catch (e) { error = qsTr("Yanıt okunamadı"); return; }
            title = j.title;
            parentId = j.parent || "";
            nextToken = j.next || "";
            // "id" ve "parent" QML'de ozel adlar; modelde fid / pid olarak tutulur
            for (var i = 0; i < j.items.length; i++) {
                var it = j.items[i];
                files.append({ fid: it.id, pid: it.parent, name: it.name, mime: it.mime, kind: it.kind, ext: it.ext, size: it.size,
                               sizeText: it.sizeText, modified: it.modified, date: it.date, starred: it.starred, owner: it.owner,
                               google: it.google, dlExt: it.dlExt, canText: it.canText });
            }
        };
        x.open("GET", url);
        x.send();
    }
    function go(v, f, q, push) {
        if (push) {
            var h = history.slice(0);
            h.push({ v: view, f: folder, q: query });
            history = h;
        }
        view = v; folder = f; query = q;
        load(true);
        list.positionViewAtBeginning();
    }
    function tab(v) {
        history = [];
        searching = false;
        go(v, "root", "", false);
    }
    function back() {
        if (menuOpen) { menuOpen = false; return; }
        if (dialog.visible) { dialog.close(); return; }
        if (filePage.visible) { filePage.close(); return; }
        if (searching) { searching = false; focusMain(); return; }
        if (history.length) {
            var h = history.slice(0);
            var s = h.pop();
            history = h;
            go(s.v, s.f, s.q, false);
            return;
        }
        if (view !== "all") { tab("all"); return; }
        toast(qsTr("Sol/sağ tuş: diğer sekmeler"));
    }
    function itemAt(i) {
        var o = files.get(i);
        return { id: o.fid, name: o.name, mime: o.mime, kind: o.kind, ext: o.ext, size: o.size, sizeText: o.sizeText,
                 modified: o.modified, date: o.date, starred: o.starred, parent: o.pid, owner: o.owner,
                 google: o.google, dlExt: o.dlExt, canText: o.canText };
    }
    function openIndex(i) {
        if (i < 0 || i >= files.count) return;
        var it = itemAt(i);
        if (it.kind === "folder") go("my", it.id, "", true);
        else filePage.show(it);
    }
    function markStar(id, on) {
        for (var i = 0; i < files.count; i++) if (files.get(i).fid === id) files.setProperty(i, "starred", on);
    }
    function uploadTarget() { return view === "my" && query === "" ? folder : "root"; }

    // ---------- Islemler ----------

    function startUpload() {
        if (drive.busy) { toast(qsTr("Önce süren aktarım bitsin")); return; }
        var p = drive.pickFile();
        focusMain();
        if (p === "") return;
        xferText = qsTr("Yükleniyor: ") + drive.baseName(p);
        xferDone = 0; xferTotal = drive.fileSize(p);
        if (!drive.upload(p, uploadTarget())) toast(qsTr("Dosya okunamadı"));
    }
    function startDownload(it, local) {
        if (drive.busy) { toast(qsTr("Önce süren aktarım bitsin")); return; }
        xferText = qsTr("İndiriliyor: ") + drive.baseName(local);
        xferDone = 0; xferTotal = it.size || 0;
        if (!drive.download(it.id, drive.baseName(local))) toast(qsTr("Telefona yazılamadı: ") + drive.downloadDir);
    }
    function askTrash(it) {
        dialog.open(qsTr("Çöpe atılsın mı?"), it.name + qsTr("\n\nDrive'ın çöp kutusundan 30 gün içinde geri alınabilir."), qsTr("Çöpe at"), false, "trash:" + it.id, true);
    }
    function askMkdir() {
        dialog.open(qsTr("Yeni klasör"), view === "my" ? "“" + title + qsTr("” içine") : qsTr("Drive'ım içine"), qsTr("Oluştur"), true, "mkdir", false);
    }

    Connections {
        target: drive
        onProgress: { app.xferDone = done; if (total > 0) app.xferTotal = total; }
        onUploadFinished: {
            if (app.harici) { app.harici = false; if (ok && app.yuklendi) app.load(true); return; }
            app.toast(ok ? qsTr("Yüklendi") : qsTr("Yüklenemedi: ") + message);
            if (ok && (app.view === "all" || (app.view === "my" && app.query === ""))) app.load(true);
        }
        onDownloadFinished: {
            if (!ok) { app.toast(qsTr("İndirilemedi: ") + message); return; }
            filePage.refreshLocal();
            app.yerelAc(path);                    // Belle Files'in varsayilan programlariyla (metin: duzenleyici, foto: galeri...)
        }
    }

    DriveDialog {
        id: dialog
        onAccepted: {
            if (tag.indexOf("trash:") === 0) {
                var id = tag.substring(6);
                app.post("/drive/api/trash/" + id, function (ok, j) {
                    if (!ok) { app.toast(j.error); return; }
                    for (var i = 0; i < files.count; i++) if (files.get(i).fid === id) { files.remove(i); break; }
                    if (filePage.visible) { filePage.visible = false; app.focusMain(); }
                    app.toast(qsTr("Çöpe atıldı"));
                });
            } else if (tag === "key") {
                var c = drive.setKey(text);
                app.toast(c === 1 ? qsTr("Parola kaydedildi") : (c === 0 ? qsTr("Parola hatalı") : qsTr("Sunucuya ulaşılamadı")));
                if (c === 1) { app.yuklendi = false; app.ilkAcilis(); }
            } else if (tag === "cid") { drive.setGoogleClient(text, ""); app.toast(qsTr("Client ID kaydedildi")); }
            else if (tag === "csec") { drive.setGoogleClient(drive.googleClientId(), text); app.toast(qsTr("Client secret kaydedildi")); }
            else if (tag === "kod") {
                var h = drive.googleKodGir(text);
                if (h !== "") app.toast(h);
                else { app.toast(qsTr("Google hesabı bağlandı: ") + drive.googleEmail()); izin.visible = false; ayarPanel.visible = false; app.yuklendi = false; app.ilkAcilis(); }
            } else if (tag === "mkdir") {
                app.post("/drive/api/mkdir?f=" + encodeURIComponent(app.uploadTarget()) + "&name=" + encodeURIComponent(text), function (ok, j) {
                    if (!ok) { app.toast(j.error); return; }
                    app.toast(qsTr("Klasör oluşturuldu"));
                    app.go("my", j.id, "", true);
                });
            }
        }
    }

    // ---------- Ust cubuk: sekmeler ----------

    Rectangle {
        id: topBar
        width: parent.width
        height: 56
        color: app.brand
        Row {
            anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
            spacing: 0
            Repeater {
                model: [{ v: "all", t: qsTr("Tümü") }, { v: "my", t: qsTr("Klasörler") }, { v: "shared", t: qsTr("Paylaşılan") }, { v: "starred", t: qsTr("Yıldızlı") }]
                delegate: Item {
                    width: tabText.paintedWidth + 26
                    height: 56
                    property bool active: app.view === modelData.v && app.query === "" && app.history.length === 0
                    Text { id: tabText; anchors.centerIn: parent; text: modelData.t; color: "#ffffff"; opacity: parent.active ? 1 : 0.75; font.pixelSize: 20; font.bold: parent.active }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 4; color: "#ffffff"; visible: parent.active }
                    MouseArea { anchors.fill: parent; onClicked: app.tab(modelData.v) }
                }
            }
        }
        Row {
            anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
            DriveBtn { flat: true; text: qsTr("Ara"); onClicked: { app.searching = true; searchField.text = app.query; searchField.forceActiveFocus(); searchField.openSoftwareInputPanel(); } }
            DriveBtn { flat: true; text: qsTr("Menü"); onClicked: app.menuOpen = !app.menuOpen }
        }
    }

    // ---------- Ikinci cubuk: baslik ve araclar / arama ----------

    Rectangle {
        id: subBar
        anchors.top: topBar.bottom
        width: parent.width
        height: 54
        color: "#f1f3f4"

        Row {
            id: leftTools
            anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
            visible: !app.searching
            spacing: 4
            DriveBtn { text: "‹"; fontSize: 26; visible: app.history.length > 0; onClicked: app.back() }
        }
        Text {
            anchors { left: leftTools.right; leftMargin: 10; right: rightTools.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            visible: !app.searching
            text: app.query !== "" ? qsTr("Arama: ") + app.query : app.title
            font.pixelSize: 21
            font.bold: true
            color: app.textPrimary
            elide: Text.ElideRight
        }
        Row {
            id: rightTools
            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
            visible: !app.searching
            spacing: 6
            DriveBtn { text: qsTr("Üst klasör"); visible: app.view === "my" && app.query === "" && app.parentId !== ""; onClicked: app.go("my", app.parentId, "", true) }
            DriveBtn { text: qsTr("+ Klasör"); visible: app.query === "" && (app.view === "my" || app.view === "all"); onClicked: app.askMkdir() }
            DriveBtn { text: qsTr("Yükle"); primary: true; visible: app.query === "" && (app.view === "my" || app.view === "all"); enabled: !drive.busy; onClicked: app.startUpload() }
        }

        // Arama
        Item {
            anchors.fill: parent
            visible: app.searching
            Rectangle {
                anchors { left: parent.left; leftMargin: 8; right: searchBtns.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                height: 42; radius: 6; color: "#ffffff"
                border.width: 2; border.color: searchField.activeFocus ? app.brand : "#c4c7c5"
                TextInput {
                    id: searchField
                    // Ctrl+V yapistir / Ctrl+A tumunu sec (E6: Ctrl+V "7" ya da kod 22 gonderir)
                    Keys.onPressed: {
                        if (((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_V || event.text === "7" || event.text === "v")) || event.text === "\u0016") { searchField.paste(); event.accepted = true; }
                        else if (((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_A || event.text === "a")) || event.text === "\u0001") { searchField.selectAll(); event.accepted = true; }
                    }
                    anchors { left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    font.pixelSize: 20
                    color: app.textPrimary
                    onAccepted: searchGo.clicked()
                    Keys.onEscapePressed: app.back()
                }
                MouseArea { anchors.fill: parent; enabled: !searchField.activeFocus; onClicked: { searchField.forceActiveFocus(); searchField.openSoftwareInputPanel(); } }
            }
            Row {
                id: searchBtns
                anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                spacing: 6
                DriveBtn {
                    id: searchGo
                    primary: true
                    text: qsTr("Ara")
                    onClicked: {
                        var q = searchField.text.replace(/^\s+|\s+$/g, "");
                        if (q === "") return;
                        searchField.closeSoftwareInputPanel();
                        app.searching = false;
                        app.go(app.view, app.folder, q, true);
                        app.focusMain();
                    }
                }
                DriveBtn { text: qsTr("Kapat"); onClicked: { searchField.closeSoftwareInputPanel(); app.back(); } }
            }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#dadce0" }
    }

    // ---------- Liste ----------

    ListView {
        id: list
        anchors { top: subBar.bottom; left: parent.left; right: parent.right; bottom: xferBar.visible ? xferBar.top : parent.bottom }
        clip: true
        model: files
        focus: true
        highlightMoveDuration: 0
        highlight: Rectangle { color: "#e8f0fe" }
        onAtYEndChanged: if (atYEnd && app.nextToken !== "" && !app.loading) app.load(false)

        Keys.onPressed: {
            if (event.key === Qt.Key_Left) { app.sekme(-1); event.accepted = true; }
            else if (event.key === Qt.Key_Right) { app.sekme(1); event.accepted = true; }
            else if (event.key === Qt.Key_Context1 || event.key === Qt.Key_Menu) { app.menuOpen = !app.menuOpen; event.accepted = true; }
            else if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Escape) { app.back(); event.accepted = true; }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) { app.openIndex(list.currentIndex); event.accepted = true; }
        }

        delegate: Item {
            width: list.width
            height: 66
            Rectangle { anchors.fill: parent; color: "#e8eaed"; visible: rowMouse.pressed }
            DriveFileIcon {
                id: ic
                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                kind: model.kind
                ext: model.ext
                thumb: model.kind === "image" ? drive.server + "/drive/img/" + model.fid + "?w=100" : ""
            }
            Text {
                id: dateLbl
                anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: 12 }
                text: model.date
                color: app.textSecondary
                font.pixelSize: 16
            }
            Text {
                anchors { left: ic.right; leftMargin: 12; right: dateLbl.left; rightMargin: 10; top: parent.top; topMargin: 9 }
                text: (model.starred ? "* " : "") + model.name
                color: app.textPrimary
                font.pixelSize: 20
                elide: Text.ElideMiddle
            }
            Text {
                anchors { left: ic.right; leftMargin: 12; right: parent.right; rightMargin: 12; bottom: parent.bottom; bottomMargin: 9 }
                text: model.kind === "folder" ? qsTr("Klasör") : model.sizeText + (app.view === "shared" && model.owner !== "" ? "  ·  " + model.owner : "")
                color: app.textSecondary
                font.pixelSize: 16
                elide: Text.ElideRight
            }
            Rectangle { anchors { left: ic.right; leftMargin: 12; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
            MouseArea {
                id: rowMouse
                anchors.fill: parent
                onClicked: { list.currentIndex = index; app.openIndex(index); }
            }
        }

        footer: Item {
            width: list.width
            height: app.loading || app.nextToken !== "" ? 60 : 10
            Text {
                anchors.centerIn: parent
                visible: app.loading || app.nextToken !== ""
                text: app.loading ? qsTr("Yükleniyor…") : qsTr("Daha fazla")
                color: app.textSecondary
                font.pixelSize: 18
            }
            MouseArea { anchors.fill: parent; enabled: !app.loading && app.nextToken !== ""; onClicked: app.load(false) }
        }
    }

    // Bos / hata
    Column {
        anchors.centerIn: list
        width: list.width - 80
        spacing: 16
        visible: !app.loading && files.count === 0
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: app.error !== "" ? app.error : (app.query !== "" ? qsTr("Sonuç yok.") : qsTr("Bu klasör boş."))
            color: app.error !== "" ? "#c5221f" : app.textSecondary
            font.pixelSize: 20
        }
        DriveBtn { anchors.horizontalCenter: parent.horizontalCenter; visible: app.error !== ""; text: qsTr("Tekrar dene"); onClicked: app.load(true) }
    }

    // ---------- Aktarim cubugu ----------

    Rectangle {
        id: xferBar
        anchors.bottom: parent.bottom
        width: parent.width
        height: 62
        color: "#202124"
        visible: drive.busy
        z: 120
        Text {
            anchors { left: parent.left; leftMargin: 12; right: cancelBtn.left; rightMargin: 10; top: parent.top; topMargin: 8 }
            text: app.xferText + (app.xferTotal > 0 ? "   " + Math.floor(100 * app.xferDone / app.xferTotal) + "%  (" + app.sizeText(app.xferDone) + " / " + app.sizeText(app.xferTotal) + ")" : "   " + app.sizeText(app.xferDone))
            color: "#ffffff"
            font.pixelSize: 17
            elide: Text.ElideMiddle
        }
        Rectangle {
            anchors { left: parent.left; leftMargin: 12; right: cancelBtn.left; rightMargin: 10; bottom: parent.bottom; bottomMargin: 12 }
            height: 8; radius: 4; color: "#5f6368"
            Rectangle { height: parent.height; radius: 4; color: "#8ab4f8"; width: app.xferTotal > 0 ? parent.width * Math.min(1, app.xferDone / app.xferTotal) : 0 }
        }
        DriveBtn { id: cancelBtn; anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter } text: qsTr("İptal"); onClicked: drive.cancel() }
    }

    DriveFilePage {
        id: filePage
        anchors.fill: parent
        anchors.bottomMargin: xferBar.visible ? xferBar.height : 0
        onClosed: app.focusMain()
    }

    // ---------- Menu ----------

    MouseArea { anchors.fill: parent; visible: app.menuOpen; z: 140; onClicked: app.menuOpen = false }
    Rectangle {
        anchors { right: parent.right; top: topBar.bottom; rightMargin: 4 }
        width: 330
        height: menuCol.height
        visible: app.menuOpen
        z: 141
        color: "#ffffff"
        border.width: 1
        border.color: "#c4c7c5"
        Column {
            id: menuCol
            width: parent.width
            Repeater {
                model: [qsTr("Yenile"), qsTr("Bağlantı ayarları (") + (drive.mod === "google" ? qsTr("Google") : qsTr("Sunucu")) + ")", qsTr("Web'de aç"), qsTr("İndirilenler: ") + drive.downloadDir]
                delegate: Rectangle {
                    width: menuCol.width
                    height: 54
                    color: mm.pressed ? "#e8eaed" : "transparent"
                    Text { anchors { left: parent.left; leftMargin: 16; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } text: modelData; font.pixelSize: 19; color: index === 3 ? app.textSecondary : app.textPrimary; elide: Text.ElideRight }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: app.divider }
                    MouseArea {
                        id: mm
                        anchors.fill: parent
                        onClicked: {
                            app.menuOpen = false;
                            if (index === 0) app.load(true);
                            else if (index === 1) app.ayarlar();
                            else if (index === 2) drive.openWeb();
                            else if (index === 3) app.yerelAc(drive.downloadDir);
                        }
                    }
                }
            }
        }
    }

    // ---------- Baglanti ayarlari: Sunucu ya da Google dogrudan ----------
    ListModel { id: ayarRows }
    function ayarDoldur() {
        var keep = ayarList.currentIndex;
        ayarRows.clear();
        var g = drive.mod === "google";
        ayarRows.append({ k: "mod", t: qsTr("Bağlantı türü"), v: g ? qsTr("Google doğrudan (sunucusuz)") : qsTr("Sunucu üzerinden") });
        if (!g) {
            ayarRows.append({ k: "server", t: qsTr("Sunucu adresi"), v: drive.server.replace("http://", "") });
            ayarRows.append({ k: "key", t: qsTr("Sunucu parolası"), v: drive.hasKey() ? qsTr("kayıtlı") : "girilmedi" });
        } else {
            ayarRows.append({ k: "cid", t: qsTr("Google Client ID"), v: drive.googleClientId() });
            ayarRows.append({ k: "csec", t: qsTr("Google Client secret"), v: drive.googleHasSecret() ? "girildi" : qsTr("girilmedi (gerekli)") });
            ayarRows.append({ k: "bagla", t: drive.googleBagli() ? qsTr("Hesap: ") + drive.googleEmail() : qsTr("Google hesabını bağla"), v: drive.googleBagli() ? qsTr("yeniden bağlamak için seçin") : qsTr("izin adresi açılır") });
            if (drive.googleBagli()) ayarRows.append({ k: "cikis", t: qsTr("Google bağlantısını kes"), v: "" });
        }
        ayarRows.append({ k: "kapat", t: qsTr("Kapat"), v: "" });
        ayarList.currentIndex = Math.max(0, Math.min(keep, ayarRows.count - 1));
    }
    Connections { target: drive; onServerChanged: app.ayarDoldur() }
    function ayarSec(k) {
        if (k === "mod") { drive.setMod(drive.mod === "google" ? "sunucu" : "google"); app.yuklendi = false; files.clear(); app.error = ""; }
        else if (k === "server") { if (drive.changeServer()) { app.toast(qsTr("Sunucu: ") + drive.server); app.yuklendi = false; } }
        else if (k === "key") dialog.open(qsTr("Sunucu parolası"), qsTr("Sunucunun parolası (WhatsBelle ile aynı)"), qsTr("Kaydet"), true, "key", false, "", true);
        else if (k === "cid") dialog.open(qsTr("Google Client ID"), qsTr("Google Cloud Console > API ve Hizmetler > Kimlik bilgileri > OAuth istemcisi (Masaüstü uygulaması)"), qsTr("Kaydet"), true, "cid", false, drive.googleClientId(), false);
        else if (k === "csec") dialog.open(qsTr("Google Client secret"), qsTr("Aynı OAuth istemcisinin gizli anahtarı. Telefonda saklanır, koda gömülmez."), qsTr("Kaydet"), true, "csec", false, "", true);
        else if (k === "bagla") {
            if (!drive.googleHasSecret()) { app.toast(qsTr("Önce Client secret girin")); return; }
            izinAdres.text = drive.googleIzinAdresi();
            izin.visible = true;
        }
        else if (k === "cikis") { drive.googleCikis(); files.clear(); app.yuklendi = false; app.toast(qsTr("Google bağlantısı kesildi")); }
        else if (k === "kapat") { ayarPanel.visible = false; app.ilkAcilis(); app.focusMain(); }
    }
    Rectangle {
        id: ayarPanel
        anchors.fill: parent
        visible: false
        color: "#ffffff"
        z: 145
        onVisibleChanged: if (visible) app.ayarDoldur()
        MouseArea { anchors.fill: parent }
        Rectangle {
            id: ayarUst
            width: parent.width; height: 52; color: app.brand
            Text { anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter } text: qsTr("Drive bağlantısı"); color: "#ffffff"; font.pixelSize: 21; font.bold: true }
            DriveBtn { anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter } flat: true; text: qsTr("Kapat"); onClicked: app.ayarSec("kapat") }
        }
        ListView {
            id: ayarList
            anchors { top: ayarUst.bottom; left: parent.left; right: parent.right; bottom: ayarAlt.top }
            clip: true; model: ayarRows
            highlight: Rectangle { color: "#e8f0fe" }
            highlightMoveDuration: 0
            delegate: Item {
                width: ayarList.width; height: 62
                Rectangle { anchors.fill: parent; color: "#e8eaed"; visible: arMa.pressed }
                Column {
                    anchors { left: parent.left; leftMargin: 16; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    Text { text: t; font.pixelSize: 19; color: app.textPrimary; elide: Text.ElideRight; width: parent.width }
                    Text { text: v; visible: v !== ""; font.pixelSize: 15; color: app.brand; elide: Text.ElideMiddle; width: parent.width }
                }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: app.divider }
                MouseArea { id: arMa; anchors.fill: parent; onClicked: { ayarList.currentIndex = index; app.ayarSec(k); } }
            }
            Keys.onPressed: {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) { app.ayarSec(ayarRows.get(currentIndex).k); event.accepted = true; }
                else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace || event.key === Qt.Key_Context2) { app.ayarSec("kapat"); event.accepted = true; }
            }
        }
        Text {
            id: ayarAlt
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
            wrapMode: Text.Wrap; font.pixelSize: 14; color: app.textSecondary
            text: drive.mod === "google"
                ? qsTr("Google doğrudan: telefon Google Drive'a kendisi bağlanır (HTTPS). Herkes kendi Google hesabını ve kendi OAuth istemcisini (Client ID + secret, 'Masaüstü uygulaması' türü) girebilir.")
                : qsTr("Sunucu üzerinden: istekler kendi sunucunuzdan geçer (adres ve parola ayarlanabilir). Sunucuda Drive bağlı olmalıdır (/drive/setup).")
        }
    }

    // Google izin adresi: bilgisayarda ya da telefonun tarayicisinda acilir, donen adres yapistirilir
    Rectangle {
        id: izin
        anchors.fill: parent
        visible: false
        color: "#ffffff"
        z: 148
        MouseArea { anchors.fill: parent }
        Flickable {
            anchors { fill: parent; margins: 14; bottomMargin: izinBtn.height + 24 }
            contentHeight: izinCol.height; clip: true
            Column {
                id: izinCol
                width: parent.width; spacing: 10
                Text { width: parent.width; wrapMode: Text.Wrap; font.pixelSize: 20; font.bold: true; color: app.textPrimary; text: qsTr("Google hesabını bağla") }
                Text {
                    width: parent.width; wrapMode: Text.Wrap; font.pixelSize: 16; color: app.textSecondary
                    text: qsTr("1) Aşağıdaki adres panoya kopyalandı. Bir bilgisayarda (ya da telefonun tarayıcısında) açın ve Google hesabınızla izin verin.\n") +
                          qsTr("2) Google sizi açılmayan bir 127.0.0.1 adresine yönlendirecek. Tarayıcının adres çubuğundaki o adresin TAMAMINI kopyalayın.\n") +
                          qsTr("3) 'Dönen adresi yapıştır' deyip yapıştırın.")
                }
                Rectangle {
                    width: parent.width; height: izinAdres.paintedHeight + 16; color: "#f1f3f4"; radius: 6
                    TextEdit { id: izinAdres; x: 8; y: 8; width: parent.width - 16; wrapMode: TextEdit.WrapAnywhere; readOnly: true; selectByMouse: true; font.pixelSize: 13; color: app.textPrimary }
                }
            }
        }
        Row {
            id: izinBtn
            anchors { right: parent.right; bottom: parent.bottom; margins: 12 }
            spacing: 8
            DriveBtn { text: qsTr("Tarayıcıda aç"); onClicked: drive.openUrl(izinAdres.text) }
            DriveBtn { text: qsTr("Vazgeç"); onClicked: izin.visible = false }
            DriveBtn { text: qsTr("Dönen adresi yapıştır"); primary: true; onClicked: dialog.open(qsTr("Dönen adres"), qsTr("127.0.0.1 ile başlayan adresin tamamı (ya da yalnızca code değeri)"), qsTr("Bağla"), true, "kod", false, "", false) }
        }
    }
    DriveToast { id: toastBox }

    // Ilk yukleme sekme acilinca (ilkAcilis); baslangicta ag kullanilmaz
}
