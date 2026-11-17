import QtQuick 1.1
import "Util.js" as Util

// Giris ekrani (yatay ekran icin iki sutun)
Rectangle {
    id: root
    color: app.bg
    property alias mobile: mobileField.text
    property alias serverUrl: serverField.text
    property alias serverKey: keyField.text
    property bool busy: false
    property string error: ""
    property bool ekleMod: false       // Ayarlar > "2. hesabı ekle": sunucu alanlari gizli, etkin hesap degismez
    property string no: ""             // giris yapilan / eklenen numara

    function ekleBasla() {
        qrKapat();
        busy = false;
        error = "";
        mobileField.text = "";
        mobileField.focusInput();
    }

    // Alanlari denetler ve uygulamaya yazar; gecersizse false
    function alanlariAl() {
        var n = Util.cleanNumber(mobileField.text);
        var s = Util.trimServer(serverField.text);
        if (n.length < 8) {
            error = qsTr("Numaranızı ülke koduyla girin (örn. 905321234567).");
            return false;
        }
        if (ekleMod) {
            if (n === app.hesap1) { error = qsTr("Bu numara zaten 1. hesap olarak ekli."); return false; }
            error = "";
            no = n;
            return true;
        }
        no = n;
        if (s.length === 0) {
            error = qsTr("Sunucu adresini girin.");
            return false;
        }
        error = "";
        app.me = n;
        app.server = s;
        app.apiKey = keyField.text.replace(/^\s+|\s+$/g, "");
        return true;
    }

    function submit() {
        if (!alanlariAl()) return;
        busy = true;
        app.apiLogin(function (user) {
            busy = false;
            bitti(user);
        }, function (msg, status) {
            busy = false;
            if (status === 401) qrBaslat();      // sunucuda bu numara aktif degil: ayni numarayla giris istegi + QR
            else error = msg;
        }, no);
    }
    function bitti(user) {
        var ad = user && user.pushname ? user.pushname : "";
        if (ekleMod) app.ikinciEklendi(no, ad);
        else app.onLoggedIn(no, app.server, ad);
    }

    // ---- QR ile baglama: sunucuda numara icin oturum baslatilir, QR telefonda gosterilir ----
    property bool qrAcik: false
    property string qrDurum: ""
    property bool qrVar: false
    property int qrTur: 0
    property int girisDeneme: 0
    property bool aGorunur: true

    function qrBaslat() {
        if (!alanlariAl()) return;
        qrAcik = true; qrVar = false; qrTur = 0; girisDeneme = 0;
        qrPanel.forceActiveFocus();
        qrDurum = qsTr("Sunucuda ") + no + qsTr(" için oturum açılıyor…");
        app.apiPair(function (d) {
            if (!qrAcik) return;
            if (!d.valid) { qrDurum = qsTr("Numara geçersiz") + (d.reason ? ": " + d.reason : ""); return; }
            if (d.durum === "hazir") { qrDurum = qsTr("Bu numaranın oturumu zaten açık, giriş yapılıyor…"); girisDene(); return; }
            qrDurum = qsTr("QR kodu hazırlanıyor (10-30 sn)…");
            qrZaman.restart();
        }, function (msg) { if (qrAcik) qrDurum = msg; }, no);
    }
    function qrKapat() { qrAcik = false; qrZaman.stop(); girisZaman.stop(); }
    function qrYukle() {
        // gizli resme yukle, hazir olunca one al (titreme olmasin)
        if (aGorunur) qrB.source = app.qrUrl(new Date().getTime(), no);
        else qrA.source = app.qrUrl(new Date().getTime(), no);
    }
    function girisDene() {
        app.apiLogin(function (user) {
            if (!qrAcik) return;
            qrKapat();
            bitti(user);
        }, function (msg, status) {
            if (!qrAcik) return;
            girisDeneme++;
            if (girisDeneme < 15) { qrDurum = qsTr("Bağlandı, sohbetler hazırlanıyor…"); girisZaman.restart(); }
            else qrDurum = msg;
        }, no);
    }
    Timer {
        id: qrZaman; interval: 2500; repeat: true
        onTriggered: app.apiLoginStatus(function (s) {
            if (!root.qrAcik) return;
            if (s.isAuthenticated) { qrZaman.stop(); root.qrDurum = qsTr("Bağlandı, giriş yapılıyor…"); root.girisDene(); return; }
            if (s.hasQr) {
                // WhatsApp QR'i ~20 sn'de bir yeniler: ilk kez ve her 3 turda bir resmi tazele
                if (!root.qrVar || root.qrTur % 3 === 0) root.qrYukle();
                root.qrTur++;
            } else if (!root.qrVar) root.qrDurum = qsTr("QR kodu hazırlanıyor (10-30 sn)…");
        }, function (msg) { if (root.qrAcik) root.qrDurum = msg; }, root.no)
    }
    Timer { id: girisZaman; interval: 2000; onTriggered: root.girisDene() }

    Rectangle {
        id: leftPane
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: parent.width * 0.40
        color: app.dark ? "#103529" : "#1DAA61"

        Column {
            anchors.centerIn: parent
            spacing: 18
            width: parent.width - 40

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 110
                height: 110
                radius: 55
                color: app.dark ? "#21C063" : "#FFFFFF"
                smooth: true
                Rectangle {
                    anchors.centerIn: parent
                    width: 64
                    height: 50
                    radius: 22
                    color: app.dark ? "#103529" : "#1DAA61"
                    smooth: true
                    Rectangle { x: 16; y: 16; width: 32; height: 6; radius: 3; color: app.dark ? "#21C063" : "#FFFFFF" }
                    Rectangle { x: 16; y: 28; width: 20; height: 6; radius: 3; color: app.dark ? "#21C063" : "#FFFFFF" }
                }
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.ekleMod ? "W²" : qsTr("WhatsBelle")
                color: "#FFFFFF"
                font.pixelSize: root.ekleMod ? 56 : 34
                font.bold: true
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: root.ekleMod ? qsTr("İkinci WhatsApp hesabı") : qsTr("Nokia E6 için sohbet")
                color: "#C8F5D6"
                font.pixelSize: 20
            }
        }
    }

    Flickable {
        anchors { left: leftPane.right; right: parent.right; top: parent.top; bottom: parent.bottom }
        contentHeight: form.height + 48
        clip: true

        Column {
            id: form
            x: 32
            y: 24
            width: parent.width - 64
            spacing: 10

            Text {
                text: root.ekleMod ? qsTr("2. hesabı ekle") : qsTr("Hoş geldiniz")
                color: app.textPrimary
                font.pixelSize: 30
                font.bold: true
            }
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: root.ekleMod ? qsTr("Eklenecek numarayı ülke koduyla, başında + veya 00 olmadan girin. Sunucu ve parola 1. hesapla aynıdır.")
                                   : qsTr("Telefon numaranızı ülke koduyla, başında + veya 00 olmadan girin.")
                color: app.textSecondary
                font.pixelSize: 19
            }
            TextField {
                id: mobileField
                width: parent.width
                placeholder: "905321234567"
                inputMethodHints: Qt.ImhDigitsOnly
                onAccepted: root.ekleMod ? root.submit() : serverField.focusInput()
            }
            Text { visible: !root.ekleMod; text: qsTr("Sunucu"); color: app.textSecondary; font.pixelSize: 18 }
            TextField {
                id: serverField
                visible: !root.ekleMod
                width: parent.width
                placeholder: "https://e6.msahincelen.xyz"
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText
                text: "https://e6.msahincelen.xyz"
                onAccepted: keyField.focusInput()
            }
            Text { visible: !root.ekleMod; text: qsTr("Sunucu parolası"); color: app.textSecondary; font.pixelSize: 18 }
            TextField {
                id: keyField
                visible: !root.ekleMod
                width: parent.width
                placeholder: qsTr("Parola")
                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                onAccepted: root.submit()
            }
            Text {
                width: parent.width
                visible: root.error !== ""
                wrapMode: Text.Wrap
                text: root.error
                color: app.danger
                font.pixelSize: 18
            }
            Rectangle {
                width: parent.width
                height: 60
                radius: 30
                color: btn.pressed ? app.brandPressed : app.brand
                opacity: root.busy ? 0.6 : 1
                Text {
                    anchors.centerIn: parent
                    text: root.busy ? qsTr("Bağlanıyor...") : qsTr("Devam")
                    color: app.dark ? "#0B141A" : "#FFFFFF"
                    font.pixelSize: 24
                    font.bold: true
                }
                MouseArea {
                    id: btn
                    anchors.fill: parent
                    enabled: !root.busy
                    onClicked: root.submit()
                }
            }
            Rectangle {
                width: parent.width
                height: 54
                radius: 27
                color: qrBtn.pressed ? (app.dark ? "#1F2C34" : "#E7F8EE") : "transparent"
                border.color: app.brand; border.width: 2
                Text {
                    anchors.centerIn: parent
                    text: root.ekleMod ? qsTr("QR ile bağla") : qsTr("QR ile bağla (yeni hesap)")
                    color: app.brand
                    font.pixelSize: 21
                    font.bold: true
                }
                MouseArea { id: qrBtn; anchors.fill: parent; enabled: !root.busy; onClicked: root.qrBaslat() }
            }
            Rectangle {
                visible: root.ekleMod
                width: parent.width
                height: 54
                radius: 27
                color: vzBtn.pressed ? (app.dark ? "#1F2C34" : "#E9EDEF") : "transparent"
                border.color: app.textSecondary; border.width: 1
                Text { anchors.centerIn: parent; text: qsTr("Vazgeç"); color: app.textPrimary; font.pixelSize: 21 }
                MouseArea { id: vzBtn; anchors.fill: parent; onClicked: app.ikinciVazgec() }
            }
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: qsTr("Numara sunucuda bağlı değilse QR kodu burada gösterilir; WhatsApp yüklü telefonunuzdan okutun.")
                color: app.textSecondary
                font.pixelSize: 16
            }
        }
    }

    // ---- QR paneli ----
    Rectangle {
        id: qrPanel
        anchors.fill: parent
        visible: root.qrAcik
        color: app.bg
        z: 10
        MouseArea { anchors.fill: parent }
        focus: visible
        Keys.onPressed: {
            if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Escape || event.key === Qt.Key_Context2) { root.qrKapat(); event.accepted = true; }
        }
        Rectangle {
            id: qrKutu
            x: 20
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(parent.height - 40, parent.width * 0.55)
            height: width
            color: "#FFFFFF"
            radius: 8
            Image { id: qrA; anchors.fill: parent; anchors.margins: 6; smooth: false; fillMode: Image.PreserveAspectFit; cache: false; visible: root.aGorunur && root.qrVar
                    onStatusChanged: if (status === Image.Ready && !root.aGorunur) { root.aGorunur = true; root.qrVar = true; root.qrDurum = qsTr("WhatsApp yüklü telefonunuzda: Ayarlar › Bağlı cihazlar › Cihaz bağla, sonra bu kodu okutun.") } }
            Image { id: qrB; anchors.fill: parent; anchors.margins: 6; smooth: false; fillMode: Image.PreserveAspectFit; cache: false; visible: !root.aGorunur && root.qrVar
                    onStatusChanged: if (status === Image.Ready && root.aGorunur) { root.aGorunur = false; root.qrVar = true; root.qrDurum = qsTr("WhatsApp yüklü telefonunuzda: Ayarlar › Bağlı cihazlar › Cihaz bağla, sonra bu kodu okutun.") } }
            Text { anchors.centerIn: parent; visible: !root.qrVar; width: parent.width - 40; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                   text: qsTr("QR bekleniyor…"); color: "#667781"; font.pixelSize: 20 }
        }
        Column {
            anchors { left: qrKutu.right; leftMargin: 20; right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
            spacing: 14
            Text { width: parent.width; text: qsTr("QR ile bağla"); color: app.textPrimary; font.pixelSize: 28; font.bold: true }
            Text { width: parent.width; text: "+" + root.no; color: app.textSecondary; font.pixelSize: 19 }
            Text { width: parent.width; wrapMode: Text.Wrap; text: root.qrDurum; color: app.textPrimary; font.pixelSize: 18 }
            Row {
                spacing: 10
                Rectangle {
                    width: 120; height: 52; radius: 26
                    color: yb.pressed ? app.brandPressed : app.brand
                    Text { anchors.centerIn: parent; text: qsTr("Yenile"); color: app.dark ? "#0B141A" : "#FFFFFF"; font.pixelSize: 20; font.bold: true }
                    MouseArea { id: yb; anchors.fill: parent; onClicked: root.qrBaslat() }
                }
                Rectangle {
                    width: 120; height: 52; radius: 26
                    color: kb.pressed ? (app.dark ? "#1F2C34" : "#E9EDEF") : "transparent"
                    border.color: app.textSecondary; border.width: 1
                    Text { anchors.centerIn: parent; text: qsTr("Kapat"); color: app.textPrimary; font.pixelSize: 20 }
                    MouseArea { id: kb; anchors.fill: parent; onClicked: root.qrKapat() }
                }
            }
        }
    }
}
