import QtQuick 1.1
import "Util.js" as U
import "Servis.js" as S
import "Durum.js" as D

// BelleCeviri: ceviri + sozluk. Sekmeler: Cevir, Sozluk, Gecmis, Ayarlar.
// Servisler Ayarlar > Servisler'den acilip kapatilir; acik olanlar calisir, her biri ayri kartta.
Rectangle {
    id: app
    width: 640
    height: 480
    color: bg
    property string version: "0.2"

    // ---- Tema: sekme basina pastel vurgu ----
    property variant renkler: [
        ["#7CC4F2", "#5EADDF", "#0E151C", "#16212B", "#223446", "#1B2835", "#182B3A", "#1E3C55", "#1E2A36", "#22303D"],
        ["#F6C177", "#E0A95A", "#17140E", "#231E15", "#3A301F", "#2C2418", "#2E2416", "#4D3B20", "#2F271B", "#352C1F"],
        ["#C9B6F0", "#AE98DE", "#14111B", "#1F1A29", "#30283F", "#251F31", "#241D33", "#372C50", "#271F33", "#2D2538"],
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
    property bool ing: (dil.secim === "auto" ? dil.kod : dil.secim) === "en"

    // ---- Ayarlar ----
    property bool gecmisTut: true
    property bool panodanAl: false
    property int surum: 0                    // servis ayarlari degisince artar (bagli gorunumler yenilensin)

    function showToast(m) { toast.show(m); }
    function db() { return openDatabaseSync("BelleCeviri", "1.0", "BelleCeviri", 2000000); }
    function initDb() {
        db().transaction(function (tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS kv(k TEXT UNIQUE, v TEXT)");
            tx.executeSql("CREATE TABLE IF NOT EXISTS gecmis(kaynak TEXT, sonuc TEXT, sl TEXT, tl TEXT, servis TEXT, t REAL, fav INTEGER)");
        });
    }
    function ayar(k, def) {
        var v = def;
        db().readTransaction(function (tx) { var rs = tx.executeSql("SELECT v FROM kv WHERE k = ?", [k]); if (rs.rows.length) v = rs.rows.item(0).v; });
        return v;
    }
    function ayarYaz(k, v) { db().transaction(function (tx) { tx.executeSql("INSERT OR REPLACE INTO kv(k, v) VALUES(?, ?)", [k, "" + v]); }); }
    function ayarSil(k) { db().transaction(function (tx) { tx.executeSql("DELETE FROM kv WHERE k = ?", [k]); }); }
    function sorgu(sql, arg) {
        var out = [];
        db().readTransaction(function (tx) { var rs = tx.executeSql(sql, arg || []); for (var i = 0; i < rs.rows.length; i++) out.push(rs.rows.item(i)); });
        return out;
    }
    function yurut(sql, arg) { db().transaction(function (tx) { tx.executeSql(sql, arg || []); }); }

    // ---- Servis durumu ----
    function aktif(kod) { var s = S.servis(kod); return ayar("aktif_" + kod, s.varsayilan ? "1" : "0") === "1"; }
    function aktifYap(kod, acik) { ayarYaz("aktif_" + kod, acik ? "1" : "0"); surum++; }
    function anahtar(kod) { return ayar("anahtar_" + kod, ""); }
    function model(kod) { return ayar("model_" + kod, S.servis(kod).model || ""); }
    function etiket(s) {
        return (s.anahtarli ? qsTr("anahtarlı") : qsTr("anahtarsız")) + " \u00B7 " + (s.llm ? qsTr("LLM") : qsTr("normal")) + (s.alt ? " \u00B7 " + qsTr(s.alt) : "");
    }
    function aktifler(tur) {
        var l = [];
        for (var i = 0; i < S.servisler.length; i++) { var s = S.servisler[i]; if (s.tur === tur && aktif(s.kod)) l.push(s); }
        return l;
    }
    function ilkLlm() {
        for (var i = 0; i < S.servisler.length; i++) { var s = S.servisler[i]; if (s.llm && aktif(s.kod) && anahtar(s.kod) !== "") return s; }
        return null;
    }
    function dilAdi(k) { return S.dilAdi(k, ing); }
    function sonDillerEkle(k) {
        if (k === "auto") return;
        var l = ayar("sonDiller", "tr,en").split(","), y = [k];
        for (var i = 0; i < l.length && y.length < 6; i++) if (l[i] !== k && l[i] !== "") y.push(l[i]);
        ayarYaz("sonDiller", y.join(","));
    }

    // Anahtarlari dosyadan ice aktar: satir basina "kod=anahtar" (ya da "model_kod=model"); okununca dosya silinir
    function anahtarIceAktar(sessiz) {
        var yollar = ["E:/BelleCeviri_anahtarlar.txt", cv.veriKlasoru() + "/anahtarlar.txt"], n = 0;
        for (var y = 0; y < yollar.length; y++) {
            if (!cv.dosyaVar(yollar[y])) continue;
            var satirlar = cv.dosyaOku(yollar[y]).split(/\r?\n/);
            for (var i = 0; i < satirlar.length; i++) {
                var s = satirlar[i].replace(/^\s+|\s+$/g, ""), e = s.indexOf("=");
                if (e <= 0 || s.charAt(0) === "#") continue;
                var k = s.substring(0, e).replace(/\s+/g, "").toLowerCase(), v = s.substring(e + 1).replace(/^\s+|\s+$/g, "");
                if (k.indexOf("model_") === 0 && S.servis(k.substring(6))) { ayarYaz(k, v); n++; }
                else if (S.servis(k) && S.servis(k).anahtarli && v !== "") { ayarYaz("anahtar_" + k, v); aktifYap(k, true); n++; }
            }
            cv.dosyaSil(yollar[y]);
        }
        surum++;
        if (n > 0) showToast(n + qsTr(" anahtar/ayar içe aktarıldı, dosya silindi"));
        else if (!sessiz) showToast(qsTr("Dosya bulunamadı: E:/BelleCeviri_anahtarlar.txt (satır başına kod=anahtar)"));
    }

    // ---- Istek dagitimi: id "onEk:kod:sira" ----
    property int sira: 0
    function gonder(onEk, kod, metin, sl, tl, aciklaIng) {
        var s = S.servis(kod);
        var r = S.istek(kod, metin, sl, tl, anahtar(kod), model(kod), aciklaIng);
        if (r.hata) return { hata: r.hata };
        sira++;
        var id = onEk + ":" + kod + ":" + sira;
        cv.istek(id, r.yontem, r.url, r.basliklar, r.govde);
        return { id: id };
    }

    function gecmiseYaz(kaynak, sonuc, sl, tl, servis, fav) {
        if (!gecmisTut && !fav) return;
        yurut("INSERT INTO gecmis(kaynak, sonuc, sl, tl, servis, t, fav) VALUES(?, ?, ?, ?, ?, ?, ?)", [kaynak, sonuc, sl, tl, servis, new Date().getTime(), fav ? 1 : 0]);
        yurut("DELETE FROM gecmis WHERE fav = 0 AND t < ?", [new Date().getTime() - 60 * 24 * 3600000]);
    }
    function kopyala(metin) {
        if (!metin) return;
        cv.panoya(metin);
        showToast(qsTr("Kopyalandı (") + metin.length + qsTr(" karakter)"));
    }

    function selectTab(i) { tab = Math.max(0, Math.min(3, i)); ayarYaz("tab", tab); if (tab === 2) gecmisSayfasi.yukle(); if (tab === 3) ayarSayfasi.kur(); focusCurrent(); }
    function stepTab(d) { selectTab((tab + d + 4) % 4); }
    function currentPage() { return tab === 0 ? cevirSayfasi : tab === 1 ? sozlukSayfasi : tab === 2 ? gecmisSayfasi : ayarSayfasi; }
    function focusCurrent() {
        if (sheet.shown || input.shown) return;
        if (dilSecici.visible) { dilSecici.takeFocus(); return; }
        currentPage().takeFocus();
    }
    function ortakTus(event) {
        var t = U.tus(event), k = event.key;
        if (U.ctrl(event) && (k === Qt.Key_Q || t === "q")) { Qt.quit(); return true; }
        return false;
    }

    Item {
        id: sayfalar
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: nav.top }
        CevirPage { id: cevirSayfasi; anchors.fill: parent; visible: app.tab === 0 }
        SozlukPage { id: sozlukSayfasi; anchors.fill: parent; visible: app.tab === 1 }
        GecmisPage { id: gecmisSayfasi; anchors.fill: parent; visible: app.tab === 2 }
        AyarPage { id: ayarSayfasi; anchors.fill: parent; visible: app.tab === 3 }
    }

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
                    { t: QT_TR_NOOP("Çevir"), i: "swap" },
                    { t: QT_TR_NOOP("Sözlük"), i: "doc" },
                    { t: QT_TR_NOOP("Geçmiş"), i: "clock" },
                    { t: QT_TR_NOOP("Ayarlar"), i: "gear" }
                ]
                delegate: Item {
                    width: nav.width / 4
                    height: nav.height
                    property bool aktif: index === app.tab
                    Rectangle { anchors.centerIn: parent; width: Math.min(parent.width - 8, ic.width + 24); height: 32; radius: 16; color: aktif ? app.renkler[index][7] : (nma.pressed ? app.pressed : "transparent") }
                    Row {
                        id: ic
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

    DilSecici { id: dilSecici; anchors.fill: parent; anchors.bottomMargin: nav.height; visible: false; z: 20 }
    ActionSheet { id: sheet }
    InputDialog { id: input }
    Toast { id: toast; bottomGap: nav.height + 10 }

    Component.onCompleted: {
        initDb();
        fontSize = parseInt(ayar("fontSize", "19"), 10);
        gecmisTut = ayar("gecmis", "1") === "1";
        panodanAl = ayar("pano", "0") === "1";
        anahtarIceAktar(true);
        cevirSayfasi.hazirla();
        selectTab(parseInt(ayar("tab", "0"), 10));
        cv.kayit("arayuz hazir v" + version);
        if (cv.dosyaVar(cv.veriKlasoru() + "/oto.txt")) { cv.dosyaSil(cv.veriKlasoru() + "/oto.txt"); cv.zamanla("oto1", 2500); }
    }

    // Duman testi (veri klasorunde oto.txt varsa): ceviri ve sozluk servislerini dener, gunluge "OTO" yazar
    function otoTest(adim) {
        var s = function (m) { cv.kayit("OTO " + adim + ": " + m); };
        if (adim === 1) { s("cevir: tr->en, acik servisler " + aktifler("ceviri").length); cevirSayfasi.dilleriVer("auto", "en"); cevirSayfasi.metinVer("Merhaba dünya, bugün hava çok güzel."); cevirSayfasi.cevir(); cv.zamanla("oto2", 12000); }
        else if (adim === 2) { s("sonuc " + cevirSayfasi.ozet()); aktifYap("mymemory", true); cevirSayfasi.dilleriVer("en", "de"); cevirSayfasi.metinVer("The book is on the table."); cevirSayfasi.cevir(); cv.zamanla("oto3", 12000); }
        else if (adim === 3) { s("sonuc " + cevirSayfasi.ozet()); aktifYap("mymemory", false); selectTab(1); sozlukSayfasi.ara("kitap"); cv.zamanla("oto4", 12000); }
        else if (adim === 4) { s("sozluk kitap " + sozlukSayfasi.ozet()); sozlukSayfasi.ara("serendipity"); cv.zamanla("oto5", 12000); }
        else if (adim === 5) { s("sozluk serendipity " + sozlukSayfasi.ozet()); selectTab(2); s("gecmis " + gecmisSayfasi.adet()); selectTab(0); s("BITTI"); }
    }
    Connections { target: cv; onZamanDoldu: if (ad.indexOf("oto") === 0) app.otoTest(parseInt(ad.substring(3), 10)) }
}
