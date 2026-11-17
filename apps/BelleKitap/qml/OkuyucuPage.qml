import QtQuick 1.1
import "Util.js" as U

// Okuyucu. Saga dokun / Bosluk / Asagi / Sag: sonraki sayfa; sola dokun / Yukari / Sol: onceki sayfa;
// ortaya dokun: cubuklar. , . bolum; T icindekiler; B yer imi; Y yer imleri; + - yazi; N tema; Geri: kitaplik.
Rectangle {
    id: root
    color: app.temalar[app.tema][1]
    property string yol: ""
    property string kitapAdi: ""
    property string yazar: ""
    property int bolumSayisi: 0
    property variant icindekiler: []
    property int bolumNo: 0
    property int parcaNo: 0
    property int parcaSayisi: 1
    property variant parcalar: []
    property bool cubuklar: false
    property bool yukleniyor: false
    property real yuzde: bolumSayisi > 0 ? Math.min(100, (bolumNo + (parcaNo + (akis.contentHeight > akis.height ? akis.contentY / Math.max(1, akis.contentHeight - akis.height) : 1)) / Math.max(1, parcaSayisi)) / bolumSayisi * 100) : 0
    property string bolumAdi: ""
    // yukleme sonrasi konumlanma: "bas" | "son" | oran (0..1)
    property variant hedefKonum: "bas"

    function takeFocus() { akis.forceActiveFocus(); }
    function durum() { return "kitap='" + kitapAdi + "' bolum=" + (bolumNo + 1) + "/" + bolumSayisi + " parca=" + (parcaNo + 1) + "/" + parcaSayisi + " metin=" + metin.text.length + " y=" + Math.round(akis.contentY) + "/" + Math.round(akis.contentHeight) + " yuzde=" + Math.round(yuzde); }

    function ac(y) {
        yukleniyor = true;
        visible = true;
        metin.text = "";
        bekleyenYol = y;
        kt.zamanla("okuyucu_ac", 60);   // once "Aciliyor" gorunsun, sonra (bloklayan) acma; C++ zamanlayici ekran kapaliyken de calisir
    }
    property string bekleyenYol: ""
    Connections {
        target: kt
        onZamanDoldu: { if (ad === "okuyucu_ac") root.acGercek(root.bekleyenYol); else if (ad === "okuyucu_konum") root.konumlan(); }
    }
    function acGercek(y) {
        var m = kt.ac(y);
        if (!m.ok) { yukleniyor = false; visible = false; app.showToast(qsTr("Açılamadı: ") + m.hata); return; }
        yol = y;
        kitapAdi = m.baslik;
        yazar = m.yazar || "";
        bolumSayisi = m.bolumSayisi;
        icindekiler = m.icindekiler;
        var k = app.konum(y);
        if (k) git(Math.min(k.bolum, bolumSayisi - 1), k.parca, k.oran);
        else git(0, 0, 0);
        cubuklar = !k;
        takeFocus();
    }
    function git(b, p, oran) {
        yukleniyor = true;
        bolumNo = Math.max(0, Math.min(bolumSayisi - 1, b));
        parcalar = kt.bolum(bolumNo, Math.max(200, akis.width - 2 * app.kenar));
        parcaSayisi = Math.max(1, parcalar.length);
        parcaNo = Math.max(0, Math.min(parcaSayisi - 1, p));
        bolumAdi = kt.bolumBasligi(bolumNo);
        hedefKonum = oran === undefined ? "bas" : oran;
        metin.text = parcalar[parcaNo] || "";
        kt.zamanla("okuyucu_konum", 40);
    }
    function parcaGit(p, hedef) {
        parcaNo = p;
        hedefKonum = hedef;
        metin.text = parcalar[parcaNo] || "";
        kt.zamanla("okuyucu_konum", 40);
    }
    // metin dizildikten sonra (contentHeight belli olunca) konumlan
    function konumlan() {
        var h = Math.max(0, akis.contentHeight - akis.height);
        if (hedefKonum === "son") akis.contentY = h;
        else if (hedefKonum === "bas") akis.contentY = 0;
        else akis.contentY = Math.round(h * Number(hedefKonum));
        yukleniyor = false;
        kaydet();
    }
    function kaydet() {
        if (yol === "") return;
        var h = Math.max(1, akis.contentHeight - akis.height);
        app.yurut("INSERT OR REPLACE INTO konum(yol, bolum, parca, oran, yuzde, t) VALUES(?, ?, ?, ?, ?, ?)", [yol, bolumNo, parcaNo, Math.min(1, akis.contentY / h), yuzde, new Date().getTime()]);
    }
    function ileri() {
        if (yukleniyor) return;
        var adim = akis.height - Math.round(app.okuFont * 1.6);
        if (akis.contentY + akis.height < akis.contentHeight - 4) { akis.contentY = Math.min(akis.contentHeight - akis.height, akis.contentY + adim); kaydet(); }
        else if (parcaNo < parcaSayisi - 1) parcaGit(parcaNo + 1, "bas");
        else if (bolumNo < bolumSayisi - 1) git(bolumNo + 1, 0, 0);
        else app.showToast(qsTr("Kitabın sonu"));
    }
    function geri() {
        if (yukleniyor) return;
        var adim = akis.height - Math.round(app.okuFont * 1.6);
        if (akis.contentY > 2) { akis.contentY = Math.max(0, akis.contentY - adim); kaydet(); }
        else if (parcaNo > 0) parcaGit(parcaNo - 1, "son");
        else if (bolumNo > 0) { var b = bolumNo - 1; git(b, 999, "son"); }
        else app.showToast(qsTr("Kitabın başı"));
    }
    function bolumGit(b) { if (b >= 0 && b < bolumSayisi) git(b, 0, 0); }
    function kapat() { kaydet(); yol = ""; app.kitapliga(); }
    function yaziBoyu(d) {
        app.okuFont = Math.max(14, Math.min(40, app.okuFont + d));
        app.ayarYaz("okuFont", app.okuFont);
        var oran = akis.contentY / Math.max(1, akis.contentHeight - akis.height);
        hedefKonum = oran;
        kt.zamanla("okuyucu_konum", 40);
    }
    function temaDegistir() { app.tema = (app.tema + 1) % app.temalar.length; app.ayarYaz("tema", app.tema); app.showToast(qsTr(app.temalar[app.tema][0])); }
    function yerImiEkle() {
        var et = (bolumAdi !== "" ? bolumAdi : qsTr("Bölüm ") + (bolumNo + 1)) + "  •  %" + Math.round(yuzde);
        var h = Math.max(1, akis.contentHeight - akis.height);
        app.yurut("INSERT INTO yerimi(yol, bolum, parca, oran, yuzde, etiket, t) VALUES(?, ?, ?, ?, ?, ?, ?)", [yol, bolumNo, parcaNo, akis.contentY / h, yuzde, et, new Date().getTime()]);
        app.showToast(qsTr("Yer imi eklendi: ") + et);
    }
    function yerImleri() {
        var l = app.sorgu("SELECT rowid AS id, * FROM yerimi WHERE yol = ? ORDER BY yuzde", [yol]), it = [];
        for (var i = 0; i < l.length; i++) it.push({ label: l[i].etiket, icon: "star", key: "y" + i });
        it.push({ label: qsTr("Buraya yer imi ekle"), icon: "plus", key: "ekle", hint: "B" });
        sheet.open(qsTr("Yer imleri"), it, function (k) {
            if (k === "ekle") { root.yerImiEkle(); return; }
            var y = l[parseInt(k.substring(1), 10)];
            sheet.open(y.etiket, [{ label: qsTr("Git"), icon: "next", key: "git" }, { label: qsTr("Sil"), icon: "trash", key: "sil", danger: true }], function (k2) {
                if (k2 === "git") root.git(Number(y.bolum), Number(y.parca), Number(y.oran));
                else { app.yurut("DELETE FROM yerimi WHERE rowid = ?", [Number(y.id)]); app.showToast(qsTr("Yer imi silindi")); }
            });
        });
    }
    function gorunum() {
        var it = [];
        for (var i = 0; i < app.temalar.length; i++) it.push({ label: (i === app.tema ? "● " : "") + qsTr(app.temalar[i][0]), icon: "eye", key: "t" + i });
        it.push({ label: qsTr("Yazı büyüt (+)  •  şu an ") + app.okuFont, icon: "plus", key: "buyut" });
        it.push({ label: qsTr("Yazı küçült (-)"), icon: "font", key: "kucult" });
        it.push({ label: qsTr("Kenar boşluğu: ") + app.kenar, icon: "wrap", key: "kenar" });
        sheet.open(qsTr("Görünüm"), it, function (k) {
            if (k.charAt(0) === "t") { app.tema = parseInt(k.substring(1), 10); app.ayarYaz("tema", app.tema); }
            else if (k === "buyut") root.yaziBoyu(2);
            else if (k === "kucult") root.yaziBoyu(-2);
            else if (k === "kenar") { app.kenar = app.kenar === 12 ? 24 : (app.kenar === 24 ? 40 : 12); app.ayarYaz("kenar", app.kenar); root.git(root.bolumNo, root.parcaNo, akis.contentY / Math.max(1, akis.contentHeight - akis.height)); }
        });
    }

    // ---- sayfa ----
    Flickable {
        id: akis
        anchors { fill: parent; topMargin: 8; bottomMargin: 26 }
        clip: true
        contentWidth: width
        contentHeight: metin.paintedHeight + 40
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        onMovementEnded: root.kaydet()
        Text {
            id: metin
            x: app.kenar
            y: 10
            width: akis.width - 2 * app.kenar
            textFormat: Text.RichText
            wrapMode: Text.Wrap
            color: app.temalar[app.tema][2]
            font.pixelSize: app.okuFont
        }
        // dokunma bolgeleri: sol ucte bir onceki, sag ucte bir sonraki sayfa, orta cubuklar
        MouseArea {
            width: akis.width
            height: Math.max(akis.height, akis.contentHeight)
            onClicked: {
                var x = mouse.x;
                if (x < width / 3) root.geri();
                else if (x > width * 2 / 3) root.ileri();
                else root.cubuklar = !root.cubuklar;
            }
        }
        Keys.onPressed: {
            var k = event.key, t = U.tus(event);
            if (U.ctrl(event) && (k === Qt.Key_Q || t === "q")) { root.kaydet(); Qt.quit(); event.accepted = true; return; }
            if (k === Qt.Key_Space || k === Qt.Key_Down || k === Qt.Key_Right || k === Qt.Key_PageDown) root.ileri();
            else if (k === Qt.Key_Up || k === Qt.Key_Left || k === Qt.Key_PageUp) root.geri();
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) root.cubuklar = !root.cubuklar;
            else if (k === Qt.Key_Backspace || k === Qt.Key_Escape || k === Qt.Key_Context2) { if (icPanel.visible) icPanel.visible = false; else root.kapat(); }
            else if (k === Qt.Key_Menu || k === Qt.Key_Context1) root.cubuklar = !root.cubuklar;
            else if (t === "," || t === "<") root.bolumGit(root.bolumNo - 1);
            else if (t === "." || t === ">") root.bolumGit(root.bolumNo + 1);
            else if (t === "t") icPanel.ac();
            else if (t === "b") root.yerImiEkle();
            else if (t === "y") root.yerImleri();
            else if (t === "+" || t === "=" || t === "*") root.yaziBoyu(2);
            else if (t === "-" || t === "_" || t === "#") root.yaziBoyu(-2);
            else if (t === "n") root.temaDegistir();
            else return;
            event.accepted = true;
        }
    }
    // alt bilgi satiri (her zaman): bolum adi ve yuzde
    Text {
        anchors { left: parent.left; leftMargin: app.kenar; right: yuzdeYazi.left; rightMargin: 8; bottom: parent.bottom; bottomMargin: 5 }
        text: root.bolumAdi !== "" ? root.bolumAdi : root.kitapAdi
        color: app.temalar[app.tema][3]
        font.pixelSize: 13
        elide: Text.ElideRight
    }
    Text { id: yuzdeYazi; anchors { right: parent.right; rightMargin: app.kenar; bottom: parent.bottom; bottomMargin: 5 } text: "%" + Math.round(root.yuzde); color: app.temalar[app.tema][3]; font.pixelSize: 13 }
    Text { anchors.centerIn: parent; visible: root.yukleniyor; text: qsTr("Açılıyor…"); color: app.temalar[app.tema][3]; font.pixelSize: 20 }

    // ---- ust cubuk ----
    Rectangle {
        id: ust
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 54
        color: app.surface
        visible: root.cubuklar
        IconButton { id: geriBtn; anchors { left: parent.left; verticalCenter: parent.verticalCenter } icon: "back"; onClicked: root.kapat() }
        Column {
            anchors { left: geriBtn.right; right: ustDugmeler.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
            Text { width: parent.width; text: root.kitapAdi; color: app.textPrimary; font.pixelSize: 17; font.bold: true; elide: Text.ElideRight }
            Text { width: parent.width; text: (root.yazar !== "" ? root.yazar + "  •  " : "") + qsTr("Bölüm ") + (root.bolumNo + 1) + "/" + root.bolumSayisi; color: app.textSecondary; font.pixelSize: 13; elide: Text.ElideRight }
        }
        Row {
            id: ustDugmeler
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            IconButton { icon: "lines"; tone: "w"; iconSize: 24; onClicked: icPanel.ac() }
            IconButton { icon: "star"; tone: "a"; iconSize: 24; onClicked: root.yerImleri() }
            IconButton { icon: "font"; tone: "w"; iconSize: 24; onClicked: root.gorunum() }
        }
    }
    // ---- alt cubuk ----
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 50
        color: app.surface
        visible: root.cubuklar
        IconButton { id: oncekiB; anchors { left: parent.left; verticalCenter: parent.verticalCenter } icon: "prev"; tone: "w"; iconSize: 24; onClicked: root.bolumGit(root.bolumNo - 1) }
        IconButton { id: sonrakiB; anchors { right: parent.right; verticalCenter: parent.verticalCenter } icon: "next"; tone: "w"; iconSize: 24; onClicked: root.bolumGit(root.bolumNo + 1) }
        Column {
            anchors { left: oncekiB.right; right: sonrakiB.left; verticalCenter: parent.verticalCenter }
            spacing: 4
            Rectangle {
                width: parent.width; height: 6; radius: 3; color: app.fieldBg
                Rectangle { width: parent.width * root.yuzde / 100; height: parent.height; radius: 3; color: app.brand }
                MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: root.bolumGit(Math.floor(mouse.x / parent.width * root.bolumSayisi)) }
            }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "%" + Math.round(root.yuzde) + "  •  " + (root.bolumAdi !== "" ? root.bolumAdi : qsTr("Bölüm ") + (root.bolumNo + 1)); color: app.textSecondary; font.pixelSize: 13; elide: Text.ElideRight; width: parent.width; horizontalAlignment: Text.AlignHCenter }
        }
    }

    // ---- icindekiler ----
    Rectangle {
        id: icPanel
        anchors.fill: parent
        color: app.bg
        visible: false
        z: 5
        function ac() {
            im.clear();
            var l = root.icindekiler, sec = 0;
            for (var i = 0; i < l.length; i++) { im.append({ baslik: l[i].baslik, bolum: l[i].bolum, derinlik: l[i].derinlik }); if (l[i].bolum <= root.bolumNo) sec = i; }
            visible = true;
            ic.currentIndex = sec;
            ic.positionViewAtIndex(sec, ListView.Center);
            ic.forceActiveFocus();
        }
        ListModel { id: im }
        Header { id: ih; anchors { left: parent.left; right: parent.right; top: parent.top } title: qsTr("İçindekiler"); subtitle: root.kitapAdi; showBack: true; onBack: { icPanel.visible = false; root.takeFocus(); } }
        ListView {
            id: ic
            anchors { left: parent.left; right: parent.right; top: ih.bottom; bottom: parent.bottom }
            clip: true
            model: im
            highlightMoveDuration: 80
            delegate: Rectangle {
                width: ic.width
                height: Math.round(28 * app.yazi + 16)
                property bool cur: ListView.isCurrentItem && ic.activeFocus
                color: ima.pressed ? app.pressed : (cur ? app.highlight : (bolum === root.bolumNo ? app.markBg : "transparent"))
                Text { x: 18 + derinlik * 18; width: parent.width - x - 14; anchors.verticalCenter: parent.verticalCenter; text: baslik; color: bolum === root.bolumNo ? app.brand : app.textPrimary; font.pixelSize: Math.round((derinlik ? 16 : 18) * app.yazi); elide: Text.ElideRight }
                Rectangle { anchors { left: parent.left; leftMargin: 18; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
                MouseArea { id: ima; anchors.fill: parent; onClicked: { icPanel.visible = false; root.git(bolum, 0, 0); root.takeFocus(); } }
            }
            Keys.onPressed: {
                var k = event.key;
                if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) { var o = im.get(currentIndex); icPanel.visible = false; root.git(o.bolum, 0, 0); root.takeFocus(); event.accepted = true; }
                else if (k === Qt.Key_Escape || k === Qt.Key_Backspace || k === Qt.Key_Left || k === Qt.Key_Context2) { icPanel.visible = false; root.takeFocus(); event.accepted = true; }
            }
        }
    }
}
