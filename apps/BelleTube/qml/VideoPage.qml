import QtQuick 1.1
import QtMultimediaKit 1.1
import BelleTube 1.0

// Oynatici sayfasi (izleme ve indirme birbirinden bagimsiz):
//  - Izleme: oynatici dosyayi dogrudan sunucudan okur (akis). Telefonda tam inmis dosya varsa ondan.
//  - Indirme: ayri baglantiyla ayri dosyaya (app.download); izlemeyi etkilemez, sayfadan cikinca da surer.
//  - Kilit / arka plan (video modu): goruntu katmani tamamen kapatilir (oynatici yok edilir), ayni
//    konumdan sadece ses devam eder. Kilit acilinca goruntu yeniden kurulur ve sesin kaldigi yerden surer.
//  - Ses modu: yalnizca ses oynaticisi; kilitte de ayni sekilde devam eder.
Rectangle {
    id: root
    color: app.bg

    // video bilgisi
    property variant item: ({})
    property string vid: ""
    property string title: ""
    property string channel: ""
    property string channelId: ""
    property int seconds: 0
    property string views: ""
    property string published: ""
    property string description: ""

    // oynatma
    property string mode: "video"        // "video" | "audio"
    property string videoKind: "360"     // "360" | "480"
    property string videoSrc: ""
    property string audioSrc: ""         // ses modu ve arka plan sesi
    property string audioFallback: ""    // ses dosyasi acilamazsa (cevrimdisi, inmis video dosyasi)
    property bool localVideo: false
    property bool ready: false           // kaynak hazir (sunucu hazirladi ya da telefonda)
    property string phase: ""            // "preparing" | "ready" | "error"
    property string err: ""
    property bool userPlaying: true
    property bool inBackground: false
    property bool fullscreen: false
    property int lastPos: 0
    property int pendingSeek: 0
    property int retries: 0
    property int openSeq: 0              // eski istek yanitlari yeni videoya karismasin

    property variant vplayer: vload.item
    property bool videoActive: mode === "video" && !inBackground && vplayer !== null && vplayer !== undefined
    property int position: videoActive ? vplayer.position : aud.position
    property int duration: (videoActive && vplayer.duration > 0) ? vplayer.duration
                           : (!videoActive && aud.duration > 0 ? aud.duration : seconds * 1000)
    property bool isPlaying: videoActive ? (vplayer.playing && !vplayer.paused) : aud.playing && !aud.paused

    function fmt(ms) {
        var s = Math.max(0, Math.floor(ms / 1000));
        var m = Math.floor(s / 60), h = Math.floor(m / 60);
        s = s % 60;
        if (h > 0) { m = m % 60; return h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s; }
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    function localKindFor(id) {
        if (tube.isComplete(id, app.quality)) return app.quality;
        if (tube.isComplete(id, "360")) return "360";
        if (tube.isComplete(id, "480")) return "480";
        return "";
    }

    // ---------------- Acma / kapama ----------------
    function open(it, m) {
        stopAll();
        openSeq++;
        item = it;
        vid = it.id;
        title = it.title ? it.title : "";
        channel = it.channel ? it.channel : "";
        channelId = it.channelId ? it.channelId : "";
        seconds = app.secondsOf(it);
        views = ""; published = ""; description = "";
        relatedModel.clear();
        commentModel.clear(); commentsNext = ""; commentsLoaded = false; commentsBusy = false; commentsOff = false;
        mode = m;
        fullscreen = false;
        commentsFull = false;
        userPlaying = true;
        lastPos = 0; pendingSeek = 0; retries = 0;
        info.contentY = 0;
        loadInfo();
        startSource();
    }

    function leave() {
        commentsFull = false;
        stopAll();
        openSeq++;
        sys.keepScreenOn(false);
    }

    function stopAll() {
        fgTimer.stop(); retryTimer.stop(); vStartTimer.stop();
        inBackground = false;
        ready = false;               // video katmani yok edilir
        aud.stop();
        aud.source = "";
        videoSrc = ""; audioSrc = ""; audioFallback = "";
        phase = ""; err = "";
    }

    function loadInfo() {
        var seq = openSeq;
        app.apiVideo(vid, function (d) {
            if (seq !== root.openSeq) return;
            if (d.title) root.title = d.title;
            if (d.channel) root.channel = d.channel;
            if (d.channelId) root.channelId = d.channelId;
            if (d.seconds) root.seconds = d.seconds;
            root.views = d.views ? Number(d.views).toLocaleString() + qsTr(" görüntüleme") : "";
            root.published = d.published ? d.published.substring(0, 10) : "";
            root.description = d.description ? d.description : "";
            for (var i = 0; i < d.related.length; i++) {
                var r = d.related[i];
                relatedModel.append({ rid: r.id, rtitle: r.title, rchannel: r.channel, rchannelId: r.channelId || "", rlength: r.length, rviews: r.views });
            }
        }, function (msg) { });
    }

    // Kaynaklari belirle: telefonda tam dosya varsa ondan, yoksa sunucu hazirlayinca akistan
    function startSource() {
        var seq = openSeq;
        var lk = localKindFor(vid);
        var localAudio = tube.isComplete(vid, "audio");
        localVideo = lk !== "";
        videoKind = lk !== "" ? lk : app.quality;
        // Goruntu her zaman yerel sunucudan (127.0.0.1): inmis dosyadan ya da uzak sunucudan aktarmayla.
        // E6'nin oynaticisi dogrudan dosyada da uzak adreste de goruntu vermiyor, sadece ses veriyor.
        videoSrc = lk !== "" ? tube.streamUrl(vid, lk) : tube.relayUrl(vid, app.quality);
        audioSrc = localAudio ? tube.fileUrl(tube.pathFor(vid, "audio")) : app.api().playUrl(vid, "audio");
        audioFallback = lk !== "" ? tube.fileUrl(tube.pathFor(vid, lk)) : "";
        tube.log("ac " + vid + " mod=" + mode + (lk !== "" ? " yerel video" : "") + (localAudio ? " yerel ses" : ""));

        var needServer = mode === "video" ? lk === "" : !localAudio;
        if (!needServer) { phase = "ready"; begin(); return; }
        phase = "preparing";
        app.api().prepare(vid, mode === "video" ? app.quality : "audio", function (d) {
            if (seq !== root.openSeq) return;
            phase = "ready";
            begin();
        }, function (msg) {
            if (seq !== root.openSeq) return;
            phase = "error";
            err = msg;
        });
    }

    function begin() {
        retries = 0;
        if (mode === "video") {
            pendingSeek = lastPos;
            ready = true;            // Loader video katmanini kurar ve oynatir
            if (!sys.foreground || sys.locked) updateBackground();   // hala arkadaysa 0,7 sn sonra sese gecer
        } else {
            startAudio(lastPos);
        }
    }

    // ---------------- Ses oynaticisi ----------------
    function startAudio(pos) {
        aud.fallbackTried = false;
        aud.seekTo = pos;
        aud.source = "";
        aud.source = audioSrc;
        if (userPlaying) aud.play();
        tube.log("ses basla konum=" + pos);
    }
    function stopAudio() {
        aud.stop();
        aud.source = "";
    }

    // ---------------- Kontroller ----------------
    function togglePlay() {
        if (phase !== "ready") return;
        if (videoActive) {
            if (vplayer.playing && !vplayer.paused) { vplayer.pause(); userPlaying = false; }
            else { vplayer.play(); userPlaying = true; }
        } else {
            if (aud.playing && !aud.paused) { aud.pause(); userPlaying = false; }
            else { if (aud.source === "") startAudio(lastPos); else aud.play(); userPlaying = true; }
        }
    }
    function seekTo(ms) {
        if (phase !== "ready") return;
        ms = Math.max(0, Math.min(Math.floor(ms), Math.max(0, duration - 1000)));
        if (videoActive) vplayer.position = ms;
        else aud.position = ms;
        lastPos = ms;
    }
    // Ses / video arasinda gecis: kaldigi yerden
    function switchMode(m) {
        if (m === mode) return;
        var pos = position > 0 ? position : lastPos;
        stopAll();
        openSeq++;
        mode = m;
        lastPos = pos;
        startSource();
    }

    // ---------------- Arka plan / kilit ----------------
    function goBackground() {
        if (mode !== "video" || inBackground) return;
        var pos = (videoActive && vplayer.position > 0) ? vplayer.position : lastPos;
        lastPos = pos;
        inBackground = true;         // Loader video katmanini yok eder
        tube.log("arka plan: ses devam konum=" + pos);
        if (ready && userPlaying) startAudio(pos);
    }
    function goForeground() {
        if (!inBackground) return;
        var pos = aud.position > 0 ? aud.position : lastPos;
        lastPos = pos;
        stopAudio();
        tube.log("one donus: goruntu konum=" + pos);
        pendingSeek = pos;
        fgTimer.start();             // ses birakilsin, sonra goruntu yeniden kurulsun
    }
    Timer { id: fgTimer; interval: 450; onTriggered: root.inBackground = false }
    Timer { id: retryTimer; interval: 900; onTriggered: { root.pendingSeek = root.lastPos; root.ready = true; } }
    Timer {
        id: vStartTimer
        interval: 500
        onTriggered: {
            if (!root.videoActive) return;
            tube.log("goruntu oynat " + root.vplayer.width + "x" + root.vplayer.height + " konum=" + root.pendingSeek);
            root.vplayer.source = root.videoSrc;
            if (root.userPlaying) root.vplayer.play();
        }
    }
    Timer {
        id: videoErrTimer
        interval: 50
        onTriggered: {
            if (root.inBackground || !app.videoOpen || root.mode !== "video") return;
            if (sys.locked || !sys.foreground) { root.goBackground(); return; }
            if (root.retries < 2) {          // katmani bastan kurup kaldigi yerden dene
                root.retries++;
                root.ready = false;
                retryTimer.start();
                return;
            }
            root.ready = false;
            root.phase = "error";
            root.err = qsTr("Video oynatılamadı. \"Sadece ses\" ile dinleyebilir ya da indirip izleyebilirsiniz.");
        }
    }
    // Kilit/one donus: kisa sureli odak kaymalari (video penceresi acilirken, baglanti
    // penceresi vb.) arka plana gecirmesin diye durum 0,7 sn sabit kalinca uygulanir.
    Timer { id: bgTimer; interval: 700; onTriggered: root.applyBackground() }

    function updateBackground() { if (app.videoOpen) bgTimer.restart(); }
    function applyBackground() {
        if (!app.videoOpen) return;
        var bg = !sys.foreground || sys.locked;
        tube.log("durum: onde=" + sys.foreground + " kilit=" + sys.locked + " (qt etkin=" + Qt.application.active + ")");
        if (bg) goBackground(); else goForeground();
    }
    Connections { target: sys; onForegroundChanged: root.updateBackground() }
    Connections { target: sys; onLockedChanged: root.updateBackground() }

    property bool screenOn: app.videoOpen && mode === "video" && phase === "ready" && userPlaying && !inBackground && sys.foreground
    onScreenOnChanged: sys.keepScreenOn(screenOn)

    Audio {
        id: aud
        property int seekTo: 0
        property bool fallbackTried: false
        // Ses seviyesi baglama ile degil elle verilir: oynatici dosya yuklerken sesi sifirlayabiliyor,
        // yuklenince ve calmaya baslayinca yeniden uygulanir
        function applyVolume() { var v = app.volume / 100; volume = v > 0.01 ? v - 0.01 : 0.01; volume = v; }
        Component.onCompleted: volume = app.volume / 100
        onPlayingChanged: if (playing) applyVolume()
        onStatusChanged: {
            if (status === Audio.Loaded || status === Audio.Buffered) applyVolume();
            if ((status === Audio.Loaded || status === Audio.Buffered) && seekTo > 0) {
                position = seekTo;
                seekTo = 0;
            }
            if (status === Audio.EndOfMedia) root.userPlaying = false;
        }
        onPositionChanged: if (position > 0) root.lastPos = position
        onError: {
            tube.log("ses hata: " + errorString);
            if (!fallbackTried && root.audioFallback !== "") {
                fallbackTried = true;
                var p = position > 0 ? position : root.lastPos;
                seekTo = p;
                source = root.audioFallback;
                play();
                return;
            }
            if (root.mode === "audio") { root.phase = "error"; root.err = qsTr("Ses çalınamadı: ") + errorString; }
        }
    }

    Connections { target: app; onVolumeChanged: aud.volume = app.volume / 100 }

    // ---------------- Oynatici alani ----------------
    property bool volumeShowing: false
    function showVolume() { volumeShowing = true; volHide.restart(); }
    Timer { id: volHide; interval: 1500; onTriggered: root.volumeShowing = false }

    Component {
        id: videoComp
        NativeVideo {
            id: nv
            volume: app.volume
            showVideo: !app.sheetOpen
            // Kaynak ve oynatma, yerel pencere boyutlanip ekrana yerlestikten sonra verilir
            // (pencere hazir olmadan oynatilinca Symbian -18 "hazir degil" hatasi veriyor)
            Component.onCompleted: { tube.log("goruntu katmani kuruldu"); vStartTimer.restart(); }
            onStatusChanged: {
                // 3 yuklendi, 6 tamponlandi, 7 sona geldi
                if ((status === 3 || status === 6) && root.pendingSeek > 0) {
                    position = root.pendingSeek;
                    root.pendingSeek = 0;
                }
                if (status === 7) root.userPlaying = false;
            }
            onPositionChanged: if (position > 0) root.lastPos = position
            // Bu oge kendi sinyali icindeyken yok edilmemeli: islem zamanlayiciyla sonraya birakilir
            onError: { tube.log("video hata: " + errorString + " | " + debugInfo()); videoErrTimer.start(); }
            onClicked: root.togglePlay()
        }
    }

    Rectangle {
        id: playerBox
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: root.fullscreen ? root.height : (root.mode === "audio" ? 200 : 356)
        color: "#000000"
        z: 2

        Item {
            id: videoArea
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: bar.top }

            // Durum / ses modu (video katmani yokken gorunur)
            Column {
                anchors.centerIn: parent
                width: parent.width - 40
                spacing: 10
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.mode === "audio" || root.inBackground
                    width: 64; height: 64; smooth: true
                    source: "../images/headphones.png"
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: root.phase === "error" ? "#FF8A95" : "#FFFFFF"
                    font.pixelSize: 19
                    text: root.phase === "error" ? root.err
                        : (root.phase === "preparing" ? qsTr("Sunucu hazırlıyor...")
                        : (root.mode === "audio" ? (root.isPlaying ? qsTr("Ses çalıyor") : qsTr("Duraklatıldı")) : qsTr("Yükleniyor...")))
                }
                Rectangle {
                    visible: root.phase === "error"
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: rtText.paintedWidth + 32; height: 42; radius: 21
                    color: rtMa.pressed ? app.brandPressed : app.brand
                    Text { id: rtText; anchors.centerIn: parent; text: qsTr("Tekrar dene"); color: "#FFFFFF"; font.pixelSize: 17; font.bold: true }
                    MouseArea { id: rtMa; anchors.fill: parent; onClicked: { var p = root.lastPos; root.stopAll(); root.openSeq++; root.lastPos = p; root.startSource(); } }
                }
            }
            MouseArea { anchors.fill: parent; onClicked: root.togglePlay() }

            // Yorumlar tam ekran acikken video kucuk pencerede (sag ust) oynamaya devam eder
            Loader {
                id: vload
                x: root.commentsFull ? root.width - 172 : 0
                y: root.commentsFull ? 5 : 0
                width: root.commentsFull ? 160 : videoArea.width
                height: root.commentsFull ? 90 : videoArea.height
                sourceComponent: (root.mode === "video" && root.ready && !root.inBackground) ? videoComp : undefined
            }
        }

        // ---- Kontrol cubugu ----
        Rectangle {
            id: bar
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 56
            color: "#181818"

            Row {
                id: leftButtons
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                IconButton {
                    source: "../images/back_light.png"
                    onClicked: { if (root.fullscreen) root.fullscreen = false; else app.closeVideo(); }
                }
                IconButton { source: "../images/rewind.png"; iconSize: 30; onClicked: root.seekTo(root.position - 10000) }
                IconButton {
                    source: root.isPlaying ? "../images/pause.png" : "../images/play_w.png"
                    iconSize: 34
                    onClicked: root.togglePlay()
                }
                IconButton { source: "../images/forward.png"; iconSize: 30; onClicked: root.seekTo(root.position + 10000) }
            }
            Text {
                id: timeText
                anchors { left: leftButtons.right; leftMargin: 6; verticalCenter: parent.verticalCenter }
                width: 104
                text: root.volumeShowing ? (qsTr("Ses: %") + app.volume) : (root.fmt(root.position) + " / " + root.fmt(root.duration))
                color: root.volumeShowing ? app.brand : "#FFFFFF"
                font.pixelSize: 15
                font.bold: root.volumeShowing
            }
            Item {
                id: seekBar
                anchors { left: timeText.right; leftMargin: 8; right: fsBtn.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                height: 40
                Rectangle { id: track; anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 6; radius: 3; color: "#55FFFFFF" }
                Rectangle {
                    anchors { left: track.left; verticalCenter: track.verticalCenter }
                    height: 6; radius: 3; color: app.brand
                    width: root.duration > 0 ? track.width * Math.min(1, root.position / root.duration) : 0
                }
                Rectangle {
                    width: 18; height: 18; radius: 9; color: app.brand
                    anchors.verticalCenter: track.verticalCenter
                    x: (root.duration > 0 ? track.width * Math.min(1, root.position / root.duration) : 0) - 9
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.seekTo(root.duration * Math.max(0, Math.min(1, mouse.x / width)))
                }
            }
            IconButton {
                id: fsBtn
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                opacity: root.mode === "video" ? 1 : 0.3
                source: root.fullscreen ? "../images/exitfull.png" : "../images/fullscreen.png"
                iconSize: 28
                onClicked: root.fullscreen = !root.fullscreen
            }
        }
    }

    // ---------------- Bilgi, indirme, yorumlar, ilgili videolar ----------------
    property bool commentsFull: false        // tam ekran yorumlar (video kucuk pencerede surer)
    function openCommentsFull() {
        if (!commentsLoaded) loadComments();
        root.fullscreen = false;
        commentsFull = true;
        commentsPage.forceActiveFocus();
    }
    property string commentsNext: ""
    property bool commentsLoaded: false
    property bool commentsBusy: false
    property bool commentsOff: false
    function loadComments() {
        if (commentsBusy) return;
        commentsBusy = true;
        var seq = openSeq;
        app.api().comments(vid, commentsNext, function (d) {
            if (seq !== root.openSeq) return;
            commentsBusy = false;
            commentsLoaded = true;
            commentsOff = !!d.disabled;
            commentsNext = d.next ? d.next : "";
            var items = d.items || [];
            for (var i = 0; i < items.length; i++) {
                var c = items[i];
                commentModel.append({ author: c.author, text: c.text, published: c.published, likes: c.likes || "", replies: c.replies || "" });
            }
        }, function (msg) { if (seq === root.openSeq) { commentsBusy = false; app.showToast(msg); } });
    }

    function stateText(kind) { var t = app.dlVersion + app.dlPercent; return app.dlState(vid, kind); }

    Flickable {
        id: info
        visible: !root.fullscreen
        anchors { left: parent.left; right: parent.right; top: playerBox.bottom; bottom: parent.bottom }
        contentHeight: infoCol.height + 20
        clip: true

        Column {
            id: infoCol
            width: parent.width

            Item { width: 1; height: 10 }
            Text {
                x: 16; width: parent.width - 32
                text: root.title
                textFormat: Text.PlainText
                color: app.textPrimary
                font.pixelSize: 22; font.bold: true
                wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
            }
            Text {
                x: 16; width: parent.width - 32
                text: [root.channel, root.views, root.published].filter(function (x) { return x; }).join("  •  ")
                textFormat: Text.PlainText
                color: app.textSecondary
                font.pixelSize: 17
                elide: Text.ElideRight
            }
            Item { width: 1; height: 10 }

            // Oynatma secenekleri
            Flow {
                x: 16; width: parent.width - 32
                spacing: 10
                Pill {
                    visible: root.mode === "video"
                    label: qsTr("Sadece ses")
                    onClicked: root.switchMode("audio")
                }
                Pill {
                    visible: root.mode === "audio"
                    label: qsTr("Videoya geç")
                    onClicked: root.switchMode("video")
                }
                Pill {
                    visible: root.channelId !== ""
                    label: qsTr("Kanal")
                    accent: true
                    onClicked: app.openChannel(root.channelId, root.channel)
                }
                Pill {
                    label: qsTr("Yorumları aç")
                    onClicked: root.openCommentsFull()
                }
                Pill {
                    visible: root.localKindFor(root.vid + (app.dlVersion > -1 ? "" : "")) !== "" || tube.isComplete(root.vid, "audio")
                    label: qsTr("Dış oynatıcı")
                    onClicked: {
                        var k = root.localKindFor(root.vid);
                        var path = (root.mode === "audio" && tube.isComplete(root.vid, "audio")) || k === ""
                                   ? tube.pathFor(root.vid, "audio") : tube.pathFor(root.vid, k);
                        root.userPlaying = false;
                        if (root.videoActive) root.vplayer.pause(); else aud.pause();
                        if (!tube.openExternally(path)) app.showToast(qsTr("Açılamadı"));
                    }
                }
            }
            Item { width: 1; height: 10 }

            // Indirme secenekleri (izlemeden bagimsiz)
            Text { x: 16; text: qsTr("İndir"); color: app.textPrimary; font.pixelSize: 18; font.bold: true }
            Item { width: 1; height: 6 }
            Flow {
                x: 16; width: parent.width - 32
                spacing: 10
                Pill {
                    label: root.stateText(app.quality) !== "" ? qsTr("Video: ") + root.stateText(app.quality) : qsTr("Videoyu indir (") + app.quality + "p)"
                    dim: root.stateText(app.quality) !== ""
                    onClicked: app.download({ id: root.vid, title: root.title, channel: root.channel, seconds: root.seconds }, app.quality)
                }
                Pill {
                    label: root.stateText("audio") !== "" ? qsTr("Ses: ") + root.stateText("audio") : qsTr("Sesi indir")
                    dim: root.stateText("audio") !== ""
                    onClicked: app.download({ id: root.vid, title: root.title, channel: root.channel, seconds: root.seconds }, "audio")
                }
            }
            Text {
                x: 16; width: parent.width - 32
                visible: app.dlKey !== "" && app.dlKey.indexOf(root.vid + "_") !== 0
                text: qsTr("Şu an inen: ") + app.dlTitle + " (%" + app.dlPercent + ")"
                color: app.textSecondary; font.pixelSize: 15; elide: Text.ElideRight
            }

            Item { width: 1; height: 10 }
            Text {
                x: 16; width: parent.width - 32
                visible: root.description !== ""
                text: root.description
                textFormat: Text.PlainText
                color: app.textSecondary
                font.pixelSize: 16
                wrapMode: Text.Wrap; maximumLineCount: 4; elide: Text.ElideRight
            }

            // ---- Yorumlar ----
            Item { width: 1; height: 12 }
            Rectangle { x: 16; width: parent.width - 32; height: 1; color: app.divider }
            Item { width: 1; height: 10 }
            Text { id: commentsTitle; x: 16; text: qsTr("Yorumlar"); color: app.textPrimary; font.pixelSize: 19; font.bold: true }
            Item { width: 1; height: 6 }
            Row {
                x: 16
                spacing: 10
                Pill {
                    visible: !root.commentsLoaded
                    label: root.commentsBusy ? qsTr("Yükleniyor...") : qsTr("Yorumları göster")
                    onClicked: root.loadComments()
                }
                Pill {
                    label: qsTr("Yorumları aç (tam ekran)")
                    onClicked: root.openCommentsFull()
                }
            }
            Text {
                x: 16; width: parent.width - 32
                visible: root.commentsLoaded && commentModel.count === 0
                text: root.commentsOff ? qsTr("Bu videoda yorumlar kapalı.") : qsTr("Yorum yok.")
                color: app.textSecondary; font.pixelSize: 16
            }
            Repeater {
                model: commentModel
                delegate: Column {
                    x: 16; width: infoCol.width - 32
                    spacing: 2
                    Item { width: 1; height: 8 }
                    Text {
                        width: parent.width
                        text: model.author + "  •  " + model.published
                        textFormat: Text.PlainText
                        color: app.accentText; font.pixelSize: 15; font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: model.text
                        textFormat: Text.PlainText
                        color: app.textPrimary; font.pixelSize: 17
                        wrapMode: Text.Wrap
                    }
                    Text {
                        visible: model.likes !== "" || model.replies !== ""
                        text: [model.likes !== "" ? model.likes + qsTr(" beğeni") : "", model.replies !== "" ? model.replies + qsTr(" yanıt") : ""].filter(function (x) { return x; }).join("  •  ")
                        color: app.textSecondary; font.pixelSize: 14
                    }
                    Item { width: 1; height: 6 }
                    Rectangle { width: parent.width; height: 1; color: app.divider }
                }
            }
            Item { width: 1; height: 8 }
            Pill {
                x: 16
                visible: root.commentsLoaded && root.commentsNext !== ""
                label: root.commentsBusy ? qsTr("Yükleniyor...") : qsTr("Daha fazla yorum")
                onClicked: root.loadComments()
            }

            // ---- Ilgili videolar ----
            Item { width: 1; height: 14 }
            Text {
                x: 16
                visible: relatedModel.count > 0
                text: qsTr("İlgili videolar")
                color: app.textPrimary
                font.pixelSize: 19; font.bold: true
            }
            Repeater {
                model: relatedModel
                delegate: VideoRow {
                    width: infoCol.width
                    vid: rid
                    title: rtitle
                    channel: rchannel
                    meta: rviews
                    length: rlength
                    onClicked: app.openVideo({ id: rid, title: rtitle, channel: rchannel, channelId: rchannelId, length: rlength })
                }
            }
        }
    }

    // ---------------- Tam ekran yorumlar ----------------
    // Videonun ustune sadece bu ekran gelir; video durmaz, sag ustte kucuk pencerede surer.
    Rectangle {
        id: commentsPage
        anchors.fill: parent
        visible: root.commentsFull
        color: app.bg
        z: 10
        MouseArea { anchors.fill: parent }    // alttaki sayfaya tiklama gecmesin

        Rectangle {
            id: cHead
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 100
            color: app.surface
            Row {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                IconButton {
                    source: "../images/back" + app.iconTone + ".png"
                    onClicked: root.commentsFull = false
                }
                IconButton {
                    source: root.isPlaying ? "../images/pause.png" : "../images/play_w.png"
                    iconSize: 30
                    onClicked: root.togglePlay()
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: cHead.width - 120 - (root.mode === "video" ? 180 : 10)
                    Text { text: qsTr("Yorumlar"); color: app.textPrimary; font.pixelSize: 23; font.bold: true }
                    Text {
                        width: parent.width
                        text: root.title
                        textFormat: Text.PlainText
                        color: app.textSecondary; font.pixelSize: 15
                        elide: Text.ElideRight
                    }
                    Text {
                        text: root.fmt(root.position) + " / " + root.fmt(root.duration) + (root.mode === "audio" ? qsTr("  •  ses") : "")
                        color: app.textSecondary; font.pixelSize: 14
                    }
                }
            }
            // kucuk videonun arkasi (pencere bu alanin ustune cizilir)
            Rectangle {
                visible: root.mode === "video"
                x: parent.width - 172; y: 5; width: 160; height: 90
                color: "#000000"
            }
            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
        }

        ListView {
            id: cList
            anchors { left: parent.left; right: parent.right; top: cHead.bottom; bottom: parent.bottom }
            clip: true
            model: commentModel
            delegate: Column {
                x: 16; width: cList.width - 32
                spacing: 2
                Item { width: 1; height: 8 }
                Text {
                    width: parent.width
                    text: model.author + "  •  " + model.published
                    textFormat: Text.PlainText
                    color: app.accentText; font.pixelSize: 15; font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: model.text
                    textFormat: Text.PlainText
                    color: app.textPrimary; font.pixelSize: 18
                    wrapMode: Text.Wrap
                }
                Text {
                    visible: model.likes !== "" || model.replies !== ""
                    text: [model.likes !== "" ? model.likes + qsTr(" beğeni") : "", model.replies !== "" ? model.replies + qsTr(" yanıt") : ""].filter(function (x) { return x; }).join("  •  ")
                    color: app.textSecondary; font.pixelSize: 14
                }
                Item { width: 1; height: 6 }
                Rectangle { width: parent.width; height: 1; color: app.divider }
            }
            footer: Item {
                width: cList.width
                height: 80
                Pill {
                    anchors.centerIn: parent
                    visible: root.commentsBusy || root.commentsNext !== ""
                    label: root.commentsBusy ? qsTr("Yükleniyor...") : qsTr("Daha fazla yorum")
                    onClicked: root.loadComments()
                }
                Text {
                    anchors.centerIn: parent
                    visible: !root.commentsBusy && root.commentsLoaded && root.commentsNext === ""
                    text: commentModel.count === 0 ? (root.commentsOff ? qsTr("Bu videoda yorumlar kapalı.") : qsTr("Yorum yok.")) : qsTr("Yorumların sonu")
                    color: app.textSecondary; font.pixelSize: 16
                }
            }
        }
        // Fiziksel klavye: yukari/asagi kaydirir, geri tusu kapatir
        focus: root.commentsFull
        Keys.onPressed: {
            if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Escape) { root.commentsFull = false; event.accepted = true; }
            else if (event.key === Qt.Key_Down) { cList.contentY = Math.min(Math.max(0, cList.contentHeight - cList.height), cList.contentY + 150); event.accepted = true; }
            else if (event.key === Qt.Key_Up) { cList.contentY = Math.max(0, cList.contentY - 150); event.accepted = true; }
        }
    }

    ListModel { id: relatedModel }
    ListModel { id: commentModel }
}
