import QtQuick 1.1
import "geri.js" as Geri

// BelleRemote arayüzü (640x480, tuş takımı + dokunmatik).
// Bağlantı ekranı: kayıtlı PC'ler, sunucudaki çevrimiçi PC'ler, adresle bağlanma, ayarlar.
// Oturum: Yön tuşları imleç, orta tuş kısa = sol tık, basılı tut = sağ tık; dokun = tık, basılı tut = sağ tık,
// sürükle = imleci taşı. Harf tuşu / PC'de yazı alanı etkinleşince yazı penceresi açılır.
// Sol yazılım tuşu: Seçenekler, sağ yazılım tuşu: Geri menüsü.
Rectangle {
    id: app
    width: 640; height: 480
    color: "#0E1318"

    property color surface: "#1A2026"
    property color textPrimary: "#ECEFF1"
    property color textSecondary: "#8C98A4"
    property color divider: "#252D35"
    property color highlight: "#26303A"
    property color accent: "#7CD992"
    property color warn: "#FFB300"
    property color danger: "#F15C6D"
    property int ekran: 0                 // 0 bağlantı, 1 oturum, 2 ayarlar
    property variant online: []
    property variant onlineGercek: []
    property string onlineHata: ""
    property bool durumCubugu: true

    // Dil / Language: Turkce <-> English (tum uygulamalarda ortak, yeniden acinca gecerli)
    function dilDegistir() {
        var k = dil.secim === "auto" ? dil.kod : dil.secim;
        dil.sec(k === "en" ? "tr" : "en");
        app.toast(dil.yenidenBaslat ? "Dil değişti; uygulamayı yeniden açın. / Language changed; restart the app." : "Dil / Language: " + (k === "en" ? "Türkçe" : "English"));
    }
    function toast(m) { toastText.text = m; toastBox.opacity = 1; toastTimer.restart(); }
    function odak() {
        if (yazi.visible) yaziInput.forceActiveFocus();
        else if (ekran === 1) oturum.forceActiveFocus();
        else if (ekran === 2) ayarList.forceActiveFocus();
        else homeList.forceActiveFocus();
    }

    // =====================================================================
    // Bağlantı ekranı modeli
    // =====================================================================
    ListModel { id: homeModel }
    function buildHome() {
        var keep = homeList.currentIndex;
        homeModel.clear();
        homeModel.append({ k: "", t: qsTr("SUNUCU TARAYICISI"), s: "", baslik: true });
        homeModel.append({ k: "tar", t: qsTr("Sunucu Tarayıcı"), s: qsTr("Sunucudaki Chrome: tüm siteler • indirme telefona ya da Drive'a"), baslik: false });
        var p = uzak.profiller();
        if (p.length) homeModel.append({ k: "", t: qsTr("KAYITLI BİLGİSAYARLAR"), s: "", baslik: true });
        for (var i = 0; i < p.length; i++)
            homeModel.append({ k: "p" + i, t: p[i].ad, s: (p[i].lan ? qsTr("Yerel: ") + p[i].lan + "  •  " : "") + qsTr("son: ") + p[i].yol + ", " + p[i].tarih, baslik: false });
        homeModel.append({ k: "", t: qsTr("SUNUCUDA ÇEVRİMİÇİ"), s: "", baslik: true });
        var o = [];
        for (var oi = 0; oi < app.online.length; oi++) if (app.online[oi].ad !== "tarayici") o.push(app.online[oi]);
        app.onlineGercek = o;
        if (!o.length) homeModel.append({ k: "yenile", t: app.onlineHata !== "" ? app.onlineHata : qsTr("Çevrimiçi PC yok — yenilemek için seç"), s: "", baslik: false });
        for (var j = 0; j < o.length; j++)
            homeModel.append({ k: "o" + j, t: o[j].ad, s: qsTr("Yerel: ") + o[j].lan + "  •  " + Math.round(o[j].sure / 60) + qsTr(" dk'dır bekliyor"), baslik: false });
        homeModel.append({ k: "", t: qsTr("BAĞLAN"), s: "", baslik: true });
        homeModel.append({ k: "lan", t: qsTr("Yerel ağda adresle bağlan…"), s: qsTr("PC uygulamasındaki 'Telefona verilecek adres'"), baslik: false });
        homeModel.append({ k: "srv", t: qsTr("Sunucu üzerinden PC adıyla bağlan…"), s: uzak.sunucu, baslik: false });
        homeModel.append({ k: "ayar", t: qsTr("Ayarlar"), s: qsTr("Sunucu, parola, hız, telefon IP'si"), baslik: false });
        var n = homeModel.count;
        var c = Math.max(0, Math.min(keep, n - 1));
        while (c < n && homeModel.get(c).baslik) c++;
        homeList.currentIndex = c < n ? c : 0;
    }
    function homeSec(i) {
        var k = homeModel.get(i).k;
        if (k === "") return;
        if (k.charAt(0) === "p") uzak.baglanProfil(parseInt(k.substring(1), 10));
        else if (k.charAt(0) === "o") {
            var o = app.onlineGercek[parseInt(k.substring(1), 10)];
            uzak.baglanIkili(o.lan, o.ad);       // önce yerel ağ (4 sn), olmazsa sunucu
        }
        else if (k === "tar") uzak.baglanTarayici();
        else if (k === "yenile") { uzak.pcListesiIste(); toast(qsTr("Sunucu soruluyor…")); }
        else if (k === "lan") ask(qsTr("Yerel ağ adresi (IP:port)"), sonLan, false, function (v) { sonLan = v; uzak.baglanLan(v); });
        else if (k === "srv") ask(qsTr("PC adı (PC uygulamasındaki ad)"), sonPc, false, function (v) { sonPc = v; uzak.baglanSunucu(v); });
        else if (k === "ayar") { ekran = 2; buildAyar(); ayarList.currentIndex = 0; odak(); }
    }
    property string sonLan: "192.168.1."
    property string sonPc: ""
    function homeMenu(i) {
        var k = homeModel.get(i).k;
        if (k.charAt(0) === "p") {
            var idx = parseInt(k.substring(1), 10);
            var p = uzak.profiller()[idx];
            var items = [{ k: "bagla", t: qsTr("Bağlan (önce yerel ağ, sonra sunucu)") }];
            if (p.lan) items.push({ k: "lan", t: qsTr("Yalnızca yerel ağ (") + p.lan + ")" });
            items.push({ k: "srv", t: qsTr("Yalnızca sunucu üzerinden") });
            items.push({ k: "sil", t: qsTr("Kayıtlı listeden sil") });
            menu.open(p.ad, items, function (c) {
                if (c === "bagla") uzak.baglanProfil(idx);
                else if (c === "lan") uzak.baglanLan(p.lan);
                else if (c === "srv") uzak.baglanSunucu(p.ad);
                else if (c === "sil") { uzak.profilSil(idx); buildHome(); }
            });
        } else if (k.charAt(0) === "o") {
            var o = app.onlineGercek[parseInt(k.substring(1), 10)];
            menu.open(o.ad, [{ k: "srv", t: qsTr("Sunucu üzerinden bağlan") }, { k: "lan", t: qsTr("Yerel ağdan bağlan (") + o.lan + ")" }], function (c) {
                if (c === "srv") uzak.baglanSunucu(o.ad); else uzak.baglanLan(o.lan);
            });
        } else homeSec(i);
    }
    function homeAnaMenu() {
        menu.open(qsTr("Belle Remote"), [
            { k: "yenile", t: qsTr("Çevrimiçi PC'leri yenile") },
            { k: "ip", t: qsTr("Telefonun IP adresini göster") },
            { k: "ayar", t: qsTr("Ayarlar") },
            { k: "kilavuz", t: qsTr("Kullanım kılavuzu") },
            { k: "log", t: qsTr("Günlük") },
            { k: "cik", t: qsTr("Çıkış") }
        ], function (c) {
            if (c === "yenile") { uzak.pcListesiIste(); toast(qsTr("Sunucu soruluyor…")); }
            else if (c === "ip") bilgi(qsTr("Telefonun adresi"), qsTr("Bu telefonun yerel ağ IP adresi:\n\n") + uzak.telefonIp() + qsTr("\n\nPC'nin adresi PC uygulamasında 'Telefona verilecek adres' kutusunda yazar (ör. 192.168.1.20:5680)."));
            else if (c === "ayar") { ekran = 2; buildAyar(); odak(); }
            else if (c === "log") bilgi(qsTr("Günlük"), uzak.gunlukMetni());
            else if (c === "kilavuz") kilavuz();
            else if (c === "cik") Qt.quit();
        });
    }

    Connections {
        target: uzak
        onMesaj: app.toast(m)
        onPcListesi: { app.online = pcler; app.onlineHata = hata; app.buildHome(); if (hata !== "") app.toast(hata); }
        onDurumChanged: {
            if (uzak.durum === 2 && app.ekran !== 1) { app.ekran = 1; menu.visible = false; app.odak(); }
            if (uzak.durum === 2 && uzak.tarayici && app.bekleyenAdres !== "") { var a = app.bekleyenAdres; app.bekleyenAdres = ""; uzak.git(a); }
            else if (uzak.durum === 0 && app.ekran === 1) { app.ekran = 0; yazi.visible = false; menu.visible = false; app.buildHome(); app.odak(); }
        }
        onYaziAlaniChanged: {
            if (uzak.yaziAlani && uzak.otoYazi && app.ekran === 1 && !yazi.visible && !menu.visible) app.yaziAc("");
        }
        onPencereListesi: {
            var items = [{ k: "masaustu", t: qsTr("Tüm masaüstü") }];
            for (var i = 0; i < satirlar.length; i++) {
                var tab = satirlar[i].indexOf("\t");
                if (tab < 0) continue;
                items.push({ k: "pencere:" + satirlar[i].substring(0, tab), t: satirlar[i].substring(tab + 1) });
            }
            menu.open(qsTr("Paylaşılacak pencere"), items, function (c) { uzak.kaynakSec(c); });
        }
    }

    // Belle Browser "Belle Remote'ta aç": adres dosyadan gelir, sunucu tarayicisina baglanip acilir
    property string bekleyenAdres: ""
    Component.onCompleted: {
        buildHome();
        var acil = uzak.acilacakAdres();
        if (acil !== "" && uzak.parolaVar) { bekleyenAdres = acil; uzak.baglanTarayici(); toast(qsTr("Belle Browser'dan: ") + acil); }
        else if (uzak.parolaVar) uzak.pcListesiIste();
        else toast(qsTr("Ayarlar'dan sunucu parolasını girin"));
        odak();
    }

    // =====================================================================
    // Bağlantı ekranı
    // =====================================================================
    Item {
        anchors.fill: parent
        visible: app.ekran === 0
        Rectangle {
            id: header
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 40; color: app.surface
            Text { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter } text: qsTr("Belle Remote"); color: app.textPrimary; font.pixelSize: 20; font.bold: true }
            Text {
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                text: uzak.durum === 1 ? uzak.durumMetni : (qsTr("Telefon: ") + uzak.telefonIp())
                color: uzak.durum === 1 ? app.warn : app.textSecondary; font.pixelSize: 13
                width: 420; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft
            }
            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
        }
        ListView {
            id: homeList
            anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: homeBar.top }
            clip: true; model: homeModel; focus: true
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            delegate: Item {
                width: homeList.width; height: baslik ? 30 : (s !== "" ? 52 : 44)
                property bool cur: ListView.isCurrentItem && homeList.activeFocus && !baslik
                Rectangle { anchors.fill: parent; color: baslik ? "#141A20" : (hma.pressed ? "#232B33" : (parent.cur ? app.highlight : "transparent")) }
                Rectangle { visible: parent.cur; anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 4; color: app.accent }
                Column {
                    anchors { left: parent.left; leftMargin: 14; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    Text { text: t; color: baslik ? app.textSecondary : app.textPrimary; font.pixelSize: baslik ? 12 : 17; font.bold: baslik; elide: Text.ElideRight; width: parent.width }
                    Text { visible: s !== "" && !baslik; text: s; color: app.textSecondary; font.pixelSize: 13; elide: Text.ElideRight; width: parent.width }
                }
                MouseArea { id: hma; anchors.fill: parent; enabled: !baslik; onClicked: { homeList.currentIndex = index; app.homeSec(index); } onPressAndHold: { homeList.currentIndex = index; app.homeMenu(index); } }
            }
            function adim(d) {
                var n = homeModel.count, i = currentIndex;
                for (var g = 0; g < n; g++) { i = (i + d + n) % n; if (!homeModel.get(i).baslik) break; }
                currentIndex = i;
            }
            Keys.onPressed: {
                var k = event.key;
                if (k === Qt.Key_Down) { adim(1); event.accepted = true; }
                else if (k === Qt.Key_Up) { adim(-1); event.accepted = true; }
                else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) { app.homeSec(currentIndex); event.accepted = true; }
                else if (k === Qt.Key_Context1) { var kk = homeModel.get(currentIndex).k; if (kk.charAt(0) === "p" || kk.charAt(0) === "o") app.homeMenu(currentIndex); else app.homeAnaMenu(); event.accepted = true; }
                else if (k === Qt.Key_Context2 || k === Qt.Key_Escape) { if (uzak.durum === 1) uzak.kes(); else Qt.quit(); event.accepted = true; }
            }
        }
        Rectangle {
            id: homeBar
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 30; color: app.surface
            Text { anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter } text: qsTr("Seçenekler"); color: app.textPrimary; font.pixelSize: 14
                   MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: app.homeAnaMenu() } }
            Text { anchors.centerIn: parent; text: uzak.durumMetni; color: app.textSecondary; font.pixelSize: 12; width: 360; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
            Text { anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } text: uzak.durum === 1 ? qsTr("Vazgeç") : qsTr("Çıkış"); color: app.textPrimary; font.pixelSize: 14
                   MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: { if (uzak.durum === 1) uzak.kes(); else Qt.quit(); } } }
        }
    }

    // =====================================================================
    // Ayarlar
    // =====================================================================
    ListModel { id: ayarModel }
    function buildAyar() {
        var keep = ayarList.currentIndex;
        ayarModel.clear();
        ayarModel.append({ k: "sunucu", t: qsTr("Sunucu adresi"), v: uzak.sunucu });
        ayarModel.append({ k: "parola", t: qsTr("Sunucu parolası (PC ile aynı)"), v: uzak.parolaVar ? qsTr("kayıtlı ••••••") : "girilmedi" });
        ayarModel.append({ k: "ad", t: qsTr("Telefon adı (PC'de görünür)"), v: uzak.telefonAdi });
        ayarModel.append({ k: "kip", t: qsTr("Gönderim kipi"), v: uzak.kip === "akis" ? qsTr("Akış (anında, hızlı ağ)") : qsTr("Paket (1 sn bekleyip toplu)") });
        ayarModel.append({ k: "fps", t: qsTr("Kare hızı"), v: uzak.fps + qsTr(" kare/sn") });
        ayarModel.append({ k: "kalite", t: qsTr("Görüntü kalitesi"), v: "%" + uzak.kalite });
        ayarModel.append({ k: "genislik", t: qsTr("Görüntü genişliği"), v: uzak.genislik + qsTr(" piksel") });
        ayarModel.append({ k: "oto", t: qsTr("PC'de yazı alanı açılınca yazı penceresi"), v: uzak.otoYazi ? qsTr("Açık") : qsTr("Kapalı") });
        ayarModel.append({ k: "lang", t: "Dil / Language", v: (dil.secim === "auto" ? dil.kod : dil.secim) === "en" ? "English" : "Türkçe" });
        ayarModel.append({ k: "depo", t: qsTr("Depolama yeri (indirmeler)"), v: depo.ad(depo.secim) + (depo.yenidenBaslat ? qsTr(" (yeniden açınca geçerli olur)") : "") });
        ayarModel.append({ k: "ip", t: qsTr("Telefonun IP adresi"), v: uzak.telefonIp() });
        ayarModel.append({ k: "log", t: qsTr("Günlük"), v: "C:/Data/E6Uzak/gunluk.txt" });
        ayarModel.append({ k: "rapor", t: qsTr("Sorun bildir (günlüğü sunucuya gönder)"), v: qsTr("Parola kayıtlı olmalı") });
        ayarList.currentIndex = Math.max(0, Math.min(keep, ayarModel.count - 1));
    }
    function ayarSec(i) {
        var k = ayarModel.get(i).k;
        if (k === "sunucu") ask(qsTr("Sunucu adresi"), uzak.sunucu, false, function (v) { uzak.setSunucu(v); buildAyar(); uzak.pcListesiIste(); });
        else if (k === "parola") ask(qsTr("Sunucu parolası"), "", true, function (v) { if (v !== "") { uzak.setAnahtar(v); buildAyar(); toast(qsTr("Parola kaydedildi (") + v.length + qsTr(" karakter)")); uzak.pcListesiIste(); } else toast(qsTr("Parola boş, kaydedilmedi")); });
        else if (k === "ad") ask(qsTr("Telefon adı"), uzak.telefonAdi, false, function (v) { uzak.setTelefonAdi(v); buildAyar(); });
        else if (k === "kip") menu.open(qsTr("Gönderim kipi"), [{ k: "paket", t: qsTr("Paket — tuşlar 1 sn sonra toplu (yavaş ağ)") }, { k: "akis", t: qsTr("Akış — her tuş anında (Wi-Fi)") }], function (c) { uzak.setKip(c); buildAyar(); });
        else if (k === "fps") menu.open(qsTr("Kare hızı"), [{ k: 1, t: qsTr("1 kare/sn (önerilen)") }, { k: 2, t: qsTr("2 kare/sn") }, { k: 3, t: qsTr("3 kare/sn") }, { k: 5, t: qsTr("5 kare/sn (Wi-Fi)") }], function (c) { uzak.setFps(c); buildAyar(); });
        else if (k === "kalite") menu.open(qsTr("Görüntü kalitesi"), [{ k: 25, t: qsTr("Düşük (%25, en hızlı)") }, { k: 35, t: qsTr("Orta (%35, önerilen)") }, { k: 50, t: qsTr("İyi (%50)") }, { k: 70, t: qsTr("Yüksek (%70)") }], function (c) { uzak.setKalite(c); buildAyar(); });
        else if (k === "genislik") menu.open(qsTr("Görüntü genişliği"), [{ k: 480, t: qsTr("480 px (en hızlı)") }, { k: 640, t: qsTr("640 px (ekran, önerilen)") }, { k: 800, t: qsTr("800 px (yakınlaştırmada net)") }, { k: 1024, t: qsTr("1024 px") }], function (c) { uzak.setGenislik(c); buildAyar(); });
        else if (k === "oto") { uzak.setOtoYazi(!uzak.otoYazi); buildAyar(); }
        else if (k === "lang") { app.dilDegistir(); buildAyar(); }
        else if (k === "depo") { depo.sec(depo.sonraki()); buildAyar(); }
        else if (k === "ip") bilgi(qsTr("Telefonun adresi"), uzak.telefonIp());
        else if (k === "log") bilgi(qsTr("Günlük"), uzak.gunlukMetni());
        else if (k === "rapor") { uzak.raporGonder(); toast(qsTr("Rapor gönderiliyor…")); }
    }
    function ayarKapat() { ekran = uzak.durum === 2 ? 1 : 0; if (ekran === 0) buildHome(); odak(); }
    Item {
        anchors.fill: parent
        visible: app.ekran === 2
        Rectangle {
            id: ayarHeader
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 40; color: app.surface
            Text { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter } text: qsTr("Ayarlar"); color: app.textPrimary; font.pixelSize: 20; font.bold: true }
            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
        }
        ListView {
            id: ayarList
            anchors { left: parent.left; right: parent.right; top: ayarHeader.bottom; bottom: ayarBar.top }
            clip: true; model: ayarModel
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            delegate: Item {
                width: ayarList.width; height: 50
                property bool cur: ListView.isCurrentItem && ayarList.activeFocus
                Rectangle { anchors.fill: parent; color: ama.pressed ? "#232B33" : (parent.cur ? app.highlight : "transparent") }
                Rectangle { visible: parent.cur; anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 4; color: app.accent }
                Column {
                    anchors { left: parent.left; leftMargin: 14; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    Text { text: t; color: app.textPrimary; font.pixelSize: 16; elide: Text.ElideRight; width: parent.width }
                    Text { text: v; color: app.accent; font.pixelSize: 13; elide: Text.ElideRight; width: parent.width }
                }
                Rectangle { anchors { left: parent.left; leftMargin: 14; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
                MouseArea { id: ama; anchors.fill: parent; onClicked: { ayarList.currentIndex = index; app.ayarSec(index); } }
            }
            Keys.onPressed: {
                var k = event.key;
                if (k === Qt.Key_Down) { currentIndex = (currentIndex + 1) % ayarModel.count; event.accepted = true; }
                else if (k === Qt.Key_Up) { currentIndex = (currentIndex - 1 + ayarModel.count) % ayarModel.count; event.accepted = true; }
                else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select || k === Qt.Key_Context1) { app.ayarSec(currentIndex); event.accepted = true; }
                else if (k === Qt.Key_Context2 || k === Qt.Key_Escape || k === Qt.Key_Backspace) { app.ayarKapat(); event.accepted = true; }
            }
        }
        Rectangle {
            id: ayarBar
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 30; color: app.surface
            Text { anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter } text: qsTr("Değiştir"); color: app.textPrimary; font.pixelSize: 14
                   MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: app.ayarSec(ayarList.currentIndex) } }
            Text { anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } text: qsTr("Geri"); color: app.textPrimary; font.pixelSize: 14
                   MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: app.ayarKapat() } }
        }
    }

    // =====================================================================
    // Oturum
    // =====================================================================
    function yaziAc(ilk) {
        yaziInput.text = ilk;
        yazi.visible = true;
        yaziInput.cursorPosition = yaziInput.text.length;
        yaziInput.forceActiveFocus();
    }
    function yaziGonder(enter) {
        yaziInput.focus = false; app.forceActiveFocus();      // son sözcüğü kutuya işlet
        var t = yaziInput.text.replace(/\r/g, "");
        yazi.visible = false; odak();
        if (t === "" && !enter) return;
        if (t === "") uzak.tus("enter"); else uzak.yaz(t, enter);
    }
    function kisayollar() {
        menu.open(qsTr("Kısayollar"), [
            { k: "ctrl+c", t: qsTr("Kopyala  (Ctrl+C)") }, { k: "ctrl+v", t: qsTr("Yapıştır  (Ctrl+V)") }, { k: "ctrl+x", t: qsTr("Kes  (Ctrl+X)") },
            { k: "ctrl+z", t: qsTr("Geri al  (Ctrl+Z)") }, { k: "ctrl+y", t: qsTr("Yinele  (Ctrl+Y)") }, { k: "ctrl+a", t: qsTr("Tümünü seç  (Ctrl+A)") },
            { k: "ctrl+s", t: qsTr("Kaydet  (Ctrl+S)") }, { k: "ctrl+f", t: qsTr("Bul  (Ctrl+F)") },
            { k: "alt+tab", t: qsTr("Pencere değiştir  (Alt+Tab)") }, { k: "alt+f4", t: qsTr("Pencereyi kapat  (Alt+F4)") },
            { k: "win", t: qsTr("Başlat menüsü  (Win)") }, { k: "win+d", t: qsTr("Masaüstünü göster  (Win+D)") }, { k: "win+e", t: qsTr("Dosya gezgini  (Win+E)") },
            { k: "win+r", t: qsTr("Çalıştır  (Win+R)") }, { k: "win+l", t: qsTr("Bilgisayarı kilitle  (Win+L)") },
            { k: "ctrl+shift+esc", t: qsTr("Görev yöneticisi") },
            { k: "enter", t: qsTr("Enter") }, { k: "esc", t: qsTr("Esc") }, { k: "tab", t: qsTr("Tab") }, { k: "shift+tab", t: qsTr("Shift+Tab") },
            { k: "delete", t: qsTr("Delete") }, { k: "home", t: qsTr("Home") }, { k: "end", t: qsTr("End") }, { k: "pgup", t: qsTr("Sayfa yukarı") }, { k: "pgdn", t: qsTr("Sayfa aşağı") },
            { k: "up", t: qsTr("Yukarı ok") }, { k: "down", t: qsTr("Aşağı ok") }, { k: "left", t: qsTr("Sol ok") }, { k: "right", t: qsTr("Sağ ok") },
            { k: "f5", t: qsTr("Yenile  (F5)") }, { k: "f11", t: qsTr("Tam ekran  (F11)") }, { k: "ctrl+t", t: qsTr("Yeni sekme  (Ctrl+T)") }, { k: "ctrl+w", t: qsTr("Sekmeyi kapat  (Ctrl+W)") },
            { k: "ctrl+tab", t: qsTr("Sonraki sekme  (Ctrl+Tab)") },
            { k: "volup", t: qsTr("Ses +") }, { k: "voldown", t: qsTr("Ses −") }, { k: "mute", t: qsTr("Sessiz") },
            { k: "play", t: qsTr("Oynat / duraklat") }, { k: "next", t: qsTr("Sonraki parça") }, { k: "prev", t: qsTr("Önceki parça") }
        ], function (c) { uzak.tus(c); });
    }
    function fareMenu() {
        menu.open(qsTr("Fare"), [
            { k: "L", t: qsTr("Sol tık") }, { k: "R", t: qsTr("Sağ tık") }, { k: "2", t: qsTr("Çift tık") }, { k: "M", t: qsTr("Orta tık") },
            { k: "D", t: qsTr("Sürüklemeyi başlat (sol tuşa bas)") }, { k: "U", t: qsTr("Sürüklemeyi bitir (bırak)") },
            { k: "w+", t: qsTr("Tekerlek yukarı") }, { k: "w-", t: qsTr("Tekerlek aşağı") }, { k: "w++", t: qsTr("Tekerlek yukarı ×5") }, { k: "w--", t: qsTr("Tekerlek aşağı ×5") }
        ], function (c) {
            if (c === "w+") uzak.tekerlek(3); else if (c === "w-") uzak.tekerlek(-3);
            else if (c === "w++") uzak.tekerlek(15); else if (c === "w--") uzak.tekerlek(-15);
            else uzak.tikla(c);
        });
    }
    function goruntuMenu() {
        menu.open(qsTr("Görüntü  •  ") + uzak.kaynakAdi, [
            { k: "masaustu", t: qsTr("Tüm masaüstü") }, { k: "pencere", t: qsTr("Pencere seç…") },
            { k: "z+", t: qsTr("Yakınlaştır (şimdi ×") + uzak.zoom + ")" }, { k: "z-", t: qsTr("Uzaklaştır") }, { k: "z0", t: qsTr("Tamamını göster") }, { k: "genel", t: qsTr("Genel bakış: tüm ekrandan bölge seç (C)") },
            { k: "f", t: qsTr("Ekranı yenile") }
        ], function (c) {
            if (c === "masaustu") uzak.kaynakSec("masaustu");
            else if (c === "pencere") { uzak.pencereListesiIste(); toast(qsTr("Pencereler alınıyor…")); }
            else if (c === "z+") uzak.yakinlas(1); else if (c === "z-") uzak.yakinlas(-1); else if (c === "z0") uzak.yakinlas(0);
            else if (c === "genel") uzak.genelAc();
            else if (c === "f") uzak.yenile();
        });
    }
    function hizMenu() {
        menu.open(qsTr("Hız"), [
            { k: "paket", t: (uzak.kip === "paket" ? "● " : "") + qsTr("Paket kipi (1 sn sonra toplu)") },
            { k: "akis", t: (uzak.kip === "akis" ? "● " : "") + qsTr("Akış kipi (anında)") },
            { k: "f1", t: (uzak.fps === 1 ? "● " : "") + qsTr("1 kare/sn") }, { k: "f2", t: (uzak.fps === 2 ? "● " : "") + qsTr("2 kare/sn") }, { k: "f5", t: (uzak.fps === 5 ? "● " : "") + qsTr("5 kare/sn") },
            { k: "q25", t: (uzak.kalite === 25 ? "● " : "") + qsTr("Kalite düşük") }, { k: "q35", t: (uzak.kalite === 35 ? "● " : "") + qsTr("Kalite orta") }, { k: "q55", t: (uzak.kalite === 55 ? "● " : "") + qsTr("Kalite iyi") },
            { k: "g480", t: (uzak.genislik === 480 ? "● " : "") + qsTr("Genişlik 480") }, { k: "g640", t: (uzak.genislik === 640 ? "● " : "") + qsTr("Genişlik 640") }, { k: "g800", t: (uzak.genislik === 800 ? "● " : "") + qsTr("Genişlik 800") }
        ], function (c) {
            if (c === "paket" || c === "akis") uzak.setKip(c);
            else if (c.charAt(0) === "f") uzak.setFps(parseInt(c.substring(1), 10));
            else if (c.charAt(0) === "q") uzak.setKalite(parseInt(c.substring(1), 10));
            else if (c.charAt(0) === "g") uzak.setGenislik(parseInt(c.substring(1), 10));
        });
    }
    function secenekler() {
        var items = [];
        if (uzak.tarayici) {
            items.push({ k: "t_adres", t: qsTr("Adres / ara…") });
            if (uzak.geriVar) items.push({ k: "t_geri", t: qsTr("Geri") });
            if (uzak.ileriVar) items.push({ k: "t_ileri", t: qsTr("İleri") });
            items.push({ k: "t_yenile", t: uzak.yukleniyor ? qsTr("Durdur") : qsTr("Yenile") });
            items.push({ k: "t_ana", t: qsTr("Ana sayfa (DuckDuckGo)") });
            items.push({ k: "t_fav", t: qsTr("Sık kullanılanlar") + (uzak.adres !== "" && !app.favoride ? qsTr(" / bu sayfayı ekle") : "") });
            items.push({ k: "t_end", t: qsTr("Sayfa sonuna in (End)  •  başına çık: Home") });
            items.push({ k: "t_gor", t: qsTr("Sayfa görünümü: ") + (uzak.gorunumOlcek < 1.1 ? qsTr("Mobil") : (uzak.gorunumOlcek < 1.9 ? qsTr("Normal (1100 px)") : qsTr("Geniş"))) + " ›" });
        }
        if (uzak.bekleyen > 0) items.push({ k: "gonder", t: qsTr("Bekleyen ") + uzak.bekleyen + qsTr(" girdiyi şimdi gönder") });
        items.push({ k: "kip", t: uzak.kip === "akis" ? qsTr("Gönderim: LAN (anlık)  →  Sunucu (paket) yap") : qsTr("Gönderim: Sunucu (paket)  →  LAN (anlık) yap") });
        items.push({ k: "yazi", t: qsTr("Yazı yaz…") });
        items.push({ k: "kis", t: qsTr("Kısayollar ›") });
        items.push({ k: "fare", t: qsTr("Fare ›") });
        items.push({ k: "gor", t: qsTr("Görüntü / pencere / yakınlaştır ›") });
        items.push({ k: "hiz", t: qsTr("Hız ve kalite ›") });
        items.push({ k: "cubuk", t: app.durumCubugu ? qsTr("Durum çubuğunu gizle") : qsTr("Durum çubuğunu göster") });
        items.push({ k: "ayar", t: qsTr("Ayarlar") });
        items.push({ k: "kilavuz", t: qsTr("Kullanım kılavuzu") });
        items.push({ k: "arka", t: qsTr("Arka plana al (bağlı kalır)") });
        items.push({ k: "kes", t: qsTr("Bağlantıyı kes") });
        menu.open(uzak.pcAdi + "  •  " + uzak.yol, items, function (c) {
            if (c === "t_adres") app.adresSor();
            else if (c === "t_geri") uzak.tarayiciKomut("geri");
            else if (c === "t_ileri") uzak.tarayiciKomut("ileri");
            else if (c === "t_yenile") uzak.tarayiciKomut(uzak.yukleniyor ? "dur" : "yenile");
            else if (c === "t_ana") uzak.tarayiciKomut("ana");
            else if (c === "t_fav") app.favoriMenu();
            else if (c === "t_end") uzak.tus("end");
            else if (c === "t_gor") menu.open(qsTr("Sayfa görünümü"), [
                    { k: "1", t: qsTr("Mobil — siteler telefon düzeninde, yazı büyük") },
                    { k: "1.72", t: qsTr("Normal — 1100 px masaüstü düzeni") },
                    { k: "2", t: qsTr("Geniş — 1280 px, yazı küçük (S ile yakınlaştır)") }
                ], function (g) { uzak.setGorunumOlcek(parseFloat(g)); });
            else if (c === "gonder") uzak.simdiGonder();
            else if (c === "kip") { uzak.setKip(uzak.kip === "akis" ? "paket" : "akis"); app.toast(uzak.kip === "akis" ? qsTr("LAN (anlık): her tuş hemen gider") : qsTr("Sunucu (paket): tuşlar 1 sn sonra toplu gider")); }
            else if (c === "kilavuz") app.kilavuz();
            else if (c === "yazi") app.yaziAc("");
            else if (c === "kis") app.kisayollar();
            else if (c === "fare") app.fareMenu();
            else if (c === "gor") app.goruntuMenu();
            else if (c === "hiz") app.hizMenu();
            else if (c === "cubuk") app.durumCubugu = !app.durumCubugu;
            else if (c === "ayar") { app.ekran = 2; app.buildAyar(); app.odak(); }
            else if (c === "arka") uzak.arkaPlanaAl();
            else if (c === "kes") uzak.kes();
        });
    }
    // ---- Sik kullanilanlar ----
    property bool favoride: false
    function favoriKontrol() {
        var l = uzak.favoriler(), f = false;
        for (var i = 0; i < l.length; i++) if (l[i].adres === uzak.adres) f = true;
        favoride = f;
    }
    function favoriMenu() {
        var l = uzak.favoriler();
        var items = [];
        if (uzak.adres !== "" && !favoride) items.push({ k: "ekle", t: qsTr("Bu sayfayı sık kullanılanlara ekle") });
        for (var i = 0; i < l.length; i++) items.push({ k: "f" + i, t: l[i].baslik + "  —  " + l[i].adres.replace(/^https?:\/\/(www\.)?/, "") });
        if (l.length) items.push({ k: "duzen", t: qsTr("Sık kullanılanı sil…") });
        if (!items.length) { toast(qsTr("Sık kullanılan yok")); return; }
        menu.open(qsTr("Sık kullanılanlar"), items, function (c) {
            if (c === "ekle") { if (uzak.favoriEkle(uzak.adres, uzak.baslik)) toast(qsTr("Eklendi: ") + (uzak.baslik || uzak.adres)); app.favoriKontrol(); }
            else if (c === "duzen") app.favoriSilMenu();
            else if (c.charAt(0) === "f") uzak.git(l[parseInt(c.substring(1), 10)].adres);
        });
    }
    function favoriSilMenu() {
        var l = uzak.favoriler(), items = [];
        for (var i = 0; i < l.length; i++) items.push({ k: "s" + i, t: qsTr("Sil: ") + l[i].baslik });
        menu.open(qsTr("Silinecek sık kullanılan"), items, function (c) { uzak.favoriSil(parseInt(c.substring(1), 10)); toast(qsTr("Silindi")); app.favoriKontrol(); });
    }
    Connections { target: uzak; onAdresChanged: app.favoriKontrol() }
    // ---- Sunucu tarayicisi ----
    function adresSor() {
        ask(qsTr("Adres ya da arama"), uzak.adres, false, function (v) { if (v.replace(/\s+/g, "") !== "") uzak.git(v); });
        askAdres = true;
    }
    function boyutYaz(b) {
        if (b >= 1048576) return (b / 1048576).toFixed(1) + qsTr(" MB");
        if (b >= 1024) return Math.round(b / 1024) + qsTr(" KB");
        return b + " B";
    }
    Connections {
        target: uzak
        onIndirmeHazir: {
            var iid = id, iad = ad;
            menu.open(qsTr("İndirme hazır: ") + ad + " (" + app.boyutYaz(boyut) + ")", [
                { k: "tel", t: qsTr("Telefona indir (E:/Downloads)") },
                { k: "drive", t: qsTr("Drive'a yükle (Belle Remote klasörü)") },
                { k: "sil", t: qsTr("Sunucudan sil") },
                { k: "sonra", t: qsTr("Sonra (24 saat sunucuda kalır)") }
            ], function (c) {
                if (c === "tel") uzak.telefonaIndir(iid, iad);
                else if (c === "drive") uzak.indirmeIslem(iid, "drive");
                else if (c === "sil") uzak.indirmeIslem(iid, "sil");
            });
        }
        onIndirmeBitti: app.toast(mesaj)
    }
    function kilavuz() {
        bilgi(qsTr("Kullanım kılavuzu"),
              qsTr("EKRAN AÇIKKEN (tuşlar doğrudan kısayoldur)\n") +
              qsTr("• Yön tuşları: imleci taşı (basılı tutunca hızlanır)\n") +
              qsTr("• İmleç kenara dayanıp itilince: yakınlaştırmada görüntü o yöne kayar; tam görünümde sayfa kaydırılır\n") +
              qsTr("• Orta tuş kısa: sol tık  •  basılı tut: sağ tık\n") +
              qsTr("• Enter bir kez: yazı penceresi  •  Enter iki kez hızlıca: PC'de Enter\n") +
              qsTr("• Boşluk: pencere seçimi (paylaşılacak pencere / tüm masaüstü)\n") +
              qsTr("• T: tekerlek yukarı  •  B: tekerlek aşağı\n") +
              qsTr("• F: sayfayı sola kaydır  •  H: sağa kaydır\n") +
              qsTr("• S: yakınlaştır 2x / geri 1x\n") +
              qsTr("• Yakınlaştırmadayken: A sol, D sağ, W yukarı, X aşağı\n") +
              qsTr("• I J K L: yön okları (yukarı, sol, aşağı, sağ) — tarayıcıda sayfayı kaydırır\n") +
              qsTr("• Silme tuşu: PC'de Backspace  •  Ctrl+harf: PC'de Ctrl+harf (Ctrl+C, Ctrl+V…)\n• G (ya da K): kısayollar menüsü  (Ctrl tuşunu telefon uygulamalara iletmiyor)\n") +
              qsTr("• Peş peşe basılan tuşlar paketlenir; bırakınca 1 sn sonra hepsi sırayla gider (paket kipi)\n\n") +
              qsTr("DOKUNMATİK\n") +
              qsTr("• Dokun: sol tık  •  basılı tut: sağ tık  •  sürükle: imleci taşı\n• Yakınlaştırmada parmağı kenara sürükleyip tutunca görüntü o yöne kayar\n\n") +
              qsTr("YAZI PENCERESİ\n") +
              qsTr("• Enter: gönder  •  Ctrl+Enter: gönder ve Enter'a bas  •  Shift+Enter: yeni satır\n") +
              qsTr("• Ctrl+V / Yapıştır: telefon panosundan\n") +
              qsTr("• PC'de yazı kutusu etkinleşince kendiliğinden açılması varsayılan kapalı (Ayarlar'dan açılabilir)\n\n") +
              qsTr("MENÜLER\n") +
              qsTr("• Sol yazılım tuşu: Seçenekler  •  sağ yazılım tuşu: Geri\n") +
              qsTr("• Menüde sol yön tuşu: bir önceki menüye dön (ilk menüde kapatır)\n") +
              qsTr("• Seçenekler ilk satır: Gönderim LAN (anlık) ↔ Sunucu (paket)\n") +
              qsTr("• Kısayollar: Ctrl+C/V/X/Z, Alt+Tab, Alt+F4, Win, Win+D, Win+E, Win+L, görev yöneticisi, ses ve medya tuşları…\n\n") +
              qsTr("SUNUCU TARAYICISI\n") +
              qsTr("• Ana ekranda 'Sunucu Tarayıcı': sunucudaki Chrome tek sayfada açılır, tüm siteler çalışır\n") +
              qsTr("• Boşluk ya da Seçenekler > Adres / ara: adres ya da arama yaz\n") +
              qsTr("• Seçenekler: Geri, İleri, Yenile/Durdur, Ana sayfa • fare, tekerlek, yazı ve kısayollar masaüstündeki gibi\n") +
              qsTr("• Bir dosya inince sorulur: Telefona indir (E:/Downloads) ya da Drive'a yükle (Belle Remote klasörü)\n") +
              qsTr("• Çerezler sunucuda kalır; girdiğin sitelerde oturumun açık kalır\n\n") +
              qsTr("BAĞLANTI\n") +
              qsTr("• Kayıtlı PC'yi seçince önce sunucudan PC'nin o anki adresi sorulur; telefon PC ile aynı ağdaysa yerel ağdan (hızlı), değilse sunucudan bağlanır. Ev ve dükkan gibi farklı Wi-Fi'lerde kendiliğinden doğru yolu seçer.\n") +
              qsTr("• Mobil veri kapalıysa uygulama internet bağlantısını kendisi açtırır.\n") +
              qsTr("• Yerel ağ için PC uygulamasında 'Güvenlik duvarı izni' bir kez verilmelidir.\n") +
              qsTr("• Not: PC'de yönetici olarak açılmış pencerelere (ör. yönetici PowerShell) Windows tuş gönderilmesine izin vermez."));
    }
    function geriMenu() {
        menu.open(qsTr("Geri"), [
            { k: "arka", t: qsTr("Arka plana al (bağlı kalır)") },
            { k: "esc", t: qsTr("PC'ye Esc gönder") },
            { k: "kes", t: qsTr("Bağlantıyı kes") }
        ], function (c) {
            if (c === "arka") uzak.arkaPlanaAl(); else if (c === "esc") uzak.tus("esc"); else if (c === "kes") uzak.kes();
        });
    }

    Item {
        id: oturum
        anchors.fill: parent
        visible: app.ekran === 1
        property int tekrar: 0

        Rectangle {
            id: ustCubuk
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: uzak.tarayici ? 40 : (app.durumCubugu ? 22 : 0); visible: uzak.tarayici || app.durumCubugu; color: uzak.tarayici ? app.surface : "#141A20"
            // ---- Tarayici cubugu: geri, ileri, yenile/durdur, adres, yildiz ----
            Row {
                visible: uzak.tarayici
                anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                spacing: 2
                Repeater {
                    model: ["geri", "ileri", "yenile"]
                    delegate: Rectangle {
                        width: 38; height: 32; radius: 6
                        property bool aktif: modelData === "geri" ? uzak.geriVar : (modelData === "ileri" ? uzak.ileriVar : true)
                        color: tbMa.pressed ? app.highlight : "transparent"
                        // simgeler resim: telefonun yazi tipinde ok isaretleri yok (dikdortgen gorunuyordu)
                        Image {
                            anchors.centerIn: parent; width: 24; height: 24; smooth: true
                            source: "../images/" + (modelData === "yenile" && uzak.yukleniyor ? "dur" : modelData) + ".png"
                            opacity: parent.aktif ? 1 : 0.3
                        }
                        MouseArea {
                            id: tbMa; anchors.fill: parent; enabled: parent.aktif
                            onClicked: uzak.tarayiciKomut(modelData === "yenile" && uzak.yukleniyor ? "dur" : modelData)
                        }
                    }
                }
            }
            Rectangle {
                visible: uzak.tarayici
                anchors { left: parent.left; leftMargin: 126; right: yildiz.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                height: 30; radius: 15; color: "#252E37"
                Rectangle {   // yukleme cizgisi
                    visible: uzak.yukleniyor
                    anchors { left: parent.left; bottom: parent.bottom; leftMargin: 12; rightMargin: 12 }
                    height: 2; color: app.accent
                    width: (parent.width - 24) * 0.6
                    SequentialAnimation on opacity { running: uzak.yukleniyor; loops: Animation.Infinite; NumberAnimation { to: 0.2; duration: 500 } NumberAnimation { to: 1; duration: 500 } }
                }
                Text {
                    anchors { left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    text: uzak.adres !== "" ? uzak.adres.replace(/^https?:\/\/(www\.)?/, "").replace(/\/$/, "") : qsTr("Adres ya da arama")
                    color: uzak.adres !== "" ? app.textPrimary : app.textSecondary; font.pixelSize: 14; elide: Text.ElideRight
                }
                MouseArea { anchors.fill: parent; onClicked: app.adresSor() }
            }
            Rectangle {
                id: yildiz
                visible: uzak.tarayici
                anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                width: 38; height: 32; radius: 6
                color: ylMa.pressed ? app.highlight : "transparent"
                Image { anchors.centerIn: parent; width: 24; height: 24; smooth: true; source: app.favoride ? "../images/yildiz_dolu.png" : "../images/yildiz_bos.png" }
                MouseArea { id: ylMa; anchors.fill: parent; onClicked: app.favoriMenu() }
            }
            Text {
                visible: !uzak.tarayici
                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                text: uzak.tarayici ? ((uzak.yukleniyor ? "… " : "") + (uzak.baslik !== "" ? uzak.baslik + "  •  " : "") + uzak.adres)
                                    : (uzak.pcAdi + "  •  " + uzak.yol + "  •  " + uzak.kaynakAdi + (uzak.zoom > 1 ? "  •  ×" + uzak.zoom : ""))
                color: app.textSecondary; font.pixelSize: 12; width: 400; elide: Text.ElideRight
            }
            Text {
                visible: !uzak.tarayici
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                text: (uzak.kip === "akis" ? qsTr("akış") : "paket") + "  " + uzak.kbps.toFixed(1) + qsTr(" KB/s") + (uzak.ping >= 0 ? "  " + uzak.ping + qsTr(" ms") : "")
                color: app.textSecondary; font.pixelSize: 12
            }
        }

        Item {
            id: alan
            anchors { left: parent.left; right: parent.right; top: ustCubuk.bottom; bottom: altCubuk.top }
            // tarayicida sunucu penceresi bu alanin oranina gore acilir (tam ekran, kenar boslugu yok)
            onWidthChanged: uzak.setAlan(width, height)
            onHeightChanged: uzak.setAlan(width, height)
            Component.onCompleted: uzak.setAlan(width, height)
            clip: true
            Image {
                id: goruntu
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                cache: false; smooth: true; asynchronous: false
                source: uzak.kareNo > 0 ? "image://ekran/" + uzak.kareNo : ""
            }
            Text {
                anchors.centerIn: parent; visible: uzak.kareNo === 0
                text: qsTr("Ekran bekleniyor…"); color: app.textSecondary; font.pixelSize: 18
            }
            // Görüntünün ekrandaki gerçek dikdörtgeni
            property real pw: goruntu.paintedWidth > 0 ? goruntu.paintedWidth : width
            property real ph: goruntu.paintedHeight > 0 ? goruntu.paintedHeight : height
            property real ox: (width - pw) / 2
            property real oy: (height - ph) / 2
            function vx(x) { return (x - ox) / pw; }
            function vy(y) { return (y - oy) / ph; }

            // Telefondaki imleç (paket kipinde gerçek imlecin önünde gider)
            Item {
                id: imlec
                x: alan.ox + (uzak.imlecX - uzak.zx1) / (uzak.zx2 - uzak.zx1) * alan.pw
                y: alan.oy + (uzak.imlecY - uzak.zy1) / (uzak.zy2 - uzak.zy1) * alan.ph
                width: 1; height: 1
                Rectangle { x: -9; y: -1; width: 19; height: 3; color: "#000000"; opacity: 0.6 }
                Rectangle { x: -1; y: -9; width: 3; height: 19; color: "#000000"; opacity: 0.6 }
                Rectangle { x: -8; y: 0; width: 17; height: 1; color: uzak.bekleyen > 0 ? app.warn : app.accent }
                Rectangle { x: 0; y: -8; width: 1; height: 17; color: uzak.bekleyen > 0 ? app.warn : app.accent }
                Rectangle { x: -4; y: -4; width: 9; height: 9; radius: 4.5; color: "transparent"; border.width: 2; border.color: uzak.bekleyen > 0 ? app.warn : app.accent }
            }

            MouseArea {
                anchors.fill: parent
                property real bx: 0
                property real by: 0
                property bool surukle: false
                property bool tutuldu: false
                // Yakınlaştırmada parmak kenara gelince görüntü o yöne kayar (basılı tuttukça devam eder)
                property int kx: 0
                property int ky: 0
                onPressed: { bx = mouse.x; by = mouse.y; surukle = false; tutuldu = false; kx = 0; ky = 0; oturum.forceActiveFocus(); }
                onPositionChanged: {
                    if (!surukle && Math.abs(mouse.x - bx) + Math.abs(mouse.y - by) > 18) surukle = true;
                    if (!surukle) return;
                    uzak.imlecGorunumde(alan.vx(mouse.x), alan.vy(mouse.y));
                    var pay = 0.12;
                    var vx = alan.vx(mouse.x), vy = alan.vy(mouse.y);
                    kx = vx < pay ? -1 : (vx > 1 - pay ? 1 : 0);
                    ky = vy < pay ? -1 : (vy > 1 - pay ? 1 : 0);
                    if (uzak.zoom > 1.01 && (kx || ky)) { if (!kenarTimer.running) { uzak.kaydir(kx, ky); kenarTimer.start(); } }
                    else kenarTimer.stop();
                }
                onCanceled: kenarTimer.stop()
                Timer { id: kenarTimer; interval: 450; repeat: true; onTriggered: { if (uzak.zoom > 1.01 && (parent.kx || parent.ky)) uzak.kaydir(parent.kx, parent.ky); else stop(); } }
                onPressAndHold: { if (surukle) return; tutuldu = true; uzak.imlecGorunumde(alan.vx(mouse.x), alan.vy(mouse.y)); uzak.tikla("R"); app.toast(qsTr("Sağ tık")); }
                onReleased: {
                    kenarTimer.stop();
                    if (tutuldu) return;
                    uzak.imlecGorunumde(alan.vx(mouse.x), alan.vy(mouse.y));
                    if (surukle) uzak.tasi(0, 0);          // yalnızca imleci götür
                    else uzak.tikla("L");
                }
            }
        }

        // ---- Genel bakis (C): tum ekran kucuk; dokun / surukle -> yakinlastirma bolgesi oraya isinlanir ----
        Rectangle {
            id: genelKatman
            anchors.fill: alan
            visible: uzak.genel
            color: "#000000"
            z: 5
            Image {
                id: genelResim
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                cache: false; smooth: true
                source: uzak.genel && uzak.kareNo > 0 ? "image://ekran/" + uzak.kareNo : ""
            }
            property real pw: genelResim.paintedWidth > 0 ? genelResim.paintedWidth : width
            property real ph: genelResim.paintedHeight > 0 ? genelResim.paintedHeight : height
            property real ox: (width - pw) / 2
            property real oy: (height - ph) / 2
            // secili bolge cercevesi
            Rectangle {
                x: genelKatman.ox + uzak.zx1 / 10000 * genelKatman.pw
                y: genelKatman.oy + uzak.zy1 / 10000 * genelKatman.ph
                width: (uzak.zx2 - uzak.zx1) / 10000 * genelKatman.pw
                height: (uzak.zy2 - uzak.zy1) / 10000 * genelKatman.ph
                color: "#3300BFA5"
                border.width: 3; border.color: "#00E5C0"
                visible: uzak.zoom > 1.01 || genelMa.pressed
            }
            Rectangle {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 6 }
                width: genelIpucu.paintedWidth + 20; height: genelIpucu.paintedHeight + 10; radius: 6
                color: "#CC000000"
                Text { id: genelIpucu; anchors.centerIn: parent; color: "white"; font.pixelSize: 14
                       text: genelResim.status === Image.Ready ? qsTr("Dokunun ya da sürükleyin: görünüm oraya gider • C: kapat") : qsTr("Tüm ekran alınıyor…") }
            }
            MouseArea {
                id: genelMa
                anchors.fill: parent
                function vx(x) { return Math.max(0, Math.min(1, (x - genelKatman.ox) / genelKatman.pw)); }
                function vy(y) { return Math.max(0, Math.min(1, (y - genelKatman.oy) / genelKatman.ph)); }
                onPressed: uzak.genelSec(vx(mouse.x), vy(mouse.y), false)
                onPositionChanged: uzak.genelSec(vx(mouse.x), vy(mouse.y), false)
                onReleased: uzak.genelSec(vx(mouse.x), vy(mouse.y), true)
            }
        }

        Rectangle {
            id: altCubuk
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 30; color: app.surface
            Text { anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter } text: qsTr("Seçenekler"); color: app.textPrimary; font.pixelSize: 14
                   MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: app.secenekler() } }
            Row {
                anchors.centerIn: parent; spacing: 8
                Rectangle {
                    width: 10; height: 10; radius: 5; anchors.verticalCenter: parent.verticalCenter
                    color: uzak.bekleyen > 0 ? app.warn : (uzak.gonderiliyor ? "#4FA3E0" : app.accent)
                }
                Text {
                    text: uzak.indirmeYuzde >= 0 ? (qsTr("İndiriliyor %") + uzak.indirmeYuzde + "  " + uzak.indirmeAd) : uzak.bekleyen > 0 ? (uzak.bekleyen + qsTr(" girdi • bırakınca 1 sn sonra gider"))
                          : (uzak.gonderiliyor ? qsTr("Gönderildi, ekran bekleniyor…") : qsTr("Hazır"))
                    color: app.textSecondary; font.pixelSize: 12
                }
            }
            Text { anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } text: qsTr("Geri"); color: app.textPrimary; font.pixelSize: 14
                   MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: app.geriMenu() } }
        }

        Timer { id: tutTimer; interval: 600; onTriggered: { uzak.tikla("R"); app.toast(qsTr("Sağ tık")); } }
        Timer { id: enterTimer; interval: 400; onTriggered: app.yaziAc("") }

        property bool ctrlYalniz: false
        Keys.onPressed: {
            var k = event.key, ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
            // Ctrl tek başına basılıp bırakılırsa kısayollar menüsü (Ctrl+harf birleşimleri yine çalışır)
            if (k !== Qt.Key_Left && k !== Qt.Key_Right && k !== Qt.Key_Up && k !== Qt.Key_Down)
                uzak.logla(qsTr("bas key=") + k + qsTr(" text=") + (event.text ? event.text.charCodeAt(0) : "-") + qsTr(" mod=") + event.modifiers);
            // Ctrl: uygulamada kısayollar menüsünü açar (PC'ye gönderilmez)
            if (k === Qt.Key_Control || k === Qt.Key_Meta) { if (!event.isAutoRepeat) app.kisayollar(); event.accepted = true; return; }
            // Symbian Ctrl+harf'i değiştirici olarak değil denetim karakteri olarak verir (Ctrl+A=1 … Ctrl+Z=26)
            if (event.text && event.text.length === 1) {
                var dk = event.text.charCodeAt(0);
                if (dk >= 1 && dk <= 26 && k !== Qt.Key_Backspace && k !== Qt.Key_Tab && k !== Qt.Key_Return && k !== Qt.Key_Enter && k !== Qt.Key_Select) {
                    uzak.tus("ctrl+" + String.fromCharCode(dk + 96));
                    app.toast(qsTr("Ctrl+") + String.fromCharCode(dk + 64));
                    event.accepted = true; return;
                }
            }
            ctrlYalniz = false;
            if (k === Qt.Key_Left || k === Qt.Key_Right || k === Qt.Key_Up || k === Qt.Key_Down) {
                tekrar = event.isAutoRepeat ? tekrar + 1 : 0;
                var st = Math.min(120 + tekrar * 45, 900);       // basılı tutunca hızlanır
                var dx = k === Qt.Key_Left ? -st : (k === Qt.Key_Right ? st : 0);
                var dy = k === Qt.Key_Up ? -st : (k === Qt.Key_Down ? st : 0);
                uzak.tasi(dx, dy);
                event.accepted = true;
            }
            else if (k === Qt.Key_Select) { if (!event.isAutoRepeat) tutTimer.restart(); event.accepted = true; }
            else if (k === Qt.Key_Context1) { app.secenekler(); event.accepted = true; }
            else if (k === Qt.Key_Context2 || k === Qt.Key_Escape) { app.geriMenu(); event.accepted = true; }
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || event.text === "\r" || event.text === "\n") {
                // Enter bir kez: yazı penceresi; hızlıca iki kez: PC'de Enter
                if (!event.isAutoRepeat) {
                    if (enterTimer.running) { enterTimer.stop(); uzak.tus(ctrl ? "ctrl+enter" : "enter"); app.toast(qsTr("Enter")); }
                    else enterTimer.restart();
                }
                event.accepted = true;
            }
            else if (k === Qt.Key_Backspace) { uzak.tus("backspace"); event.accepted = true; }
            else if (k === Qt.Key_Space && !ctrl) { if (uzak.tarayici) app.adresSor(); else { uzak.pencereListesiIste(); app.toast(qsTr("Pencereler alınıyor…")); } event.accepted = true; }
            else if (k === Qt.Key_Tab) { uzak.tus("tab"); event.accepted = true; }
            else if (ctrl && ((k >= Qt.Key_A && k <= Qt.Key_Z) || (k >= 97 && k <= 122))) { uzak.tus("ctrl+" + String.fromCharCode(k).toLowerCase()); event.accepted = true; }
            else {
                // Doğrudan kısayollar (yazmak için Enter)
                // Önce tuşun kendi kodu (Qt.Key_A..Z), yoksa yazdığı metin. E6'da T=2, F=4, H=6, B=8 rakamlarını da taşır.
                var t = "";
                if (k >= Qt.Key_A && k <= Qt.Key_Z) t = String.fromCharCode(k).toLowerCase();
                else {
                    t = (event.text || "").toLowerCase();
                    if (t === "" && k >= Qt.Key_0 && k <= Qt.Key_9) t = String.fromCharCode(k);
                    // Telefon raporundan: T=2, F=4, G=5, H=6, B=8, D=-, X=%, C==
                    var rakam = { "2": "t", "4": "f", "5": "g", "6": "h", "8": "b", "-": "d", "%": "x", "=": "c" };
                    if (rakam[t] !== undefined) t = rakam[t];
                }
                var yak = uzak.zoom > 1.01;
                // I J K L = yön okları (telefon bu tuşlarda Ğ # ş i gönderiyor)
                if (t === "#" || t === "j") uzak.tus("left");
                else if (t === "ş" || t === "k") uzak.tus("down");
                else if (t === "i" || t === "l") uzak.tus("right");
                else if (t === "ğ" || t === "ı") uzak.tus("up");
                else if (t === "b") uzak.tekerlek(-1);       // B aşağı
                else if (t === "t") uzak.tekerlek(1);   // T yukarı
                else if (t === "f") uzak.yatay(-1);
                else if (t === "h") uzak.yatay(1);
                else if (t === "s") uzak.zoomDongu();
                else if (t === "c") { if (uzak.genel) uzak.genelKapat(); else uzak.genelAc(); }
                else if (t === "g" || t === "k") app.kisayollar();      // Ctrl tuşu telefonda uygulamaya iletilmiyor
                else if (t === "a" && yak) uzak.kaydir(-1, 0);
                else if (t === "d" && yak) uzak.kaydir(1, 0);
                else if (t === "w" && yak) uzak.kaydir(0, -1);
                else if (t === "x" && yak) uzak.kaydir(0, 1);
                else if (t !== "" && t.charCodeAt(0) > 32) { uzak.logla(qsTr("tanimsiz tus: key=") + k + qsTr(" text=") + event.text); app.toast("'" + event.text + qsTr("' tuşu tanımsız • yazmak için Enter")); }
                else return;
                event.accepted = true;
            }
        }
        Keys.onReleased: {
            if (event.key === Qt.Key_Control || event.key === Qt.Key_Meta) { event.accepted = true; }
            else if (event.key === Qt.Key_Select && !event.isAutoRepeat) {
                if (tutTimer.running) { tutTimer.stop(); uzak.tikla("L"); }
                event.accepted = true;
            }
        }
    }

    // =====================================================================
    // Yazı penceresi: metin bütün olarak yazılır, onaylanınca tek pakette gider
    // =====================================================================
    Rectangle {
        id: yazi
        anchors.fill: parent; color: "#C0000000"; visible: false; z: 20
        MouseArea { anchors.fill: parent }
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 24; topMargin: 20 }
            height: 250; radius: 12; color: app.surface
            Text { x: 16; y: 10; text: qsTr("Bilgisayara yaz"); color: app.textPrimary; font.pixelSize: 17; font.bold: true }
            Text { anchors { right: parent.right; rightMargin: 16 } y: 13; text: uzak.yaziAlani ? qsTr("PC'de yazı alanı etkin") : ""; color: app.accent; font.pixelSize: 13 }
            Rectangle {
                id: yaziKutu
                x: 16; y: 40; width: parent.width - 32; height: 140; radius: 8; color: "#252E37"; border.width: 2; border.color: app.accent
                Flickable {
                    id: yaziFlick
                    anchors { fill: parent; margins: 8 }
                    clip: true; contentHeight: yaziInput.paintedHeight + 4; contentWidth: width
                    function goster(r) {
                        if (contentY >= r.y) contentY = r.y;
                        else if (contentY + height <= r.y + r.height) contentY = r.y + r.height - height;
                    }
                    TextEdit {
                        id: yaziInput
                        width: yaziFlick.width; wrapMode: TextEdit.Wrap
                        font.pixelSize: 18; color: app.textPrimary
                        inputMethodHints: Qt.ImhNoPredictiveText
                        onCursorRectangleChanged: yaziFlick.goster(cursorRectangle)
                        Keys.onPressed: {
                            // Ctrl+V yapistir / Ctrl+A tumunu sec (E6: Ctrl+V "7" ya da kod 22 gonderir)
                            if (((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_V || event.text === "7" || event.text === "v")) || event.text === "\u0016") { pano.yapistir(yaziInput); event.accepted = true; return; }
                            if (((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_A || event.text === "a")) || event.text === "\u0001") { yaziInput.selectAll(); event.accepted = true; return; }
                            var k = event.key, ctrl = (event.modifiers & Qt.ControlModifier) !== 0, shift = (event.modifiers & Qt.ShiftModifier) !== 0;
                            if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select || event.text === "\r" || event.text === "\n") {
                                if (shift) { yaziInput.text = yaziInput.text.substring(0, cursorPosition) + "\n" + yaziInput.text.substring(cursorPosition); }
                                else app.yaziGonder(ctrl);
                                event.accepted = true;
                            }
                            else if (k === Qt.Key_Escape || k === Qt.Key_Context2) { yazi.visible = false; app.odak(); event.accepted = true; }
                            else if (k === Qt.Key_Context1) { app.yaziMenu(); event.accepted = true; }
                            else if ((ctrl && k === Qt.Key_V) || event.text === "\u0016" || k === Qt.Key_Paste) { app.yaziYapistir(); event.accepted = true; }
                        }
                    }
                }
            }
            Row {
                x: 16; y: 192; spacing: 8
                Repeater {
                    model: [{ k: "gonder", t: qsTr("Gönder") }, { k: "enter", t: qsTr("Gönder + Enter") }, { k: "yap", t: qsTr("Yapıştır") }, { k: "sil", t: qsTr("Temizle") }, { k: "iptal", t: qsTr("İptal") }]
                    delegate: Rectangle {
                        width: bt.paintedWidth + 24; height: 36; radius: 18
                        color: btMa.pressed ? "#33503C" : (modelData.k === "gonder" || modelData.k === "enter" ? "#24402C" : "#252E37")
                        Text { id: bt; anchors.centerIn: parent; text: modelData.t; color: modelData.k === "gonder" || modelData.k === "enter" ? app.accent : app.textPrimary; font.pixelSize: 14 }
                        MouseArea { id: btMa; anchors.fill: parent; onClicked: app.yaziEylem(modelData.k) }
                    }
                }
            }
            Text { anchors { right: parent.right; rightMargin: 16; bottom: parent.bottom; bottomMargin: 6 } text: qsTr("Enter gönder • Ctrl+Enter gönder+Enter • Shift+Enter yeni satır • Ctrl+V yapıştır"); color: app.textSecondary; font.pixelSize: 11 }
        }
    }
    function yaziYapistir() {
        var c = uzak.panoMetni();
        if (c === "") { toast(qsTr("Pano boş")); return; }
        var p = yaziInput.cursorPosition;
        yaziInput.text = yaziInput.text.substring(0, p) + c + yaziInput.text.substring(p);
        yaziInput.cursorPosition = p + c.length;
        yaziInput.forceActiveFocus();
    }
    function yaziEylem(k) {
        if (k === "gonder") yaziGonder(false);
        else if (k === "enter") yaziGonder(true);
        else if (k === "yap") yaziYapistir();
        else if (k === "sil") { yaziInput.text = ""; yaziInput.forceActiveFocus(); }
        else { yazi.visible = false; odak(); }
    }
    function yaziMenu() {
        menu.open(qsTr("Yazı"), [{ k: "gonder", t: qsTr("Gönder") }, { k: "enter", t: qsTr("Gönder ve Enter'a bas") }, { k: "yap", t: qsTr("Telefon panosundan yapıştır") }, { k: "sil", t: qsTr("Temizle") }, { k: "iptal", t: qsTr("İptal") }],
                  function (c) { yaziEylem(c); });
    }

    // =====================================================================
    // Menü (uzun listeler kayar)
    // =====================================================================
    ListModel { id: menuModel }
    Rectangle {
        id: menu
        anchors.fill: parent; color: "#A0000000"; visible: false; z: 30
        property string title: ""
        // Alt menü bir menü seçiminin içinden açılırsa üst menü yığına girer; sol tuş geri götürür
        function open(t, items, f) {
            if (Geri.secimde && Geri.su) { var y = Geri.yigin; y.push(Geri.su); Geri.yigin = y; }
            else if (!Geri.geriDonus) Geri.yigin = [];
            Geri.su = { t: t, items: items, f: f };
            title = t; menuModel.clear();
            for (var i = 0; i < items.length; i++) menuModel.append({ k: "" + items[i].k, t: items[i].t, sayi: typeof items[i].k === "number" });
            Geri.menu = f; visible = true; menuList.currentIndex = 0; menuList.positionViewAtIndex(0, ListView.Beginning); menuList.forceActiveFocus();
        }
        function kapat() { visible = false; Geri.yigin = []; Geri.su = null; app.odak(); }
        function geri() {
            var y = Geri.yigin;
            if (!y.length) { kapat(); return; }
            var ust = y.pop(); Geri.yigin = y;
            Geri.geriDonus = true;
            open(ust.t, ust.items, ust.f);
            Geri.geriDonus = false;
        }
        function choose(i) {
            var it = menuModel.get(i);
            var k = it.sayi ? parseInt(it.k, 10) : it.k;
            var cb = Geri.menu;
            visible = false; app.odak();
            Geri.secimde = true;
            if (cb) cb(k);
            Geri.secimde = false;
            if (!visible) { Geri.yigin = []; Geri.su = null; }
        }
        MouseArea { anchors.fill: parent; onClicked: menu.kapat() }
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 30; bottomMargin: 36 }
            height: Math.min(40 + menuModel.count * 42, app.height - 60); radius: 12; color: app.surface
            MouseArea { anchors.fill: parent }
            Text { x: 16; y: 11; text: menu.title; color: app.textSecondary; font.pixelSize: 14; width: parent.width - 32; elide: Text.ElideRight }
            ListView {
                id: menuList
                anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 38; bottom: parent.bottom; bottomMargin: 4 }
                model: menuModel; clip: true
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                delegate: Item {
                    width: menuList.width; height: 42
                    Rectangle { anchors.fill: parent; color: mma.pressed ? "#232B33" : (parent.ListView.isCurrentItem ? app.highlight : "transparent") }
                    Text { anchors { left: parent.left; leftMargin: 18; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } text: t; color: app.textPrimary; font.pixelSize: 16; elide: Text.ElideRight }
                    MouseArea { id: mma; anchors.fill: parent; onClicked: menu.choose(index) }
                }
                Keys.onPressed: {
                    var k = event.key;
                    if (k === Qt.Key_Down) { currentIndex = (currentIndex + 1) % menuModel.count; event.accepted = true; }
                    else if (k === Qt.Key_Up) { currentIndex = (currentIndex - 1 + menuModel.count) % menuModel.count; event.accepted = true; }
                    else if (k === Qt.Key_Right) { currentIndex = Math.min(menuModel.count - 1, currentIndex + 6); event.accepted = true; }
                    else if (k === Qt.Key_Left) { menu.geri(); event.accepted = true; }
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select || k === Qt.Key_Context1) { menu.choose(currentIndex); event.accepted = true; }
                    else if (k === Qt.Key_Escape || k === Qt.Key_Backspace || k === Qt.Key_Context2) { menu.kapat(); event.accepted = true; }
                }
            }
        }
    }

    // =====================================================================
    // Metin girişi (adres, parola…) — E6'da Enter elle yakalanır, Ctrl+V yapıştırır
    // =====================================================================
    property bool askSecret: false
    property bool askAdres: false           // adres penceresi: Temizle ve https:// dugmeleri
    function ask(title, value, secret, f) {
        askAdres = false;
        askTitle.text = title; askInput.text = value; askSecret = secret;
        askInput.echoMode = secret ? TextInput.Password : TextInput.Normal;
        Geri.giris = f; askBox.visible = true; askInput.forceActiveFocus(); askInput.cursorPosition = askInput.text.length;
    }
    // E6'da yazılan son sözcük kutuya işlenmemiş (ön yazım) olabilir: önce odağı alıp yazımı tamamlat, sonra oku
    function askEkle(s) {
        var p = askInput.cursorPosition;
        askInput.text = askInput.text.substring(0, p) + s + askInput.text.substring(p);
        askInput.cursorPosition = p + s.length;
        askInput.forceActiveFocus();
    }
    function askAccept() {
        askInput.focus = false;
        app.forceActiveFocus();
        var v = askInput.text.replace(/[\r\n\t]/g, "");
        var cb = Geri.giris;
        uzak.logla(qsTr("giris onay: '") + askTitle.text + "' " + v.length + qsTr(" karakter"));
        askBox.visible = false; odak();
        if (cb) cb(v);
    }
    function askPaste() {
        var c = uzak.panoMetni().replace(/[\r\n\t]/g, "");
        uzak.logla(qsTr("yapistir: ") + c.length + qsTr(" karakter"));
        if (c === "") { toast(qsTr("Pano boş (önce başka uygulamada metni kopyalayın)")); return; }
        var s = askInput.selectionStart, e = askInput.selectionEnd;
        askInput.text = askInput.text.substring(0, s) + c + askInput.text.substring(e);
        askInput.cursorPosition = s + c.length;
        askInput.forceActiveFocus();
        toast(c.length + qsTr(" karakter yapıştırıldı"));
    }
    Rectangle {
        id: askBox
        anchors.fill: parent; color: "#B0000000"; visible: false; z: 35
        MouseArea { anchors.fill: parent; onClicked: { askBox.visible = false; app.odak(); } }
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 40; topMargin: 50 }
            height: 150; radius: 12; color: app.surface
            MouseArea { anchors.fill: parent }
            Text { id: askTitle; x: 16; y: 12; color: app.textPrimary; font.pixelSize: 17; font.bold: true; width: parent.width - 32; elide: Text.ElideRight }
            Rectangle {
                x: 16; y: 44; width: parent.width - 32; height: 42; radius: 8; color: "#252E37"; border.width: 2; border.color: app.accent
                TextInput {
                    id: askInput
                    anchors { left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    font.pixelSize: 18; color: app.textPrimary
                    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    Keys.onPressed: {
                        // Ctrl+V yapistir / Ctrl+A tumunu sec (E6: Ctrl+V "7" ya da kod 22 gonderir)
                        if (((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_V || event.text === "7" || event.text === "v")) || event.text === "\u0016") { pano.yapistir(askInput); event.accepted = true; return; }
                        if (((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_A || event.text === "a")) || event.text === "\u0001") { askInput.selectAll(); event.accepted = true; return; }
                        var k = event.key, ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
                        if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select || event.text === "\r" || event.text === "\n") { app.askAccept(); event.accepted = true; }
                        else if (k === Qt.Key_Escape || k === Qt.Key_Context2) { askBox.visible = false; app.odak(); event.accepted = true; }
                        else if ((ctrl && k === Qt.Key_V) || event.text === "\u0016" || k === Qt.Key_Paste) { app.askPaste(); event.accepted = true; }
                        else if (ctrl && k === Qt.Key_G) { askInput.echoMode = askInput.echoMode === TextInput.Password ? TextInput.Normal : TextInput.Password; event.accepted = true; }
                    }
                }
            }
            Row {
                x: 16; y: 96; spacing: 10
                Repeater {
                    model: [{ k: "sil", t: qsTr("Temizle") }, { k: "https", t: "https://" }, { k: "paste", t: qsTr("Yapıştır") }, { k: "show", t: qsTr("Göster/Gizle") }, { k: "ok", t: qsTr("Tamam") }]
                    delegate: Rectangle {
                        visible: (modelData.k !== "show" || app.askSecret) && ((modelData.k !== "sil" && modelData.k !== "https") || app.askAdres)
                        width: abt.paintedWidth + 26; height: 36; radius: 18
                        color: abtMa.pressed ? "#33503C" : (modelData.k === "ok" ? "#24402C" : "#252E37")
                        Text { id: abt; anchors.centerIn: parent; text: modelData.t; color: modelData.k === "ok" ? app.accent : app.textPrimary; font.pixelSize: 15 }
                        MouseArea {
                            id: abtMa; anchors.fill: parent
                            onClicked: {
                                if (modelData.k === "paste") app.askPaste();
                                else if (modelData.k === "sil") { askInput.text = ""; askInput.forceActiveFocus(); }
                                else if (modelData.k === "https") { if (askInput.text.indexOf("://") < 0) { askInput.text = "https://" + askInput.text.replace(/^\s+/, ""); askInput.cursorPosition = askInput.text.length; } askInput.forceActiveFocus(); }
                                else if (modelData.k === "show") { askInput.echoMode = askInput.echoMode === TextInput.Password ? TextInput.Normal : TextInput.Password; askInput.forceActiveFocus(); }
                                else app.askAccept();
                            }
                        }
                    }
                }
            }
            Text { anchors { right: parent.right; rightMargin: 16; bottom: parent.bottom; bottomMargin: 8 } text: qsTr("Enter tamam • Ctrl+V yapıştır • Ctrl+G göster • Esc"); color: app.textSecondary; font.pixelSize: 11 }
        }
    }

    // =====================================================================
    // Bilgi
    // =====================================================================
    function bilgi(t, body) { infoTitle.text = t; infoBody.text = body; info.visible = true; infoFlick.contentY = 0; infoFlick.forceActiveFocus(); }
    Rectangle {
        id: info
        anchors.fill: parent; color: "#0E1318"; visible: false; z: 32
        Text { id: infoTitle; anchors { left: parent.left; top: parent.top; margins: 14 } color: app.textPrimary; font.pixelSize: 19; font.bold: true }
        Flickable {
            id: infoFlick
            anchors { left: parent.left; right: parent.right; top: infoTitle.bottom; bottom: parent.bottom; margins: 14 }
            clip: true; contentHeight: infoBody.paintedHeight + 20
            Text { id: infoBody; width: infoFlick.width; wrapMode: Text.Wrap; color: app.textPrimary; font.pixelSize: 15 }
            Keys.onPressed: {
                if (event.key === Qt.Key_Down) { contentY = Math.min(Math.max(0, contentHeight - height), contentY + 60); event.accepted = true; }
                else if (event.key === Qt.Key_Up) { contentY = Math.max(0, contentY - 60); event.accepted = true; }
                else { info.visible = false; app.odak(); event.accepted = true; }
            }
        }
        MouseArea { anchors.fill: parent; onClicked: { info.visible = false; app.odak(); } }
    }

    // =====================================================================
    // Bildirim
    // =====================================================================
    Rectangle {
        id: toastBox
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 40 }
        width: Math.min(parent.width - 40, toastText.paintedWidth + 40); height: toastText.paintedHeight + 18; radius: 12
        color: "#ECEFF1"; opacity: 0; visible: opacity > 0; z: 40
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Text { id: toastText; anchors.centerIn: parent; width: app.width - 80; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; color: "#0E1318"; font.pixelSize: 15 }
        Timer { id: toastTimer; interval: 3000; onTriggered: toastBox.opacity = 0 }
    }
}
