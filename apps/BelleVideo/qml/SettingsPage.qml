import QtQuick 1.1

// Ayarlar. Klavye: yukari/asagi satir secer, Enter degistirir, Sol/Sag sekme.
Rectangle {
    id: root
    color: app.bg

    property int sel: 0
    property bool showLog: false

    function takeFocus() { flick.forceActiveFocus(); }

    // Satirlar: kind "toggle" | "cycle" | "action" | "info"
    function rows() {
        return [
            { key: "resume", kind: "toggle", title: qsTr("Kaldığı yerden devam et"), sub: qsTr("Her dosyanın kaldığı saniyeyi hatırlar"), isOn: app.resume },
            { key: "bgAudio", kind: "toggle", title: qsTr("Kilitte ve arka planda sesle devam"), sub: qsTr("Video durur, ses aynı yerden sürer; dönünce görüntü geri gelir"), isOn: app.bgAudio },
            { key: "autoNext", kind: "toggle", title: qsTr("Klasörde bitince sonrakine geç"), sub: qsTr("Liste'de her zaman sonrakine geçilir"), isOn: app.autoNext },
            { key: "seekStep", kind: "cycle", title: qsTr("Sarma adımı"), sub: qsTr("Sol/sağ tuşu ve 10 sn düğmeleri"), value: app.seekStep + qsTr(" sn") },
            { key: "directFile", kind: "toggle", title: qsTr("Doğrudan dosyadan oynat"), sub: qsTr("Sorun giderme: yerel sunucuyu atlar (E6'da genelde yalnızca ses gelir)"), isOn: app.directFile },
            { key: "lang", kind: "cycle", title: "Dil / Language", sub: dil.yenidenBaslat ? "Yeniden açınca geçerli olur / Restart to apply" : "Türkçe / English", value: (dil.secim === "auto" ? dil.kod : dil.secim) === "en" ? "EN" : "TR" },
            { key: "depo", kind: "cycle", title: qsTr("Depolama yeri"), sub: qsTr("Önbellek ve indirmeler: ") + depo.etkinAd + (depo.yenidenBaslat ? qsTr(" → yeniden açınca: ") + depo.hedefAd : ""), value: depo.secim === "auto" ? qsTr("Oto") : depo.secim + ":" },
            { key: "rescan", kind: "action", title: qsTr("Videoları yeniden tara"), sub: lib.scanning ? qsTr("Taranıyor... ") + lib.scanFound : qsTr("Hafıza kartı ve telefon belleği") },
            { key: "log", kind: "action", title: root.showLog ? qsTr("Günlüğü gizle") : qsTr("Günlüğü göster"), sub: qsTr("Oynatma sorunlarında bakmak için") }
        ];
    }
    property variant items: rows()
    function refresh() { items = rows(); }
    Connections {
        target: lib
        onScanningChanged: root.refresh()
    }

    function activate(i) {
        var r = items[i];
        if (!r) return;
        if (r.key === "resume") { app.resume = !app.resume; app.setSetting("resume", app.resume ? 1 : 0); }
        else if (r.key === "bgAudio") { app.bgAudio = !app.bgAudio; app.setSetting("bgAudio", app.bgAudio ? 1 : 0); }
        else if (r.key === "autoNext") { app.autoNext = !app.autoNext; app.setSetting("autoNext", app.autoNext ? 1 : 0); }
        else if (r.key === "directFile") { app.directFile = !app.directFile; app.setSetting("directFile", app.directFile ? 1 : 0); }
        else if (r.key === "seekStep") { var s = [5, 10, 15, 30]; var k = s.indexOf(app.seekStep); app.seekStep = s[(k + 1) % s.length]; app.setSetting("seekStep", app.seekStep); }
        else if (r.key === "lang") { var dk = dil.secim === "auto" ? dil.kod : dil.secim; dil.sec(dk === "en" ? "tr" : "en"); }
        else if (r.key === "depo") depo.sec(depo.sonraki());
        else if (r.key === "rescan") { lib.rescan(); app.showToast(qsTr("Tarama başladı")); }
        else if (r.key === "log") { showLog = !showLog; if (showLog) logText.text = lib.logText(); }
        refresh();
    }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: qsTr("Ayarlar")
        subtitle: qsTr("BelleVideo ") + app.version
    }

    Flickable {
        id: flick
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        clip: true
        contentHeight: col.height + 20
        focus: true

        function ensureY(y) {
            if (y < contentY) contentY = y;
            else if (y + 64 > contentY + height) contentY = y + 64 - height;
        }

        Column {
            id: col
            width: flick.width

            Repeater {
                id: rep
                model: root.items.length
                delegate: Item {
                    id: row
                    property variant r: root.items[index]
                    width: col.width
                    height: 64
                    Rectangle {
                        anchors.fill: parent
                        color: rowMa.pressed ? app.pressed : (root.sel === index && flick.activeFocus ? app.highlight : "transparent")
                    }
                    Rectangle { visible: root.sel === index && flick.activeFocus; width: 4; height: parent.height; color: app.brand }
                    Column {
                        anchors { left: parent.left; leftMargin: 18; right: ctl.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        Text { width: parent.width; text: row.r ? row.r.title : ""; color: app.textPrimary; font.pixelSize: 18; elide: Text.ElideRight }
                        Text { width: parent.width; text: row.r ? row.r.sub : ""; color: app.textSecondary; font.pixelSize: 13; elide: Text.ElideRight }
                    }
                    Item {
                        id: ctl
                        anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                        width: 70; height: 32
                        // ac/kapa
                        Rectangle {
                            visible: row.r && row.r.kind === "toggle"
                            anchors.right: parent.right
                            width: 52; height: 28; radius: 14
                            color: row.r && row.r.isOn ? app.brand : app.fieldBg
                            Rectangle {
                                width: 22; height: 22; radius: 11
                                anchors.verticalCenter: parent.verticalCenter
                                x: row.r && row.r.isOn ? parent.width - width - 3 : 3
                                color: "#FFFFFF"
                            }
                        }
                        Text {
                            visible: row.r && row.r.kind === "cycle"
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            text: row.r && row.r.value ? row.r.value : ""
                            color: app.brand; font.pixelSize: 17; font.bold: true
                        }
                    }
                    Rectangle { anchors { left: parent.left; leftMargin: 18; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
                    MouseArea { id: rowMa; anchors.fill: parent; onClicked: { root.sel = index; root.activate(index); flick.forceActiveFocus(); } }
                }
            }

            // Gunluk
            Rectangle {
                width: col.width - 24
                x: 12
                visible: root.showLog
                height: visible ? logText.paintedHeight + 20 : 0
                color: app.surface
                radius: 8
                Text {
                    id: logText
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                    wrapMode: Text.WrapAnywhere
                    color: app.textSecondary
                    font.pixelSize: 12
                    textFormat: Text.PlainText
                }
            }

            // Tuslar
            Item { width: 1; height: 14 }
            Text { x: 18; text: qsTr("Oynatıcı tuşları"); color: app.brand; font.pixelSize: 15; font.bold: true }
            Text {
                x: 18; width: col.width - 36
                wrapMode: Text.Wrap
                color: app.textSecondary
                font.pixelSize: 14
                lineHeight: 1.15
                text: qsTr("Enter / Boşluk: oynat-duraklat   •   Sol / Sağ: geri / ileri sar (basılı tut: hızlı)\n")
                    + qsTr("Yukarı / Aşağı ve ses tuşları: ses   •   F: tam ekran   •   S: sadece ses   •   V: videoya dön\n")
                    + qsTr("B: arka plana al (ses sürer)   •   N / P: sonraki / önceki   •   R: tekrar   •   K: karışık\n")
                    + qsTr("0: baştan   •   1-9: videonun %10-%90'ı   •   D: dış oynatıcı   •   Geri: kapat\n")
                    + qsTr("Listelerde: Boşluk seçenekler, + listeye ekle, harf yazınca arama")
            }

            Item { width: 1; height: 14 }
            Text { x: 18; text: qsTr("Hakkında"); color: app.brand; font.pixelSize: 15; font.bold: true }
            Text {
                x: 18; width: col.width - 36
                wrapMode: Text.Wrap
                color: app.textSecondary
                font.pixelSize: 14
                text: qsTr("BelleVideo ") + app.version + qsTr(". Star Player'ın (Paul Wallace / Allstar Software, MIT lisansı) yeteneklerinden yola çıkılarak E6 için baştan yazıldı. Videolar telefonda kalır, hiçbir sunucuya gönderilmez.\nİndirilenler: ") + lib.downloadDir()
            }
        }

        Keys.onPressed: {
            var k = event.key;
            if (k === Qt.Key_Down) { root.sel = Math.min(root.items.length - 1, root.sel + 1); ensureY(root.sel * 64); if (root.sel === root.items.length - 1) contentY = Math.max(0, contentHeight - height); event.accepted = true; }
            else if (k === Qt.Key_Up) { root.sel = Math.max(0, root.sel - 1); ensureY(root.sel * 64); event.accepted = true; }
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select || k === Qt.Key_Space) { root.activate(root.sel); event.accepted = true; }
            else if (k === Qt.Key_Left) { app.stepTab(-1); event.accepted = true; }
            else if (k === Qt.Key_Right) { app.stepTab(1); event.accepted = true; }
        }
    }
}
