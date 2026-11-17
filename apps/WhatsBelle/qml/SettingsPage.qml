import QtQuick 1.1
import "Util.js" as Util

// Ayarlar: profil, tema, sunucu, yenileme suresi, cikis
Rectangle {
    id: root
    color: app.bg
    property bool reporting: false

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: qsTr("Ayarlar")
    }

    function takeFocus() { root.forceActiveFocus(); }
    function scrollBy(dir) {
        var maxY = Math.max(0, flick.contentHeight - flick.height);
        flick.contentY = Math.max(0, Math.min(maxY, flick.contentY + dir * Math.round(flick.height * 0.6)));
    }
    Keys.onUpPressed: { scrollBy(-1); event.accepted = true; }
    Keys.onDownPressed: { scrollBy(1); event.accepted = true; }
    Keys.onLeftPressed: { app.stepTab(-1); event.accepted = true; }
    Keys.onRightPressed: { app.stepTab(1); event.accepted = true; }

    Flickable {
        id: flick
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        contentHeight: col.height + 30
        clip: true

        Column {
            id: col
            width: parent.width

            // Profil karti
            Item {
                width: parent.width
                height: 110
                Avatar {
                    id: av
                    anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                    name: app.myName !== "" ? app.myName : app.me
                    key: app.me
                    peer: app.me !== "" ? app.me + "@c.us" : ""
                    size: 72
                }
                Column {
                    anchors { left: av.right; leftMargin: 18; right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                    spacing: 2
                    Text {
                        width: parent.width
                        text: app.myName !== "" ? app.myName : qsTr("Hesabım")
                        color: app.textPrimary
                        font.pixelSize: 26
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text { width: parent.width; text: "+" + app.me + (app.ikiHesap ? "  ·  " + app.aktif + qsTr(". hesap") : ""); color: app.textSecondary; font.pixelSize: 20 }
                }
                // Iki hesap varken: W² rozeti
                Rectangle {
                    visible: app.ikiHesap
                    anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                    width: 76; height: 46; radius: 23
                    color: app.pill
                    Text { anchors.centerIn: parent; text: "W²"; color: app.accentText; font.pixelSize: 26; font.bold: true }
                }
            }
            Rectangle { width: parent.width; height: 8; color: app.dark ? "#0B141A" : "#F0F2F5" }

            // ---- Hesaplar ----
            Column {
                x: 20
                width: parent.width - 40
                spacing: 8
                Item { width: 1; height: 8 }
                Text { text: app.ikiHesap ? qsTr("Hesaplar (W²)") : qsTr("Hesaplar"); color: app.accentText; font.pixelSize: 19; font.bold: true }
                Repeater {
                    model: app.ikiHesap ? 2 : 1
                    delegate: Rectangle {
                        property int h: index + 1
                        property bool sec: app.aktif === h
                        width: parent.width
                        height: 62
                        radius: 12
                        color: hMa.pressed ? app.pressed : (sec && app.ikiHesap ? app.pill : app.fieldBg)
                        Column {
                            anchors { left: parent.left; leftMargin: 16; right: hEtk.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            Text { width: parent.width; text: h + ". " + app.hesapAd(h); color: app.textPrimary; font.pixelSize: 20; font.bold: sec; elide: Text.ElideRight }
                            Text { width: parent.width; text: "+" + app.hesapNo(h); color: app.textSecondary; font.pixelSize: 16 }
                        }
                        Text {
                            id: hEtk
                            anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                            text: sec ? qsTr("Etkin") : qsTr("Geç")
                            color: sec ? app.accentText : app.textPrimary
                            font.pixelSize: 18
                            font.bold: true
                        }
                        MouseArea { id: hMa; anchors.fill: parent; onClicked: app.hesapSec(h) }
                    }
                }
                Row {
                    spacing: 10
                    Rectangle {
                        visible: !app.ikiHesap
                        width: ekText.paintedWidth + 36; height: 46; radius: 23
                        color: ekMa.pressed ? app.brandPressed : app.brand
                        Text { id: ekText; anchors.centerIn: parent; text: qsTr("2. hesabı ekle"); color: app.dark ? "#0B141A" : "#FFFFFF"; font.pixelSize: 18; font.bold: true }
                        MouseArea { id: ekMa; anchors.fill: parent; onClicked: app.ikinciEkleBasla() }
                    }
                    Rectangle {
                        visible: app.ikiHesap
                        width: dgText.paintedWidth + 36; height: 46; radius: 23
                        color: dgMa.pressed ? app.brandPressed : app.brand
                        Text { id: dgText; anchors.centerIn: parent; text: qsTr("Hesap değiştir"); color: app.dark ? "#0B141A" : "#FFFFFF"; font.pixelSize: 18; font.bold: true }
                        MouseArea { id: dgMa; anchors.fill: parent; onClicked: app.hesapDegistir() }
                    }
                    Rectangle {
                        visible: app.ikiHesap
                        width: kaText.paintedWidth + 36; height: 46; radius: 23
                        color: kaMa.pressed ? app.pressed : app.fieldBg
                        Text { id: kaText; anchors.centerIn: parent; text: qsTr("2. hesabı kaldır"); color: app.danger; font.pixelSize: 18 }
                        MouseArea { id: kaMa; anchors.fill: parent; onClicked: app.ikinciKaldir() }
                    }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: app.ikiHesap ? qsTr("İki hesabın da bildirimleri gelir; başlıkta hangi hesaba geldiği yazar. Sohbetler listesindeki W² düğmesi de hesabı değiştirir.")
                                       : qsTr("İkinci bir WhatsApp numarası ekleyebilirsiniz (aynı sunucu). Numara sunucuda bağlı değilse QR kodu gösterilir.")
                    color: app.textSecondary
                    font.pixelSize: 16
                }
                Item { width: 1; height: 8 }
            }
            Rectangle { width: parent.width; height: 1; color: app.divider }

            DilSatiri { x: 20; width: parent.width - 40; yazi: app.textPrimary; ikinci: app.textSecondary; vurgu: app.brand; boyut: 23 }
            Rectangle { width: parent.width; height: 1; color: app.divider }

            // Posta sekmesi anahtari
            Item {
                width: parent.width
                height: 76
                Rectangle { anchors.fill: parent; color: mailMa.pressed ? app.pressed : app.bg }
                Column {
                    anchors { left: parent.left; leftMargin: 20; right: mailSw.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    Text { text: qsTr("Posta sekmesi"); color: app.textPrimary; font.pixelSize: 23 }
                    Text { width: parent.width; text: app.mailOn ? qsTr("Açık: e-postalar ve bildirimleri gösterilir") : qsTr("Kapalı: sekme ve posta bildirimleri gizli"); color: app.textSecondary; font.pixelSize: 16; elide: Text.ElideRight }
                }
                Rectangle {
                    id: mailSw
                    anchors { right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter }
                    width: 64; height: 34; radius: 17
                    color: app.mailOn ? app.brand : "#C4CBD0"
                    Rectangle {
                        width: 28; height: 28; radius: 14; y: 3
                        x: app.mailOn ? mailSw.width - width - 3 : 3
                        color: "#FFFFFF"
                        Behavior on x { NumberAnimation { duration: 150 } }
                    }
                }
                MouseArea { id: mailMa; anchors.fill: parent; onClicked: app.setMailOn(!app.mailOn) }
            }
            Rectangle { width: parent.width; height: 1; color: app.divider }

            // Karanlik tema anahtari
            Item {
                width: parent.width
                height: 76
                Rectangle { anchors.fill: parent; color: themeMa.pressed ? app.pressed : app.bg }
                Text {
                    anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                    text: qsTr("Karanlık tema")
                    color: app.textPrimary
                    font.pixelSize: 23
                }
                Rectangle {
                    id: sw
                    anchors { right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter }
                    width: 64
                    height: 34
                    radius: 17
                    color: app.dark ? app.brand : "#C4CBD0"
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        y: 3
                        x: app.dark ? sw.width - width - 3 : 3
                        color: "#FFFFFF"
                        smooth: true
                        Behavior on x { NumberAnimation { duration: 150 } }
                    }
                }
                MouseArea { id: themeMa; anchors.fill: parent; onClicked: app.setDark(!app.dark) }
            }
            Rectangle { width: parent.width; height: 1; color: app.divider }

            // Sunucu
            Column {
                x: 20
                width: parent.width - 40
                spacing: 8
                Item { width: 1; height: 8 }
                Text { text: qsTr("Sunucu adresi"); color: app.accentText; font.pixelSize: 19; font.bold: true }
                Row {
                    width: parent.width
                    spacing: 10
                    TextField {
                        id: serverField
                        width: parent.width - saveBtn.width - 10
                        text: app.server
                        inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText
                    }
                    Rectangle {
                        id: saveBtn
                        width: 120
                        height: 56
                        radius: 28
                        color: saveMa.pressed ? app.brandPressed : app.brand
                        Text { anchors.centerIn: parent; text: qsTr("Kaydet"); color: app.dark ? "#0B141A" : "#FFFFFF"; font.pixelSize: 21; font.bold: true }
                        MouseArea {
                            id: saveMa
                            anchors.fill: parent
                            onClicked: {
                                var s = Util.trimServer(serverField.text);
                                if (s === "") return;
                                app.server = s;
                                app.apiKey = keyField.text.replace(/^\s+|\s+$/g, "");
                                app.setSetting("server", s);
                                app.setSetting("key", app.apiKey);
                                app.configureApi();
                                serverField.text = s;
                                app.showToast(qsTr("Sunucu ayarları kaydedildi"));
                            }
                        }
                    }
                }
                Text { text: qsTr("Sunucu parolası"); color: app.accentText; font.pixelSize: 19; font.bold: true }
                TextField {
                    id: keyField
                    width: parent.width - saveBtn.width - 10
                    text: app.apiKey
                    placeholder: qsTr("Parola")
                    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                }
                Item { width: 1; height: 8 }
            }
            Rectangle { width: parent.width; height: 1; color: app.divider }

            // Yenileme suresi
            Column {
                x: 20
                width: parent.width - 40
                spacing: 10
                Item { width: 1; height: 8 }
                Text { text: qsTr("Yeni mesajları kontrol et"); color: app.accentText; font.pixelSize: 19; font.bold: true }
                Row {
                    spacing: 10
                    Repeater {
                        model: [10, 15, 30, 60]
                        delegate: Rectangle {
                            width: 110
                            height: 50
                            radius: 25
                            property bool sel: app.refreshSec === modelData
                            color: sel ? app.pill : app.bg
                            border.width: sel ? 0 : 1
                            border.color: app.dark ? "#3B4A54" : "#D1D7DB"
                            Text {
                                anchors.centerIn: parent
                                text: modelData + qsTr(" sn")
                                color: sel ? app.accentText : app.textPrimary
                                font.pixelSize: 20
                                font.bold: sel
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { app.refreshSec = modelData; app.setSetting("refresh", modelData); }
                            }
                        }
                    }
                }
                Item { width: 1; height: 8 }
            }
            Rectangle { width: parent.width; height: 1; color: app.divider }

            // Arka plan bildirimleri
            Column {
                x: 20
                width: parent.width - 40
                spacing: 10
                Item { width: 1; height: 8 }
                Text { text: qsTr("Arka plan bildirimleri"); color: app.accentText; font.pixelSize: 19; font.bold: true }
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: qsTr("Uygulama arka plandayken bu aralıkla yeni mesajlara bakar ve ekranın köşesinde bildirim gösterir. Kısa aralık pili biraz daha çok kullanır.")
                    color: app.textSecondary
                    font.pixelSize: 16
                }
                Row {
                    spacing: 8
                    Repeater {
                        model: [0, 1, 2, 5, 15]
                        delegate: Rectangle {
                            width: 98
                            height: 50
                            radius: 25
                            property bool sel: app.notifyMin === modelData
                            color: sel ? app.pill : app.bg
                            border.width: sel ? 0 : 1
                            border.color: app.dark ? "#3B4A54" : "#D1D7DB"
                            Text {
                                anchors.centerIn: parent
                                text: modelData === 0 ? qsTr("Kapalı") : modelData + qsTr(" dk")
                                color: sel ? app.accentText : app.textPrimary
                                font.pixelSize: 19
                                font.bold: sel
                            }
                            MouseArea { anchors.fill: parent; onClicked: app.setNotifyMin(modelData) }
                        }
                    }
                }
                Item {
                    width: parent.width
                    height: 60
                    Text {
                        anchors { left: parent.left; right: autoSw.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: qsTr("Telefon açılınca arka planda başlat")
                        wrapMode: Text.Wrap
                        color: app.textPrimary
                        font.pixelSize: 20
                    }
                    Rectangle {
                        id: autoSw
                        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                        width: 64; height: 34; radius: 17
                        color: notify.autostart ? app.brand : "#C4CBD0"
                        Rectangle {
                            width: 28; height: 28; radius: 14; y: 3
                            x: notify.autostart ? autoSw.width - width - 3 : 3
                            color: "#FFFFFF"
                            Behavior on x { NumberAnimation { duration: 150 } }
                        }
                    }
                    MouseArea { anchors.fill: parent; onClicked: notify.autostart = !notify.autostart }
                }
                Item {
                    width: parent.width
                    height: 60
                    Text {
                        anchors { left: parent.left; right: drawerSw.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: qsTr("Durum çubuğu çekmecesine bildirim")
                        wrapMode: Text.Wrap
                        color: app.textPrimary
                        font.pixelSize: 20
                    }
                    Rectangle {
                        id: drawerSw
                        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                        width: 64; height: 34; radius: 17
                        color: app.drawerNotify ? app.brand : "#C4CBD0"
                        Rectangle {
                            width: 28; height: 28; radius: 14; y: 3
                            x: app.drawerNotify ? drawerSw.width - width - 3 : 3
                            color: "#FFFFFF"
                            Behavior on x { NumberAnimation { duration: 150 } }
                        }
                    }
                    MouseArea { anchors.fill: parent; onClicked: app.setDrawerNotify(!app.drawerNotify) }
                }
                Item {
                    width: parent.width
                    height: 60
                    Text {
                        anchors { left: parent.left; right: nokiaSw.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: qsTr("Nokia mesaj notu (yalnızca ekran kapalıyken)")
                        wrapMode: Text.Wrap
                        color: app.textPrimary
                        font.pixelSize: 20
                    }
                    Rectangle {
                        id: nokiaSw
                        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                        width: 64; height: 34; radius: 17
                        color: app.nokiaNote ? app.brand : "#C4CBD0"
                        Rectangle {
                            width: 28; height: 28; radius: 14; y: 3
                            x: app.nokiaNote ? nokiaSw.width - width - 3 : 3
                            color: "#FFFFFF"
                            Behavior on x { NumberAnimation { duration: 150 } }
                        }
                    }
                    MouseArea { anchors.fill: parent; onClicked: app.setNokiaNote(!app.nokiaNote) }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: (notify.piglerReady() ? qsTr("Pigler eklentisi kurulu: çekmecede gönderen ve mesaj görünür, dokununca sohbet açılır.")
                                                : qsTr("Pigler eklentisi kurulu değil: sistemin genel \"yeni sohbet mesajı\" notu kullanılır."))
                          + qsTr("\nSon kontrol: ") + (app.lastNotifyInfo !== "" ? app.lastNotifyInfo : qsTr("henüz yok"))
                          + (app.ikiHesap && app.lastNotifyInfo2 !== "" ? "\n" + app.lastNotifyInfo2 : "")
                    color: app.textSecondary
                    font.pixelSize: 16
                }
                Row {
                    spacing: 10
                    Rectangle {
                        width: testText.paintedWidth + 36; height: 46; radius: 23
                        color: testMa.pressed ? app.pressed : app.fieldBg
                        Text { id: testText; anchors.centerIn: parent; text: qsTr("Bildirimi dene"); color: app.textPrimary; font.pixelSize: 18 }
                        MouseArea {
                            id: testMa
                            anchors.fill: parent
                            onClicked: {
                                notify.show(qsTr("WhatsBelle"), qsTr("Bildirimler çalışıyor"));
                                if (app.drawerNotify) notify.postKind("chat", qsTr("WhatsBelle"), qsTr("Deneme bildirimi"), 1);
                                notify.vibrate(300);
                                notify.log("deneme bildirimi; " + notify.postInfo());
                            }
                        }
                    }
                }
                Item { width: 1; height: 8 }
            }
            Rectangle { width: parent.width; height: 1; color: app.divider }

            // ---- Hata raporu ----
            Column {
                x: 20
                width: parent.width - 40
                spacing: 10
                Item { width: 1; height: 6 }
                Text { text: qsTr("Sorun bildir"); color: app.accentText; font.pixelSize: 19; font.bold: true }
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: qsTr("Uygulamanın günlüğünü ve ayarlarını (parola hariç) sunucuya gönderir; sorunun ne olduğunu oradan görebilirim. Yalnızca düğmeye bastığınızda gider.")
                    color: app.textSecondary
                    font.pixelSize: 16
                }
                TextField { id: reportNote; width: parent.width; placeholder: qsTr("Ne oldu? (isteğe bağlı)"); fontSize: 19 }
                Row {
                    spacing: 10
                    Rectangle {
                        width: repText.paintedWidth + 36; height: 46; radius: 23
                        color: repMa.pressed ? app.brandPressed : app.brand
                        Text { id: repText; anchors.centerIn: parent; text: root.reporting ? qsTr("Gönderiliyor...") : qsTr("Rapor gönder"); color: "white"; font.pixelSize: 18; font.bold: true }
                        MouseArea {
                            id: repMa
                            anchors.fill: parent
                            enabled: !root.reporting
                            onClicked: {
                                root.reporting = true;
                                app.sendReport(reportNote.text, function (ok, msg) {
                                    root.reporting = false;
                                    if (ok) reportNote.text = "";
                                    app.showToast(msg);
                                });
                            }
                        }
                    }
                    Rectangle {
                        width: clrText.paintedWidth + 36; height: 46; radius: 23
                        color: clrMa.pressed ? app.pressed : app.fieldBg
                        Text { id: clrText; anchors.centerIn: parent; text: qsTr("Günlüğü temizle"); color: app.textPrimary; font.pixelSize: 18 }
                        MouseArea { id: clrMa; anchors.fill: parent; onClicked: { notify.clearLog(); app.showToast(qsTr("Günlük temizlendi")); } }
                    }
                }
                Item { width: 1; height: 8 }
            }
            Rectangle { width: parent.width; height: 1; color: app.divider }

            Item {
                width: parent.width
                height: 76
                Rectangle { anchors.fill: parent; color: logoutMa.pressed ? app.pressed : app.bg }
                Text {
                    anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                    text: app.ikiHesap ? qsTr("Etkin hesaptan çıkış yap") : qsTr("Çıkış yap")
                    color: app.danger
                    font.pixelSize: 23
                }
                MouseArea { id: logoutMa; anchors.fill: parent; onClicked: app.logout() }
            }
            Rectangle { width: parent.width; height: 1; color: app.divider }

            Text {
                x: 20
                width: parent.width - 40
                wrapMode: Text.Wrap
                text: qsTr("\nWhatsBelle ") + app.version + qsTr(" - kendi WhatsBelle sunucusuyla çalışır. WhatsApp ile resmi bir bağlantısı yoktur. Emojiler: Twemoji (Twitter, CC-BY 4.0).")
                color: app.textSecondary
                font.pixelSize: 17
            }
        }
    }
}
