import QtQuick 1.1
import QtMultimediaKit 1.1

// Calma motoru: kuyruk, karisik, tekrar, uyku zamanlayicisi, hata kurtarma
Item {
    id: player

    property alias queue: queueModel
    property int index: -1
    property variant current: null
    property bool shuffle: false
    property int repeat: 0                 // 0 kapali, 1 tumu, 2 tek sarki
    property bool wantPlay: false          // kullanici calmak istiyor (yuklenirken de)
    property bool loading: wantPlay && (current ? true : false) && !playing && aud.status !== Audio.EndOfMedia
    property bool playing: aud.playing && !aud.paused
    property int position: aud.position
    property int duration: aud.duration > 0 ? aud.duration : (current ? current.duration * 1000 : 0)
    property int lastPos: 0
    property int attempts: 0               // ayni sarkida art arda hata sayisi
    property bool directThisTrack: false   // aktarici sorun cikarirsa bu sarkida dogrudan dene
    property string status: ""

    // Uyku zamanlayicisi
    property double sleepAt: 0             // ms (epoch); 0 = kapali
    property bool sleepEndOfTrack: false
    property int sleepLeft: 0              // kalan saniye (gosterim)

    ListModel { id: queueModel }

    function trackAt(i) { return (i >= 0 && i < queueModel.count) ? app.plain(queueModel.get(i)) : null; }

    // ---------------- Kuyruk ----------------
    function fill(arr) {
        queueModel.clear();
        for (var i = 0; i < arr.length; i++) queueModel.append(app.plain(arr[i]));
    }
    // Listeyi cal: start konumundan; shuffleIt=true ise karisik (start bastan rastgele)
    function playTracks(arr, start, shuffleIt) {
        if (!arr || arr.length === 0) return;
        var list = [];
        for (var i = 0; i < arr.length; i++) list.push(app.plain(arr[i]));
        storeOrig(list);
        if (shuffleIt === true) shuffle = true;
        if (shuffle) {
            var first = (shuffleIt === true) ? null : list[start];
            var rest = [];
            for (i = 0; i < list.length; i++) if (shuffleIt === true || i !== start) rest.push(list[i]);
            rest = app.util().shuffled(rest);
            if (first) rest.unshift(first);
            fill(rest);
            index = 0;
        } else {
            fill(list);
            index = Math.max(0, Math.min(start, list.length - 1));
        }
        startCurrent(true, 0);
    }
    function storeOrig(list) { app.setOrig(list); }

    function enqueue(arr) {
        for (var i = 0; i < arr.length; i++) { queueModel.append(app.plain(arr[i])); app.appendOrig(app.plain(arr[i])); }
        if (index < 0) { index = 0; startCurrent(true, 0); }
    }
    function playNext(arr) {
        if (index < 0) { playTracks(arr, 0, false); return; }
        for (var i = arr.length - 1; i >= 0; i--) { queueModel.insert(index + 1, app.plain(arr[i])); app.appendOrig(app.plain(arr[i])); }
    }
    function removeAt(i) {
        if (i < 0 || i >= queueModel.count) return;
        if (i === index) {
            queueModel.remove(i);
            if (queueModel.count === 0) { stopAll(); index = -1; current = null; return; }
            if (index >= queueModel.count) index = 0;
            startCurrent(wantPlay, 0);
            return;
        }
        queueModel.remove(i);
        if (i < index) index--;
    }
    function moveItem(from, to) {
        if (from === to || from < 0 || to < 0 || from >= queueModel.count || to >= queueModel.count) return;
        queueModel.move(from, to, 1);
        if (index === from) index = to;
        else if (from < index && to >= index) index--;
        else if (from > index && to <= index) index++;
    }
    function jumpTo(i) { if (i >= 0 && i < queueModel.count) { index = i; startCurrent(true, 0); } }
    function clearUpcoming() {
        while (queueModel.count > index + 1) queueModel.remove(queueModel.count - 1);
    }

    function setShuffle(on) {
        if (on === shuffle) return;
        shuffle = on;
        if (queueModel.count < 2 || index < 0) return;
        var cur = trackAt(index);
        var list = [];
        if (on) {
            for (var i = 0; i < queueModel.count; i++) if (i !== index) list.push(trackAt(i));
            list = app.util().shuffled(list);
            list.unshift(cur);
            fill(list);
            index = 0;
        } else {
            list = app.getOrig();
            if (list.length === 0) return;
            fill(list);
            index = 0;
            for (i = 0; i < list.length; i++) if (list[i].key === cur.key) { index = i; break; }
        }
        app.saveSession();
    }
    function cycleRepeat() { repeat = (repeat + 1) % 3; app.saveSession(); }

    // ---------------- Calma ----------------
    function startCurrent(autoplay, pos) {
        var t = trackAt(index);
        if (!t) return;
        current = t;
        attempts = 0;
        directThisTrack = false;
        lastPos = pos || 0;
        wantPlay = autoplay;
        if (autoplay) app.addRecent(t);
        resolveAndPlay(t, false);
        app.saveSession();
    }

    function resolveAndPlay(t, forceRefresh) {
        var local = app.downloadPath(t.key);
        if (local !== "" && music.fileExists(local)) { go(local, true); return; }
        var key = t.key;
        if (app.belleModu) {
            if (!forceRefresh && app.api().isBelle(t.url)) {
                // Kisisel: sunucu sesi ilk kez hazirlarken (30-60 sn) oynatici zaman asimina dusmesin diye once beklenir
                status = qsTr("Sunucuda hazırlanıyor...");
                app.api().prepare(t.url, function () {
                    if (!current || current.key !== key) return;
                    go(app.api().mediaUrl(t.url), false);
                }, function (msg) {
                    if (!current || current.key !== key) return;
                    failTrack(msg);
                });
                return;
            }
            // sunucuda olmayan eski adres (ya da calmadi): sarki sunucuda adla yeniden aranir
            status = qsTr("Adres yenileniyor...");
            app.api().refresh(t, function (url) {
                if (!current || current.key !== key) return;
                updateUrl(key, url);
                var n = app.plain(current); n.url = url;
                resolveAndPlay(n, false);
            }, function (msg) {
                if (!current || current.key !== key) return;
                failTrack(msg);
            });
            return;
        }
        if (forceRefresh || app.api().isExpired(t.url)) {
            status = qsTr("Adres yenileniyor...");
            app.api().refresh(t, function (url) {
                if (!current || current.key !== key) return;
                updateUrl(key, url);
                go(url, false);
            }, function (msg) {
                if (!current || current.key !== key) return;
                if (forceRefresh) failTrack(msg); else go(t.url, false);
            });
            return;
        }
        go(t.url, false);
    }
    function updateUrl(key, url) {
        for (var i = 0; i < queueModel.count; i++) if (queueModel.get(i).key === key) queueModel.setProperty(i, "url", url);
        app.updateTrackUrl(key, url);
        var c = current;
        if (c && c.key === key) { var n = app.plain(c); n.url = url; current = n; }
    }
    function go(src, isLocal) {
        status = "";
        aud.stop();
        aud.source = "";
        aud.seekTo = lastPos;
        var s;
        if (app.useRelay && !directThisTrack) s = music.streamUrl(src);
        else s = isLocal ? music.fileUrl(src) : src;
        music.log("cal: " + (current ? current.name : "") + (isLocal ? " [yerel]" : "") + (s.indexOf("127.0.0.1") >= 0 ? " [aktarici]" : " [dogrudan]"));
        aud.source = s;
        if (wantPlay) aud.play();
    }
    function stopAll() { aud.stop(); aud.source = ""; wantPlay = false; }

    function toggle() {
        if (!current) return;
        if (playing) { pause(); return; }
        play();
    }
    function play() {
        if (!current) return;
        wantPlay = true;
        if (aud.source === "" || aud.status === Audio.NoMedia || aud.status === Audio.InvalidMedia) { app.addRecent(current); resolveAndPlay(current, false); }
        else aud.play();
    }
    function pause() { wantPlay = false; if (aud.playing) aud.pause(); app.saveSession(); }

    function next(user) {
        if (queueModel.count === 0) return;
        if (index < queueModel.count - 1) index++;
        else if (repeat === 1 || user) index = 0;
        else { pause(); aud.position = 0; return; }
        startCurrent(true, 0);
    }
    function prev() {
        if (queueModel.count === 0) return;
        if (aud.position > 4000) { seek(0); return; }
        if (index > 0) index--;
        else if (repeat === 1) index = queueModel.count - 1;
        startCurrent(true, 0);
    }
    function seek(ms) {
        ms = Math.max(0, Math.min(Math.floor(ms), Math.max(0, duration - 1500)));
        if (aud.source === "") { lastPos = ms; return; }
        aud.position = ms;
        lastPos = ms;
    }
    function seekBy(sec) { seek(position + sec * 1000); }

    // Hata: 1) adresi yenile  2) aktaricisiz dene  3) sonraki sarkiya gec
    property double lastErrAt: 0
    function onPlaybackError(msg) {
        var t0 = new Date().getTime();
        if (t0 - lastErrAt < 800) return;          // ayni hata hem error hem InvalidMedia olarak gelebilir
        lastErrAt = t0;
        music.log("hata: " + msg + " (" + (current ? current.name : "") + ")");
        attempts++;
        var t = current;
        if (!t) return;
        if (attempts === 1 && app.downloadPath(t.key) === "") { resolveAndPlay(t, true); return; }
        if (attempts <= 2 && app.useRelay && !directThisTrack) { directThisTrack = true; resolveAndPlay(t, false); return; }
        failTrack(msg);
    }
    function failTrack(msg) {
        status = qsTr("Çalınamadı");
        app.showToast(qsTr("Çalınamadı: ") + (current ? current.name : "") + (msg ? " (" + msg + ")" : ""));
        if (queueModel.count > 1 && index < queueModel.count - 1) skipTimer.start();
        else wantPlay = false;
    }
    Timer { id: skipTimer; interval: 1500; onTriggered: player.next(false) }

    // Uygulama acilisinda son oturum (calmaz, kaldigi yerden bekler)
    function restore(arr, i, pos, sh, rp) {
        fill(arr);
        app.setOrig(arr);
        shuffle = sh;
        repeat = rp;
        index = Math.max(0, Math.min(i, arr.length - 1));
        current = trackAt(index);
        lastPos = pos;
        wantPlay = false;
    }

    // ---------------- Uyku zamanlayicisi ----------------
    function setSleep(minutes) {
        sleepEndOfTrack = false;
        if (minutes <= 0) { sleepAt = 0; sleepLeft = 0; app.showToast(qsTr("Uyku zamanlayıcısı kapatıldı")); return; }
        sleepAt = new Date().getTime() + minutes * 60000;
        sleepLeft = minutes * 60;
        app.showToast(qsTr("Müzik ") + minutes + qsTr(" dakika sonra duracak"));
    }
    function sleepAfterTrack() { sleepAt = 0; sleepEndOfTrack = true; app.showToast(qsTr("Bu şarkı bitince duracak")); }
    Timer {
        interval: 1000; repeat: true; running: player.sleepAt > 0
        onTriggered: {
            var left = Math.round((player.sleepAt - new Date().getTime()) / 1000);
            player.sleepLeft = Math.max(0, left);
            if (left <= 0) { player.sleepAt = 0; player.pause(); app.showToast(qsTr("Uyku zamanlayıcısı: müzik durduruldu")); }
        }
    }

    // Calarken konumu ara ara kaydet
    Timer { interval: 15000; repeat: true; running: player.playing; onTriggered: app.saveSession() }

    // Symbian'in oynaticisi her yeni sarkida sesi kendi varsayilanina cekiyor ve bunu calma BASLADIKTAN
    // sonra da yapabiliyor (kullanici her sarkida sesi yeniden ayarlamak zorunda kaliyordu).
    // Cozum: sarki baslayinca ilk ~6 saniye boyunca sesi yarim saniyede bir yeniden uygula.
    property int volTries: 0
    function kickVolume() { volTries = 0; aud.applyVolume(); volFix.restart(); }
    Timer {
        id: volFix
        interval: 500; repeat: true
        onTriggered: { aud.applyVolume(); player.volTries++; if (player.volTries >= 12) stop(); }
    }

    Audio {
        id: aud
        property int seekTo: 0
        // Oynatici dosya yuklerken sesi sifirlayabiliyor: yuklenince/calinca yeniden uygula (E6Tube)
        function applyVolume() { var v = app.volume / 100; volume = v > 0.01 ? v - 0.01 : 0.01; volume = v; }
        Component.onCompleted: volume = app.volume / 100
        onPlayingChanged: if (playing) player.kickVolume()
        onSourceChanged: player.kickVolume()
        onStatusChanged: {
            if (status === Audio.Loaded || status === Audio.Buffered) {
                player.kickVolume();
                if (seekTo > 0) { position = seekTo; seekTo = 0; }
            }
            if (status === Audio.EndOfMedia) {
                if (player.sleepEndOfTrack) { player.sleepEndOfTrack = false; player.wantPlay = false; app.showToast(qsTr("Uyku zamanlayıcısı: müzik durduruldu")); return; }
                if (player.repeat === 2) { player.startCurrent(true, 0); return; }
                player.next(false);
            }
            if (status === Audio.InvalidMedia) player.onPlaybackError(qsTr("geçersiz ortam"));
        }
        onPositionChanged: if (position > 0) player.lastPos = position
        onError: if (error !== Audio.NoError) player.onPlaybackError(errorString)
    }
    Connections { target: app; onVolumeChanged: aud.volume = app.volume / 100 }
}
