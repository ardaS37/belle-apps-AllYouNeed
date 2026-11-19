import QtQuick 1.1

Rectangle {
    id: page
    color: app.bg
    property bool logOpen: false

    function takeFocus() { page.forceActiveFocus(); }
    function scrollBy(dir) {
        var maxY = Math.max(0, flick.contentHeight - flick.height);
        flick.contentY = Math.max(0, Math.min(maxY, flick.contentY + dir * Math.round(flick.height * 0.6)));
    }
    Keys.onUpPressed: { scrollBy(-1); event.accepted = true; }
    Keys.onDownPressed: { scrollBy(1); event.accepted = true; }
    Keys.onLeftPressed: { app.stepTab(-1); event.accepted = true; }
    Keys.onRightPressed: { app.stepTab(1); event.accepted = true; }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: qsTr("Ayarlar")
        subtitle: qsTr("E6Müzik 1.1")
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

            Text { visible: kisisel; text: qsTr("Kaynak"); color: app.accent; font.pixelSize: 18; font.bold: true }
            Flow {
                visible: kisisel
                width: parent.width
                spacing: 8
                Chip { text: qsTr("Kendi sunucum"); selected: app.kaynak === "belle"; onClicked: app.kaynakSec("belle") }
                Chip { text: "s60tube"; selected: app.kaynak !== "belle"; onClicked: app.kaynakSec("s60") }
            }
            Text { visible: !app.belleModu; text: qsTr("Varsayılan müzik servisi"); color: app.accent; font.pixelSize: 18; font.bold: true }
            Flow {
                visible: !app.belleModu
                width: parent.width
                spacing: 8
                Repeater {
                    model: app.api().SERVICES
                    Chip { text: modelData.name; selected: app.service === modelData.id; onClicked: { app.service = modelData.id; app.setSetting("service", modelData.id); } }
                }
            }
            Text { visible: !app.belleModu; width: parent.width; wrapMode: Text.Wrap; color: app.textSecondary; font.pixelSize: 15
                   text: qsTr("Keşfet ve Ara bu servisle açılır (ekranda değiştirebilirsiniz). YouTube Music'te herkese açık listelerinizi adıyla arayabilir ya da Kitaplık'tan bağlantısıyla ekleyebilirsiniz; bir şarkının ilk çalınışı birkaç saniye sürebilir. NhacCuaTui kapakları telefonda gösterilemiyor (WebP).") }
            Text { visible: kisisel && app.belleModu; text: qsTr("Sunucu"); color: app.accent; font.pixelSize: 18; font.bold: true }
            Text { visible: app.belleModu; width: parent.width; wrapMode: Text.Wrap; color: app.textSecondary; font.pixelSize: 15
                   text: qsTr("BelleMusic şarkıları yalnızca kendi sunucunuzdan getirir (BelleTube ile aynı sunucu ve parola). Bir şarkının ilk çalınışı sunucuda hazırlandığı için 30-60 saniye sürebilir, sonrakiler hemen başlar.") }
            TextField {
                id: sunucuKutu
                visible: app.belleModu
                width: parent.width
                placeholder: qsTr("Sunucu adresi")
                text: app.belleServer
                onAccepted: parolaKutu.focusInput()
            }
            TextField {
                id: parolaKutu
                visible: app.belleModu
                width: parent.width
                placeholder: app.belleKey !== "" ? qsTr("Parola kayıtlı (değiştirmek için yazın)") : qsTr("Sunucu parolası")
                Component.onCompleted: input.echoMode = TextInput.Password
                onAccepted: kaydetBtn.clicked()
            }
            Btn {
                id: kaydetBtn
                visible: app.belleModu
                text: qsTr("Kaydet")
                onClicked: {
                    var s = sunucuKutu.text.replace(/^\s+|\s+$/g, "").replace(/\/+$/, "");
                    if (s === "" || s.indexOf("203.0.113.10") >= 0) s = "https://e6.msahincelen.xyz";
                    if (!/^https?:\/\//.test(s)) s = "http://" + s;
                    app.belleServer = s; app.setSetting("belleServer", s);
                    if (parolaKutu.text !== "") { app.belleKey = parolaKutu.text; app.setSetting("belleKey", parolaKutu.text); parolaKutu.text = ""; }
                    sunucuKutu.text = s;
                    app.showToast(qsTr("Sunucu kaydedildi"));
                }
            }

            Rectangle { width: parent.width; height: 1; color: app.divider }
            DilSatiri { width: parent.width; yazi: app.textPrimary; ikinci: app.textSecondary; vurgu: app.accent; boyut: 19 }
            DepoSatiri { width: parent.width; yazi: app.textPrimary; ikinci: app.textSecondary; vurgu: app.accent; boyut: 19 }
            Rectangle { width: parent.width; height: 1; color: app.divider }
            Text { text: qsTr("Oynatma"); color: app.accent; font.pixelSize: 18; font.bold: true }
            Flow {
                width: parent.width
                spacing: 8
                Chip { text: qsTr("Yerel aktarıcı (önerilen)"); selected: app.useRelay; onClicked: { app.useRelay = true; app.setSetting("relay", "1"); } }
                Chip { text: qsTr("Doğrudan"); selected: !app.useRelay; onClicked: { app.useRelay = false; app.setSetting("relay", "0"); } }
            }
            Text { width: parent.width; wrapMode: Text.Wrap; color: app.textSecondary; font.pixelSize: 15
                   text: qsTr("Yerel aktarıcı, sesi telefondaki küçük bir sunucu üzerinden oynatıcıya verir; yönlendirmeleri ve ileri-geri sarmayı daha sağlam yapar. Bir şarkı çalmazsa uygulama kendiliğinden diğer yolu da dener.") }

            Item {
                width: parent.width; height: 56
                Text { anchors { left: parent.left; verticalCenter: parent.verticalCenter } text: qsTr("Kapak resimlerini göster"); color: app.textPrimary; font.pixelSize: 19 }
                Rectangle {
                    id: sw
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 64; height: 34; radius: 17
                    color: app.showCovers ? app.accent : "#555560"
                    Rectangle { width: 28; height: 28; radius: 14; y: 3; x: app.showCovers ? sw.width - width - 3 : 3; color: "white"; Behavior on x { NumberAnimation { duration: 150 } } }
                }
                MouseArea { anchors.fill: parent; onClicked: { app.showCovers = !app.showCovers; app.setSetting("covers", app.showCovers ? "1" : "0"); } }
            }
            Text { width: parent.width; wrapMode: Text.Wrap; color: app.textSecondary; font.pixelSize: 15; text: qsTr("Kapatırsanız listeler daha hızlı açılır ve daha az veri harcanır.") }

            Rectangle { width: parent.width; height: 1; color: app.divider }
            Text { text: qsTr("İndirmeler"); color: app.accent; font.pixelSize: 18; font.bold: true }
            Text { width: parent.width; wrapMode: Text.Wrap; color: app.textPrimary; font.pixelSize: 17; text: qsTr("Klasör: ") + music.musicDir }
            Text {
                width: parent.width; wrapMode: Text.Wrap; color: app.textSecondary; font.pixelSize: 15
                text: music.queueCount > 0 ? qsTr("Şu an ") + music.queueCount + qsTr(" şarkı iniyor (%") + app.dlPercent + ")." : qsTr("İndirilen şarkılar internetsiz de çalar ve telefonun Müzik uygulamasında da görünür.")
            }
            Btn { visible: music.queueCount > 0; text: qsTr("Tüm indirmeleri iptal et"); icon: "close"; onClicked: music.cancelAll() }

            Rectangle { width: parent.width; height: 1; color: app.divider }
            Text { text: qsTr("Geçmiş"); color: app.accent; font.pixelSize: 18; font.bold: true }
            Flow {
                width: parent.width
                spacing: 10
                Btn { text: qsTr("Son çalınanları temizle"); icon: "trash"; onClicked: { app.clearRecent(); app.showToast(qsTr("Temizlendi")); } }
                Btn { text: qsTr("Arama geçmişini temizle"); icon: "trash"; onClicked: { app.clearSearches(); searchPage.reloadHistory(); app.showToast(qsTr("Temizlendi")); } }
            }

            Rectangle { width: parent.width; height: 1; color: app.divider }
            Text { text: qsTr("Günlük (son 30 kayıt)"); color: app.accent; font.pixelSize: 18; font.bold: true }
            Flow {
                width: parent.width
                spacing: 10
                Btn { text: page.logOpen ? qsTr("Gizle") : qsTr("Göster"); onClicked: { page.logOpen = !page.logOpen; logText.text = music.logText(); } }
                Btn { text: qsTr("Kopyala"); onClicked: { music.copyText(music.logText()); app.showToast(qsTr("Günlük kopyalandı")); } }
                Btn { text: qsTr("Temizle"); onClicked: { music.clearLog(); logText.text = ""; } }
            }
            Rectangle {
                visible: page.logOpen
                width: parent.width
                height: logText.paintedHeight + 24
                radius: 10
                color: app.surface
                Text { id: logText; x: 12; y: 12; width: parent.width - 24; wrapMode: Text.WrapAnywhere; color: app.textSecondary; font.pixelSize: 13 }
            }

            Rectangle { width: parent.width; height: 1; color: app.divider }
            Text { text: qsTr("Klavye"); color: app.accent; font.pixelSize: 18; font.bold: true }
            Text {
                width: parent.width; wrapMode: Text.Wrap; color: app.textSecondary; font.pixelSize: 15
                text: qsTr("Sol/sağ: sekmeler (ayrıntı sayfasında sol: geri)\nYukarı/aşağı: listede gezinme, Enter/orta tuş: aç/çal\nBoşluk: şarkı seç (çoklu seçim)\nÇalar ekranında: Boşluk/Enter çal-duraklat, sol/sağ 10 sn sar, yukarı/aşağı önceki/sonraki\nSes tuşları ve kulaklık tuşları desteklenir.")
            }

            Rectangle { width: parent.width; height: 1; color: app.divider }
            Text {
                width: parent.width; wrapMode: Text.Wrap; color: app.textSecondary; font.pixelSize: 14
                text: app.belleModu ? qsTr("BelleMusic – kendi sunucunuza (Belle) bağlı müzik istemcisi: arama, listeler, indirme ve çalma sunucunuz üzerinden yapılır. Ses MP3.")
                              : qsTr("BelleMusic – MIDPlay'in kullandığı s60tube müzik sunucusu (music.s60tube.io.vn) için yerel Qt istemcisi. Her şey doğrudan s60tube ve servislerin kendi resim sunucularından gelir; başka sunucu kullanılmaz. Ses 128 kbps MP3.")
            }
        }
    }
}
