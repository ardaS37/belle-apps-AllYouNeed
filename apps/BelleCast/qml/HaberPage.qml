import QtQuick 1.1
import "Util.js" as U
import "Durum.js" as D

// Haberler (RSS/Atom): kaynaklardan birlesik akis, kaynaga gore suzme, okunmamis isareti, onbellek.
// Klavye: Enter ac, Bosluk menu, Y yenile, K kaynaklar, A tumunu okundu say, Sol/Sag sekme.
Rectangle {
    id: root
    color: app.bg
    property string suzgec: ""              // "" = tumu, yoksa kaynak adresi
    property bool yukleniyor: false
    property bool ilkOldu: false
    property double sonYenileme: 0
    property variant kaynaklar: []          // [{url, ad, acik}]

    function takeFocus() { liste.forceActiveFocus(); }
    function hazirla() {
        if (parseInt(app.sorgu("SELECT COUNT(*) AS n FROM kaynak")[0].n, 10) === 0) varsayilanKaynaklar();
        kaynaklariOku();
    }
    function varsayilanKaynaklar() {
        var l = [
            ["BBC Türkçe", "https://feeds.bbci.co.uk/turkce/rss.xml", 1],
            ["TRT Haber", "https://www.trthaber.com/sondakika.rss", 1],
            ["Anadolu Ajansı", "https://www.aa.com.tr/tr/rss/default?cat=guncel", 1],
            ["DW Türkçe", "https://rss.dw.com/rdf/rss-tur-all", 1],
            ["Euronews Türkçe", "https://tr.euronews.com/rss", 1],
            ["NTV", "https://www.ntv.com.tr/gundem.rss", 1],
            ["Hürriyet", "https://www.hurriyet.com.tr/rss/anasayfa", 0],
            ["Habertürk", "https://www.haberturk.com/rss", 0],
            ["Milliyet", "https://www.milliyet.com.tr/rss/rssnew/gundemrss.xml", 0],
            ["Sözcü", "https://www.sozcu.com.tr/feeds-son-dakika", 1],
            ["Cumhuriyet", "https://www.cumhuriyet.com.tr/rss/son_dakika.xml", 1],
            ["Webrazzi", "https://webrazzi.com/feed/", 1],
            ["ShiftDelete", "https://shiftdelete.net/feed", 1],
            ["DonanımHaber", "https://www.donanimhaber.com/rss/tum/", 0],
            ["BBC News World", "https://feeds.bbci.co.uk/news/world/rss.xml", 0]
        ];
        app.db().transaction(function (tx) {
            tx.executeSql("DELETE FROM kaynak");
            for (var i = 0; i < l.length; i++) tx.executeSql("INSERT INTO kaynak(url, ad, acik, sira) VALUES(?, ?, ?, ?)", [l[i][1], l[i][0], l[i][2], i]);
        });
    }
    function kaynaklariOku() {
        var l = app.sorgu("SELECT * FROM kaynak ORDER BY sira, ad"), k = [];
        for (var i = 0; i < l.length; i++) k.push({ url: l[i].url, ad: l[i].ad, acik: Number(l[i].acik) === 1 });
        kaynaklar = k;
    }
    function kaynakAdi(url) { var k = kaynaklar; for (var i = 0; i < k.length; i++) if (k[i].url === url) return k[i].ad; return url; }
    function ilkAcilis() {
        if (ilkOldu) { if (new Date().getTime() - sonYenileme > 15 * 60000) yenile(); return; }
        ilkOldu = true;
        // onbellekteki son liste hemen gorunsun, sonra tazele
        var on = yayin.metinOku("haberler.json");
        if (on !== "") { try { D.haberHam = JSON.parse(on); doldur(); } catch (e) { } }
        yenile();
    }
    function yenile() {
        var k = kaynaklar, n = 0;
        D.haberYeni = [];
        for (var i = 0; i < k.length; i++) if (k[i].acik) { yayin.akisCek("haber:" + k[i].url, k[i].url); n++; }
        D.haberBekleyen = n;
        yukleniyor = n > 0;
        sonYenileme = new Date().getTime();
        if (!n) app.showToast(qsTr("Açık kaynak yok (K: kaynaklar)"));
    }
    function okunduMu(link) { return app.sorgu("SELECT 1 FROM okundu WHERE link = ?", [link]).length > 0; }
    function doldur() {
        var l = D.haberHam, keep = liste.currentIndex >= 0 && liste.currentIndex < hModel.count ? hModel.get(liste.currentIndex).link : "";
        var ok = {};
        app.db().readTransaction(function (tx) { var rs = tx.executeSql("SELECT link FROM okundu"); for (var i = 0; i < rs.rows.length; i++) ok[rs.rows.item(i).link] = true; });
        hModel.clear();
        var sec = 0;
        for (var i = 0; i < l.length; i++) {
            if (suzgec !== "" && l[i].kaynakUrl !== suzgec) continue;
            hModel.append({ baslik: l[i].baslik || "", link: l[i].link || "", zaman: l[i].zaman || 0, ozet: l[i].ozet || "", resim: l[i].resim || "",
                           kaynak: l[i].kaynak || "", kaynakUrl: l[i].kaynakUrl || "", okundu: !!ok[l[i].link] });
            if (l[i].link === keep) sec = hModel.count - 1;
        }
        liste.currentIndex = hModel.count ? sec : -1;
    }
    function okunduIsaretle(i) {
        if (i < 0 || i >= hModel.count) return;
        var o = hModel.get(i);
        if (o.okundu) return;
        hModel.setProperty(i, "okundu", true);
        app.yurut("INSERT OR REPLACE INTO okundu(link, t) VALUES(?, ?)", [o.link, new Date().getTime()]);
    }
    function tumunuOkundu() {
        app.db().transaction(function (tx) {
            for (var i = 0; i < hModel.count; i++) if (!hModel.get(i).okundu) tx.executeSql("INSERT OR REPLACE INTO okundu(link, t) VALUES(?, ?)", [hModel.get(i).link, new Date().getTime()]);
            tx.executeSql("DELETE FROM okundu WHERE t < ?", [new Date().getTime() - 30 * 24 * 3600000]);   // 30 gunden eski kayitlar
        });
        for (var j = 0; j < hModel.count; j++) hModel.setProperty(j, "okundu", true);
    }
    function ac(i) {
        if (i < 0 || i >= hModel.count) return;
        okunduIsaretle(i);
        makale.haberAc(root, i);
    }
    function oge(i) { return i >= 0 && i < hModel.count ? hModel.get(i) : null; }
    function adet() { return hModel.count; }
    function suz(url) { suzgec = url; doldur(); liste.positionViewAtIndex(0, ListView.Beginning); liste.currentIndex = 0; }
    function menu(i) {
        if (i < 0 || i >= hModel.count) { genelMenu(); return; }
        var o = hModel.get(i);
        sheet.open(o.baslik, [
            { label: qsTr("Oku"), icon: "doc", key: "ac", hint: qsTr("Enter") },
            { label: qsTr("Tarayıcıda aç"), icon: "globe", key: "web", hint: "O" },
            { label: o.okundu ? qsTr("Okunmadı say") : qsTr("Okundu say"), icon: "check", key: "okundu", hint: "M" },
            { label: qsTr("Yalnız bu kaynak: ") + o.kaynak, icon: "search", key: "suz" }
        ], function (k) {
            if (k === "ac") root.ac(i);
            else if (k === "web") yayin.disaridaAc(o.link);
            else if (k === "okundu") { if (o.okundu) { app.yurut("DELETE FROM okundu WHERE link = ?", [o.link]); hModel.setProperty(i, "okundu", false); } else root.okunduIsaretle(i); }
            else if (k === "suz") root.suz(o.kaynakUrl);
        });
    }
    function kaynakMenu() {
        var k = kaynaklar, items = [];
        for (var i = 0; i < k.length; i++) items.push({ label: (k[i].acik ? "● " : "○ ") + k[i].ad, icon: k[i].acik ? "check" : "close", key: "k" + i });
        items.push({ label: qsTr("RSS adresiyle kaynak ekle"), icon: "plus", key: "ekle" });
        items.push({ label: qsTr("Varsayılan kaynaklara dön"), icon: "undo", key: "varsayilan" });
        sheet.open(qsTr("Kaynaklar (dokunarak aç/kapat)"), items, function (v) {
            if (v === "ekle") { root.kaynakEkle(); return; }
            if (v === "varsayilan") { root.varsayilanKaynaklar(); root.kaynaklariOku(); root.yenile(); return; }
            var o = root.kaynaklar[parseInt(v.substring(1), 10)];
            sheet.open(o.ad, [
                { label: o.acik ? qsTr("Kapat (akışta gösterme)") : qsTr("Aç (akışta göster)"), icon: o.acik ? "close" : "check", key: "ac" },
                { label: qsTr("Yalnız bunun haberleri"), icon: "search", key: "suz" },
                { label: qsTr("Yeniden adlandır"), icon: "edit", key: "ad" },
                { label: qsTr("Sil"), icon: "trash", key: "sil", danger: true }
            ], function (k2) {
                if (k2 === "ac") { app.yurut("UPDATE kaynak SET acik = ? WHERE url = ?", [o.acik ? 0 : 1, o.url]); root.kaynaklariOku(); root.kaynakMenu(); if (!o.acik) root.yenile(); }
                else if (k2 === "suz") root.suz(o.url);
                else if (k2 === "ad") input.open({ title: qsTr("Yeniden adlandır"), label1: "", text1: o.ad, ok: qsTr("Kaydet") }, function (y) { if (y.replace(/\s+/g, "") === "") return; app.yurut("UPDATE kaynak SET ad = ? WHERE url = ?", [y, o.url]); root.kaynaklariOku(); });
                else if (k2 === "sil") { app.yurut("DELETE FROM kaynak WHERE url = ?", [o.url]); root.kaynaklariOku(); }
            });
        });
    }
    function kaynakEkle() {
        input.open({ title: qsTr("Haber kaynağı ekle"), label1: qsTr("RSS / Atom adresi"), text1: "https://", label2: qsTr("Ad (boş: beslemeden)"), text2: "", ok: qsTr("Ekle") }, function (u, ad) {
            u = u.replace(/^\s+|\s+$/g, "");
            if (u.length < 12) { app.showToast(qsTr("Geçersiz adres")); return; }
            root.ekleAd = ad.replace(/^\s+|\s+$/g, "");
            yayin.akisCek("kaynakdene:" + u, u);
            app.showToast(qsTr("Besleme deneniyor…"));
        });
    }
    property string ekleAd: ""
    function genelMenu() {
        sheet.open(qsTr("Haberler"), [
            { label: qsTr("Yenile"), icon: "senkron", key: "yenile", hint: "Y" },
            { label: qsTr("Kaynaklar…"), icon: "doc", key: "kaynak", hint: "K" },
            { label: qsTr("Tümünü okundu say"), icon: "check", key: "okundu", hint: "A" },
            { label: root.suzgec !== "" ? qsTr("Tüm kaynakları göster") : qsTr("Kaynağa göre süz…"), icon: "search", key: "suz" }
        ], function (k) {
            if (k === "yenile") root.yenile(); else if (k === "kaynak") root.kaynakMenu(); else if (k === "okundu") root.tumunuOkundu();
            else if (k === "suz") {
                if (root.suzgec !== "") { root.suz(""); return; }
                var it = [], kk = root.kaynaklar;
                for (var i = 0; i < kk.length; i++) if (kk[i].acik) it.push({ label: kk[i].ad, icon: "doc", key: kk[i].url });
                sheet.open(qsTr("Kaynak seç"), it, function (u) { root.suz(u); });
            }
        });
    }

    Connections {
        target: yayin
        onAkisHazir: {
            if (istekId.indexOf("kaynakdene:") === 0) {
                var u = istekId.substring(11);
                if (hata !== "" || !ogeler.length) { app.showToast(qsTr("Besleme okunamadı: ") + (hata || qsTr("haber yok"))); return; }
                var ad = root.ekleAd !== "" ? root.ekleAd : (kanal.baslik || u);
                var n = parseFloat(app.sorgu("SELECT MAX(sira) AS m FROM kaynak")[0].m) || 0;
                app.yurut("INSERT OR REPLACE INTO kaynak(url, ad, acik, sira) VALUES(?, ?, 1, ?)", [u, ad, n + 1]);
                root.kaynaklariOku();
                app.showToast(qsTr("Kaynak eklendi: ") + ad + " (" + ogeler.length + qsTr(" haber)"));
                root.yenile();
                return;
            }
            if (istekId.indexOf("haber:") !== 0) return;
            var url = istekId.substring(6), adi = root.kaynakAdi(url);
            yayin.kayit("haber " + adi + ": " + (hata !== "" ? "hata " + hata : ogeler.length + " oge") + ", kalan " + (D.haberBekleyen - 1));
            var yeni = D.haberYeni;
            for (var i = 0; i < ogeler.length && i < 60; i++) {
                var o = ogeler[i];
                if (!o.baslik || !o.link) continue;
                yeni.push({ baslik: o.baslik, link: o.link, zaman: o.zaman || 0, ozet: (o.ozet || "").substring(0, 1500), resim: o.resim || "", kaynak: adi, kaynakUrl: url });
            }
            D.haberYeni = yeni;
            D.haberBekleyen = D.haberBekleyen - 1;
            // her kaynak geldikce goster (en yeni once)
            var l = D.haberYeni.slice(0);
            l.sort(function (a, b) { return b.zaman - a.zaman; });
            if (l.length > 400) l = l.slice(0, 400);
            D.haberHam = l;
            root.doldur();
            if (D.haberBekleyen <= 0) {
                root.yukleniyor = false;
                yayin.metinYaz("haberler.json", JSON.stringify(l));
            }
        }
    }

    ListModel { id: hModel }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: root.suzgec === "" ? qsTr("Haberler") : root.kaynakAdi(root.suzgec)
        subtitle: hModel.count + qsTr(" haber") + (root.yukleniyor ? qsTr("  •  yenileniyor…") : (root.sonYenileme ? "  •  " + Qt.formatDateTime(new Date(root.sonYenileme), "hh:mm") : ""))
        showBack: root.suzgec !== ""
        onBack: root.suz("")
        busy: root.yukleniyor
        IconButton { icon: "senkron"; tone: "w"; iconSize: 26; onClicked: root.yenile() }
        IconButton { icon: "more"; tone: "w"; iconSize: 24; onClicked: root.genelMenu() }
    }
    Flickable {
        id: hapSerit
        anchors { left: parent.left; right: parent.right; top: header.bottom }
        height: 44
        contentWidth: haplar.width + 20
        clip: true
        Row {
            id: haplar
            x: 10; anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Hap { yazi: qsTr("Tümü"); secili: root.suzgec === ""; onTiklandi: root.suz("") }
            Repeater {
                model: root.kaynaklar
                delegate: Hap { visible: modelData.acik; yazi: modelData.ad; secili: root.suzgec === modelData.url; onTiklandi: root.suz(modelData.url) }
            }
            Hap { yazi: qsTr("Kaynaklar…"); onTiklandi: root.kaynakMenu() }
        }
    }
    ListView {
        id: liste
        anchors { left: parent.left; right: parent.right; top: hapSerit.bottom; bottom: parent.bottom }
        clip: true
        model: hModel
        highlightMoveDuration: 100
        delegate: Item {
            id: hs
            width: liste.width
            height: Math.max(64, kol.height + 18)
            property bool sec: ListView.isCurrentItem && liste.activeFocus
            Rectangle { anchors.fill: parent; color: hma.pressed ? app.pressed : (hs.sec ? app.highlight : "transparent") }
            Rectangle { visible: hs.sec; anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 4; color: app.brand }
            Column {
                id: kol
                anchors { left: parent.left; leftMargin: 14; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 3
                Row {
                    spacing: 6
                    Rectangle { visible: !okundu; width: 8; height: 8; radius: 4; color: app.brand; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: kaynak + "  •  " + app.zamanYazi(zaman); color: app.brand; font.pixelSize: Math.round(13 * app.yazi) }
                }
                Text {
                    width: parent.width
                    text: baslik
                    textFormat: Text.PlainText
                    color: okundu ? app.textSecondary : app.textPrimary
                    font.pixelSize: Math.round(18 * app.yazi)
                    font.bold: !okundu
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
            }
            Rectangle { anchors { left: parent.left; leftMargin: 14; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
            MouseArea { id: hma; anchors.fill: parent; onClicked: { liste.currentIndex = index; root.ac(index); } onPressAndHold: { liste.currentIndex = index; root.menu(index); } }
        }
        Keys.onPressed: {
            var k = event.key, t = U.tus(event);
            if (app.ortakTus(event)) { event.accepted = true; return; }
            if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) root.ac(currentIndex);
            else if (k === Qt.Key_Space || k === Qt.Key_Menu || k === Qt.Key_Context1) root.menu(currentIndex);
            else if (k === Qt.Key_Left) app.stepTab(-1);
            else if (k === Qt.Key_Right) app.stepTab(1);
            else if ((k === Qt.Key_Backspace || k === Qt.Key_Escape) && root.suzgec !== "") root.suz("");
            else if (t === "y" || t === "r") root.yenile();
            else if (t === "k") root.kaynakMenu();
            else if (t === "a") root.tumunuOkundu();
            else if (t === "o") { if (currentIndex >= 0) yayin.disaridaAc(hModel.get(currentIndex).link); }
            else if (t === "m") root.okunduIsaretle(currentIndex);
            else return;
            event.accepted = true;
        }
    }
    Text {
        anchors.centerIn: liste
        width: liste.width - 40
        visible: hModel.count === 0
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: root.yukleniyor ? qsTr("Haberler yükleniyor…") : qsTr("Haber yok. Yenile (Y) ya da kaynakları açın (K).")
        color: app.textSecondary
        font.pixelSize: Math.round(17 * app.yazi)
    }
}
