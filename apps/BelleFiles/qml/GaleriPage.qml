import QtQuick 1.1
import "Util.js" as U

// Belle galeri: ayni klasordeki fotograflari sirayla gosterir.
//  Dokunma: kaydir (onceki/sonraki), tek dokunus cubuklari gizle/goster, cift dokunus yakinlastir,
//  iki parmakla yakinlastir; yakinken parmakla gez. Alt seritte kucuk resimler.
//  Klavye: Sol/Sag onceki/sonraki, Yukari/Asagi yakinlastir/uzaklastir, Enter cubuklar,
//  R dondur, Bosluk slayt gosterisi, I bilgi, D sil, Home/End ilk/son, Geri kapat.
Rectangle {
    id: root
    anchors.fill: parent
    color: "#000000"
    visible: false
    property bool shown: visible
    property variant resimler: []       // [{ path, name, size, time }]
    property int sira: 0
    property real olcek: 1               // 1 = ekrana sigdir
    property int aci: 0                  // 0 / 90 / 180 / 270 (yalniz gorunum)
    property bool cubuklar: true
    property bool slayt: false
    property string yol: resimler.length ? resimler[sira].path : ""
    // gercek resim boyutu (dosya basligindan): oran buradan, Image'in kendi boyutundan degil (dongu olmasin)
    property real gw: 1
    property real gh: 1
    onYolChanged: { var b = yol !== "" ? fs.resimBoyutu(yol) : { w: 0, h: 0 }; gw = b.w > 0 ? b.w : 1; gh = b.h > 0 ? b.h : 1; }

    function ac(path) {
        var dir = fs.folderOf(path), l = fs.listDir(dir, true, "", app.filesSort), r = [], s = 0;
        for (var i = 0; i < l.length; i++) {
            if (l[i].dir || !/^(jpg|jpeg|png|gif|bmp)$/.test(l[i].ext)) continue;
            if (l[i].path === path) s = r.length;
            r.push({ path: l[i].path, name: l[i].name, size: l[i].size, time: l[i].time });
        }
        if (!r.length) r.push({ path: path, name: fs.fileName(path), size: fs.info(path).size, time: fs.info(path).time });
        resimler = r;
        git(s);
        cubuklar = true;
        slayt = false;
        visible = true;
        takeFocus();
        app.addRecent(path, 0);
    }
    function kapat() { slayt = false; visible = false; resimler = []; app.focusCurrent(); }
    function takeFocus() { odak.forceActiveFocus(); }
    function git(i) {
        if (!resimler.length) return;
        sira = (i + resimler.length) % resimler.length;
        olcek = 1; aci = 0;
        flick.contentX = 0; flick.contentY = 0;
        serit.positionViewAtIndex(sira, ListView.Center);
    }
    function sonraki() { git(sira + 1); }
    function onceki() { git(sira - 1); }
    function yakinlastir(f) {
        var yeni = Math.max(1, Math.min(4, olcek * f));
        var cx = flick.contentX + flick.width / 2, cy = flick.contentY + flick.height / 2, oran = yeni / olcek;
        olcek = yeni;
        flick.contentX = Math.max(0, Math.min(flick.contentWidth - flick.width, cx * oran - flick.width / 2));
        flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, cy * oran - flick.height / 2));
    }
    function dondur() { aci = (aci + 90) % 360; olcek = 1; }
    function bilgi() {
        if (!resimler.length) return;
        var o = resimler[sira], b = fs.resimBoyutu(o.path);
        sheet.open(o.name, [
            { label: (b.w ? b.w + " × " + b.h + qsTr(" piksel  •  ") : "") + U.sizeText(o.size), icon: "info", key: "x" },
            { label: qsTr("Tarih: ") + U.dateText(o.time), icon: "clock", key: "x" },
            { label: qsTr("Klasör: ") + fs.folderOf(o.path), icon: "folder", key: "klasor" },
            { label: (sira + 1) + " / " + resimler.length + qsTr(" fotoğraf"), icon: "lines", key: "x" },
            { label: qsTr("Yolu panoya kopyala"), icon: "copy", key: "yol" }
        ], function (k) {
            if (k === "yol") app.copyPathText(o.path);
            else if (k === "klasor") { var p = o.path; root.kapat(); app.showFolder(fs.folderOf(p), p); }
        });
    }
    function sil() {
        if (!resimler.length) return;
        var o = resimler[sira];
        sheet.open(qsTr("Silinsin mi? ") + o.name, [
            { label: qsTr("Evet, kalıcı olarak sil"), icon: "trash", key: "evet", danger: true },
            { label: qsTr("Vazgeç"), icon: "close", key: "hayir" }
        ], function (k) {
            if (k !== "evet") { root.takeFocus(); return; }
            if (!fs.removePath(o.path)) { app.showToast(qsTr("Silinemedi: ") + fs.lastError()); return; }
            app.forgetRecent(o.path);
            var r = [], l = root.resimler;
            for (var i = 0; i < l.length; i++) if (i !== root.sira) r.push(l[i]);
            app.showToast(qsTr("Silindi: ") + o.name);
            app.refreshAll();
            if (!r.length) { root.kapat(); return; }
            var s = Math.min(root.sira, r.length - 1);
            root.resimler = r;
            root.git(s);
            root.takeFocus();
        });
    }
    function menu() {
        if (!resimler.length) return;
        var o = resimler[sira];
        sheet.open(o.name, [
            { label: slayt ? qsTr("Slayt gösterisini durdur") : qsTr("Slayt gösterisi (3 sn)"), icon: slayt ? "pause" : "play", key: "slayt", hint: qsTr("Boşluk") },
            { label: qsTr("Döndür"), icon: "redo", key: "dondur", hint: "R" },
            { label: qsTr("Bilgi"), icon: "info", key: "bilgi", hint: "I" },
            { label: qsTr("Telefonun galerisinde aç"), icon: "globe", key: "sistem" },
            { label: qsTr("Drive'a yükle"), icon: "yukle", key: "drive" },
            { label: qsTr("Yeniden adlandır"), icon: "edit", key: "ad" },
            { label: qsTr("Kopyala (dosya)"), icon: "copy", key: "kopya" },
            { label: qsTr("Klasöründe göster"), icon: "folder", key: "klasor" },
            { label: qsTr("Fotoğraflar için varsayılan program…"), icon: "gear", key: "vars" },
            { label: qsTr("Sil"), icon: "trash", key: "sil", danger: true, hint: "D" }
        ], function (k) {
            if (k === "slayt") root.slayt = !root.slayt;
            else if (k === "dondur") root.dondur();
            else if (k === "bilgi") { root.bilgi(); return; }
            else if (k === "sistem") app.openExternal(o.path);
            else if (k === "drive") app.driveYukle(o.path);
            else if (k === "ad") { root.kapat(); app.renameItem(o.path); return; }
            else if (k === "kopya") app.copyItems([o.path], false);
            else if (k === "klasor") { root.kapat(); app.showFolder(fs.folderOf(o.path), o.path); return; }
            else if (k === "vars") { app.varsayilanSec("resim", function () { root.takeFocus(); }); return; }
            else if (k === "sil") { root.sil(); return; }
            root.takeFocus();
        });
    }

    Timer { id: slaytZaman; interval: 3000; repeat: true; running: root.slayt && root.visible; onTriggered: root.sonraki() }
    Timer { id: gizle; interval: 4000; running: root.cubuklar && root.visible && !sheet.shown; onTriggered: root.cubuklar = false }

    // ---- Resim ----
    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        interactive: root.olcek > 1
        contentWidth: Math.max(width, kap.width)
        contentHeight: Math.max(height, kap.height)
        boundsBehavior: Flickable.StopAtBounds

        Item {
            id: kap
            // dondurulmus resmin ekrana sigan boyutu * olcek
            property bool yan: root.aci === 90 || root.aci === 270
            property real rw: root.gw
            property real rh: root.gh
            property real sig: Math.min(flick.width / (yan ? rh : rw), flick.height / (yan ? rw : rh))
            width: (yan ? rh : rw) * sig * root.olcek
            height: (yan ? rw : rh) * sig * root.olcek
            x: Math.max(0, (flick.width - width) / 2)
            y: Math.max(0, (flick.height - height) / 2)

            Image {
                id: resim
                anchors.centerIn: parent
                width: kap.rw * kap.sig * root.olcek
                height: kap.rh * kap.sig * root.olcek
                rotation: root.aci
                source: root.yol === "" ? "" : "file:///" + root.yol
                sourceSize.width: 1280
                sourceSize.height: 1280
                asynchronous: true
                smooth: !flick.moving
                fillMode: Image.Stretch            // boyut zaten dogru oranda hesaplaniyor
            }
            PinchArea {
                anchors.fill: parent
                property real bas: 1
                onPinchStarted: bas = root.olcek
                onPinchUpdated: root.olcek = Math.max(1, Math.min(4, bas * pinch.scale))
            }
            // yakinken: tek dokunus cubuklar, cift dokunus geri sigdir (suruklemeyi Flickable alir)
            MouseArea {
                anchors.fill: parent
                enabled: root.olcek > 1
                onClicked: tekDokunus.restart()
                onDoubleClicked: { tekDokunus.stop(); root.olcek = 1; }
            }
        }
    }
    // Kaydirma ve dokunma (yakin degilken); yakinken Flickable gezdirir, burada yalniz dokunuslar
    MouseArea {
        anchors.fill: parent
        property real bx: 0
        property real by: 0
        property bool kaydi: false
        enabled: root.olcek <= 1
        onPressed: { bx = mouse.x; by = mouse.y; kaydi = false; }
        onPositionChanged: if (Math.abs(mouse.x - bx) > 30) kaydi = true
        onReleased: {
            var dx = mouse.x - bx, dy = mouse.y - by;
            if (kaydi && Math.abs(dx) > 60 && Math.abs(dx) > Math.abs(dy)) { if (dx < 0) root.sonraki(); else root.onceki(); }
        }
        onClicked: if (!kaydi) tekDokunus.restart()
        onDoubleClicked: { tekDokunus.stop(); root.olcek = 2; flick.contentX = (flick.contentWidth - flick.width) / 2; flick.contentY = (flick.contentHeight - flick.height) / 2; }
    }
    Timer { id: tekDokunus; interval: 280; onTriggered: root.cubuklar = !root.cubuklar }

    // komsu resimleri onbellege isit (kaydirinca aninda gelsin)
    Image { visible: false; asynchronous: true; sourceSize.width: 1280; sourceSize.height: 1280; source: root.resimler.length > 1 ? "file:///" + root.resimler[(root.sira + 1) % root.resimler.length].path : "" }
    Image { visible: false; asynchronous: true; sourceSize.width: 1280; sourceSize.height: 1280; source: root.resimler.length > 2 ? "file:///" + root.resimler[(root.sira - 1 + root.resimler.length) % root.resimler.length].path : "" }

    Text {
        anchors.centerIn: parent
        visible: resim.status !== Image.Ready
        text: resim.status === Image.Error ? qsTr("Bu fotoğraf açılamadı") : qsTr("Yükleniyor…")
        color: "#B0BEC5"
        font.pixelSize: 20
    }

    // ---- Ust cubuk ----
    Rectangle {
        id: ust
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 54
        color: "#CC000000"
        opacity: root.cubuklar ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        MouseArea { anchors.fill: parent }
        IconButton { id: geriBtn; anchors { left: parent.left; verticalCenter: parent.verticalCenter } icon: "back"; onClicked: root.kapat() }
        Column {
            anchors { left: geriBtn.right; leftMargin: 2; right: araclar.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
            Text { width: parent.width; text: root.resimler.length ? root.resimler[root.sira].name : ""; color: "#FFFFFF"; font.pixelSize: 18; font.bold: true; elide: Text.ElideMiddle }
            Text { width: parent.width; text: root.resimler.length ? (root.sira + 1) + " / " + root.resimler.length + (root.olcek > 1 ? "  •  " + Math.round(root.olcek * 100) + "%" : "") + (root.slayt ? qsTr("  •  slayt") : "") : ""; color: "#B0BEC5"; font.pixelSize: 14 }
        }
        Row {
            id: araclar
            anchors { right: parent.right; rightMargin: 2; verticalCenter: parent.verticalCenter }
            IconButton { icon: root.slayt ? "pause" : "play"; iconSize: 26; onClicked: root.slayt = !root.slayt }
            IconButton { icon: "redo"; iconSize: 26; onClicked: root.dondur() }
            IconButton { icon: "info"; iconSize: 26; onClicked: root.bilgi() }
            IconButton { icon: "trash"; iconSize: 26; onClicked: root.sil() }
            IconButton { icon: "more"; iconSize: 26; onClicked: root.menu() }
        }
    }

    // ---- Alt serit: kucuk resimler + onceki/sonraki ----
    Rectangle {
        id: alt
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 84
        color: "#CC000000"
        opacity: root.cubuklar && root.resimler.length > 1 ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        MouseArea { anchors.fill: parent }
        IconButton { id: oncekiBtn; anchors { left: parent.left; verticalCenter: parent.verticalCenter } icon: "prev"; iconSize: 26; onClicked: root.onceki() }
        IconButton { id: sonrakiBtn; anchors { right: parent.right; verticalCenter: parent.verticalCenter } icon: "next"; iconSize: 26; onClicked: root.sonraki() }
        ListView {
            id: serit
            anchors { left: oncekiBtn.right; right: sonrakiBtn.left; top: parent.top; bottom: parent.bottom; topMargin: 6; bottomMargin: 6 }
            orientation: ListView.Horizontal
            spacing: 4
            clip: true
            model: root.resimler.length
            currentIndex: root.sira
            highlightMoveDuration: 150
            delegate: Rectangle {
                width: 72; height: serit.height
                color: index === root.sira ? app.brand : "#222222"
                Image {
                    anchors { fill: parent; margins: index === root.sira ? 3 : 1 }
                    source: "file:///" + root.resimler[index].path
                    sourceSize.width: 96
                    sourceSize.height: 96
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    clip: true
                }
                MouseArea { anchors.fill: parent; onClicked: root.git(index) }
            }
        }
    }

    // ---- Klavye ----
    Item {
        id: odak
        focus: root.visible
        Keys.onPressed: {
            var k = event.key, t = U.tus(event);
            if (k === Qt.Key_Right) root.sonraki();
            else if (k === Qt.Key_Left) root.onceki();
            else if (k === Qt.Key_Up) root.yakinlastir(1.5);
            else if (k === Qt.Key_Down) root.yakinlastir(1 / 1.5);
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) root.cubuklar = !root.cubuklar;
            else if (k === Qt.Key_Space) root.slayt = !root.slayt;
            else if (k === Qt.Key_Home) root.git(0);
            else if (k === Qt.Key_End) root.git(root.resimler.length - 1);
            else if (k === Qt.Key_Menu || k === Qt.Key_Context1) root.menu();
            else if (k === Qt.Key_Backspace || k === Qt.Key_Escape || k === Qt.Key_Context2 || k === Qt.Key_Back) root.kapat();
            else if (t === "r") root.dondur();
            else if (t === "i") root.bilgi();
            else if (t === "d") root.sil();
            else return;
            event.accepted = true;
        }
    }
}
