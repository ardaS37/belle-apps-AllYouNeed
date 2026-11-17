import QtQuick 1.1
import "HaritaJs.js" as H

// Belle Maps: ara, konumum, katmanlar, kayitli yerler, rota (OSRM), karo onbellegi.
// Klavye: oklar kaydir • +/- (ya da * #) yakinlas • S ara • G konumum • K katman • Y kayitli yerler • M menu • Enter: ortadaki yer
Rectangle {
    id: app
    width: 640; height: 480
    color: koyu ? "#1b1d22" : "#ffffff"

    property bool koyu: H.koyuMu(harita.katman)
    property color cZemin: koyu ? "#202124" : "#ffffff"
    property color cYuzey: koyu ? "#2b2e33" : "#f1f3f4"
    property color cYazi: koyu ? "#e8eaed" : "#202124"
    property color cIkinci: koyu ? "#9aa0a6" : "#5f6368"
    property color cCizgi: koyu ? "#3c4043" : "#dadce0"
    property color cVurgu: koyu ? "#8ab4f8" : "#1a73e8"

    // secili yer (arama sonucu / uzun basma / kayitli yer)
    property bool yerVar: false
    property string yerAd: ""
    property string yerAdres: ""
    property real yerLat: 0
    property real yerLng: 0
    // rota
    property bool rotaVar: false
    property string rotaBilgi: ""
    property bool rotaBekliyor: false        // GPS sonucu gelince rota cizilecek
    property bool takip: false               // haritayi konumla birlikte kaydir

    property variant yerler: []              // kayitli yerler [{ad, adres, lat, lng}]
    property bool sunucuAra: arac.ayar("sunucuAra", "0") === "1"
    property string sunucu: { var s = ("" + arac.ayar("sunucu", "")).replace(/\/+$/, ""); return (s === "" || s.indexOf("203.0.113.10") >= 0) ? "https://e6.msahincelen.xyz" : s; }   // eski IP -> yeni adres
    property string anahtar: arac.ayar("anahtar", "")

    function bildir(m) { tost.goster(m); }

    // ---------- kayitli yerler ----------
    function yerleriYukle() { try { yerler = JSON.parse(arac.ayar("yerler", "[]")); } catch (e) { yerler = []; } }
    function yerleriKaydet(l) { yerler = l; arac.setAyar("yerler", JSON.stringify(l)); }
    function kayitliMi(lat, lng) {
        for (var i = 0; i < yerler.length; i++) if (Math.abs(yerler[i].lat - lat) < 0.00002 && Math.abs(yerler[i].lng - lng) < 0.00002) return i;
        return -1;
    }
    function yerKaydetSil() { adAc(kayitliMi(yerLat, yerLng)); }

    // ---------- kayitli yere ad verme ----------
    property int adNo: -1                    // duzenlenen kayit (-1: secili yer yeni kaydedilecek)
    function adAc(i) {
        adNo = i;
        var o = i >= 0 ? yerler[i] : null;
        var oneri = o ? o.ad : (yerAd !== "" ? yerAd : (yerAdres !== "" ? yerAdres.split(",")[0] : ""));
        adSayfa.ac(oneri, o ? (o.adres !== "" ? o.adres : H.koordinatMetni(o.lat, o.lng)) : (yerAdres !== "" ? yerAdres : H.koordinatMetni(yerLat, yerLng)));
    }
    function adKaydet(metin) {
        var ad = (metin || "").replace(/^\s+|\s+$/g, "");
        var l = yerler.slice(0);
        if (adNo >= 0 && adNo < l.length) {
            var o = l[adNo];
            if (ad === "") ad = o.ad;
            l[adNo] = { ad: ad, adres: o.adres, lat: o.lat, lng: o.lng };
            if (yerVar && Math.abs(o.lat - yerLat) < 0.00002 && Math.abs(o.lng - yerLng) < 0.00002) yerAd = ad;
        } else {
            if (ad === "") ad = H.koordinatMetni(yerLat, yerLng);
            l.unshift({ ad: ad, adres: yerAdres, lat: yerLat, lng: yerLng });
            yerAd = ad;
        }
        yerleriKaydet(l);
        bildir(qsTr("Kaydedildi: ") + ad);
    }
    function adSil() {
        if (adNo < 0 || adNo >= yerler.length) return;
        var l = yerler.slice(0), ad = l[adNo].ad;
        l.splice(adNo, 1);
        yerleriKaydet(l);
        bildir(qsTr("Silindi: ") + ad);
    }

    // ---------- secim ----------
    function yerSec(lat, lng, ad, adres, ortala) {
        yerVar = true; yerAd = ad || ""; yerAdres = adres || ""; yerLat = lat; yerLng = lng;
        harita.isaretVar = true; harita.isaretLat = lat; harita.isaretLng = lng;
        if (ortala) harita.merkezle(lat, lng, Math.max(harita.zoom, 16));
    }
    function yerKapat() { yerVar = false; harita.isaretVar = false; }

    // ---------- arama ----------
    property int aramaNo: 0
    property bool araniyor: false
    function ara(q) {
        q = (q || "").replace(/^\s+|\s+$/g, "");
        if (q === "") return;
        // koordinat yazildiysa dogrudan git ("41.03, 28.98")
        var k = /^(-?\d+(?:\.\d+)?)\s*[, ]\s*(-?\d+(?:\.\d+)?)$/.exec(q) ? null : H.metindenKonum(q);
        var c = /^(-?\d+(?:\.\d+)?)\s*[, ]\s*(-?\d+(?:\.\d+)?)$/.exec(q);
        if (c) k = { lat: parseFloat(c[1]), lng: parseFloat(c[2]) };
        if (k) { sonuclar.clear(); yerSec(k.lat, k.lng, "", "", true); aramaKutu.kapat(); return; }
        aramaYap(q, sunucuAra);
    }
    function aramaYap(q, sunucudan) {
        var no = ++aramaNo;
        araniyor = true;
        sonuclar.clear();
        var lat = harita.merkezLat(), lng = harita.merkezLng();
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== 4 || no !== app.aramaNo) return;
            app.araniyor = false;
            var l = [];
            try {
                var j = JSON.parse(x.responseText);
                if (j.sonuclar) l = j.sonuclar;
                else if (j.features) for (var i = 0; i < j.features.length; i++) l.push(H.photonOge(j.features[i]));
            } catch (e) { }
            if (x.status === 200 && l.length > 0) {
                for (var n = 0; n < l.length; n++) if (!isNaN(l[n].lat))
                    sonuclar.append({ ad: l[n].ad || qsTr("(adsız)"), adres: l[n].adres || "", lat: l[n].lat, lng: l[n].lng, bos: false,
                                      uzak: H.mesafeMetni(H.mesafe(lat, lng, l[n].lat, l[n].lng)) });
                return;
            }
            var mesaj = x.status === 200 ? qsTr("Sonuç bulunamadı") : (sunucudan ? qsTr("Sunucu araması yapılamadı (") + x.status + ")" :
                        qsTr("Doğrudan arama yapılamadı: telefon bu siteyle güvenli bağlantı kuramıyor olabilir. Menü > Ayarlar > \"Aramada sunucuyu kullan\""));
            sonuclar.append({ ad: mesaj, adres: "", lat: 0, lng: 0, bos: true, uzak: "" });
        };
        if (sunucudan) {
            x.open("GET", sunucu + "/api/geo/ara?q=" + encodeURIComponent(q) + "&lat=" + lat + "&lng=" + lng);
            if (anahtar !== "") x.setRequestHeader("X-Api-Key", anahtar); x.setRequestHeader("X-Lang", dil.kod);
        } else {
            x.open("GET", "https://photon.komoot.io/api/?limit=10&q=" + encodeURIComponent(q) + "&lat=" + lat + "&lon=" + lng);
        }
        x.send();
    }

    // ---------- rota ve yolculuk (OSRM) ----------
    // Rota: hedefe arac rotasi cizilir. Basla: GPS surekli acik, harita konumu izler, siradaki donus ve
    // uzaklik gosterilir; rotadan cikinca yeniden hesaplanir, hedefe gelince biter.
    property bool yolculuk: false
    property variant adimlar: []          // [{ lat, lng, metin, m }]  (m: o adimin uzunlugu)
    property int adimNo: 0
    property real rotaHedefLat: 0
    property real rotaHedefLng: 0
    property string navMetin: ""
    property string navAlt: ""
    property real sonYeniden: 0

    function rotaCiz() {
        if (!yerVar) return;
        console.log("iz: rota istendi");
        if (rotaVar && Math.abs(rotaHedefLat - yerLat) < 1e-6 && Math.abs(rotaHedefLng - yerLng) < 1e-6) { yolculukBasla(); return; }
        rotaHedefLat = yerLat; rotaHedefLng = yerLng;
        if (!harita.konumVar) {
            rotaBekliyor = true;
            gps.baslat(false);
            bildir(qsTr("Konumunuz aranıyor; bulununca rota çizilecek"));
            return;
        }
        rotaIste(harita.konumLat, harita.konumLng, rotaHedefLat, rotaHedefLng, true);
    }
    function yonMetni(m) {
        var md = { "left": qsTr("sola"), "right": qsTr("sağa"), "slight left": qsTr("hafif sola"), "slight right": qsTr("hafif sağa"),
                   "sharp left": qsTr("keskin sola"), "sharp right": qsTr("keskin sağa"), "straight": qsTr("düz"), "uturn": qsTr("geri (U dönüşü)") }[m.modifier || ""] || "";
        var t = m.type, s;
        if (t === "depart") s = qsTr("Yola çıkın");
        else if (t === "arrive") s = qsTr("Hedefe vardınız");
        else if (t === "turn" || t === "end of road") s = (t === "end of road" ? qsTr("Yolun sonunda ") : "") + (md !== "" ? md + qsTr(" dönün") : qsTr("Dönün"));
        else if (t === "roundabout" || t === "rotary" || t === "roundabout turn") s = qsTr("Döner kavşaktan ") + (m.exit ? m.exit + qsTr(". çıkıştan") : "") + qsTr(" çıkın");
        else if (t === "fork") s = qsTr("Ayrımda ") + (md !== "" ? md : "") + qsTr(" kalın");
        else if (t === "merge") s = qsTr("Yola katılın");
        else if (t === "on ramp") s = qsTr("Bağlantı yoluna girin") + (md !== "" ? " (" + md + ")" : "");
        else if (t === "off ramp") s = qsTr("Çıkışa girin") + (md !== "" ? " (" + md + ")" : "");
        else s = md !== "" && md !== "düz" ? md.charAt(0).toUpperCase() + md.substring(1) + qsTr(" devam edin") : qsTr("Düz devam edin");
        return s;
    }
    // OSRM HTTPS artik yalnizca TLS 1.3 istiyor (telefonda 1.2 var); duz HTTP kullanilir, ikinci sunucu yedek
    property variant rotaSunuculari: ["http://router.project-osrm.org/route/v1/driving/", "http://routing.openstreetmap.de/routed-car/route/v1/driving/"]
    function rotaIste(lat1, lng1, lat2, lng2, sigdirsin, deneme) {
        deneme = deneme || 0;
        rotaBekliyor = false;
        if (!yolculuk && deneme === 0) bildir(qsTr("Rota hesaplanıyor…"));
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== 4) return;
            console.log("iz: rota yaniti " + x.status + ", " + (x.responseText ? x.responseText.length : 0) + " karakter");
            try {
                var j = JSON.parse(x.responseText);
                console.log("iz: rota json cozuldu");
                if (j.code === "Ok" && j.routes.length) {
                    var r = j.routes[0], l = [];
                    var nk = H.polylineCoz(r.geometry);
                    console.log("iz: rota " + nk.length + " nokta, cizgiye veriliyor");
                    harita.rota = nk;
                    console.log("iz: rota cizgiye verildi");
                    var legs = r.legs || [];
                    for (var a = 0; a < legs.length; a++) {
                        var st = legs[a].steps || [];
                        for (var b = 0; b < st.length; b++) {
                            var loc = st[b].maneuver.location, ad = st[b].name || "";
                            l.push({ lat: loc[1], lng: loc[0], m: st[b].distance, metin: app.yonMetni(st[b].maneuver) + (ad !== "" && st[b].maneuver.type !== "arrive" ? " • " + ad : "") });
                        }
                    }
                    console.log("iz: " + l.length + " adim");
                    app.adimlar = l;
                    app.adimNo = l.length > 1 ? 1 : 0;
                    app.rotaVar = true;
                    app.rotaBilgi = H.mesafeMetni(r.distance) + " • " + H.sureMetni(r.duration) + qsTr(" (araçla)");
                    console.log("iz: rota bilgisi yazildi, sigdiriliyor");
                    if (sigdirsin) app.rotaTumunuGoster();
                    console.log("iz: sigdirildi z" + harita.zoom);
                    if (app.yolculuk) app.navGuncelle(lat1, lng1);
                    return;
                }
            } catch (e) { console.log("iz: rota hatasi " + e); }
            var hata = x.status === 0 || x.status >= 500 || x.status === 429;
            if (hata && deneme + 1 < app.rotaSunuculari.length) { app.rotaIste(lat1, lng1, lat2, lng2, sigdirsin, deneme + 1); return; }
            app.bildir(hata ? qsTr("Rota sunucusuna ulaşılamadı") : qsTr("Rota bulunamadı"));
        };
        x.open("GET", app.rotaSunuculari[deneme] + lng1 + "," + lat1 + ";" + lng2 + "," + lat2 + "?overview=full&geometries=polyline&steps=true");
        x.send();
    }
    function rotaKapat() { yolculukBitir(); harita.rota = []; rotaVar = false; rotaBilgi = ""; adimlar = []; rotaTumu = false; }
    // Rota gorunumu: "Tumu" butun rotayi adim adim sigdirir, "Geri" onceki yakinlik ve konuma adim adim doner
    property bool rotaTumu: false
    property int oncekiZ: 16
    property real oncekiLat: 0
    property real oncekiLng: 0
    function rotaTumunuGoster() {
        var r = harita.rota;
        if (!r || r.length < 2) return;
        oncekiZ = harita.zoom; oncekiLat = harita.merkezLat(); oncekiLng = harita.merkezLng();
        takip = false;
        harita.kademeliSigdir(r);
        rotaTumu = true;
    }
    function rotaGeriDon() {
        rotaTumu = false;
        harita.kademeliGit(oncekiZ, oncekiLat, oncekiLng);
    }
    function yolculukBasla() {
        if (!rotaVar) return;
        console.log("iz: yolculuk basladi");
        yolculuk = true; takip = true; yerVar = false; harita.isaretVar = true;
        harita.isaretLat = rotaHedefLat; harita.isaretLng = rotaHedefLng;
        if (!gps.aktif) gps.baslat(false);
        if (harita.konumVar) { harita.merkezle(harita.konumLat, harita.konumLng, 17); navGuncelle(harita.konumLat, harita.konumLng); }
        else navMetin = qsTr("Konum bekleniyor…");
    }
    function yolculukBitir() {
        if (!yolculuk) return;
        yolculuk = false; takip = false; navMetin = ""; navAlt = "";
        gps.durdur();
    }
    // her konumda: siradaki adim, kalan yol, rotadan cikis
    function navGuncelle(lat, lng) {
        var l = adimlar;
        if (!l.length) return;
        while (adimNo < l.length - 1 && H.mesafe(lat, lng, l[adimNo].lat, l[adimNo].lng) < 25) adimNo++;
        var hedefUzak = H.mesafe(lat, lng, rotaHedefLat, rotaHedefLng);
        if (hedefUzak < 30) { navMetin = qsTr("Hedefe vardınız"); navAlt = ""; bildir(qsTr("Hedefe vardınız")); yolculukBitir(); return; }
        var sonraki = H.mesafe(lat, lng, l[adimNo].lat, l[adimNo].lng), kalan = sonraki;
        for (var i = adimNo; i < l.length; i++) kalan += l[i].m;
        navMetin = H.mesafeMetni(sonraki) + qsTr(" sonra: ") + l[adimNo].metin;
        navAlt = qsTr("Kalan ") + H.mesafeMetni(kalan) + (adimNo + 1 < l.length ? qsTr(" • ardından: ") + l[adimNo + 1].metin : "");
        // rotadan ciktiysak (en yakin rota noktasi 90 m'den uzak) yeniden hesapla (en fazla 20 sn'de bir)
        var r = harita.rota, enYakin = 1e9;
        for (var k = 0; k < r.length; k++) enYakin = Math.min(enYakin, H.mesafe(lat, lng, r[k][0], r[k][1]));
        var simdi = new Date().getTime();
        if (enYakin > 90 && harita.konumDogruluk < 60 && simdi - sonYeniden > 20000) {
            sonYeniden = simdi;
            bildir(qsTr("Rotadan çıkıldı, yeniden hesaplanıyor"));
            rotaIste(lat, lng, rotaHedefLat, rotaHedefLng, false);
        }
    }

    // ---------- GPS ----------
    Connections {
        target: gps
        onBulundu: {
            var ilk = !harita.konumVar;
            harita.konumVar = true; harita.konumLat = lat; harita.konumLng = lng; harita.konumDogruluk = dogruluk;
            if (ilk || app.takip) harita.merkezle(lat, lng, ilk ? Math.max(harita.zoom, 16) : harita.zoom);
            if (app.rotaBekliyor && app.yerVar && dogruluk < 500) app.rotaIste(lat, lng, app.rotaHedefLat, app.rotaHedefLng, true);
            if (app.yolculuk) app.navGuncelle(lat, lng);
        }
        onHata: { app.rotaBekliyor = false; app.takip = false; app.bildir(mesaj); }
    }
    // Konum amblemi: kapaliysa ac ve izle; aciksa ve harita elle kaydirildiysa yeniden ortala; izliyorsa kapat
    function konumum() {
        console.log("iz: konum dugmesi (gps " + (gps.aktif ? "acik" : "kapali") + ", takip " + takip + ")");
        if (!gps.aktif) {
            takip = true;
            gps.baslat(false);
            bildir(harita.konumVar ? qsTr("Konum güncelleniyor") : qsTr("Konum aranıyor… (açık havada daha hızlı)"));
            return;
        }
        if (!takip) {
            takip = true;
            if (harita.konumVar) harita.merkezle(harita.konumLat, harita.konumLng, Math.max(harita.zoom, 16));
            return;
        }
        if (yolculuk) { bildir(qsTr("Yolculuk sürüyor: bitirmek için alttaki Bitir'e basın")); return; }
        takip = false;
        gps.durdur();
    }

    function katmanDegistir() {
        console.log("iz: katman degistir (" + harita.katman + ")");
        var s = H.KATMAN_SIRA, i = s.indexOf(harita.katman);
        harita.katman = s[(i + 1) % s.length];
        arac.setAyar("katman", harita.katman);
        bildir(qsTr("Katman: ") + H.katman(harita.katman).ad);
    }

    // ---------- harita ----------
    Harita {
        id: harita
        anchors.fill: parent
        focus: true
        dugmeler: false                         // + / - sag alttaki sutunda (konum, katmanla birlikte)
        onElleOynandi: app.takip = false        // kullanici gezerken GPS haritayi geri cekmesin
        onUzunBasildi: app.yerSec(lat, lng, "", "", false)
        onDokunuldu: { if (sonuclar.count > 0) sonuclar.clear(); }
        onIsaretTiklandi: app.yerVar = true
        onDegisti: { kaydetZaman.restart(); }
        Keys.onPressed: {
            var k = event.key, t = (event.text || "").toLowerCase();
            if (k === Qt.Key_Left) harita.kaydir(-90, 0);
            else if (k === Qt.Key_Right) harita.kaydir(90, 0);
            else if (k === Qt.Key_Up) harita.kaydir(0, -90);
            else if (k === Qt.Key_Down) harita.kaydir(0, 90);
            else if (t === "+" || t === "*" || k === Qt.Key_Plus) harita.yakinlas(1);
            else if (t === "-" || t === "#" || k === Qt.Key_Minus) harita.yakinlas(-1);
            else if (t === "s" || t === "/") aramaKutu.ac();
            else if (t === "g") app.konumum();
            else if (t === "k") app.katmanDegistir();
            else if (t === "y") yerlerSayfa.ac();
            else if (t === "m" || k === Qt.Key_Context1) menu.visible = !menu.visible;
            else if (k === Qt.Key_Select || k === Qt.Key_Return || k === Qt.Key_Enter) app.yerSec(harita.merkezLat(), harita.merkezLng(), "", "", false);
            else if (k === Qt.Key_Backspace || k === Qt.Key_Escape) { if (app.yerVar) app.yerKapat(); else if (app.rotaVar) app.rotaKapat(); }
            else return;
            event.accepted = true;
        }
    }
    Timer {
        id: kaydetZaman; interval: 1500
        onTriggered: { console.log("iz: harita z" + harita.zoom + " " + harita.katman + " " + harita.merkezLat().toFixed(4) + "," + harita.merkezLng().toFixed(4)); arac.setAyar("lat", "" + harita.merkezLat()); arac.setAyar("lng", "" + harita.merkezLng()); arac.setAyar("zoom", "" + harita.zoom); }
    }

    // ---------- ust: arama cubugu ----------
    Rectangle {
        id: aramaKutu
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
        height: 50; radius: 25
        color: app.cZemin
        border.color: app.cCizgi; border.width: 1
        z: 5
        function ac() { alan.forceActiveFocus(); alan.openSoftwareInputPanel(); }
        function kapat() { alan.closeSoftwareInputPanel(); harita.forceActiveFocus(); }
        Rectangle {
            id: menuDugme
            anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
            width: 42; height: 42; radius: 21
            color: mdma.pressed ? app.cYuzey : "transparent"
            Column {
                anchors.centerIn: parent; spacing: 4
                Repeater { model: 3; Rectangle { width: 20; height: 3; radius: 1; color: app.cYazi } }
            }
            MouseArea { id: mdma; anchors.fill: parent; onClicked: menu.visible = !menu.visible }
        }
        TextInput {
            id: alan
            anchors { left: menuDugme.right; leftMargin: 8; right: araD.left; rightMargin: 4; verticalCenter: parent.verticalCenter }
            font.pixelSize: 21
            color: app.cYazi
            selectByMouse: true
            Keys.onReturnPressed: app.ara(text)
            Keys.onEnterPressed: app.ara(text)
            Keys.onDownPressed: { if (sonuclar.count > 0) { sonucListe.currentIndex = 0; sonucListe.forceActiveFocus(); } else harita.forceActiveFocus(); }
            Keys.onEscapePressed: aramaKutu.kapat()
        }
        Text {
            anchors { left: alan.left; verticalCenter: parent.verticalCenter }
            visible: alan.text === "" && !alan.activeFocus
            text: qsTr("Ara: yer, adres, koordinat")
            color: app.cIkinci; font.pixelSize: 20
        }
        MouseArea { anchors.fill: alan; enabled: !alan.activeFocus; onClicked: aramaKutu.ac() }
        Rectangle {
            id: araD
            anchors { right: parent.right; rightMargin: 5; verticalCenter: parent.verticalCenter }
            width: 54; height: 40; radius: 20
            color: adma.pressed ? app.cYuzey : "transparent"
            Text { anchors.centerIn: parent; text: app.araniyor ? "…" : (alan.text !== "" ? qsTr("Ara") : ""); color: app.cVurgu; font.pixelSize: 18; font.bold: true }
            Item {
                anchors.centerIn: parent; width: 20; height: 20; visible: alan.text === "" && !app.araniyor && (sonuclar.count > 0 || alan.activeFocus)
                Rectangle { anchors.centerIn: parent; width: 22; height: 3; radius: 1; rotation: 45; color: app.cIkinci; smooth: true }
                Rectangle { anchors.centerIn: parent; width: 22; height: 3; radius: 1; rotation: -45; color: app.cIkinci; smooth: true }
            }
            MouseArea { id: adma; anchors.fill: parent; onClicked: { if (alan.text !== "") app.ara(alan.text); else { sonuclar.clear(); aramaKutu.kapat(); } } }
        }
    }

    ListModel { id: sonuclar }
    Rectangle {
        anchors { left: aramaKutu.left; right: aramaKutu.right; top: aramaKutu.bottom; topMargin: 6 }
        height: Math.min(sonuclar.count * 66, app.height - 90)
        visible: sonuclar.count > 0
        radius: 12; color: app.cZemin; border.color: app.cCizgi; border.width: 1
        z: 5
        clip: true
        ListView {
            id: sonucListe
            anchors { fill: parent; margins: 1 }
            clip: true
            model: sonuclar
            delegate: Rectangle {
                width: sonucListe.width; height: 66
                color: sma.pressed || (sonucListe.activeFocus && ListView.isCurrentItem) ? app.cYuzey : "transparent"
                Text { x: 16; y: 8; width: parent.width - (bos ? 30 : 100); text: ad; font.pixelSize: bos ? 16 : 20; font.bold: !bos; color: app.cYazi; elide: bos ? Text.ElideNone : Text.ElideRight; wrapMode: bos ? Text.Wrap : Text.NoWrap; maximumLineCount: 3 }
                Text { x: 16; y: 38; width: parent.width - 100; text: adres; font.pixelSize: 15; color: app.cIkinci; elide: Text.ElideRight }
                Text { anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter } text: uzak; font.pixelSize: 15; color: app.cIkinci }
                MouseArea { id: sma; anchors.fill: parent; onClicked: app.sonucSec(index) }
            }
            Keys.onReturnPressed: app.sonucSec(currentIndex)
            Keys.onSelectPressed: app.sonucSec(currentIndex)
            Keys.onUpPressed: { if (currentIndex <= 0) alan.forceActiveFocus(); else decrementCurrentIndex(); }
        }
    }
    function sonucSec(i) {
        var o = sonuclar.get(i);
        if (o.bos) { if (/sunucu/i.test(o.ad)) ayarSayfa.ac(); return; }
        yerSec(o.lat, o.lng, o.ad, o.adres, true);
        sonuclar.clear();
        aramaKutu.kapat();
    }

    // ---------- GPS durumu (yalnizca konum aranirken / az once) ----------
    Rectangle {
        id: gpsSerit
        anchors { left: parent.left; right: parent.right; top: aramaKutu.bottom; topMargin: 6; leftMargin: 10; rightMargin: 10 }
        height: gsY.paintedHeight + 16; radius: 10
        visible: (gps.aktif || gpsSure.running) && sonuclar.count === 0
        color: gps.aktif ? "#e61a73e8" : "#e6202124"; z: 4
        Rectangle { id: gsN; x: 12; anchors.verticalCenter: parent.verticalCenter; width: 12; height: 12; radius: 6; color: "white"
            SequentialAnimation on opacity { running: gps.aktif; loops: Animation.Infinite; NumberAnimation { to: 0.2; duration: 500 } NumberAnimation { to: 1; duration: 500 } } }
        Text { id: gsY; anchors { left: gsN.right; leftMargin: 10; right: gsD.left; rightMargin: 8; verticalCenter: parent.verticalCenter } text: gps.durum + (app.takip && gps.aktif ? qsTr(" • takip açık") : ""); color: "white"; font.pixelSize: 16; wrapMode: Text.Wrap }
        Text { id: gsD; visible: gps.aktif; anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } text: qsTr("Durdur"); color: "white"; font.pixelSize: 16; font.bold: true
            MouseArea { anchors { fill: parent; margins: -12 } onClicked: { gps.durdur(); app.takip = false; app.rotaBekliyor = false; } } }
    }
    Timer { id: gpsSure; interval: 6000 }
    Connections { target: gps; onAktifDegisti: if (!gps.aktif) gpsSure.restart() }

    // ---------- sag alt: konumum / katman ----------
    // tek sutun: + - katman konum (paneller acilinca yukari kayar, hicbiri digerinin ustune binmez)
    Column {
        anchors { right: parent.right; rightMargin: 10; bottom: altPanel.visible ? altPanel.top : (rotaCubuk.visible ? rotaCubuk.top : parent.bottom); bottomMargin: 12 }
        spacing: 8
        z: 4
        Yuvarlak { tur: "arti"; onTik: { app.takip = app.takip && app.yolculuk; harita.yakinlas(1); } }
        Yuvarlak { tur: "eksi"; onTik: { app.takip = app.takip && app.yolculuk; harita.yakinlas(-1); } }
        Item { width: 52; height: 6 }
        Yuvarlak { tur: "katman"; onTik: app.katmanDegistir() }
        Yuvarlak { tur: "konum"; vurgu: gps.aktif && app.takip; onTik: app.konumum() }
    }

    // ---------- rota / yolculuk cubugu ----------
    Rectangle {
        id: rotaCubuk
        visible: app.rotaVar && !altPanel.visible
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: app.yolculuk ? navKolon.height + 20 : 64
        color: app.yolculuk ? "#1a73e8" : app.cZemin; z: 4
        Rectangle { width: parent.width; height: 1; color: app.cCizgi }
        Column {
            id: navKolon
            visible: app.yolculuk
            x: 14; y: 10; width: parent.width - 150
            spacing: 4
            Text { width: parent.width; text: app.navMetin; font.pixelSize: 21; font.bold: true; color: "white"; wrapMode: Text.Wrap; maximumLineCount: 2 }
            Text { width: parent.width; text: app.navAlt; font.pixelSize: 15; color: "#e8f0fe"; elide: Text.ElideRight }
        }
        Text { visible: !app.yolculuk; x: 16; anchors.verticalCenter: parent.verticalCenter; text: app.rotaBilgi; font.pixelSize: 19; font.bold: true; color: app.cYazi }
        Row {
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 8
            Dugme2 { visible: !app.yolculuk; metin: app.rotaTumu ? qsTr("Geri") : qsTr("Tümü"); onTik: app.rotaTumu ? app.rotaGeriDon() : app.rotaTumunuGoster() }
            Dugme2 { visible: !app.yolculuk; metin: qsTr("Başlat"); ana: true; onTik: app.yolculukBasla() }
            Dugme2 { visible: !app.yolculuk; metin: qsTr("Kapat"); onTik: app.rotaKapat() }
            Dugme2 { visible: app.yolculuk; metin: qsTr("Bitir"); onTik: app.rotaKapat() }
        }
    }

    // ---------- alt panel: secili yer ----------
    Rectangle {
        id: altPanel
        visible: app.yerVar
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: apKolon.height + 22
        color: app.cZemin; z: 4
        Rectangle { width: parent.width; height: 1; color: app.cCizgi }
        MouseArea { anchors.fill: parent }
        Column {
            id: apKolon
            x: 16; y: 12
            width: parent.width - 32
            spacing: 6
            Text { width: parent.width; text: app.yerAd !== "" ? app.yerAd : qsTr("İşaretli nokta"); font.pixelSize: 21; font.bold: true; color: app.cYazi; elide: Text.ElideRight }
            Text {
                width: parent.width
                text: (app.yerAdres !== "" ? app.yerAdres + " • " : "") + H.koordinatMetni(app.yerLat, app.yerLng)
                      + (harita.konumVar ? " • " + H.mesafeMetni(H.mesafe(harita.konumLat, harita.konumLng, app.yerLat, app.yerLng)) : "")
                font.pixelSize: 15; color: app.cIkinci; elide: Text.ElideRight
            }
            Row {
                spacing: 8
                Dugme2 { metin: app.rotaVar && Math.abs(app.rotaHedefLat - app.yerLat) < 1e-6 && Math.abs(app.rotaHedefLng - app.yerLng) < 1e-6 ? qsTr("Başlat") : qsTr("Rota"); ana: true; onTik: app.rotaCiz() }
                Dugme2 { metin: app.kayitliMi(app.yerLat, app.yerLng) >= 0 ? qsTr("Adlandır") : qsTr("Kaydet"); onTik: app.yerKaydetSil() }
                Dugme2 { metin: qsTr("Bağlantı"); onTik: { arac.pano(H.googleUrl(app.yerLat, app.yerLng)); app.bildir(qsTr("Google Maps bağlantısı kopyalandı")); } }
                Dugme2 { metin: qsTr("Kapat"); onTik: app.yerKapat() }
            }
        }
    }

    // ---------- menu ----------
    Item {
        id: menu
        anchors.fill: parent
        visible: false
        z: 8
        MouseArea { anchors.fill: parent; onClicked: menu.visible = false }
        Rectangle {
            x: 10; y: 66
            width: 300; height: mk.height + 16
            radius: 12; color: app.cZemin; border.color: app.cCizgi; border.width: 1
            Column {
                id: mk
                x: 0; y: 8; width: parent.width
                Repeater {
                    model: ListModel {
                        ListElement { ad: QT_TR_NOOP("Kayıtlı yerler"); k: "yerler" }
                        ListElement { ad: QT_TR_NOOP("Katman değiştir"); k: "katman" }
                        ListElement { ad: QT_TR_NOOP("Konumum"); k: "konum" }
                        ListElement { ad: QT_TR_NOOP("Ortadaki noktayı işaretle"); k: "isaret" }
                        ListElement { ad: QT_TR_NOOP("Çevrimdışı harita indir"); k: "cevrim" }
                        ListElement { ad: QT_TR_NOOP("Ayarlar ve önbellek"); k: "ayar" }
                        ListElement { ad: QT_TR_NOOP("Çıkış"); k: "cikis" }
                    }
                    Rectangle {
                        width: mk.width; height: 52
                        color: mma.pressed ? app.cYuzey : "transparent"
                        Text { x: 18; anchors.verticalCenter: parent.verticalCenter; text: qsTr(ad); font.pixelSize: 20; color: app.cYazi }
                        MouseArea {
                            id: mma; anchors.fill: parent
                            onClicked: {
                                menu.visible = false;
                                if (k === "yerler") yerlerSayfa.ac();
                                else if (k === "katman") app.katmanDegistir();
                                else if (k === "konum") app.konumum();
                                else if (k === "isaret") app.yerSec(harita.merkezLat(), harita.merkezLng(), "", "", false);
                                else if (k === "ayar") ayarSayfa.ac();
                                else if (k === "cevrim") cevrimSayfa.ac();
                                else if (k === "cikis") Qt.quit();
                            }
                        }
                    }
                }
            }
        }
    }

    // ---------- kayitli yerler ----------
    Rectangle {
        id: yerlerSayfa
        anchors.fill: parent
        visible: false
        color: app.cZemin; z: 9
        function ac() { visible = true; yl.currentIndex = 0; yl.forceActiveFocus(); }
        function kapat() { visible = false; harita.forceActiveFocus(); }
        Rectangle {
            id: yUst; width: parent.width; height: 58; color: app.cYuzey
            Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Kayıtlı yerler (") + app.yerler.length + ")"; font.pixelSize: 21; font.bold: true; color: app.cYazi }
            Dugme2 { anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } metin: qsTr("Kapat"); onTik: yerlerSayfa.kapat() }
        }
        Text { anchors.centerIn: parent; visible: app.yerler.length === 0; width: parent.width - 60; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
               text: qsTr("Henüz kayıtlı yer yok. Haritada bir noktaya uzun basın ya da arayın, sonra \"Kaydet\"."); color: app.cIkinci; font.pixelSize: 18 }
        ListView {
            id: yl
            anchors { left: parent.left; right: parent.right; top: yUst.bottom; bottom: parent.bottom }
            clip: true
            model: app.yerler
            delegate: Rectangle {
                width: yl.width; height: 64
                color: yma.pressed || (yl.activeFocus && ListView.isCurrentItem) ? app.cYuzey : "transparent"
                Text { x: 16; y: 8; width: parent.width - 120; text: modelData.ad; font.pixelSize: 20; font.bold: true; color: app.cYazi; elide: Text.ElideRight }
                Text { x: 16; y: 37; width: parent.width - 120; text: modelData.adres !== "" ? modelData.adres : H.koordinatMetni(modelData.lat, modelData.lng); font.pixelSize: 15; color: app.cIkinci; elide: Text.ElideRight }
                Text { anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                       text: harita.konumVar ? H.mesafeMetni(H.mesafe(harita.konumLat, harita.konumLng, modelData.lat, modelData.lng)) : ""; font.pixelSize: 15; color: app.cIkinci }
                MouseArea { id: yma; anchors.fill: parent; onClicked: { yerlerSayfa.kapat(); app.yerSec(modelData.lat, modelData.lng, modelData.ad, modelData.adres, true); }
                            onPressAndHold: app.adAc(index) }
            }
            Keys.onReturnPressed: { var o = app.yerler[currentIndex]; if (o) { yerlerSayfa.kapat(); app.yerSec(o.lat, o.lng, o.ad, o.adres, true); } }
            Keys.onSelectPressed: { var o = app.yerler[currentIndex]; if (o) { yerlerSayfa.kapat(); app.yerSec(o.lat, o.lng, o.ad, o.adres, true); } }
            Keys.onEscapePressed: yerlerSayfa.kapat()
            Keys.onPressed: {
                if (event.key === Qt.Key_Backspace) { yerlerSayfa.kapat(); event.accepted = true; }
                else if (event.key === Qt.Key_Context1 || (event.text || "").toLowerCase() === "e") { if (currentIndex >= 0) app.adAc(currentIndex); event.accepted = true; }
            }
        }
        Text { anchors { bottom: parent.bottom; bottomMargin: 8; horizontalCenter: parent.horizontalCenter }
               visible: app.yerler.length > 0; text: qsTr("Basılı tutun: adlandır / sil"); font.pixelSize: 14; color: app.cIkinci }
    }

    // ---------- ad verme penceresi ----------
    Item {
        id: adSayfa
        anchors.fill: parent
        visible: false
        z: 11
        function ac(ad, alt) { adAlan.text = ad; adAlt.text = alt; visible = true; adAlan.forceActiveFocus(); adAlan.selectAll(); }
        function kapat() { visible = false; adAlan.closeSoftwareInputPanel(); if (yerlerSayfa.visible) yl.forceActiveFocus(); else harita.forceActiveFocus(); }
        Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.5 }
        MouseArea { anchors.fill: parent; onClicked: adSayfa.kapat() }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(10, parent.height * 0.12)
            width: Math.min(parent.width - 30, 560); height: adKolon.height + 28
            radius: 14; color: app.cZemin; border.color: app.cCizgi; border.width: 1
            MouseArea { anchors.fill: parent }
            Column {
                id: adKolon
                x: 16; y: 14; width: parent.width - 32
                spacing: 10
                Text { text: app.adNo >= 0 ? qsTr("Kayıtlı yeri adlandır") : qsTr("Yeri kaydet"); font.pixelSize: 21; font.bold: true; color: app.cYazi }
                Text { id: adAlt; width: parent.width; font.pixelSize: 15; color: app.cIkinci; elide: Text.ElideRight }
                Rectangle {
                    width: parent.width; height: 50; radius: 8
                    color: app.cYuzey; border.color: adAlan.activeFocus ? "#1a73e8" : app.cCizgi; border.width: 2
                    TextInput {
                        id: adAlan
                        anchors { left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        font.pixelSize: 20; color: app.cYazi; selectByMouse: true; maximumLength: 60
                        Keys.onReturnPressed: { app.adKaydet(text); adSayfa.kapat(); }
                        Keys.onEnterPressed: { app.adKaydet(text); adSayfa.kapat(); }
                        Keys.onEscapePressed: adSayfa.kapat()
                    }
                    Text { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                           visible: adAlan.text === "" && !adAlan.activeFocus; text: qsTr("Ad (örn. Ev, İş, Okul)"); font.pixelSize: 20; color: app.cIkinci }
                    MouseArea { anchors.fill: parent; onClicked: { adAlan.forceActiveFocus(); adAlan.openSoftwareInputPanel(); } }
                }
                Row {
                    spacing: 8
                    Dugme2 { metin: qsTr("Kaydet"); ana: true; onTik: { app.adKaydet(adAlan.text); adSayfa.kapat(); } }
                    Dugme2 { visible: app.adNo >= 0; metin: qsTr("Sil"); onTik: { app.adSil(); adSayfa.kapat(); } }
                    Dugme2 { metin: qsTr("Vazgeç"); onTik: adSayfa.kapat() }
                }
            }
        }
    }

    // ---------- ayarlar ----------
    Rectangle {
        id: ayarSayfa
        anchors.fill: parent
        visible: false
        color: app.cZemin; z: 9
        property string onbellek: ""
        function ac() { onbellek = arac.onbellekMetni(); sunucuAlan.text = app.sunucu; anahtarAlan.text = app.anahtar; visible = true; }
        function kapat() {
            app.sunucu = sunucuAlan.text.replace(/\/+$/, ""); arac.setAyar("sunucu", app.sunucu);
            app.anahtar = anahtarAlan.text; arac.setAyar("anahtar", app.anahtar);
            visible = false; harita.forceActiveFocus();
        }
        Rectangle {
            id: aUst; width: parent.width; height: 58; color: app.cYuzey
            Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Ayarlar"); font.pixelSize: 21; font.bold: true; color: app.cYazi }
            Dugme2 { anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } metin: qsTr("Tamam"); onTik: ayarSayfa.kapat() }
        }
        Flickable {
            anchors { left: parent.left; right: parent.right; top: aUst.bottom; bottom: parent.bottom }
            contentHeight: ak.height + 30
            clip: true
            Column {
                id: ak
                x: 18; y: 14; width: parent.width - 36
                spacing: 12
                Text { text: qsTr("Karo önbelleği: ") + ayarSayfa.onbellek; font.pixelSize: 19; color: app.cYazi }
                Text { width: parent.width; wrapMode: Text.Wrap; font.pixelSize: 15; color: app.cIkinci
                       text: qsTr("Baktığınız harita parçaları karta (") + arac.klasor() + qsTr(") kaydedilir; aynı yerler internetsiz de açılır. En fazla 120 MB; aşılırsa açılışta temizlenir.") }
                Dugme2 { metin: qsTr("Önbelleği temizle"); onTik: { arac.onbellekSil(); ayarSayfa.onbellek = arac.onbellekMetni(); app.bildir(qsTr("Önbellek temizlendi")); } }
                Rectangle { width: parent.width; height: 1; color: app.cCizgi }
                // Dil / Language (tum uygulamalarda ortak, yeniden acinca gecerli)
                Dugme2 {
                    metin: "Dil / Language: " + ((dil.secim === "auto" ? dil.kod : dil.secim) === "en" ? "English" : "Türkçe")
                    onTik: {
                        var k = dil.secim === "auto" ? dil.kod : dil.secim;
                        dil.sec(k === "en" ? "tr" : "en");
                        app.bildir(dil.yenidenBaslat ? "Dil değişti; uygulamayı yeniden açın. / Language changed; restart the app." : "Dil / Language: " + (k === "en" ? "Türkçe" : "English"));
                    }
                }
                Rectangle { width: parent.width; height: 1; color: app.cCizgi }
                Row {
                    spacing: 12
                    Rectangle {
                        width: 52; height: 30; radius: 15; anchors.verticalCenter: parent.verticalCenter
                        color: app.sunucuAra ? "#00a884" : app.cCizgi
                        Rectangle { x: app.sunucuAra ? 25 : 3; y: 3; width: 24; height: 24; radius: 12; color: "white" }
                        MouseArea { anchors.fill: parent; onClicked: { app.sunucuAra = !app.sunucuAra; arac.setAyar("sunucuAra", app.sunucuAra ? "1" : "0"); } }
                    }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Aramada sunucuyu kullan (öneri)"); font.pixelSize: 19; color: app.cYazi }
                }
                Text { width: parent.width; wrapMode: Text.Wrap; font.pixelSize: 15; color: app.cIkinci
                       text: qsTr("Harita, rota ve GPS sunucusuz çalışır. Adres arama servisi (Photon) yalnızca güvenli bağlantı (TLS 1.2) kabul ediyor; telefon bunu kuramazsa arama sonuç vermez. Bu seçenek açılırsa arama, WhatsBelle'in de kullandığı kendi sunucunuz üzerinden yapılır (yalnızca aranan metin gider).") }
                Text { text: qsTr("Sunucu adresi"); font.pixelSize: 16; color: app.cIkinci }
                Rectangle { width: parent.width; height: 46; radius: 8; color: app.cYuzey
                    TextInput { id: sunucuAlan; anchors { fill: parent; leftMargin: 12; rightMargin: 12; topMargin: 11 } font.pixelSize: 19; color: app.cYazi } }
                Text { text: qsTr("Sunucu parolası"); font.pixelSize: 16; color: app.cIkinci }
                Rectangle { width: parent.width; height: 46; radius: 8; color: app.cYuzey
                    TextInput { id: anahtarAlan; anchors { fill: parent; leftMargin: 12; rightMargin: 12; topMargin: 11 } font.pixelSize: 19; color: app.cYazi; echoMode: TextInput.Password } }
                Rectangle { width: parent.width; height: 1; color: app.cCizgi }
                Text { width: parent.width; wrapMode: Text.Wrap; font.pixelSize: 15; color: app.cIkinci
                       text: "Belle Maps 1.3.1 • Harita verisi © OpenStreetMap katkıcıları • Karolar OpenStreetMap, Esri, OpenTopoMap • Arama Photon (komoot) • Rota OSRM. Klavye: oklar kaydır, + - yakınlaş, S ara, G konumum, K katman, Y kayıtlı yerler, M menü, Enter ortadaki noktayı işaretle." }
            }
        }
    }

    // ---------- cevrimdisi harita ----------
    // Ekrandaki alan (ve biraz cevresi) secilen yakinliklara kadar karta indirilir; internet yokken de acilir.
    Rectangle {
        id: cevrimSayfa
        anchors.fill: parent
        visible: false
        color: app.cZemin; z: 9
        property real lat1: 0
        property real lng1: 0
        property real lat2: 0
        property real lng2: 0
        property int z1: 10
        property int z2: 16
        property int adet: 0
        property string boyut: ""
        property string mesaj: ""
        function hesapla() { adet = cevrimdisi.say(lat1, lng1, lat2, lng2, z1, z2); }
        function ac() {
            // gorunen alanin %20 cevresi
            var px = harita.width * 0.2, py = harita.height * 0.2;
            lat1 = harita.ekranLat(-py); lng1 = harita.ekranLng(-px);
            lat2 = harita.ekranLat(harita.height + py); lng2 = harita.ekranLng(harita.width + px);
            z1 = Math.max(2, Math.min(harita.zoom, 18) - 2);
            z2 = Math.min(H.katman(harita.katman).enCok, Math.max(z1, Math.min(harita.zoom, 18) + 2));
            boyut = cevrimdisi.boyutMetni();
            mesaj = "";
            hesapla();
            visible = true;
        }
        function kapat() { visible = false; harita.forceActiveFocus(); }
        Connections {
            target: cevrimdisi
            onBitti: { cevrimSayfa.mesaj = mesaj; cevrimSayfa.boyut = cevrimdisi.boyutMetni(); app.bildir(mesaj); }
        }
        Rectangle {
            id: cUst; width: parent.width; height: 58; color: app.cYuzey
            Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Çevrimdışı harita"); font.pixelSize: 21; font.bold: true; color: app.cYazi }
            Dugme2 { anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } metin: qsTr("Kapat"); onTik: cevrimSayfa.kapat() }
        }
        Flickable {
            anchors { left: parent.left; right: parent.right; top: cUst.bottom; bottom: parent.bottom }
            contentHeight: cKol.height + 30
            clip: true
            Column {
                id: cKol
                x: 18; y: 14; width: parent.width - 36
                spacing: 12
                Text { width: parent.width; wrapMode: Text.Wrap; font.pixelSize: 16; color: app.cIkinci
                       text: qsTr("Haritada şu an görünen alan (ve çevresi) seçilen yakınlık aralığında karta indirilir. İnternet yokken bu alan açılır; dokunmadan kalır, önbellek gibi silinmez. Katman: ") + H.katman(harita.katman).ad + qsTr(" (önce istediğiniz katmana geçin).") }
                Text { font.pixelSize: 18; color: app.cYazi; text: qsTr("Alan: ") + H.koordinatMetni(cevrimSayfa.lat1, cevrimSayfa.lng1) + " → " + H.koordinatMetni(cevrimSayfa.lat2, cevrimSayfa.lng2) }
                Row {
                    spacing: 10
                    Text { anchors.verticalCenter: parent.verticalCenter; width: 200; text: qsTr("En uzak: ") + cevrimSayfa.z1; font.pixelSize: 19; color: app.cYazi }
                    Dugme2 { metin: "-"; onTik: { cevrimSayfa.z1 = Math.max(2, cevrimSayfa.z1 - 1); cevrimSayfa.hesapla(); } }
                    Dugme2 { metin: "+"; onTik: { cevrimSayfa.z1 = Math.min(cevrimSayfa.z2, cevrimSayfa.z1 + 1); cevrimSayfa.hesapla(); } }
                }
                Row {
                    spacing: 10
                    Text { anchors.verticalCenter: parent.verticalCenter; width: 200; text: qsTr("En yakın: ") + cevrimSayfa.z2; font.pixelSize: 19; color: app.cYazi }
                    Dugme2 { metin: "-"; onTik: { cevrimSayfa.z2 = Math.max(cevrimSayfa.z1, cevrimSayfa.z2 - 1); cevrimSayfa.hesapla(); } }
                    Dugme2 { metin: "+"; onTik: { cevrimSayfa.z2 = Math.min(H.katman(harita.katman).enCok, cevrimSayfa.z2 + 1); cevrimSayfa.hesapla(); } }
                }
                Text { width: parent.width; wrapMode: Text.Wrap; font.pixelSize: 18; font.bold: true
                       color: cevrimSayfa.adet > 25000 ? "#d93025" : app.cYazi
                       text: cevrimSayfa.adet + qsTr(" karo • yaklaşık ") + Math.max(1, Math.round(cevrimSayfa.adet * 0.022)) + qsTr(" MB") + (cevrimSayfa.adet > 25000 ? qsTr(" • çok büyük: en fazla 25000 karo (yakınlığı azaltın ya da daha küçük alan seçin)") : "") }
                Text { width: parent.width; wrapMode: Text.Wrap; font.pixelSize: 15; color: app.cIkinci
                       text: qsTr("Yakınlık 15 ≈ mahalle, 17 ≈ sokak, 18 ≈ bina. Her bir artış karo sayısını yaklaşık 4 katına çıkarır. 18'den sonrası bu karolar büyütülerek gösterilir.") }
                Row {
                    spacing: 10
                    Dugme2 { visible: !cevrimdisi.calisiyor; ana: true; metin: qsTr("İndir")
                             onTik: { var k = H.katman(harita.katman);
                                      if (!cevrimdisi.baslat(k.url, k.alt, cevrimSayfa.lat1, cevrimSayfa.lng1, cevrimSayfa.lat2, cevrimSayfa.lng2, cevrimSayfa.z1, cevrimSayfa.z2)) app.bildir(qsTr("Başlatılamadı (alan çok büyük olabilir)")); } }
                    Dugme2 { visible: cevrimdisi.calisiyor; metin: qsTr("Durdur"); onTik: cevrimdisi.iptal() }
                }
                Column {
                    visible: cevrimdisi.calisiyor
                    width: parent.width; spacing: 6
                    Rectangle { width: parent.width; height: 10; radius: 5; color: app.cYuzey
                        Rectangle { width: cevrimdisi.toplam > 0 ? parent.width * cevrimdisi.biten / cevrimdisi.toplam : 0; height: parent.height; radius: 5; color: "#1a73e8" } }
                    Text { text: qsTr("İndiriliyor: ") + cevrimdisi.biten + " / " + cevrimdisi.toplam + (cevrimdisi.hatali ? " • " + cevrimdisi.hatali + qsTr(" hata") : ""); font.pixelSize: 17; color: app.cYazi }
                }
                Text { visible: cevrimSayfa.mesaj !== ""; width: parent.width; wrapMode: Text.Wrap; text: cevrimSayfa.mesaj; font.pixelSize: 17; color: app.cYazi }
                Rectangle { width: parent.width; height: 1; color: app.cCizgi }
                Text { text: qsTr("Kartta çevrimdışı harita: ") + cevrimSayfa.boyut; font.pixelSize: 18; color: app.cYazi }
                Dugme2 { metin: qsTr("Tüm çevrimdışı haritayı sil"); onTik: { cevrimdisi.hepsiniSil(); cevrimSayfa.boyut = cevrimdisi.boyutMetni(); app.bildir(qsTr("Silindi")); } }
            }
        }
    }

    // ---------- bildirim ----------
    Rectangle {
        id: tost
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 90 }
        width: Math.min(app.width - 40, tt.paintedWidth + 32); height: tt.paintedHeight + 18
        radius: 10; color: "#e6202124"; opacity: 0; z: 20
        Behavior on opacity { NumberAnimation { duration: 180 } }
        function goster(m) { tt.text = m; opacity = 1; tz.restart(); }
        Text { id: tt; anchors.centerIn: parent; width: app.width - 72; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; color: "white"; font.pixelSize: 17 }
        Timer { id: tz; interval: 3000; onTriggered: tost.opacity = 0 }
    }

    Component.onCompleted: {
        yerleriYukle();
        var kt = arac.ayar("katman", "acik");
        harita.katman = H.KATMANLAR[kt] ? kt : "acik";
        var lat = parseFloat(arac.ayar("lat", "41.0082")), lng = parseFloat(arac.ayar("lng", "28.9784")), z = parseInt(arac.ayar("zoom", "12"), 10);
        harita.merkezle(isNaN(lat) ? 41.0082 : lat, isNaN(lng) ? 28.9784 : lng, isNaN(z) ? 12 : z);
        harita.forceActiveFocus();
        httpsDene.start();
        // onceki acilis coktuyse gunluk sunucuya gider (parola yoksa bekler)
        if (gunluk.raporBekliyor) {
            if (app.anahtar !== "") raporZaman.start();
            else bildir(qsTr("Belle Maps son açılışta kapandı. Hata raporunun gitmesi için Ayarlar'da sunucu parolasını girin."));
        }
    }
    Timer { id: raporZaman; interval: 6000; onTriggered: gunluk.gonder(app.sunucu, app.anahtar, "") }
    Connections { target: gunluk; onRaporSonucu: app.bildir(mesaj) }
    // Acilista bir kez: dogrudan (HTTPS) arama calisiyor mu? Calismiyorsa kullaniciya sunucu secenegi onerilir
    property bool httpsCalisiyor: arac.ayar("https", "?") === "1"
    Timer {
        id: httpsDene; interval: 2500
        onTriggered: {
            var x = new XMLHttpRequest();
            x.onreadystatechange = function () {
                if (x.readyState !== 4) return;
                var ok = x.status === 200 && x.responseText.indexOf("features") >= 0;
                console.log("https deneme: durum " + x.status + (ok ? " (calisiyor)" : " (calismiyor)"));
                app.httpsCalisiyor = ok;
                if (arac.ayar("https", "?") !== (ok ? "1" : "0")) {
                    arac.setAyar("https", ok ? "1" : "0");
                    if (!ok && !app.sunucuAra) app.bildir(qsTr("Not: doğrudan adres araması bu telefonda çalışmıyor. Ayarlar > \"Aramada sunucuyu kullan\" ile açılabilir."));
                }
            };
            x.open("GET", "https://photon.komoot.io/api/?limit=1&q=Ankara");
            x.send();
        }
    }
}
