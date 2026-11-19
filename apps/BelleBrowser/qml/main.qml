import QtQuick 1.1
import "Db.js" as Db
import "Util.js" as U

// Belle Browser ana ekran.
// Dokunma: sayfa dogrudan dokunulur, uzun basma menusu sayfadan gelir.
// Klavye: ok tuslari imleci gezdirir (kenarda sayfayi kaydirir), orta tus tiklar, orta tusa uzun basma menu acar.
// Kisayollar: G adres, R yenile, T yeni sekme, W sekmeyi kapat, B yer imleri, H gecmis, D indirilenler,
// F sayfada bul, O okuma modu, M menu, I imlec ac/kapat, J/K sayfa asagi/yukari, N sonraki sekme, Z yakinlastir, Geri: onceki sayfa
Rectangle {
    id: app
    width: 640; height: 480
    property bool gece: tb.ayar("gece", "0") === "1"
    onGeceChanged: tb.setKoyu(gece)
    property color cZemin: gece ? "#15171a" : "#ffffff"
    property color cYuzey: gece ? "#25282d" : "#f1f3f4"
    property color cYazi: gece ? "#e8eaed" : "#202124"
    property color cIkinci: gece ? "#9aa0a6" : "#5f6368"
    property color cCizgi: gece ? "#33373d" : "#dadce0"
    property color cVurgu: gece ? "#8ab4f8" : "#1a73e8"
    color: cZemin

    property int aktif: 0
    property variant s: null              // etkin sekme
    property bool cubukGizli: false
    property bool imlecAcik: false
    property real ix: width / 2
    property real iy: height / 2
    property int adim: 7
    property double sonTus: 0
    property bool seciliBasili: false
    property string arama: tb.ayar("arama", "ddg")
    property string anaSayfa: tb.ayar("anasayfa", "")
    property int yaziYuzde: parseInt(tb.ayar("yazi", "100"), 10)
    property string listeTuru: ""

    function bildir(m) { bildirim.goster(m); }
    function katmanAcik() { return overlayAcik(); }
    function overlayAcik() { return adres.acik || menu.acik || secim.acik || girdi.acik || liste.acik || oynatici.item !== null || bulCubugu.visible; }
    function odakla() {
        if (adres.acik || secim.acik || girdi.acik || menu.acik) return;
        if (oynatici.item) { oynatici.item.forceActiveFocus(); return; }
        if (liste.acik) { liste.forceActiveFocus(); return; }
        if (tb.yaziKipi) return;
        ana.forceActiveFocus();
    }
    function guncelle() { s = rep.count > aktif ? rep.itemAt(aktif) : null; }
    onAktifChanged: guncelle()

    // ---------- sekmeler ----------
    function adresYap(t) {
        t = t.replace(/^\s+|\s+$/g, "");
        if (U.adresMi(t)) return /^[a-z]+:\/\//i.test(t) ? t : ((tb.parolaVar && tb.mod !== "dogrudan") ? "https://" : "http://") + t;
        return U.MOTORLAR[arama].url + encodeURIComponent(t);
    }
    function git(t) { var u = adresYap(t); if (tb.parolaVar && tb.ayar("sadeHep", "0") === "1" && /^https?:/i.test(u) && u.indexOf(tb.sunucu) !== 0) u = tb.sadeAdres(u); ac(u); }
    function ac(u) { if (!s) { yeniSekme(u); return; } cubukGizli = false; s.ac(u); odakla(); }
    function yeniSekme(u, sabit) {
        if (sm.count >= 6) { if (u && s) { bildir(qsTr("En fazla 6 sekme: bu sekmede açılıyor")); ac(u); } else bildir(qsTr("En fazla 6 sekme açılabilir")); return; }
        sm.append({ ilk: u || "", sabit: !!sabit });
        aktif = sm.count - 1;
        guncelle();
        cubukGizli = false;
    }
    function sekmeKapat(i) {
        var sabitti = sm.get(i).sabit;
        if (sm.count <= 1) { if (s) { s.dur(); s.ac(""); } sm.setProperty(0, "sabit", false); if (sabitti) sabitleriKaydet(); return; }
        sm.remove(i);
        if (aktif >= sm.count) aktif = sm.count - 1;
        else if (i < aktif) aktif--;
        guncelle();
        if (sabitti) sabitleriKaydet();
    }
    function sabitleriKaydet() {
        var l = [];
        for (var i = 0; i < sm.count; i++) if (sm.get(i).sabit) { var t = rep.itemAt(i); if (t && t.url !== "") l.push(t.url); }
        tb.setAyar("sabitler", l.join("\n"));
    }
    function sabitle(i) {
        var t = rep.itemAt(i);
        if (!t || t.url === "") { bildir(qsTr("Boş sekme sabitlenemez")); return; }
        sm.setProperty(i, "sabit", !sm.get(i).sabit);
        sabitleriKaydet();
        bildir(sm.get(i).sabit ? qsTr("Sekme sabitlendi • uygulama açılınca yeniden açılır") : qsTr("Sabitleme kaldırıldı"));
    }
    function sekmeMenusu(i) {
        var t = rep.itemAt(i);
        if (!t) return;
        var bos = t.url === "";
        var o = [];
        if (!bos) o.push({ ad: sm.get(i).sabit ? qsTr("Sabitlemeyi kaldır") : qsTr("Sabitle"), ikon: "raptiye", anahtar: "sabit" });
        if (!bos) o.push({ ad: Db.favMi(t.url) ? qsTr("Yer iminden çıkar") : qsTr("Yer imi ekle"), ikon: "yildiz", anahtar: "fav" });
        if (!bos) o.push({ ad: qsTr("Adresi kopyala"), ikon: "kopya", anahtar: "kopya" });
        o.push({ ad: qsTr("Sekmeyi kapat"), ikon: "kapat", anahtar: "kapat" });
        if (sm.count > 1) o.push({ ad: qsTr("Diğer sekmeleri kapat (sabitler kalır)"), ikon: "kapat", anahtar: "digerleri", tehlike: true });
        secim.ac(bos ? qsTr("Yeni sekme") : (t.baslik || U.host(t.url)), o, function (k) {
            if (k === "sabit") sabitle(i);
            else if (k === "fav") { if (Db.favMi(t.url)) { Db.favSil(t.url); bildir(qsTr("Yer iminden çıkarıldı")); } else { Db.favEkle(t.url, t.baslik); bildir(qsTr("Yer imine eklendi")); } baslangic.yenile(); }
            else if (k === "kopya") { tb.setPano(t.url); bildir(qsTr("Adres kopyalandı")); }
            else if (k === "kapat") sekmeKapat(i);
            else if (k === "digerleri") { for (var j = sm.count - 1; j >= 0; j--) if (j !== i && !sm.get(j).sabit) { if (j < aktif) aktif--; sm.remove(j); } if (aktif >= sm.count) aktif = sm.count - 1; guncelle(); }
            if (liste.acik && liste.tur === "sekme") sekmeleriAc();
        });
    }
    function adresAc(u) { adres.ac(u !== undefined ? u : (s ? s.url : "")); }

    // ---------- imlec ----------
    function imlecOynat(dx, dy) {
        if (!imlecAcik) { imlecAcik = true; return; }
        var simdi = new Date().getTime();
        adim = simdi - sonTus < 170 ? Math.min(adim + 3, 28) : 7;
        sonTus = simdi;
        var ust = icerik.y, alt = Math.min(icerik.y + icerik.height, bulCubugu.visible ? bulCubugu.y : app.height);
        var nx = ix + dx * adim, ny = iy + dy * adim;
        if (s && s.url !== "") {
            if (ny > alt - 6) { s.kaydir(0, ny - (alt - 6)); ny = alt - 6; if (s.flick.contentY > 60) cubukGizli = true; }
            if (ny < ust + 6) { if (s.flick.contentY <= 0) cubukGizli = false; else s.kaydir(0, ny - (ust + 6)); ny = Math.max(ust + 6, ny); }
            if (nx > width - 4) { s.kaydir(nx - (width - 4), 0); nx = width - 4; }
            if (nx < 2) { s.kaydir(nx - 2, 0); nx = 2; }
        }
        ix = Math.max(0, Math.min(width - 2, nx));
        iy = Math.max(0, Math.min(height - 2, ny));
    }
    function imlecTikla(cift) {
        tb.tikla(ix, iy, cift);
        girdiDenetim.restart();
    }
    Timer {
        id: girdiDenetim
        interval: 380
        onTriggered: {
            if (app.s && app.s.url !== "" && app.s.odakGirdiMi()) { tb.yaziKipi = true; app.bildir(qsTr("Yazma modu • bitince orta tuşa basın")); }
            else app.odakla();
        }
    }
    Timer { id: uzunBasma; interval: 650; onTriggered: { app.seciliBasili = false; app.imlecMenusu(); } }
    function imlecMenusu() {
        if (!s || s.url === "") return;
        var y = ana.mapToItem(s, ix, iy);
        baglam(s.hedefAl(y.x, y.y));
    }
    Connections {
        target: tb
        onYaziBitir: { if (app.s) app.s.odakBirak(); app.imlecAcik = true; ana.forceActiveFocus(); }
        // sayfada uzun basma (WebKit menusu yerine)
        onSayfaBaglam: { if (!app.s || app.s.url === "" || app.overlayAcik()) return; var p = app.s.mapFromItem(app, sx, sy); app.baglam(app.s.hedefAl(p.x, p.y)); }
        onRaporBitti: app.bildir(mesaj)
    }
    function hataBildir() {
        var ek = qsTr("Belle Browser ") + tb.surum() + qsTr("\nadres: ") + (s ? s.url : "") + qsTr("\nmod: ") + tb.mod + qsTr(" • parola: ") + (tb.parolaVar ? "var" : "yok") + qsTr(" • kimlik: ") + tb.ua
               + qsTr("\nsekme: ") + sm.count + qsTr(" • ekran: ") + width + "x" + height + (tb.tasarruf ? "\n" + tb.tasarruf : "");
        girdi.ac(qsTr("Hata bildir"), qsTr("Ne oldu? Kısaca yazın. Uygulama günlüğü ve açık sayfanın adresi sunucuya gönderilir."), "", false, function (n) {
            tb.raporGonder(n, ek);
            bildir(qsTr("Rapor gönderiliyor…"));
        });
    }

    // ---------- menuler ----------
    function baglam(json) {
        if (secim.acik) return;
        var r = {};
        try { r = JSON.parse(json); } catch (e) { }
        var o = [];
        if (r.a) {
            o.push({ ad: qsTr("Aç"), ikon: "dunya", anahtar: "ac" });
            o.push({ ad: qsTr("Yeni sekmede aç"), ikon: "arti", anahtar: "yeni" });
            o.push({ ad: qsTr("Okuma modunda aç"), ikon: "kitap", anahtar: "oku" });
            o.push({ ad: qsTr("Sade görünümde aç"), ikon: "yazi", anahtar: "sade" });
            o.push({ ad: qsTr("Bağlantıyı indir"), ikon: "indir", anahtar: "indir" });
            o.push({ ad: qsTr("Bağlantıyı kopyala"), ikon: "kopya", anahtar: "kopya" });
            if (U.youtubeId(r.a)) o.push({ ad: qsTr("Videoyu oynat (sunucudan)"), ikon: "video", anahtar: "yt" });
        }
        if (r.img) { o.push({ ad: qsTr("Resmi aç"), ikon: "dunya", anahtar: "resim" }); o.push({ ad: qsTr("Resmi indir"), ikon: "indir", anahtar: "resimindir" }); }
        if (r.video) { o.push({ ad: qsTr("Videoyu oynat"), ikon: "video", anahtar: "video" }); o.push({ ad: qsTr("Videoyu indir"), ikon: "indir", anahtar: "videoindir" }); }
        if (!o.length) { o.push({ ad: qsTr("Sayfayı yenile"), ikon: "yenile", anahtar: "yenile" }); o.push({ ad: qsTr("Adresi kopyala"), ikon: "kopya", anahtar: "sayfakopya" }); }
        secim.ac(r.at || r.a || r.img || r.video || (s ? s.baslik : ""), o, function (k) {
            if (k === "ac") ac(r.a);
            else if (k === "yeni") yeniSekme(r.a);
            else if (k === "oku") okumaModu(r.a);
            else if (k === "sade") sadeModu(r.a);
            else if (k === "indir") indirBaslat(r.a, "");
            else if (k === "kopya") { tb.setPano(r.a); bildir(qsTr("Bağlantı kopyalandı")); }
            else if (k === "yt") videoAc(r.a, r.at || "");
            else if (k === "resim") ac(r.img);
            else if (k === "resimindir") indirBaslat(r.img, "");
            else if (k === "video") videoAc(r.video, s ? s.baslik : "");
            else if (k === "videoindir") indirBaslat(r.video, "");
            else if (k === "yenile" && s) s.yenile();
            else if (k === "sayfakopya" && s) { tb.setPano(s.url); bildir(qsTr("Adres kopyalandı")); }
        });
    }
    function baglantiMenusu(u, b) {
        secim.ac(b || u, [
            { ad: qsTr("Aç"), ikon: "dunya", anahtar: "ac" }, { ad: qsTr("Yeni sekmede aç"), ikon: "arti", anahtar: "yeni" },
            { ad: Db.favMi(u) ? qsTr("Yer iminden çıkar") : qsTr("Yer imine ekle"), ikon: "yildiz", anahtar: "fav" }, { ad: qsTr("Bağlantıyı kopyala"), ikon: "kopya", anahtar: "kopya" }
        ], function (k) {
            if (k === "ac") ac(u); else if (k === "yeni") yeniSekme(u);
            else if (k === "fav") { if (Db.favMi(u)) Db.favSil(u); else Db.favEkle(u, b); bildir(qsTr("Yer imleri güncellendi")); baslangic.yenile(); }
            else if (k === "kopya") tb.setPano(u);
        });
    }
    function dosyaSor(u, ad) {
        var medya = /\.(mp4|3gp|3g2|m4v|mov|mp3|m4a|aac|amr|wav)(\?|#|$)/i.test(u);
        var o = [{ ad: qsTr("İndir") + (ad ? ": " + ad : ""), ikon: "indir", anahtar: "indir" }];
        if (medya) o.push({ ad: qsTr("Dahili oynatıcıda aç"), ikon: "video", anahtar: "oynat" });
        o.push({ ad: qsTr("Başka uygulamada aç"), ikon: "paylas", anahtar: "dis" });
        o.push({ ad: qsTr("Bağlantıyı kopyala"), ikon: "kopya", anahtar: "kopya" });
        secim.ac(decodeURIComponent(u.replace(/[?#].*$/, "").split("/").pop()) || u, o, function (k) {
            if (k === "indir") indirBaslat(u, ad);
            else if (k === "oynat") videoAc(u, ad);
            else if (k === "dis") tb.disaAc(u);
            else if (k === "kopya") tb.setPano(u);
        });
    }
    function indirBaslat(u, ad) {
        if (indir.baslat(u, ad) < 0) bildir(qsTr("İndirme başlatılamadı"));
        else bildir(qsTr("İndiriliyor → ") + indir.klasor + qsTr("  (Menü > İndirilenler)"));
    }
    function sadeModu(u) {
        if (!u) return;
        if (!tb.parolaVar) { bildir(qsTr("Sade görünüm sunucuda hazırlanır: Ayarlar'dan sunucu parolasını girin")); return; }
        if (!/^(https?:\/\/|[^\s:\/]+\.[^\s]+)/i.test(u)) { bildir(qsTr("Bu sayfa sade görünümde açılamaz")); return; }
        bildir(qsTr("Sayfa sunucuda hazırlanıyor (birkaç saniye)…"));
        ac(tb.sadeAdres(u));
    }
    function okumaModu(u) {
        if (!u) return;
        if (!/^(https?:\/\/|[^\s:\/]+\.[^\s]+)/i.test(u)) { bildir(qsTr("Bu sayfa okuma modunda açılamaz")); return; }
        if (tb.parolaVar) ac(tb.okumaAdres(u));
        else ac("http://frogfind.com/read.php?a=" + encodeURIComponent(u));
    }

    // ---------- video ----------
    function videoAc(u, baslik) {
        var yid = U.youtubeId(u);
        if (yid) {
            if (!tb.parolaVar) { bildir(qsTr("YouTube videoları sunucuda dönüştürülür: Ayarlar'dan sunucu parolasını girin")); return; }
            bildir(qsTr("Video sunucuda hazırlanıyor…"));
            var x = new XMLHttpRequest();
            x.onreadystatechange = function () {
                if (x.readyState !== 4) return;
                var ok = false;
                try { ok = JSON.parse(x.responseText).ok; } catch (e) { }
                if (ok) oynaticiAc(tb.anahtarliAdres("/yt/stream/" + yid + ".mp4"), baslik || qsTr("YouTube"));
                else bildir(qsTr("Video hazırlanamadı") + (x.status ? qsTr(" (HTTP ") + x.status + ")" : ""));
            };
            x.open("GET", tb.sunucu + "/yt/prepare/" + yid + "?k=360");
            x.send();
            return;
        }
        oynaticiAc(/^https:/i.test(u) && tb.parolaVar ? tb.vekilAdres(u) : u, baslik);
        sonVideo = u;
    }
    property string sonVideo: ""
    function oynaticiAc(kaynak, baslik) {
        if (("" + kaynak).indexOf("https://e6.msahincelen.xyz") === 0) kaynak = "http://" + kaynak.substring(8);   // yerlesik oynatici TLS 1.2 bilmez
        oynatici.source = "VideoOynatici.qml";
        if (oynatici.status !== Loader.Ready || !oynatici.item) { oynatici.source = ""; bildir(qsTr("Dahili oynatıcı açılamadı; dosyayı indirip açabilirsiniz")); return; }
        oynatici.item.oynat(kaynak, baslik);
    }
    function videoKapat() { if (oynatici.item) oynatici.item.durdur(); oynatici.source = ""; odakla(); }
    function videoHatasi(e) {
        var u = sonVideo;
        videoKapat();
        secim.ac(qsTr("Video oynatılamadı: ") + e, [{ ad: qsTr("İndir (sonra harici oynatıcı)"), ikon: "indir", anahtar: "i" }, { ad: qsTr("Başka uygulamada aç"), ikon: "paylas", anahtar: "d" }], function (k) {
            if (!u) return;
            if (k === "i") indirBaslat(u, ""); else tb.disaAc(u);
        });
    }
    function videolariGoster() {
        if (!s) return;
        var l = s.videolar, o = [];
        if (U.youtubeId(s.url)) o.push({ ad: qsTr("Bu YouTube videosu (sunucuda dönüştür)"), ikon: "video", anahtar: s.url });
        for (var i = 0; i < l.length; i++) o.push({ ad: decodeURIComponent(("" + l[i]).replace(/[?#].*$/, "").split("/").pop()) || l[i], ikon: "video", anahtar: l[i] });
        if (!o.length) { bildir(qsTr("Bu sayfada oynatılabilir video bulunamadı")); return; }
        secim.ac(qsTr("Videolar"), o, function (k) { videoAc(k, s.baslik); });
    }

    // ---------- liste sayfalari ----------
    function favlariAc() {
        var f = Db.favlar(), o = [];
        for (var i = 0; i < f.length; i++) o.push({ baslik: f[i].baslik, alt: f[i].url, ikon: "yildizd", anahtar: f[i].url });
        liste.ekDugme = "";
        liste.ac(qsTr("Yer imleri"), "fav", o);
    }
    function gecmisiAc() {
        var g = Db.gecmis(200), o = [];
        for (var i = 0; i < g.length; i++) o.push({ baslik: g[i].baslik, alt: g[i].url, ikon: "gecmis", anahtar: g[i].url });
        liste.ekDugme = "kapat";
        liste.ac(qsTr("Geçmiş"), "gecmis", o);
    }
    function indirilenOgeleri() {
        var l = indir.liste, o = [];
        for (var i = 0; i < l.length; i++) {
            var d = l[i];
            var alt = d.durum === "iniyor" ? U.boyut(d.alinan) + (d.toplam > 0 ? " / " + U.boyut(d.toplam) : "") + qsTr(" • iniyor")
                    : (d.durum === "bitti" ? U.boyut(d.toplam) + " • " + d.yol : d.durum === "iptal" ? qsTr("İptal edildi") : qsTr("Hata"));
            o.push({ baslik: d.ad, alt: alt, ikon: d.durum === "bitti" ? "indir" : (d.durum === "iniyor" ? "yenile" : "kapat"), anahtar: d.id, oran: d.durum === "iniyor" && d.toplam > 0 ? d.alinan / d.toplam : -1 });
        }
        return o;
    }
    function indirilenleriAc() { liste.ekDugme = "kapat"; liste.ac(qsTr("İndirilenler • ") + indir.klasor, "indir", indirilenOgeleri()); }
    Connections { target: indir; onDegisti: if (liste.acik && liste.tur === "indir") liste.doldur(app.indirilenOgeleri())
        onBitti: app.bildir(ok ? qsTr("İndirildi: ") + ad : qsTr("İndirilemedi: ") + ad + " (" + mesaj + ")") }
    function sekmeleriAc() {
        var o = [];
        for (var i = 0; i < rep.count; i++) { var t = rep.itemAt(i); o.push({ baslik: (i === aktif ? "● " : "") + (t.url === "" ? qsTr("Yeni sekme") : (t.baslik || U.host(t.url))), alt: t.url, ikon: sm.get(i).sabit ? "raptiye" : "sekme", anahtar: i, sag: "kapat" }); }
        liste.ekDugme = "arti";
        if (liste.acik && liste.tur === "sekme") { liste.baslik = qsTr("Sekmeler (") + rep.count + qsTr(") • basılı tut: sabitle, yer imi"); liste.doldur(o); }
        else liste.ac(qsTr("Sekmeler (") + rep.count + qsTr(") • basılı tut: sabitle, yer imi"), "sekme", o);
    }
    function ayarOgeleri() {
        var modAd = { dogrudan: qsTr("Doğrudan"), akilli: qsTr("Akıllı (HTTPS sunucudan)"), sikistir: qsTr("Sıkıştırılmış (her şey sunucudan)") };
        var uaAd = { mobil: qsTr("Mobil (hafif sayfalar)"), masa: qsTr("Masaüstü"), modern: qsTr("Modern mobil") };
        return [
            { baslik: qsTr("Sunucu parolası"), alt: tb.parolaVar ? qsTr("Girildi • sunucu katmanı kullanılabilir") : qsTr("Girilmedi • yalnızca doğrudan bağlantı"), ikon: "sunucu", anahtar: "parola" },
            { baslik: qsTr("Bağlantı modu"), alt: modAd[tb.mod] || tb.mod, ikon: "simsek", anahtar: "mod" },
            { baslik: qsTr("Sayfaları sade görünümde aç"), alt: (tb.ayar("sadeHep", "0") === "1" ? qsTr("Açık") : qsTr("Kapalı")) + qsTr(" • yerleşimi bozuk siteler sunucuda tek sütuna indirilir"), ikon: "yazi", anahtar: "sadehep" },
            { baslik: qsTr("Resim kalitesi (sıkıştırılmış mod)"), alt: tb.resimW + qsTr(" px genişlik"), ikon: "dunya", anahtar: "resim" },
            { baslik: qsTr("Sunucu adresi"), alt: tb.sunucu, ikon: "sunucu", anahtar: "sunucu" },
            { baslik: qsTr("Tarayıcı kimliği"), alt: uaAd[tb.ua] || tb.ua, ikon: "masa", anahtar: "ua" },
            { baslik: qsTr("Arama motoru"), alt: U.MOTORLAR[arama].ad, ikon: "ara", anahtar: "arama" },
            { baslik: qsTr("Ana sayfa"), alt: anaSayfa === "" ? qsTr("Başlangıç sayfası") : anaSayfa, ikon: "ev", anahtar: "anasayfa" },
            { baslik: qsTr("Reklam engelleyici"), alt: tb.reklam ? qsTr("Açık") : qsTr("Kapalı"), ikon: "dur", anahtar: "reklam" },
            { baslik: qsTr("Resimleri yükle"), alt: tb.ayar("resimler", "1") === "1" ? qsTr("Açık") : qsTr("Kapalı (yeni sekmelerde)"), ikon: "dunya", anahtar: "resimler" },
            { baslik: qsTr("Sertifika hatalarını yok say"), alt: (tb.sertifikaYoksay ? qsTr("Açık") : qsTr("Kapalı")) + qsTr(" • yalnızca doğrudan bağlantıda"), ikon: "kilit", anahtar: "sertifika" },
            { baslik: qsTr("İndirme klasörü"), alt: indir.klasor, ikon: "indir", anahtar: "klasor" },
            { baslik: qsTr("Çerezleri sil"), alt: qsTr("Tüm sitelerden çıkış yapılır"), ikon: "kapat", anahtar: "cerez" },
            { baslik: qsTr("Önbelleği temizle"), alt: "", ikon: "kapat", anahtar: "onbellek" },
            { baslik: qsTr("Geçmişi temizle"), alt: "", ikon: "gecmis", anahtar: "gecmissil" },
            { baslik: qsTr("Hata bildir"), alt: qsTr("Sorunu yazın; günlük sunucuya gönderilir"), ikon: "paylas", anahtar: "rapor" },
            { baslik: "Dil / Language", alt: ((dil.secim === "auto" ? dil.kod : dil.secim) === "en" ? "English" : "Türkçe") + (dil.yenidenBaslat ? " • yeniden açınca / restart to apply" : ""), ikon: "dunya", anahtar: "dil" },
            { baslik: qsTr("Depolama yeri"), alt: depo.ad(depo.secim) + (depo.yenidenBaslat ? qsTr(" (yeniden açınca geçerli olur)") : ""), ikon: "indir", anahtar: "depo" },
            { baslik: qsTr("Hakkında"), alt: qsTr("Belle Browser ") + tb.surum() + (tb.tasarruf ? " • " + tb.tasarruf : ""), ikon: "ayar", anahtar: "hakkinda" }
        ];
    }
    function ayarlariAc() { liste.ekDugme = ""; liste.ac(qsTr("Ayarlar"), "ayar", ayarOgeleri()); }
    function ayarSec(k) {
        var yenile = function () { liste.doldur(ayarOgeleri()); };
        if (k === "dil") { var dk = dil.secim === "auto" ? dil.kod : dil.secim; dil.sec(dk === "en" ? "tr" : "en"); yenile(); return; }
        if (k === "depo") { depo.sec(depo.sonraki()); yenile(); return; }
        if (k === "sadehep") { tb.setAyar("sadeHep", tb.ayar("sadeHep", "0") === "1" ? "0" : "1"); yenile(); return; }
        if (k === "parola") girdi.ac(qsTr("Sunucu parolası"), qsTr("Telefondaki diğer Belle uygulamalarında kullandığınız sunucu parolası. HTTPS siteler, resim küçültme, okuma modu ve YouTube için gerekir."), "", true, function (p) {
            if (p === "") { tb.parolaSil(); yenile(); return; }
            var r = tb.setParola(p);
            bildir(r === 1 ? qsTr("Parola doğrulandı • sunucu katmanı hazır") : (r === 0 ? qsTr("Parola hatalı") : qsTr("Sunucuya ulaşılamadı")));
            yenile();
        });
        else if (k === "mod") secim.ac(qsTr("Bağlantı modu"), [
            { ad: qsTr("Doğrudan (sunucu kullanılmaz)"), anahtar: "dogrudan" },
            { ad: qsTr("Akıllı: HTTPS sunucudan, HTTP doğrudan"), anahtar: "akilli" },
            { ad: qsTr("Sıkıştırılmış: her şey sunucudan, resimler küçük"), anahtar: "sikistir" }], function (m) {
                tb.setMod(m); yenile();
                if (m !== "dogrudan" && !tb.parolaVar) { bildir(qsTr("Bu mod için sunucu parolası gerekir")); ayarSec("parola"); }
                else if (m === "sikistir") bildir(qsTr("Sıkıştırılmış mod açık • adres çubuğundaki şimşek ve tasarruf bilgisi çalıştığını gösterir"));
                if (s && s.url) s.yenile(); });
        else if (k === "resim") secim.ac(qsTr("Resim kalitesi"), [
            { ad: qsTr("Düşük (480 px, en hızlı)"), anahtar: "480,12" }, { ad: qsTr("Orta (640 px)"), anahtar: "640,8" }, { ad: qsTr("Yüksek (960 px)"), anahtar: "960,5" }], function (v) {
                var a = v.split(","); tb.setResim(parseInt(a[0], 10), parseInt(a[1], 10)); yenile(); });
        else if (k === "sunucu") girdi.ac(qsTr("Sunucu adresi"), qsTr("Örnek: 203.0.113.10 (diğer Belle uygulamalarıyla ortak)"), tb.sunucu, false, function (v) { if (v) { tb.setSunucu(v); yenile(); } });
        else if (k === "ua") secim.ac(qsTr("Tarayıcı kimliği"), [
            { ad: qsTr("Mobil (hafif, eski WebKit'e uygun sayfalar)"), anahtar: "mobil" }, { ad: qsTr("Masaüstü"), anahtar: "masa" }, { ad: qsTr("Modern mobil (bazı siteler ağır gelebilir)"), anahtar: "modern" }], function (v) { tb.setUa(v); yenile(); });
        else if (k === "arama") {
            var o = [];
            for (var m in U.MOTORLAR) o.push({ ad: U.MOTORLAR[m].ad, anahtar: m });
            secim.ac(qsTr("Arama motoru"), o, function (v) { arama = v; tb.setAyar("arama", v); yenile(); });
        }
        else if (k === "anasayfa") girdi.ac(qsTr("Ana sayfa"), qsTr("Boş bırakılırsa başlangıç sayfası açılır"), anaSayfa === "" && s ? s.url : anaSayfa, false, function (v) { anaSayfa = v; tb.setAyar("anasayfa", v); yenile(); });
        else if (k === "reklam") { tb.setReklam(!tb.reklam); yenile(); }
        else if (k === "resimler") { tb.setAyar("resimler", tb.ayar("resimler", "1") === "1" ? "0" : "1"); yenile(); }
        else if (k === "sertifika") { tb.setSertifikaYoksay(!tb.sertifikaYoksay); yenile(); }
        else if (k === "klasor") secim.ac(qsTr("İndirme klasörü"), [
            { ad: qsTr("Hafıza kartı: E:/Downloads"), anahtar: "E:/Downloads" }, { ad: qsTr("Telefon: C:/Data/Downloads"), anahtar: "C:/Data/Downloads" },
            { ad: qsTr("Hafıza kartı: E:/BelleBrowser/Indirilen"), anahtar: "E:/BelleBrowser/Indirilen" }], function (v) { indir.setKlasor(v); yenile(); });
        else if (k === "cerez") { tb.cerezSil(); bildir(qsTr("Çerezler silindi")); }
        else if (k === "onbellek") { tb.onbellekSil(); bildir(qsTr("Önbellek temizlendi")); }
        else if (k === "gecmissil") { Db.gecmisSil(); bildir(qsTr("Geçmiş temizlendi")); }
        else if (k === "rapor") hataBildir();
        else if (k === "hakkinda") secim.ac(qsTr("Belle Browser ") + tb.surum() + qsTr(" • QtWebKit • Sunucu katmanı: ") + tb.sunucu + (tb.tasarruf ? " • " + tb.tasarruf : ""),
            [{ ad: qsTr("Tamam"), anahtar: "x" }], function () { });
    }

    // ---------- menu ----------
    function menuSec(k) {
        if (k === "yeni") { yeniSekme(anaSayfa); }
        else if (k === "sekmeler") sekmeleriAc();
        else if (k === "favlar") favlariAc();
        else if (k === "gecmis") gecmisiAc();
        else if (k === "indirilen") indirilenleriAc();
        else if (k === "favekle" && s && s.url !== "") { if (Db.favMi(s.url)) { Db.favSil(s.url); bildir(qsTr("Yer iminden çıkarıldı")); } else { Db.favEkle(s.url, s.baslik); bildir(qsTr("Yer imine eklendi")); } }
        else if (k === "bul") { bulCubugu.visible = true; bulAlan.text = ""; bulAlan.forceActiveFocus(); }
        else if (k === "oku" && s) okumaModu(s.url);
        else if (k === "sade" && s) sadeModu(s.url);
        else if (k === "masa") { tb.setUa(tb.ua === "masa" ? "mobil" : "masa"); bildir(tb.ua === "masa" ? qsTr("Masaüstü sitesi istenecek") : qsTr("Mobil site istenecek")); if (s && s.url) s.yenile(); }
        else if (k === "mod") ayarSec("mod");
        else if (k === "uzak") { if (!tb.belleRemoteAc(s ? s.url : "")) bildir(qsTr("Belle Remote açılamadı (kurulu mu?)")); }
        else if (k === "videolar") videolariGoster();
        else if (k === "gece") { gece = !gece; tb.setAyar("gece", gece ? "1" : "0"); for (var i = 0; i < rep.count; i++) rep.itemAt(i).gece(gece); }
        else if (k === "yazi") secim.ac(qsTr("Yazı boyutu"), [{ ad: "%85", anahtar: "85" }, { ad: "%100", anahtar: "100" }, { ad: "%120", anahtar: "120" }, { ad: "%140", anahtar: "140" }, { ad: "%165", anahtar: "165" }],
                                    function (v) { yaziYuzde = parseInt(v, 10); tb.setAyar("yazi", v); });
        else if (k === "kopya" && s) { tb.setPano(s.url); bildir(qsTr("Adres kopyalandı")); }
        else if (k === "dis" && s && s.url) tb.disaAc(s.url);
        else if (k === "imlec") { imlecAcik = !imlecAcik; if (imlecAcik) { ix = width / 2; iy = height / 2; } }
        else if (k === "ev") ac(anaSayfa);
        else if (k === "ayarlar") ayarlariAc();
        else if (k === "rapor") hataBildir();
        else if (k === "cikis") Qt.quit();
    }

    ListModel { id: sm }

    // ---------- ust cubuk ----------
    Rectangle {
        id: cubuk
        anchors { left: parent.left; right: parent.right }
        y: app.cubukGizli ? -height : 0
        Behavior on y { NumberAnimation { duration: 140 } }
        height: 54
        z: 10
        color: app.cZemin
        IkonDugme { id: geriD; anchors { left: parent.left; verticalCenter: parent.verticalCenter } ikon: "geri"; enabled: app.s !== null && app.s.geriVar
            onClicked: app.s.geri(); onPressAndHold: app.gecmisiAc() }
        Rectangle {
            id: hap
            anchors { left: geriD.right; right: sekmeD.left; verticalCenter: parent.verticalCenter; rightMargin: 2 }
            height: 40; radius: 20
            color: hm.pressed ? app.cCizgi : app.cYuzey
            Image {
                id: guven
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                width: 18; height: 18; smooth: true
                property bool vekil: app.s !== null && tb.parolaVar && (tb.mod === "sikistir" || (tb.mod === "akilli" && /^https:/.test(app.s.url)))
                source: "../images/" + (vekil ? "simsek" : (app.s && /^https:/.test(app.s.url) ? "kilit" : (app.s && app.s.url === "" ? "ara" : "dunya"))) + "_" + (vekil ? "m" : (app.gece ? "b" : "k")) + ".png"
            }
            Column {
                anchors { left: guven.right; leftMargin: 10; right: yenD.left; verticalCenter: parent.verticalCenter }
                Text {
                    width: parent.width
                    text: !app.s || app.s.url === "" ? qsTr("Ara ya da adres yaz") : (app.s.yukleniyor ? U.host(app.s.url) : (app.s.baslik !== "" && app.s.baslik !== app.s.url ? app.s.baslik : U.host(app.s.url)))
                    color: !app.s || app.s.url === "" ? app.cIkinci : app.cYazi
                    font.pixelSize: guven.vekil ? 18 : 20; elide: Text.ElideRight
                }
                Text {
                    width: parent.width; visible: guven.vekil
                    text: (tb.mod === "sikistir" ? qsTr("Sıkıştırılmış") : qsTr("Sunucudan")) + (tb.tasarruf ? " • " + tb.tasarruf : "")
                    color: app.cVurgu; font.pixelSize: 14; elide: Text.ElideRight
                }
            }
            MouseArea { id: hm; anchors { fill: parent; rightMargin: 44 } onClicked: app.adresAc() }
            IkonDugme { id: yenD; anchors { right: parent.right; verticalCenter: parent.verticalCenter } boy: 20
                visible: app.s !== null && app.s.url !== ""
                ikon: app.s && app.s.yukleniyor ? "dur" : "yenile"
                onClicked: { if (app.s.yukleniyor) app.s.dur(); else app.s.yenile(); } }
        }
        Item {
            id: sekmeD
            anchors { right: menuD.left; verticalCenter: parent.verticalCenter }
            width: 44; height: 44
            Rectangle { anchors.centerIn: parent; width: 24; height: 24; radius: 5; color: "transparent"; border.width: 2; border.color: app.cYazi
                Text { anchors.centerIn: parent; text: sm.count; font.pixelSize: 16; font.bold: true; color: app.cYazi } }
            MouseArea { anchors.fill: parent; onClicked: app.sekmeleriAc(); onPressAndHold: app.yeniSekme(app.anaSayfa) }
        }
        IkonDugme { id: menuD; anchors { right: parent.right; verticalCenter: parent.verticalCenter } ikon: "menu"; onClicked: menu.ac() }
        Rectangle {
            anchors { left: parent.left; bottom: parent.bottom }
            height: 3; color: app.cVurgu
            width: app.s && app.s.yukleniyor ? parent.width * Math.max(0.05, app.s.ilerleme) : 0
            visible: app.s !== null && app.s.yukleniyor
        }
        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: app.cCizgi; visible: !(app.s && app.s.yukleniyor) }
    }

    // ---------- icerik ----------
    Item {
        id: icerik
        // Yukseklik sabit: ust cubuk kayinca yalnizca kaydirilir, sayfa yeniden dizilmez (eskiden her karede diziliyordu, donma buydu)
        anchors { left: parent.left; right: parent.right }
        y: cubuk.y + cubuk.height
        height: app.height - (bulCubugu.visible ? bulCubugu.height : 0)
        Repeater {
            id: rep
            model: sm
            delegate: Sekme {
                anchors.fill: parent
                sayfaYuksekligi: app.height
                visible: index === app.aktif
                Component.onCompleted: { if (ilk !== "") ac(ilk); app.guncelle(); }
                yaziBoyu: Math.round(16 * app.yaziYuzde / 100)
                onKaydirildi: { if (dy > 0 && flick.contentY > 80) app.cubukGizli = true; else if (dy < -8) app.cubukGizli = false; }
                onDosyaIstendi: app.dosyaSor(u, ad)
                onBaglamIstendi: app.baglam(json)
                onYuklendi: { Db.gecmisEkle(url, baslik); if (sabit) app.sabitleriKaydet(); }
                onDokunuldu: app.imlecAcik = false
                onYeniPencere: app.yeniSekme(u)
                onYukleniyorChanged: if (yukleniyor && index === app.aktif) app.cubukGizli = false
            }
            onItemAdded: app.guncelle()
            onItemRemoved: app.guncelle()
        }
    }
    // Baslangic ve hata ekrani: cubugun altinda, ekrana sigar (sayfa alani gibi kaymaz)
    Item {
        id: sabitAlan
        anchors { left: parent.left; right: parent.right; top: cubuk.bottom; bottom: bulCubugu.visible ? bulCubugu.top : parent.bottom }
        Baslangic {
            id: baslangic
            anchors.fill: parent
            visible: !app.s || app.s.url === ""
            onAc: app.ac(url)
        }
        // sayfa acilamadi
        Rectangle {
            anchors.fill: parent
            visible: app.s !== null && app.s.hata && app.s.url !== ""
            color: app.cZemin
            Column {
                anchors.centerIn: parent
                width: Math.min(parent.width - 40, 520)
                spacing: 12
                Text { width: parent.width; text: qsTr("Sayfa açılamadı"); font.pixelSize: 28; font.bold: true; color: app.cYazi }
                Text { width: parent.width; wrapMode: Text.Wrap; color: app.cIkinci; font.pixelSize: 19
                    text: (app.s ? U.host(app.s.url) : "") + (tb.parolaVar && tb.mod !== "dogrudan" ? qsTr("\nSunucu katmanı da açamadı; site kapalı olabilir.") : qsTr("\nTelefonun eski güvenlik (TLS) desteği modern HTTPS sitelerine yetmeyebilir. Sunucu katmanı bunu çözer.")) }
                Flow {
                    width: parent.width; spacing: 8
                    Dugme { metin: qsTr("Yeniden dene"); ana: true; onClicked: app.s.yenile() }
                    Dugme { metin: tb.parolaVar ? qsTr("Akıllı moda geç") : qsTr("Sunucu parolası gir"); visible: !tb.parolaVar || tb.mod === "dogrudan"
                        onClicked: { if (!tb.parolaVar) app.ayarSec("parola"); else { tb.setMod("akilli"); app.s.yenile(); } } }
                    Dugme { metin: qsTr("Okuma modu"); onClicked: app.okumaModu(app.s.url) }
                    Dugme { metin: qsTr("Sade görünüm"); onClicked: app.sadeModu(app.s.url) }
                    Dugme { metin: qsTr("Belle Remote'ta aç"); onClicked: tb.belleRemoteAc(app.s.url) }
                }
            }
        }
        // video cipi
        Rectangle {
            anchors { right: parent.right; bottom: parent.bottom; margins: 12 }
            z: 5
            visible: app.s !== null && app.s.url !== "" && !app.s.yukleniyor && (app.s.videolar.length > 0 || U.youtubeId(app.s.url) !== "")
            width: vt.paintedWidth + 50; height: 40; radius: 20
            color: "#e61a73e8"
            Image { anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter } width: 22; height: 22; smooth: true; source: "../images/video_b.png" }
            Text { id: vt; anchors { left: parent.left; leftMargin: 38; verticalCenter: parent.verticalCenter } color: "#fff"; font.pixelSize: 19
                text: U.youtubeId(app.s ? app.s.url : "") ? qsTr("Oynat") : qsTr("Video (") + (app.s ? app.s.videolar.length : 0) + ")" }
            MouseArea { anchors.fill: parent; onClicked: app.videolariGoster() }
        }
    }

    // ---------- sayfada bul ----------
    Rectangle {
        id: bulCubugu
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 52; visible: false; color: app.cZemin; z: 12
        Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: app.cCizgi }
        Rectangle {
            anchors { left: parent.left; right: sonraki.left; verticalCenter: parent.verticalCenter; leftMargin: 10 }
            height: 38; radius: 19; color: app.cYuzey
            TextInput {
                id: bulAlan
                anchors { left: parent.left; right: parent.right; margins: 14; verticalCenter: parent.verticalCenter }
                font.pixelSize: 21; color: app.cYazi
                inputMethodHints: Qt.ImhNoPredictiveText
                onAccepted: sonraki.clicked()
                Keys.onPressed: {
                    // Ctrl+V yapistir / Ctrl+A tumunu sec (E6: Ctrl+V "7" ya da kod 22 gonderir)
                    if (((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_V || event.text === "7" || event.text === "v")) || event.text === "\u0016") { pano.yapistir(bulAlan); event.accepted = true; return; }
                    if (((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_A || event.text === "a")) || event.text === "\u0001") { bulAlan.selectAll(); event.accepted = true; return; }
                    if (event.text === "\r" || event.key === Qt.Key_Select) { sonraki.clicked(); event.accepted = true; }
                    else if (event.key === Qt.Key_Escape) { kapatB.clicked(); event.accepted = true; }
                }
            }
        }
        IkonDugme { id: sonraki; anchors { right: kapatB.left; verticalCenter: parent.verticalCenter } ikon: "ara"
            onClicked: { bulAlan.focus = false; bulCubugu.forceActiveFocus(); if (app.s && !app.s.bul(bulAlan.text)) app.bildir(qsTr("Bulunamadı")); bulAlan.forceActiveFocus(); } }
        IkonDugme { id: kapatB; anchors { right: parent.right; verticalCenter: parent.verticalCenter } ikon: "kapat"; onClicked: { bulCubugu.visible = false; app.odakla(); } }
    }

    // ---------- imlec ve klavye ----------
    Image {
        id: imlec
        x: app.ix - 3; y: app.iy - 2
        z: 40
        width: 26; height: 26; smooth: true
        visible: app.imlecAcik && !app.overlayAcik()
        source: "../images/imlec_k.png"
    }
    Item {
        id: ana
        focus: true
        Keys.onPressed: {
            var k = event.key, t = U.tus(event);
            if (k === Qt.Key_Left) { app.imlecOynat(-1, 0); event.accepted = true; }
            else if (k === Qt.Key_Right) { app.imlecOynat(1, 0); event.accepted = true; }
            else if (k === Qt.Key_Up) { app.imlecOynat(0, -1); event.accepted = true; }
            else if (k === Qt.Key_Down) { app.imlecOynat(0, 1); event.accepted = true; }
            else if (k === Qt.Key_Select || k === Qt.Key_Return || k === Qt.Key_Enter) {
                event.accepted = true;
                if (event.isAutoRepeat) return;
                if (!app.imlecAcik) { app.imlecAcik = true; return; }
                app.seciliBasili = true;
                uzunBasma.restart();
            }
            else if (k === Qt.Key_Backspace || k === Qt.Key_Context2) { if (app.s && app.s.geriVar) app.s.geri(); else if (app.s && app.s.url !== "") app.ac(""); event.accepted = true; }
            else if (k === Qt.Key_Context1 || k === Qt.Key_Menu) { menu.ac(); event.accepted = true; }
            else if (k === Qt.Key_Space) { if (app.s) app.s.sayfa((event.modifiers & Qt.ShiftModifier) ? -1 : 1); event.accepted = true; }
            else if (t === "g" || t === "l") { app.adresAc(); event.accepted = true; }
            else if (t === "r") { if (app.s && app.s.url) app.s.yenile(); event.accepted = true; }
            else if (t === "t") { app.yeniSekme(app.anaSayfa); event.accepted = true; }
            else if (t === "w") { app.sekmeKapat(app.aktif); event.accepted = true; }
            else if (t === "n") { if (sm.count > 1) app.aktif = (app.aktif + 1) % sm.count; event.accepted = true; }
            else if (t === "b") { app.favlariAc(); event.accepted = true; }
            else if (t === "h") { app.gecmisiAc(); event.accepted = true; }
            else if (t === "d") { app.indirilenleriAc(); event.accepted = true; }
            else if (t === "f") { app.menuSec("bul"); event.accepted = true; }
            else if (t === "o") { if (app.s) app.okumaModu(app.s.url); event.accepted = true; }
            else if (t === "m") { menu.ac(); event.accepted = true; }
            else if (t === "i") { app.menuSec("imlec"); event.accepted = true; }
            else if (t === "j") { if (app.s) app.s.sayfa(1); event.accepted = true; }
            else if (t === "k") { if (app.s) app.s.sayfa(-1); event.accepted = true; }
            else if (t === "z") { if (app.s) { var y = ana.mapToItem(app.s, app.ix, app.iy); app.s.yakinlas(app.s.olcek < app.s.temelOlcek * 1.4 ? app.s.temelOlcek * 2 : app.s.temelOlcek, y.x, y.y); } event.accepted = true; }
            else if (t === "v") { app.videolariGoster(); event.accepted = true; }
            else if (t === "e") { if (app.s) app.s.basaGit(); app.cubukGizli = false; event.accepted = true; }
        }
        Keys.onReleased: {
            var k = event.key;
            if ((k === Qt.Key_Select || k === Qt.Key_Return || k === Qt.Key_Enter) && !event.isAutoRepeat) {
                event.accepted = true;
                if (app.seciliBasili && uzunBasma.running) { uzunBasma.stop(); app.seciliBasili = false; app.imlecTikla(false); }
            }
        }
    }

    // ---------- katmanlar ----------
    Loader { id: oynatici; anchors.fill: parent; z: 90 }
    AdresGirisi { id: adres }
    MenuPaneli { id: menu; onSecildi: app.menuSec(anahtar) }
    ListeSayfasi {
        id: liste
        onSecildi: {
            if (tur === "fav" || tur === "gecmis") { kapat(); app.ac(anahtar); }
            else if (tur === "sekme") { kapat(); app.aktif = parseInt(anahtar, 10); }
            else if (tur === "ayar") app.ayarSec(anahtar);
            else if (tur === "indir") {
                var id = parseInt(anahtar, 10), y = indir.yol(id);
                var l = indir.liste, d = null;
                for (var i = 0; i < l.length; i++) if (l[i].id === id) d = l[i];
                if (!d) return;
                if (d.durum === "bitti") {
                    if (/\.(mp4|3gp|m4v|mov|mp3|m4a|aac|amr|wav)$/i.test(y)) { app.videoAc("file:///" + y, d.ad); }
                    else if (!tb.disaAc("file:///" + y)) app.bildir(qsTr("Açacak uygulama yok: ") + d.ad);
                } else if (d.durum === "iniyor") app.bildir(qsTr("İniyor: ") + U.boyut(d.alinan));
            }
        }
        onUzunBasildi: {
            if (tur === "fav") app.secim2Fav(anahtar);
            else if (tur === "gecmis") app.baglantiMenusu(anahtar, "");
            else if (tur === "sekme") app.sekmeMenusu(parseInt(anahtar, 10));
            else if (tur === "indir") {
                var id = parseInt(anahtar, 10);
                secim.ac(qsTr("İndirme"), [{ ad: qsTr("Durdur"), ikon: "dur", anahtar: "iptal" }, { ad: qsTr("Listeden kaldır"), ikon: "kapat", anahtar: "kaldir" }, { ad: qsTr("Dosyayı sil"), ikon: "kapat", anahtar: "sil", tehlike: true }, { ad: qsTr("Başka uygulamada aç"), ikon: "paylas", anahtar: "dis" }], function (k) {
                    if (k === "iptal") indir.iptal(id); else if (k === "kaldir") indir.kaldir(id, false); else if (k === "sil") indir.kaldir(id, true);
                    else if (k === "dis") tb.disaAc("file:///" + indir.yol(id));
                });
            }
        }
        onSagTiklandi: {
            if (tur === "sekme") { app.sekmeKapat(parseInt(anahtar, 10)); app.sekmeleriAc(); }
        }
        onEkTiklandi: {
            if (tur === "sekme") { kapat(); app.yeniSekme(app.anaSayfa); }
            else if (tur === "gecmis") secim.ac(qsTr("Tüm geçmiş silinsin mi?"), [{ ad: qsTr("Evet, sil"), anahtar: "e", tehlike: true }, { ad: qsTr("Vazgeç"), anahtar: "h" }], function (k) { if (k === "e") { Db.gecmisSil(); liste.doldur([]); } });
            else if (tur === "indir") { indir.temizle(); }
        }
    }
    function secim2Fav(u) {
        secim.ac(u, [{ ad: qsTr("Aç"), anahtar: "ac" }, { ad: qsTr("Yeni sekmede aç"), anahtar: "yeni" }, { ad: qsTr("Kopyala"), anahtar: "kopya" }, { ad: qsTr("Sil"), anahtar: "sil", tehlike: true }], function (k) {
            if (k === "ac") { liste.kapat(); ac(u); } else if (k === "yeni") { liste.kapat(); yeniSekme(u); } else if (k === "kopya") tb.setPano(u);
            else if (k === "sil") { Db.favSil(u); favlariAc(); }
        });
    }
    Secim { id: secim }
    Girdi { id: girdi }
    Rectangle {
        id: bildirim
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 22 }
        width: Math.min(parent.width - 40, bt.paintedWidth + 36); height: bt.paintedHeight + 20; radius: 10
        color: "#e6323639"; z: 95; visible: opacity > 0; opacity: 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        function goster(m) { bt.text = m; opacity = 1; bz.restart(); }
        Text { id: bt; anchors.centerIn: parent; width: app.width - 76; wrapMode: Text.Wrap; color: "#fff"; font.pixelSize: 19; horizontalAlignment: Text.AlignHCenter }
        Timer { id: bz; interval: 3200; onTriggered: bildirim.opacity = 0 }
    }

    Component.onCompleted: {
        console.log("BB qml hazir");
        tb.setKoyu(gece);
        var sb = tb.ayar("sabitler", "");
        if (sb !== "") { var l = sb.split("\n"); for (var i = 0; i < l.length && i < 5; i++) if (l[i] !== "") yeniSekme(l[i], true); }
        yeniSekme(anaSayfa);
        tb.log("arayuz hazir, sabit sekme: " + (sm.count - 1));
        if (!tb.parolaVar) bilgiZaman.start();
    }
    Timer { id: bilgiZaman; interval: 2500; onTriggered: app.bildir(qsTr("İpucu: Menü > Ayarlar > Sunucu parolası ile HTTPS siteler, resim küçültme ve YouTube açılır")) }
}
