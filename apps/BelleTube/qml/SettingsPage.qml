import QtQuick 1.1

Rectangle {
    id: root
    color: app.bg

    property bool showLog: false
    property string logText: ""

    // Sunucu ayarini kaydet ve parolayi hemen dogrula
    property string keyState: ""
    property bool keyOk: false
    function saveServer() {
        var s = serverField.text.replace(/^\s+|\s+$/g, "").replace(/\/+$/, "");
        if (s.indexOf("://") < 0) s = "http://" + s;
        app.server = s;
        app.apiKey = keyField.text.replace(/^\s+|\s+$/g, "");
        app.setSetting("server", s);
        app.setSetting("key", app.apiKey);
        app.configureApi();
        keyOk = false;
        keyState = qsTr("Sunucu kontrol ediliyor...");
        app.api().authStatus(function (d) {
            keyOk = true;
            keyState = qsTr("Bağlantı tamam.");
            app.showToast(qsTr("Kaydedildi"));
            app.selectTab(0);
        }, function (msg) { keyOk = false; keyState = msg; });
    }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: qsTr("Ayarlar")
    }

    Flickable {
        id: flick
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        contentHeight: col.height + 30
        clip: true

        Column {
            id: col
            x: 20
            width: parent.width - 40
            spacing: 10

            Item { width: 1; height: 6 }

            // ================= Sunucu (ilk acilista gereken tek ayar) =================
            Text { text: qsTr("Sunucu adresi"); color: app.accentText; font.pixelSize: 19; font.bold: true }
            TextField {
                id: serverField
                width: parent.width
                text: app.server
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText
            }
            Text { text: qsTr("Sunucu parolası (WhatsBelle ile aynı)"); color: app.accentText; font.pixelSize: 19; font.bold: true }
            Row {
                width: parent.width
                spacing: 10
                TextField {
                    id: keyField
                    width: parent.width - saveBtn.width - pasteBtn.width - 20
                    text: app.apiKey
                    placeholder: qsTr("Parola")
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    onAccepted: root.saveServer()
                }
                Rectangle {
                    id: pasteBtn
                    width: 120; height: 56; radius: 28
                    color: pasteMa.pressed ? app.pressed : app.fieldBg
                    Text { anchors.centerIn: parent; text: qsTr("Yapıştır"); color: app.textPrimary; font.pixelSize: 19 }
                    MouseArea {
                        id: pasteMa
                        anchors.fill: parent
                        onClicked: {
                            keyField.text = "";
                            keyField.input.forceActiveFocus();
                            keyField.input.paste();
                            keyField.text = keyField.text.replace(/\s+/g, "");
                            if (keyField.text === "") app.showToast(qsTr("Panoda metin yok"));
                        }
                    }
                }
                Rectangle {
                    id: saveBtn
                    width: 120; height: 56; radius: 28
                    color: saveMa.pressed ? app.brandPressed : app.brand
                    Text { anchors.centerIn: parent; text: qsTr("Kaydet"); color: "#FFFFFF"; font.pixelSize: 21; font.bold: true }
                    MouseArea { id: saveMa; anchors.fill: parent; onClicked: root.saveServer() }
                }
            }
            Text {
                width: parent.width
                visible: root.keyState !== ""
                wrapMode: Text.Wrap
                text: root.keyState
                color: root.keyOk ? app.textSecondary : app.danger
                font.pixelSize: 16
            }

            // ================= Oynatma =================
            Rectangle { width: parent.width; height: 1; color: app.divider }
            Text { text: qsTr("Video kalitesi"); color: app.accentText; font.pixelSize: 19; font.bold: true }
            Row {
                spacing: 10
                Repeater {
                    model: [["360", qsTr("360p (önerilen)")], ["480", "480p"]]
                    delegate: Rectangle {
                        property bool sel: app.quality === modelData[0]
                        width: 200; height: 50; radius: 25
                        color: sel ? app.pill : app.bg
                        border.width: sel ? 0 : 1
                        border.color: app.dark ? "#3B4A54" : "#D1D7DB"
                        Text { anchors.centerIn: parent; text: modelData[1]; color: sel ? app.accentText : app.textPrimary; font.pixelSize: 19; font.bold: sel }
                        MouseArea { anchors.fill: parent; onClicked: { app.quality = modelData[0]; app.setSetting("quality", modelData[0]); } }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: app.divider }
            Text { text: qsTr("İndirilenler için ayrılan yer"); color: app.accentText; font.pixelSize: 19; font.bold: true }
            Row {
                spacing: 10
                Repeater {
                    model: [1, 2, 4, 8]
                    delegate: Rectangle {
                        property bool sel: app.limitGB === modelData
                        width: 100; height: 50; radius: 25
                        color: sel ? app.pill : app.bg
                        border.width: sel ? 0 : 1
                        border.color: app.dark ? "#3B4A54" : "#D1D7DB"
                        Text { anchors.centerIn: parent; text: modelData + qsTr(" GB"); color: sel ? app.accentText : app.textPrimary; font.pixelSize: 19; font.bold: sel }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { app.limitGB = modelData; app.setSetting("limitGB", modelData); tube.enforceLimit(app.limitBytes(), ""); }
                        }
                    }
                }
            }
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: qsTr("Sınır aşılınca en eski videolar otomatik silinir. Klasör: ") + tube.cacheDir()
                color: app.textSecondary
                font.pixelSize: 16
            }

            Rectangle { width: parent.width; height: 1; color: app.divider }
            Item {
                width: parent.width
                height: 64
                Text { anchors { left: parent.left; verticalCenter: parent.verticalCenter } text: qsTr("Karanlık tema"); color: app.textPrimary; font.pixelSize: 22 }
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
            }

            Rectangle { width: parent.width; height: 1; color: app.divider }
            DilSatiri { width: parent.width; yazi: app.textPrimary; ikinci: app.textSecondary; vurgu: app.brand }
            // ================= Gunluk =================
            Rectangle { width: parent.width; height: 1; color: app.divider }
            Item {
                width: parent.width
                height: 56
                Text { anchors { left: parent.left; verticalCenter: parent.verticalCenter } text: qsTr("Günlük (son 20)"); color: app.textPrimary; font.pixelSize: 21 }
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 8
                    Rectangle {
                        width: 110; height: 44; radius: 22; color: lgMa.pressed ? app.pressed : app.fieldBg
                        Text { anchors.centerIn: parent; text: root.showLog ? qsTr("Gizle") : qsTr("Göster"); color: app.textPrimary; font.pixelSize: 17 }
                        MouseArea { id: lgMa; anchors.fill: parent; onClicked: { root.showLog = !root.showLog; if (root.showLog) root.logText = tube.logText(); } }
                    }
                    Rectangle {
                        width: 110; height: 44; radius: 22; color: lpMa.pressed ? app.brandPressed : app.brand
                        Text { anchors.centerIn: parent; text: qsTr("Kopyala"); color: "#FFFFFF"; font.pixelSize: 17; font.bold: true }
                        MouseArea { id: lpMa; anchors.fill: parent; onClicked: { root.logText = tube.logText(); tube.copyText(root.logText); app.showToast(qsTr("Günlük panoya kopyalandı")); } }
                    }
                    Rectangle {
                        width: 110; height: 44; radius: 22; color: lcMa.pressed ? app.pressed : app.fieldBg
                        Text { anchors.centerIn: parent; text: qsTr("Temizle"); color: app.textPrimary; font.pixelSize: 17 }
                        MouseArea { id: lcMa; anchors.fill: parent; onClicked: { tube.clearLog(); root.logText = ""; app.showToast(qsTr("Günlük temizlendi")); } }
                    }
                }
            }
            Rectangle {
                width: parent.width
                visible: root.showLog
                height: visible ? logT.paintedHeight + 20 : 0
                color: app.surface
                radius: 8
                Text {
                    id: logT
                    x: 10; y: 10
                    width: parent.width - 20
                    text: root.logText
                    textFormat: Text.PlainText
                    wrapMode: Text.WrapAnywhere
                    color: app.textSecondary
                    font.pixelSize: 13
                }
            }

            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: qsTr("\nBelleTube 0.7 - videolar kendi sunucunuz üzerinden gelir. YouTube ile resmi bir bağlantısı yoktur; Google hesabı gerekmez. Abonelik listeniz sunucuda saklanır.")
                color: app.textSecondary
                font.pixelSize: 16
            }
        }
    }
}
