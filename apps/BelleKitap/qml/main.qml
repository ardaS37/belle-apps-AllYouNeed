import QtQuick 1.1
import "Util.js" as U

// BelleKitap: EPUB (ve kitap klasorlerindeki TXT) okuyucu. Iki ekran: Kitaplik ve Okuyucu.
Rectangle {
    id: app
    width: 640
    height: 480
    color: bg
    property string version: "0.3"

    // ---- Uygulama temasi (lila pastel) ----
    property color brand: "#C9A7EB"
    property color brandPressed: "#B08DD6"
    property color bg: "#15111B"
    property color surface: "#201A29"
    property color highlight: "#30283F"
    property color pressed: "#251F31"
    property color markBg: "#241D33"
    property color pill: "#372C50"
    property color fieldBg: "#271F33"
    property color divider: "#2D2538"
    property color textPrimary: "#F2F4F5"
    property color textSecondary: "#A3ADB6"
    property color danger: "#F47C8A"
    property int fontSize: 19
    property real yazi: Math.max(0.8, Math.min(1.7, fontSize / 19))
    property bool ing: (dil.secim === "auto" ? dil.kod : dil.secim) === "en"

    // ---- Okuma ayarlari ----
    //  temalar: [ad, zemin, yazi, ikincil]
    property variant temalar: [
        [QT_TR_NOOP("Gündüz"), "#F5F1E8", "#1E1E1E", "#6B6458"],
        [QT_TR_NOOP("Sepya"), "#EEDFC0", "#3A2E1E", "#7A6648"],
        [QT_TR_NOOP("Gece"), "#121212", "#CACACA", "#7A7A7A"],
        [QT_TR_NOOP("Gece mavisi"), "#0F1720", "#B9C8D6", "#6C7E90"]
    ]
    property int tema: 1
    property int okuFont: 22
    property int kenar: 24

    function showToast(m) { toast.show(m); }
    function db() { return openDatabaseSync("BelleKitap", "1.0", "BelleKitap", 2000000); }
    function initDb() {
        db().transaction(function (tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS kv(k TEXT UNIQUE, v TEXT)");
            tx.executeSql("CREATE TABLE IF NOT EXISTS konum(yol TEXT UNIQUE, bolum INTEGER, parca INTEGER, oran REAL, yuzde REAL, t REAL)");
            tx.executeSql("CREATE TABLE IF NOT EXISTS yerimi(yol TEXT, bolum INTEGER, parca INTEGER, oran REAL, yuzde REAL, etiket TEXT, t REAL)");
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
    function konum(yol) {
        var r = sorgu("SELECT * FROM konum WHERE yol = ?", [yol]);
        return r.length ? { bolum: Number(r[0].bolum) || 0, parca: Number(r[0].parca) || 0, oran: Number(r[0].oran) || 0, yuzde: Number(r[0].yuzde) || 0, t: Number(r[0].t) || 0 } : null;
    }

    function kitapAc(yol) { okuyucu.ac(yol); }
    function kitapliga() { okuyucu.visible = false; kitaplik.yenile(); if (kitapBul.visible) kitapBul.takeFocus(); else kitaplik.takeFocus(); }

    KitaplikPage { id: kitaplik; anchors.fill: parent }
    KitapBulPage { id: kitapBul; anchors.fill: parent; visible: false; z: 8 }
    OkuyucuPage { id: okuyucu; anchors.fill: parent; visible: false; z: 10 }
    ActionSheet { id: sheet }
    InputDialog { id: input }
    Toast { id: toast; bottomGap: 30 }

    function focusCurrent() {
        if (sheet.shown || input.shown) return;
        if (okuyucu.visible) okuyucu.takeFocus(); else if (kitapBul.visible) kitapBul.takeFocus(); else kitaplik.takeFocus();
    }

    // Duman testi (veri klasorunde oto.txt): tara, ilk kitabi ac, sayfa cevir, gunluge "OTO" yaz
    property int otoBekle: 0
    function otoTest(adim) {
        var s = function (m) { kt.kayit("OTO " + adim + ": " + m); };
        if (adim === 1) { s("tarama"); kt.tara(); kt.zamanla("oto2", 25000); }
        else if (adim === 2 && kt.taraniyor && otoBekle++ < 30) { kt.zamanla("oto2", 5000); }
        else if (adim === 2) { var l = kt.kutuphane(); s("kitap sayisi " + l.length + (l.length ? " ilk: " + l[0].baslik + " / " + l[0].yazar + " kapak=" + (l[0].kapak !== "") : "") + " taraniyor=" + kt.taraniyor); if (l.length) kitapAc(l[0].yol); kt.zamanla("oto3", 8000); }
        else if (adim === 3) { s("okuyucu " + okuyucu.durum()); okuyucu.ileri(); okuyucu.ileri(); okuyucu.bolumGit(okuyucu.bolumSayisi > 3 ? 3 : 0); kt.zamanla("oto4", 6000); }
        else if (adim === 4) { s("ilerleme " + okuyucu.durum()); okuyucu.kapat(); s("konum kaydi " + sorgu("SELECT COUNT(*) AS n FROM konum")[0].n); kitapBul.ac(); kitapBul.testAra("gutenberg", "sherlock holmes"); kt.zamanla("oto5", 20000); }
        else if (adim === 5) { s("gutenberg " + kitapBul.ozet()); kitapBul.testIndir(); kt.zamanla("oto6", 45000); }
        else if (adim === 6) { s("indirme sonrasi " + kitapBul.ozet() + " kitaplik=" + kt.kutuphane().length); kitapBul.testAra("vikikaynak", "Kaşağı"); kt.zamanla("oto7", 15000); }
        else if (adim === 7) { s("vikikaynak " + kitapBul.ozet()); kitapBul.testIndir(); kt.zamanla("oto8", 30000); }
        else if (adim === 8) { var l2 = kt.kutuphane(); s("son " + kitapBul.ozet() + " kitaplik=" + l2.length + " ilk=" + (l2.length ? l2[0].baslik + " (" + l2[0].tur + ")" : "-")); kitapBul.kapat(); s("BITTI"); }
    }
    Connections { target: kt; onZamanDoldu: if (ad.indexOf("oto") === 0) app.otoTest(parseInt(ad.substring(3), 10)) }

    Component.onCompleted: {
        initDb();
        fontSize = parseInt(ayar("fontSize", "19"), 10);
        tema = parseInt(ayar("tema", "1"), 10);
        okuFont = parseInt(ayar("okuFont", "22"), 10);
        kenar = parseInt(ayar("kenar", "24"), 10);
        kitaplik.yenile();
        if (kt.kutuphane().length === 0 && !kt.dosyaVar(kt.veriKlasoru() + "/oto.txt")) kt.tara();
        kitaplik.takeFocus();
        kt.kayit("arayuz hazir v" + version);
        if (kt.dosyaVar(kt.veriKlasoru() + "/oto.txt")) { kt.dosyaSil(kt.veriKlasoru() + "/oto.txt"); kt.zamanla("oto1", 2500); }
    }
}
