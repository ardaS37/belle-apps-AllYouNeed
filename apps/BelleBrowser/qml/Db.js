.pragma library
// Yer imleri ve gecmis (QML LocalStorage)
var _db = null;
function db() {
    if (_db) return _db;
    _db = openDatabaseSync("BelleBrowser", "1.0", qsTr("Belle Browser"), 2000000);
    _db.transaction(function (tx) {
        tx.executeSql("CREATE TABLE IF NOT EXISTS fav (url TEXT PRIMARY KEY, baslik TEXT, zaman INTEGER)");
        tx.executeSql("CREATE TABLE IF NOT EXISTS gecmis (url TEXT PRIMARY KEY, baslik TEXT, zaman INTEGER, sayi INTEGER)");
    });
    return _db;
}
function simdi() { return Math.round(new Date().getTime() / 1000); }
function favEkle(url, baslik) { db().transaction(function (tx) { tx.executeSql("INSERT OR REPLACE INTO fav VALUES (?,?,?)", [url, baslik || url, simdi()]); }); }
function favSil(url) { db().transaction(function (tx) { tx.executeSql("DELETE FROM fav WHERE url = ?", [url]); }); }
function favMi(url) { var v = false; db().readTransaction(function (tx) { v = tx.executeSql("SELECT 1 FROM fav WHERE url = ?", [url]).rows.length > 0; }); return v; }
function favlar() {
    var l = [];
    db().readTransaction(function (tx) { var r = tx.executeSql("SELECT url, baslik FROM fav ORDER BY zaman DESC"); for (var i = 0; i < r.rows.length; i++) l.push({ url: r.rows.item(i).url, baslik: r.rows.item(i).baslik }); });
    return l;
}
function gecmisEkle(url, baslik) {
    if (!url || /^(about|data|file):/.test(url)) return;
    db().transaction(function (tx) {
        var r = tx.executeSql("SELECT sayi FROM gecmis WHERE url = ?", [url]);
        var n = r.rows.length ? r.rows.item(0).sayi + 1 : 1;
        tx.executeSql("INSERT OR REPLACE INTO gecmis VALUES (?,?,?,?)", [url, baslik || url, simdi(), n]);
        if (Math.random() < 0.05) tx.executeSql("DELETE FROM gecmis WHERE zaman < ?", [simdi() - 90 * 86400]);
    });
}
function gecmis(n) {
    var l = [];
    db().readTransaction(function (tx) { var r = tx.executeSql("SELECT url, baslik, zaman FROM gecmis ORDER BY zaman DESC LIMIT ?", [n || 200]); for (var i = 0; i < r.rows.length; i++) l.push({ url: r.rows.item(i).url, baslik: r.rows.item(i).baslik, zaman: r.rows.item(i).zaman }); });
    return l;
}
function gecmisSil() { db().transaction(function (tx) { tx.executeSql("DELETE FROM gecmis"); }); }
// Adres cubugu onerileri: yer imleri + sik ziyaret edilenler
function oner(q) {
    var l = [], g = {};
    q = "%" + q + "%";
    db().readTransaction(function (tx) {
        var r = tx.executeSql("SELECT url, baslik FROM fav WHERE url LIKE ? OR baslik LIKE ? LIMIT 4", [q, q]);
        for (var i = 0; i < r.rows.length; i++) { l.push({ url: r.rows.item(i).url, baslik: r.rows.item(i).baslik, fav: true }); g[r.rows.item(i).url] = 1; }
        r = tx.executeSql("SELECT url, baslik FROM gecmis WHERE url LIKE ? OR baslik LIKE ? ORDER BY sayi DESC, zaman DESC LIMIT 8", [q, q]);
        for (var j = 0; j < r.rows.length; j++) if (!g[r.rows.item(j).url]) l.push({ url: r.rows.item(j).url, baslik: r.rows.item(j).baslik, fav: false });
    });
    return l;
}
// Sik ziyaret edilenler (baslangic sayfasi)
function sikZiyaret(n) {
    var l = [];
    db().readTransaction(function (tx) { var r = tx.executeSql("SELECT url, baslik FROM gecmis ORDER BY sayi DESC LIMIT ?", [n || 8]); for (var i = 0; i < r.rows.length; i++) l.push({ url: r.rows.item(i).url, baslik: r.rows.item(i).baslik }); });
    return l;
}
