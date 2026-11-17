// Ortak harita yardimcilari (Belle Maps + WhatsBelle konum ekrani)
// Karolar (anahtarsiz, HTTPS; telefon TLS 1.2'yi sorunsuz kullaniyor):
//   OpenStreetMap standart, Esri (koyu gri, uydu, sokak), OpenTopoMap. CARTO artik anahtar istiyor ("API KEY REQUIRED").
// Arama: Photon (komoot, acik kaynak). Rota: OSRM (acik kaynak).
.pragma library

var ESRI = "https://server.arcgisonline.com/ArcGIS/rest/services/";
var KATMANLAR = {
    acik:  { ad: qsTr("Açık (OSM)"),  url: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", alt: [""], enCok: 19, telif: qsTr("© OpenStreetMap katkıcıları") },
    koyu:  { ad: qsTr("Koyu"),  url: ESRI + "Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}", alt: [""], enCok: 16, telif: "© Esri, OpenStreetMap" },
    uydu:  { ad: qsTr("Uydu"),  url: ESRI + "World_Imagery/MapServer/tile/{z}/{y}/{x}", alt: [""], enCok: 19, telif: "© Esri, Maxar, Earthstar" },
    sokak: { ad: qsTr("Sokak"), url: ESRI + "World_Street_Map/MapServer/tile/{z}/{y}/{x}", alt: [""], enCok: 19, telif: "© Esri, HERE, OpenStreetMap" },
    topo:  { ad: qsTr("Arazi"), url: "https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png", alt: ["a", "b", "c"], enCok: 17, telif: "© OpenStreetMap, OpenTopoMap" }
};
var KATMAN_SIRA = ["acik", "koyu", "uydu", "sokak", "topo"];
function koyuMu(ad) { return ad === "koyu" || ad === "uydu"; }

function katman(ad) { return KATMANLAR[ad] || KATMANLAR.acik; }

function karoUrl(ad, z, x, y) {
    var k = katman(ad);
    var n = 1 << z;
    x = ((x % n) + n) % n;               // dunya yatayda doner
    if (y < 0 || y >= n) return "";
    var s = k.alt[(x + y) % k.alt.length];
    if (z > k.enCok) return "";
    return k.url.replace("{s}", s).replace("{z}", z).replace("{x}", x).replace("{y}", y);
}

// Web Mercator: derece <-> dunya pikseli (256 piksel karo)
function lngX(lng, z) { return (lng + 180) / 360 * 256 * (1 << z); }
function latY(lat, z) {
    lat = Math.max(-85.0511, Math.min(85.0511, lat));
    var r = lat * Math.PI / 180;
    return (1 - Math.log(Math.tan(r) + 1 / Math.cos(r)) / Math.PI) / 2 * 256 * (1 << z);
}
function xLng(x, z) { return x / (256 * (1 << z)) * 360 - 180; }
function yLat(y, z) {
    var n = Math.PI - 2 * Math.PI * y / (256 * (1 << z));
    return 180 / Math.PI * Math.atan(0.5 * (Math.exp(n) - Math.exp(-n)));
}

// Iki nokta arasi mesafe (metre)
function mesafe(lat1, lng1, lat2, lng2) {
    var R = 6371000, d = Math.PI / 180;
    var a = Math.sin((lat2 - lat1) * d / 2), b = Math.sin((lng2 - lng1) * d / 2);
    var h = a * a + Math.cos(lat1 * d) * Math.cos(lat2 * d) * b * b;
    return 2 * R * Math.asin(Math.min(1, Math.sqrt(h)));
}
function mesafeMetni(m) {
    if (m < 1000) return Math.round(m) + " m";
    return (m < 10000 ? (Math.round(m / 100) / 10) : Math.round(m / 1000)) + qsTr(" km");
}
function sureMetni(sn) {
    var dk = Math.round(sn / 60);
    if (dk < 60) return dk + qsTr(" dk");
    return Math.floor(dk / 60) + qsTr(" sa ") + (dk % 60) + qsTr(" dk");
}

function koordinatMetni(lat, lng) {
    return (Math.round(lat * 100000) / 100000) + ", " + (Math.round(lng * 100000) / 100000);
}
function googleUrl(lat, lng) { return "https://maps.google.com/?q=" + lat.toFixed(6) + "," + lng.toFixed(6); }

// Metinde konum baglantisi / koordinat bul (Google Maps, OSM, geo:, "41.03, 28.98")
function metindenKonum(t) {
    if (!t) return null;
    var m = /maps\.google\.[a-z.]+\/(?:maps)?\?(?:[^ ]*?&)?(?:q|ll)=(-?\d+\.\d+),\s*(-?\d+\.\d+)/i.exec(t)
         || /google\.[a-z.]+\/maps\/[^ ]*@(-?\d+\.\d+),(-?\d+\.\d+)/i.exec(t)
         || /openstreetmap\.org\/[^ ]*[?&#](?:mlat=|map=\d+\/)(-?\d+\.\d+)[&\/](?:mlon=)?(-?\d+\.\d+)/i.exec(t)
         || /\bgeo:(-?\d+\.\d+),(-?\d+\.\d+)/i.exec(t);
    if (!m) return null;
    var lat = parseFloat(m[1]), lng = parseFloat(m[2]);
    if (isNaN(lat) || isNaN(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) return null;
    return { lat: lat, lng: lng };
}

// Google/OSRM polyline (5 hane) cozumu -> [[lat,lng],...]
function polylineCoz(s) {
    var i = 0, lat = 0, lng = 0, out = [];
    while (i < s.length) {
        var b, sh = 0, r = 0;
        do { b = s.charCodeAt(i++) - 63; r |= (b & 0x1f) << sh; sh += 5; } while (b >= 0x20);
        lat += (r & 1) ? ~(r >> 1) : (r >> 1);
        sh = 0; r = 0;
        do { b = s.charCodeAt(i++) - 63; r |= (b & 0x1f) << sh; sh += 5; } while (b >= 0x20);
        lng += (r & 1) ? ~(r >> 1) : (r >> 1);
        out.push([lat / 1e5, lng / 1e5]);
    }
    return out;
}

// Photon sonucunu sadelestir
function photonOge(f) {
    var p = f.properties || {}, c = (f.geometry && f.geometry.coordinates) || [];
    var sokak = [p.street, p.housenumber].filter(function (x) { return !!x; }).join(" ");
    var ad = p.name || sokak || p.city || "";
    var parca = [p.name ? sokak : "", p.district, p.city || p.county, p.state, p.country], adres = [];
    for (var i = 0; i < parca.length; i++) if (parca[i] && parca[i] !== ad && adres.indexOf(parca[i]) < 0) adres.push(parca[i]);
    return { ad: ad, adres: adres.join(", "), lat: +c[1], lng: +c[0] };
}
