import QtQuick 1.1
import QtMultimediaKit 1.1
import "Util.js" as U
import "Durum.js" as D

// BelleCast: internet radyosu + podcast + haberler (RSS). Nokia E6, Qt 4.7.4 / QML 1.1.
// Sekmeler: Radyo, Podcast, Haberler, Ayarlar. Altta ortak calar cubugu.
Rectangle {
    id: app
    width: 640
    height: 480
    color: bg
    property string version: "0.3"

    // ---- Tema: koyu zemin, sekme basina pastel vurgu (Belle Files ile ayni yaklasim) ----
    //  [vurgu, basili, zemin, yuzey, secili, basili satir, aktif satir, hap, kutu, cizgi]
    property variant renkler: [
        ["#F6B26B", "#E09A50", "#18130E", "#241C14", "#3A2D1F", "#2C2218", "#2E2316", "#4D3820", "#2F251B", "#352A1F"],
        ["#C9B6F0", "#AE98DE", "#14111B", "#1F1A29", "#30283F", "#251F31", "#241D33", "#372C50", "#271F33", "#2D2538"],
        ["#9CCBEF", "#7BB2DD", "#0F151B", "#172029", "#253546", "#1C2834", "#182A38", "#1F3B52", "#1F2A35", "#22303C"],
        ["#A8E0C0", "#86C9A3", "#0F1713", "#16221C", "#22372C", "#1B2A22", "#172B21", "#1E4030", "#1D2B24", "#21312A"]
    ]
    property int tab: 0
    property color brand: renkler[tab][0]
    property color brandPressed: renkler[tab][1]
    property color bg: renkler[tab][2]
    property color surface: renkler[tab][3]
    property color highlight: renkler[tab][4]
    property color pressed: renkler[tab][5]
    property color markBg: renkler[tab][6]
    property color pill: renkler[tab][7]
    property color fieldBg: renkler[tab][8]
    property color divider: renkler[tab][9]
    property color textPrimary: "#F2F4F5"
    property color textSecondary: "#A3ADB6"
    property color danger: "#F47C8A"
    property int fontSize: 19
    property real yazi: Math.max(0.8, Math.min(1.7, fontSize / 19))

    // ---- Ayarlar ----
    property bool aktarmaAcik: true          // radyo telefon ici aktarma uzerinden (sarki adi, HTTPS, ICY)
    property bool tamMetinOto: true          // haber acilinca tam metni getir
    property int uykuVarsayilan: 30
    property string evUlke: "TR"             // radyoda "popüler" listesinin ülkesi
    property string evUlkeAd: "Türkiye"
    function evUlkeAyarla(kod, ad) { evUlke = kod; evUlkeAd = ad; ayarYaz("evUlke", kod); ayarYaz("evUlkeAd", ad); showToast(qsTr("Ülkem: ") + ad); radyoSayfasi.kipSec("tr"); }

    function showToast(m) { toast.show(m); }
    function db() { return openDatabaseSync("BelleCast", "1.0", "BelleCast", 2000000); }
    function initDb() {
        db().transaction(function (tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS kv(k TEXT UNIQUE, v TEXT)");
            tx.executeSql("CREATE TABLE IF NOT EXISTS istasyon(url TEXT UNIQUE, ad TEXT, uuid TEXT, codec TEXT, bitrate INTEGER, ulke TEXT, sira REAL)");
            tx.executeSql("CREATE TABLE IF NOT EXISTS podcast(feed TEXT UNIQUE, ad TEXT, yazar TEXT, resim TEXT, sonGorulen REAL, yeni INTEGER)");
            tx.executeSql("CREATE TABLE IF NOT EXISTS bolum(guid TEXT UNIQUE, feed TEXT, baslik TEXT, url TEXT, zaman REAL, sure INTEGER, poz INTEGER, dinlendi INTEGER, yerel TEXT)");
            tx.executeSql("CREATE TABLE IF NOT EXISTS kaynak(url TEXT UNIQUE, ad TEXT, acik INTEGER, sira REAL)");
            tx.executeSql("CREATE TABLE IF NOT EXISTS okundu(link TEXT UNIQUE, t REAL)");
        });
    }
    function ayar(k, def) {
        var v = def;
        db().readTransaction(function (tx) { var rs = tx.executeSql("SELECT v FROM kv WHERE k = ?", [k]); if (rs.rows.length) v = rs.rows.item(0).v; });
        return v;
    }
    function ayarYaz(k, v) { db().transaction(function (tx) { tx.executeSql("INSERT OR REPLACE INTO kv(k, v) VALUES(?, ?)", [k, "" + v]); }); }
    function sorgu(sql, arg) {
        var out = [];
        db().readTransaction(function (tx) { var rs = tx.executeSql(sql, arg || []); for (var i = 0; i < rs.rows.length; i++) out.push(rs.rows.item(i)); });
        return out;
    }
    function yurut(sql, arg) { db().transaction(function (tx) { tx.executeSql(sql, arg || []); }); }

    function sureYazi(sn) {
        sn = Math.max(0, Math.round(sn));
        var s = Math.floor(sn / 3600), d = Math.floor((sn % 3600) / 60), k = sn % 60;
        return (s > 0 ? s + ":" + (d < 10 ? "0" : "") : "") + d + ":" + (k < 10 ? "0" : "") + k;
    }
    function zamanYazi(ms) {
        if (!ms) return "";
        var t = new Date(ms), simdi = new Date(), fark = (simdi.getTime() - ms) / 60000;
        if (fark >= 0 && fark < 60) return Math.max(1, Math.round(fark)) + qsTr(" dk önce");
        if (fark >= 0 && fark < 24 * 60 && t.getDate() === simdi.getDate()) return Qt.formatDateTime(t, "hh:mm");
        if (fark >= 0 && fark < 48 * 60) return qsTr("dün ") + Qt.formatDateTime(t, "hh:mm");
        return Qt.formatDateTime(t, t.getFullYear() === simdi.getFullYear() ? "d MMM hh:mm" : "d MMM yyyy");
    }

    function selectTab(i) {
        tab = Math.max(0, Math.min(3, i));
        ayarYaz("tab", tab);
        if (tab === 2) haberSayfasi.ilkAcilis();
        if (tab === 1) podcastSayfasi.ilkAcilis();
        focusCurrent();
    }
    function stepTab(d) { selectTab((tab + d + 4) % 4); }
    function currentPage() { return tab === 0 ? radyoSayfasi : tab === 1 ? podcastSayfasi : tab === 2 ? haberSayfasi : ayarSayfasi; }
    function focusCurrent() {
        if (sheet.shown || input.shown) return;
        if (makale.visible) { makale.takeFocus(); return; }
        currentPage().takeFocus();
    }

    // ================================================================ Calar
    property variant calan: null            // { tur: "radyo"|"podcast", ad, url, guid, yerel, feed, poz }
    property string calanBaslik: ""         // radyoda calan sarki (ICY)
    property int deneme: 0
    property bool dogrudanZorla: false
    property bool konumAtla: false
    property double uykuBitis: 0
    property variant kanalListe: []          // radyoda ileri/geri icin calinan liste
    property int kanalSira: -1
    property bool caliyor: ses.playing && !ses.paused

    function cal(o, liste) {
        if (calan && calan.tur === "podcast") konumKaydet();
        if (yayin.kayitta && (!calan || calan.url !== o.url)) yayin.kayitDurdur();     // kanal degisince kayit kapanir
        if (o.tur === "radyo" && liste) {
            kanalListe = liste;
            kanalSira = -1;
            for (var i = 0; i < liste.length; i++) if (liste[i].url === o.url) kanalSira = i;
        }
        calan = o;
        calanBaslik = "";
        deneme = 0;
        dogrudanZorla = false;
        konumAtla = false;
        kaynagiAc();
        if (o.tur === "radyo") { ayarYaz("sonIstasyon", o.url); if (o.uuid) yayin.getir("tik", "https://de1.api.radio-browser.info/json/url/" + o.uuid); }
    }
    function kaynagiAc() {
        var o = calan;
        if (!o) return;
        var src;
        if ((o.tur === "podcast" || o.tur === "dosya") && o.yerel && yayin.dosyaVar(o.yerel)) { src = yayin.yerelUrl(o.yerel); konumAtla = (o.poz || 0) > 5000; }
        else if (((aktarmaAcik && !dogrudanZorla) || yayin.kayitta) && o.url.indexOf("http") === 0) src = yayin.aktarma(o.url);   // kayit aktarmadan yazilir
        else src = o.url;
        ses.stop();
        ses.source = src;
        ses.play();
        yayin.kayit("cal " + o.tur + " " + o.ad + (src.indexOf("127.0.0.1") > 0 ? " (aktarma)" : ""));
        if (o.tur === "podcast") yayin.zamanla("konum", 15000);
    }
    function duraklat() {
        if (!calan) return;
        if (caliyor) { ses.pause(); if (calan.tur === "podcast") konumKaydet(); }
        else if (calan.tur === "radyo") kaynagiAc();      // canli yayinda kaldigi yerden degil, simdiden
        else ses.play();
    }
    function dur() {
        if (calan && calan.tur === "podcast") konumKaydet();
        if (yayin.kayitta) yayin.kayitDurdur();
        ses.stop();
        ses.source = "";
        calan = null;
        calanBaslik = "";
        yayin.zamanIptal("uyku");
        uykuBitis = 0;
    }
    function konumKaydet() {
        if (!calan || calan.tur !== "podcast" || !calan.guid) return;
        var p = ses.position, sure = ses.duration;
        var bitti = sure > 0 && p > sure - 30000;
        yurut("UPDATE bolum SET poz = ?, dinlendi = CASE WHEN ? THEN 1 ELSE dinlendi END WHERE guid = ?", [bitti ? 0 : p, bitti ? 1 : 0, calan.guid]);
    }
    function ileriGeri(sn) {
        if (!calan || calan.tur !== "podcast" || !ses.seekable) return;
        ses.position = Math.max(0, Math.min(ses.duration - 1000, ses.position + sn * 1000));
    }
    // ---- kanal ileri/geri (radyo), podcastta 30 sn ----
    function kanalDegistir(d) {
        if (!calan) return;
        if (calan.tur !== "radyo") { ileriGeri(d * 30); return; }
        var l = kanalListe;
        if (!l || l.length < 2) { showToast(qsTr("Kanal listesi yok: istasyonu bir listeden açın")); return; }
        var j = ((kanalSira < 0 ? 0 : kanalSira) + d + l.length) % l.length;
        cal(l[j], l);
        showToast((d > 0 ? "\u25B6 " : "\u25C0 ") + l[j].ad);
    }
    // ---- radyo kaydi ----
    function kayitDegistir() {
        if (yayin.kayitta) { yayin.kayitDurdur(); return; }
        if (!calan || calan.tur !== "radyo") { showToast(qsTr("Kayıt için önce bir radyo çalın")); return; }
        yayin.kayitBaslat(calan.url, calan.ad);
        if (ses.source.toString().indexOf("127.0.0.1") < 0) { dogrudanZorla = false; kaynagiAc(); }
        showToast(qsTr("Kayıt başladı: ") + calan.ad);
    }
    function uykuKur(dk) {
        if (dk <= 0) { yayin.zamanIptal("uyku"); uykuBitis = 0; showToast(qsTr("Uyku zamanlayıcısı kapatıldı")); return; }
        yayin.zamanla("uyku", dk * 60000);
        uykuBitis = new Date().getTime() + dk * 60000;
        showToast(dk + qsTr(" dakika sonra duracak"));
    }
    function calarMenu() {
        if (!calan) return;
        var items = [];
        items.push({ label: caliyor ? qsTr("Duraklat") : qsTr("Çal"), icon: caliyor ? "pause" : "play", key: "dur", hint: qsTr("Boşluk") });
        if (calan.tur === "podcast") {
            items.push({ label: qsTr("30 sn geri"), icon: "prev", key: "geri" });
            items.push({ label: qsTr("30 sn ileri"), icon: "next", key: "ileri" });
        }
        var uk = uykuBitis > 0 ? Math.max(1, Math.round((uykuBitis - new Date().getTime()) / 60000)) : 0;
        items.push({ label: uk > 0 ? qsTr("Uyku zamanlayıcısı: ") + uk + qsTr(" dk kaldı") : qsTr("Uyku zamanlayıcısı…"), icon: "clock", key: "uyku" });
        if (calan.tur === "radyo") {
            items.push({ label: yayin.kayitta ? qsTr("Kaydı durdur (") + sureYazi(yayin.kayitSure) + ", " + U.sizeText(yayin.kayitBoyut) + ")" : qsTr("Kaydı başlat"), icon: "save", key: "kayit" });
            items.push({ label: qsTr("Önceki kanal"), icon: "prev", key: "onceki", hint: "," });
            items.push({ label: qsTr("Sonraki kanal"), icon: "next", key: "sonraki", hint: "." });
            items.push({ label: qsTr("Yeniden bağlan"), icon: "senkron", key: "yeniden" });
        }
        items.push({ label: qsTr("Durdur ve kapat"), icon: "stop", key: "kapat", danger: true });
        sheet.open(calan.ad + (calanBaslik ? " • " + calanBaslik : ""), items, function (k) {
            if (k === "dur") duraklat();
            else if (k === "geri") ileriGeri(-30);
            else if (k === "ileri") ileriGeri(30);
            else if (k === "yeniden") { deneme = 0; kaynagiAc(); }
            else if (k === "kayit") kayitDegistir();
            else if (k === "onceki") kanalDegistir(-1);
            else if (k === "sonraki") kanalDegistir(1);
            else if (k === "kapat") dur();
            else if (k === "uyku") {
                var l = [15, 30, 45, 60, 90, 120], it = [];
                if (uykuBitis > 0) it.push({ label: qsTr("Kapat"), icon: "close", key: "0" });
                for (var i = 0; i < l.length; i++) it.push({ label: l[i] + qsTr(" dakika"), icon: "clock", key: "" + l[i] });
                sheet.open(qsTr("Uyku zamanlayıcısı"), it, function (v) { uykuKur(parseInt(v, 10)); });
            }
        });
    }

    Audio {
        id: ses
        onStatusChanged: {
            if (status === Audio.Buffered && app.konumAtla && app.calan) { app.konumAtla = false; ses.position = app.calan.poz; }
            if (status === Audio.EndOfMedia && app.calan) {
                if (app.calan.tur === "radyo") { yayin.kayit("yayin kesildi, yeniden baglaniliyor"); yayin.zamanla("yeniden", 2000); }
                else { app.konumKaydet(); app.yurut("UPDATE bolum SET dinlendi = 1, poz = 0 WHERE guid = ?", [app.calan.guid]); podcastSayfasi.durumYenile(); }
            }
        }
        onError: {
            if (error === Audio.NoError || !app.calan) return;
            yayin.kayit("calma hatasi " + error + " " + errorString);
            if (app.calan.tur === "radyo" && app.deneme < 4) {
                app.deneme++;
                if (app.deneme >= 2) app.dogrudanZorla = !app.dogrudanZorla;   // aktarma / dogrudan sirayla dene
                yayin.zamanla("yeniden", 2500);
            } else app.showToast(qsTr("Çalınamadı: ") + errorString);
        }
    }
    Connections {
        target: yayin
        onBaslikDegisti: if (app.calan && app.calan.url === url) app.calanBaslik = baslik
        onKayitBitti: app.showToast(yol !== "" ? qsTr("Kayıt kaydedildi: ") + yol.split("/").pop() + " (" + U.sizeText(boyut) + ")" : qsTr("Kayıt boş kaldı, silindi"))
        onZamanDoldu: {
            if (ad === "uyku") { app.uykuBitis = 0; if (app.calan) { app.dur(); app.showToast(qsTr("Uyku zamanlayıcısı: durduruldu")); } }
            else if (ad === "yeniden") { if (app.calan) app.kaynagiAc(); }
            else if (ad.indexOf("oto") === 0) app.otoTest(parseInt(ad.substring(3), 10));
            else if (ad === "konum") { if (app.calan && app.calan.tur === "podcast") { if (app.caliyor) app.konumKaydet(); yayin.zamanla("konum", 15000); } }
        }
    }

    // Kulaklik / bluetooth kumanda / ses tuslari (RemCon)
    Connections {
        target: tuslar
        onPlayPause: app.duraklat()
        onNext: app.kanalDegistir(1)
        onPrevious: app.kanalDegistir(-1)
        onStop: app.dur()
        onUp: ses.volume = Math.min(1, ses.volume + 0.05)
        onDown: ses.volume = Math.max(0, ses.volume - 0.05)
    }

    // ================================================================ Sayfalar
    Item {
        id: sayfalar
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: calarCubugu.top }
        RadyoPage { id: radyoSayfasi; anchors.fill: parent; visible: app.tab === 0 }
        PodcastPage { id: podcastSayfasi; anchors.fill: parent; visible: app.tab === 1 }
        HaberPage { id: haberSayfasi; anchors.fill: parent; visible: app.tab === 2 }
        AyarPage { id: ayarSayfasi; anchors.fill: parent; visible: app.tab === 3 }
    }

    // ---- Calar cubugu ----
    Rectangle {
        id: calarCubugu
        anchors { left: parent.left; right: parent.right; bottom: nav.top }
        height: app.calan ? 54 : 0
        visible: !!app.calan
        color: app.pill
        clip: true
        Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: app.brand; opacity: 0.5 }
        // podcast ilerleme cizgisi
        Rectangle {
            visible: !!app.calan && app.calan.tur === "podcast" && ses.duration > 0
            anchors { left: parent.left; top: parent.top }
            height: 3
            width: ses.duration > 0 ? parent.width * ses.position / ses.duration : 0
            color: app.brand
        }
        IconButton {
            id: oynatBtn
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            icon: app.caliyor ? "pause" : "play"
            tone: "a"
            iconSize: 28
            onClicked: app.duraklat()
        }
        Column {
            anchors { left: oynatBtn.right; leftMargin: 4; right: sagDugmeler.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
            Text {
                width: parent.width
                text: app.calan ? app.calan.ad : ""
                color: app.textPrimary
                font.pixelSize: Math.round(17 * Math.min(app.yazi, 1.3))
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: !app.calan ? "" : (ses.status === Audio.Loading || ses.status === Audio.Buffering || ses.status === Audio.Stalled ? qsTr("Bağlanıyor…")
                      : (app.calan.tur === "radyo" ? (app.calanBaslik !== "" ? app.calanBaslik : qsTr("Canlı yayın")) : app.sureYazi(ses.position / 1000) + (ses.duration > 0 ? " / " + app.sureYazi(ses.duration / 1000) : "")))
                      + (app.uykuBitis > 0 ? "   ☾" : "") + (yayin.kayitta ? "   \u25CF " + app.sureYazi(yayin.kayitSure) + " " + U.sizeText(yayin.kayitBoyut) : "")
                color: app.brand
                font.pixelSize: Math.round(14 * Math.min(app.yazi, 1.3))
                elide: Text.ElideRight
            }
        }
        Row {
            id: sagDugmeler
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            IconButton { visible: !!app.calan; icon: "prev"; tone: "w"; iconSize: 24; onClicked: app.kanalDegistir(-1) }
            IconButton { visible: !!app.calan; icon: "next"; tone: "w"; iconSize: 24; onClicked: app.kanalDegistir(1) }
            Item {
                visible: !!app.calan && app.calan.tur === "radyo"
                width: visible ? 46 : 0; height: 52
                Rectangle {
                    anchors.centerIn: parent
                    width: 22; height: 22; radius: 11
                    color: yayin.kayitta ? "#FF4A4A" : "transparent"
                    border.width: 3; border.color: "#FF4A4A"
                    opacity: yayin.kayitta && (yayin.kayitSure % 2) ? 0.45 : 1
                }
                MouseArea { anchors.fill: parent; onClicked: app.kayitDegistir() }
            }
            IconButton { icon: "clock"; tone: app.uykuBitis > 0 ? "a" : "w"; iconSize: 24; onClicked: { var dk = app.uykuBitis > 0 ? 0 : app.uykuVarsayilan; app.uykuKur(dk); } }
            IconButton { icon: "more"; tone: "w"; iconSize: 24; onClicked: app.calarMenu() }
        }
        MouseArea { anchors { left: oynatBtn.right; right: sagDugmeler.left; top: parent.top; bottom: parent.bottom } onClicked: app.calarMenu() }
    }

    // ---- Alt sekmeler ----
    Rectangle {
        id: nav
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 44
        color: app.surface
        Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: app.divider }
        Row {
            anchors.fill: parent
            Repeater {
                model: [
                    { t: QT_TR_NOOP("Radyo"), i: "muzik" },
                    { t: QT_TR_NOOP("Podcast"), i: "play" },
                    { t: QT_TR_NOOP("Haberler"), i: "doc" },
                    { t: QT_TR_NOOP("Ayarlar"), i: "gear" }
                ]
                delegate: Item {
                    width: nav.width / 4
                    height: nav.height
                    property bool aktif: index === app.tab
                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 8, icerik.width + 24)
                        height: 32; radius: 16
                        color: aktif ? app.renkler[index][7] : (nma.pressed ? app.pressed : "transparent")
                    }
                    Row {
                        id: icerik
                        anchors.centerIn: parent
                        spacing: 5
                        Image { anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22; smooth: true; source: "../images/" + modelData.i + (aktif ? "_a" : "_g") + ".png" }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: qsTr(modelData.t); color: aktif ? app.renkler[index][0] : app.textPrimary; font.pixelSize: 14; font.bold: aktif }
                    }
                    MouseArea { id: nma; anchors.fill: parent; onClicked: app.selectTab(index) }
                }
            }
        }
    }

    MakalePage { id: makale; anchors.fill: parent; anchors.bottomMargin: nav.height + calarCubugu.height; visible: false; z: 15 }
    ActionSheet { id: sheet }
    InputDialog { id: input }
    Toast { id: toast; bottomGap: nav.height + calarCubugu.height + 10 }

    // donanim klavyesi: her sayfada ortak kisayollar sayfalarin kendi Keys'inde; burada calar
    function ortakTus(event) {
        var t = U.tus(event), k = event.key;
        if (U.ctrl(event) && (k === Qt.Key_Q || t === "q")) { Qt.quit(); return true; }
        if (t === "p" && app.calan) { app.duraklat(); return true; }
        if (t === "u" && app.calan) { app.calarMenu(); return true; }
        if ((t === "," || t === "<") && app.calan) { app.kanalDegistir(-1); return true; }
        if ((t === "." || t === ">") && app.calan) { app.kanalDegistir(1); return true; }
        if (k === Qt.Key_VolumeUp || t === "+") { ses.volume = Math.min(1, ses.volume + 0.1); app.showToast(qsTr("Ses %") + Math.round(ses.volume * 100)); return true; }
        if (k === Qt.Key_VolumeDown || t === "-") { ses.volume = Math.max(0, ses.volume - 0.1); app.showToast(qsTr("Ses %") + Math.round(ses.volume * 100)); return true; }
        return false;
    }

    // Duman testi: veri klasorunde oto.txt varsa (CODA ile konur) acilista adim adim dener, gunluge yazar
    function otoTest(adim) {
        var s = function (m) { yayin.kayit("OTO " + adim + ": " + m); };
        if (adim === 1) { s("haberler"); selectTab(2); s("acik kaynak " + haberSayfasi.kaynaklar.length); yayin.zamanla("oto2", 50000); }
        else if (adim === 2) { s("haber sayisi " + haberSayfasi.adet()); selectTab(1); podcastSayfasi.kipSec("populer"); yayin.zamanla("oto3", 15000); }
        else if (adim === 3) { s("podcast " + podcastSayfasi.sayilar()); podcastSayfasi.tikla(0); yayin.zamanla("oto4", 20000); }
        else if (adim === 4) { s("bolumler " + podcastSayfasi.sayilar()); selectTab(0); radyoSayfasi.kipSec("kayitli"); s("favori sayisi " + radyoSayfasi.adet() + " db " + sorgu("SELECT COUNT(*) AS n FROM istasyon")[0].n); radyoSayfasi.cal(0); yayin.zamanla("oto5", 20000); }
        else if (adim === 5) { s("radyo " + (calan ? calan.ad : "-") + " durum=" + ses.status + " poz=" + ses.position + " calan='" + calanBaslik + "'"); kayitDegistir(); yayin.zamanla("oto6", 20000); }
        else if (adim === 6) { s("kayit suruyor=" + yayin.kayitta + " boyut=" + yayin.kayitBoyut + " sure=" + yayin.kayitSure); kanalDegistir(1); yayin.zamanla("oto7", 15000); }
        else if (adim === 7) { var k = yayin.kayitlar(); s("kanal simdi " + (calan ? calan.ad : "-") + " durum=" + ses.status + " poz=" + ses.position + " kayit dosyasi=" + k.length + (k.length ? " son=" + k[0].ad + " " + k[0].boyut + " bayt" : "")); kanalDegistir(-1); yayin.zamanla("oto8", 8000); }
        else if (adim === 8) { s("geri kanal " + (calan ? calan.ad : "-")); dur(); radyoSayfasi.kipSec("kayit"); s("kayitlar listesi " + radyoSayfasi.adet()); s("BITTI"); }
    }

    Component.onCompleted: {
        initDb();
        fontSize = parseInt(ayar("fontSize", "19"), 10);
        aktarmaAcik = ayar("aktarma", "1") === "1";
        tamMetinOto = ayar("tamMetin", "1") === "1";
        uykuVarsayilan = parseInt(ayar("uyku", "30"), 10);
        evUlke = ayar("evUlke", "TR");
        evUlkeAd = ayar("evUlkeAd", "Türkiye");
        ses.volume = parseFloat(ayar("ses", "0.8"));
        radyoSayfasi.hazirla();
        haberSayfasi.hazirla();
        selectTab(parseInt(ayar("tab", "0"), 10));
        yayin.kayit("arayuz hazir v" + version);
        if (yayin.dosyaVar(yayin.veriKlasoru() + "/oto.txt")) { yayin.dosyaSil(yayin.veriKlasoru() + "/oto.txt"); yayin.zamanla("oto1", 3000); }
    }
    Component.onDestruction: { if (calan && calan.tur === "podcast") konumKaydet(); ayarYaz("ses", ses.volume); }
}
