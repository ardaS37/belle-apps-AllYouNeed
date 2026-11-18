import QtQuick 1.1
import QtMultimediaKit 1.1
import "Util.js" as Util
import "Emoji.js" as Emoji
import "HaritaJs.js" as H

// Sohbet ekrani: balonlar, gun ayiraclari, mesaj yazma, medya ve sesli mesaj
Rectangle {
    id: root
    color: app.chatBg
    property bool busy: false
    property string lastTopId: ""
    property int uploadIndex: -1
    property string pendingVoice: ""
    property int msgLimit: 50          // sunucudan istenen son mesaj sayisi (50'ser artar, en fazla 200)
    property bool mayHaveOlder: false
    property bool loadingOlder: false
    property int longLimit: 700        // bundan uzun mesajlar "Devamini oku" ile kisaltilir

    // ---- Balon icinde sesli mesaj calma ----
    property string voiceMid: ""       // calinan / hazirlanan mesaj
    property string voiceName: ""      // sunucudaki dosya adi (123.mp3)
    property bool voiceLoading: false
    property bool voiceDirect: false   // yerel dosya calmadiysa sunucudan dogrudan deneniyor
    property bool voicePlaying: voice.playing && !voice.paused
    property variant durs: ({})        // mid -> sure (ms), calinmis mesajlarda sureyi gostermek icin

    function isVoice(t) { return t === "audio" || t === "ptt"; }
    function clock(ms) {
        var s = Math.max(0, Math.floor(ms / 1000));
        return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60);
    }
    function rememberDur(mid, ms) {
        if (ms <= 0 || durs[mid] === ms) return;
        var d = {};
        for (var k in durs) d[k] = durs[k];
        d[mid] = ms;
        durs = d;
    }
    // Symbian ses arka ucu: calan bir sesin kaynagi hemen degistirilirse (ya da bos verilirse)
    // uygulama cokebiliyor. Bu yuzden: once durdur, kaynagi bosaltma, yeni kaynagi kisa bir
    // beklemeden sonra ver; gecis sirasinda gelen eski durum/hata sinyallerini yok say.
    property bool voiceSwitching: false
    property string voicePendingUrl: ""

    function toggleVoice(mid, type) {
        if (mid === voiceMid && !voiceLoading) {
            if (voicePlaying) voice.pause();
            else voice.play();
            return;
        }
        if (mid === voiceMid && voiceLoading) { stopVoice(); return; }
        stopVoice();
        voiceMid = mid;
        voiceName = Util.mediaFile(type, mid);
        voiceDirect = false;
        voiceLoading = true;
        var local = device.cachedAudio(voiceName);
        if (local !== "") startVoice(device.fileUrl(local));
        else device.fetchAudio(app.mediaUrl(voiceName), voiceName);
    }
    function startVoice(url) {
        voicePendingUrl = url;
        voiceSwitching = true;
        voiceStart.restart();
    }
    Timer {
        id: voiceStart
        interval: 300
        onTriggered: {
            if (root.voiceMid === "" || root.voicePendingUrl === "") { root.voiceSwitching = false; return; }
            var same = ("" + voice.source) === root.voicePendingUrl;
            if (!same) voice.source = root.voicePendingUrl;
            root.voiceSwitching = false;
            if (same) voice.position = 0;
            voice.play();
        }
    }
    function stopVoice() {
        voiceSwitching = true;
        voiceStart.stop();
        voiceNext.stop();
        if (voice.playing) voice.stop();
        voiceMid = "";
        voiceName = "";
        voiceLoading = false;
        voicePendingUrl = "";
        voiceSwitching = false;
    }
    function voiceFailed(msg) {
        if (voiceSwitching || voiceMid === "") return;
        notify.log("ses hatasi (" + voiceName + (voiceDirect ? ", dogrudan" : "") + "): " + msg);
        if (!voiceDirect) {
            // Yerel dosya calinamadiysa sunucudaki dosyayi dogrudan dene
            voiceDirect = true;
            voiceLoading = true;
            if (voice.playing) voice.stop();
            startVoice(app.mediaUrl(voiceName));
            return;
        }
        stopVoice();
        app.showToast(qsTr("Sesli mesaj çalınamadı") + (msg ? ": " + msg : ""));
    }
    // Bitince arkasindan gelen sesli mesaja gec (ayni kisiden, araya baska mesaj girmeden)
    property string voiceNextMid: ""
    property string voiceNextType: ""
    function voiceEnded() {
        if (voiceSwitching || voiceMid === "" || voiceLoading) return;
        var mid = voiceMid;
        var idx = -1;
        for (var i = 0; i < msgModel.count; i++) if (msgModel.get(i).mid === mid) { idx = i; break; }
        stopVoice();
        if (idx >= 0 && idx + 1 < msgModel.count) {
            var a = msgModel.get(idx), b = msgModel.get(idx + 1);
            if (isVoice(b.type) && b.mine === a.mine && b.author === a.author && !b.mine) {
                voiceNextMid = b.mid; voiceNextType = b.type;
                voiceNext.restart();
            }
        }
    }
    Timer { id: voiceNext; interval: 400; onTriggered: if (root.voiceMid === "") root.toggleVoice(root.voiceNextMid, root.voiceNextType) }
    function seekVoice(mid, frac) {
        if (mid !== voiceMid || voiceLoading || voice.duration <= 0) return;
        voice.position = Math.round(Math.max(0, Math.min(1, frac)) * voice.duration);
    }

    function togglePlaying() {
        if (voiceMid === "" || voiceLoading) return;
        if (voicePlaying) voice.pause(); else voice.play();
    }
    function applyVolume() {
        // Symbian: ayni deger yeniden verilince uygulanmiyor; once biraz degistir
        var v = app.volume / 100;
        voice.volume = v > 0.01 ? v - 0.01 : 0.01;
        voice.volume = v;
    }
    Connections { target: app; onVolumeChanged: root.applyVolume() }

    Audio {
        id: voice
        onPlayingChanged: if (playing && !root.voiceSwitching) { root.voiceLoading = false; root.applyVolume(); }
        onStatusChanged: {
            if (root.voiceSwitching) return;
            if (status === Audio.Loaded || status === Audio.Buffered) {
                root.applyVolume();
                if (root.voiceMid !== "") root.rememberDur(root.voiceMid, duration);
            }
            if (status === Audio.EndOfMedia) root.voiceEnded();
            if (status === Audio.InvalidMedia) root.voiceFailed(qsTr("geçersiz ses"));
        }
        onDurationChanged: if (!root.voiceSwitching && root.voiceMid !== "" && duration > 0) root.rememberDur(root.voiceMid, duration)
        onError: if (error !== Audio.NoError) root.voiceFailed(errorString)
    }

    function reset() {
        stopVoice();
        msgModel.clear();
        lastTopId = "";
        msgLimit = 50;
        mayHaveOlder = false;
        loadingOlder = false;
        composer.text = "";
        sheet.visible = false;
        emojiSheet.visible = false;
        picker.visible = false;
        tepkiPanel.visible = false;
        if (konumEkrani.visible) konumEkrani.kapat();
        focusTimer.restart();
        if (device.recording) device.cancelRecording();
    }

    function isMine(sender) { return Util.bareId(sender) === app.me; }

    function refresh(silent, force) {
        if (busy || app.peerId === "") return;
        busy = true;
        var peerAtRequest = app.peerId;
        app.apiMessages(app.peerId, msgLimit, function (msgs) {
            busy = false;
            if (peerAtRequest !== app.peerId) return;
            mayHaveOlder = msgs.length >= msgLimit && msgLimit < 200;
            var topId = msgs.length > 0 ? ("" + msgs[0]._id) : "";
            if (!force && topId !== "" && topId === lastTopId && !hasPending()) return;
            lastTopId = topId;
            merge(msgs);
            if (msgs.length > 0) app.markSeen(app.peerId, msgs[0].createdAt);
        }, function (msg) {
            busy = false;
            loadingOlder = false;
            if (!silent) app.showToast(msg);
        });
    }

    function loadOlder() {
        if (busy || msgLimit >= 200) return;
        msgLimit = msgLimit + 50;
        loadingOlder = true;
        refresh(false, true);
    }

    function hasPending() {
        for (var i = 0; i < msgModel.count; i++)
            if (msgModel.get(i).pending) return true;
        return false;
    }

    function pad6(n) { var s = "" + n; while (s.length < 6) s = "0" + s; return s; }

    // Sunucudan gelenleri ekrandakilerle birlestir: ekranda olup yeni listede olmayan
    // eski mesajlar silinmez (en fazla 200 mesaj tutulur).
    function merge(msgs) {
        var wasAtEnd = msgModel.count === 0 || list.atYEnd || (list.contentY + list.height >= list.contentHeight - 120);
        var oldCount = msgModel.count;
        var byId = {};
        var arr = [];
        var pendingLocal = [];
        var upload = null;
        for (var i = 0; i < msgModel.count; i++) {
            var e = msgModel.get(i);
            if (e.type === "upload") { if (device.uploading) upload = e.body; continue; }
            if (e.pending || e.failed) { pendingLocal.push({ mid: e.mid, mine: e.mine, author: e.author, body: e.body, type: e.type, ts: e.ts, day: e.day, pending: e.pending, failed: e.failed, expanded: false, quoteName: "", quoteText: "", waId: "", locLat: 0, locLng: 0, locAd: "", locAdres: "", tepki: e.tepki ? e.tepki : "" }); continue; }
            var o = { mid: e.mid, mine: e.mine, author: e.author, body: e.body, type: e.type, ts: e.ts, day: e.day,
                      pending: false, failed: false, expanded: e.expanded, quoteName: e.quoteName, quoteText: e.quoteText, key: e.ts + "#" + pad6(i),
                      waId: e.waId, locLat: e.locLat, locLng: e.locLng, locAd: e.locAd, locAdres: e.locAdres, tepki: e.tepki };
            byId[o.mid] = o;
            arr.push(o);
        }
        var n = msgs.length;
        for (var j = n - 1; j >= 0; j--) {          // sunucu yeniden eskiye siraliyor
            var m = msgs[j];
            var type = m.chatType ? m.chatType : "chat";
            var text = m.message ? m.message : "";
            if (type !== "chat" && text === type + " received") text = "";
            var mid = "" + m._id;
            var ts = m.createdAt ? m.createdAt : "";
            var loc = m.location && m.location.lat !== undefined ? m.location : H.metindenKonum(text);
            var item = { mid: mid, mine: isMine(m.sender), author: m.senderName ? m.senderName : "",
                         body: text, type: type, ts: ts, day: Util.dayLabel(ts),
                         pending: false, failed: false, expanded: false,
                         quoteName: m.quote && m.quote.name ? m.quote.name : "", quoteText: m.quote && m.quote.text ? m.quote.text : "",
                         key: ts + "#" + pad6(500000 + (n - j)),
                         waId: m.waId ? "" + m.waId : "", locLat: loc ? loc.lat : 0, locLng: loc ? loc.lng : 0,
                         locAd: loc && loc.ad ? loc.ad : "", locAdres: loc && loc.adres ? loc.adres : "", tepki: "" };
            if (byId[mid]) { item.expanded = byId[mid].expanded; byId[mid].body = item.body; byId[mid].type = item.type; byId[mid].quoteName = item.quoteName; byId[mid].quoteText = item.quoteText; byId[mid].waId = item.waId; byId[mid].locLat = item.locLat; byId[mid].locLng = item.locLng; byId[mid].locAd = item.locAd; byId[mid].locAdres = item.locAdres; continue; }
            byId[mid] = item;
            arr.push(item);
        }
        arr.sort(function (a, b) { return a.key < b.key ? -1 : (a.key > b.key ? 1 : 0); });
        if (arr.length > 200) arr = arr.slice(arr.length - 200);

        // gonderilmis ve sunucudan donmus yerel mesajlari ele
        var stillPending = [];
        for (var p = 0; p < pendingLocal.length; p++) {
            var found = false;
            if (!pendingLocal[p].failed) {
                for (var q = arr.length - 1; q >= 0 && q >= arr.length - 10; q--)
                    if (arr[q].mine && arr[q].body === pendingLocal[p].body) { found = true; break; }
            }
            if (!found) stillPending.push(pendingLocal[p]);
        }

        // Hedef liste
        var target = [];
        for (var k = 0; k < arr.length; k++) {
            var a = arr[k];
            target.push({ mid: a.mid, mine: a.mine, author: a.author, body: a.body, type: a.type, ts: a.ts,
                          day: a.day, pending: false, failed: false, expanded: a.expanded ? true : false,
                          quoteName: a.quoteName ? a.quoteName : "", quoteText: a.quoteText ? a.quoteText : "",
                          waId: a.waId ? a.waId : "", locLat: a.locLat ? a.locLat : 0, locLng: a.locLng ? a.locLng : 0, locAd: a.locAd ? a.locAd : "", locAdres: a.locAdres ? a.locAdres : "", tepki: a.tepki ? a.tepki : "" });
        }
        for (var s = 0; s < stillPending.length; s++) target.push(stillPending[s]);
        if (upload !== null)
            target.push({ mid: "upload", mine: true, author: "", body: upload, type: "upload", ts: "",
                          day: qsTr("BUGÜN"), pending: true, failed: false, expanded: false, quoteName: "", quoteText: "", waId: "", locLat: 0, locLng: 0, locAd: "", locAdres: "", tepki: "" });

        // Modeli silip yeniden doldurmak yerine yerinde guncelle:
        // boylece liste en basa ziplamaz, okunan yer korunur.
        var keep = {};
        for (var t = 0; t < target.length; t++) keep[target[t].mid] = true;
        for (var r = msgModel.count - 1; r >= 0; r--)
            if (!keep[msgModel.get(r).mid]) msgModel.remove(r);
        for (var x = 0; x < target.length; x++) {
            var f = target[x];
            if (x < msgModel.count && msgModel.get(x).mid === f.mid) {
                var cur = msgModel.get(x);
                if (cur.body !== f.body) msgModel.setProperty(x, "body", f.body);
                if (cur.type !== f.type) msgModel.setProperty(x, "type", f.type);
                if (cur.day !== f.day) msgModel.setProperty(x, "day", f.day);
                if (cur.pending !== f.pending) msgModel.setProperty(x, "pending", f.pending);
                if (cur.failed !== f.failed) msgModel.setProperty(x, "failed", f.failed);
                if (cur.quoteText !== f.quoteText) { msgModel.setProperty(x, "quoteName", f.quoteName); msgModel.setProperty(x, "quoteText", f.quoteText); }
                if (cur.waId !== f.waId) msgModel.setProperty(x, "waId", f.waId);
                if (cur.locLat !== f.locLat || cur.locAd !== f.locAd) { msgModel.setProperty(x, "locLat", f.locLat); msgModel.setProperty(x, "locLng", f.locLng); msgModel.setProperty(x, "locAd", f.locAd); msgModel.setProperty(x, "locAdres", f.locAdres); }
            } else {
                for (var y = x + 1; y < msgModel.count; y++)
                    if (msgModel.get(y).mid === f.mid) { msgModel.remove(y); break; }
                msgModel.insert(x, f);
            }
        }
        while (msgModel.count > target.length) msgModel.remove(msgModel.count - 1);
        uploadIndex = -1;
        for (var u = msgModel.count - 1; u >= 0; u--)
            if (msgModel.get(u).mid === "upload") { uploadIndex = u; break; }

        if (loadingOlder) {
            loadingOlder = false;
            list.positionViewAtIndex(Math.max(0, msgModel.count - oldCount), ListView.Beginning);
        } else if (wasAtEnd) {
            scrollToEnd();
        }
    }

    function scrollMessages(dir) {
        if (msgModel.count === 0) return;
        if (dir > 0 && list.atYEnd) return;
        if (dir < 0 && list.atYBeginning) return;
        var step = Math.round(list.height * 0.6);
        var y = list.contentY + dir * step;
        var endY = list.contentHeight - list.height;
        if (dir > 0 && y >= endY) { scrollToEnd(); return; }
        if (dir < 0 && (y <= 0 || list.indexAt(10, y + 10) === 0)) { list.positionViewAtIndex(0, ListView.Beginning); return; }
        list.contentY = y;
    }

    function scrollToEnd() {
        if (msgModel.count > 0) list.positionViewAtIndex(msgModel.count - 1, ListView.End);
    }

    function addUploadBubble(label, scroll) {
        msgModel.append({ mid: "upload", mine: true, author: "", body: label, type: "upload",
                          ts: "", day: qsTr("BUGÜN"), pending: true, failed: false, expanded: false, quoteName: "", quoteText: "", waId: "", locLat: 0, locLng: 0, locAd: "", locAdres: "", tepki: "" });
        uploadIndex = msgModel.count - 1;
        if (scroll !== false) scrollToEnd();
    }

    function send() {
        var text = composer.text.replace(/^\s+|\s+$/g, "");
        if (text.length === 0) return;
        composer.text = "";
        var idx = msgModel.count;
        msgModel.append({ mid: "local" + new Date().getTime(), mine: true, author: "", body: text, type: "chat",
                          ts: "", day: qsTr("BUGÜN"), pending: true, failed: false, expanded: false, quoteName: "", quoteText: "", waId: "", locLat: 0, locLng: 0, locAd: "", locAdres: "", tepki: "" });
        composer.forceActiveFocus();
        scrollToEnd();
        app.apiSend(app.peerId, text, function () {
            // "bekliyor" olarak kalir; sunucudan geri donunce merge() yerini gercek mesaja birakir
            lastTopId = "";
            refreshAfterSend.restart();
        }, function (msg) {
            if (idx < msgModel.count) { msgModel.setProperty(idx, "pending", false); msgModel.setProperty(idx, "failed", true); }
            app.showToast(msg);
        });
    }

    function sendFile(path, label) {
        if (device.uploading) { app.showToast(qsTr("Önceki gönderim sürüyor")); return; }
        addUploadBubble(label + qsTr(" gönderiliyor..."));
        device.upload(app.uploadUrl(), app.apiKey, app.me, app.peerId, path);
    }

    // ---- Ifade (tepki) ve kopyalama ----
    property variant tepkiler: ["1f44d", "2764", "1f602", "1f62e", "1f622", "1f64f", "1f60d", "1f525", "1f44f", "1f621", "1f389", "1f914"]
    function tepkiAc(i) {
        if (i < 0 || i >= msgModel.count) return;
        var m = msgModel.get(i);
        if (m.type === "upload" || m.pending || m.failed) return;
        tepkiPanel.idx = i;
        tepkiPanel.visible = true;
    }
    function tepkiGonder(hex) {
        var i = tepkiPanel.idx;
        tepkiPanel.visible = false;
        if (i < 0 || i >= msgModel.count) return;
        var m = msgModel.get(i);
        if (!m.waId) { app.showToast(qsTr("Bu mesaja ifade bırakılamıyor")); return; }
        var onceki = m.tepki, mid = m.mid;
        // WhatsApp kirmizi kalbi "❤️" (degisken secicili) bekler
        var ch = hex === "" ? "" : Emoji.charFor(hex) + (hex === "2764" ? "️" : "");
        msgModel.setProperty(i, "tepki", hex);
        app.apiReact(m.waId, ch, function () { }, function (msg) {
            for (var k = 0; k < msgModel.count; k++) if (msgModel.get(k).mid === mid) { msgModel.setProperty(k, "tepki", onceki); break; }
            app.showToast(msg);
        });
    }
    function kopyala(i) {
        if (i < 0 || i >= msgModel.count) return;
        var m = msgModel.get(i);
        var t = m.body;
        if (m.locLat !== 0 || m.locLng !== 0) t = (m.locAd !== "" ? m.locAd + "\n" : "") + (m.locAdres !== "" ? m.locAdres + "\n" : "") + H.googleUrl(m.locLat, m.locLng);
        if (t === "" || m.type === "upload") { app.showToast(qsTr("Kopyalanacak metin yok")); return; }
        device.setClipboard(t);
        app.showToast(qsTr("Mesaj kopyalandı"));
    }

    // ---- Konum gonderme ----
    function konumGonder(lat, lng, ad, adres) {
        var etiket = ad !== "" ? qsTr("Konum: ") + ad : qsTr("Konum");
        var idx = msgModel.count;
        msgModel.append({ mid: "local" + new Date().getTime(), mine: true, author: "", body: etiket, type: "location",
                          ts: "", day: qsTr("BUGÜN"), pending: true, failed: false, expanded: false, quoteName: "", quoteText: "",
                          waId: "", locLat: lat, locLng: lng, locAd: ad, locAdres: adres, tepki: "" });
        scrollToEnd();
        app.apiSendLocation(app.peerId, lat, lng, ad, adres, function () {
            lastTopId = "";
            refreshAfterSend.restart();
        }, function (msg) {
            if (idx < msgModel.count) { msgModel.setProperty(idx, "pending", false); msgModel.setProperty(idx, "failed", true); }
            app.showToast(msg);
        });
    }

    Timer { id: refreshAfterSend; interval: 1500; onTriggered: { root.lastTopId = ""; root.refresh(true); } }
    // Fiziksel klavye: sohbet acilinca yazma kutusu hazir odakli olsun (sanal klavye acilmaz)
    Timer { id: focusTimer; interval: 350; onTriggered: if (app.chatOpen) composer.forceActiveFocus() }
    function focusComposer() { composer.forceActiveFocus(); }

    // Panelden secilen emojiyi imlecin oldugu yere ekle
    function insertEmoji(hex) {
        var ch = Emoji.charFor(hex);
        var pos = composer.cursorPosition;
        var t = composer.text;
        composer.text = t.substring(0, pos) + ch + t.substring(pos);
        composer.cursorPosition = pos + ch.length;
        composer.forceActiveFocus();
    }
    // Kayit durdurulduktan sonra dosyanin kapanmasini bekle, sonra gonder
    Timer {
        id: voiceSendDelay
        interval: 900
        onTriggered: { if (root.pendingVoice !== "") { root.sendFile(root.pendingVoice, qsTr("Sesli mesaj")); root.pendingVoice = ""; } }
    }

    Connections {
        target: device
        onUploadProgress: {
            if (root.uploadIndex >= 0 && root.uploadIndex < msgModel.count)
                msgModel.setProperty(root.uploadIndex, "body", qsTr("Gönderiliyor... %") + percent);
        }
        onUploadFinished: {
            if (root.uploadIndex >= 0 && root.uploadIndex < msgModel.count) {
                msgModel.setProperty(root.uploadIndex, "pending", false);
                if (ok) msgModel.setProperty(root.uploadIndex, "body", qsTr("Gönderildi"));
                else { msgModel.setProperty(root.uploadIndex, "failed", true); msgModel.setProperty(root.uploadIndex, "body", message); }
            }
            if (!ok) app.showToast(message);
            root.lastTopId = "";
            refreshAfterSend.interval = ok ? 3000 : 1500;
            refreshAfterSend.restart();
        }
        onRecordSeconds: recTime.text = Math.floor(seconds / 60) + ":" + (seconds % 60 < 10 ? "0" : "") + (seconds % 60)
        onRecordError: app.showToast(qsTr("Kayıt başlatılamadı: ") + message)
        onAudioReady: if (name === root.voiceName && root.voiceLoading) root.startVoice(device.fileUrl(path))
        onAudioFailed: if (name === root.voiceName) { root.voiceDirect = true; root.voiceFailed(message); }
    }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        z: 2
        showBack: true
        avatarName: app.peerName
        avatarKey: app.peerId
        avatarPeer: app.peerId
        title: app.peerName
        subtitle: Util.isGroup(app.peerId) ? qsTr("Grup") : "+" + Util.bareId(app.peerId)
        busy: root.busy
        onBack: app.closeChat()
        IconButton { source: "../images/refresh" + app.iconTone + ".png"; onClicked: { root.lastTopId = ""; root.refresh(false); } }
    }

    ListModel { id: msgModel }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: inputBar.top }
        model: msgModel
        clip: true
        spacing: 4
        cacheBuffer: 800
        header: Item {
            width: list.width
            height: root.mayHaveOlder ? 66 : 8
            Rectangle {
                visible: root.mayHaveOlder
                anchors.centerIn: parent
                width: olderText.paintedWidth + 40
                height: 44
                radius: 22
                color: olderMa.pressed ? app.pressed : app.chip
                Text {
                    id: olderText
                    anchors.centerIn: parent
                    text: root.loadingOlder ? qsTr("Yükleniyor...") : qsTr("Daha eski mesajlar")
                    color: app.accentText
                    font.pixelSize: 18
                    font.bold: true
                }
                MouseArea { id: olderMa; anchors.fill: parent; onClicked: root.loadOlder() }
            }
        }
        footer: Item { width: list.width; height: 10 }

        section.property: "day"
        section.criteria: ViewSection.FullString
        section.delegate: Item {
            width: list.width
            height: 52
            Rectangle {
                anchors.centerIn: parent
                width: dayText.paintedWidth + 28
                height: 32
                radius: 9
                color: app.chip
                Text { id: dayText; anchors.centerIn: parent; text: section; color: app.textSecondary; font.pixelSize: 16; font.bold: true }
            }
        }

        delegate: Item {
            id: row
            width: list.width
            height: bubble.height + (tepki !== "" ? 20 : 4)

            property int maxW: Math.round(list.width * 0.74)
            property bool isMedia: type === "image" || type === "audio" || type === "ptt" || type === "video"
            property bool showAuthor: !mine && Util.isGroup(app.peerId) && author !== ""
            property string mediaUrl: isMedia ? app.mediaUrl(Util.mediaFile(type, mid)) : ""
            property bool isLong: body.length > root.longLimit
            property string shownText: (isLong && !expanded) ? body.substring(0, root.longLimit) + "…" : body
            property bool emo: Emoji.has(body)
            property bool isLoc: locLat !== 0 || locLng !== 0
            // konum karti: 15. yakinliktaki karolardan noktayi ortalayan 2x2 parca
            property real lwx: isLoc ? H.lngX(locLng, 15) : 0
            property real lwy: isLoc ? H.latY(locLat, 15) : 0

            // Genislik olcumu sadece ilk 200 karakterle (uzun mesajlarda gereksiz yuk olmasin)
            Text { id: measure; visible: false; text: body.substring(0, 200); textFormat: Text.PlainText; font.pixelSize: 22 }
            Text { id: qMeasure; visible: false; text: quoteText.substring(0, 80); textFormat: Text.PlainText; font.pixelSize: 17 }

            Rectangle {
                id: bubble
                x: mine ? row.width - width - 16 : 16
                radius: 12
                color: mine ? app.bubbleOut : app.bubbleIn
                smooth: true

                property int contentW: Math.max(
                        Math.min(measure.paintedWidth, row.maxW - 28),
                        meta.width + 8,
                        row.showAuthor ? Math.min(authorText.paintedWidth, row.maxW - 28) : 0,
                        row.isMedia ? (type === "image" ? 280 : 260) : 0,
                        row.isLoc ? 280 : 0,
                        quoteText !== "" ? Math.min(qMeasure.paintedWidth + 26, row.maxW - 28) : 0)
                width: contentW + 28
                height: content.height + 20

                // Bir kez dokun: ifade birak; basili tut: kopyala (resim/ses/konum kendi dokunmasini kullanir)
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.tepkiAc(index)
                    onPressAndHold: root.kopyala(index)
                }

                // Birakilan ifade (balonun alt kosesinde)
                Rectangle {
                    visible: tepki !== ""
                    z: 2
                    anchors { bottom: parent.bottom; bottomMargin: -16; left: mine ? undefined : parent.left; leftMargin: 10; right: mine ? parent.right : undefined; rightMargin: 10 }
                    width: 34; height: 30; radius: 15
                    color: app.surface
                    border.width: 1; border.color: app.divider
                    Image { anchors.centerIn: parent; width: 22; height: 22; smooth: true; source: tepki !== "" ? Emoji.imgPath(tepki) : "" }
                }

                Column {
                    id: content
                    x: 14
                    y: 9
                    width: bubble.contentW
                    spacing: 4

                    Text {
                        id: authorText
                        visible: row.showAuthor
                        text: author
                        color: Util.colorFor(author)
                        font.pixelSize: 18
                        font.bold: true
                    }

                    // Alinti (yanitlanan mesaj): ilk kelimeler ya da "Alintilanan fotograf"
                    Rectangle {
                        visible: quoteText !== ""
                        width: parent.width
                        height: visible ? qCol.height + 12 : 0
                        radius: 8
                        color: app.dark ? "#26000000" : "#14000000"
                        Rectangle { width: 4; height: parent.height; radius: 2; color: app.brand }
                        Column {
                            id: qCol
                            x: 12; y: 6
                            width: parent.width - 20
                            Text {
                                width: parent.width
                                visible: quoteName !== ""
                                text: quoteName
                                textFormat: Text.PlainText
                                color: app.accentText
                                font.pixelSize: 16
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: Emoji.has(quoteText) ? Emoji.rich(quoteText, 18) : quoteText
                                textFormat: Emoji.has(quoteText) ? Text.RichText : Text.PlainText
                                color: app.textSecondary
                                font.pixelSize: 17
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Rectangle {
                        visible: type === "image"
                        width: parent.width
                        height: visible ? (img.status === Image.Ready ? img.paintedHeight : 180) : 0
                        color: app.pressed
                        radius: 8
                        clip: true
                        Image {
                            id: img
                            width: parent.width
                            fillMode: Image.PreserveAspectFit
                            sourceSize.width: 280
                            asynchronous: true
                            source: type === "image" ? row.mediaUrl : ""
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: img.status !== Image.Ready
                            text: img.status === Image.Error ? qsTr("Fotoğraf yüklenemedi") : qsTr("Yükleniyor...")
                            color: app.textSecondary
                            font.pixelSize: 17
                        }
                        MouseArea { anchors.fill: parent; onClicked: Qt.openUrlExternally(app.duzHttp(row.mediaUrl)) }
                    }

                    // Konum karti: kucuk harita + ad; dokununca uygulama ici haritada acilir
                    Rectangle {
                        visible: row.isLoc
                        width: parent.width
                        height: visible ? lCol.height + 156 : 0
                        radius: 8
                        clip: true
                        color: app.pressed
                        Item {
                            id: lHarita
                            width: parent.width; height: 150
                            clip: true
                            property int bx: Math.floor((row.lwx - width / 2) / 256)
                            property int by: Math.floor((row.lwy - height / 2) / 256)
                            Repeater {
                                model: row.isLoc ? 4 : 0
                                Image {
                                    property int tx: lHarita.bx + index % 2
                                    property int ty: lHarita.by + Math.floor(index / 2)
                                    x: Math.round(tx * 256 - (row.lwx - lHarita.width / 2))
                                    y: Math.round(ty * 256 - (row.lwy - lHarita.height / 2))
                                    width: 256; height: 256
                                    asynchronous: true
                                    source: H.karoUrl(app.dark ? "koyu" : "acik", 15, tx, ty)
                                }
                            }
                            Item {
                                x: lHarita.width / 2; y: lHarita.height / 2
                                Rectangle { x: -13; y: -38; width: 26; height: 26; radius: 13; color: "#ea4335"; border.color: "#b31412"; border.width: 2; smooth: true }
                                Rectangle { x: -5; y: -30; width: 10; height: 10; radius: 5; color: "white"; smooth: true }
                                Rectangle { x: -2; y: -14; width: 4; height: 14; color: "#b31412" }
                            }
                        }
                        Column {
                            id: lCol
                            anchors { left: parent.left; right: parent.right; top: lHarita.bottom; leftMargin: 10; rightMargin: 10; topMargin: 4 }
                            Text { width: parent.width; text: locAd !== "" ? locAd : qsTr("Konum"); font.pixelSize: 19; font.bold: true; color: app.textPrimary; elide: Text.ElideRight }
                            Text { width: parent.width; visible: locAdres !== ""; text: locAdres; font.pixelSize: 15; color: app.textSecondary; elide: Text.ElideRight }
                            Text { text: qsTr("Haritada açmak için dokunun"); font.pixelSize: 15; color: app.accentText }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: konumEkrani.goster(locLat, locLng, locAd, locAdres)
                            onPressAndHold: root.kopyala(index)
                        }
                    }

                    // Sesli mesaj: balonun icinde cal / duraklat, cubuga dokunarak sar
                    Item {
                        id: vp
                        visible: root.isVoice(type)
                        width: parent.width
                        height: visible ? 62 : 0
                        property bool active: visible && root.voiceMid === mid
                        property bool loading: active && root.voiceLoading
                        property bool playingNow: active && root.voicePlaying
                        property int dur: active && voice.duration > 0 ? voice.duration : (root.durs[mid] ? root.durs[mid] : 0)
                        property real frac: active && voice.duration > 0 ? voice.position / voice.duration : 0

                        Rectangle {
                            id: vBtn
                            anchors.verticalCenter: parent.verticalCenter
                            width: 50; height: 50; radius: 25
                            color: vBtnMa.pressed ? app.brandPressed : app.brand
                            smooth: true
                            Image {
                                visible: !vp.playingNow && !vp.loading
                                anchors.centerIn: parent; anchors.horizontalCenterOffset: 2
                                width: 28; height: 28; smooth: true; source: "../images/play.png"
                            }
                            Row {                       // duraklat simgesi
                                visible: vp.playingNow
                                anchors.centerIn: parent
                                spacing: 6
                                Rectangle { width: 6; height: 22; radius: 1; color: "white" }
                                Rectangle { width: 6; height: 22; radius: 1; color: "white" }
                            }
                            Row {                       // hazirlaniyor: uc nokta
                                visible: vp.loading
                                anchors.centerIn: parent
                                spacing: 5
                                Repeater {
                                    model: 3
                                    Rectangle {
                                        width: 7; height: 7; radius: 3.5; color: "white"
                                        SequentialAnimation on opacity {
                                            running: vp.loading
                                            loops: Animation.Infinite
                                            PauseAnimation { duration: index * 150 }
                                            NumberAnimation { to: 0.25; duration: 300 }
                                            NumberAnimation { to: 1; duration: 300 }
                                            PauseAnimation { duration: (2 - index) * 150 }
                                        }
                                    }
                                }
                            }
                            MouseArea {
                                id: vBtnMa
                                anchors { fill: parent; margins: -6 }
                                onClicked: root.toggleVoice(mid, type)
                                onPressAndHold: Qt.openUrlExternally(app.duzHttp(row.mediaUrl))
                            }
                        }
                        Item {
                            id: track
                            anchors { left: vBtn.right; leftMargin: 14; right: parent.right; rightMargin: 4; top: parent.top; topMargin: 14 }
                            height: 16
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; height: 5; radius: 2.5
                                color: app.dark ? "#55FFFFFF" : "#33000000"
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.round(parent.width * vp.frac); height: 5; radius: 2.5
                                color: app.brand
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.round((parent.width - width) * vp.frac)
                                width: 16; height: 16; radius: 8
                                color: vp.active ? app.brand : (app.dark ? "#AAFFFFFF" : "#88000000")
                                smooth: true
                            }
                            MouseArea {
                                anchors { fill: parent; topMargin: -14; bottomMargin: -10 }
                                onClicked: {
                                    if (vp.active && voice.duration > 0) root.seekVoice(mid, mouse.x / track.width);
                                    else root.toggleVoice(mid, type);
                                }
                            }
                        }
                        Text {
                            anchors { left: track.left; top: track.bottom; topMargin: 6 }
                            text: vp.loading ? qsTr("Hazırlanıyor...")
                                  : (vp.active && voice.duration > 0 ? root.clock(voice.position) + " / " + root.clock(vp.dur)
                                  : (vp.dur > 0 ? root.clock(vp.dur) : (type === "ptt" ? qsTr("Sesli mesaj") : qsTr("Ses"))))
                            color: app.textSecondary
                            font.pixelSize: 16
                        }
                    }

                    Item {
                        visible: type === "video"
                        width: parent.width
                        height: visible ? 60 : 0
                        Rectangle {
                            id: playBtn
                            anchors.verticalCenter: parent.verticalCenter
                            width: 50; height: 50; radius: 25
                            color: app.brand
                            Image { anchors.centerIn: parent; width: 28; height: 28; smooth: true; source: "../images/play.png" }
                        }
                        Text {
                            anchors { left: playBtn.right; leftMargin: 12; right: parent.right; verticalCenter: parent.verticalCenter }
                            text: Util.mediaLabel(type) + qsTr("\nAçmak için dokunun")
                            color: app.textSecondary
                            font.pixelSize: 18
                        }
                        MouseArea { anchors.fill: parent; onClicked: Qt.openUrlExternally(app.duzHttp(row.mediaUrl)) }
                    }

                    Text {
                        visible: body !== "" && !(type === "location" && row.isLoc)
                        width: parent.width
                        // Emojili mesajlar zengin metin (emojiler resim), digerleri duz metin ("<" HTML sanilmasin)
                        text: row.emo ? Emoji.rich(row.shownText, 26) : row.shownText
                        textFormat: row.emo ? Text.RichText : Text.PlainText
                        wrapMode: Text.Wrap
                        color: type === "upload" ? app.textSecondary : app.textPrimary
                        font.pixelSize: 22
                        font.italic: type === "upload"
                    }
                    Text {
                        visible: row.isLong
                        text: expanded ? qsTr("Daralt") : qsTr("Devamını oku (") + Math.round(body.length / 100) / 10 + qsTr(" bin karakter)")
                        color: app.accentText
                        font.pixelSize: 19
                        font.bold: true
                        MouseArea {
                            anchors { fill: parent; margins: -10 }
                            onClicked: msgModel.setProperty(index, "expanded", !expanded)
                        }
                    }

                    Row {
                        id: meta
                        anchors.right: parent.right
                        spacing: 4
                        Text {
                            text: failed ? qsTr("Gönderilemedi") : (pending ? (type === "upload" ? "" : qsTr("Gönderiliyor...")) : Util.timeText(ts))
                            color: failed ? app.danger : app.textSecondary
                            font.pixelSize: 15
                        }
                        Image {
                            visible: mine && !pending && !failed && type !== "upload"
                            width: 20; height: 20; smooth: true
                            source: "../images/ticks.png"
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.centerIn: list
        visible: msgModel.count === 0 && !root.busy
        width: emptyText.paintedWidth + 40
        height: emptyText.paintedHeight + 24
        radius: 10
        color: app.noteBg
        Text {
            id: emptyText
            anchors.centerIn: parent
            width: Math.min(420, root.width - 100)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: qsTr("Henüz mesaj yok. İlk mesajı siz gönderin.")
            color: app.noteText
            font.pixelSize: 18
        }
    }

    // ---- Mesaj yazma cubugu ----
    Item {
        id: inputBar
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: device.recording ? 76 : Math.max(76, composerBox.height + 18)

        // Normal mod
        Item {
            anchors.fill: parent
            visible: !device.recording

            IconButton {
                id: attachBtn
                anchors { left: parent.left; leftMargin: 4; bottom: parent.bottom; bottomMargin: 8 }
                source: "../images/attach" + app.iconTone + ".png"
                onClicked: { emojiSheet.visible = false; sheet.visible = !sheet.visible; }
            }
            IconButton {
                id: emojiBtn
                anchors { left: attachBtn.right; leftMargin: -6; bottom: parent.bottom; bottomMargin: 8 }
                source: "../images/emoji" + app.iconTone + ".png"
                onClicked: { sheet.visible = false; emojiSheet.visible = !emojiSheet.visible; if (!emojiSheet.visible) root.focusComposer(); }
            }
            // Cok satirli yazma kutusu: 3-4 satira kadar buyur, sonra kaydirilir
            Rectangle {
                id: composerBox
                anchors { left: emojiBtn.right; leftMargin: 2; right: actionBtn.left; rightMargin: 10; bottom: parent.bottom; bottomMargin: 9 }
                height: Math.min(150, Math.max(58, composer.paintedHeight + 28))
                radius: 29
                color: app.dark ? "#2A3942" : "#FFFFFF"
                border.width: composer.activeFocus ? 2 : 0
                border.color: app.brand

                Flickable {
                    id: flick
                    anchors { fill: parent; leftMargin: 22; rightMargin: 18; topMargin: 14; bottomMargin: 14 }
                    contentWidth: width
                    contentHeight: composer.paintedHeight
                    clip: true
                    function ensureVisible(r) {
                        if (contentY >= r.y) contentY = r.y;
                        else if (contentY + height <= r.y + r.height) contentY = r.y + r.height - height;
                    }
                    TextEdit {
                        id: composer
                        // Ctrl+V yapistir / Ctrl+A tumunu sec (E6: Ctrl+V "7" ya da kod 22 gonderir)
                        Keys.onPressed: {
                            if (((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_V || event.text === "7" || event.text === "v")) || event.text === "\u0016") { pano.yapistir(composer); event.accepted = true; }
                            else if (((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_A || event.text === "a")) || event.text === "\u0001") { composer.selectAll(); event.accepted = true; }
                        }
                        width: flick.width
                        wrapMode: TextEdit.Wrap
                        textFormat: TextEdit.PlainText
                        font.pixelSize: 22
                        color: app.textPrimary
                        selectionColor: app.brand
                        onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
                        Keys.onReturnPressed: { root.send(); event.accepted = true; }
                        Keys.onEnterPressed: { root.send(); event.accepted = true; }
                        // Yukari/asagi: imlec ilk/son satirdaysa mesajlari kaydir
                        Keys.onUpPressed: {
                            if (cursorRectangle.y < 4) { root.scrollMessages(-1); event.accepted = true; }
                            else event.accepted = false;
                        }
                        Keys.onDownPressed: {
                            if (cursorRectangle.y + cursorRectangle.height >= paintedHeight - 4) { root.scrollMessages(1); event.accepted = true; }
                            else event.accepted = false;
                        }
                    }
                }
                Text {
                    anchors { left: parent.left; leftMargin: 22; verticalCenter: parent.verticalCenter }
                    text: qsTr("Mesaj")
                    color: app.placeholder
                    font.pixelSize: 22
                    visible: composer.text.length === 0
                }
                Text {
                    // uzun mesajda karakter sayaci
                    visible: composer.text.length > 300
                    anchors { right: parent.right; rightMargin: 16; top: parent.top; topMargin: 2 }
                    text: composer.text.length
                    color: app.textSecondary
                    font.pixelSize: 13
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !composer.activeFocus
                    onClicked: { composer.forceActiveFocus(); composer.openSoftwareInputPanel(); }
                }
            }
            Rectangle {
                id: actionBtn
                anchors { right: parent.right; rightMargin: 12; bottom: parent.bottom; bottomMargin: 9 }
                width: 58; height: 58; radius: 29
                color: actMa.pressed ? app.brandPressed : app.brand
                smooth: true
                property bool hasText: composer.text.replace(/\s+/g, "") !== ""
                Image {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: actionBtn.hasText ? 2 : 0
                    width: 32; height: 32; smooth: true
                    source: actionBtn.hasText ? "../images/send.png" : "../images/mic.png"
                }
                MouseArea {
                    id: actMa
                    anchors.fill: parent
                    onClicked: {
                        if (actionBtn.hasText) root.send();
                        else { sheet.visible = false; root.stopVoice(); device.startRecording(); }
                    }
                }
            }
        }

        // Kayit modu
        Rectangle {
            anchors.fill: parent
            visible: device.recording
            color: app.surface

            IconButton {
                id: cancelRec
                anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                source: "../images/close" + app.iconTone + ".png"
                onClicked: device.cancelRecording()
            }
            Rectangle {
                id: recDot
                anchors { left: cancelRec.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
                width: 18; height: 18; radius: 9
                color: "#F15C6D"
                SequentialAnimation on opacity {
                    running: device.recording
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 600 }
                    NumberAnimation { to: 1; duration: 600 }
                }
            }
            Text {
                id: recTime
                anchors { left: recDot.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
                text: "0:00"
                color: app.textPrimary
                font.pixelSize: 24
            }
            Text {
                anchors { left: recTime.right; leftMargin: 18; right: stopBtn.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                text: qsTr("Kaydediliyor... göndermek için düğmeye dokunun")
                color: app.textSecondary
                font.pixelSize: 17
                elide: Text.ElideRight
            }
            Rectangle {
                id: stopBtn
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                width: 58; height: 58; radius: 29
                color: stopMa.pressed ? app.brandPressed : app.brand
                Image { anchors.centerIn: parent; anchors.horizontalCenterOffset: 2; width: 32; height: 32; smooth: true; source: "../images/send.png" }
                MouseArea {
                    id: stopMa
                    anchors.fill: parent
                    onClicked: { root.pendingVoice = device.stopRecording(); voiceSendDelay.restart(); }
                }
            }
        }
    }

    // ---- Ek menusu (ataş) ----
    Item {
        id: sheet
        anchors.fill: parent
        visible: false
        z: 5
        MouseArea { anchors.fill: parent; onClicked: sheet.visible = false }
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 12; rightMargin: 12; bottomMargin: 84 }
            height: 150
            radius: 18
            color: app.surface
            border.width: app.dark ? 0 : 1
            border.color: app.divider
            MouseArea { anchors.fill: parent }
            Row {
                anchors.centerIn: parent
                spacing: 50
                Repeater {
                    model: ListModel {
                        ListElement { label: QT_TR_NOOP("Fotoğraf"); kind: "image"; icon: "gallery"; tint: "#BF59CF" }
                        ListElement { label: QT_TR_NOOP("Video"); kind: "video"; icon: "video"; tint: "#FF2E74" }
                        ListElement { label: QT_TR_NOOP("Ses dosyası"); kind: "audio"; icon: "music"; tint: "#FF7F21" }
                        ListElement { label: QT_TR_NOOP("Konum"); kind: "location"; icon: "location"; tint: "#1FA855" }
                    }
                    delegate: Column {
                        spacing: 8
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 72; height: 72; radius: 36
                            color: tint
                            opacity: optMa.pressed ? 0.7 : 1
                            Image { anchors.centerIn: parent; width: 38; height: 38; smooth: true; source: "../images/" + icon + ".png" }
                            MouseArea {
                                id: optMa
                                anchors.fill: parent
                                onClicked: { sheet.visible = false; if (kind === "location") konumEkrani.ac(); else picker.open(kind); }
                            }
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: qsTr(label); color: app.textPrimary; font.pixelSize: 18 }
                    }
                }
            }
        }
    }

    // ---- Emoji paneli ----
    Item {
        id: emojiSheet
        anchors.fill: parent
        visible: false
        z: 5
        MouseArea { anchors.fill: parent; onClicked: { emojiSheet.visible = false; root.focusComposer(); } }
        Rectangle {
            id: emojiBox
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 8; rightMargin: 8; bottomMargin: inputBar.height + 6 }
            height: 250
            radius: 18
            color: app.surface
            border.width: app.dark ? 0 : 1
            border.color: app.divider
            MouseArea { anchors.fill: parent }
            Flickable {
                anchors { fill: parent; margins: 10 }
                contentHeight: emojiGrid.height
                clip: true
                Grid {
                    id: emojiGrid
                    columns: 10
                    spacing: 2
                    Repeater {
                        model: Emoji.codes
                        delegate: Rectangle {
                            width: (emojiBox.width - 20 - 18) / 10
                            height: 56
                            radius: 10
                            color: ema.pressed ? app.pressed : "transparent"
                            Image { anchors.centerIn: parent; width: 34; height: 34; smooth: true; source: Emoji.imgPath(modelData) }
                            MouseArea { id: ema; anchors.fill: parent; onClicked: root.insertEmoji(modelData) }
                        }
                    }
                }
            }
        }
    }

    // Yazilan metinde emoji varsa nasil gorunecegini goster (yazma kutusunda kutu gorunur)
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: inputBar.top; leftMargin: 70; rightMargin: 80 }
        visible: !device.recording && Emoji.has(composer.text)
        height: visible ? Math.min(90, prev.paintedHeight + 14) : 0
        radius: 10
        color: app.surface
        clip: true
        Text {
            id: prev
            x: 12; y: 7
            width: parent.width - 24
            text: Emoji.rich(composer.text, 22)
            textFormat: Text.RichText
            wrapMode: Text.Wrap
            color: app.textPrimary
            font.pixelSize: 20
        }
    }

    MediaPicker {
        id: picker
        anchors.fill: parent
        z: 10
        onPicked: root.sendFile(path, kind === "image" ? qsTr("Fotoğraf") : (kind === "video" ? qsTr("Video") : qsTr("Ses")))
    }

    // ---- Ifade paneli: her duygudan birkac ifade ----
    Item {
        id: tepkiPanel
        anchors.fill: parent
        visible: false
        z: 8
        property int idx: -1
        MouseArea { anchors.fill: parent; onClicked: tepkiPanel.visible = false }
        Rectangle { anchors.fill: parent; color: "#66000000" }
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 40, 6 * 76 + 30)
            height: tCol.height + 28
            radius: 18
            color: app.surface
            MouseArea { anchors.fill: parent }
            Column {
                id: tCol
                x: 15; y: 14
                width: parent.width - 30
                spacing: 10
                Text { text: qsTr("İfade bırak"); font.pixelSize: 20; font.bold: true; color: app.textPrimary }
                Grid {
                    columns: 6
                    spacing: 4
                    Repeater {
                        model: root.tepkiler
                        Rectangle {
                            width: (tCol.width - 20) / 6; height: 62; radius: 12
                            property bool secili: tepkiPanel.idx >= 0 && tepkiPanel.idx < msgModel.count && msgModel.get(tepkiPanel.idx).tepki === modelData
                            color: tma.pressed ? app.pressed : (secili ? app.chip : "transparent")
                            Image { anchors.centerIn: parent; width: 40; height: 40; smooth: true; source: Emoji.imgPath(modelData) }
                            MouseArea { id: tma; anchors.fill: parent; onClicked: root.tepkiGonder(modelData) }
                        }
                    }
                }
                Row {
                    spacing: 12
                    Rectangle {
                        width: kt.paintedWidth + 32; height: 46; radius: 23; color: kma.pressed ? app.pressed : app.chip
                        Text { id: kt; anchors.centerIn: parent; text: qsTr("Kopyala"); font.pixelSize: 18; font.bold: true; color: app.accentText }
                        MouseArea { id: kma; anchors.fill: parent; onClicked: { tepkiPanel.visible = false; root.kopyala(tepkiPanel.idx); } }
                    }
                    Rectangle {
                        visible: tepkiPanel.idx >= 0 && tepkiPanel.idx < msgModel.count && msgModel.get(tepkiPanel.idx).tepki !== ""
                        width: ct.paintedWidth + 32; height: 46; radius: 23; color: cma.pressed ? app.pressed : app.chip
                        Text { id: ct; anchors.centerIn: parent; text: qsTr("İfadeyi kaldır"); font.pixelSize: 18; font.bold: true; color: app.accentText }
                        MouseArea { id: cma; anchors.fill: parent; onClicked: root.tepkiGonder("") }
                    }
                }
            }
        }
    }

    // ---- Konum gonderme / gosterme (ortak harita kutuphanesi) ----
    KonumSecici {
        id: konumEkrani
        anchors.fill: parent
        z: 12
        koyu: app.dark
        sunucu: app.server
        anahtar: app.apiKey
        onGonder: root.konumGonder(lat, lng, ad, adres)
        onKapandi: root.focusComposer()
    }
}
