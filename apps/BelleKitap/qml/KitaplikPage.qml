import QtQuick 1.1
import "Util.js" as U

// Kitaplik: bulunan kitaplar (kapak, baslik, yazar, okuma yuzdesi). Son okunanlar ustte.
// Klavye: Enter ac, Bosluk menu, R tara, S ara, Ctrl+Q cikis.
Rectangle {
    id: root
    color: app.bg
    property string suzgec: ""
    property string sirala: "son"            // son | ad | yazar

    function takeFocus() { liste.forceActiveFocus(); }
    function yenile() {
        var l = kt.kutuphane(), q = U.fold(suzgec), d = [];
        for (var i = 0; i < l.length; i++) {
            var b = l[i];
            if (q !== "" && U.fold(b.baslik).indexOf(q) < 0 && U.fold(b.yazar).indexOf(q) < 0) continue;
            var k = app.konum(b.yol);
            d.push({ yol: b.yol, baslik: b.baslik, yazar: b.yazar || "", kapak: b.kapak || "", boyut: b.boyut || 0, tur: b.tur || "epub",
                     yuzde: k ? k.yuzde : -1, t: k ? k.t : 0 });
        }
        d.sort(function (a, b) {
            if (root.sirala === "son" && a.t !== b.t) return b.t - a.t;
            var x = U.fold(root.sirala === "yazar" ? a.yazar + a.baslik : a.baslik), y = U.fold(root.sirala === "yazar" ? b.yazar + b.baslik : b.baslik);
            return x < y ? -1 : (x > y ? 1 : 0);
        });
        km.clear();
        for (var j = 0; j < d.length; j++) km.append(d[j]);
        liste.currentIndex = km.count ? 0 : -1;
    }
    function ac(i) { if (i >= 0 && i < km.count) app.kitapAc(km.get(i).yol); }
    function menu(i) {
        if (i < 0 || i >= km.count) { genel(); return; }
        var o = km.get(i);
        sheet.open(o.baslik, [
            { label: qsTr("Oku"), icon: "doc", key: "ac", hint: qsTr("Enter") },
            { label: qsTr("Baştan başla"), icon: "undo", key: "bastan" },
            { label: (o.yazar ? o.yazar + "  •  " : "") + U.sizeText(o.boyut) + "  •  " + o.tur.toUpperCase(), icon: "info", key: "x" },
            { label: o.yol, icon: "folder", key: "x" }
        ], function (k) {
            if (k === "ac") root.ac(i);
            else if (k === "bastan") { app.yurut("DELETE FROM konum WHERE yol = ?", [o.yol]); root.ac(i); }
        });
    }
    function genel() {
        sheet.open(qsTr("Kitaplık"), [
            { label: qsTr("İnternetten kitap bul (Gutenberg, Vikikaynak)"), icon: "globe", key: "bul", hint: "I" },
            { label: qsTr("Kitapları yeniden tara"), icon: "senkron", key: "tara", hint: "R" },
            { label: qsTr("Ara"), icon: "search", key: "ara", hint: "S" },
            { label: qsTr("Sırala: ") + (root.sirala === "son" ? qsTr("son okunan") : (root.sirala === "ad" ? qsTr("ada göre") : qsTr("yazara göre"))), icon: "sort", key: "sira" },
            { label: "Dil / Language: " + (app.ing ? "English" : "Türkçe"), icon: "font", key: "dil" },
            { label: qsTr("Depolama yeri: ") + depo.ad(depo.secim), icon: "folder", key: "depo" },
            { label: qsTr("Liste yazı boyutu: ") + app.fontSize, icon: "font", key: "yazi" },
            { label: qsTr("Günlüğü göster"), icon: "lines", key: "gunluk" },
            { label: qsTr("Hakkında"), icon: "info", key: "hakkinda" },
            { label: qsTr("Çıkış"), icon: "quit", key: "cikis", hint: qsTr("Ctrl+Q") }
        ], function (k) {
            if (k === "bul") kitapBul.ac();
            else if (k === "tara") kt.tara();
            else if (k === "ara") root.ara();
            else if (k === "sira") { root.sirala = root.sirala === "son" ? "ad" : (root.sirala === "ad" ? "yazar" : "son"); root.yenile(); }
            else if (k === "dil") { dil.sec(app.ing ? "tr" : "en"); app.showToast("Dil değişti; uygulamayı yeniden açın. / Language changed; please restart the app."); }
            else if (k === "depo") { depo.sec(depo.sonraki()); app.showToast(qsTr("Depolama yeri: ") + depo.ad(depo.secim) + (depo.yenidenBaslat ? qsTr(" (yeniden açınca geçerli olur)") : "")); }
            else if (k === "yazi") {
                var l = [16, 18, 19, 21, 24, 28], it = [];
                for (var j = 0; j < l.length; j++) it.push({ label: (l[j] === app.fontSize ? "\u25CF " : "") + l[j], icon: "font", key: "" + l[j] });
                sheet.open(qsTr("Liste yazı boyutu"), it, function (v) { app.fontSize = parseInt(v, 10); app.ayarYaz("fontSize", v); });
            }
            else if (k === "gunluk") bilgi.goster(qsTr("Günlük"), kt.gunluk());
            else if (k === "hakkinda") bilgi.goster("BelleKitap " + app.version, qsTr("Nokia E6 için e-kitap okuyucu.\n\nEPUB (2 ve 3) ve kitap klasörlerindeki TXT dosyaları. Kitaplar hafıza kartında ve C:/Data altında aranır; EPUB'ları örneğin E:/Kitaplar klasörüne kopyalayıp Tara'ya basın.\n\nOkurken: ekranın sağına dokun / Boşluk / Aşağı: sonraki sayfa, soluna dokun / Yukarı: önceki sayfa, ortasına dokun: menü çubukları. , ve . önceki/sonraki bölüm, T içindekiler, B yer imi, Y yer imleri, + - yazı boyutu, N tema, Geri: kitaplık.\n\nKaldığınız yer, yer imleri ve okuma yüzdesi kitap başına saklanır. DRM'li (şifreli) EPUB'lar açılamaz."));
            else if (k === "cikis") Qt.quit();
        });
    }
    function ara() {
        input.open({ title: qsTr("Kitaplıkta ara"), label1: qsTr("Başlık ya da yazar (boş: tümü)"), text1: suzgec, ok: qsTr("Ara") }, function (q) { root.suzgec = q.replace(/^\s+|\s+$/g, ""); root.yenile(); });
    }

    Connections {
        target: kt
        onTaramaBitti: { root.yenile(); app.showToast(kt.kutuphane().length + qsTr(" kitap bulundu")); }
    }

    ListModel { id: km }
    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: root.suzgec !== "" ? "\"" + root.suzgec + "\"" : qsTr("Kitaplığım")
        showBack: root.suzgec !== ""
        onBack: { root.suzgec = ""; root.yenile(); }
        subtitle: kt.taraniyor ? qsTr("taranıyor… ") + tarananSayi.n : km.count + qsTr(" kitap")
        busy: kt.taraniyor
        IconButton { icon: "globe"; tone: "a"; iconSize: 26; onClicked: kitapBul.ac() }
        IconButton { icon: "search"; tone: "w"; iconSize: 24; onClicked: root.ara() }
        IconButton { icon: "senkron"; tone: kt.taraniyor ? "a" : "w"; iconSize: 26; onClicked: kt.tara() }
        IconButton { icon: "more"; tone: "w"; iconSize: 24; onClicked: root.genel() }
    }
    QtObject { id: tarananSayi; property int n: 0 }
    Connections { target: kt; onTaramaIlerleme: tarananSayi.n = bulunan }
    ListView {
        id: liste
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        clip: true
        model: km
        highlightMoveDuration: 100
        delegate: Rectangle {
            id: sat
            width: liste.width
            height: Math.max(96, kol.height + 16)
            property bool cur: ListView.isCurrentItem && liste.activeFocus
            color: sma.pressed ? app.pressed : (cur ? app.highlight : "transparent")
            Rectangle { visible: sat.cur; anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 4; color: app.brand }
            Rectangle {
                id: kapakKutu
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                width: 56; height: 80; radius: 4
                color: app.fieldBg
                clip: true
                Image { id: kapakResim; anchors.fill: parent; source: kapak !== "" ? "file:///" + kapak : ""; sourceSize.width: 112; sourceSize.height: 160; fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true }
                Text { visible: kapakResim.status !== Image.Ready; anchors.centerIn: parent; width: parent.width - 6; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: baslik.substring(0, 24); color: app.brand; font.pixelSize: 10; maximumLineCount: 5; elide: Text.ElideRight }
            }
            Column {
                id: kol
                anchors { left: kapakKutu.right; leftMargin: 14; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                spacing: 3
                Text { width: parent.width; text: baslik; color: app.textPrimary; font.pixelSize: Math.round(19 * app.yazi); font.bold: true; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight }
                Text { width: parent.width; visible: yazar !== ""; text: yazar; color: app.textSecondary; font.pixelSize: Math.round(15 * app.yazi); elide: Text.ElideRight }
                Row {
                    spacing: 8
                    visible: yuzde >= 0
                    Rectangle { width: 120; height: 6; radius: 3; color: app.fieldBg; anchors.verticalCenter: parent.verticalCenter
                        Rectangle { width: parent.width * Math.min(100, yuzde) / 100; height: parent.height; radius: 3; color: app.brand } }
                    Text { text: "%" + Math.round(yuzde) + (t ? "  •  " + Qt.formatDateTime(new Date(t), "d MMM") : ""); color: app.textSecondary; font.pixelSize: Math.round(13 * app.yazi) }
                }
                Text { visible: yuzde < 0; text: qsTr("okunmadı") + "  •  " + tur.toUpperCase(); color: app.textSecondary; font.pixelSize: Math.round(13 * app.yazi) }
            }
            Rectangle { anchors { left: kapakKutu.right; leftMargin: 14; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
            MouseArea { id: sma; anchors.fill: parent; onClicked: { liste.currentIndex = index; root.ac(index); } onPressAndHold: { liste.currentIndex = index; root.menu(index); } }
        }
        Keys.onPressed: {
            var k = event.key, t = U.tus(event);
            if (U.ctrl(event) && (k === Qt.Key_Q || t === "q")) { Qt.quit(); event.accepted = true; return; }
            if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) root.ac(currentIndex);
            else if (k === Qt.Key_Space || k === Qt.Key_Menu || k === Qt.Key_Context1) root.menu(currentIndex);
            else if ((k === Qt.Key_Backspace || k === Qt.Key_Escape) && root.suzgec !== "") { root.suzgec = ""; root.yenile(); }
            else if (t === "r") kt.tara();
            else if (t === "i") kitapBul.ac();
            else if (t === "s" || t === "/") root.ara();
            else return;
            event.accepted = true;
        }
    }
    Text {
        anchors.centerIn: liste
        width: liste.width - 60
        visible: km.count === 0
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: kt.taraniyor ? qsTr("Kitaplar aranıyor…") : qsTr("Kitap yok.\nÜstteki dünya düğmesiyle internetten ücretsiz kitap bulun (Gutenberg, Vikikaynak) ya da EPUB dosyalarını E:/Kitaplar klasörüne kopyalayıp yenileyin.")
        color: app.textSecondary
        font.pixelSize: Math.round(17 * app.yazi)
    }
    Rectangle {
        id: bilgi
        anchors.fill: parent
        color: app.bg
        visible: false
        z: 5
        property string baslik: ""
        function goster(b, m) { baslik = b; bt.text = m; visible = true; bf.contentY = 0; bf.forceActiveFocus(); }
        function gizle() { visible = false; liste.forceActiveFocus(); }
        Header { id: bh; anchors { left: parent.left; right: parent.right; top: parent.top } title: bilgi.baslik; showBack: true; onBack: bilgi.gizle() }
        Flickable {
            id: bf
            anchors { left: parent.left; right: parent.right; top: bh.bottom; bottom: parent.bottom; margins: 12 }
            clip: true
            contentHeight: bt.paintedHeight + 20
            Text { id: bt; width: bf.width; wrapMode: Text.Wrap; color: app.textPrimary; font.pixelSize: Math.round(15 * app.yazi); textFormat: Text.PlainText }
            Keys.onPressed: {
                var k = event.key;
                if (k === Qt.Key_Down) contentY = Math.min(Math.max(0, contentHeight - height), contentY + 60);
                else if (k === Qt.Key_Up) contentY = Math.max(0, contentY - 60);
                else if (k === Qt.Key_Escape || k === Qt.Key_Backspace || k === Qt.Key_Left || k === Qt.Key_Return || k === Qt.Key_Select) bilgi.gizle();
                else return;
                event.accepted = true;
            }
        }
    }
}
