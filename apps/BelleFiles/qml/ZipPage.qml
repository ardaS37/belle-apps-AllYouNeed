import QtQuick 1.1
import "Util.js" as U

// Zip arsivinin icini gezme: klasorlere gir, dosyayi ac (gecici klasore cikarip), tumunu / secileni cikar.
// Klavye: Enter ac, Bosluk/Menu secenekler, Geri ust klasor / kapat, A tumunu cikar.
Rectangle {
    id: root
    anchors.fill: parent
    color: app.bg
    visible: false
    z: 15
    property bool shown: visible
    property string arsiv: ""
    property string onek: ""          // arsiv icindeki gecerli klasor ("a/b/")
    property variant tum: []
    property double toplamBoyut: 0

    function ac(p) {
        var l = isci.zipListe(p);
        if (!l.length) { app.showToast(isci.hata() !== "" ? isci.hata() : qsTr("Arşiv boş")); return; }
        arsiv = p; tum = l; onek = "";
        var t = 0;
        for (var i = 0; i < l.length; i++) t += l[i].boyut;
        toplamBoyut = t;
        doldur("");
        visible = true;
        list.forceActiveFocus();
    }
    function kapat() { visible = false; app.focusCurrent(); }
    function takeFocus() { list.forceActiveFocus(); }
    function doldur(secilecek) {
        zm.clear();
        var gorulen = {}, dirs = [], files = [], l = tum;
        for (var i = 0; i < l.length; i++) {
            var e = l[i];
            if (e.ad.indexOf(onek) !== 0) continue;
            var rest = e.ad.substring(onek.length);
            if (rest === "") continue;
            var k = rest.indexOf("/");
            if (k >= 0) {
                var ad = rest.substring(0, k);
                if (gorulen[ad]) continue;
                gorulen[ad] = true;
                dirs.push({ ad: ad, yol: onek + ad + "/", klasor: true, boyut: 0, zaman: e.zaman, ext: "", sifreli: false });
            } else {
                var nokta = rest.lastIndexOf(".");
                files.push({ ad: rest, yol: e.ad, klasor: false, boyut: e.boyut, zaman: e.zaman, ext: nokta > 0 ? rest.substring(nokta + 1).toLowerCase() : "", sifreli: e.sifreli });
            }
        }
        var cmp = function (a, b) { return a.ad.toLowerCase() < b.ad.toLowerCase() ? -1 : 1; };
        dirs.sort(cmp); files.sort(cmp);
        var sec = 0, all = dirs.concat(files);
        for (var j = 0; j < all.length; j++) { zm.append(all[j]); if (all[j].yol === secilecek) sec = j; }
        list.currentIndex = sec;
    }
    function yukari() {
        if (onek === "") { kapat(); return; }
        var eski = onek;
        var s = onek.substring(0, onek.length - 1);
        var k = s.lastIndexOf("/");
        onek = k < 0 ? "" : s.substring(0, k + 1);
        doldur(eski);
    }
    function girOge(i) {
        if (i < 0 || i >= zm.count) return;
        var o = zm.get(i);
        if (o.klasor) { onek = o.yol; doldur(""); return; }
        var gecici = fs.dataDir() + "/zipgecici";
        fs.removePath(gecici);
        app.zipAc(arsiv, gecici, [o.yol], qsTr("Açılıyor: ") + o.ad, function (ok, sonuc) { if (ok) app.akilliAc(sonuc); });
    }
    function cikar(yollar, hedef) {
        app.zipAc(arsiv, hedef, yollar, qsTr("Çıkarılıyor → ") + fs.fileName(hedef), function (ok, sonuc) {
            if (ok) { root.kapat(); app.showFolder(hedef, ""); }
        });
    }
    function menu() {
        var i = list.currentIndex, o = i >= 0 && i < zm.count ? zm.get(i) : null;
        var items = [];
        if (o) items.push({ label: o.klasor ? qsTr("Klasöre gir") : qsTr("Aç"), icon: o.klasor ? "folder" : "eye", key: "ac", hint: qsTr("Enter") });
        items.push({ label: qsTr("Tümünü çıkar → ") + fs.baseName(arsiv) + qsTr(" klasörüne"), icon: "zip", key: "tum", hint: "A" });
        if (o) items.push({ label: qsTr("Bunu çıkar: ") + o.ad, icon: "zip", key: "bu" });
        items.push({ label: qsTr("Başka klasöre çıkar…"), icon: "folder", key: "baska" });
        items.push({ label: qsTr("Kapat"), icon: "close", key: "kapat" });
        sheet.open(fs.fileName(arsiv) + (onek ? " / " + onek : ""), items, function (k) {
            if (k === "ac") root.girOge(i);
            else if (k === "tum") root.cikar([], isci.benzersiz(fs.folderOf(arsiv), fs.baseName(arsiv)));
            else if (k === "bu") root.cikar([o.yol], fs.folderOf(arsiv));
            else if (k === "baska") {
                input.open({ title: qsTr("Hedef klasör"), label1: qsTr("Kart için E:/..., telefon için C:/Data/..."), text1: fs.folderOf(arsiv) + "/" + fs.baseName(arsiv), ok: qsTr("Çıkar") }, function (d) {
                    d = d.replace(/^\s+|\s+$/g, "");
                    if (d === "") return;
                    root.cikar([], d);
                });
            }
            else if (k === "kapat") root.kapat();
        });
    }

    ListModel { id: zm }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        showBack: true
        title: fs.fileName(root.arsiv)
        subtitle: (root.onek ? "/" + root.onek + "  •  " : "") + root.tum.length + qsTr(" öğe  •  ") + U.sizeText(root.toplamBoyut) + qsTr(" açılmış")
        onBack: root.yukari()
        IconButton { icon: "zip"; tone: "a"; iconSize: 26; onClicked: root.cikar([], isci.benzersiz(fs.folderOf(root.arsiv), fs.baseName(root.arsiv))) }
        IconButton { icon: "more"; tone: "w"; iconSize: 24; onClicked: root.menu() }
    }
    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        clip: true
        model: zm
        focus: true
        highlightMoveDuration: 100
        delegate: FileRow {
            width: list.width
            icon: U.iconFor(ext, klasor)
            title: ad
            sub: klasor ? qsTr("klasör") : U.sizeText(boyut) + (zaman ? "  •  " + U.dateText(zaman) : "") + (sifreli ? qsTr("  •  şifreli") : "")
            selected: ListView.isCurrentItem && list.activeFocus
            onClicked: { list.currentIndex = index; root.girOge(index); }
            onPressAndHold: { list.currentIndex = index; root.menu(); }
            onAction: { list.currentIndex = index; root.menu(); }
        }
        Keys.onPressed: {
            var k = event.key, t = U.tus(event);
            if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) { root.girOge(currentIndex); event.accepted = true; }
            else if (k === Qt.Key_Backspace || k === Qt.Key_Escape || k === Qt.Key_Context2 || k === Qt.Key_Left) { root.yukari(); event.accepted = true; }
            else if (k === Qt.Key_Space || k === Qt.Key_Menu || k === Qt.Key_Context1) { root.menu(); event.accepted = true; }
            else if (t === "a") { root.cikar([], isci.benzersiz(fs.folderOf(root.arsiv), fs.baseName(root.arsiv))); event.accepted = true; }
            else if (U.printable(event)) event.accepted = true;
        }
    }
}
