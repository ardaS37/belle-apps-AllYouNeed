import QtQuick 1.1
import "Api.js" as Api
import "Util.js" as U
import "State.js" as St

Rectangle {
    id: app
    width: 640
    height: 480
    color: bg

    // ---------------- Tema (karanlik, turuncu vurgu) ----------------
    property color bg: "#121216"
    property color surface: "#1C1C23"
    property color surface2: "#262630"
    property color pressed: "#2F2F3A"
    property color divider: "#24242C"
    property color textPrimary: "#F2F2F5"
    property color textSecondary: "#9A9AA8"
    property color accent: "#FF8A3D"
    property color accentPressed: "#E0702A"
    property color onAccent: "#1B1206"
    property color danger: "#FF6B6B"
    property color highlight: "#2A2420"

    // ---------------- Ayarlar ----------------
    property string service: "ytmusic"    // varsayilan servis (kisisel derlemede "belle")
    // Kisisel derleme: kaynak "belle" (kendi sunucumuz) ya da "s60" (s60tube), Ayarlar'da degistirilir. Yayin derlemesi hep s60tube.
    property string kaynak: "belle"
    property bool belleModu: kisisel && kaynak === "belle"
    function kaynakSec(k) {
        kaynak = k;
        setSetting("kaynak", k);
        Api.kisisel = belleModu;
        service = belleModu ? "belle" : setting("service", "ytmusic");
        showToast(belleModu ? qsTr("Kaynak: kendi sunucum") : qsTr("Kaynak: s60tube"));
    }
    property bool useRelay: true          // oynatici yerel aktarici uzerinden
    property int volume: 80
    property bool showCovers: true
    // Belle sunucusu: adres + parola (Api.js bunlari kullanir)
    property string belleServer: "https://e6.msahincelen.xyz"
    property string belleKey: ""
    onBelleServerChanged: Api.server = belleServer
    onBelleKeyChanged: Api.key = belleKey

    // Degisince listeler yeniden ciziliyor
    property int favVersion: 0
    property int favListsVersion: 0
    property int dlVersion: 0
    property int plVersion: 0
    property int recentVersion: 0

    // Indirme durumu
    property string dlKey: music.currentKey
    property int dlPercent: 0

    property int tab: 0                   // 0 Kesfet, 1 Ara, 2 Kitaplik, 3 Ayarlar
    property int stackDepth: 0
    property bool playerOpen: false
    property bool sheetOpen: false
    property bool promptOpen: false
    property bool pickerOpen: false

    function showToast(m) { toast.show(m); }

    // Kapaklar dogrudan servislerin kendi resim sunucularindan, telefona uygun boyutta istenir
    // (MIDPlay gibi; ara sunucu yok). s60tube'un /convert kucultme servisi su an kapali.
    //  - NhacCuaTui yalnizca WebP veriyor, Qt 4 acamiyor: yer tutucu gosterilir
    function coverUrl(u, w) {
        if (!u) return "";
        var small = w <= 96;
        if (/^https?:\/\/[^\/]*(nct\.vn|nixcdn\.com)\//.test(u)) return "";
        // YouTube Music liste/albüm/sanatci kapaklari: "=w544-h544-..." son eki boyut belirler; -rj JPEG ister
        if (/^https?:\/\/[^\/]*(ggpht\.com|googleusercontent\.com)\//.test(u)) {
            var s = small ? 120 : 300;
            return u.replace(/=[^\/=]*$/, "") + "=w" + s + "-h" + s + "-l90-rj";
        }
        // Spotify: ab67616d0000b273 = 640px, 00001e02 = 300px, 00004851 = 64px
        if (/^https?:\/\/i\.scdn\.co\//.test(u)) return u.replace("ab67616d0000b273", small ? "ab67616d00004851" : "ab67616d00001e02");
        // SoundCloud: -t250x250 -> -large (100px) / -t300x300
        if (/sndcdn\.com\//.test(u)) return u.replace(/-(t\d+x\d+|large|t500x500|original)\./, small ? "-large." : "-t300x300.");
        return u;
    }

    // YouTube Music listesini baglanti/kimlikle ekle (herkese acik listeler)
    function addListByLink() {
        askText(qsTr("YouTube Music liste bağlantısı"), "", qsTr("Aç"), function (text) {
            var l = Api.ytListFromText(text);
            if (!l) { showToast(qsTr("Bağlantıda liste bulunamadı (…playlist?list=PL… biçiminde olmalı)")); return; }
            openList(l);
        });
    }
    // Liste favorilere kaydedilirken adi bilinmiyorsa sor
    function saveListAsk(l, cb) {
        askText(qsTr("Liste adı"), l.name, qsTr("Kaydet"), function (n) {
            n = n.replace(/^\s+|\s+$/g, "");
            var c = { listKey: l.listKey, name: n !== "" ? n : l.name, singer: l.singer, image: l.image, service: l.service };
            setFavList(c, true);
            showToast("\"" + c.name + qsTr("\" favori listelere kaydedildi"));
            if (cb) cb(c);
        });
    }
    function api() { Api.kisisel = belleModu; return Api; }   // belleModu: kisisel derleme + kaynak "belle"
    function util() { return U; }

    // =====================================================================
    //  Kalici depo (SQLite / LocalStorage)
    // =====================================================================
    function db() { return openDatabaseSync("E6Muzik", "1.0", qsTr("E6Muzik kitapligi"), 8000000); }
    function initDb() {
        db().transaction(function (tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS kv(k TEXT UNIQUE, v TEXT)");
            tx.executeSql("CREATE TABLE IF NOT EXISTS tracks(key TEXT PRIMARY KEY, data TEXT)");
            tx.executeSql("CREATE TABLE IF NOT EXISTS fav(key TEXT PRIMARY KEY, ts INTEGER)");
            tx.executeSql("CREATE TABLE IF NOT EXISTS favlists(lkey TEXT PRIMARY KEY, data TEXT, ts INTEGER)");
            tx.executeSql("CREATE TABLE IF NOT EXISTS pls(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, ts INTEGER)");
            tx.executeSql("CREATE TABLE IF NOT EXISTS plt(pl INTEGER, key TEXT, pos INTEGER)");
            tx.executeSql("CREATE TABLE IF NOT EXISTS recent(key TEXT PRIMARY KEY, ts INTEGER)");
            tx.executeSql("CREATE TABLE IF NOT EXISTS dl(key TEXT PRIMARY KEY, path TEXT, ts INTEGER)");
            tx.executeSql("CREATE TABLE IF NOT EXISTS searches(q TEXT PRIMARY KEY, ts INTEGER)");
        });
    }
    function setting(k, def) {
        var v = def;
        db().readTransaction(function (tx) {
            var rs = tx.executeSql("SELECT v FROM kv WHERE k = ?", [k]);
            if (rs.rows.length > 0) v = rs.rows.item(0).v;
        });
        return v;
    }
    function setSetting(k, v) { db().transaction(function (tx) { tx.executeSql("INSERT OR REPLACE INTO kv(k, v) VALUES(?, ?)", [k, "" + v]); }); }

    function now() { return new Date().getTime(); }
    // Karisik calmadan onceki sira (Player icin)
    function setOrig(list) { St.orig = list.slice(0); }
    function appendOrig(t) { St.orig.push(t); }
    function getOrig() { return St.orig.slice(0); }
    function plain(t) {   // ListModel ogesi -> duz nesne
        return { key: t.key, name: t.name, singer: t.singer, url: t.url, image: t.image, duration: t.duration, service: t.service };
    }
    function saveTrackTx(tx, t) { tx.executeSql("INSERT OR REPLACE INTO tracks(key, data) VALUES(?, ?)", [t.key, JSON.stringify(plain(t))]); }
    function updateTrackUrl(key, url) {
        db().transaction(function (tx) {
            var rs = tx.executeSql("SELECT data FROM tracks WHERE key = ?", [key]);
            if (rs.rows.length === 0) return;
            var t = JSON.parse(rs.rows.item(0).data);
            t.url = url;
            tx.executeSql("UPDATE tracks SET data = ? WHERE key = ?", [JSON.stringify(t), key]);
        });
    }
    function queryTracks(sql, args) {
        var out = [];
        db().readTransaction(function (tx) {
            var rs = tx.executeSql(sql, args || []);
            for (var i = 0; i < rs.rows.length; i++) { try { out.push(JSON.parse(rs.rows.item(i).data)); } catch (e) { } }
        });
        return out;
    }

    // ---- Favori sarkilar ----
    function isFav(key) { return St.fav[key] === true; }
    function setFav(t, on) { setFavMany([t], on); }
    function setFavMany(arr, on) {
        var n = 0;
        db().transaction(function (tx) {
            for (var i = 0; i < arr.length; i++) {
                var t = arr[i];
                if (on) {
                    if (St.fav[t.key]) continue;
                    saveTrackTx(tx, t);
                    tx.executeSql("INSERT OR REPLACE INTO fav(key, ts) VALUES(?, ?)", [t.key, now() + i]);
                    St.fav[t.key] = true;
                } else {
                    tx.executeSql("DELETE FROM fav WHERE key = ?", [t.key]);
                    delete St.fav[t.key];
                }
                n++;
            }
        });
        favVersion++;
        return n;
    }
    function favTracks() { return queryTracks("SELECT t.data FROM fav f JOIN tracks t ON t.key = f.key ORDER BY f.ts DESC"); }
    function favCount() { var n = 0; for (var k in St.fav) n++; return n; }

    // ---- Favori listeler ----
    function isFavList(lkey) { return St.favLists[lkey] === true; }
    function setFavList(l, on) {
        db().transaction(function (tx) {
            if (on) tx.executeSql("INSERT OR REPLACE INTO favlists(lkey, data, ts) VALUES(?, ?, ?)", [l.listKey, JSON.stringify(l), now()]);
            else tx.executeSql("DELETE FROM favlists WHERE lkey = ?", [l.listKey]);
        });
        if (on) St.favLists[l.listKey] = true; else delete St.favLists[l.listKey];
        favListsVersion++;
    }
    function favLists() { return queryTracks("SELECT data FROM favlists ORDER BY ts DESC"); }

    // ---- Kendi listelerim ----
    function myPlaylists() {
        var out = [];
        db().readTransaction(function (tx) {
            var rs = tx.executeSql("SELECT p.id, p.name, (SELECT COUNT(*) FROM plt WHERE plt.pl = p.id) AS n FROM pls p ORDER BY p.ts DESC");
            for (var i = 0; i < rs.rows.length; i++) out.push({ id: rs.rows.item(i).id, name: rs.rows.item(i).name, n: rs.rows.item(i).n });
        });
        return out;
    }
    function createPlaylist(name) {
        var id = 0;
        db().transaction(function (tx) {
            var r = tx.executeSql("INSERT INTO pls(name, ts) VALUES(?, ?)", [name, now()]);
            id = parseInt(r.insertId, 10);
        });
        plVersion++;
        return id;
    }
    function renamePlaylist(id, name) { db().transaction(function (tx) { tx.executeSql("UPDATE pls SET name = ? WHERE id = ?", [name, id]); }); plVersion++; }
    function deletePlaylist(id) {
        db().transaction(function (tx) { tx.executeSql("DELETE FROM plt WHERE pl = ?", [id]); tx.executeSql("DELETE FROM pls WHERE id = ?", [id]); });
        plVersion++;
    }
    function addToPlaylist(id, arr) {
        var added = 0;
        db().transaction(function (tx) {
            var rs = tx.executeSql("SELECT COALESCE(MAX(pos), 0) AS m FROM plt WHERE pl = ?", [id]);
            var pos = rs.rows.item(0).m;
            for (var i = 0; i < arr.length; i++) {
                var ex = tx.executeSql("SELECT 1 FROM plt WHERE pl = ? AND key = ?", [id, arr[i].key]);
                if (ex.rows.length > 0) continue;
                saveTrackTx(tx, arr[i]);
                tx.executeSql("INSERT INTO plt(pl, key, pos) VALUES(?, ?, ?)", [id, arr[i].key, ++pos]);
                added++;
            }
            tx.executeSql("UPDATE pls SET ts = ? WHERE id = ?", [now(), id]);
        });
        plVersion++;
        return added;
    }
    function removeFromPlaylist(id, keys) {
        db().transaction(function (tx) { for (var i = 0; i < keys.length; i++) tx.executeSql("DELETE FROM plt WHERE pl = ? AND key = ?", [id, keys[i]]); });
        plVersion++;
    }
    function playlistTracks(id) { return queryTracks("SELECT t.data FROM plt p JOIN tracks t ON t.key = p.key WHERE p.pl = ? ORDER BY p.pos", [id]); }
    function playlistName(id) {
        var n = "";
        db().readTransaction(function (tx) { var rs = tx.executeSql("SELECT name FROM pls WHERE id = ?", [id]); if (rs.rows.length > 0) n = rs.rows.item(0).name; });
        return n;
    }

    // ---- Son calinanlar ----
    function addRecent(t) {
        db().transaction(function (tx) {
            saveTrackTx(tx, t);
            tx.executeSql("INSERT OR REPLACE INTO recent(key, ts) VALUES(?, ?)", [t.key, now()]);
            tx.executeSql("DELETE FROM recent WHERE key NOT IN (SELECT key FROM recent ORDER BY ts DESC LIMIT 150)");
        });
        recentVersion++;
    }
    function recentTracks() { return queryTracks("SELECT t.data FROM recent r JOIN tracks t ON t.key = r.key ORDER BY r.ts DESC"); }
    function clearRecent() { db().transaction(function (tx) { tx.executeSql("DELETE FROM recent"); }); recentVersion++; }

    // ---- Indirilenler ----
    function downloadPath(key) { return St.dl[key] || ""; }
    function isDownloaded(key) { return St.dl[key] !== undefined; }
    function downloads() { return queryTracks("SELECT t.data FROM dl d JOIN tracks t ON t.key = d.key ORDER BY d.ts DESC"); }
    function removeDownloads(keys) {
        db().transaction(function (tx) {
            for (var i = 0; i < keys.length; i++) {
                if (St.dl[keys[i]]) music.removeFile(St.dl[keys[i]]);
                tx.executeSql("DELETE FROM dl WHERE key = ?", [keys[i]]);
                delete St.dl[keys[i]];
            }
        });
        dlVersion++;
    }
    function download(arr) {
        var n = 0;
        for (var i = 0; i < arr.length; i++) {
            var t = plain(arr[i]);
            if (isDownloaded(t.key) || music.isQueued(t.key)) continue;
            St.dlPending[t.key] = t;
            db().transaction(function (tx) { saveTrackTx(tx, t); });
            startDownload(t);
            n++;
        }
        dlVersion++;
        if (n > 0) showToast(n + qsTr(" şarkı indirme sırasına eklendi"));
        else showToast(qsTr("Seçilen şarkılar zaten indirilmiş"));
    }
    function startDownload(t) {
        var name = (t.singer ? t.singer + " - " : "") + t.name;
        Api.kisisel = belleModu;
        if (belleModu) {
            if (Api.isBelle(t.url)) { music.download(t.key, Api.mediaUrl(t.url), name); return; }
            Api.refresh(t, function (url) { updateTrackUrl(t.key, url); music.download(t.key, Api.mediaUrl(url), name); },
                        function (msg) { delete St.dlPending[t.key]; showToast(msg); });
            return;
        }
        if (Api.isExpired(t.url)) {
            Api.refresh(t, function (url) { updateTrackUrl(t.key, url); music.download(t.key, url, name); },
                        function () { music.download(t.key, t.url, name); });
        } else {
            music.download(t.key, t.url, name);
        }
    }
    Connections {
        target: music
        onProgress: { if (key === app.dlKey) app.dlPercent = total > 0 ? Math.round(received * 100 / total) : 0; }
        onFinished: {
            delete St.dlPending[key];
            if (ok) {
                St.dl[key] = path;
                app.db().transaction(function (tx) { tx.executeSql("INSERT OR REPLACE INTO dl(key, path, ts) VALUES(?, ?, ?)", [key, path, app.now()]); });
                if (music.queueCount === 0) app.showToast(qsTr("İndirmeler tamamlandı"));
            } else if (message !== "İptal edildi") {
                app.showToast(message);
            }
            app.dlPercent = 0;
            app.dlVersion++;
        }
    }

    // ---- Aramalar ----
    function addSearch(q) {
        db().transaction(function (tx) {
            tx.executeSql("INSERT OR REPLACE INTO searches(q, ts) VALUES(?, ?)", [q, now()]);
            tx.executeSql("DELETE FROM searches WHERE q NOT IN (SELECT q FROM searches ORDER BY ts DESC LIMIT 12)");
        });
    }
    function recentSearches() {
        var out = [];
        db().readTransaction(function (tx) { var rs = tx.executeSql("SELECT q FROM searches ORDER BY ts DESC"); for (var i = 0; i < rs.rows.length; i++) out.push(rs.rows.item(i).q); });
        return out;
    }
    function clearSearches() { db().transaction(function (tx) { tx.executeSql("DELETE FROM searches"); }); }

    function loadSets() {
        db().readTransaction(function (tx) {
            var rs = tx.executeSql("SELECT key FROM fav");
            for (var i = 0; i < rs.rows.length; i++) St.fav[rs.rows.item(i).key] = true;
            rs = tx.executeSql("SELECT lkey FROM favlists");
            for (i = 0; i < rs.rows.length; i++) St.favLists[rs.rows.item(i).lkey] = true;
            rs = tx.executeSql("SELECT key, path FROM dl");
            for (i = 0; i < rs.rows.length; i++) St.dl[rs.rows.item(i).key] = rs.rows.item(i).path;
        });
        // Telefondan silinmis dosyalari kitapliktan cikar
        var gone = [];
        for (var k in St.dl) if (!music.fileExists(St.dl[k])) gone.push(k);
        if (gone.length > 0) removeDownloads(gone);
    }

    // =====================================================================
    //  Gezinme: sekmeler + ayrinti sayfasi yigini
    // =====================================================================
    function push(comp, props) {
        var p = comp.createObject(pageHost, props || {});
        if (!p) { showToast(qsTr("Sayfa açılamadı")); return null; }
        if (St.stack.length > 0) St.stack[St.stack.length - 1].visible = false;
        St.stack.push(p);
        stackDepth = St.stack.length;
        focusTop();
        return p;
    }
    function pop() {
        if (St.stack.length === 0) return;
        var p = St.stack.pop();
        p.visible = false;
        p.destroy();
        stackDepth = St.stack.length;
        if (St.stack.length > 0) St.stack[St.stack.length - 1].visible = true;
        focusTop();
    }
    function popAll() { while (St.stack.length > 0) pop(); }
    function topPage() { return St.stack.length > 0 ? St.stack[St.stack.length - 1] : tabPage(tab); }
    function tabPage(i) { return i === 0 ? discoverPage : (i === 1 ? searchPage : (i === 2 ? libraryPage : settingsPage)); }
    function focusTop() { focusTimer.restart(); }
    Timer {
        id: focusTimer; interval: 60
        onTriggered: {
            if (app.playerOpen) { playerPage.takeFocus(); return; }
            var p = app.topPage();
            if (p && p.takeFocus) p.takeFocus(); else if (p) p.forceActiveFocus();
        }
    }
    function selectTab(i) {
        if (St.stack.length > 0 && i === tab) { popAll(); return; }
        popAll();
        tab = i;
        setSetting("tab", i);
        focusTop();
    }
    function stepTab(d) { selectTab((tab + d + 4) % 4); }
    function back() {
        if (sheetOpen) { closeSheet(); return true; }
        if (promptOpen) { promptOpen = false; focusTop(); return true; }
        if (pickerOpen) { pickerOpen = false; focusTop(); return true; }
        if (playerOpen) { if (!playerPage.back()) closePlayer(); return true; }
        if (St.stack.length > 0) { pop(); return true; }
        return false;
    }
    function openPlayer() { if (!player.current) return; playerOpen = true; focusTop(); }
    function closePlayer() { playerOpen = false; focusTop(); }

    // Sayfa acma kisayollari
    function openList(l) { push(trackListComp, { mode: "remote", listInfo: l, title: l.name, subtitle: l.singer, cover: l.image }); }
    function openTracks(mode, title, extra) {
        var props = { mode: mode, title: title };
        if (extra) for (var k in extra) props[k] = extra[k];
        push(trackListComp, props);
    }
    function openLists(mode) { push(listsComp, { mode: mode }); }

    Component { id: trackListComp; TrackListPage { } }
    Component { id: listsComp; ListsPage { } }

    // =====================================================================
    //  Secenek penceresi, metin girisi, liste secici
    // =====================================================================
    // actions: [{label, icon, act}], cb(act)
    function openSheet(title, actions, cb) {
        St.sheetCb = cb;
        sheet.show(title, actions);
        sheetOpen = true;
    }
    function closeSheet() { sheetOpen = false; St.sheetCb = null; focusTop(); }
    function sheetChosen(act) {
        var cb = St.sheetCb;
        sheetOpen = false;
        St.sheetCb = null;
        focusTop();
        if (cb) cb(act);
    }
    function askText(title, initial, okLabel, cb) {
        St.promptCb = cb;
        prompt.show(title, initial, okLabel);
        promptOpen = true;
    }
    function promptDone(text) {
        var cb = St.promptCb;
        promptOpen = false;
        St.promptCb = null;
        focusTop();
        if (cb) cb(text);
    }
    // "Listeye ekle": once liste secilir (ya da yeni liste olusturulur)
    function pickPlaylist(arr) {
        if (!arr || arr.length === 0) return;
        St.pickTracks = [];
        for (var i = 0; i < arr.length; i++) St.pickTracks.push(plain(arr[i]));
        picker.reload();
        pickerOpen = true;
    }
    function pickedPlaylist(id) {
        pickerOpen = false;
        var arr = St.pickTracks;
        focusTop();
        if (id === 0) {
            askText(qsTr("Yeni liste adı"), "", qsTr("Oluştur"), function (name) {
                name = name.replace(/^\s+|\s+$/g, "");
                if (name === "") return;
                var nid = createPlaylist(name);
                var n = addToPlaylist(nid, arr);
                showToast("\"" + name + qsTr("\" oluşturuldu, ") + n + qsTr(" şarkı eklendi"));
            });
            return;
        }
        var added = addToPlaylist(id, arr);
        showToast(added > 0 ? added + qsTr(" şarkı \"") + playlistName(id) + qsTr("\" listesine eklendi") : qsTr("Şarkılar zaten listede"));
    }

    // Tek sarki icin secenekler (uzun basma / ... dugmesi)
    function trackMenu(t, extraActions, extraCb) {
        t = plain(t);
        var acts = [
            { label: qsTr("Şimdi çal"), icon: "play", act: "play" },
            { label: qsTr("Sıradaki olarak çal"), icon: "next", act: "next" },
            { label: qsTr("Kuyruğa ekle"), icon: "queue", act: "queue" },
            { label: isFav(t.key) ? qsTr("Favorilerden çıkar") : qsTr("Favorilere ekle"), icon: isFav(t.key) ? "heart" : "heart_o", act: "fav" },
            { label: qsTr("Listeye ekle"), icon: "plus", act: "pl" },
            { label: isDownloaded(t.key) ? qsTr("İndirildi") : (music.isQueued(t.key) ? qsTr("İndirme sırada") : qsTr("İndir")), icon: isDownloaded(t.key) ? "done" : "download", act: "dl" },
            { label: qsTr("Bu sanatçıyı ara"), icon: "search", act: "artist" }
        ];
        if (extraActions) acts = acts.concat(extraActions);
        openSheet(t.name + (t.singer ? " – " + t.singer : ""), acts, function (a) {
            if (a === "play") player.playTracks([t], 0, false);
            else if (a === "next") { player.playNext([t]); showToast(qsTr("Sıradaki şarkı: ") + t.name); }
            else if (a === "queue") { player.enqueue([t]); showToast(qsTr("Kuyruğa eklendi")); }
            else if (a === "fav") { var on = !isFav(t.key); setFav(t, on); showToast(on ? qsTr("Favorilere eklendi") : qsTr("Favorilerden çıkarıldı")); }
            else if (a === "pl") pickPlaylist([t]);
            else if (a === "dl") { if (!isDownloaded(t.key)) download([t]); }
            else if (a === "artist") searchFor(t.singer.split(",")[0]);
            else if (extraCb) extraCb(a, t);
        });
    }
    // Sunucudaki bir listenin sarkilarini getirip islem yapar
    function withListTracks(l, cb) {
        showToast(qsTr("Liste yükleniyor..."));
        Api.tracks(l.listKey, l.service, function (items) {
            var arr = [];
            for (var i = 0; i < items.length; i++) arr.push(Api.toTrack(items[i], l.service));
            if (arr.length === 0) { showToast(qsTr("Bu listede şarkı yok")); return; }
            cb(arr);
        }, function (msg) { showToast(msg); });
    }
    function playRemoteList(l, sh) { withListTracks(l, function (arr) { player.playTracks(arr, 0, sh); }); }
    function listMenu(l) {
        var fav = isFavList(l.listKey);
        openSheet(l.name, [
            { label: qsTr("Aç"), icon: "list", act: "open" },
            { label: qsTr("Çal"), icon: "play", act: "play" },
            { label: qsTr("Karışık çal"), icon: "shuffle", act: "shuffle" },
            { label: qsTr("Kuyruğa ekle"), icon: "queue", act: "queue" },
            { label: fav ? qsTr("Listeyi favorilerden çıkar") : qsTr("Listeyi favorilere kaydet"), icon: fav ? "heart" : "heart_o", act: "favlist" },
            { label: qsTr("Tüm şarkıları favorilere ekle"), icon: "heart", act: "favall" },
            { label: qsTr("Tüm şarkıları listeme ekle"), icon: "plus", act: "plall" },
            { label: qsTr("Tüm şarkıları indir"), icon: "download", act: "dlall" }
        ], function (a) {
            if (a === "open") openList(l);
            else if (a === "play") playRemoteList(l, false);
            else if (a === "shuffle") playRemoteList(l, true);
            else if (a === "queue") withListTracks(l, function (arr) { player.enqueue(arr); showToast(arr.length + qsTr(" şarkı kuyruğa eklendi")); });
            else if (a === "favlist") {
                if (!fav && l.askName) { saveListAsk(l); return; }
                setFavList(l, !fav);
                showToast(!fav ? qsTr("Liste favorilere kaydedildi") : qsTr("Liste favorilerden çıkarıldı"));
            }
            else if (a === "favall") withListTracks(l, function (arr) { var n = setFavMany(arr, true); showToast(n + qsTr(" şarkı favorilere eklendi")); });
            else if (a === "plall") withListTracks(l, function (arr) { pickPlaylist(arr); });
            else if (a === "dlall") withListTracks(l, function (arr) { download(arr); });
        });
    }

    function searchFor(q) {
        closePlayer();
        popAll();
        tab = 1;
        searchPage.search(q);
    }

    // =====================================================================
    //  Oturum (kuyruk ve konum) - uygulama yeniden acilinca kaldigi yerden
    // =====================================================================
    function saveSession() {
        if (!player.current) return;
        var q = [];
        var from = Math.max(0, player.index - 50), to = Math.min(player.queue.count, from + 200);
        for (var i = from; i < to; i++) q.push(plain(player.queue.get(i)));
        setSetting("session", JSON.stringify({ q: q, i: player.index - from, pos: player.position, sh: player.shuffle, rp: player.repeat }));
    }
    function loadSession() {
        var s = setting("session", "");
        if (s === "") return;
        try {
            var j = JSON.parse(s);
            if (j.q && j.q.length > 0) player.restore(j.q, j.i || 0, j.pos || 0, j.sh === true, j.rp || 0);
        } catch (e) { }
    }

    Component.onCompleted: {
        initDb();
        kaynak = setting("kaynak", "belle");
        Api.kisisel = belleModu;
        service = belleModu ? "belle" : setting("service", "ytmusic");
        belleServer = setting("belleServer", "https://e6.msahincelen.xyz");
        belleKey = setting("belleKey", "");
        useRelay = setting("relay", "1") === "1";
        volume = parseInt(setting("volume", "80"), 10);
        showCovers = setting("covers", "1") === "1";
        loadSets();
        loadSession();
        tab = parseInt(setting("tab", "0"), 10);
        if (belleModu && belleKey === "") tab = 3;     // ilk acilista sunucu parolasi girilsin
        music.log("BelleMusic acildi");
        focusTop();
    }

    // =====================================================================
    //  Ekran
    // =====================================================================
    Player { id: player }

    Item {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: mini.top }
        DiscoverPage { id: discoverPage; anchors.fill: parent; visible: app.tab === 0 && app.stackDepth === 0 }
        SearchPage { id: searchPage; anchors.fill: parent; visible: app.tab === 1 && app.stackDepth === 0 }
        LibraryPage { id: libraryPage; anchors.fill: parent; visible: app.tab === 2 && app.stackDepth === 0 }
        SettingsPage { id: settingsPage; anchors.fill: parent; visible: app.tab === 3 && app.stackDepth === 0 }
        Item { id: pageHost; anchors.fill: parent }
    }

    MiniPlayer {
        id: mini
        anchors { left: parent.left; right: parent.right; bottom: nav.top }
        height: player.current ? 56 : 0
        visible: player.current ? true : false
    }

    BottomNav {
        id: nav
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        current: app.tab
        onSelected: app.selectTab(index)
    }

    PlayerPage { id: playerPage; anchors.fill: parent; visible: app.playerOpen; z: 5 }

    ActionSheet { id: sheet; anchors.fill: parent; visible: app.sheetOpen; z: 10 }
    PlaylistPicker { id: picker; anchors.fill: parent; visible: app.pickerOpen; z: 10 }
    Prompt { id: prompt; anchors.fill: parent; visible: app.promptOpen; z: 11 }

    // Ses seviyesi gostergesi
    Rectangle {
        id: volBox
        z: 20
        anchors.centerIn: parent
        width: 260; height: 70; radius: 16
        color: "#E6202028"
        opacity: volHide.running ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Image { id: volIcon; anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter } width: 34; height: 34; smooth: true; source: "../images/volume_w.png" }
        Rectangle {
            anchors { left: volIcon.right; leftMargin: 14; right: volText.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
            height: 8; radius: 4; color: "#44FFFFFF"
            Rectangle { width: parent.width * app.volume / 100; height: parent.height; radius: 4; color: app.accent }
        }
        Text { id: volText; anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter } text: app.volume; color: "white"; font.pixelSize: 20; font.bold: true; width: 40; horizontalAlignment: Text.AlignRight }
    }
    Timer { id: volHide; interval: 1400 }
    function changeVolume(d) {
        volume = Math.max(0, Math.min(100, volume + d));
        volHide.restart();
        volSave.restart();
    }
    Timer { id: volSave; interval: 800; onTriggered: app.setSetting("volume", app.volume) }

    Connections {
        target: keys
        onUp: app.changeVolume(5)
        onDown: app.changeVolume(-5)
        onPlayPause: player.toggle()
        onNext: player.next(true)
        onPrevious: player.prev()
        onStop: player.pause()
    }

    Toast { id: toast; z: 30 }
}
