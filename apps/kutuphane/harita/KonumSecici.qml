import QtQuick 1.1
import "HaritaJs.js" as H

// Konum secme / gosterme ekrani (WhatsBelle). GPS yalnizca dugmeyle acilir, ekrandan cikinca (kapat) kapanir.
//  sec kipi: adres ara (Photon) ya da haritayi kaydir -> ortadaki igne gonderilir; "Anlik konumum" GPS'i yalnizca o an acar
//  goster kipi: gelen konumu isaretle; Google Maps baglantisi, kendi konumuna gore uzaklik
// Baglam: "gps" (GpsKonum) context property'si olmali.
Rectangle {
    id: kok
    visible: false
    color: koyu ? "#111b21" : "#ffffff"

    property bool koyu: false
    property string sunucu: ""              // doluysa arama sunucudan (/api/geo/ara), bossa dogrudan Photon (HTTPS)
    property string anahtar: ""
    property bool gosterKipi: false
    property string secAd: ""
    property string secAdres: ""
    property bool gpsBekliyor: false        // "anlik konumumu gonder"e basildi, ilk sonuc bekleniyor
    property bool gpsGonder: false

    property color cYazi: koyu ? "#e9edef" : "#111b21"
    property color cIkinci: koyu ? "#8696a0" : "#667781"
    property color cYuzey: koyu ? "#202c33" : "#f0f2f5"
    property color cVurgu: "#00a884"

    signal gonder(real lat, real lng, string ad, string adres)
    signal kapandi()

    function ac(lat, lng) {
        gosterKipi = false; secAd = ""; secAdres = ""; gpsBekliyor = false; gpsGonder = false;
        harita.isaretVar = false; harita.artiGoster = true; harita.rota = [];
        harita.katman = koyu ? "koyu" : "acik";
        if (lat !== undefined && lat !== null) harita.merkezle(lat, lng, 15);
        else if (sonLat !== 0) harita.merkezle(sonLat, sonLng, 14);
        visible = true;
        sonuc.model.clear();
        alan.text = "";
        harita.forceActiveFocus();
    }
    function goster(lat, lng, ad, adres) {
        gosterKipi = true; secAd = ad || ""; secAdres = adres || ""; gpsBekliyor = false; gpsGonder = false;
        harita.artiGoster = false; harita.isaretVar = true; harita.isaretLat = lat; harita.isaretLng = lng; harita.rota = [];
        harita.katman = koyu ? "koyu" : "acik";
        harita.merkezle(lat, lng, 16);
        visible = true;
        sonuc.model.clear();
        harita.forceActiveFocus();
    }
    function kapat() { if (gps.aktif) gps.durdur(); visible = false; kapandi(); }

    property real sonLat: 0
    property real sonLng: 0

    // ---- arama ----
    property int aramaNo: 0
    property bool araniyor: false
    function ara(q) {
        q = (q || "").replace(/^\s+|\s+$/g, "");
        if (q === "") return;
        var no = ++aramaNo;
        araniyor = true;
        sonuc.model.clear();
        var lat = harita.merkezLat(), lng = harita.merkezLng();
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== 4 || no !== kok.aramaNo) return;
            kok.araniyor = false;
            var l = [];
            try {
                var j = JSON.parse(x.responseText);
                if (j.sonuclar) l = j.sonuclar;
                else if (j.features) for (var i = 0; i < j.features.length; i++) l.push(H.photonOge(j.features[i]));
            } catch (e) { }
            if (x.status !== 200 || l.length === 0) {
                sonuc.model.append({ ad: x.status === 0 ? qsTr("Bağlanılamadı") : (x.status === 200 ? qsTr("Sonuç bulunamadı") : qsTr("Arama yapılamadı (") + x.status + ")"), adres: "", lat: 0, lng: 0, bos: true });
                return;
            }
            for (var k = 0; k < l.length; k++) if (!isNaN(l[k].lat)) sonuc.model.append({ ad: l[k].ad || qsTr("(adsız)"), adres: l[k].adres || "", lat: l[k].lat, lng: l[k].lng, bos: false });
        };
        if (sunucu !== "") {
            x.open("GET", sunucu + "/api/geo/ara?q=" + encodeURIComponent(q) + "&lat=" + lat + "&lng=" + lng);
            if (anahtar !== "") x.setRequestHeader("X-Api-Key", anahtar); if (typeof dil !== "undefined") x.setRequestHeader("X-Lang", dil.kod);
        } else {
            x.open("GET", "https://photon.komoot.io/api/?limit=10&q=" + encodeURIComponent(q) + "&lat=" + lat + "&lon=" + lng);
        }
        x.send();
    }
    function sonucSec(i) {
        var o = sonuc.model.get(i);
        if (o.bos) return;
        secAd = o.ad; secAdres = o.adres;
        harita.merkezle(o.lat, o.lng, 17);
        sonuc.model.clear();
        alan.closeSoftwareInputPanel();
        harita.forceActiveFocus();
    }

    // ---- GPS ----
    Connections {
        target: gps
        onBulundu: {
            if (!kok.visible) return;
            kok.sonLat = lat; kok.sonLng = lng;
            harita.konumVar = true; harita.konumLat = lat; harita.konumLng = lng; harita.konumDogruluk = dogruluk;
            if (kok.gpsBekliyor) {
                harita.merkezle(lat, lng, Math.max(harita.zoom, 16));
                if (kok.gpsGonder && dogruluk <= 150) {
                    kok.gpsBekliyor = false; kok.gpsGonder = false;
                    gps.durdur();
                    kok.gonder(lat, lng, qsTr("Anlık konum"), "");
                    kok.kapat();
                }
            }
        }
        onHata: { kok.gpsBekliyor = false; kok.gpsGonder = false; ipucu.goster(mesaj); }
    }
    function anlikGonder() {
        gpsBekliyor = true; gpsGonder = true;
        gps.baslat(false);
        ipucu.goster(qsTr("Konum aranıyor… (uydu araması açık havada daha hızlıdır)"));
    }
    function konumumuGoster() { gpsBekliyor = true; gpsGonder = false; gps.baslat(false); }

    // ---- ust cubuk ----
    Rectangle {
        id: ust
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 64
        color: kok.koyu ? "#202c33" : "#008069"
        z: 3
        Rectangle {
            id: geri
            anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
            width: 50; height: 50; radius: 25
            color: gma.pressed ? "#33ffffff" : "transparent"
            // geri oku (cizilmis: yazi tipinde "‹" bos kutu cikabiliyor)
            Rectangle { x: 15; y: 19; width: 16; height: 4; radius: 2; color: "white"; rotation: -45; transformOrigin: Item.Left; smooth: true }
            Rectangle { x: 15; y: 28; width: 16; height: 4; radius: 2; color: "white"; rotation: 45; transformOrigin: Item.Left; smooth: true }
            Rectangle { x: 15; y: 23.5; width: 22; height: 4; radius: 2; color: "white" }
            MouseArea { id: gma; anchors.fill: parent; onClicked: kok.kapat() }
        }
        Text {
            visible: kok.gosterKipi
            anchors { left: geri.right; leftMargin: 8; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            text: kok.secAd !== "" ? kok.secAd : qsTr("Konum")
            color: "white"; font.pixelSize: 22; font.bold: true; elide: Text.ElideRight
        }
        Rectangle {
            visible: !kok.gosterKipi
            anchors { left: geri.right; leftMargin: 6; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            height: 46; radius: 23
            color: kok.koyu ? "#2a3942" : "white"
            TextInput {
                id: alan
                anchors { left: parent.left; leftMargin: 18; right: araDugme.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                font.pixelSize: 21
                color: kok.cYazi
                selectByMouse: true
                Keys.onReturnPressed: kok.ara(text)
                Keys.onEnterPressed: kok.ara(text)
                Keys.onDownPressed: { if (sonuc.model.count > 0) { sonuc.currentIndex = 0; sonuc.forceActiveFocus(); } else harita.forceActiveFocus(); }
            }
            Text {
                anchors { left: alan.left; verticalCenter: parent.verticalCenter }
                visible: alan.text === "" && !alan.activeFocus
                text: qsTr("Adres, yer ya da işletme ara")
                color: kok.cIkinci; font.pixelSize: 20
            }
            MouseArea { anchors.fill: alan; enabled: !alan.activeFocus; onClicked: { alan.forceActiveFocus(); alan.openSoftwareInputPanel(); } }
            Rectangle {
                id: araDugme
                anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                width: 40; height: 40; radius: 20
                color: ama.pressed ? "#3300a884" : "transparent"
                Text { anchors.centerIn: parent; text: kok.araniyor ? "…" : qsTr("Ara"); font.pixelSize: 16; font.bold: true; color: kok.cVurgu }
                MouseArea { id: ama; anchors.fill: parent; onClicked: kok.ara(alan.text) }
            }
        }
    }

    Harita {
        id: harita
        anchors { left: parent.left; right: parent.right; top: ust.bottom; bottom: alt.top }
        focus: true
        onDokunuldu: if (!kok.gosterKipi) { kok.secAd = ""; kok.secAdres = ""; harita.merkezle(lat, lng); }
        Keys.onPressed: {
            var k = event.key;
            if (k === Qt.Key_Left) harita.kaydir(-80, 0);
            else if (k === Qt.Key_Right) harita.kaydir(80, 0);
            else if (k === Qt.Key_Up) harita.kaydir(0, -80);
            else if (k === Qt.Key_Down) harita.kaydir(0, 80);
            else if (event.text === "+" || event.text === "*" || k === Qt.Key_Plus) harita.yakinlas(1);
            else if (event.text === "-" || event.text === "#" || k === Qt.Key_Minus) harita.yakinlas(-1);
            else if (k === Qt.Key_Select || k === Qt.Key_Return || k === Qt.Key_Enter) { if (!kok.gosterKipi) kok.noktaGonder(); }
            else if (k === Qt.Key_Backspace || k === Qt.Key_Escape) kok.kapat();
            else if (!kok.gosterKipi && event.text !== "" && event.text.charCodeAt(0) > 32) { alan.text = event.text; alan.forceActiveFocus(); }
            else return;
            event.accepted = true;
        }
    }

    // ---- GPS durumu: yalnizca konum aranirken / az once arandiysa gorunur ----
    Rectangle {
        id: gpsSerit
        anchors { left: parent.left; right: parent.right; top: ust.bottom }
        height: visible ? gpsYazi.paintedHeight + 16 : 0
        visible: gps.aktif || gpsGosterSure.running
        color: gps.aktif ? "#e61a73e8" : "#e6202124"
        z: 3
        Rectangle {
            id: gpsNokta
            x: 14; anchors.verticalCenter: parent.verticalCenter
            width: 12; height: 12; radius: 6; color: "white"
            SequentialAnimation on opacity { running: gps.aktif; loops: Animation.Infinite; NumberAnimation { to: 0.2; duration: 500 } NumberAnimation { to: 1; duration: 500 } }
        }
        Text {
            id: gpsYazi
            anchors { left: gpsNokta.right; leftMargin: 10; right: gpsDur.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            text: gps.durum; color: "white"; font.pixelSize: 16; wrapMode: Text.Wrap
        }
        Text {
            id: gpsDur
            visible: gps.aktif
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            text: qsTr("Durdur"); color: "white"; font.pixelSize: 16; font.bold: true
            MouseArea { anchors { fill: parent; margins: -12 } onClicked: { gps.durdur(); kok.gpsBekliyor = false; kok.gpsGonder = false; } }
        }
    }
    Timer { id: gpsGosterSure; interval: 6000 }
    Connections { target: gps; onAktifDegisti: if (!gps.aktif) gpsGosterSure.restart() }

    // konum amblemi: basinca GPS acilir, konum bulununca haritada gosterilir ve GPS kapanir
    Rectangle {
        anchors { left: parent.left; leftMargin: 10; bottom: alt.top; bottomMargin: 12 }
        width: 52; height: 52; radius: 26; z: 3
        color: kma.pressed ? "#dadce0" : "white"
        border.color: "#c4c7c5"; border.width: 1
        smooth: true
        Rectangle { anchors.centerIn: parent; width: 26; height: 26; radius: 13; color: "transparent"; border.width: 3; border.color: gps.aktif ? "#1a73e8" : "#5f6368"; smooth: true }
        Rectangle { anchors.centerIn: parent; width: 10; height: 10; radius: 5; color: gps.aktif ? "#1a73e8" : "#5f6368"; smooth: true }
        Rectangle { anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 8 } width: 3; height: 8; color: gps.aktif ? "#1a73e8" : "#5f6368" }
        Rectangle { anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 8 } width: 3; height: 8; color: gps.aktif ? "#1a73e8" : "#5f6368" }
        MouseArea { id: kma; anchors.fill: parent; onClicked: { if (gps.aktif) { gps.durdur(); kok.gpsBekliyor = false; } else kok.konumumuGoster(); } }
    }

    function noktaGonder() {
        var lat = harita.merkezLat(), lng = harita.merkezLng();
        gonder(lat, lng, secAd, secAdres);
        kapat();
    }

    // ---- arama sonuclari ----
    Rectangle {
        anchors { left: parent.left; right: parent.right; top: ust.bottom }
        height: Math.min(sonuc.count * 64, kok.height * 0.55)
        visible: sonuc.count > 0
        color: kok.koyu ? "#111b21" : "white"
        z: 4
        ListView {
            id: sonuc
            anchors.fill: parent
            clip: true
            model: ListModel { }
            delegate: Rectangle {
                width: sonuc.width; height: 64
                color: sma.pressed || (sonuc.activeFocus && ListView.isCurrentItem) ? kok.cYuzey : "transparent"
                Text { x: 18; y: 8; width: parent.width - 30; text: ad; font.pixelSize: 20; font.bold: !bos; color: kok.cYazi; elide: Text.ElideRight }
                Text { x: 18; y: 36; width: parent.width - 30; text: adres; font.pixelSize: 16; color: kok.cIkinci; elide: Text.ElideRight }
                Rectangle { anchors.bottom: parent.bottom; x: 18; width: parent.width - 18; height: 1; color: kok.koyu ? "#222d34" : "#e9edef" }
                MouseArea { id: sma; anchors.fill: parent; onClicked: kok.sonucSec(index) }
            }
            Keys.onReturnPressed: kok.sonucSec(currentIndex)
            Keys.onSelectPressed: kok.sonucSec(currentIndex)
            Keys.onUpPressed: { if (currentIndex <= 0) alan.forceActiveFocus(); else decrementCurrentIndex(); }
        }
    }

    // ---- alt panel ----
    Rectangle {
        id: alt
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: altKolon.height + 20
        color: kok.koyu ? "#111b21" : "white"
        Rectangle { width: parent.width; height: 1; color: kok.koyu ? "#222d34" : "#e9edef" }
        Column {
            id: altKolon
            x: 14; y: 10
            width: parent.width - 28
            spacing: 8
            Text {
                width: parent.width
                text: kok.secAd !== "" ? kok.secAd : (kok.gosterKipi ? qsTr("Konum") : qsTr("Haritayı kaydırın: iğnenin olduğu yer gönderilir"))
                font.pixelSize: 19; font.bold: kok.secAd !== ""; color: kok.cYazi; elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: (kok.secAdres !== "" ? kok.secAdres + " • " : "") + (kok.gosterKipi ? H.koordinatMetni(harita.isaretLat, harita.isaretLng)
                       + (harita.konumVar ? " • " + H.mesafeMetni(H.mesafe(harita.konumLat, harita.konumLng, harita.isaretLat, harita.isaretLng)) + qsTr(" uzakta") : "")
                       : H.koordinatMetni(harita.merkezLat(), harita.merkezLng()) + (harita.cx > -1 ? "" : ""))
                font.pixelSize: 15; color: kok.cIkinci; elide: Text.ElideRight
            }
            Row {
                spacing: 10
                // sec kipi
                Dugme2 { visible: !kok.gosterKipi; metin: qsTr("Bu konumu gönder"); ana: true; onTik: kok.noktaGonder() }
                Dugme2 { visible: !kok.gosterKipi; metin: kok.gpsBekliyor ? qsTr("Aranıyor…") : qsTr("Anlık konumum"); onTik: if (!kok.gpsBekliyor) kok.anlikGonder(); else { gps.durdur(); kok.gpsBekliyor = false; } }
                // goster kipi
                Dugme2 { visible: kok.gosterKipi; metin: qsTr("Google Maps"); ana: true; onTik: Qt.openUrlExternally(H.googleUrl(harita.isaretLat, harita.isaretLng)) }
                Dugme2 { visible: kok.gosterKipi; metin: kok.gpsBekliyor ? qsTr("Aranıyor…") : qsTr("Benim konumum"); onTik: kok.konumumuGoster() }
                Dugme2 { visible: kok.gosterKipi; metin: qsTr("Ortala"); onTik: harita.merkezle(harita.isaretLat, harita.isaretLng, 16) }
            }
        }
    }

    // kucuk ipucu
    Rectangle {
        id: ipucu
        anchors { horizontalCenter: parent.horizontalCenter; bottom: alt.top; bottomMargin: 12 }
        width: Math.min(kok.width - 40, ipt.paintedWidth + 30); height: ipt.paintedHeight + 18
        radius: 10; color: "#e6202124"; opacity: 0; z: 5
        Behavior on opacity { NumberAnimation { duration: 200 } }
        function goster(m) { ipt.text = m; opacity = 1; ipz.restart(); }
        Text { id: ipt; anchors.centerIn: parent; width: kok.width - 70; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; color: "white"; font.pixelSize: 16 }
        Timer { id: ipz; interval: 3500; onTriggered: ipucu.opacity = 0 }
    }
}
