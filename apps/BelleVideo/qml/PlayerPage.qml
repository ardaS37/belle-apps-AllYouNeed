import QtQuick 1.1
import QtMultimediaKit 1.1
import BelleVideo 1.0
import "Util.js" as U

// Oynatici. Video, Symbian'in yerel video penceresinde (NativeVideo) oynar; bu pencere QML'in
// ustunde durdugu icin kontroller videonun ALTINDAKI seritte. Tam ekranda serit gizlenir,
// bir tusa basilinca kisa sure gorunur.
//
// Arka plan / kilit: video katmani yok edilir, ayni dosya ayni saniyeden yalnizca ses olarak
// devam eder (Star Player'in "arka planda video" ozelligi). One donunce goruntu kaldigi yerden.
// "Sadece ses" modu: video hic cozulmez, pil dostu.
Rectangle {
    id: root
    color: "#000000"

    // ---- Kuyruk ----
    property variant queue: []
    property variant titles: []
    property int qIndex: 0
    property string source: "single"
    property string path: ""
    property string title: ""

    // ---- Oynatma durumu ----
    property string mode: "video"         // "video" | "audio"
    property bool userPlaying: true
    property bool inBackground: false
    property bool fullscreen: false
    property bool peek: false             // tam ekranda seridi kisa sure goster
    property int lastPos: 0
    property int pendingSeek: 0
    property int retries: 0
    property bool triedDirect: false
    property bool ready: false            // video katmani kurulabilir
    property string phase: ""             // "ready" | "error" | "ended"
    property string err: ""
    property string videoSrc: ""
    property int openSeq: 0
    property int seenDuration: 0
    property string lastVideoErr: ""

    property variant vplayer: vload.item
    property bool videoActive: mode === "video" && !inBackground && vplayer !== null && vplayer !== undefined
    property int position: videoActive ? vplayer.position : aud.position
    property int duration: (videoActive && vplayer.duration > 0) ? vplayer.duration : (aud.duration > 0 ? aud.duration : seenDuration)
    property bool isPlaying: videoActive ? (vplayer.playing && !vplayer.paused) : (aud.playing && !aud.paused)
    property bool panelVisible: !fullscreen || peek || mode === "audio" || phase !== "ready"
    onDurationChanged: if (duration > 0) seenDuration = duration

    function titleAt(i) {
        var t = titles && titles.length > i ? titles[i] : "";
        return t ? t : lib.baseName(queue[i]);
    }

    // ---------------- Acma / kapama ----------------
    function open(paths, ts, index, src, audioOnly) {
        saveCurrent();
        stopAll();
        queue = paths;
        titles = ts;
        source = src;
        qIndex = Math.max(0, Math.min(index, paths.length - 1));
        fullscreen = false;
        load(audioOnly);
    }

    function load(audioOnly) {
        openSeq++;
        path = queue[qIndex];
        title = titleAt(qIndex);
        app.nowPath = path;
        app.nowSource = source;
        mode = (audioOnly || lib.isAudio(path)) ? "audio" : "video";
        userPlaying = true;
        lastPos = 0; pendingSeek = 0; retries = 0; triedDirect = false; seenDuration = 0;
        err = "";
        if (app.resume && !lib.isRemote(path)) {
            var sp = lib.savedPosition(path), sd = lib.savedDuration(path);
            if (sp > 5000 && (sd === 0 || sp < sd - 8000)) {
                lastPos = sp;
                seenDuration = sd;
                app.showToast(qsTr("Kaldığı yerden: ") + U.fmt(sp) + qsTr("   (0 tuşu: baştan)"));
            }
        }
        lib.log("ac " + mode + " " + path + (lastPos > 0 ? " @" + lastPos : ""));
        phase = "ready";
        bgPaused = false; audioWaiting = false;
        begin();
        // Kilitte calabilmek icin videonun ses izi ayri dosyaya cikarilir (video basladiktan biraz sonra)
        if (lib.canExtractAudio(path)) { if (mode === "audio") lib.prepareAudio(path); else if (app.bgAudio) prepTimer.restart(); }
    }

    function begin() {
        if (mode === "video") {
            pendingSeek = lastPos;
            videoSrc = lib.videoUrl(path, app.directFile || triedDirect);
            ready = true;                      // Loader video katmanini kurar
            if (!sys.foreground || sys.locked || sys.screenOff) updateBackground();
        } else {
            startAudio(lastPos);
        }
    }

    function leave() {
        saveCurrent();
        stopAll();
        openSeq++;
        sys.keepScreenOn(false);
    }

    function stopAll() {
        fgTimer.stop(); retryTimer.stop(); vStartTimer.stop(); bgTimer.stop();
        inBackground = false;
        ready = false;
        aud.stop();
        aud.source = "";
        videoSrc = "";
        phase = "";
    }

    // Kaldigi yeri kaydet (son izlenenlere de eklenir)
    function saveCurrent() {
        if (path === "" || lib.isRemote(path)) return;
        var pos = position > 0 ? position : lastPos;
        var dur = duration;
        if (dur > 0 && pos >= dur - 5000) lib.savePosition(path, 0, dur);    // bitti: bastan
        else if (pos > 0) lib.savePosition(path, pos, dur);
    }
    Timer { interval: 10000; repeat: true; running: app.playerOpen && root.isPlaying; onTriggered: root.saveCurrent() }

    // ---------------- Ses oynaticisi ----------------
    // Video dosyasi Audio'ya dogrudan verilirse Symbian video oturumu acip donanim cozucusunu kullaniyor;
    // kilitte cozucu alininca (-12015) cokebiliyor. Bu yuzden once ayri ses izi (.m4a) beklenir.
    property bool audioWaiting: false
    property int audioWaitPos: 0
    property bool bgPaused: false         // arka planda ses calinamadigi icin duraklatildi
    property int prepTick: 0
    Timer { id: prepTimer; interval: 2500; onTriggered: lib.prepareAudio(root.path) }
    Timer { interval: 500; repeat: true; running: root.audioWaiting; onTriggered: root.prepTick++ }
    function unsafeForVideoFile() { return sys.locked || sys.screenOff || !sys.foreground; }

    function startAudio(pos) {
        if (lib.isVideo(path) && !lib.isRemote(path) && !lib.audioReady(path)) {
            if (lib.canExtractAudio(path)) {
                audioWaiting = true;
                audioWaitPos = pos;
                prepTimer.stop();
                lib.prepareAudio(path);
                if (!lib.audioReady(path)) return;      // hazir olunca onAudioPrepared devam ettirir
                audioWaiting = false;
            } else if (unsafeForVideoFile()) {
                pauseForBackground(qsTr("bu biçimde ses ayrılamıyor"));
                return;
            }
        }
        playAudioUrl(lib.audioUrl(path), pos);
    }
    function playAudioUrl(url, pos) {
        aud.seekTo = pos;
        aud.source = "";
        aud.source = url;
        if (userPlaying) aud.play();
    }
    function stopAudio() { audioWaiting = false; aud.stop(); aud.source = ""; }
    function pauseForBackground(why) {
        audioWaiting = false;
        bgPaused = true;
        userPlaying = false;
        saveCurrent();
        lib.log("arka planda ses yok (" + why + "), duraklatildi");
    }
    Connections {
        target: lib
        onAudioPrepared: {
            if (!root.audioWaiting || path !== root.path) return;
            root.audioWaiting = false;
            if (ok) { root.startAudio(root.audioWaitPos); return; }
            // Ses izi cikmadi: kilitli/ekran kapaliysa duraklat, ekran aciksa video dosyasindan dene
            if (root.unsafeForVideoFile()) { root.pauseForBackground(message); return; }
            app.showToast(qsTr("Ses izi ayrılamadı: ") + message);
            root.playAudioUrl("file:///" + root.path, root.audioWaitPos);
        }
    }

    // ---------------- Kontroller ----------------
    function togglePlay() {
        if (phase === "ended") { restart(); return; }
        if (phase !== "ready") return;
        if (videoActive) {
            if (vplayer.playing && !vplayer.paused) { vplayer.pause(); userPlaying = false; }
            else { vplayer.play(); userPlaying = true; }
        } else {
            if (aud.playing && !aud.paused) { aud.pause(); userPlaying = false; }
            else { if (aud.source == "") startAudio(lastPos); else aud.play(); userPlaying = true; }
        }
        showPeek();
    }
    function seekTo(ms) {
        if (phase !== "ready") return;
        ms = Math.max(0, Math.floor(ms));
        if (duration > 0) ms = Math.min(ms, Math.max(0, duration - 1500));
        if (videoActive) vplayer.position = ms;
        else aud.position = ms;
        lastPos = ms;
        showPeek();
    }
    function seekBy(sec) { seekTo((position > 0 ? position : lastPos) + sec * 1000); }
    function restart() {
        lib.clearPosition(path);
        var a = mode === "audio" && !lib.isAudio(path);
        stopAll();
        load(a);
    }
    function switchMode(m) {
        if (m === mode || lib.isAudio(path)) return;
        var pos = position > 0 ? position : lastPos;
        stopAll();
        openSeq++;
        mode = m;
        lastPos = pos;
        phase = "ready";
        userPlaying = true;
        begin();
        app.showToast(m === "audio" ? qsTr("Sadece ses: video çözülmüyor") : qsTr("Videoya dönüldü"));
    }
    function toBackground() {
        if (mode === "video" && !app.bgAudio) app.showToast(qsTr("Ayarlar'da 'arka planda sesle devam' kapalı"));
        lib.sendToBackground();            // one donusler kilit/odak kontroluyle yonetilir
    }

    function hasNext() { return qIndex < queue.length - 1 || (app.repeatMode === 1 && queue.length > 1) || (app.shuffle && queue.length > 1); }
    function go(i) {
        saveCurrent();
        var a = mode === "audio" && !lib.isAudio(path);
        stopAll();
        qIndex = i;
        load(a);
    }
    function next() {
        if (queue.length < 2) { app.showToast(qsTr("Kuyrukta başka dosya yok")); return; }
        var i;
        if (app.shuffle) { do { i = Math.floor(Math.random() * queue.length); } while (i === qIndex); }
        else i = qIndex + 1;
        if (i >= queue.length) {
            if (app.repeatMode !== 1) { app.showToast(qsTr("Sonuncu dosya")); return; }
            i = 0;
        }
        go(i);
    }
    function prev() {
        if (position > 5000 || queue.length < 2) { seekTo(0); return; }
        var i = qIndex - 1;
        if (i < 0) { if (app.repeatMode !== 1) { seekTo(0); return; } i = queue.length - 1; }
        go(i);
    }
    function cycleRepeat() {
        app.repeatMode = (app.repeatMode + 1) % 3;
        app.setSetting("repeat", app.repeatMode);
        app.showToast([qsTr("Tekrar kapalı"), qsTr("Tümünü tekrarla"), qsTr("Bu dosyayı tekrarla")][app.repeatMode]);
    }
    function toggleShuffle() {
        app.shuffle = !app.shuffle;
        app.setSetting("shuffle", app.shuffle ? 1 : 0);
        app.showToast(app.shuffle ? qsTr("Karışık çalma açık") : qsTr("Karışık çalma kapalı"));
    }

    // Dosya bitti
    function ended() {
        lib.clearPosition(path);
        lib.savePosition(path, 0, duration);
        if (app.repeatMode === 2) { endTimer.action = "again"; endTimer.start(); return; }
        var auto = source === "list" || app.autoNext;
        if (auto && hasNext()) { endTimer.action = "next"; endTimer.start(); return; }
        userPlaying = false;
        phase = "ended";
        app.showToast(queue.length > 1 && !auto ? qsTr("Bitti. N: sonraki") : qsTr("Bitti"));
    }
    // Oynatici kendi sinyali icindeyken yok edilmesin: gecis sonraya birakilir
    Timer {
        id: endTimer
        property string action: ""
        interval: 300
        onTriggered: { if (action === "again") root.restart(); else root.next(); }
    }

    // ---------------- Arka plan / kilit ----------------
    function goBackground() {
        if (mode !== "video" || inBackground) return;
        var pos = (videoActive && vplayer.position > 0) ? vplayer.position : lastPos;
        lastPos = pos;
        inBackground = true;                  // video katmani yok edilir
        lib.log("arka plan konum=" + pos + (app.bgAudio ? " ses devam" : " duraklat"));
        if (!app.bgAudio) { userPlaying = false; saveCurrent(); return; }
        if (ready && userPlaying) startAudio(pos);
    }
    function goForeground() {
        if (!inBackground) return;
        var pos = aud.position > 0 ? aud.position : lastPos;
        lastPos = pos;
        stopAudio();
        if (bgPaused) { bgPaused = false; userPlaying = true; }
        lib.log("one donus konum=" + pos);
        pendingSeek = pos;
        fgTimer.start();
    }
    Timer { id: fgTimer; interval: 450; onTriggered: root.inBackground = false }
    Timer { id: bgTimer; interval: 700; onTriggered: root.applyBackground() }
    function updateBackground() { if (app.playerOpen) bgTimer.restart(); }
    function applyBackground() {
        if (!app.playerOpen) return;
        if (!sys.foreground || sys.locked || sys.screenOff) goBackground(); else goForeground();
    }
    Connections { target: sys; onForegroundChanged: root.updateBackground() }
    Connections { target: sys; onLockedChanged: root.updateBackground() }
    Connections { target: sys; onScreenOffChanged: root.updateBackground() }

    property bool screenOn: app.playerOpen && mode === "video" && phase === "ready" && userPlaying && !inBackground && sys.foreground
    onScreenOnChanged: sys.keepScreenOn(screenOn)

    // ---------------- Hata / yeniden deneme ----------------
    Timer { id: retryTimer; interval: 900; onTriggered: { root.pendingSeek = root.lastPos; root.videoSrc = lib.videoUrl(root.path, app.directFile || root.triedDirect); root.ready = true; } }
    Timer {
        id: vStartTimer
        interval: 500
        onTriggered: {
            if (!root.videoActive) return;
            root.vplayer.source = root.videoSrc;
            if (root.userPlaying) root.vplayer.play();
        }
    }
    Timer {
        id: videoErrTimer
        interval: 50
        onTriggered: {
            if (root.inBackground || !app.playerOpen || root.mode !== "video") return;
            // -12015 KErrMMDecoder: ekran kararinca/kilitlenince video cozucusu alindi. Bu durumda
            // pencereyi kilitli ekranda yeniden kurmak cokmeye yol aciyordu: dogrudan sese gecilir.
            var decoderLost = root.lastVideoErr.indexOf("12015") >= 0;
            if (sys.locked || !sys.foreground || sys.screenOff || (decoderLost && root.retries >= 1)) { root.goBackground(); return; }
            if (root.retries < 1) { root.retries++; root.ready = false; retryTimer.start(); return; }
            if (!root.triedDirect && !app.directFile && !lib.isRemote(root.path)) {
                root.triedDirect = true; root.retries = 0; root.ready = false; retryTimer.start(); return;
            }
            root.ready = false;
            root.phase = "error";
            root.err = qsTr("Video oynatılamadı (biçim desteklenmiyor olabilir).\nS: sadece ses   D: dış oynatıcı   N: sonraki");
        }
    }

    // ---------------- Ses (sadece ses modu ve arka plan) ----------------
    Audio {
        id: aud
        property int seekTo: 0
        // Oynatici dosya yuklerken sesi kendi varsayilanina cekebiliyor: yuklenince yeniden verilir
        function applyVolume() { var v = app.volume / 100; volume = v > 0.01 ? v - 0.01 : 0.01; volume = v; }
        Component.onCompleted: volume = app.volume / 100
        onPlayingChanged: if (playing) applyVolume()
        onStatusChanged: {
            if (status === Audio.Loaded || status === Audio.Buffered) {
                applyVolume();
                if (seekTo > 0) { position = seekTo; seekTo = 0; }
            }
            if (status === Audio.EndOfMedia && source != "") root.ended();
        }
        onPositionChanged: if (position > 0) root.lastPos = position
        onError: {
            lib.log("ses hata: " + errorString);
            if (root.mode === "audio") { root.phase = "error"; root.err = qsTr("Ses çalınamadı: ") + errorString + qsTr("\nD: dış oynatıcı   N: sonraki"); }
        }
    }
    Connections { target: app; onVolumeChanged: aud.volume = app.volume / 100 }

    // ---------------- Ses gostergesi ----------------
    property bool volumeShowing: false
    function showVolume() { volumeShowing = true; volHide.restart(); showPeek(); }
    Timer { id: volHide; interval: 1500; onTriggered: root.volumeShowing = false }
    function showPeek() { if (fullscreen) { peek = true; peekTimer.restart(); } }
    Timer { id: peekTimer; interval: 2500; onTriggered: root.peek = false }

    // ---------------- Video alani ----------------
    Component {
        id: videoComp
        NativeVideo {
            volume: app.volume
            showVideo: !app.sheetShown
            Component.onCompleted: vStartTimer.restart()
            onStatusChanged: {
                // 3 yuklendi, 6 tamponlandi, 7 sona geldi
                if ((status === 3 || status === 6) && root.pendingSeek > 0) {
                    position = root.pendingSeek;
                    root.pendingSeek = 0;
                }
                if (status === 7) root.ended();
            }
            onPositionChanged: if (position > 0) root.lastPos = position
            onError: {
                root.lastVideoErr = errorString;
                lib.log("video hata: " + errorString + " | " + debugInfo() + (sys.screenOff ? " ekran kapali" : "") + (sys.locked ? " kilitli" : ""));
                videoErrTimer.start();
            }
            onClicked: { if (root.fullscreen) root.showPeek(); else root.togglePlay(); }
        }
    }

    Item {
        id: videoArea
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: root.panelVisible ? panel.top : parent.bottom }

        // Durum ekrani (video katmani yokken gorunur)
        Column {
            anchors.centerIn: parent
            width: parent.width - 60
            spacing: 12
            visible: !root.videoActive || root.phase !== "ready"
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 72; height: 72; smooth: true
                source: "../images/" + (root.phase === "error" ? "close" : (root.mode === "audio" || root.inBackground ? "phones" : "film")) + "_a.png"
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.title
                textFormat: Text.PlainText
                color: "#FFFFFF"
                font.pixelSize: 21
                font.bold: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: root.phase === "error" ? "#FF8A95" : app.textSecondary
                font.pixelSize: 17
                text: root.phase === "error" ? root.err
                    : root.phase === "ended" ? qsTr("Bitti. Tekrar oynatmak için Enter") + (root.queue.length > 1 ? qsTr(", sonraki için N") : "")
                    : root.audioWaiting ? qsTr("Ses hazırlanıyor %") + (root.prepTick >= 0 ? lib.audioProgress() : 0)
                    : root.bgPaused ? qsTr("Duraklatıldı: kilitte bu videonun sesi çalınamadı")
                    : root.mode === "audio" ? (root.isPlaying ? qsTr("Sadece ses çalıyor") : qsTr("Duraklatıldı")) + (lib.isAudio(root.path) ? "" : qsTr("   (V: videoya dön)"))
                    : root.inBackground ? qsTr("Arka planda ses devam ediyor")
                    : qsTr("Yükleniyor...")
            }
        }
        MouseArea { anchors.fill: parent; onClicked: root.togglePlay() }

        Loader {
            id: vload
            anchors.fill: parent
            sourceComponent: (root.mode === "video" && root.ready && !root.inBackground) ? videoComp : undefined
        }
    }

    // ---------------- Kontrol seridi ----------------
    Rectangle {
        id: panel
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 92
        color: "#14181C"
        visible: root.panelVisible

        // Ust satir: sure ve ilerleme cubugu
        Item {
            id: seekRow
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 34
            Text {
                id: posText
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                width: 62
                text: U.fmt(root.position > 0 ? root.position : root.lastPos)
                color: "#FFFFFF"; font.pixelSize: 15
            }
            Text {
                id: durText
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                width: 62
                horizontalAlignment: Text.AlignRight
                text: root.duration > 0 ? U.fmt(root.duration) : "--:--"
                color: app.textSecondary; font.pixelSize: 15
            }
            Item {
                anchors { left: posText.right; right: durText.left; leftMargin: 6; rightMargin: 6; top: parent.top; bottom: parent.bottom }
                property real frac: root.duration > 0 ? Math.min(1, (root.position > 0 ? root.position : root.lastPos) / root.duration) : 0
                id: seekBar
                Rectangle { id: track; anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 5; radius: 2; color: "#3A444E" }
                Rectangle { anchors { left: track.left; verticalCenter: track.verticalCenter } height: 5; radius: 2; color: app.brand; width: track.width * seekBar.frac }
                Rectangle { width: 16; height: 16; radius: 8; color: app.brand; anchors.verticalCenter: track.verticalCenter; x: track.width * seekBar.frac - 8 }
                MouseArea {
                    anchors.fill: parent
                    onClicked: if (root.duration > 0) root.seekTo(root.duration * Math.max(0, Math.min(1, mouse.x / width)))
                }
            }
        }

        // Alt satir: dugmeler ve baslik
        Item {
            anchors { left: parent.left; right: parent.right; top: seekRow.bottom; bottom: parent.bottom }
            Row {
                id: leftBtns
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                IconButton { icon: "back"; iconSize: 26; onClicked: app.closePlayer() }
                IconButton { icon: "prev"; iconSize: 24; opacity: root.queue.length > 1 ? 1 : 0.35; onClicked: root.prev() }
                IconButton { icon: "rew"; iconSize: 30; onClicked: root.seekBy(-app.seekStep) }
                IconButton {
                    icon: root.isPlaying ? "pause" : "play"
                    tone: "a"
                    iconSize: 32
                    onClicked: root.togglePlay()
                }
                IconButton { icon: "fwd"; iconSize: 30; onClicked: root.seekBy(app.seekStep) }
                IconButton { icon: "next"; iconSize: 24; opacity: root.queue.length > 1 ? 1 : 0.35; onClicked: root.next() }
            }
            Column {
                anchors { left: leftBtns.right; leftMargin: 6; right: rightBtns.left; rightMargin: 4; verticalCenter: parent.verticalCenter }
                Text {
                    width: parent.width
                    text: root.volumeShowing ? qsTr("Ses: %") + app.volume : root.title
                    textFormat: Text.PlainText
                    color: root.volumeShowing ? app.brand : "#FFFFFF"
                    font.pixelSize: 16
                    font.bold: root.volumeShowing
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: {
                        var a = [];
                        if (root.queue.length > 1) a.push((root.qIndex + 1) + "/" + root.queue.length);
                        if (root.source === "list") a.push(qsTr("Liste"));
                        if (app.shuffle && root.queue.length > 1) a.push(qsTr("karışık"));
                        if (root.mode === "audio") a.push("ses");
                        if (root.inBackground) a.push(qsTr("arka plan"));
                        return a.join(" • ");
                    }
                    color: app.textSecondary
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
            }
            Row {
                id: rightBtns
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                IconButton {
                    icon: "phones"; iconSize: 26
                    active: root.mode === "audio"
                    onClicked: root.switchMode(root.mode === "audio" ? "video" : "audio")
                }
                IconButton {
                    icon: app.repeatMode === 2 ? "repeat1" : "repeat"; iconSize: 26
                    active: app.repeatMode > 0
                    onClicked: root.cycleRepeat()
                }
                IconButton {
                    icon: root.fullscreen ? "exitfull" : "full"; iconSize: 24
                    opacity: root.mode === "video" ? 1 : 0.35
                    onClicked: if (root.mode === "video") { root.fullscreen = !root.fullscreen; root.peek = false; }
                }
            }
        }
    }

    // ---------------- Klavye ----------------
    // Enter/Bosluk: oynat-duraklat   Sol/Sag: geri/ileri sar   Yukari/Asagi: ses
    // F: tam ekran  S: sadece ses  B: arka plana al  N/P: sonraki/onceki  R: tekrar  K: karisik
    // 0: bastan  1-9: %10-%90  D: dis oynatici  Geri/Esc: kapat
    focus: app.playerOpen
    Keys.onPressed: {
        var k = event.key, t = event.text ? event.text.toLowerCase() : "";
        var handled = true;
        if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select || k === Qt.Key_Space) togglePlay();
        else if (k === Qt.Key_Left) seekBy(event.isAutoRepeat ? -3 * app.seekStep : -app.seekStep);
        else if (k === Qt.Key_Right) seekBy(event.isAutoRepeat ? 3 * app.seekStep : app.seekStep);
        else if (k === Qt.Key_Up) app.changeVolume(10);
        else if (k === Qt.Key_Down) app.changeVolume(-10);
        else if (k === Qt.Key_Backspace || k === Qt.Key_Escape) { if (fullscreen) fullscreen = false; else app.closePlayer(); }
        else if (t === "f") { if (mode === "video") { fullscreen = !fullscreen; peek = false; } }
        else if (t === "s") switchMode("audio");
        else if (t === "v") switchMode("video");
        else if (t === "b") toBackground();
        else if (t === "n") next();
        else if (t === "p") prev();
        else if (t === "r") cycleRepeat();
        else if (t === "k") toggleShuffle();
        else if (t === "d") { if (isPlaying) togglePlay(); if (!lib.openExternally(path)) app.showToast(qsTr("Açılamadı")); }
        else if (t === "0") { if (phase === "ended") restart(); else seekTo(0); }
        else if (t >= "1" && t <= "9" && duration > 0) seekTo(duration * parseInt(t, 10) / 10);
        else handled = false;
        event.accepted = handled;
    }
}
