import QtQuick 1.1
import "Util.js" as U

// Internetten kitap bul ve indir:
//  Gutenberg (gutenberg.org OPDS katalogu): 70 binden fazla telifsiz kitap, EPUB, bircok dil
//  Vikikaynak (tr.wikisource.org): Turkce eserler, metin olarak (alt sayfali eserlerin bolumleri birlestirilir)
Rectangle {
    id: root
    color: app.bg
    property string kaynak: "gutenberg"     // gutenberg | vikikaynak
    property string arama: ""
    property string dil: ""                 // gutenberg dil suzgeci ("" tum diller)
    property string sonraki: ""             // gutendex sonraki sayfa adresi
    property bool yukleniyor: false
    property string hata: ""
    property int yuzde: -1
    property string indirilen: ""
    property bool indirinceAc: false
    // vikikaynak birlestirme
    property string vkBaslik: ""
    property variant vkSayfalar: []
    property int vkSira: 0
    property string vkMetin: ""

    function ozet() { return "kaynak=" + kaynak + " sonuc=" + sm.count + (sm.count ? " ilk='" + sm.get(0).baslik + "'" : "") + " hata='" + hata + "' indiriyor=" + (kt.indiriyor || vkBaslik !== ""); }
    function testAra(k, q) { kaynak = k; alan.text = q; ara(); }
    function testIndir() { if (sm.count) indir(sm.get(0), false); }
    function ac() { visible = true; if (sm.count === 0) listele(); alan.focusInput(); }
    function kapat() { visible = false; alan.input.closeSoftwareInputPanel(); app.focusCurrent(); }
    function takeFocus() { liste.forceActiveFocus(); }
    function kaynakSec(k) { kaynak = k; sm.clear(); hata = ""; sonraki = ""; listele(); }
    function ara() { arama = alan.text.replace(/^\s+|\s+$/g, ""); sm.clear(); sonraki = ""; listele(); liste.forceActiveFocus(); }
    function listele() {
        hata = "";
        yukleniyor = true;
        if (kaynak === "gutenberg") {
            // Gutenberg'in kendi OPDS katalogu (gutendex sik sik 503/zaman asimi veriyor)
            var sorgu = (arama + (dil !== "" ? " l." + dil : "")).replace(/^\s+/, "");
            var u = sonraki !== "" ? sonraki : "https://www.gutenberg.org/ebooks/search.opds/?sort_order=downloads" + (sorgu !== "" ? "&query=" + encodeURIComponent(sorgu) : "");
            kt.getir("gut", u);
        } else {
            if (arama === "") { yukleniyor = false; hata = qsTr("Vikikaynak'ta aramak için yazar ya da eser adı yazın (ör. Ömer Seyfettin, Kaşağı, Nutuk)."); return; }
            kt.getir("vka", "https://tr.wikisource.org/w/api.php?action=query&list=search&srnamespace=0&srlimit=40&format=json&srsearch=" + encodeURIComponent(arama));
        }
    }
    function xmlCoz(s) { return ("" + s).replace(/&quot;/g, "\"").replace(/&apos;/g, "'").replace(/&#39;/g, "'").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&"); }
    function htmlSil(s) { return ("" + s).replace(/<[^>]*>/g, "").replace(/&quot;/g, "\"").replace(/&amp;/g, "&").replace(/&#039;/g, "'"); }
    function dosyaYolu(o) { return kt.kitapKlasoru() + "/" + kt.guvenliAd(o.baslik + (o.yazar ? " - " + o.yazar : "")) + (kaynak === "gutenberg" ? ".epub" : ".txt"); }
    function sec(i) {
        if (i < 0 || i >= sm.count) return;
        var o = sm.get(i);
        if (o.dahaFazla) { listele(); return; }
        var yol = dosyaYolu(o), var_ = kt.dosyaVar(yol), items = [];
        if (var_) items.push({ label: qsTr("Aç (indirilmiş)"), icon: "doc", key: "ac" });
        items.push({ label: var_ ? qsTr("Yeniden indir") : qsTr("İndir ve aç"), icon: "yukle", key: "indirac" });
        if (!var_) items.push({ label: qsTr("Yalnızca indir"), icon: "yukle", key: "indir" });
        items.push({ label: o.alt, icon: "info", key: "x" });
        sheet.open(o.baslik, items, function (k) {
            if (k === "ac") { root.kapat(); app.kitapAc(yol); }
            else if (k === "indirac" || k === "indir") root.indir(o, k === "indirac");
        });
    }
    function indir(o, acilsin) {
        if (kt.indiriyor || vkBaslik !== "") { app.showToast(qsTr("Başka bir indirme sürüyor")); return; }
        indirinceAc = acilsin;
        indirilen = o.baslik;
        var yol = dosyaYolu(o);
        if (kaynak === "gutenberg") {
            yuzde = 0;
            if (!kt.indir(o.adres, yol)) app.showToast(qsTr("İndirme başlatılamadı"));
        } else {
            // once ana sayfa, sonra alt sayfalar (Eser/Bolum)
            vkBaslik = o.baslik;
            vkMetin = "";
            vkSayfalar = [o.baslik];
            vkSira = 0;
            yuzde = 0;
            kt.getir("vkalt", "https://tr.wikisource.org/w/api.php?action=query&list=allpages&apnamespace=0&aplimit=100&format=json&apprefix=" + encodeURIComponent(o.baslik + "/"));
        }
    }
    function vkSonraki() {
        if (vkSira >= vkSayfalar.length) {
            var yol = kt.kitapKlasoru() + "/" + kt.guvenliAd(vkBaslik) + ".txt";
            var b = vkBaslik;
            vkBaslik = "";
            yuzde = -1;
            if (vkMetin.replace(/\s+/g, "").length < 50) { app.showToast(qsTr("Eserde metin bulunamadı")); return; }
            if (!kt.metinKaydet(yol, b + "\n\n" + vkMetin)) { app.showToast(qsTr("Kaydedilemedi")); return; }
            root.bitti(yol);
            return;
        }
        yuzde = Math.round(vkSira * 100 / vkSayfalar.length);
        kt.getir("vkmetin", "https://tr.wikisource.org/w/api.php?action=query&prop=extracts&explaintext=1&format=json&titles=" + encodeURIComponent(vkSayfalar[vkSira]));
    }
    function bitti(yol) {
        kt.kitapEkle(yol);
        app.showToast(qsTr("İndirildi: ") + indirilen);
        if (indirinceAc) { root.kapat(); app.kitapAc(yol); }
    }

    Connections {
        target: kt
        onMetinGeldi: {
            if (id === "gut" || id === "vka") {
                root.yukleniyor = false;
                if (hata !== "") { root.hata = qsTr("Alınamadı: ") + hata; return; }
                var j = null;
                if (id === "vka") { try { j = JSON.parse(govde); } catch (e) { root.hata = qsTr("Geçersiz yanıt"); return; } }
                if (sm.count && sm.get(sm.count - 1).dahaFazla) sm.remove(sm.count - 1);
                if (id === "gut") {
                    var g = ("" + govde).split("<entry>");
                    for (var i = 1; i < g.length; i++) {
                        var no = /\/ebooks\/(\d+)\.opds/.exec(g[i]);
                        if (!no) continue;                               // "Subjects/Authors" gibi alt katalog girdileri
                        var tb = /<title>([^<]*)<\/title>/.exec(g[i]);
                        var yb = /<content[^>]*>([^<]*)<\/content>/.exec(g[i]);
                        var bs = tb ? root.xmlCoz(tb[1]) : "#" + no[1];
                        var yz = yb ? root.xmlCoz(yb[1]) : "";
                        if (/^\d+ (downloads|books)/.test(yz)) yz = "";
                        sm.append({ baslik: bs, yazar: yz, alt: (yz !== "" ? yz + "  •  " : "") + "Gutenberg #" + no[1], adres: "https://www.gutenberg.org/ebooks/" + no[1] + ".epub3.images", dahaFazla: false });
                    }
                    var nx = /<link[^>]*rel="next"[^>]*href="([^"]*)"/.exec(govde) || /<link[^>]*href="([^"]*)"[^>]*rel="next"/.exec(govde);
                    root.sonraki = nx ? "https://www.gutenberg.org" + root.xmlCoz(nx[1]) : "";
                    if (root.sonraki !== "") sm.append({ baslik: qsTr("Daha fazla…"), yazar: "", alt: "", adres: "", dahaFazla: true });
                } else {
                    var s = j.query && j.query.search ? j.query.search : [];
                    for (var k = 0; k < s.length; k++) {
                        if (s[k].title.indexOf("/") >= 0) continue;          // alt sayfalar ana eserle iner
                        sm.append({ baslik: s[k].title, yazar: "", alt: root.htmlSil(s[k].snippet).substring(0, 90) + "  •  " + Math.round(s[k].size / 1024) + " KB", adres: "", dahaFazla: false });
                    }
                }
                if (!sm.count) root.hata = qsTr("Sonuç yok");
                if (liste.currentIndex < 0) liste.currentIndex = 0;
            } else if (id === "vkalt") {
                if (hata === "") {
                    try {
                        var ap = JSON.parse(govde).query.allpages || [], l = [root.vkBaslik];
                        for (var a = 0; a < ap.length && l.length < 80; a++) l.push(ap[a].title);
                        root.vkSayfalar = l;
                    } catch (e2) { }
                }
                root.vkSonraki();
            } else if (id === "vkmetin") {
                if (hata === "") {
                    try {
                        var pg = JSON.parse(govde).query.pages;
                        for (var p in pg) {
                            var t = (pg[p].extract || "").replace(/^\s+|\s+$/g, "");
                            if (t !== "") root.vkMetin += (root.vkSira > 0 ? "\n\n" + pg[p].title.split("/").pop() + "\n\n" : "") + t;
                        }
                    } catch (e3) { }
                }
                root.vkSira = root.vkSira + 1;
                root.vkSonraki();
            }
        }
        onIndirmeIlerleme: root.yuzde = toplam > 0 ? Math.round(alinan * 100 / toplam) : 0
        onIndirmeBitti: {
            root.yuzde = -1;
            if (ok) root.bitti(yol); else app.showToast(qsTr("İndirilemedi: ") + hata);
        }
    }

    MouseArea { anchors.fill: parent }
    ListModel { id: sm }
    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        showBack: true
        onBack: root.kapat()
        title: qsTr("Kitap bul")
        subtitle: root.yuzde >= 0 ? "↓ " + root.yuzde + "%  " + root.indirilen : (root.kaynak === "gutenberg" ? qsTr("Gutenberg · EPUB · telifsiz") : qsTr("Vikikaynak · Türkçe · metin"))
        busy: root.yukleniyor || root.yuzde >= 0
        IconButton { visible: kt.indiriyor; icon: "close"; tone: "w"; iconSize: 22; onClicked: kt.indirmeIptal() }
    }
    Row {
        id: haplar
        anchors { left: parent.left; leftMargin: 10; top: header.bottom; topMargin: 6 }
        spacing: 8
        Hap { yazi: qsTr("Gutenberg (dünya, EPUB)"); secili: root.kaynak === "gutenberg"; onTiklandi: root.kaynakSec("gutenberg") }
        Hap { yazi: qsTr("Vikikaynak (Türkçe)"); secili: root.kaynak === "vikikaynak"; onTiklandi: root.kaynakSec("vikikaynak") }
        Hap {
            visible: root.kaynak === "gutenberg"
            yazi: qsTr("Dil: ") + (root.dil === "" ? qsTr("tümü") : root.dil)
            onTiklandi: {
                var l = [["", qsTr("Tüm diller")], ["en", "English"], ["de", "Deutsch"], ["fr", "Français"], ["es", "Español"], ["it", "Italiano"], ["pt", "Português"], ["nl", "Nederlands"], ["fi", "Suomi"], ["ru", "Русский"], ["la", "Latina"], ["el", "Ελληνικά"]], it = [];
                for (var i = 0; i < l.length; i++) it.push({ label: (l[i][0] === root.dil ? "● " : "") + l[i][1], icon: "globe", key: "d" + l[i][0] });
                sheet.open(qsTr("Kitap dili"), it, function (k) { root.dil = k.substring(1); sm.clear(); root.sonraki = ""; root.listele(); });
            }
        }
    }
    Row {
        id: aramaSatiri
        anchors { left: parent.left; right: parent.right; top: haplar.bottom; margins: 8 }
        spacing: 8
        TextField {
            id: alan
            width: aramaSatiri.width - araBtn.width - 8
            placeholder: root.kaynak === "gutenberg" ? qsTr("Kitap ya da yazar (boş: en popüler)") : qsTr("Eser ya da yazar (ör. Ömer Seyfettin)")
            onAccepted: root.ara()
            onTabbed: liste.forceActiveFocus()
        }
        Rectangle {
            id: araBtn
            width: 90; height: 44; radius: 22
            color: ama.pressed ? app.brandPressed : app.brand
            Text { anchors.centerIn: parent; text: qsTr("Ara"); color: "#101418"; font.pixelSize: 17; font.bold: true }
            MouseArea { id: ama; anchors.fill: parent; onClicked: root.ara() }
        }
    }
    ListView {
        id: liste
        anchors { left: parent.left; right: parent.right; top: aramaSatiri.bottom; topMargin: 6; bottom: parent.bottom }
        clip: true
        model: sm
        highlightMoveDuration: 80
        delegate: Satir {
            width: liste.width
            baslik: model.baslik
            alt: model.alt
            simge: model.dahaFazla ? "plus" : (kt.dosyaVar(root.dosyaYolu(model)) ? "check" : "doc")
            secili: ListView.isCurrentItem && liste.activeFocus
            onTiklandi: { liste.currentIndex = index; root.sec(index); }
            onBasiliTutuldu: { liste.currentIndex = index; root.sec(index); }
            onMenu: { liste.currentIndex = index; root.sec(index); }
        }
        Keys.onPressed: {
            var k = event.key;
            if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) root.sec(currentIndex);
            else if (k === Qt.Key_Escape || k === Qt.Key_Backspace || k === Qt.Key_Context2) root.kapat();
            else if (U.printable(event) && !U.ctrl(event)) { alan.focusInput(); alan.text += event.text; }
            else return;
            event.accepted = true;
        }
    }
    Text {
        anchors.centerIn: liste
        width: liste.width - 40
        visible: sm.count === 0
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: root.yukleniyor ? qsTr("Aranıyor…") : root.hata
        color: app.textSecondary
        font.pixelSize: Math.round(16 * app.yazi)
    }
}
