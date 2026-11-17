import QtQuick 1.1

Rectangle {
    id: root
    color: app.bg

    property string mode: "direct"
    property string pickProvider: ""        // model listesi acik olan saglayici
    property variant pickList: []
    property bool pickBusy: false
    property bool pickImg: false            // true: resim modeli seciliyor
    function secili() { return pickImg ? app.setting("img_" + pickProvider, app.ai().IMG_DEFAULTS[pickProvider] || "") : app.modelFor(pickProvider); }
    property string serverStatus: ""

    property bool loaded: false
    property bool gunlukAcik: false
    Connections { target: yardim; onRaporBitti: app.showToast(mesaj) }

    function load() {
        app.initDb();   // bu sayfa ana pencereden once hazir olabilir; tablo yoksa okuma hata verir
        mode = app.setting("mode", "direct");
        serverField.text = app.setting("server", "") || "https://e6.msahincelen.xyz";
        serverKeyField.text = app.setting("serverKey", "");
        systemEdit.text = app.setting("system", app.defaultSystem);
        loaded = true;      // kartlardan biri hata verse de kayit calissin
        for (var i = 0; i < provRepeater.count; i++) {
            try { provRepeater.itemAt(i).load(); } catch (e) { yardim.log("kart yuklenemedi " + i + ": " + e); }
        }
        yardim.log("ayarlar yuklendi, sistem istemi " + systemEdit.text.length + " karakter");
    }

    // Sistem istemi yazildikca kaydedilir (sekme degistirmeden uygulamadan cikilsa da kaybolmaz)
    // HATA (cozuldu): sayfa olusurken gorunurluk true -> false degisince save() alanlar daha YUKLENMEDEN calisip
    // bos sistem istemini (ve bos sunucu alanlarini) kaydediyordu. Artik hicbir kayit loaded olmadan yapilmaz.
    function sistemKaydet(neden) {
        if (!loaded) return;
        app.setSetting("system", systemEdit.text);
        app.applyConfig();
        yardim.log("sistem istemi kaydedildi (" + neden + ") " + systemEdit.text.length + " karakter");
    }
    Timer { id: systemSave; interval: 600; onTriggered: root.sistemKaydet("yazarken") }
    // Uygulama arka plana gecince / kapatilirken (kirmizi tus) son hali kaydet
    Connections { target: Qt.application; onActiveChanged: if (!Qt.application.active && root.loaded) root.save(true) }

    // Yon tuslari: sol/sag sekme degistirir, yukari/asagi sayfayi kaydirir
    function scrollBy(dir) {
        var maxY = Math.max(0, flick.contentHeight - flick.height);
        flick.contentY = Math.max(0, Math.min(maxY, flick.contentY + dir * Math.round(flick.height * 0.6)));
    }
    Keys.onUpPressed: { scrollBy(-1); event.accepted = true; }
    Keys.onDownPressed: { scrollBy(1); event.accepted = true; }
    Keys.onLeftPressed: { app.stepTab(-1); event.accepted = true; }
    Keys.onRightPressed: { app.stepTab(1); event.accepted = true; }

    // E6'da tahminli yazmada son sozcuk kutuya islenmemis bekler: kaydetmeden once odagi alip islet
    function yaziyiIsle() { systemEdit.focus = false; root.forceActiveFocus(); }

    function save(silent) {
        if (!loaded) return;
        yaziyiIsle();
        app.setSetting("mode", mode);
        app.setSetting("server", serverField.text.replace(/^\s+|\s+$/g, "").replace(/\/+$/, ""));
        app.setSetting("serverKey", serverKeyField.text.replace(/^\s+|\s+$/g, ""));
        sistemKaydet("ayarlar");
        for (var i = 0; i < provRepeater.count; i++) provRepeater.itemAt(i).save();
        app.applyConfig();
        if (!silent) app.showToast(qsTr("Kaydedildi"));
    }

    Component.onCompleted: load()
    onVisibleChanged: if (!visible && loaded) save(true)

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: qsTr("Ayarlar")
        subtitle: qsTr("API anahtarları, modeller, bağlantı")
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 110; height: 46; radius: 23
            color: hsMa.pressed ? app.brandPressed : app.brand
            Text { anchors.centerIn: parent; text: qsTr("Kaydet"); color: "#FFFFFF"; font.pixelSize: 19; font.bold: true }
            MouseArea { id: hsMa; anchors.fill: parent; onClicked: root.save(false) }
        }
        Item { width: 10; height: 10 }
    }

    Flickable {
        id: flick
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        contentHeight: col.height + 30
        clip: true

        Column {
            id: col
            x: 18
            width: parent.width - 36
            spacing: 12
            Item { width: 1; height: 4 }

            // ================= Saglayicilar =================
            Repeater {
                id: provRepeater
                model: [["openai", qsTr("GPT (OpenAI)"), "nav_gpt_on", qsTr("platform.openai.com → API keys")],
                        ["claude", qsTr("Claude (Anthropic)"), "nav_claude_on", qsTr("console.anthropic.com → API Keys")],
                        ["gemini", qsTr("Gemini (Google)"), "nav_gemini_on", qsTr("aistudio.google.com → Get API key")],
                        ["grok", qsTr("Grok (xAI)"), "nav_grok_on", qsTr("console.x.ai → API Keys")]]
                delegate: Rectangle {
                    id: card
                    property string p: modelData[0]
                    property string testResult: ""
                    property bool testOk: false
                    property bool testing: false
                    property bool cizer: app.ai().canDraw(p)
                    function load() { keyField.text = app.setting("key_" + p, ""); modelField.text = app.modelFor(p); if (cizer) imgField.text = app.setting("img_" + p, app.ai().IMG_DEFAULTS[p]); }
                    function save() {
                        app.setSetting("key_" + p, keyField.text.replace(/\s+/g, ""));
                        var m = modelField.text.replace(/^\s+|\s+$/g, "");
                        if (m !== "") app.setModel(p, m);
                        if (cizer) { var im = imgField.text.replace(/^\s+|\s+$/g, ""); app.setSetting("img_" + p, im !== "" ? im : app.ai().IMG_DEFAULTS[p]); }
                    }
                    function test() {
                        root.save(true);
                        testing = true;
                        testResult = qsTr("Deneniyor...");
                        app.ai().chat(p, app.modelFor(p), [{ role: "user", text: qsTr("Bağlantı testi: yalnızca 'tamam' yaz.") }], function (r) {
                            testing = false;
                            testOk = !r.refusal;
                            testResult = (r.refusal ? qsTr("Yanıt reddedildi: ") + r.refusal : qsTr("Çalışıyor  •  ") + ((r.ms || 0) / 1000).toFixed(1) + qsTr(" sn  •  ") + r.model + qsTr("\nYanıt: ") + r.text.substring(0, 80));
                        }, function (m) { testing = false; testOk = false; testResult = qsTr("Hata: ") + m; });
                    }
                    width: col.width
                    height: cardCol.height + 28
                    radius: 14
                    color: app.surface
                    border.width: 1; border.color: app.divider
                    Column {
                        id: cardCol
                        x: 16; y: 14
                        width: parent.width - 32
                        spacing: 10
                        Row {
                            spacing: 12
                            Image { width: 36; height: 36; smooth: true; source: "../images/" + modelData[2] + ".png" }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: modelData[1]; color: app.textPrimary; font.pixelSize: 21; font.bold: true }
                                Text { text: qsTr("Anahtar: ") + modelData[3]; color: app.textSecondary; font.pixelSize: 14 }
                            }
                        }
                        Row {
                        width: parent.width
                        spacing: 8
                        TextField {
                            id: keyField
                            width: parent.width - kpBtn.width - 8
                            placeholder: qsTr("API anahtarı")
                            echoMode: TextInput.Password
                            fontSize: 19
                            inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                        }
                        Rectangle {
                            id: kpBtn
                            width: 130; height: 56; radius: 28
                            color: kpMa.pressed ? app.pressed : app.fieldBg
                            Text { anchors.centerIn: parent; text: qsTr("Yapıştır"); color: app.textPrimary; font.pixelSize: 18 }
                            MouseArea {
                                id: kpMa
                                anchors.fill: parent
                                onClicked: { keyField.text = ""; keyField.input.forceActiveFocus(); keyField.input.paste(); keyField.text = keyField.text.replace(/\s+/g, ""); }
                            }
                        }
                        }                        Row {
                            width: parent.width
                            spacing: 8
                            TextField {
                                id: modelField
                                width: parent.width - listBtn.width - 8
                                placeholder: qsTr("Model")
                                fontSize: 19
                                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                            }
                            Rectangle {
                                id: listBtn
                                width: 130; height: 56; radius: 28
                                color: lMa.pressed ? app.pressed : app.fieldBg
                                Text { anchors.centerIn: parent; text: qsTr("Modeller"); color: app.textPrimary; font.pixelSize: 18 }
                                MouseArea {
                                    id: lMa
                                    anchors.fill: parent
                                    onClicked: {
                                        root.save(true);
                                        root.pickImg = false;
                                        root.pickProvider = card.p;
                                        root.pickBusy = true;
                                        root.pickList = [];
                                        app.ai().models(card.p, function (list) { root.pickBusy = false; root.pickList = list; },
                                                        function (m) { root.pickBusy = false; root.pickProvider = ""; app.showToast(m); });
                                    }
                                }
                            }
                        }
                        Text { visible: card.cizer; text: qsTr("Resim çizme modeli"); color: app.textSecondary; font.pixelSize: 16 }
                        Row {
                            visible: card.cizer
                            width: parent.width
                            spacing: 8
                            TextField {
                                id: imgField
                                width: parent.width - imgBtn.width - 8
                                placeholder: qsTr("Resim çizme modeli")
                                fontSize: 18
                                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                            }
                            Rectangle {
                                id: imgBtn
                                width: 130; height: 56; radius: 28
                                color: iMa.pressed ? app.pressed : app.fieldBg
                                Text { anchors.centerIn: parent; text: qsTr("Seç"); color: app.textPrimary; font.pixelSize: 18 }
                                MouseArea {
                                    id: iMa
                                    anchors.fill: parent
                                    onClicked: {
                                        root.save(true);
                                        root.pickImg = true;
                                        root.pickProvider = card.p;
                                        root.pickBusy = true;
                                        root.pickList = [];
                                        app.ai().imageModels(card.p, function (list) { root.pickBusy = false; root.pickList = list; },
                                                             function (m) { root.pickBusy = false; root.pickProvider = ""; app.showToast(m); });
                                    }
                                }
                            }
                        }
                        Row {
                            spacing: 10
                            Rectangle {
                                width: tText.paintedWidth + 36; height: 46; radius: 23
                                color: tMa.pressed ? app.brandPressed : app.brand
                                opacity: card.testing ? 0.6 : 1
                                Text { id: tText; anchors.centerIn: parent; text: qsTr("Bağlantıyı test et"); color: "#FFFFFF"; font.pixelSize: 18; font.bold: true }
                                MouseArea { id: tMa; anchors.fill: parent; enabled: !card.testing; onClicked: card.test() }
                            }
                        }
                        Text {
                            width: parent.width
                            visible: card.testResult !== ""
                            wrapMode: Text.Wrap
                            text: card.testResult
                            color: card.testing ? app.textSecondary : (card.testOk ? (app.dark ? "#4CD964" : "#1E8E3E") : app.danger)
                            font.pixelSize: 16
                        }
                    }
                }
            }

            // ================= Baglanti =================
            Rectangle { width: parent.width; height: 1; color: app.divider }
            Text { text: qsTr("Bağlantı"); color: app.accentText; font.pixelSize: 19; font.bold: true }
            Row {
                spacing: 10
                Repeater {
                    model: [["direct", qsTr("Doğrudan (HTTPS)")], ["relay", qsTr("Sunucu üzerinden")]]
                    delegate: Rectangle {
                        property bool sel: root.mode === modelData[0]
                        width: 250; height: 50; radius: 25
                        color: sel ? app.pill : app.bg
                        border.width: sel ? 0 : 1
                        border.color: app.dark ? "#3B4A54" : "#D1D7DB"
                        Text { anchors.centerIn: parent; text: modelData[1]; color: sel ? app.accentText : app.textPrimary; font.pixelSize: 18; font.bold: sel }
                        MouseArea { anchors.fill: parent; onClicked: { root.mode = modelData[0]; root.save(true); } }
                    }
                }
            }
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                color: app.textSecondary
                font.pixelSize: 15
                text: root.mode === "direct"
                    ? qsTr("Telefon sağlayıcıya şifreli (HTTPS) bağlanır; anahtarlar yalnızca telefonda durur. Telefonda Qt TLS 1.2 yaması gerekir. TLS hatası olursa istek sunucu üzerinden tekrarlanır (sunucu parolası gerekir).")
                    : qsTr("İstekler kendi sunucunuz üzerinden gider. Anahtarlar bir kez sunucuya gönderilir ve orada saklanır. Sunucu bağlantısı şifresiz (HTTP) olduğu için bu gönderimi güvendiğiniz bir ağda yapın.")
            }
            Column {
                width: parent.width
                spacing: 10
                Text { text: qsTr("Sunucu adresi") + (root.mode === "relay" ? "" : qsTr(" (sorun bildirmek için)")); color: app.textPrimary; font.pixelSize: 17 }
                TextField { id: serverField; width: parent.width; fontSize: 19; inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText }
                Text { text: qsTr("Sunucu parolası (WhatsBelle ile aynı)"); color: app.textPrimary; font.pixelSize: 17 }
                TextField { id: serverKeyField; width: parent.width; fontSize: 19; echoMode: TextInput.Password; inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase }
                Rectangle {
                    visible: root.mode === "relay"
                    width: skText.paintedWidth + 36; height: 46; radius: 23
                    color: skMa.pressed ? app.pressed : app.fieldBg
                    Text { id: skText; anchors.centerIn: parent; text: qsTr("Anahtarları sunucuya kaydet"); color: app.textPrimary; font.pixelSize: 18 }
                    MouseArea {
                        id: skMa
                        anchors.fill: parent
                        onClicked: {
                            root.save(true);
                            root.serverStatus = qsTr("Gönderiliyor...");
                            app.ai().saveKeysToServer(function (s) {
                                root.serverStatus = qsTr("Sunucudaki anahtarlar: GPT ") + (s.openai ? "var" : "yok") + qsTr(", Claude ") + (s.claude ? "var" : "yok") + qsTr(", Gemini ") + (s.gemini ? "var" : "yok") + qsTr(", Grok ") + (s.grok ? "var" : "yok");
                            }, function (m) { root.serverStatus = qsTr("Hata: ") + m; });
                        }
                    }
                }
                Text { width: parent.width; visible: root.serverStatus !== ""; wrapMode: Text.Wrap; text: root.serverStatus; color: app.textSecondary; font.pixelSize: 15 }
            }

            // ================= Sistem istemi =================
            Rectangle { width: parent.width; height: 1; color: app.divider }
            Item {
                width: parent.width
                height: 40
                Text { anchors { left: parent.left; verticalCenter: parent.verticalCenter } text: qsTr("Sistem istemi (üç modele de gider)"); color: app.accentText; font.pixelSize: 19; font.bold: true }
                Rectangle {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: defText.paintedWidth + 28; height: 38; radius: 19
                    color: defMa.pressed ? app.pressed : app.fieldBg
                    Text { id: defText; anchors.centerIn: parent; text: qsTr("Varsayılan"); color: app.textPrimary; font.pixelSize: 16 }
                    MouseArea { id: defMa; anchors.fill: parent; onClicked: { systemEdit.text = app.defaultSystem; app.showToast(qsTr("Varsayılan istem yüklendi")); } }
                }
            }
            Rectangle {
                width: parent.width
                height: Math.max(90, systemEdit.paintedHeight + 28)
                radius: 14
                color: app.fieldBg
                border.width: systemEdit.activeFocus ? 2 : 0
                border.color: app.brand
                TextEdit {
                    id: systemEdit
                    anchors { fill: parent; margins: 14 }
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    font.pixelSize: 18
                    color: app.textPrimary
                    // tahminli yazma kapali: her harf hemen islenir, otomatik kayit da her harfi gorur
                    inputMethodHints: Qt.ImhNoPredictiveText
                    onTextChanged: if (root.loaded) systemSave.restart()
                    onActiveFocusChanged: if (!activeFocus) root.sistemKaydet("odak")
                    Keys.onLeftPressed: event.accepted = systemEdit.text.length > 0 && systemEdit.cursorPosition === 0
                    Keys.onRightPressed: event.accepted = systemEdit.text.length > 0 && systemEdit.cursorPosition >= systemEdit.text.length
                }
                Text {
                    anchors { left: parent.left; top: parent.top; margins: 14 }
                    visible: systemEdit.text.length === 0 && !systemEdit.activeFocus
                    text: qsTr("Boş: sistem istemi gönderilmez")
                    color: app.placeholder
                    font.pixelSize: 18
                }
                MouseArea { anchors.fill: parent; enabled: !systemEdit.activeFocus; onClicked: { systemEdit.forceActiveFocus(); systemEdit.openSoftwareInputPanel(); } }
            }

            // ================= Sorun bildir =================
            Rectangle { width: parent.width; height: 1; color: app.divider }
            Text { text: qsTr("Sorun bildir"); color: app.accentText; font.pixelSize: 19; font.bold: true }
            Text {
                width: parent.width; wrapMode: Text.Wrap; color: app.textSecondary; font.pixelSize: 15
                text: qsTr("Uygulamanın günlüğü (C:/Data/ApiLauncher/gunluk.txt) sunucuya gönderilir; anahtarlar ve sohbetler gönderilmez. Yukarıdaki sunucu adresi ve parolası kullanılır.")
            }
            Row {
                spacing: 10
                Rectangle {
                    width: rpText.paintedWidth + 36; height: 46; radius: 23
                    color: rpMa.pressed ? app.brandPressed : app.brand
                    Text { id: rpText; anchors.centerIn: parent; text: qsTr("Rapor gönder"); color: "#FFFFFF"; font.pixelSize: 18; font.bold: true }
                    MouseArea {
                        id: rpMa; anchors.fill: parent
                        onClicked: { root.save(true); app.showToast(qsTr("Rapor gönderiliyor...")); yardim.raporGonder(app.setting("server", "https://e6.msahincelen.xyz"), app.setting("serverKey", ""), ""); }
                    }
                }
                Rectangle {
                    width: glText.paintedWidth + 36; height: 46; radius: 23
                    color: glMa.pressed ? app.pressed : app.fieldBg
                    Text { id: glText; anchors.centerIn: parent; text: root.gunlukAcik ? qsTr("Günlüğü gizle") : qsTr("Günlüğü göster"); color: app.textPrimary; font.pixelSize: 18 }
                    MouseArea { id: glMa; anchors.fill: parent; onClicked: { root.gunlukAcik = !root.gunlukAcik; gunlukText.text = yardim.gunluk(); } }
                }
            }
            Text { id: gunlukText; visible: root.gunlukAcik; width: parent.width; wrapMode: Text.WrapAnywhere; color: app.textSecondary; font.pixelSize: 13 }
            // ================= Gorunum =================
            Rectangle { width: parent.width; height: 1; color: app.divider }
            Item {
                width: parent.width
                height: 60
                Text { anchors { left: parent.left; verticalCenter: parent.verticalCenter } text: qsTr("Karanlık tema"); color: app.textPrimary; font.pixelSize: 21 }
                Rectangle {
                    id: sw
                    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                    width: 64; height: 34; radius: 17
                    color: app.dark ? app.brand : "#C4CBD0"
                    Rectangle {
                        width: 28; height: 28; radius: 14; y: 3
                        x: app.dark ? sw.width - width - 3 : 3
                        color: "#FFFFFF"
                        Behavior on x { NumberAnimation { duration: 150 } }
                    }
                }
                MouseArea { anchors.fill: parent; onClicked: { app.dark = !app.dark; app.setSetting("dark", app.dark ? "1" : "0"); } }
            }            Rectangle { width: parent.width; height: 1; color: app.divider }
            DilSatiri { width: parent.width; yazi: app.textPrimary; ikinci: app.textSecondary; vurgu: app.brand }

            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: qsTr("ApiLauncher 1.3 (eski adı E6AI) - sohbet geçmişi ve resimler yalnızca telefonda saklanır (oluşturulan resimler: E:/Images/ApiLauncher). Doğrudan bağlantı kurulamazsa (TLS hatası) istekler sunucu parolası girilmişse kendiliğinden sunucu üzerinden gider; fotoğraf, resim çizme ve Grok iki modda da çalışır. Claude'da güvenlik reddi olursa istek uygun bir Claude modelinde otomatik yeniden denenir.")
                color: app.textSecondary
                font.pixelSize: 15
            }
        }
    }

    // ---- Model secim listesi ----
    Rectangle {
        anchors.fill: parent
        visible: root.pickProvider !== ""
        color: "#99000000"
        z: 10
        MouseArea { anchors.fill: parent; onClicked: root.pickProvider = "" }
        Rectangle {
            anchors { fill: parent; margins: 30 }
            radius: 16
            color: app.surface
            MouseArea { anchors.fill: parent }
            Text {
                id: pickTitle
                anchors { left: parent.left; top: parent.top; margins: 16 }
                text: root.pickBusy ? qsTr("Modeller getiriliyor...") : (root.pickImg ? qsTr("Resim modeli") : qsTr("Sohbet modeli")) + " - " + root.pickList.length + qsTr(" model, seçmek için dokunun")
                color: app.textPrimary
                font.pixelSize: 19
                font.bold: true
            }
            ListView {
                anchors { left: parent.left; right: parent.right; top: pickTitle.bottom; bottom: parent.bottom; margins: 10 }
                clip: true
                model: root.pickList
                delegate: Rectangle {
                    width: parent ? parent.width : 400
                    height: 48
                    color: pkMa.pressed ? app.pressed : "transparent"
                    Text {
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        text: modelData
                        color: modelData === root.secili() ? app.accentText : app.textPrimary
                        font.pixelSize: 18
                        font.bold: modelData === root.secili()
                    }
                    MouseArea {
                        id: pkMa
                        anchors.fill: parent
                        onClicked: {
                            if (root.pickImg) app.setSetting("img_" + root.pickProvider, modelData);
                            else app.setModel(root.pickProvider, modelData);
                            app.applyConfig();
                            root.load();
                            root.pickProvider = "";
                            app.showToast((root.pickImg ? qsTr("Resim modeli: ") : qsTr("Model: ")) + modelData);
                        }
                    }
                }
            }
        }
    }
}
