import QtQuick 1.1
import QtMultimediaKit 1.1
import "Util.js" as Util
import "Emoji.js" as Emoji
import "HaritaJs.js" as H

// Sohbet ekrani: mesaj balonlari (foto, ses, konum, dosya, yanit), yazma kutusu, ekler, sesli mesaj kaydi.
// Mesaja basili tut: yanitla / kopyala / ilet / duzenle / sil / ifade. Yukari kaydirinca eski mesajlar gelir.
Rectangle {
    id: root
    color: app.chatBg

    property string yanitId: ""
    property string yanitAd: ""
    property string yanitOzet: ""
    property string duzenlenen: ""
    property string yaziyorMetni: ""
    property string durumMetni: ""
    property double sonYaziyor: 0
    property string acBekleyen: ""          // indirilince acilacak dosya anahtari
    property variant tepkiler: ["1f44d", "2764", "1f525", "1f970", "1f44f", "1f601", "1f914", "1f631", "1f622", "1f389", "1f64f", "1f60d"]

    function sonda() { return liste.atYEnd || liste.count < 2; }
    function sonaGit() { sonaZamanlayici.restart(); }
    function konumKoru(eklenen) {
        liste.positionViewAtIndex(Math.min(eklenen, liste.count - 1), ListView.Beginning);
    }
    function sifirla() {
        sesDurdur();
        yanitIptal();
        duzenlenen = "";
        yazi.text = "";
        yaziyorMetni = "";
        sheet.visible = false;
        emojiSheet.visible = false;
        tepkiPanel.visible = false;
        picker.visible = false;
        if (konumEkrani.visible) konumEkrani.kapat();
        if (cihaz.kayitta) cihaz.kayitIptal();
        durumYenile();
    }
    function durumYenile() { durumMetni = app.acik !== "" ? tg.kisiDurumu(app.acik) : ""; }
    // geri tusu: acik katmani kapat
    function geri() {
        if (fotoSayfa.visible) { fotoSayfa.kapat(); return true; }
        if (konumEkrani.visible) { konumEkrani.kapat(); return true; }
        if (picker.visible) { picker.close(); return true; }
        if (tepkiPanel.visible) { tepkiPanel.visible = false; return true; }
        if (sheet.visible) { sheet.visible = false; return true; }
        if (emojiSheet.visible) { emojiSheet.visible = false; return true; }
        if (cihaz.kayitta) { cihaz.kayitIptal(); return true; }
        if (duzenlenen !== "" || yanitId !== "") { yanitIptal(); duzenlenen = ""; yazi.text = ""; return true; }
        return false;
    }

    function gonder() {
        var t = yazi.text;
        if (t.replace(/\s+/g, "") === "") return;
        if (duzenlenen !== "") {
            tg.mesajDuzenle(app.acik, duzenlenen, t);
            duzenlenen = "";
        } else {
            tg.mesajGonder(app.acik, t, yanitId);
        }
        yazi.text = "";
        yanitIptal();
    }
    function yanitla(i) {
        var m = mesajModel.get(i);
        duzenlenen = "";
        yanitId = m.mid;
        yanitAd = m.benden ? qsTr("Siz") : (m.gonderen !== "" ? m.gonderen : app.acikAd);
        yanitOzet = m.metin !== "" ? m.metin : "[" + Util.turEtiketi(m) + "]";
        yaziOdak();
    }
    function yanitIptal() { yanitId = ""; yanitAd = ""; yanitOzet = ""; }
    function yaziOdak() { yazi.forceActiveFocus(); yazi.openSoftwareInputPanel(); }
    function kopyala(i) {
        var m = mesajModel.get(i);
        var t = m.metin;
        if (m.tur === "konum") t = (m.konumAd !== "" ? m.konumAd + "\n" : "") + (m.adres !== "" ? m.adres + "\n" : "") + H.googleUrl(m.lat, m.lng);
        if (t === "") { toast.show(qsTr("Kopyalanacak metin yok")); return; }
        cihaz.panoya(t);
        toast.show(qsTr("Mesaj kopyalandı"));
    }
    function emojiEkle(hex) {
        var ch = Emoji.charFor(hex);
        var pos = yazi.cursorPosition;
        var t = yazi.text;
        yazi.text = t.substring(0, pos) + ch + t.substring(pos);
        yazi.cursorPosition = pos + ch.length;
        yazi.forceActiveFocus();
    }

    // ---- Basili tutma menusu ----
    function mesajMenusu(i) {
        var m = mesajModel.get(i);
        if (m.tur === "servis" || Util.gecici(m.mid)) return;
        var o = [];
        o.push(["yanitla", qsTr("Yanıtla")]);
        o.push(["tepki", qsTr("İfade bırak")]);
        if (m.metin !== "" || m.tur === "konum") o.push(["kopyala", qsTr("Kopyala")]);
        o.push(["ilet", qsTr("İlet")]);
        if (m.benden && (m.tur === "metin" || m.metin !== "")) o.push(["duzenle", qsTr("Düzenle")]);
        if (m.tur === "foto" && m.yol !== "") o.push(["foto", qsTr("Fotoğrafı aç")]);
        if (m.medya !== "" && m.tur !== "foto" && m.tur !== "ses") o.push(["ac", m.yol !== "" ? qsTr("Dosyayı aç") : qsTr("İndir")]);
        if (app.acikTur === "kanal" && !m.benden) { /* kanal: yalniz yonetici siler */ }
        else if (m.benden || app.acikTur === "kisi") o.push(["silHerkes", qsTr("Herkesten sil"), true]);
        if (app.acikTur !== "kanal" && app.acik.charAt(0) !== "k") o.push(["silBen", qsTr("Benden sil"), true]);
        menu.ac(m.metin !== "" ? m.metin.substring(0, 60) : Util.turEtiketi(m), o, { tur: "mesaj", i: i, mid: m.mid });
    }
    function menuSecimi(kod, i, mid) {
        if (i >= mesajModel.count || mesajModel.get(i).mid !== mid) { i = app.mesajBul(mid); if (i < 0) return; }
        var m = mesajModel.get(i);
        if (kod === "yanitla") yanitla(i);
        else if (kod === "kopyala") kopyala(i);
        else if (kod === "tepki") { tepkiPanel.mid = mid; tepkiPanel.visible = true; }
        else if (kod === "ilet") app.kisilerAc("ilet", mid);
        else if (kod === "duzenle") { yanitIptal(); duzenlenen = mid; yazi.text = m.metin; yaziOdak(); }
        else if (kod === "silHerkes") tg.mesajSil(app.acik, mid, true);
        else if (kod === "silBen") tg.mesajSil(app.acik, mid, false);
        else if (kod === "foto") fotoSayfa.ac(m.yol, m.buyukMedya);
        else if (kod === "ac") dosyaAc(i);
    }

    // ---- Medya ----
    function dosyaAc(i) {
        var m = mesajModel.get(i);
        if (m.yol !== "") { cihaz.ac(m.yol); return; }
        if (m.medya === "") return;
        acBekleyen = m.medya;
        mesajModel.setProperty(i, "yuzde", 0);
        tg.medyaIndir(m.medya);
    }
    function medyaGeldi(anahtar, yol) {
        for (var i = 0; i < mesajModel.count; i++) {
            var m = mesajModel.get(i);
            if (m.medya === anahtar) { mesajModel.setProperty(i, "yol", yol); mesajModel.setProperty(i, "yuzde", -1); }
            else if (m.onizleme === anahtar) mesajModel.setProperty(i, "oYol", yol);
        }
        if (anahtar === sesAnahtar && sesYukleniyor) sesBasla(yol);
        if (anahtar === acBekleyen) { acBekleyen = ""; cihaz.ac(yol); }
    }
    function medyaIlerledi(anahtar, yuzde) {
        for (var i = mesajModel.count - 1; i >= 0; i--) if (mesajModel.get(i).medya === anahtar) { mesajModel.setProperty(i, "yuzde", yuzde); return; }
    }
    function medyaOlmadi(anahtar, mesaj) {
        for (var i = 0; i < mesajModel.count; i++) if (mesajModel.get(i).medya === anahtar) mesajModel.setProperty(i, "yuzde", -2);
        if (anahtar === sesAnahtar) { sesDurdur(); toast.show(qsTr("Sesli mesaj alınamadı: ") + mesaj); }
        if (anahtar === acBekleyen) { acBekleyen = ""; toast.show(mesaj); }
    }
    function dosyaSecildi(kind, yol) {
        if (kind === "image") { tg.fotoGonder(app.acik, yol, yazi.text, yanitId); yazi.text = ""; }
        else tg.dosyaGonder(app.acik, yol, yanitId);
        yanitIptal();
    }

    // ---- Sesli mesaj calma (Symbian ses arka ucu: kaynak degisiminde kisa bekleme) ----
    property string sesMid: ""
    property string sesAnahtar: ""
    property bool sesYukleniyor: false
    property bool sesCaliyor: ses.playing && !ses.paused
    property bool sesGecis: false
    property string sesBekleyenUrl: ""

    function sesDegistir(i) {
        var m = mesajModel.get(i);
        if (m.mid === sesMid && !sesYukleniyor) { if (sesCaliyor) ses.pause(); else ses.play(); return; }
        if (m.mid === sesMid && sesYukleniyor) { sesDurdur(); return; }
        sesDurdur();
        sesMid = m.mid;
        sesAnahtar = m.medya;
        sesYukleniyor = true;
        if (m.yol !== "") sesBasla(m.yol);
        else if (m.medya !== "") tg.medyaIndir(m.medya);
        else sesDurdur();
    }
    function sesBasla(yol) {
        sesBekleyenUrl = cihaz.url(yol);
        sesGecis = true;
        sesBaslat.restart();
    }
    Timer {
        id: sesBaslat
        interval: 300
        onTriggered: {
            if (root.sesMid === "" || root.sesBekleyenUrl === "") { root.sesGecis = false; return; }
            var ayni = ("" + ses.source) === root.sesBekleyenUrl;
            if (!ayni) ses.source = root.sesBekleyenUrl;
            root.sesGecis = false;
            if (ayni) ses.position = 0;
            ses.play();
        }
    }
    function sesDurdur() {
        sesGecis = true;
        sesBaslat.stop();
        if (ses.playing) ses.stop();
        sesMid = "";
        sesAnahtar = "";
        sesYukleniyor = false;
        sesBekleyenUrl = "";
        sesGecis = false;
    }
    function saatMs(ms) {
        var s = Math.max(0, Math.floor(ms / 1000));
        return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60);
    }
    Audio {
        id: ses
        onPlayingChanged: if (playing && !root.sesGecis) root.sesYukleniyor = false
        onStatusChanged: {
            if (root.sesGecis) return;
            if (status === Audio.EndOfMedia) root.sesDurdur();
            if (status === Audio.InvalidMedia) { root.sesDurdur(); toast.show(qsTr("Sesli mesaj çalınamadı")); }
        }
        onError: if (error !== Audio.NoError && !root.sesGecis) { root.sesDurdur(); toast.show(qsTr("Sesli mesaj çalınamadı: ") + errorString); }
    }

    Timer { id: sonaZamanlayici; interval: 60; onTriggered: liste.positionViewAtEnd() }
    Timer { id: yaziyorSil; interval: 6000; onTriggered: root.yaziyorMetni = "" }
    Timer { id: kayitYaziyor; interval: 5000; repeat: true; running: cihaz.kayitta; onTriggered: tg.yaziyor(app.acik, true) }

    Connections {
        target: tg
        onYaziyorBilgi: if (sohbet === app.acik) { root.yaziyorMetni = metin; if (metin !== "") yaziyorSil.restart(); }
        onKisiDurumDegisti: if (sohbet === app.acik) root.durumYenile()
        onMedyaHazir: root.medyaGeldi(anahtar, yol)
        onMedyaIlerleme: root.medyaIlerledi(anahtar, yuzde)
        onMedyaHata: root.medyaOlmadi(anahtar, mesaj)
    }
    Connections {
        target: cihaz
        onKayitSaniye: kayitSure.text = Math.floor(saniye / 60) + ":" + (saniye % 60 < 10 ? "0" : "") + (saniye % 60)
        onKayitHatasi: toast.show(mesaj)
    }

    Header {
        id: baslik
        anchors { left: parent.left; right: parent.right; top: parent.top }
        z: 2
        showBack: true
        title: app.acikAd
        subtitle: !tg.bagli ? qsTr("Bağlanıyor…") : (root.yaziyorMetni !== "" ? root.yaziyorMetni : root.durumMetni)
        avatarName: app.acikAd
        avatarKey: app.acik
        busy: app.gecmisYukleniyor
        onBack: app.sohbetKapat()
    }

    ListView {
        id: liste
        anchors { left: parent.left; right: parent.right; top: baslik.bottom; bottom: yanitCubuk.top }
        model: mesajModel
        clip: true
        spacing: 4
        cacheBuffer: 600
        onAtYBeginningChanged: {
            if (atYBeginning && count > 0 && !app.gecmisSonu && !app.gecmisYukleniyor && moving) {
                app.gecmisYukleniyor = true;
                tg.mesajlariYukle(app.acik, true);
            }
        }
        header: Item { width: liste.width; height: 8 }
        footer: Item { width: liste.width; height: 8 }

        delegate: Item {
            id: oge
            width: liste.width
            property bool gunBasi: index <= 0 || index > mesajModel.count || !mesajModel.get(index - 1) || !Util.ayniGun(mesajModel.get(index - 1).zaman, zaman)
            property bool servis: tur === "servis"
            property bool grupta: app.acikTur !== "kisi" && !benden
            property int enGenis: Math.round(liste.width * 0.78) - 24
            property bool uzun: metin.length > 1500
            property string gosterilen: (uzun && !genis) ? metin.substring(0, 1500) + "…" : metin
            property bool emo: Emoji.has(metin)
            property bool gorsel: (tur === "foto" || ((tur === "video" || tur === "gif" || tur === "yuvarlak") && onizleme !== ""))
            property bool konumlu: tur === "konum" && (lat !== 0 || lng !== 0)
            property real lwx: konumlu ? H.lngX(lng, 15) : 0
            property real lwy: konumlu ? H.latY(lat, 15) : 0
            property int gorselEn: Math.min(enGenis, 300)
            property int gorselBoy: en > 0 && boy > 0 ? Math.min(360, Math.round(gorselEn * boy / en)) : 200
            height: (gunBasi ? 40 : 0) + (servis ? servisKutu.height + 6 : balon.height + (tepki !== "" ? 22 : 2))

            Component.onCompleted: {
                // gorunen fotograflari ve onizlemeleri kendiliginden indir
                if (tur === "foto" && medya !== "" && yol === "") tg.medyaIndir(medya);
                else if (onizleme !== "" && oYol === "") tg.medyaIndir(onizleme);
            }

            // genislik olcumu (gorunmez): uzun satir kaymasin, balon metne gore daralsin
            Text { id: olcu; visible: false; text: oge.gosterilen.substring(0, 300); textFormat: Text.PlainText; font.pixelSize: 20 }
            Text { id: yOlcu; visible: false; text: yanitOzet.substring(0, 80); font.pixelSize: 16 }
            Text { id: gOlcu; visible: false; text: gonderen; font.pixelSize: 17; font.bold: true }

            Rectangle {
                visible: oge.gunBasi
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 6 }
                height: 28
                width: gunYazi.paintedWidth + 24
                radius: 14
                color: app.chip
                Text { id: gunYazi; anchors.centerIn: parent; text: Util.gunEtiketi(zaman); color: app.textSecondary; font.pixelSize: 16 }
            }

            Rectangle {
                id: servisKutu
                visible: oge.servis
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: oge.gunBasi ? 40 : 2 }
                width: Math.min(liste.width - 80, servisYazi.paintedWidth + 28)
                height: servisYazi.paintedHeight + 12
                radius: 14
                color: app.chip
                Text {
                    id: servisYazi
                    anchors.centerIn: parent
                    width: liste.width - 108
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: metin
                    color: app.textSecondary
                    font.pixelSize: 16
                }
            }

            Rectangle {
                id: balon
                visible: !oge.servis
                anchors { top: parent.top; topMargin: oge.gunBasi ? 40 : 0 }
                x: benden ? liste.width - width - 10 : 10
                radius: 14
                color: benden ? app.bubbleOut : app.bubbleIn
                property int icerikEn: Math.max(
                        Math.min(olcu.paintedWidth + (oge.emo ? 20 : 0), oge.enGenis),
                        altSatir.width + 4,
                        oge.grupta && gonderen !== "" ? Math.min(gOlcu.paintedWidth, oge.enGenis) : 0,
                        yanitId !== "" ? Math.min(yOlcu.paintedWidth + 20, oge.enGenis) : 0,
                        oge.gorsel ? oge.gorselEn : 0,
                        oge.konumlu ? Math.min(oge.enGenis, 300) : 0,
                        (tur === "ses") ? Math.min(oge.enGenis, 280) : 0,
                        (tur === "dosya" || tur === "muzik" || (tur === "video" && onizleme === "")) ? Math.min(oge.enGenis, 300) : 0,
                        tur !== "metin" && !oge.gorsel && !oge.konumlu && tur !== "ses" ? Math.min(oge.enGenis, 220) : 0)
                width: icerikEn + 24
                height: icerik.height + 14

                MouseArea {
                    anchors.fill: parent
                    onPressAndHold: root.mesajMenusu(index)
                    onDoubleClicked: if (!Util.gecici(mid)) tg.tepkiGonder(app.acik, mid, benimTepki === "" ? "❤" : "")
                }

                Column {
                    id: icerik
                    x: 12; y: 7
                    width: balon.icerikEn
                    spacing: 4

                    Text {
                        visible: oge.grupta && gonderen !== ""
                        width: parent.width
                        text: gonderen
                        color: Util.colorFor(gonderenId)
                        font.pixelSize: 17
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: iletildi
                        width: parent.width
                        text: qsTr("İletildi: ") + iletenAd
                        color: app.accentText
                        font.pixelSize: 16
                        font.italic: true
                        elide: Text.ElideRight
                    }
                    // yanitlanan mesaj
                    Rectangle {
                        visible: yanitId !== ""
                        width: parent.width
                        height: visible ? yKol.height + 8 : 0
                        radius: 6
                        color: app.dark ? "#26000000" : "#14000000"
                        Rectangle { width: 3; height: parent.height; color: app.accentText }
                        Column {
                            id: yKol
                            x: 10; y: 4
                            width: parent.width - 16
                            Text { width: parent.width; visible: yanitAd !== ""; text: yanitAd; color: app.accentText; font.pixelSize: 16; font.bold: true; elide: Text.ElideRight }
                            Text { width: parent.width; text: yanitOzet.replace(/\n/g, " "); color: app.textSecondary; font.pixelSize: 16; elide: Text.ElideRight }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { var j = app.mesajBul(yanitId); if (j >= 0) liste.positionViewAtIndex(j, ListView.Center); }
                            onPressAndHold: root.mesajMenusu(index)
                        }
                    }
                    // fotograf / video onizlemesi
                    Rectangle {
                        visible: oge.gorsel
                        width: oge.gorselEn
                        height: visible ? oge.gorselBoy : 0
                        radius: 8
                        clip: true
                        color: app.pressed
                        Image {
                            id: resim
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: false
                            sourceSize.width: 320
                            source: !oge.gorsel ? "" : (tur === "foto" ? (yol !== "" ? cihaz.url(yol) : "") : (oYol !== "" ? cihaz.url(oYol) : ""))
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: resim.status !== Image.Ready
                            text: yuzde === -2 ? qsTr("Alınamadı, dokunun") : qsTr("Yükleniyor…")
                            color: app.textSecondary
                            font.pixelSize: 17
                        }
                        Rectangle {
                            visible: tur !== "foto"
                            anchors.centerIn: parent
                            width: 60; height: 60; radius: 30
                            color: "#99000000"
                            Image { anchors.centerIn: parent; anchors.horizontalCenterOffset: 2; width: 30; height: 30; smooth: true; source: yuzde >= 0 ? "" : "../images/play.png" }
                            Text { anchors.centerIn: parent; visible: yuzde >= 0; text: yuzde + "%"; color: "white"; font.pixelSize: 16 }
                        }
                        Rectangle {
                            visible: tur !== "foto" && sure > 0
                            anchors { left: parent.left; top: parent.top; margins: 6 }
                            width: vsYazi.paintedWidth + 12; height: 24; radius: 12
                            color: "#99000000"
                            Text { id: vsYazi; anchors.centerIn: parent; text: Util.sure(sure); color: "white"; font.pixelSize: 15 }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (tur === "foto") {
                                    if (yol !== "") fotoSayfa.ac(yol, buyukMedya);
                                    else if (medya !== "") { mesajModel.setProperty(index, "yuzde", -1); tg.medyaIndir(medya); }
                                } else root.dosyaAc(index);
                            }
                            onPressAndHold: root.mesajMenusu(index)
                        }
                    }
                    // konum karti
                    Rectangle {
                        visible: oge.konumlu
                        width: parent.width
                        height: visible ? lKol.height + 156 : 0
                        radius: 8
                        clip: true
                        color: app.pressed
                        Item {
                            id: lHarita
                            width: parent.width; height: 150
                            clip: true
                            property int bx: Math.floor((oge.lwx - width / 2) / 256)
                            property int by: Math.floor((oge.lwy - height / 2) / 256)
                            Repeater {
                                model: oge.konumlu ? 4 : 0
                                Image {
                                    property int tx: lHarita.bx + index % 2
                                    property int ty: lHarita.by + Math.floor(index / 2)
                                    x: Math.round(tx * 256 - (oge.lwx - lHarita.width / 2))
                                    y: Math.round(ty * 256 - (oge.lwy - lHarita.height / 2))
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
                            id: lKol
                            anchors { left: parent.left; right: parent.right; top: lHarita.bottom; leftMargin: 10; rightMargin: 10; topMargin: 4 }
                            Text { width: parent.width; text: konumAd !== "" ? konumAd : qsTr("Konum"); font.pixelSize: 19; font.bold: true; color: app.textPrimary; elide: Text.ElideRight }
                            Text { width: parent.width; visible: adres !== ""; text: adres; font.pixelSize: 15; color: app.textSecondary; elide: Text.ElideRight }
                            Text { text: qsTr("Haritada açmak için dokunun"); font.pixelSize: 15; color: app.accentText }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: konumEkrani.goster(lat, lng, konumAd, adres)
                            onPressAndHold: root.mesajMenusu(index)
                        }
                    }
                    // sesli mesaj
                    Item {
                        id: sp
                        visible: tur === "ses"
                        width: parent.width
                        height: visible ? 60 : 0
                        property bool etkin: visible && root.sesMid === mid
                        property bool yukleniyor: etkin && root.sesYukleniyor
                        property bool caliyor: etkin && root.sesCaliyor
                        property real oran: etkin && ses.duration > 0 ? ses.position / ses.duration : 0
                        Rectangle {
                            id: sDugme
                            anchors.verticalCenter: parent.verticalCenter
                            width: 50; height: 50; radius: 25
                            color: sFare.pressed ? app.brandPressed : app.brand
                            smooth: true
                            Image { visible: !sp.caliyor && !sp.yukleniyor; anchors.centerIn: parent; anchors.horizontalCenterOffset: 2; width: 28; height: 28; smooth: true; source: "../images/play.png" }
                            Row {
                                visible: sp.caliyor
                                anchors.centerIn: parent
                                spacing: 6
                                Rectangle { width: 6; height: 22; radius: 1; color: "white" }
                                Rectangle { width: 6; height: 22; radius: 1; color: "white" }
                            }
                            Text { visible: sp.yukleniyor; anchors.centerIn: parent; text: yuzde > 0 ? yuzde + "%" : "…"; color: "white"; font.pixelSize: 16; font.bold: true }
                            MouseArea { id: sFare; anchors { fill: parent; margins: -6 } onClicked: root.sesDegistir(index); onPressAndHold: root.mesajMenusu(index) }
                        }
                        Item {
                            id: iz
                            anchors { left: sDugme.right; leftMargin: 12; right: parent.right; rightMargin: 4; top: parent.top; topMargin: 12 }
                            height: 16
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 5; radius: 2.5; color: app.dark ? "#55FFFFFF" : "#33000000" }
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: Math.round(parent.width * sp.oran); height: 5; radius: 2.5; color: app.accentText }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.round((parent.width - width) * sp.oran)
                                width: 14; height: 14; radius: 7
                                color: sp.etkin ? app.accentText : (app.dark ? "#AAFFFFFF" : "#88000000")
                                smooth: true
                            }
                            MouseArea {
                                anchors { fill: parent; topMargin: -14; bottomMargin: -10 }
                                onClicked: { if (sp.etkin && ses.duration > 0) ses.position = Math.round(mouse.x / iz.width * ses.duration); else root.sesDegistir(index); }
                            }
                        }
                        Text {
                            anchors { left: iz.left; top: iz.bottom; topMargin: 6 }
                            text: sp.etkin && ses.duration > 0 ? root.saatMs(ses.position) + " / " + root.saatMs(ses.duration) : Util.sure(sure)
                            color: app.textSecondary
                            font.pixelSize: 15
                        }
                    }
                    // dosya / muzik / onizlemesiz video
                    Item {
                        visible: tur === "dosya" || tur === "muzik" || (tur === "video" && onizleme === "") || (tur === "gif" && onizleme === "")
                        width: parent.width
                        height: visible ? 58 : 0
                        Rectangle {
                            id: dDugme
                            anchors.verticalCenter: parent.verticalCenter
                            width: 50; height: 50; radius: 25
                            color: app.brand
                            Image {
                                visible: yuzde < 0
                                anchors.centerIn: parent
                                width: 28; height: 28; smooth: true
                                source: yol !== "" ? (tur === "muzik" ? "../images/music.png" : (tur === "dosya" ? "../images/file.png" : "../images/play.png")) : "../images/down.png"
                            }
                            Text { visible: yuzde >= 0; anchors.centerIn: parent; text: yuzde + "%"; color: "white"; font.pixelSize: 15; font.bold: true }
                        }
                        Column {
                            anchors { left: dDugme.right; leftMargin: 12; right: parent.right; verticalCenter: parent.verticalCenter }
                            Text { width: parent.width; text: dosyaAdi !== "" ? dosyaAdi : Util.turEtiketi({ tur: tur, sure: sure, dosyaAdi: "", konumAd: "", boyut: 0 }); color: app.textPrimary; font.pixelSize: 18; elide: Text.ElideMiddle }
                            Text { width: parent.width; text: (yuzde === -2 ? qsTr("Alınamadı") + " · " : "") + Util.boyut(boyut) + (sure > 0 ? " · " + Util.sure(sure) : "") + (yol !== "" ? "" : "  " + qsTr("(indirmek için dokunun)")); color: app.textSecondary; font.pixelSize: 15; elide: Text.ElideRight }
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.dosyaAc(index); onPressAndHold: root.mesajMenusu(index) }
                    }
                    // diger turler (kisi, anket, cikartma, zar...)
                    Text {
                        visible: tur !== "metin" && !oge.gorsel && !oge.konumlu && tur !== "ses" && tur !== "dosya" && tur !== "muzik" && tur !== "foto" && !(tur === "video" || tur === "gif" || tur === "yuvarlak")
                        width: parent.width
                        text: "[" + Util.turEtiketi({ tur: tur, sure: sure, dosyaAdi: dosyaAdi, konumAd: konumAd, boyut: boyut }) + "]"
                        color: app.accentText
                        font.pixelSize: 18
                        wrapMode: Text.Wrap
                    }
                    Text {
                        id: metinYazi
                        visible: metin !== ""
                        width: parent.width
                        text: oge.emo ? Emoji.rich(oge.gosterilen, 24) : oge.gosterilen
                        textFormat: oge.emo ? Text.RichText : Text.PlainText
                        color: app.textPrimary
                        font.pixelSize: 20
                        wrapMode: Text.Wrap
                    }
                    Text {
                        visible: oge.uzun
                        text: genis ? qsTr("Daralt") : qsTr("Devamını oku")
                        color: app.accentText
                        font.pixelSize: 18
                        font.bold: true
                        MouseArea { anchors { fill: parent; margins: -10 } onClicked: mesajModel.setProperty(index, "genis", !genis) }
                    }
                    Row {
                        id: altSatir
                        anchors.right: parent.right
                        spacing: 6
                        Text {
                            text: (duzenlendi ? qsTr("düzenlendi ") : "") + (bekliyor && yuzde >= 0 ? yuzde + "%  " : "") + Util.saat(zaman)
                            color: benden ? (app.dark ? "#7DA8D3" : "#5DAA5D") : app.textSecondary
                            font.pixelSize: 15
                        }
                        Text {
                            visible: benden && (hata || bekliyor)
                            text: hata ? "!" : "..."
                            color: hata ? app.danger : (app.dark ? "#7DA8D3" : "#5DAA5D")
                            font.pixelSize: 15
                            font.bold: true
                        }
                        Image {
                            visible: benden && !hata && !bekliyor
                            source: okundu ? "../images/ticks.png" : "../images/tick1.png"
                            width: 20; height: 14
                            smooth: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // ifadeler
                Rectangle {
                    visible: tepki !== ""
                    z: 2
                    anchors { top: parent.bottom; topMargin: -6; left: benden ? undefined : parent.left; leftMargin: 10; right: benden ? parent.right : undefined; rightMargin: 10 }
                    width: tepkiYazi.paintedWidth + 16; height: 28; radius: 14
                    color: benimTepki !== "" ? app.brand : app.surface
                    border.width: 1; border.color: app.divider
                    Text {
                        id: tepkiYazi
                        anchors.centerIn: parent
                        text: Emoji.has(tepki) ? Emoji.rich(tepki, 18) : tepki
                        textFormat: Emoji.has(tepki) ? Text.RichText : Text.PlainText
                        color: benimTepki !== "" ? "white" : app.textPrimary
                        font.pixelSize: 15
                    }
                    MouseArea { anchors.fill: parent; onClicked: { tepkiPanel.mid = mid; tepkiPanel.visible = true; } }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: liste.count === 0 && !app.gecmisYukleniyor
            text: qsTr("Henüz mesaj yok")
            color: app.textSecondary
            font.pixelSize: 20
        }
    }

    // ---- Yanit / duzenleme cubugu ----
    Rectangle {
        id: yanitCubuk
        anchors { left: parent.left; right: parent.right; bottom: altCubuk.top }
        height: visible ? 56 : 0
        visible: root.yanitId !== "" || root.duzenlenen !== ""
        color: app.surface
        Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: app.divider }
        Rectangle { x: 14; y: 8; width: 3; height: 40; color: app.accentText }
        Column {
            anchors { left: parent.left; leftMargin: 26; right: yKapat.left; verticalCenter: parent.verticalCenter }
            Text { width: parent.width; text: root.duzenlenen !== "" ? qsTr("Düzenleniyor") : qsTr("Yanıt: ") + root.yanitAd; color: app.accentText; font.pixelSize: 17; font.bold: true; elide: Text.ElideRight }
            Text { width: parent.width; visible: root.duzenlenen === ""; text: root.yanitOzet.replace(/\n/g, " "); color: app.textSecondary; font.pixelSize: 16; elide: Text.ElideRight }
        }
        IconButton {
            id: yKapat
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            source: "../images/close" + app.iconTone + ".png"
            onClicked: { if (root.duzenlenen !== "") yazi.text = ""; root.duzenlenen = ""; root.yanitIptal(); }
        }
    }

    // ---- Yazma cubugu ----
    Item {
        id: altCubuk
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: cihaz.kayitta ? 76 : Math.max(76, yaziKutu.height + 18)

        Rectangle { anchors.fill: parent; color: app.surface }

        Item {
            anchors.fill: parent
            visible: !cihaz.kayitta

            IconButton {
                id: ekDugme
                anchors { left: parent.left; leftMargin: 2; bottom: parent.bottom; bottomMargin: 8 }
                source: "../images/attach" + app.iconTone + ".png"
                onClicked: { emojiSheet.visible = false; sheet.visible = !sheet.visible; }
            }
            IconButton {
                id: emojiDugme
                anchors { left: ekDugme.right; leftMargin: -8; bottom: parent.bottom; bottomMargin: 8 }
                source: "../images/emoji/1f60a.png"
                iconSize: 30
                onClicked: { sheet.visible = false; emojiSheet.visible = !emojiSheet.visible; if (!emojiSheet.visible) root.yaziOdak(); }
            }
            Rectangle {
                id: yaziKutu
                anchors { left: emojiDugme.right; leftMargin: 2; right: eylemDugme.left; rightMargin: 8; bottom: parent.bottom; bottomMargin: 9 }
                height: Math.min(150, Math.max(58, yazi.paintedHeight + 28))
                radius: 29
                color: app.fieldBg
                border.width: yazi.activeFocus ? 2 : 0
                border.color: app.brand
                Flickable {
                    id: kaydir
                    anchors { fill: parent; leftMargin: 20; rightMargin: 16; topMargin: 14; bottomMargin: 14 }
                    contentWidth: width
                    contentHeight: yazi.paintedHeight
                    clip: true
                    function gorunur(r) {
                        if (contentY >= r.y) contentY = r.y;
                        else if (contentY + height <= r.y + r.height) contentY = r.y + r.height - height;
                    }
                    TextEdit {
                        id: yazi
                        // Ctrl+V yapistir / Ctrl+A tumunu sec (E6: Ctrl+V "7" ya da kod 22 gonderir)
                        Keys.onPressed: {
                            if (((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_V || event.text === "7" || event.text === "v")) || event.text === "\u0016") { pano.yapistir(yazi); event.accepted = true; }
                            else if (((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_A || event.text === "a")) || event.text === "\u0001") { yazi.selectAll(); event.accepted = true; }
                        }
                        width: kaydir.width
                        wrapMode: TextEdit.Wrap
                        textFormat: TextEdit.PlainText
                        font.pixelSize: 21
                        color: app.textPrimary
                        selectionColor: app.brand
                        onCursorRectangleChanged: kaydir.gorunur(cursorRectangle)
                        Keys.onReturnPressed: { root.gonder(); event.accepted = true; }
                        Keys.onEnterPressed: { root.gonder(); event.accepted = true; }
                        onTextChanged: {
                            var simdi = new Date().getTime();
                            if (text !== "" && root.duzenlenen === "" && simdi - root.sonYaziyor > 5000) { root.sonYaziyor = simdi; tg.yaziyor(app.acik); }
                        }
                    }
                }
                Text {
                    anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                    text: qsTr("Mesaj")
                    color: app.placeholder
                    font.pixelSize: 21
                    visible: yazi.text.length === 0
                }
                MouseArea { anchors.fill: parent; enabled: !yazi.activeFocus; onClicked: root.yaziOdak() }
            }
            Rectangle {
                id: eylemDugme
                anchors { right: parent.right; rightMargin: 10; bottom: parent.bottom; bottomMargin: 9 }
                width: 58; height: 58; radius: 29
                color: eFare.pressed ? app.brandPressed : app.brand
                smooth: true
                property bool yaziVar: yazi.text.replace(/\s+/g, "") !== ""
                Image {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: eylemDugme.yaziVar ? 2 : 0
                    width: 32; height: 32; smooth: true
                    source: eylemDugme.yaziVar ? "../images/send.png" : "../images/mic.png"
                }
                MouseArea {
                    id: eFare
                    anchors.fill: parent
                    onClicked: {
                        if (eylemDugme.yaziVar) root.gonder();
                        else { sheet.visible = false; root.sesDurdur(); if (cihaz.kayitBasla()) tg.yaziyor(app.acik, true); }
                    }
                }
            }
        }

        // kayit modu
        Item {
            anchors.fill: parent
            visible: cihaz.kayitta
            IconButton {
                id: kayitIptal
                anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                source: "../images/close" + app.iconTone + ".png"
                onClicked: cihaz.kayitIptal()
            }
            Rectangle {
                id: kayitNokta
                anchors { left: kayitIptal.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
                width: 18; height: 18; radius: 9
                color: "#F15C6D"
                SequentialAnimation on opacity {
                    running: cihaz.kayitta
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 600 }
                    NumberAnimation { to: 1; duration: 600 }
                }
            }
            Text {
                id: kayitSure
                anchors { left: kayitNokta.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
                text: "0:00"
                color: app.textPrimary
                font.pixelSize: 24
            }
            Text {
                anchors { left: kayitSure.right; leftMargin: 18; right: kayitGonder.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                text: qsTr("Kaydediliyor… göndermek için dokunun")
                color: app.textSecondary
                font.pixelSize: 17
                elide: Text.ElideRight
            }
            Rectangle {
                id: kayitGonder
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                width: 58; height: 58; radius: 29
                color: kgFare.pressed ? app.brandPressed : app.brand
                Image { anchors.centerIn: parent; anchors.horizontalCenterOffset: 2; width: 32; height: 32; smooth: true; source: "../images/send.png" }
                MouseArea {
                    id: kgFare
                    anchors.fill: parent
                    onClicked: {
                        var yol = cihaz.kayitBitir();
                        if (yol !== "") { tg.sesGonder(app.acik, yol, cihaz.sonSure(), cihaz.sonDalga(), root.yanitId); root.yanitIptal(); }
                    }
                }
            }
        }
    }

    // ---- Ek menusu ----
    Item {
        id: sheet
        anchors.fill: parent
        visible: false
        z: 5
        MouseArea { anchors.fill: parent; onClicked: sheet.visible = false }
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 10; rightMargin: 10; bottomMargin: altCubuk.height + 6 }
            height: 140
            radius: 18
            color: app.surface
            MouseArea { anchors.fill: parent }
            Row {
                anchors.centerIn: parent
                spacing: 26
                Repeater {
                    model: ListModel {
                        ListElement { etiket: QT_TR_NOOP("Fotoğraf"); tur: "image"; ikon: "gallery"; renk: "#BF59CF" }
                        ListElement { etiket: QT_TR_NOOP("Video"); tur: "video"; ikon: "video"; renk: "#FF2E74" }
                        ListElement { etiket: QT_TR_NOOP("Ses"); tur: "audio"; ikon: "music"; renk: "#FF7F21" }
                        ListElement { etiket: QT_TR_NOOP("Dosya"); tur: "file"; ikon: "file"; renk: "#5288C1" }
                        ListElement { etiket: QT_TR_NOOP("Konum"); tur: "location"; ikon: "location"; renk: "#1FA855" }
                    }
                    delegate: Column {
                        spacing: 8
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 66; height: 66; radius: 33
                            color: renk
                            opacity: sFare.pressed ? 0.7 : 1
                            Image { anchors.centerIn: parent; width: 36; height: 36; smooth: true; source: "../images/" + ikon + ".png" }
                            MouseArea {
                                id: sFare
                                anchors.fill: parent
                                onClicked: { sheet.visible = false; if (tur === "location") konumEkrani.ac(); else picker.open(tur); }
                            }
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: qsTr(etiket); color: app.textPrimary; font.pixelSize: 17 }
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
        MouseArea { anchors.fill: parent; onClicked: { emojiSheet.visible = false; root.yaziOdak(); } }
        Rectangle {
            id: emojiKutu
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 8; rightMargin: 8; bottomMargin: altCubuk.height + 6 }
            height: 250
            radius: 18
            color: app.surface
            MouseArea { anchors.fill: parent }
            Flickable {
                anchors { fill: parent; margins: 10 }
                contentHeight: emojiIzgara.height
                clip: true
                Grid {
                    id: emojiIzgara
                    columns: 10
                    spacing: 2
                    Repeater {
                        model: Emoji.codes
                        delegate: Rectangle {
                            width: (emojiKutu.width - 20 - 18) / 10
                            height: 56
                            radius: 10
                            color: emFare.pressed ? app.pressed : "transparent"
                            Image { anchors.centerIn: parent; width: 34; height: 34; smooth: true; source: Emoji.imgPath(modelData) }
                            MouseArea { id: emFare; anchors.fill: parent; onClicked: root.emojiEkle(modelData) }
                        }
                    }
                }
            }
        }
    }

    // ---- Ifade paneli ----
    Item {
        id: tepkiPanel
        anchors.fill: parent
        visible: false
        z: 8
        property string mid: ""
        MouseArea { anchors.fill: parent; onClicked: tepkiPanel.visible = false }
        Rectangle { anchors.fill: parent; color: "#66000000" }
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 40, 6 * 76 + 30)
            height: tKol.height + 28
            radius: 18
            color: app.surface
            MouseArea { anchors.fill: parent }
            Column {
                id: tKol
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
                            width: (tKol.width - 20) / 6; height: 62; radius: 12
                            color: tFare.pressed ? app.pressed : "transparent"
                            Image { anchors.centerIn: parent; width: 40; height: 40; smooth: true; source: Emoji.imgPath(modelData) }
                            MouseArea {
                                id: tFare
                                anchors.fill: parent
                                onClicked: { tepkiPanel.visible = false; tg.tepkiGonder(app.acik, tepkiPanel.mid, Emoji.charFor(modelData)); }
                            }
                        }
                    }
                }
                Rectangle {
                    width: kt.paintedWidth + 32; height: 46; radius: 23; color: kFare.pressed ? app.pressed : app.chip
                    Text { id: kt; anchors.centerIn: parent; text: qsTr("İfadeyi kaldır"); font.pixelSize: 18; font.bold: true; color: app.accentText }
                    MouseArea { id: kFare; anchors.fill: parent; onClicked: { tepkiPanel.visible = false; tg.tepkiGonder(app.acik, tepkiPanel.mid, ""); } }
                }
            }
        }
    }

    MediaPicker {
        id: picker
        anchors.fill: parent
        z: 10
        onPicked: root.dosyaSecildi(picker.kind, path)
    }

    KonumSecici {
        id: konumEkrani
        anchors.fill: parent
        z: 12
        koyu: app.dark
        cVurgu: app.brand
        onGonder: tg.konumGonder(app.acik, lat, lng, ad, adres)
    }

    FotoPage {
        id: fotoSayfa
        anchors.fill: parent
    }
}
