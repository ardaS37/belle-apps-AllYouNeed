import QtQuick 1.1
import BelleMaps 1.0
import "HaritaJs.js" as H

// Hafif karo haritasi: surukle, iki parmakla / cift dokunla yakinlas, isaret, anlik konum, rota cizgisi.
// Durum dunya pikseli olarak tutulur (cx, cy @ zoom); lat/lng okumak icin merkezLat()/merkezLng().
Item {
    id: harita
    clip: true

    property int zoom: 12
    property real cx: H.lngX(28.9784, 12)          // merkez (dunya pikseli)
    property real cy: H.latY(41.0082, 12)
    property string katman: "acik"
    property bool koyu: H.koyuMu(katman)

    // isaret (secilen / gonderilen nokta)
    property bool isaretVar: false
    property real isaretLat: 0
    property real isaretLng: 0
    property string isaretAd: ""
    // anlik konum (GPS)
    property bool konumVar: false
    property real konumLat: 0
    property real konumLng: 0
    property real konumDogruluk: 0
    // rota: [[lat,lng], ...]
    property variant rota: []
    property bool artiGoster: false                 // merkezde nisangah (nokta secerken)
    property bool dugmeler: true

    signal dokunuldu(real lat, real lng)
    signal uzunBasildi(real lat, real lng)
    signal isaretTiklandi()
    signal degisti()                                // merkez / yakinlik degisti
    signal elleOynandi()                            // kullanici surukledi / yakinlastirdi (konum takibi birakilsin)

    // Saglayicinin en yuksek seviyesinden sonra da yakinlasilir: o seviyenin karolari buyutulerek gosterilir
    property int enCokGoster: 20
    property int kz: Math.min(zoom, enCok())                      // indirilen karo seviyesi
    property real ks: 256 * Math.pow(2, zoom - kz)                 // ekrandaki karo boyu

    function enCok() { return H.katman(katman).enCok; }
    function merkezLat() { return H.yLat(cy, zoom); }
    function merkezLng() { return H.xLng(cx, zoom); }
    function merkezle(lat, lng, z) {
        katmanKutu.olcek = 1;
        if (z !== undefined && z !== null) zoom = Math.max(2, Math.min(enCokGoster, z));
        cx = H.lngX(lng, zoom);
        cy = H.latY(lat, zoom);
        degisti();
    }
    function ekranLat(sy) { return H.yLat(cy - height / 2 + sy, zoom); }
    function ekranLng(sx) { return H.xLng(cx - width / 2 + sx, zoom); }
    function sx(lng) { return H.lngX(lng, zoom) - cx + width / 2; }
    function sy(lat) { return H.latY(lat, zoom) - cy + height / 2; }
    function kaydir(dx, dy) {
        var dunya = 256 * (1 << zoom);
        cx = ((cx + dx) % dunya + dunya) % dunya;
        cy = Math.max(0, Math.min(dunya, cy + dy));
        degisti();
    }
    // (px, py) ekrandaki noktayi yerinde tutarak yakinlas
    function yakinlas(adim, px, py) {
        katmanKutu.olcek = 1;
        var yeni = Math.max(2, Math.min(enCokGoster, zoom + adim));
        if (yeni === zoom) return;
        if (px === undefined) { px = width / 2; py = height / 2; }
        var lat = ekranLat(py), lng = ekranLng(px);
        zoom = yeni;
        cx = H.lngX(lng, zoom) - (px - width / 2);
        cy = H.latY(lat, zoom) - (py - height / 2);
        degisti();
    }
    // birden cok noktayi sigdir: [[lat,lng],...]
    // sigdirma hesabi: [z, lat, lng] (haritayi degistirmez)
    function sigdirHesap(noktalar) {
        var a = 90, b = -90, c = 180, d = -180;
        for (var i = 0; i < noktalar.length; i++) {
            a = Math.min(a, noktalar[i][0]); b = Math.max(b, noktalar[i][0]);
            c = Math.min(c, noktalar[i][1]); d = Math.max(d, noktalar[i][1]);
        }
        var z = 18;
        while (z > 2 && (H.lngX(d, z) - H.lngX(c, z) > width - 60 || H.latY(a, z) - H.latY(b, z) > height - 80)) z--;
        return [z, (a + b) / 2, (c + d) / 2];
    }
    // Kademeli sigdirma: yakinlik her adimda bir seviye degisir (elle yakinlastirma gibi), sonra merkeze kaydirilir.
    // Tek seferde 7 seviye atlamak (ornegin 100+ km'lik rota) Symbian'da cokmeye yol aciyordu.
    property int hedefZ: -1
    property real hedefLat: 0
    property real hedefLng: 0
    function kademeliSigdir(noktalar) {
        if (!noktalar || noktalar.length === 0) return;
        var h = sigdirHesap(noktalar);
        kademeliGit(h[0], h[1], h[2]);
    }
    // Verilen yakinlik ve merkeze adim adim git. Yakinlasirken once kaydirilir (uzak gorunumde kucuk kaydirma),
    // uzaklasirken once uzaklasilir, sonra kaydirilir.
    function kademeliGit(z, lat, lng) {
        z = Math.max(2, Math.min(enCokGoster, z));
        if (z > zoom) merkezle(lat, lng, zoom);
        hedefZ = z; hedefLat = lat; hedefLng = lng;
        sigdirZaman.restart();
    }
    Timer {
        id: sigdirZaman; interval: 300; repeat: true
        onTriggered: {
            console.log("iz: kademeli z" + harita.zoom + " -> " + harita.hedefZ);
            if (harita.zoom > harita.hedefZ) harita.yakinlas(-1);
            else if (harita.zoom < harita.hedefZ) harita.yakinlas(1);
            else { stop(); harita.merkezle(harita.hedefLat, harita.hedefLng, harita.zoom); harita.hedefZ = -1; }
        }
    }
    onElleOynandi: sigdirZaman.stop()          // kullanici haritayi ellerse kademeli sigdirma birakilir
    function sigdir(noktalar) {
        if (!noktalar || noktalar.length === 0) return;
        var a = 90, b = -90, c = 180, d = -180;
        for (var i = 0; i < noktalar.length; i++) {
            a = Math.min(a, noktalar[i][0]); b = Math.max(b, noktalar[i][0]);
            c = Math.min(c, noktalar[i][1]); d = Math.max(d, noktalar[i][1]);
        }
        var z = 18;
        while (z > 2 && (H.lngX(d, z) - H.lngX(c, z) > width - 60 || H.latY(a, z) - H.latY(b, z) > height - 80)) z--;
        merkezle((a + b) / 2, (c + d) / 2, z);
    }

    Rectangle { anchors.fill: parent; color: harita.koyu ? "#1b1d22" : "#eae6df" }

    // ---- karolar ----
    Item {
        id: katmanKutu
        width: harita.width; height: harita.height
        transformOrigin: Item.TopLeft
        property real olcek: 1
        property real ox: 0
        property real oy: 0
        transform: Scale { origin.x: katmanKutu.ox; origin.y: katmanKutu.oy; xScale: katmanKutu.olcek; yScale: katmanKutu.olcek }

        property int sutun: Math.ceil(harita.width / harita.ks) + 1
        property int satir: Math.ceil(harita.height / harita.ks) + 1
        property int bx: Math.floor((harita.cx - harita.width / 2) / harita.ks)
        property int by: Math.floor((harita.cy - harita.height / 2) / harita.ks)

        Repeater {
            model: katmanKutu.sutun * katmanKutu.satir
            Image {
                id: karoResim
                property int tx: katmanKutu.bx + index % katmanKutu.sutun
                property int ty: katmanKutu.by + Math.floor(index / katmanKutu.sutun)
                // karo C++'ta indirilir (karoYukleyici); QML yalnizca kartta hazir dosyayi acar
                property string uzak: H.karoUrl(harita.katman, harita.kz, tx, ty)
                property int surum: 0
                x: Math.round(tx * harita.ks - (harita.cx - harita.width / 2))
                y: Math.round(ty * harita.ks - (harita.cy - harita.height / 2))
                width: harita.ks; height: harita.ks
                asynchronous: true
                cache: true
                smooth: harita.ks > 256
                source: karoYukleyici.yerel(uzak, surum)
                Connections { target: karoYukleyici; onHazir: if (url === karoResim.uzak) karoResim.surum++ }
            }
        }

        // ---- rota cizgisi: tek oge, tek polyline (C++). Eskiden her parca bir Rectangle idi:
        //      uzun rotada binlerce oge "hafiza dolu" ile uygulamayi kapatiyordu ----
        RotaCizgi {
            width: harita.width; height: harita.height
            visible: harita.rota.length > 1
            noktalar: harita.rota
            cx: harita.cx; cy: harita.cy; zoom: harita.zoom
        }

        // ---- anlik konum ----
        Item {
            visible: harita.konumVar
            x: harita.sx(harita.konumLng); y: harita.sy(harita.konumLat)
            Rectangle {     // dogruluk halkasi
                property real r: Math.min(400, harita.konumDogruluk / (156543.03 * Math.cos(harita.konumLat * Math.PI / 180) / (1 << harita.zoom)))
                width: 2 * r; height: width; radius: r
                x: -r; y: -r
                color: "#331a73e8"; border.color: "#661a73e8"; border.width: 1
                visible: r > 14
            }
            Rectangle { x: -11; y: -11; width: 22; height: 22; radius: 11; color: "white"; smooth: true }
            Rectangle { x: -8; y: -8; width: 16; height: 16; radius: 8; color: "#1a73e8"; smooth: true }
        }

        // ---- isaret (ignesi noktaya bakar) ----
        Item {
            id: isaret
            visible: harita.isaretVar
            x: harita.sx(harita.isaretLng); y: harita.sy(harita.isaretLat)
            Rectangle { x: -15; y: -44; width: 30; height: 30; radius: 15; color: "#ea4335"; border.color: "#b31412"; border.width: 2; smooth: true }
            Rectangle { x: -6; y: -35; width: 12; height: 12; radius: 6; color: "white"; smooth: true }
            Rectangle { x: -2; y: -16; width: 4; height: 16; color: "#b31412" }
            Rectangle { x: -4; y: -2; width: 8; height: 4; radius: 2; color: "#55000000" }
            MouseArea { x: -22; y: -50; width: 44; height: 52; onClicked: harita.isaretTiklandi() }
        }
    }

    // ---- dokunma: surukle / dokun / uzun bas / cift dokun ----
    PinchArea {
        id: pinch
        anchors.fill: parent
        pinch.minimumScale: 0.12
        pinch.maximumScale: 8
        onPinchStarted: { harita.elleOynandi(); katmanKutu.ox = pinch.center.x; katmanKutu.oy = pinch.center.y; katmanKutu.olcek = 1; }
        onPinchUpdated: katmanKutu.olcek = pinch.scale
        onPinchFinished: {
            var s = katmanKutu.olcek;
            katmanKutu.olcek = 1;
            var adim = Math.round(Math.log(s) / Math.LN2);
            if (adim !== 0) harita.yakinlas(adim, pinch.center.x, pinch.center.y);
        }
        MouseArea {
            anchors.fill: parent
            property real sonX: 0
            property real sonY: 0
            property real basX: 0
            property real basY: 0
            property bool surukledi: false
            onPressed: { sonX = mouse.x; sonY = mouse.y; basX = mouse.x; basY = mouse.y; surukledi = false; }
            onPositionChanged: {
                if (!surukledi && Math.abs(mouse.x - basX) + Math.abs(mouse.y - basY) < 12) return;
                if (!surukledi) harita.elleOynandi();
                surukledi = true;
                harita.kaydir(sonX - mouse.x, sonY - mouse.y);
                sonX = mouse.x; sonY = mouse.y;
            }
            onClicked: if (!surukledi) harita.dokunuldu(harita.ekranLat(mouse.y), harita.ekranLng(mouse.x))
            onPressAndHold: if (!surukledi) harita.uzunBasildi(harita.ekranLat(mouse.y), harita.ekranLng(mouse.x))
            onDoubleClicked: { harita.elleOynandi(); harita.yakinlas(1, mouse.x, mouse.y); }
        }
    }

    // ---- merkez nisangahi ----
    Item {
        visible: harita.artiGoster
        anchors.centerIn: parent
        Rectangle { x: -15; y: -44; width: 30; height: 30; radius: 15; color: "#ea4335"; border.color: "#b31412"; border.width: 2; smooth: true }
        Rectangle { x: -6; y: -35; width: 12; height: 12; radius: 6; color: "white"; smooth: true }
        Rectangle { x: -2; y: -16; width: 4; height: 16; color: "#b31412" }
        Rectangle { x: -4; y: -2; width: 8; height: 4; radius: 2; color: "#55000000" }
    }

    // ---- yakinlastirma dugmeleri ----
    Column {
        visible: harita.dugmeler
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        spacing: 8
        // + ve - cizilerek (Belle yazi tipinde bazi isaretler bos kutu gorunuyor)
        Repeater {
            model: 2
            Rectangle {
                width: 48; height: 48; radius: 24
                color: zma.pressed ? (harita.koyu ? "#3c4043" : "#dadce0") : (harita.koyu ? "#2b2e33" : "white")
                border.color: harita.koyu ? "#44484e" : "#c4c7c5"; border.width: 1
                smooth: true
                Rectangle { anchors.centerIn: parent; width: 20; height: 4; radius: 1; color: harita.koyu ? "#e8eaed" : "#3c4043" }
                Rectangle { anchors.centerIn: parent; width: 4; height: 20; radius: 1; visible: index === 0; color: harita.koyu ? "#e8eaed" : "#3c4043" }
                MouseArea { id: zma; anchors.fill: parent; onClicked: { harita.elleOynandi(); harita.yakinlas(index === 0 ? 1 : -1); } }
            }
        }
    }

    Rectangle {
        anchors { right: parent.right; bottom: parent.bottom }
        width: telifYazi.paintedWidth + 8; height: telifYazi.paintedHeight + 2
        color: harita.koyu ? "#99000000" : "#99ffffff"
        Text { id: telifYazi; anchors.centerIn: parent; text: H.katman(harita.katman).telif; font.pixelSize: 11; color: harita.koyu ? "#c0c4c8" : "#3c4043" }
    }
}
