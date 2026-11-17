import QtQuick 1.1
import "Util.js" as U

// Radyo: kayitli istasyonlar, Turkiye/dunyada populer (radio-browser.info), arama, adresle ekleme.
// Klavye: Enter cal, Bosluk menu, S ara, N adres ekle, 1-4 gorunum, P duraklat, Sol/Sag sekme.
Rectangle {
    id: root
    color: app.bg
    property string kip: "kayitli"          // kayitli | tr | dunya | ulke | ara
    property string ulkeKod: ""             // ulke kipinde secili ulke (bos = ulke listesi)
    property string ulkeAd: ""
    property string arama: ""
    property bool yukleniyor: false
    property string hata: ""
    property int sunucu: 0
    property variant sunucular: ["https://de1.api.radio-browser.info/json/", "https://at1.api.radio-browser.info/json/", "https://nl1.api.radio-browser.info/json/"]
    property string sonIstek: ""

    function takeFocus() { liste.forceActiveFocus(); }
    function adet() { return istModel.count; }

    // Ilk acilista hazir Turk radyolari (adresler radio-browser.info'dan; telefonda denendi: MP3, AAC, HLS)
    function hazirla() {
        if (parseInt(app.sorgu("SELECT COUNT(*) AS n FROM istasyon")[0].n, 10) === 0) {
            var l = [
                ["TRT FM", "https://rd-trtfm.medya.trt.com.tr/master_128.m3u8", "AAC"],
                ["TRT Radyo 1", "https://rd-trtradyo1.medya.trt.com.tr/master_128.m3u8", "AAC"],
                ["TRT Radyo 3", "https://rd-trtradyo3.medya.trt.com.tr/master_128.m3u8", "AAC"],
                ["TRT Türkü", "https://rd-trtturku.medya.trt.com.tr/master_128.m3u8", "AAC"],
                ["TRT Nağme", "https://rd-trtnagme.medya.trt.com.tr/master_128.m3u8", "AAC"],
                ["Virgin Radio Türkiye", "http://25503.live.streamtheworld.com:3690/VIRGIN_RADIO_SC", "MP3"],
                ["Süper FM", "http://22343.live.streamtheworld.com:3690/SUPER_FMAAC_SC", "AAC+"],
                ["Metro FM", "http://29341.live.streamtheworld.com:3690/METRO_FMAAC_SC", "AAC+"],
                ["JOY Türk", "https://playerservices.streamtheworld.com/api/livestream-redirect/JOY_TURK_SC?/", "MP3"],
                ["Kral FM", "https://dygedge2.radyotvonline.net/kralfm/playlist.m3u8", "AAC"],
                ["Best FM", "https://ssldyg.radyotvonline.com/best/bestfm.stream/playlist.m3u8", "AAC"],
                ["Alem FM", "https://turkmedya.radyotvonline.net/alemfmaac", "AAC"],
                ["Radyo Fenomen", "https://live.radyofenomen.com/fenomen/128/icecast.audio", "AAC+"],
                ["Power Pop", "https://listen.powerapp.com.tr/powerpop/128/chunks.m3u8", "AAC"],
                ["Pop 90 Turkey", "http://28573.live.streamtheworld.com/POP90AAC_SC", "AAC+"],
                ["Radyo 7", "http://46.20.3.250/;stream", "MP3"],
                ["Baba Radyo", "http://officialbabaradyo.radyotvonline.net/babaofficial", "MP3"],
                ["DamarTürk FM", "https://live.radyositesihazir.com:10997/stream?type=http&nocache=99881", "MP3"],
                ["Türkülerle Türkiye", "http://37.247.98.8/stream/22/;", "MP3"],
                ["Altın Şarkılar", "http://37.247.98.8/stream/25/;", "MP3"]
            ];
            app.db().transaction(function (tx) {
                for (var i = 0; i < l.length; i++)
                    tx.executeSql("INSERT OR IGNORE INTO istasyon(url, ad, uuid, codec, bitrate, ulke, sira) VALUES(?, ?, '', ?, 0, 'TR', ?)", [l[i][1], l[i][0], l[i][2], i]);
            });
        }
        yukle();
    }
    function kayitliMi(url) { return app.sorgu("SELECT 1 FROM istasyon WHERE url = ?", [url]).length > 0; }
    function yukle() {
        hata = "";
        if (kip !== "kayitli") return;
        var l = app.sorgu("SELECT * FROM istasyon ORDER BY sira, ad");
        istModel.clear();
        for (var i = 0; i < l.length; i++)
            istModel.append({ ad: l[i].ad, url: l[i].url, uuid: l[i].uuid || "", codec: l[i].codec || "", bitrate: Number(l[i].bitrate) || 0, ulke: l[i].ulke || "", kayitli: true, ulkeSatiri: false, sayi: 0, kayit: false });
    }
    function kipSec(k) {
        kip = k;
        istModel.clear();
        hata = "";
        if (k === "kayitli") yukle();
        else if (k === "tr") api("stations/search?countrycode=" + app.evUlke + "&hidebroken=true&order=clickcount&reverse=true&limit=80");
        else if (k === "dunya") api("stations/topclick/80?hidebroken=true");
        else if (k === "ulke") { if (ulkeKod === "") api("countries?order=stationcount&reverse=true&hidebroken=true"); else api("stations/search?countrycode=" + ulkeKod + "&hidebroken=true&order=clickcount&reverse=true&limit=120"); }
        else if (k === "kayit") kayitlariYukle();
        else if (k === "ara") { if (arama === "") ara(); else api("stations/search?name=" + encodeURIComponent(arama) + "&hidebroken=true&order=clickcount&reverse=true&limit=80"); }
        liste.forceActiveFocus();
    }
    function api(yol) {
        yukleniyor = true;
        sonIstek = yol;
        yayin.getir("radyo:" + yol, sunucular[sunucu] + yol);
    }
    function ara() {
        input.open({ title: qsTr("İstasyon ara"), label1: qsTr("Ad, şehir ya da tür (ör. kral, ankara, jazz)"), text1: arama, ok: qsTr("Ara") }, function (q) {
            q = q.replace(/^\s+|\s+$/g, "");
            if (q === "") return;
            root.arama = q;
            root.kipSec("ara");
        });
    }
    function adresEkle() {
        input.open({ title: qsTr("Adresle istasyon ekle"), label1: qsTr("İstasyon adı"), text1: "", label2: qsTr("Yayın adresi (http://… mp3/aac/m3u8, .pls/.m3u da olur)"), text2: "http://", ok: qsTr("Ekle") }, function (ad, url) {
            url = url.replace(/^\s+|\s+$/g, "");
            if (url.length < 10) { app.showToast(qsTr("Geçersiz adres")); return; }
            if (ad.replace(/\s+/g, "") === "") ad = url.replace(/^https?:\/\//, "").split("/")[0];
            if (/\.(pls|m3u)(\?|$)/i.test(url)) { root.bekleyenAd = ad; yayin.getir("liste:" + url, url); app.showToast(qsTr("Çalma listesi okunuyor…")); return; }
            root.kaydet({ ad: ad, url: url, uuid: "", codec: "", bitrate: 0, ulke: "" });
        });
    }
    property string bekleyenAd: ""
    function kaydet(o) {
        var n = parseFloat(app.sorgu("SELECT MAX(sira) AS m FROM istasyon")[0].m) || 0;
        app.yurut("INSERT OR REPLACE INTO istasyon(url, ad, uuid, codec, bitrate, ulke, sira) VALUES(?, ?, ?, ?, ?, ?, ?)", [o.url, o.ad, o.uuid || "", o.codec || "", o.bitrate || 0, o.ulke || "", n + 1]);
        app.showToast(qsTr("Favorilere eklendi: ") + o.ad);
        if (kip === "kayitli") yukle(); else for (var i = 0; i < istModel.count; i++) if (istModel.get(i).url === o.url) istModel.setProperty(i, "kayitli", true);
    }
    function cikar(url, ad) {
        app.yurut("DELETE FROM istasyon WHERE url = ?", [url]);
        app.showToast(qsTr("Favorilerden çıkarıldı: ") + ad);
        if (kip === "kayitli") yukle(); else for (var i = 0; i < istModel.count; i++) if (istModel.get(i).url === url) istModel.setProperty(i, "kayitli", false);
    }
    function kayitlariYukle() {
        var l = yayin.kayitlar();
        istModel.clear();
        for (var i = 0; i < l.length; i++)
            istModel.append({ ad: l[i].ad, url: l[i].yol, uuid: "", codec: l[i].uzanti.toUpperCase(), bitrate: 0, ulke: app.zamanYazi(l[i].zaman), kayitli: false, ulkeSatiri: false, sayi: l[i].boyut, kayit: true });
        if (!istModel.count) hata = qsTr("Henüz kayıt yok. Bir radyo çalarken çubuktaki kırmızı düğmeye basın.");
    }
    // calinan listedeki istasyonlar (kanal ileri/geri icin)
    function kanallar() {
        var l = [];
        for (var i = 0; i < istModel.count; i++) { var o = istModel.get(i); if (!o.ulkeSatiri && !o.kayit) l.push({ tur: "radyo", ad: o.ad, url: o.url, uuid: o.uuid }); }
        return l;
    }
    function cal(i) {
        if (i < 0 || i >= istModel.count) return;
        var o = istModel.get(i);
        if (o.ulkeSatiri) { ulkeKod = o.url; ulkeAd = o.ad; kipSec("ulke"); return; }
        if (o.kayit) { app.cal({ tur: "dosya", ad: o.ad, url: o.url, yerel: o.url }); return; }
        app.cal({ tur: "radyo", ad: o.ad, url: o.url, uuid: o.uuid }, kanallar());
    }
    function tasi(i, d) {
        var l = app.sorgu("SELECT url FROM istasyon ORDER BY sira, ad"), j = i + d;
        if (j < 0 || j >= l.length) return;
        var a = l[i].url; l[i].url = l[j].url; l[j].url = a;
        app.db().transaction(function (tx) { for (var k = 0; k < l.length; k++) tx.executeSql("UPDATE istasyon SET sira = ? WHERE url = ?", [k, l[k].url]); });
        yukle();
        liste.currentIndex = j;
    }
    function menu(i) {
        if (i < 0 || i >= istModel.count) { genelMenu(); return; }
        var o = istModel.get(i), items = [];
        if (o.kayit) {
            sheet.open(o.ad, [
                { label: qsTr("Çal"), icon: "play", key: "cal" },
                { label: U.sizeText(o.sayi) + "  •  " + o.codec + "  •  " + o.ulke, icon: "info", key: "x" },
                { label: o.url, icon: "folder", key: "x" },
                { label: qsTr("Sil"), icon: "trash", key: "sil", danger: true }
            ], function (k) {
                if (k === "cal") root.cal(i);
                else if (k === "sil") { if (app.calan && app.calan.url === o.url) app.dur(); yayin.dosyaSil(o.url); app.showToast(qsTr("Kayıt silindi")); root.kayitlariYukle(); }
            });
            return;
        }
        if (o.ulkeSatiri) {
            sheet.open(o.ad, [{ label: qsTr("İstasyonlarını göster"), icon: "muzik", key: "ac" }, { label: qsTr("Ülkem yap (popüler listesi)"), icon: "home", key: "ev" }], function (k) {
                if (k === "ac") root.cal(i); else app.evUlkeAyarla(o.url, o.ad);
            });
            return;
        }
        items.push({ label: qsTr("Çal"), icon: "play", key: "cal", hint: qsTr("Enter") });
        items.push({ label: o.kayitli ? qsTr("Favorilerden çıkar") : qsTr("Favorilere ekle"), icon: o.kayitli ? "star_o" : "star", key: "kayit", hint: "F" });
        if (kip === "kayitli") {
            items.push({ label: qsTr("Yeniden adlandır"), icon: "edit", key: "ad", hint: "R" });
            if (i > 0) items.push({ label: qsTr("Yukarı taşı"), icon: "up", key: "yukari" });
            if (i < istModel.count - 1) items.push({ label: qsTr("Aşağı taşı"), icon: "sort", key: "asagi" });
        }
        items.push({ label: qsTr("Bilgi ve adres"), icon: "info", key: "bilgi" });
        sheet.open(o.ad, items, function (k) {
            if (k === "cal") root.cal(i);
            else if (k === "kayit") { if (o.kayitli) root.cikar(o.url, o.ad); else root.kaydet(o); }
            else if (k === "ad") input.open({ title: qsTr("Yeniden adlandır"), label1: "", text1: o.ad, ok: qsTr("Kaydet") }, function (y) { if (y.replace(/\s+/g, "") === "") return; app.yurut("UPDATE istasyon SET ad = ? WHERE url = ?", [y, o.url]); root.yukle(); });
            else if (k === "yukari") root.tasi(i, -1);
            else if (k === "asagi") root.tasi(i, 1);
            else if (k === "bilgi") sheet.open(o.ad, [
                { label: (o.codec || qsTr("biçim ?")) + (o.bitrate ? "  •  " + o.bitrate + " kbps" : "") + (o.ulke ? "  •  " + o.ulke : ""), icon: "info", key: "x" },
                { label: o.url, icon: "globe", key: "x" }
            ], function () {});
        });
    }
    // Ulkem: Ulkeler listesine gec, bir ulkenin … menusunden "Ulkem yap"
    function ulkemSec() { ulkeKod = ""; ulkeAd = ""; kipSec("ulke"); app.showToast(qsTr("Ülkeyi seçin, … menüsünden 'Ülkem yap' deyin")); }
    function genelMenu() {
        sheet.open(qsTr("Radyo"), [
            { label: qsTr("İstasyon ara"), icon: "search", key: "ara", hint: "S" },
            { label: qsTr("Adresle istasyon ekle"), icon: "plus", key: "ekle", hint: "N" },
            { label: qsTr("Favoriler"), icon: "star", key: "k1", hint: "1" },
            { label: app.evUlkeAd + qsTr(" • popüler"), icon: "muzik", key: "k2", hint: "2" },
            { label: qsTr("Ülkemi değiştir (şu an: ") + app.evUlkeAd + ")", icon: "globe", key: "ulkem" },
            { label: qsTr("Dünyada popüler"), icon: "globe", key: "k3", hint: "3" },
            { label: qsTr("Ülkelere göz at"), icon: "globe", key: "k4", hint: "4" }
        ], function (k) {
            if (k === "ara") root.ara(); else if (k === "ekle") root.adresEkle();
            else if (k === "k1") root.kipSec("kayitli"); else if (k === "k2") root.kipSec("tr"); else if (k === "ulkem") root.ulkemSec(); else if (k === "k3") root.kipSec("dunya"); else if (k === "k4") { root.ulkeKod = ""; root.kipSec("ulke"); }
        });
    }

    Connections {
        target: yayin
        onMetinGeldi: {
            if (istekId.indexOf("radyo:") === 0) {
                if (istekId.substring(6) !== root.sonIstek) return;
                root.yukleniyor = false;
                if (hata !== "") {
                    if (root.sunucu < root.sunucular.length - 1) { root.sunucu++; root.api(root.sonIstek); return; }
                    root.hata = qsTr("Radyo listesi alınamadı: ") + hata;
                    return;
                }
                var l = [];
                try { l = JSON.parse(govde); } catch (e) { root.hata = qsTr("Geçersiz yanıt"); return; }
                istModel.clear();
                if (root.kip === "ulke" && root.ulkeKod === "") {
                    for (var c = 0; c < l.length; c++) {
                        if (!l[c].iso_3166_1 || (l[c].stationcount || 0) < 3) continue;
                        istModel.append({ ad: l[c].name, url: l[c].iso_3166_1, uuid: "", codec: "", bitrate: 0, ulke: l[c].iso_3166_1, kayitli: false, ulkeSatiri: true, sayi: l[c].stationcount || 0, kayit: false });
                    }
                    liste.currentIndex = 0;
                    return;
                }
                // adla sonuc yoksa ture (etiket) gore dene: jazz, rock, haber...
                if (l.length === 0 && root.kip === "ara" && root.sonIstek.indexOf("name=") >= 0) { root.api("stations/search?tag=" + encodeURIComponent(root.arama.toLowerCase()) + "&hidebroken=true&order=clickcount&reverse=true&limit=80"); return; }
                for (var i = 0; i < l.length; i++) {
                    var u = l[i].url_resolved || l[i].url;
                    if (!u) continue;
                    istModel.append({ ad: (l[i].name || "").replace(/^\s+|\s+$/g, ""), url: u, uuid: l[i].stationuuid || "", codec: l[i].codec || "",
                                   bitrate: l[i].bitrate || 0, ulke: l[i].countrycode || "", kayitli: root.kayitliMi(u), ulkeSatiri: false, sayi: 0, kayit: false });
                }
                if (!istModel.count) root.hata = qsTr("Sonuç yok");
                liste.currentIndex = 0;
            } else if (istekId.indexOf("liste:") === 0) {
                // .pls / .m3u: ilk http satiri
                var m = (govde || "").split(/\r?\n/), bulunan = "";
                for (var j = 0; j < m.length && bulunan === ""; j++) {
                    var s = m[j].replace(/^\s+|\s+$/g, "").replace(/^File\d+=/i, "");
                    if (/^https?:\/\//i.test(s)) bulunan = s;
                }
                if (bulunan === "") { app.showToast(qsTr("Listede yayın adresi bulunamadı")); return; }
                root.kaydet({ ad: root.bekleyenAd, url: bulunan });
            }
        }
    }

    ListModel { id: istModel }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: qsTr("Radyo")
        subtitle: root.kip === "kayitli" ? istModel.count + qsTr(" favori") : (root.kip === "ara" ? "\"" + root.arama + "\" • " + qsTr("tüm dünya") : (root.kip === "ulke" && root.ulkeKod === "" ? istModel.count + qsTr(" ülke") : istModel.count + qsTr(" istasyon")))
        busy: root.yukleniyor
        IconButton { icon: "search"; tone: "w"; iconSize: 24; onClicked: root.ara() }
        IconButton { icon: "plus"; tone: "a"; iconSize: 26; onClicked: root.adresEkle() }
        IconButton { icon: "more"; tone: "w"; iconSize: 24; onClicked: root.genelMenu() }
    }
    Flickable {
        id: hapSerit
        anchors { left: parent.left; right: parent.right; top: header.bottom }
        height: 44
        contentWidth: haplar.width + 20
        clip: true
        Row {
            id: haplar
            x: 10; anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Hap { yazi: qsTr("★ Favoriler"); secili: root.kip === "kayitli"; onTiklandi: root.kipSec("kayitli") }
            Hap { yazi: app.evUlkeAd + qsTr(" • popüler"); secili: root.kip === "tr"; onTiklandi: root.kipSec("tr") }
            Hap { yazi: qsTr("Dünyada popüler"); secili: root.kip === "dunya"; onTiklandi: root.kipSec("dunya") }
            Hap { yazi: root.ulkeAd !== "" ? qsTr("Ülke: ") + root.ulkeAd : qsTr("Ülkeler"); secili: root.kip === "ulke"; onTiklandi: { if (root.kip === "ulke") { root.ulkeKod = ""; root.ulkeAd = ""; } root.kipSec("ulke"); } }
            Hap { yazi: qsTr("\u25CF Kayıtlar"); secili: root.kip === "kayit"; onTiklandi: root.kipSec("kayit") }
            Hap { yazi: root.arama !== "" ? qsTr("Arama: ") + root.arama : qsTr("Ara…"); secili: root.kip === "ara"; onTiklandi: root.kipSec("ara") }
        }
    }
    ListView {
        id: liste
        anchors { left: parent.left; right: parent.right; top: hapSerit.bottom; bottom: parent.bottom }
        clip: true
        model: istModel
        highlightMoveDuration: 100
        delegate: Satir {
            width: liste.width
            baslik: ad
            simge: ulkeSatiri ? "globe" : (kayit ? "save" : "")
            alt: ulkeSatiri ? sayi + qsTr(" istasyon") : kayit ? U.sizeText(sayi) + "  •  " + codec + "  •  " + ulke : (app.calan && app.calan.url === url && app.calanBaslik !== "" ? "♪ " + app.calanBaslik : [codec, bitrate ? bitrate + " kbps" : "", root.kip !== "kayitli" ? ulke : ""].filter(function (x) { return x !== ""; }).join("  •  "))
            aktif: !!app.calan && app.calan.url === url
            secili: ListView.isCurrentItem && liste.activeFocus
            sagYazi: kayitli && root.kip !== "kayitli" ? "★" : ""
            onTiklandi: { liste.currentIndex = index; root.cal(index); }
            onBasiliTutuldu: { liste.currentIndex = index; root.menu(index); }
            onMenu: { liste.currentIndex = index; root.menu(index); }
        }
        Keys.onPressed: {
            var k = event.key, t = U.tus(event);
            if (app.ortakTus(event)) { event.accepted = true; return; }
            if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) root.cal(currentIndex);
            else if (k === Qt.Key_Space || k === Qt.Key_Menu || k === Qt.Key_Context1) root.menu(currentIndex);
            else if (k === Qt.Key_Left) app.stepTab(-1);
            else if (k === Qt.Key_Right) app.stepTab(1);
            else if (t === "s" || t === "/") root.ara();
            else if (t === "n") root.adresEkle();
            else if (t === "f") { if (currentIndex >= 0) { var o = istModel.get(currentIndex); if (o.kayitli) root.cikar(o.url, o.ad); else root.kaydet(o); } }
            else if (t === "1") root.kipSec("kayitli");
            else if (t === "2") root.kipSec("tr");
            else if (t === "3") root.kipSec("dunya");
            else if (t === "4") { root.ulkeKod = ""; root.ulkeAd = ""; root.kipSec("ulke"); }
            else if (t === "5") root.kipSec("ara");
            else if (t === "6") root.kipSec("kayit");
            else if ((k === Qt.Key_Backspace || k === Qt.Key_Escape || k === Qt.Key_Context2) && root.kip === "ulke" && root.ulkeKod !== "") { root.ulkeKod = ""; root.ulkeAd = ""; root.kipSec("ulke"); }
            else return;
            event.accepted = true;
        }
    }
    Text {
        anchors.centerIn: liste
        width: liste.width - 40
        visible: istModel.count === 0
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: root.yukleniyor ? qsTr("Yükleniyor…") : (root.hata !== "" ? root.hata : (root.kip === "kayitli" ? qsTr("Favori istasyon yok.\nAra (S), ülkelere göz at ya da adres ekle (N); istasyonun … menüsünden Favorilere ekle.") : ""))
        color: app.textSecondary
        font.pixelSize: Math.round(17 * app.yazi)
    }
}
