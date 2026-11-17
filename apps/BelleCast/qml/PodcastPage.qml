import QtQuick 1.1
import "Util.js" as U
import "Durum.js" as D

// Podcast: abonelikler, populer (iTunes, secili ulke), arama, RSS adresiyle ekleme, bolumler, indirilenler.
// Bolum: dinle (indirildiyse kaldigi yerden), indir, dinlendi isareti, aciklama.
Rectangle {
    id: root
    color: app.bg
    property string kip: "abonelik"         // abonelik | populer | ara | indirilen
    property string arama: ""
    property bool yukleniyor: false
    property string hata: ""
    property string acikFeed: ""            // bolum listesi acikken podcast beslemesi
    property string acikAd: ""
    property string acikResim: ""
    property bool ilkOldu: false
    property string indirilenAd: yayin.indirilenAd
    property int indirYuzde: -1

    function sayilar() { return "liste=" + pModel.count + " bolum=" + bModel.count + " hata='" + hata + "' acik=" + acikAd; }
    function takeFocus() { if (acikFeed !== "") bListe.forceActiveFocus(); else liste.forceActiveFocus(); }
    function ilkAcilis() {
        if (ilkOldu) return;
        ilkOldu = true;
        kipSec(parseInt(app.sorgu("SELECT COUNT(*) AS n FROM podcast")[0].n, 10) > 0 ? "abonelik" : "populer");
    }
    function kipSec(k) {
        kip = k;
        acikFeed = "";
        hata = "";
        pModel.clear();
        if (k === "abonelik") aboneliklerYukle();
        else if (k === "indirilen") indirilenlerYukle();
        else if (k === "populer") { yukleniyor = true; yayin.getir("itunes:top", "https://itunes.apple.com/" + app.evUlke.toLowerCase() + "/rss/toppodcasts/limit=60/json"); }
        else if (k === "ara") { if (arama === "") ara(); else { yukleniyor = true; yayin.getir("itunes:ara", "https://itunes.apple.com/search?media=podcast&limit=50&term=" + encodeURIComponent(arama)); } }
        liste.forceActiveFocus();
    }
    function aboneliklerYukle() {
        var l = app.sorgu("SELECT * FROM podcast ORDER BY ad");
        pModel.clear();
        for (var i = 0; i < l.length; i++) pModel.append({ ad: l[i].ad, yazar: l[i].yazar || "", feed: l[i].feed, resim: l[i].resim || "", yeni: Number(l[i].yeni) || 0, kimlik: "", abone: true });
    }
    function indirilenlerYukle() {
        var l = app.sorgu("SELECT b.*, p.ad AS pad FROM bolum b LEFT JOIN podcast p ON p.feed = b.feed WHERE b.yerel <> '' ORDER BY b.zaman DESC");
        pModel.clear();
        for (var i = 0; i < l.length; i++) {
            if (!yayin.dosyaVar(l[i].yerel)) { app.yurut("UPDATE bolum SET yerel = '' WHERE guid = ?", [l[i].guid]); continue; }
            pModel.append({ ad: l[i].baslik, yazar: (l[i].pad || "") + "  •  " + U.sizeText(yayin.dosyaBoyutu(l[i].yerel)), feed: l[i].feed, resim: "", yeni: 0, kimlik: l[i].guid, abone: false });
        }
    }
    function aboneMi(feed) { if (!feed) return false; return app.sorgu("SELECT 1 FROM podcast WHERE feed = ?", [feed]).length > 0; }
    function abone(feed, ad, yazar, resim) {
        app.yurut("INSERT OR REPLACE INTO podcast(feed, ad, yazar, resim, sonGorulen, yeni) VALUES(?, ?, ?, ?, ?, 0)", [feed, ad, yazar || "", resim || "", new Date().getTime()]);
        app.showToast(qsTr("Abone olundu: ") + ad);
        if (kip === "abonelik") aboneliklerYukle();
    }
    function aboneliktenCik(feed, ad) {
        app.yurut("DELETE FROM podcast WHERE feed = ?", [feed]);
        app.showToast(qsTr("Abonelik bırakıldı: ") + ad);
        if (kip === "abonelik") aboneliklerYukle();
    }
    function ara() {
        input.open({ title: qsTr("Podcast ara"), label1: qsTr("Ad ya da konu (ör. bilim, tarih, teknoloji)"), text1: arama, ok: qsTr("Ara") }, function (q) {
            q = q.replace(/^\s+|\s+$/g, "");
            if (q === "") return;
            root.arama = q;
            root.kipSec("ara");
        });
    }
    function adresEkle() {
        input.open({ title: qsTr("RSS adresiyle podcast ekle"), label1: qsTr("Besleme adresi (https://…/rss)"), text1: "https://", ok: qsTr("Aç") }, function (u) {
            u = u.replace(/^\s+|\s+$/g, "");
            if (u.length < 12) { app.showToast(qsTr("Geçersiz adres")); return; }
            root.ac(u, "", "");
        });
    }
    // Podcast'in bolumlerini ac
    function ac(feed, ad, resim) {
        acikFeed = feed;
        acikAd = ad || qsTr("Podcast");
        acikResim = resim || "";
        bModel.clear();
        // once onbellekteki bolumler (cevrimdisi da gorunur)
        var l = app.sorgu("SELECT * FROM bolum WHERE feed = ? ORDER BY zaman DESC LIMIT 150", [feed]);
        for (var i = 0; i < l.length; i++) bModel.append(bolumSatiri(l[i]));
        yukleniyor = true;
        yayin.akisCek("pod:" + feed, feed);
        app.yurut("UPDATE podcast SET yeni = 0, sonGorulen = ? WHERE feed = ?", [new Date().getTime(), feed]);
        bListe.forceActiveFocus();
    }
    function bolumSatiri(r) {
        return { baslik: r.baslik, guid: r.guid, url: r.url, zaman: Number(r.zaman) || 0, sure: Number(r.sure) || 0, poz: Number(r.poz) || 0, dinlendi: Number(r.dinlendi) === 1, yerel: r.yerel || "", ozet: r.ozet || "" };
    }
    function kapatBolumler() { acikFeed = ""; if (kip === "abonelik") aboneliklerYukle(); liste.forceActiveFocus(); }
    function durumYenile() {
        for (var i = 0; i < bModel.count; i++) {
            var r = app.sorgu("SELECT poz, dinlendi, yerel FROM bolum WHERE guid = ?", [bModel.get(i).guid]);
            if (!r.length) continue;
            bModel.setProperty(i, "poz", Number(r[0].poz) || 0);
            bModel.setProperty(i, "dinlendi", Number(r[0].dinlendi) === 1);
            bModel.setProperty(i, "yerel", r[0].yerel || "");
        }
        if (kip === "indirilen" && acikFeed === "") indirilenlerYukle();
    }
    function dinle(b) {
        if (!b.url && !b.yerel) { app.showToast(qsTr("Bu bölümde ses dosyası yok")); return; }
        var r = app.sorgu("SELECT poz, yerel FROM bolum WHERE guid = ?", [b.guid]);
        var yerel = r.length ? r[0].yerel : "", poz = r.length ? Number(r[0].poz) || 0 : 0;
        if (!yerel && poz > 0) app.showToast(qsTr("Akışta kaldığı yere atlanamaz; indirilirse kaldığı yerden devam eder"));
        app.cal({ tur: "podcast", ad: b.baslik, url: b.url, guid: b.guid, yerel: yerel || "", poz: poz || 0, feed: b.feed || acikFeed });
    }
    // ---- indirme kuyrugu ----
    function indir(b) {
        var r = app.sorgu("SELECT yerel FROM bolum WHERE guid = ?", [b.guid]);
        if (r.length && r[0].yerel && yayin.dosyaVar(r[0].yerel)) { app.showToast(qsTr("Zaten indirildi")); return; }
        var q = D.indirKuyruk;
        for (var i = 0; i < q.length; i++) if (q[i].guid === b.guid) { app.showToast(qsTr("Zaten sırada")); return; }
        var uz = (b.url.split("?")[0].match(/\.(mp3|m4a|aac|ogg|mp4|wav)$/i) || [".mp3"])[0];
        q.push({ url: b.url, ad: (acikAd ? acikAd + " - " : "") + b.baslik + uz, guid: b.guid });
        D.indirKuyruk = q;
        app.showToast(yayin.indiriyor ? qsTr("Sıraya eklendi (") + q.length + ")" : qsTr("İndiriliyor: ") + b.baslik);
        siradaki();
    }
    function siradaki() {
        if (yayin.indiriyor || !D.indirKuyruk.length) return;
        var q = D.indirKuyruk, b = q[0];
        D.indirKuyruk = q.slice(1);
        D.sonrakiIs = b.guid;
        indirYuzde = 0;
        if (!yayin.indir(b.url, b.ad)) { app.showToast(qsTr("İndirme başlatılamadı")); siradaki(); }
    }
    function indirileniSil(b) {
        var r = app.sorgu("SELECT yerel FROM bolum WHERE guid = ?", [b.guid]);
        if (r.length && r[0].yerel) yayin.dosyaSil(r[0].yerel);
        app.yurut("UPDATE bolum SET yerel = '' WHERE guid = ?", [b.guid]);
        app.showToast(qsTr("İndirilen dosya silindi"));
        durumYenile();
    }
    function bolumMenu(i) {
        if (i < 0 || i >= bModel.count) return;
        var b = bModel.get(i), items = [];
        var indirildi = b.yerel !== "" && yayin.dosyaVar(b.yerel);
        items.push({ label: qsTr("Dinle") + (indirildi ? qsTr(" (indirilen)") : qsTr(" (akış)")) + (b.poz > 0 && indirildi ? qsTr(" • kaldığı yerden ") + app.sureYazi(b.poz / 1000) : ""), icon: "play", key: "dinle", hint: qsTr("Enter") });
        if (indirildi) items.push({ label: qsTr("İndirileni sil"), icon: "trash", key: "sil" });
        else if (b.url) items.push({ label: qsTr("İndir (çevrimdışı dinle, kaldığı yerden devam)"), icon: "yukle", key: "indir", hint: "D" });
        if (b.poz > 0) items.push({ label: qsTr("Baştan başlat"), icon: "undo", key: "bastan" });
        items.push({ label: b.dinlendi ? qsTr("Dinlenmedi olarak işaretle") : qsTr("Dinlendi olarak işaretle"), icon: "check", key: "dinlendi", hint: "M" });
        items.push({ label: qsTr("Açıklama"), icon: "doc", key: "aciklama", hint: "I" });
        sheet.open(b.baslik, items, function (k) {
            if (k === "dinle") root.dinle(b);
            else if (k === "indir") root.indir(b);
            else if (k === "sil") root.indirileniSil(b);
            else if (k === "bastan") { app.yurut("UPDATE bolum SET poz = 0 WHERE guid = ?", [b.guid]); root.durumYenile(); }
            else if (k === "dinlendi") { app.yurut("UPDATE bolum SET dinlendi = ?, poz = 0 WHERE guid = ?", [b.dinlendi ? 0 : 1, b.guid]); root.durumYenile(); }
            else if (k === "aciklama") makale.metinGoster(b.baslik, root.acikAd + "  •  " + app.zamanYazi(b.zaman) + (b.sure ? "  •  " + app.sureYazi(b.sure) : ""), b.ozet || qsTr("Açıklama yok"), "");
        });
    }
    function menu(i) {
        if (i < 0 || i >= pModel.count) { genelMenu(); return; }
        var o = pModel.get(i), items = [];
        if (kip === "indirilen") {
            var b = app.sorgu("SELECT * FROM bolum WHERE guid = ?", [o.kimlik]);
            if (!b.length) return;
            sheet.open(o.ad, [
                { label: qsTr("Dinle (kaldığı yerden)"), icon: "play", key: "dinle" },
                { label: qsTr("Sil"), icon: "trash", key: "sil", danger: true }
            ], function (k) { if (k === "dinle") root.dinle(root.bolumSatiri(b[0])); else { root.indirileniSil(b[0]); root.indirilenlerYukle(); } });
            return;
        }
        var abn = o.feed ? aboneMi(o.feed) : false;
        items.push({ label: qsTr("Bölümleri aç"), icon: "play", key: "ac", hint: qsTr("Enter") });
        if (o.feed) items.push({ label: abn ? qsTr("Abonelikten çık") : qsTr("Abone ol"), icon: abn ? "star_o" : "star", key: "abone", hint: "F" });
        sheet.open(o.ad, items, function (k) {
            if (k === "ac") root.tikla(i);
            else if (k === "abone") { if (abn) root.aboneliktenCik(o.feed, o.ad); else root.abone(o.feed, o.ad, o.yazar, o.resim); }
        });
    }
    function tikla(i) {
        if (i < 0 || i >= pModel.count) return;
        var o = pModel.get(i);
        if (kip === "indirilen") { var b = app.sorgu("SELECT * FROM bolum WHERE guid = ?", [o.kimlik]); if (b.length) dinle(bolumSatiri(b[0])); return; }
        if (!o.feed && o.kimlik) { yukleniyor = true; yayin.getir("itunes:bul", "https://itunes.apple.com/lookup?id=" + o.kimlik); return; }   // populer: once besleme adresi
        if (o.feed) ac(o.feed, o.ad, o.resim);
    }
    function hepsiniYenile() {
        var l = app.sorgu("SELECT feed FROM podcast");
        if (!l.length) { app.showToast(qsTr("Abonelik yok")); return; }
        for (var i = 0; i < l.length; i++) yayin.akisCek("yenile:" + l[i].feed, l[i].feed);
        app.showToast(l.length + qsTr(" podcast yenileniyor…"));
    }
    function genelMenu() {
        sheet.open(qsTr("Podcast"), [
            { label: qsTr("Podcast ara"), icon: "search", key: "ara", hint: "S" },
            { label: qsTr("RSS adresiyle ekle"), icon: "plus", key: "ekle", hint: "N" },
            { label: qsTr("Aboneliklerdeki yeni bölümleri denetle"), icon: "senkron", key: "yenile", hint: "Y" },
            { label: yayin.indiriyor ? qsTr("İndirmeyi durdur (") + yayin.indirilenAd + ")" : qsTr("İndirme yok"), icon: "stop", key: "durdur" },
            { label: qsTr("İndirme klasörü: ") + yayin.indirmeKlasoru(), icon: "folder", key: "x" }
        ], function (k) {
            if (k === "ara") root.ara(); else if (k === "ekle") root.adresEkle(); else if (k === "yenile") root.hepsiniYenile();
            else if (k === "durdur" && yayin.indiriyor) { D.indirKuyruk = []; yayin.indirmeIptal(); }
        });
    }

    Connections {
        target: yayin
        onMetinGeldi: {
            if (istekId.indexOf("itunes:") !== 0) return;
            root.yukleniyor = false;
            if (hata !== "") { root.hata = qsTr("Alınamadı: ") + hata; return; }
            var j = null;
            try { j = JSON.parse(govde); } catch (e) { root.hata = qsTr("Geçersiz yanıt"); return; }
            if (istekId === "itunes:bul") {
                var r = j.results && j.results.length ? j.results[0] : null;
                if (!r || !r.feedUrl) { app.showToast(qsTr("Bu podcast'in RSS beslemesi yok")); return; }
                root.ac(r.feedUrl, r.collectionName, r.artworkUrl100);
                return;
            }
            pModel.clear();
            if (istekId === "itunes:top") {
                var en = j.feed && j.feed.entry ? j.feed.entry : [];
                for (var i = 0; i < en.length; i++)
                    pModel.append({ ad: en[i]["im:name"].label, yazar: en[i]["im:artist"] ? en[i]["im:artist"].label : "", feed: "", resim: "", yeni: 0,
                                   kimlik: en[i].id && en[i].id.attributes ? en[i].id.attributes["im:id"] : "", abone: false });
            } else {
                var rs = j.results || [];
                for (var k = 0; k < rs.length; k++) {
                    if (!rs[k].feedUrl) continue;
                    pModel.append({ ad: rs[k].collectionName, yazar: rs[k].artistName + (rs[k].trackCount ? "  •  " + rs[k].trackCount + qsTr(" bölüm") : ""), feed: rs[k].feedUrl,
                                   resim: rs[k].artworkUrl100 || "", yeni: 0, kimlik: "", abone: root.aboneMi(rs[k].feedUrl) });
                }
            }
            if (!pModel.count) root.hata = qsTr("Sonuç yok");
            liste.currentIndex = 0;
        }
        onAkisHazir: {
            if (istekId.indexOf("pod:") === 0) {
                var feed = istekId.substring(4);
                if (feed !== root.acikFeed) return;
                root.yukleniyor = false;
                if (hata !== "") { app.showToast(qsTr("Besleme alınamadı: ") + hata); return; }
                if (kanal.baslik) root.acikAd = kanal.baslik;
                if (kanal.resim) root.acikResim = kanal.resim;
                // bolumleri veritabanina isle (durum korunur), listeyi yenile
                app.db().transaction(function (tx) {
                    for (var i = 0; i < ogeler.length; i++) {
                        var o = ogeler[i];
                        if (!o.ses) continue;
                        tx.executeSql("INSERT OR IGNORE INTO bolum(guid, feed, baslik, url, zaman, sure, poz, dinlendi, yerel) VALUES(?, ?, ?, ?, ?, ?, 0, 0, '')", [o.guid || o.ses, feed, o.baslik || "", o.ses, o.zaman || 0, o.sure || 0]);
                        tx.executeSql("UPDATE bolum SET baslik = ?, url = ?, zaman = ?, sure = ? WHERE guid = ?", [o.baslik || "", o.ses, o.zaman || 0, o.sure || 0, o.guid || o.ses]);
                    }
                });
                bModel.clear();
                var oz = {};
                for (var m = 0; m < ogeler.length; m++) if (ogeler[m].ses) oz[ogeler[m].guid || ogeler[m].ses] = ogeler[m].ozet || "";
                var l = app.sorgu("SELECT * FROM bolum WHERE feed = ? ORDER BY zaman DESC LIMIT 150", [feed]);
                for (var n = 0; n < l.length; n++) { var s = root.bolumSatiri(l[n]); s.ozet = oz[s.guid] || ""; bModel.append(s); }
                if (root.aboneMi(feed)) app.yurut("UPDATE podcast SET ad = ?, resim = ? WHERE feed = ?", [root.acikAd, root.acikResim, feed]);
            } else if (istekId.indexOf("yenile:") === 0 && hata === "") {
                var f = istekId.substring(7);
                var son = app.sorgu("SELECT sonGorulen FROM podcast WHERE feed = ?", [f]);
                if (!son.length) return;
                var yeni = 0;
                for (var y = 0; y < ogeler.length; y++) if ((ogeler[y].zaman || 0) > Number(son[0].sonGorulen)) yeni++;
                app.yurut("UPDATE podcast SET yeni = ? WHERE feed = ?", [yeni, f]);
                if (root.kip === "abonelik" && root.acikFeed === "") root.aboneliklerYukle();
            }
        }
        onIndirmeIlerleme: root.indirYuzde = toplam > 0 ? Math.round(alinan * 100 / toplam) : -1
        onIndirmeBitti: {
            root.indirYuzde = -1;
            if (ok && D.sonrakiIs) app.yurut("UPDATE bolum SET yerel = ? WHERE guid = ?", [yol, D.sonrakiIs]);
            app.showToast(ok ? qsTr("İndirildi: ") + yayin.guvenliAd(yol.split("/").pop()) : qsTr("İndirilemedi: ") + mesaj);
            D.sonrakiIs = null;
            root.durumYenile();
            root.siradaki();
        }
    }

    ListModel { id: pModel }
    ListModel { id: bModel }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        showBack: root.acikFeed !== ""
        onBack: root.kapatBolumler()
        title: root.acikFeed !== "" ? root.acikAd : qsTr("Podcast")
        subtitle: yayin.indiriyor ? "↓ " + (root.indirYuzde >= 0 ? root.indirYuzde + "% " : "") + yayin.indirilenAd : (root.acikFeed !== "" ? bModel.count + qsTr(" bölüm") : "")
        busy: root.yukleniyor
        IconButton { visible: root.acikFeed !== ""; icon: root.aboneMi(root.acikFeed) ? "star" : "star_o"; tone: "a"; iconSize: 24
            onClicked: { if (root.aboneMi(root.acikFeed)) root.aboneliktenCik(root.acikFeed, root.acikAd); else root.abone(root.acikFeed, root.acikAd, "", root.acikResim); visible = false; visible = true; } }
        IconButton { visible: root.acikFeed === ""; icon: "search"; tone: "w"; iconSize: 24; onClicked: root.ara() }
        IconButton { icon: "more"; tone: "w"; iconSize: 24; onClicked: root.genelMenu() }
    }
    Flickable {
        id: hapSerit
        visible: root.acikFeed === ""
        anchors { left: parent.left; right: parent.right; top: header.bottom }
        height: visible ? 44 : 0
        contentWidth: haplar.width + 20
        clip: true
        Row {
            id: haplar
            x: 10; anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Hap { yazi: qsTr("★ Aboneliklerim"); secili: root.kip === "abonelik"; onTiklandi: root.kipSec("abonelik") }
            Hap { yazi: app.evUlkeAd + qsTr(" • popüler"); secili: root.kip === "populer"; onTiklandi: root.kipSec("populer") }
            Hap { yazi: root.arama !== "" ? qsTr("Arama: ") + root.arama : qsTr("Ara…"); secili: root.kip === "ara"; onTiklandi: root.kipSec("ara") }
            Hap { yazi: qsTr("İndirilenler"); secili: root.kip === "indirilen"; onTiklandi: root.kipSec("indirilen") }
        }
    }
    ListView {
        id: liste
        visible: root.acikFeed === ""
        anchors { left: parent.left; right: parent.right; top: hapSerit.bottom; bottom: parent.bottom }
        clip: true
        model: pModel
        highlightMoveDuration: 100
        delegate: Satir {
            width: liste.width
            baslik: ad
            alt: yazar
            simge: root.kip === "indirilen" ? "play" : ""
            yeni: model.yeni > 0
            sagYazi: model.yeni > 0 ? model.yeni + qsTr(" yeni") : (abone && root.kip !== "abonelik" ? "★" : "")
            aktif: root.kip === "indirilen" && !!app.calan && app.calan.guid === kimlik
            secili: ListView.isCurrentItem && liste.activeFocus
            onTiklandi: { liste.currentIndex = index; root.tikla(index); }
            onBasiliTutuldu: { liste.currentIndex = index; root.menu(index); }
            onMenu: { liste.currentIndex = index; root.menu(index); }
        }
        Keys.onPressed: {
            var k = event.key, t = U.tus(event);
            if (app.ortakTus(event)) { event.accepted = true; return; }
            if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) root.tikla(currentIndex);
            else if (k === Qt.Key_Space || k === Qt.Key_Menu || k === Qt.Key_Context1) root.menu(currentIndex);
            else if (k === Qt.Key_Left) app.stepTab(-1);
            else if (k === Qt.Key_Right) app.stepTab(1);
            else if (t === "s" || t === "/") root.ara();
            else if (t === "n") root.adresEkle();
            else if (t === "y") root.hepsiniYenile();
            else if (t === "1") root.kipSec("abonelik");
            else if (t === "2") root.kipSec("populer");
            else if (t === "3") root.kipSec("ara");
            else if (t === "4") root.kipSec("indirilen");
            else return;
            event.accepted = true;
        }
    }
    ListView {
        id: bListe
        visible: root.acikFeed !== ""
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        clip: true
        model: bModel
        highlightMoveDuration: 100
        delegate: Satir {
            width: bListe.width
            baslik: model.baslik
            alt: app.zamanYazi(zaman) + (sure ? "  •  " + app.sureYazi(sure) : "") + (poz > 0 ? qsTr("  •  kaldı: ") + app.sureYazi(Math.max(0, sure - poz / 1000)) : "")
            simge: yerel !== "" ? "yukle" : "play"
            soluk: dinlendi
            aktif: !!app.calan && app.calan.guid === guid
            sagYazi: dinlendi ? "✓" : ""
            secili: ListView.isCurrentItem && bListe.activeFocus
            onTiklandi: { bListe.currentIndex = index; root.dinle(bModel.get(index)); }
            onBasiliTutuldu: { bListe.currentIndex = index; root.bolumMenu(index); }
            onMenu: { bListe.currentIndex = index; root.bolumMenu(index); }
        }
        Keys.onPressed: {
            var k = event.key, t = U.tus(event);
            if (app.ortakTus(event)) { event.accepted = true; return; }
            var b = currentIndex >= 0 && currentIndex < bModel.count ? bModel.get(currentIndex) : null;
            if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) { if (b) root.dinle(b); }
            else if (k === Qt.Key_Space || k === Qt.Key_Menu || k === Qt.Key_Context1) root.bolumMenu(currentIndex);
            else if (k === Qt.Key_Backspace || k === Qt.Key_Escape || k === Qt.Key_Context2 || k === Qt.Key_Left) root.kapatBolumler();
            else if (t === "d") { if (b) root.indir(b); }
            else if (t === "m") { if (b) { app.yurut("UPDATE bolum SET dinlendi = ?, poz = 0 WHERE guid = ?", [b.dinlendi ? 0 : 1, b.guid]); root.durumYenile(); } }
            else if (t === "i") root.bolumMenu(currentIndex);
            else return;
            event.accepted = true;
        }
    }
    Text {
        anchors.centerIn: root.acikFeed !== "" ? bListe : liste
        width: parent.width - 40
        visible: (root.acikFeed !== "" ? bModel.count : pModel.count) === 0
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: root.yukleniyor ? qsTr("Yükleniyor…") : (root.hata !== "" ? root.hata
              : (root.acikFeed !== "" ? qsTr("Bölüm yok")
              : (root.kip === "abonelik" ? qsTr("Abonelik yok.\nPopüler listesine bakın ya da arayın (S); podcast'i açıp ★ ile abone olun.")
              : (root.kip === "indirilen" ? qsTr("İndirilen bölüm yok.\nBölümün … menüsünden İndir deyin.") : ""))))
        color: app.textSecondary
        font.pixelSize: Math.round(17 * app.yazi)
    }
}
