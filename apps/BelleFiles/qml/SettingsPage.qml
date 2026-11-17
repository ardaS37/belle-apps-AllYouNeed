import QtQuick 1.1
import "Util.js" as U

// Ayarlar listesi. Enter / Bosluk: degistir. Sol/Sag: sekme.
Rectangle {
    id: root
    color: app.bg

    // notKipi: Notlar sekmesinden acilan "Not ayarları" (duzenleyici, notlar klasoru, not esitleme)
    property bool notKipi: false
    signal kapat

    function takeFocus() { list.forceActiveFocus(); build(); }

    function onoff(b) { return b ? qsTr("Açık") : qsTr("Kapalı"); }
    function ekle(k, label, value, icon) { smodel.append({ k: k, label: label, value: "" + value, icon: icon }); }
    function build() {
        var keep = list.currentIndex;
        smodel.clear();
        ekle("font", qsTr("Yazı boyutu"), app.fontSize + qsTr(" piksel"), "font");
        if (notKipi) {
            ekle("wrap", qsTr("Satır kaydırma"), onoff(app.wrap), "wrap");
            ekle("enc", qsTr("Açarken kodlama"), U.encodingLabel(app.defaultEncoding), "font");
            ekle("eol", qsTr("Yeni dosyada satır sonu"), U.eolLabel(app.newEol), "wrap");
            ekle("backup", qsTr("Kaydederken .bak yedeği"), onoff(app.makeBackup), "save");
            ekle("auto", qsTr("Otomatik kaydet (30 sn)"), onoff(app.autoSave), "clock");
            ekle("draft", qsTr("Taslak koruması (çökmeye karşı)"), onoff(app.draftGuard), "check");
            ekle("big", qsTr("Büyük dosya sınırı"), app.bigFileKB + qsTr(" KB"), "info");
            ekle("notes", qsTr("Notlar klasörü"), fs.notesDir(), "home");
            ekle("oto", qsTr("Not kaydedince Drive'a eşitle"), onoff(app.otoEsitle), "senkron");
            ekle("otodir", qsTr("Otomatik eşitlenen klasörler"), app.otoKlasorler.length ? app.otoKlasorler.length + qsTr(" klasör") : qsTr("yok"), "sdkart");
            ekle("dnot", qsTr("Drive'da notlar klasörü"), app.driveNotKlasoru, "drive");
            ekle("exts", qsTr("Metin olarak tanınan uzantılar"), "", "doc");
        } else {
            ekle("notayar", qsTr("Not ayarları"), qsTr("Notlar sekmesinde ⚙"), "home");
            ekle("all", qsTr("Tüm dosyaları göster"), onoff(app.showAll), "file");
            ekle("vars", qsTr("Varsayılan programlar"), qsTr("metin, foto, video, ses"), "gear");
            ekle("dyedek", qsTr("Drive'da yedek klasörü"), app.driveYedekKlasoru, "drive");
            ekle("indir", qsTr("Drive'dan indirilenler"), drive.downloadDir, "sdkart");
            ekle("lang", "Dil / Language", ((dil.secim === "auto" ? dil.kod : dil.secim) === "en" ? "English" : "Türkçe") + (dil.yenidenBaslat ? " ↻" : ""), "font");
            ekle("help", qsTr("Klavye kısayolları"), "H", "key");
            ekle("log", qsTr("Günlüğü göster"), "", "lines");
            ekle("about", qsTr("Hakkında"), qsTr("Belle Files ") + app.version, "info");
            ekle("quit", qsTr("Çıkış"), qsTr("Ctrl+Q"), "quit");
        }
        list.currentIndex = Math.max(0, Math.min(keep, smodel.count - 1));
    }
    // Dosya turu basina hangi programla acilacagi (Belle Files / telefonun uygulamasi / sor)
    function varsayilanlar() {
        var turler = ["metin", "resim", "video", "ses"], ik = { metin: "doc", resim: "eye", video: "play", ses: "muzik" }, items = [];
        for (var i = 0; i < turler.length; i++)
            items.push({ label: app.turAdi(turler[i]) + ": " + app.secenekAdi(turler[i], app.varsayilan(turler[i])), icon: ik[turler[i]], key: turler[i] });
        sheet.open(qsTr("Varsayılan programlar (Belle Files içinden açılan dosyalar)"), items, function (t) {
            app.varsayilanSec(t, function () { root.varsayilanlar(); });
        });
    }
    function setBool(name, key) {
        app[name] = !app[name];
        app.setSetting(key, app[name] ? "1" : "0");
        build();
    }
    function activate(i) {
        if (i < 0 || i >= smodel.count) return;
        var k = smodel.get(i).k;
        if (k === "font") {
            var sizes = [14, 16, 18, 19, 21, 24, 28, 32], items = [];
            for (var j = 0; j < sizes.length; j++) items.push({ label: (sizes[j] === app.fontSize ? "● " : "") + sizes[j] + qsTr(" piksel") + (sizes[j] === 19 ? qsTr(" (varsayılan)") : ""), icon: "font", key: "f" + sizes[j] });
            sheet.open(qsTr("Yazı boyutu (tüm uygulama)"), items, function (v) {
                var n = parseInt(("" + v).replace(/[^0-9]/g, ""), 10);
                if (!(n > 0)) return;
                app.fontSize = n;
                app.setSetting("fontSize", "" + n);
                root.build();
                app.showToast(qsTr("Yazı boyutu: ") + n);
            });
        }
        else if (k === "lang") { var dk = dil.secim === "auto" ? dil.kod : dil.secim; dil.sec(dk === "en" ? "tr" : "en"); app.showToast(dil.yenidenBaslat ? "Dil değişti; uygulamayı yeniden açın. / Language changed; restart the app." : "Dil / Language: " + (dk === "en" ? "Türkçe" : "English")); build(); }
        else if (k === "wrap") setBool("wrap", "wrap");
        else if (k === "enc") {
            var encs = ["", "UTF-8", "windows-1254", "ISO-8859-9", "ISO-8859-1", "UTF-16LE"], it2 = [];
            for (var e = 0; e < encs.length; e++) it2.push({ label: (encs[e] === app.defaultEncoding ? "● " : "") + U.encodingLabel(encs[e]), icon: "font", key: "e" + encs[e] });
            sheet.open(qsTr("Açarken kodlama (Otomatik önerilir)"), it2, function (v) { app.defaultEncoding = v.substring(1); app.setSetting("encoding", app.defaultEncoding); root.build(); });
        }
        else if (k === "eol") {
            sheet.open(qsTr("Yeni dosyada satır sonu"), [
                { label: qsTr("CRLF (Windows, Nokia)"), icon: "wrap", key: "crlf" },
                { label: qsTr("LF (Unix, Android)"), icon: "wrap", key: "lf" }
            ], function (v) { app.newEol = v; app.setSetting("eol", v); root.build(); });
        }
        else if (k === "backup") setBool("makeBackup", "backup");
        else if (k === "auto") setBool("autoSave", "autoSave");
        else if (k === "draft") setBool("draftGuard", "draft");
        else if (k === "all") { setBool("showAll", "showAll"); app.refreshAll(); }
        else if (k === "big") {
            var kb = [128, 256, 384, 512, 768, 1024], it3 = [];
            for (var b = 0; b < kb.length; b++) it3.push({ label: (kb[b] === app.bigFileKB ? "● " : "") + kb[b] + qsTr(" KB"), icon: "info", key: "" + kb[b] });
            sheet.open(qsTr("Bu boyuttan büyük dosyalar parça parça, salt okunur açılır"), it3, function (v) { app.bigFileKB = parseInt(v, 10); app.setSetting("bigFileKB", v); root.build(); });
        }
        else if (k === "vars") varsayilanlar();
        else if (k === "notayar") app.notAyarlari();
        else if (k === "notes") {
            sheet.open(qsTr("Notlar klasörü: ") + fs.notesDir(), [
                { label: qsTr("Klasörü aç"), icon: "folder", key: "open" },
                { label: qsTr("Varsayılana dön (") + fs.baseDir() + "/Notlar)", icon: "home", key: "reset" },
                { label: qsTr("Hafıza kartı: E:/BelleFiles/Notlar"), icon: "sdkart", key: "E:/BelleFiles/Notlar" },
                { label: qsTr("Telefon: C:/Data/BelleFiles/Notlar"), icon: "home", key: "C:/Data/BelleFiles/Notlar" },
                { label: qsTr("Başka klasör: Dosyalar'da klasör menüsü > Notlar klasörü yap"), icon: "info", key: "x" }
            ], function (v) {
                if (v === "open") app.showFolder(fs.notesDir(), "");
                else if (v === "reset") { var p = fs.baseDir() + "/Notlar"; fs.setNotesDir(p); app.setSetting("notesDir", ""); notesPage.openPath(p, ""); root.build(); }
                else if (v.indexOf(":/") === 1) { fs.makeDir(v); fs.setNotesDir(v); app.setSetting("notesDir", v); notesPage.openPath(v, ""); root.build(); }
            });
        }
        else if (k === "oto") { app.otoEsitle = !app.otoEsitle; app.setSetting("otoEsitle", app.otoEsitle ? "1" : "0"); build(); }
        else if (k === "otodir") {
            var l = app.otoKlasorler, it4 = [];
            for (var a = 0; a < l.length; a++) it4.push({ label: qsTr("Çıkar: ") + l[a], icon: "close", key: "d" + a });
            var hazir = ["E:/Images", "E:/Videos", "E:/Sounds", "E:/Documents", "E:/Downloads", "C:/Data/Images", "C:/Data/Documents"];
            for (var b2 = 0; b2 < hazir.length; b2++) if (fs.isDir(hazir[b2]) && !app.otoKlasorVar(hazir[b2])) it4.push({ label: qsTr("Ekle: ") + hazir[b2], icon: "sdkart", key: "a" + hazir[b2] });
            it4.push({ label: qsTr("Başka klasör: Dosyalar > klasöre basılı tut > Otomatik Drive eşitlemesine ekle"), icon: "info", key: "x" });
            it4.push({ label: qsTr("Şimdi eşitle (notlar + bu klasörler)"), icon: "senkron", key: "s" });
            sheet.open(qsTr("Notlar ekranındaki senkron düğmesi bu klasörleri de Drive > ") + app.driveYedekKlasoru + qsTr(" altına eşitler (yalnızca değişenler)"), it4, function (v) {
                if (v.charAt(0) === "d") app.otoKlasorDegistir(app.otoKlasorler[parseInt(v.substring(1), 10)]);
                else if (v.charAt(0) === "a") app.otoKlasorDegistir(v.substring(1));
                else if (v === "s") app.notlariEsitle(false);
                root.build();
            });
        }
        else if (k === "dnot" || k === "dyedek") {
            var not = k === "dnot";
            input.open({ title: not ? qsTr("Drive'da notlar klasörü") : qsTr("Drive'da yedek klasörü"), label1: qsTr("Drive'ım altında klasör adı (alt klasör için / kullanın)"), text1: not ? app.driveNotKlasoru : app.driveYedekKlasoru, ok: qsTr("Kaydet") }, function (v) {
                v = v.replace(/^[\s\/]+|[\s\/]+$/g, "");
                if (v === "") return;
                if (not) { app.driveNotKlasoru = v; app.setSetting("driveNot", v); } else { app.driveYedekKlasoru = v; app.setSetting("driveYedek", v); }
                root.build();
            });
        }
        else if (k === "indir") {
            var sec = [{ label: qsTr("Hafıza kartı: E:/Drive"), icon: "sdkart", key: "E:/Drive" }, { label: qsTr("Telefon: C:/Data/Drive"), icon: "home", key: "C:/Data/Drive" },
                       { label: qsTr("Hafıza kartı: E:/Downloads"), icon: "sdkart", key: "E:/Downloads" }, { label: qsTr("Varsayılan (kart varsa kart)"), icon: "check", key: "" },
                       { label: qsTr("Klasörü aç"), icon: "folder", key: "ac" }];
            sheet.open(qsTr("Drive'dan indirilenler: ") + drive.downloadDir, sec, function (v) {
                if (v === "ac") { app.showFolder(drive.downloadDir, ""); return; }
                drive.setDownloadDir(v);
                root.build();
            });
        }
        else if (k === "exts") logView.show(qsTr("Metin olarak tanınan uzantılar"), fs.textExtensions().replace(/ /g, "  ") + qsTr("\n\nUzantısız küçük dosyalar da metin sayılır. Diğerleri için: Dosyalar > T (tüm dosyalar) > dosya > G (metin olarak aç)."));
        else if (k === "help") help.open();
        else if (k === "log") logView.show(qsTr("Günlük"), fs.logText());
        else if (k === "about") logView.show(qsTr("Belle Files ") + app.version,
            qsTr("Nokia E6 (Belle) için not defteri, dosya yöneticisi ve Google Drive istemcisi.\n\nNotlar: not ekranındaki bulut düğmesi notu, Notlar listesindeki senkron düğmesi tüm notları (ve seçtiğiniz otomatik klasörleri) Drive'a eşitler; yalnızca değişenler gider.\nZip: arşivin içini gezme, çıkarma ve sıkıştırma. Ses dosyaları dahili çalarla çalar.\nUzun dosya işleri (kopyala, taşı, sil, zip, Drive yedeği) arka planda ilerleme göstergesiyle çalışır.\nDosyalar: bir dosyaya basılı tutun > Drive'a yükle. SIS/JAR yükleyiciye, video ve müzik harici oynatıcıya gider; büyük dosyalar metin olarak parça parça açılır.\nDrive: Sunucu üzerinden ya da kendi Google hesabınızla doğrudan.\n\n") +
            qsTr("Klasörler:\n  Notlar: ") + fs.notesDir() + qsTr("\n  Dışa aktarılanlar: ") + fs.exportDir() + qsTr("\n  Yedekler: ") + fs.backupDir() + qsTr("\n  Günlük / taslak: ") + fs.dataDir() + "\n\n" +
            qsTr("Kodlama tanıma: BOM, UTF-8, Windows-1254 (Türkçe), UTF-16.\n") +
            qsTr("Dönüştürme: html, txt, vcf (rehber), vcs (takvim), m3u, csv, json, xml, srt.\n") +
            qsTr("Dışa aktarma: paket .txt (geri yüklenebilir), tek HTML, ayrı HTML'ler, kopya, pano.\n") +
            qsTr("Drive: Sunucu üzerinden ya da kendi Google hesabınızla doğrudan."));
        else if (k === "quit") app.quit();
    }

    ListModel { id: smodel }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: root.notKipi ? qsTr("Not ayarları") : qsTr("Ayarlar")
        subtitle: root.notKipi ? qsTr("düzenleyici, notlar klasörü, eşitleme") : qsTr("Belle Files ") + app.version
        showBack: root.notKipi
        onBack: root.kapat()
    }
    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        clip: true
        model: smodel
        focus: true
        delegate: Item {
            width: list.width
            height: Math.round(32 * app.yazi + 20)
            property bool cur: ListView.isCurrentItem && list.activeFocus
            Rectangle { anchors.fill: parent; color: ma.pressed ? app.pressed : (parent.cur ? app.highlight : "transparent") }
            Rectangle { visible: parent.cur; anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 4; color: app.brand }
            Image { anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter } width: 24; height: 24; smooth: true; source: "../images/" + icon + "_a.png" }
            Text { id: lbl; anchors { left: parent.left; leftMargin: 54; verticalCenter: parent.verticalCenter } text: label; color: app.textPrimary; font.pixelSize: Math.round(18 * app.yazi) }
            Text {
                anchors { left: lbl.right; leftMargin: 12; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                horizontalAlignment: Text.AlignRight
                text: value; color: app.textSecondary; font.pixelSize: Math.round(15 * app.yazi); elide: Text.ElideLeft
            }
            Rectangle { anchors { left: parent.left; leftMargin: 54; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
            MouseArea { id: ma; anchors.fill: parent; onClicked: { list.currentIndex = index; root.activate(index); } }
        }
        Keys.onPressed: {
            var k = event.key;
            if (root.notKipi && (k === Qt.Key_Left || k === Qt.Key_Backspace || k === Qt.Key_Escape || k === Qt.Key_Context2)) { root.kapat(); event.accepted = true; }
            else if (U.ctrl(event) && k === Qt.Key_Q) { app.quit(); event.accepted = true; }
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select || k === Qt.Key_Space || k === Qt.Key_Context1) { root.activate(currentIndex); event.accepted = true; }
            else if (k === Qt.Key_Left) { app.stepTab(-1); event.accepted = true; }
            else if (k === Qt.Key_Right) { app.stepTab(1); event.accepted = true; }
            else if (U.tus(event) === "h" || event.text === "?") { help.open(); event.accepted = true; }
        }
    }

    // Uzun yazi gosterici (gunluk, hakkinda)
    Rectangle {
        id: logView
        anchors.fill: parent
        color: app.bg
        visible: false
        z: 5
        property string title: ""
        function show(t, body) { title = t; logText.text = body; visible = true; lflick.contentY = 0; lflick.forceActiveFocus(); }
        function hide() { visible = false; list.forceActiveFocus(); }
        Header { id: lh; anchors { left: parent.left; right: parent.right; top: parent.top } title: logView.title; showBack: true; onBack: logView.hide()
            IconButton { icon: "copy"; tone: "w"; iconSize: 22; onClicked: { fs.setClipboardText(logText.text); app.showToast(qsTr("Panoya kopyalandı")); } }
        }
        Flickable {
            id: lflick
            anchors { left: parent.left; right: parent.right; top: lh.bottom; bottom: parent.bottom; margins: 12 }
            clip: true
            contentHeight: logText.paintedHeight + 20
            Text { id: logText; width: lflick.width; wrapMode: Text.Wrap; color: app.textPrimary; font.pixelSize: 16; textFormat: Text.PlainText }
            Keys.onPressed: {
                var k = event.key;
                if (k === Qt.Key_Down) { contentY = Math.min(Math.max(0, contentHeight - height), contentY + 60); event.accepted = true; }
                else if (k === Qt.Key_Up) { contentY = Math.max(0, contentY - 60); event.accepted = true; }
                else if (k === Qt.Key_Escape || k === Qt.Key_Backspace || k === Qt.Key_Context2 || k === Qt.Key_Left || k === Qt.Key_Return || k === Qt.Key_Select) { logView.hide(); event.accepted = true; }
            }
        }
    }
}
