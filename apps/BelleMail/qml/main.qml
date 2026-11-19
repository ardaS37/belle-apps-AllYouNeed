import QtQuick 1.1
import "Posta.js" as P

// BelleMail: posta listesi. Sunucusuz: "mail" (C++) posta kutusuna dogrudan IMAP ile baglanir.
// Fiziksel klavye: Enter ac, Sil geri. Ana listede geri: uygulama arka plana gecer (bildirimler surer).
Rectangle {
    id: app
    width: 640
    height: 480
    color: "#ffffff"

    property string brand: "#c5221f"
    property string brandDark: "#a50e0e"
    property string textPrimary: "#202124"
    property string textSecondary: "#5f6368"
    property string divider: "#ececec"
    property string unreadBg: "#fdf3f2"

    property string folder: "inbox"
    property string folderTitle: ""
    property string query: ""
    property int page: 0
    property bool more: false
    property bool loading: false
    property string error: ""
    property int unseen: mail.okunmamis
    property int total: 0
    property int reqSeq: 0
    property bool searching: false
    property bool menuOpen: false

    property string xferText: ""
    property double xferDone: 0
    property double xferTotal: 0

    property variant folderNames: ({ inbox: qsTr("Gelen kutusu"), starred: qsTr("Yıldızlı"), sent: qsTr("Gönderilen"), spam: qsTr("Spam"), trash: qsTr("Çöp kutusu"),
                                     all: qsTr("Tüm postalar"), drafts: qsTr("Taslaklar") })
    property variant araliklar: [0, 2, 5, 15, 30]

    ListModel { id: mails }

    // ---------- Yardimcilar ----------

    function toast(m) { toastBox.show(m); }
    function focusMain() {
        if (hesapSayfasi.visible) return;
        if (compose.visible) compose.focusEditor();
        else if (msgPage.visible) msgPage.forceActiveFocus();
        else if (klasorSayfasi.visible) return;
        else list.forceActiveFocus();
    }
    function sizeText(b) {
        if (b >= 1048576) return (b / 1048576).toFixed(1) + qsTr(" MB");
        return Math.max(1, Math.round(b / 1024)) + qsTr(" KB");
    }
    // tur: liste | mesaj | islem | klasorler | gonder ; cb(ok, j) (hata: j.error)
    function istek(tur, p, cb) { return P.istek(tur, p, cb); }
    function baslik() {
        if (query !== "") return qsTr("Arama: ") + query;
        if (folderTitle !== "") return folderTitle;
        return folderNames[folder] || folder;
    }
    function aralikMetni(dk) { return dk > 0 ? qsTr("%1 dk").arg(dk) : qsTr("kapalı"); }
    function aralikDegistir() {
        var a = araliklar, s = mail.kontrolDakika, i = 0;
        for (var k = 0; k < a.length; k++) if (a[k] === s) i = k;
        mail.kontrolDakika = a[(i + 1) % a.length];
        toast(qsTr("Yeni posta denetimi: ") + aralikMetni(mail.kontrolDakika));
    }

    // ---------- Liste ----------

    function load(reset) {
        if (!mail.hesapVar) { mails.clear(); error = qsTr("Posta hesabı girilmemiş."); return; }
        if (!reset && (!more || loading)) return;
        var seq = ++reqSeq;
        loading = true;
        if (reset) { error = ""; page = 0; }
        var p = reset ? 0 : page + 1;
        istek("liste", { f: folder, s: p, q: query }, function (ok, j) {
            if (seq !== reqSeq) return;
            loading = false;
            if (!ok) { if (j.error === "iptal") return; error = j.error; if (reset) mails.clear(); return; }
            if (reset) mails.clear();
            page = p;
            more = j.more;
            total = j.total;
            for (var i = 0; i < j.items.length; i++) {
                var it = j.items[i];
                // "uid" yerine muid: modelde ozel adlarla cakismasin
                mails.append({ muid: it.uid, from: it.from || it.fromAddr, fromAddr: it.fromAddr, subject: it.subject, snippet: it.snippet,
                               date: P.kisaTarih(it.ts), unread: it.unread, starred: it.starred, att: it.att });
            }
            if (reset) list.positionViewAtBeginning();
        });
    }
    function tab(f) {
        searching = false;
        query = "";
        folder = f;
        folderTitle = "";
        load(true);
    }
    function klasorAc(k, ad) {
        searching = false;
        query = "";
        folder = k;
        folderTitle = folderNames[k] ? "" : ad;
        load(true);
        focusMain();
    }
    function back() {
        if (menuOpen) { menuOpen = false; return; }
        if (dialog.visible) { dialog.close(); return; }
        if (hesapSayfasi.visible) { if (mail.hesapVar) hesapSayfasi.kapat(); return; }
        if (compose.visible) { compose.tryClose(); return; }
        if (msgPage.visible) { msgPage.close(); return; }
        if (klasorSayfasi.visible) { klasorSayfasi.kapat(); return; }
        if (searching) { searching = false; focusMain(); return; }
        if (query !== "") { query = ""; load(true); return; }
        if (folder !== "inbox") { tab("inbox"); return; }
        arkaPlan();
    }
    function arkaPlan() {
        if (mail.kontrolDakika > 0) toast(qsTr("Arka planda çalışıyor; yeni postalar bildirilecek"));
        bildirim.arkaPlan();
    }
    function openIndex(i) {
        if (i < 0 || i >= mails.count) return;
        var o = mails.get(i);
        if (o.unread) mails.setProperty(i, "unread", false);
        msgPage.show(folder, { uid: o.muid, from: o.from, fromAddr: o.fromAddr, subject: o.subject, date: o.date, starred: o.starred }, i);
    }
    function indexOfUid(uid) {
        for (var i = 0; i < mails.count; i++) if (mails.get(i).muid === uid) return i;
        return -1;
    }
    // Islem: archive | trash | unread | star | unstar | notspam
    function act(uid, a, done) {
        istek("islem", { f: folder, uid: uid, a: a }, function (ok, j) {
            if (!ok) { toast(j.error); return; }
            var i = indexOfUid(uid);
            if (a === "archive" || a === "trash" || a === "notspam") {
                if (i >= 0) mails.remove(i);
                if (total > 0) total--;
                toast(a === "archive" ? qsTr("Arşivlendi") : (a === "trash" ? (folder === "trash" ? qsTr("Kalıcı olarak silindi") : qsTr("Çöp kutusuna taşındı")) : qsTr("Gelen kutusuna taşındı")));
            } else if (a === "unread") {
                if (i >= 0) mails.setProperty(i, "unread", true);
                toast(qsTr("Okunmadı olarak işaretlendi"));
            } else if (a === "star" || a === "unstar") {
                if (i >= 0) mails.setProperty(i, "starred", a === "star");
                if (a === "unstar" && folder === "starred" && i >= 0) mails.remove(i);
            }
            if (done) done();
        });
    }

    Connections {
        target: mail
        onYanit: P.yanitGeldi(id, ok, veri, hata)
        onProgress: { app.xferDone = done; if (total > 0) app.xferTotal = total; }
        onDownloadFinished: {
            if (!ok) { app.toast(qsTr("İndirilemedi: ") + message); return; }
            if (!mail.openFile(path)) app.toast(qsTr("İndirildi: ") + path);
        }
        onHesapDegisti: { app.tab("inbox"); }
        onYeniPosta: {
            bildirim.mesaj("posta", (adet > 1 ? qsTr("✉ %1 yeni posta").arg(adet) + " · " : "✉ ") + kimden, konu, true);
            if (bildirim.onde && app.folder === "inbox" && app.query === "" && !msgPage.visible && !compose.visible && list.contentY < 50 && !app.loading) app.load(true);
        }
    }
    Connections {
        target: bildirim
        onDokunuldu: { bildirim.temizle("posta"); if (!compose.visible) { msgPage.visible = false; app.tab("inbox"); } }
        onOndeDegisti: if (bildirim.onde) bildirim.temizle("posta")
    }

    Dialog {
        id: dialog
        onAccepted: {
            if (tag === "discard") compose.close();
            else if (tag === "hesapSil") { mail.hesapSil(); mails.clear(); hesapSayfasi.ac(); }
        }
    }

    // ---------- Ust cubuk: klasorler ----------

    Rectangle {
        id: topBar
        width: parent.width
        height: 56
        color: app.brand
        Row {
            anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
            Repeater {
                model: [{ f: "inbox", t: qsTr("Gelen") }, { f: "starred", t: qsTr("Yıldızlı") }, { f: "sent", t: qsTr("Giden") }, { f: "all", t: qsTr("Tümü") }, { f: "*", t: qsTr("Klasörler") }]
                delegate: Item {
                    width: tabRow.width + 20
                    height: 56
                    property bool active: modelData.f === "*" ? (app.folder !== "inbox" && app.folder !== "starred" && app.folder !== "sent" && app.folder !== "all" && app.query === "")
                                                              : (app.folder === modelData.f && app.query === "")
                    Row {
                        id: tabRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: modelData.t; color: "#ffffff"; opacity: parent.parent.active ? 1 : 0.78; font.pixelSize: 19; font.bold: parent.parent.active; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle {
                            visible: modelData.f === "inbox" && app.unseen > 0
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(26, cnt.paintedWidth + 12); height: 24; radius: 12
                            color: "#ffffff"
                            Text { id: cnt; anchors.centerIn: parent; text: app.unseen > 999 ? "999+" : app.unseen; color: app.brand; font.pixelSize: 14; font.bold: true }
                        }
                    }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 4; color: "#ffffff"; visible: parent.active }
                    MouseArea { anchors.fill: parent; onClicked: modelData.f === "*" ? klasorSayfasi.ac() : app.tab(modelData.f) }
                }
            }
        }
        Btn {
            anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
            flat: true; text: qsTr("Menü")
            onClicked: app.menuOpen = !app.menuOpen
        }
    }

    // ---------- Ikinci cubuk: baslik, arama, yeni posta ----------

    Rectangle {
        id: subBar
        anchors.top: topBar.bottom
        width: parent.width
        height: 56
        color: "#f6f8fc"

        Column {
            anchors { left: parent.left; leftMargin: 14; right: rightTools.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            visible: !app.searching
            Text {
                width: parent.width
                text: app.baslik()
                font.pixelSize: 21; font.bold: true; color: app.textPrimary; elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: mail.kullanici + (app.total > 0 ? "  ·  " + app.total + qsTr(" posta") : "")
                visible: mail.kullanici !== ""
                font.pixelSize: 14; color: app.textSecondary; elide: Text.ElideRight
            }
        }
        Row {
            id: rightTools
            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
            visible: !app.searching
            spacing: 6
            Btn { text: qsTr("Ara"); onClicked: { app.searching = true; searchField.text = app.query; searchField.forceActiveFocus(); searchField.openSoftwareInputPanel(); } }
            Btn { text: qsTr("✎ Yaz"); primary: true; onClicked: compose.open("new", "", 0) }
        }

        Item {
            anchors.fill: parent
            visible: app.searching
            Rectangle {
                anchors { left: parent.left; leftMargin: 8; right: searchBtns.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                height: 42; radius: 21; color: "#ffffff"
                border.width: 2; border.color: searchField.activeFocus ? app.brand : "#c4c7c5"
                TextInput {
                    id: searchField
                    // Ctrl+V yapistir / Ctrl+A tumunu sec (E6: Ctrl+V "7" ya da kod 22 gonderir)
                    Keys.onPressed: {
                        if (((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_V || event.text === "7" || event.text === "v")) || event.text === "\u0016") { pano.yapistir(searchField); event.accepted = true; }
                        else if (((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_A || event.text === "a")) || event.text === "\u0001") { searchField.selectAll(); event.accepted = true; }
                    }
                    anchors { left: parent.left; right: parent.right; leftMargin: 16; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    font.pixelSize: 20
                    color: app.textPrimary
                    onAccepted: { mail.girisiTamamla(); searchGo.clicked(); }
                    Keys.onEscapePressed: app.back()
                }
                MouseArea { anchors.fill: parent; enabled: !searchField.activeFocus; onClicked: { searchField.forceActiveFocus(); searchField.openSoftwareInputPanel(); } }
            }
            Row {
                id: searchBtns
                anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                spacing: 6
                Btn {
                    id: searchGo
                    primary: true
                    text: qsTr("Ara")
                    onClicked: {
                        mail.girisiTamamla();
                        var q = searchField.text.replace(/^\s+|\s+$/g, "");
                        if (q === "") return;
                        searchField.closeSoftwareInputPanel();
                        app.searching = false;
                        app.query = q;
                        app.load(true);
                        app.focusMain();
                    }
                }
                Btn { text: qsTr("Kapat"); onClicked: { searchField.closeSoftwareInputPanel(); app.back(); } }
            }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#dadce0" }
    }

    // ---------- Liste ----------

    ListView {
        id: list
        anchors { top: subBar.bottom; left: parent.left; right: parent.right; bottom: xferBar.visible ? xferBar.top : parent.bottom }
        clip: true
        model: mails
        focus: true
        highlightMoveDuration: 0
        highlight: Rectangle { color: "#e8eaed" }
        onAtYEndChanged: if (atYEnd && app.more && !app.loading) app.load(false)

        Keys.onPressed: {
            if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Escape) { app.back(); event.accepted = true; }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) { app.openIndex(list.currentIndex); event.accepted = true; }
        }

        delegate: Item {
            width: list.width
            height: 84
            Rectangle { anchors.fill: parent; color: rowMouse.pressed ? "#e8eaed" : (model.unread ? app.unreadBg : "transparent") }
            Rectangle {   // okunmadi cizgisi
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: 4
                color: app.brand
                visible: model.unread
            }
            Avatar {
                id: av
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                name: model.from
            }
            Text {
                id: dateLbl
                anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: 10 }
                text: model.date
                color: model.unread ? app.brand : app.textSecondary
                font.pixelSize: 15
                font.bold: model.unread
            }
            Text {
                anchors { left: av.right; leftMargin: 14; right: dateLbl.left; rightMargin: 10; top: parent.top; topMargin: 8 }
                text: model.from
                textFormat: Text.PlainText
                color: app.textPrimary
                font.pixelSize: 19
                font.bold: model.unread
                elide: Text.ElideRight
            }
            Text {
                id: subj
                anchors { left: av.right; leftMargin: 14; right: flags.left; rightMargin: 8; top: parent.top; topMargin: 33 }
                text: model.subject
                textFormat: Text.PlainText
                color: model.unread ? app.textPrimary : "#3c4043"
                font.pixelSize: 17
                font.bold: model.unread
                elide: Text.ElideRight
            }
            Row {
                id: flags
                anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: 34 }
                spacing: 6
                Rectangle {
                    visible: model.att
                    width: attT.paintedWidth + 10; height: 20; radius: 4; color: "#e8eaed"
                    Text { id: attT; anchors.centerIn: parent; text: qsTr("Ek"); font.pixelSize: 13; color: app.textSecondary; font.bold: true }
                }
                Text { visible: model.starred; text: "★"; color: "#f4b400"; font.pixelSize: 19 }
            }
            Text {
                anchors { left: av.right; leftMargin: 14; right: parent.right; rightMargin: 12; top: parent.top; topMargin: 57 }
                text: model.snippet
                textFormat: Text.PlainText
                color: app.textSecondary
                font.pixelSize: 15
                elide: Text.ElideRight
            }
            Rectangle { anchors { left: av.right; leftMargin: 14; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
            MouseArea {
                id: rowMouse
                anchors.fill: parent
                onClicked: { list.currentIndex = index; app.openIndex(index); }
            }
        }

        footer: Item {
            width: list.width
            height: app.loading || app.more ? 60 : 10
            Text {
                anchors.centerIn: parent
                visible: app.loading || app.more
                text: app.loading ? qsTr("Yükleniyor…") : qsTr("Daha eski postalar")
                color: app.textSecondary
                font.pixelSize: 18
            }
            MouseArea { anchors.fill: parent; enabled: !app.loading && app.more; onClicked: app.load(false) }
        }
    }

    // Bos / hata
    Column {
        anchors.centerIn: list
        width: list.width - 80
        spacing: 16
        visible: !app.loading && mails.count === 0
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: app.error !== "" ? app.error : (app.query !== "" ? qsTr("Sonuç yok.") : qsTr("Burada posta yok."))
            color: app.error !== "" ? "#c5221f" : app.textSecondary
            font.pixelSize: 20
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            Btn { visible: app.error !== "" && mail.hesapVar; text: qsTr("Tekrar dene"); onClicked: app.load(true) }
            Btn { visible: app.error !== ""; text: qsTr("Hesap ayarları"); onClicked: hesapSayfasi.ac() }
        }
    }

    // ---------- Ek indirme cubugu ----------

    Rectangle {
        id: xferBar
        anchors.bottom: parent.bottom
        width: parent.width
        height: 62
        color: "#202124"
        visible: mail.busy
        z: 120
        Text {
            anchors { left: parent.left; leftMargin: 12; right: cancelBtn.left; rightMargin: 10; top: parent.top; topMargin: 8 }
            text: app.xferText + (app.xferTotal > 0 ? "   " + Math.min(100, Math.floor(100 * app.xferDone / app.xferTotal)) + "%" : "   " + app.sizeText(app.xferDone))
            color: "#ffffff"
            font.pixelSize: 17
            elide: Text.ElideMiddle
        }
        Rectangle {
            anchors { left: parent.left; leftMargin: 12; right: cancelBtn.left; rightMargin: 10; bottom: parent.bottom; bottomMargin: 12 }
            height: 8; radius: 4; color: "#5f6368"
            Rectangle { height: parent.height; radius: 4; color: "#f28b82"; width: app.xferTotal > 0 ? parent.width * Math.min(1, app.xferDone / app.xferTotal) : 0 }
        }
        Btn { id: cancelBtn; anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter } text: qsTr("İptal"); onClicked: mail.cancel() }
    }

    KlasorPage {
        id: klasorSayfasi
        anchors.fill: parent
        onClosed: app.focusMain()
    }

    MessagePage {
        id: msgPage
        anchors.fill: parent
        anchors.bottomMargin: xferBar.visible ? xferBar.height : 0
        onClosed: app.focusMain()
    }

    ComposePage {
        id: compose
        anchors.fill: parent
        onClosed: app.focusMain()
    }

    HesapPage {
        id: hesapSayfasi
        anchors.fill: parent
        onClosed: app.focusMain()
    }

    // ---------- Menu ----------

    MouseArea { anchors.fill: parent; visible: app.menuOpen; z: 140; onClicked: app.menuOpen = false }
    Rectangle {
        anchors { right: parent.right; top: topBar.bottom; rightMargin: 4 }
        width: 380
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
                model: [qsTr("Yenile"), qsTr("Hesap: ") + (mail.kullanici !== "" ? mail.kullanici : qsTr("yok")), qsTr("Yeni posta denetimi: ") + app.aralikMetni(mail.kontrolDakika),
                        qsTr("Ekler: ") + mail.downloadDir, qsTr("Arka plana al"), "Dil / Language: " + ((dil.secim === "auto" ? dil.kod : dil.secim) === "en" ? "English" : "Türkçe"), qsTr("Depolama yeri: ") + depo.ad(depo.secim), qsTr("Çık")]
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
                            if (index === 0) { app.load(true); mail.simdiKontrol(); }
                            else if (index === 1) hesapSayfasi.ac();
                            else if (index === 2) app.aralikDegistir();
                            else if (index === 3) mail.openFile(mail.downloadDir);
                            else if (index === 4) app.arkaPlan();
                            else if (index === 5) app.dilDegistir();
                            else if (index === 6) app.depoDegistir();
                            else if (index === 7) Qt.quit();
                        }
                    }
                }
            }
        }
    }

    // Dil / Language: Turkce <-> English (tum uygulamalarda ortak, yeniden acinca gecerli)
    function dilDegistir() {
        var k = dil.secim === "auto" ? dil.kod : dil.secim;
        dil.sec(k === "en" ? "tr" : "en");
        app.toast(dil.yenidenBaslat ? "Dil değişti; uygulamayı yeniden açın. / Language changed; restart the app." : "Dil / Language: " + (k === "en" ? "Türkçe" : "English"));
    }

    // Depolama yeri: Otomatik -> saglam suruculer -> Telefon (C:) (kutuphane/depo; yeniden acinca gecerli)
    function depoDegistir() {
        depo.sec(depo.sonraki());
        app.toast(qsTr("Depolama yeri: ") + depo.ad(depo.secim) + (depo.yenidenBaslat ? qsTr(" (yeniden açınca geçerli olur)") : ""));
    }

    Toast { id: toastBox }

    // Acikken (onde) gelen kutusu basindaysa liste kendiliginden tazelensin
    Timer {
        interval: 180000; repeat: true; running: bildirim.onde && mail.hesapVar
        onTriggered: if (app.folder === "inbox" && app.query === "" && !msgPage.visible && !compose.visible && !hesapSayfasi.visible && list.contentY < 50 && !app.loading) app.load(true)
    }

    Component.onCompleted: {
        if (!mail.hesapVar) { hesapSayfasi.ac(); return; }
        load(true);
        list.forceActiveFocus();
    }
}
