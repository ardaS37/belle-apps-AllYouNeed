import QtQuick 1.1
import "Util.js" as Util

// BelleGram: Nokia E6 icin dogrudan (sunucusuz) Telegram istemcisi. Veriler C++ "tg" nesnesinden gelir.
Rectangle {
    id: app
    width: 640
    height: 480
    color: bg

    // ---- Tema (Telegram koyu mavi) ----
    property bool dark: true
    property color brand: dark ? "#5288C1" : "#3390EC"
    property color brandPressed: dark ? "#3E6E9F" : "#2A78C8"
    property color accentText: dark ? "#6AB2F2" : "#3390EC"
    property color bg: dark ? "#17212B" : "#FFFFFF"
    property color surface: dark ? "#232E3C" : "#FFFFFF"
    property color textPrimary: dark ? "#F5F5F5" : "#000000"
    property color textSecondary: dark ? "#708499" : "#707579"
    property color divider: dark ? "#101921" : "#E7E7E7"
    property color pressed: dark ? "#2B3846" : "#F1F1F1"
    property color fieldBg: dark ? "#242F3D" : "#F1F1F1"
    property color chatBg: dark ? "#0E1621" : "#D5E3F0"
    property color bubbleOut: dark ? "#2B5278" : "#EFFDDE"
    property color bubbleIn: dark ? "#182533" : "#FFFFFF"
    property color chip: dark ? "#1E2C3A" : "#FFFFFF"
    property color danger: dark ? "#EC3942" : "#E53935"
    property color placeholder: dark ? "#6D7F8F" : "#9AA0A6"
    property color unread: dark ? "#3E6E9F" : "#3390EC"
    property string iconTone: dark ? "_light" : "_gray"

    // ---- Durum ----
    property string acik: ""          // acik sohbetin kimligi (u123 / c123 / k123)
    property string acikAd: ""
    property string acikTur: ""
    property bool sohbetSonu: false
    property bool sohbetYukleniyor: false
    property bool gecmisSonu: false
    property bool gecmisYukleniyor: false
    property bool ayarAcik: false
    property bool girisEkrani: tg.durum !== "hazir"

    ListModel { id: sohbetModel }
    ListModel { id: mesajModel }

    function sohbetBul(id) {
        for (var i = 0; i < sohbetModel.count; i++) if (sohbetModel.get(i).sid === id) return i;
        return -1;
    }
    function mesajBul(mid) {
        for (var i = mesajModel.count - 1; i >= 0; i--) if (mesajModel.get(i).mid === mid) return i;
        return -1;
    }
    function sohbetNorm(o) {
        return { sid: o.id, ad: o.ad || "", son: o.son || "", zaman: o.zaman || 0, okunmamis: o.okunmamis || 0,
                 benden: !!o.benden, sabit: !!o.sabit, tur: o.tur || "kisi", sessiz: !!o.sessiz, yaziyor: "" };
    }
    // mesaj: onbellekte inmis medya varsa yolunu hemen koy
    function mesajNorm(h) {
        var o = Util.mesajNorm(h);
        if (o.medya !== "" && o.yol === "") o.yol = tg.medyaYolu(o.medya);
        if (o.onizleme !== "") o.oYol = tg.medyaYolu(o.onizleme);
        return o;
    }
    function kisilerAc(kip, mid) { kisilerSayfasi.ac(kip, mid); }
    function sabitlenenSonu() {
        var n = 0;
        while (n < sohbetModel.count && sohbetModel.get(n).sabit) n++;
        return n;
    }

    function sohbetAc(id, ad, tur) {
        if (acik !== "" && acik !== id) sohbetKapat();
        acik = id;
        acikAd = ad;
        acikTur = tur;
        mesajModel.clear();
        gecmisSonu = false;
        gecmisYukleniyor = true;
        tg.mesajlariYukle(id, false);
        sohbetSayfasi.sifirla();
        var i = sohbetBul(id);
        if (i >= 0) sohbetModel.setProperty(i, "okunmamis", 0);
        bildirim.temizle(id);
    }

    // ---- Bildirimler (C++ "bildirim": Pigler cekmecesi, ust kose kutusu, titresim) ----
    function bildir(sid, mesaj) {
        var i = sohbetBul(sid);
        var s = i >= 0 ? sohbetModel.get(i) : null;
        if (s && s.sessiz) return;
        var n = Util.mesajNorm(mesaj);
        var govde = n.metin !== "" ? n.metin : Util.turEtiketi(n);
        if (govde === "") govde = qsTr("Yeni mesaj");
        var kim = mesaj.gonderen || "";
        var baslik = s ? s.ad : (kim !== "" ? kim : "BelleGram");
        if (s && s.tur !== "kisi" && kim !== "" && kim !== s.ad) govde = kim + ": " + govde;
        bildirim.mesaj(sid, baslik, govde, true);
    }
    function bildirimSohbeti(sid) {
        if (menu.visible) menu.kapat();
        if (kisilerSayfasi.visible) kisilerSayfasi.kapat();
        ayarAcik = false;
        var i = sohbetBul(sid);
        if (i >= 0) { var o = sohbetModel.get(i); sohbetAc(o.sid, o.ad, o.tur); }
        else sohbetAc(sid, "", sid.charAt(0) === "u" ? "kisi" : "grup");
    }
    Connections {
        target: bildirim
        onDokunuldu: if (!app.girisEkrani) app.bildirimSohbeti(sohbet)
        onOndeDegisti: if (bildirim.onde && app.acik !== "") { tg.okundu(app.acik); bildirim.temizle(app.acik); }
    }
    function sohbetKapat() {
        sohbetSayfasi.sifirla();
        acik = "";
        acikAd = "";
        mesajModel.clear();
    }
    function geri() {
        if (menu.visible) { menu.kapat(); return true; }
        if (kisilerSayfasi.visible) { kisilerSayfasi.kapat(); return true; }
        if (ayarAcik) { ayarAcik = false; return true; }
        if (acik !== "" && sohbetSayfasi.geri()) return true;
        if (acik !== "") { sohbetKapat(); return true; }
        return false;
    }

    Connections {
        target: tg
        onSohbetListesi: {
            sohbetYukleniyor = false;
            sohbetSonu = sonu;
            if (!daha) sohbetModel.clear();
            for (var i = 0; i < liste.length; i++) {
                var o = sohbetNorm(liste[i]);
                var j = daha ? sohbetBul(o.sid) : -1;
                if (j < 0) sohbetModel.append(o);
            }
            // uygulama cekmecedeki bildirime dokunularak acildiysa o sohbete git
            if (!daha) { var a = bildirim.acilisSohbeti(); if (a !== "") bildirimSohbeti(a); }
        }
        onSohbetGuncellendi: {
            var o = sohbetNorm(sohbet);
            var i = sohbetBul(o.sid);
            var gelen = !o.benden && (o.sid !== acik || !bildirim.onde);
            if (i >= 0) {
                var eski = sohbetModel.get(i);
                o.okunmamis = gelen ? eski.okunmamis + 1 : (o.sid === acik ? 0 : eski.okunmamis);
                o.sessiz = eski.sessiz;
                o.sabit = eski.sabit;
                o.tur = eski.tur;
                if (!o.ad) o.ad = eski.ad;
                sohbetModel.set(i, o);
                if (!o.sabit) { var hedef = sabitlenenSonu(); if (i > hedef) sohbetModel.move(i, hedef, 1); }
            } else {
                o.okunmamis = gelen ? 1 : 0;
                sohbetModel.insert(sabitlenenSonu(), o);
            }
        }
        onMesajListesi: {
            if (sohbet !== acik) return;
            gecmisYukleniyor = false;
            gecmisSonu = sonu;
            if (!eskiler) {
                mesajModel.clear();
                for (var i = liste.length - 1; i >= 0; i--) mesajModel.append(mesajNorm(liste[i]));
                sohbetSayfasi.sonaGit();
                tg.okundu(sohbet);
            } else {
                for (var k = 0; k < liste.length; k++) mesajModel.insert(0, mesajNorm(liste[k]));
                sohbetSayfasi.konumKoru(liste.length);
            }
        }
        onYeniMesaj: {
            if (!mesaj.benden && (sohbet !== acik || !bildirim.onde)) bildir(sohbet, mesaj);
            if (sohbet !== acik) return;
            if (mesajBul("" + mesaj.id) >= 0) return;
            var sondaydi = sohbetSayfasi.sonda();
            mesajModel.append(mesajNorm(mesaj));
            if (sondaydi || mesaj.benden) sohbetSayfasi.sonaGit();
            if (!mesaj.benden && bildirim.onde) tg.okundu(sohbet);
        }
        onMesajGitti: {
            if (sohbet !== acik) return;
            var i = mesajBul(geciciId);
            if (i < 0) return;
            mesajModel.setProperty(i, "mid", "" + mesaj.id);
            mesajModel.setProperty(i, "bekliyor", false);
            mesajModel.setProperty(i, "yuzde", -1);
            if (mesaj.zaman) mesajModel.setProperty(i, "zaman", mesaj.zaman);
            // medya: sunucudaki dosya bilgisi (yerel onizleme yolu korunur)
            if (mesaj.medya) {
                mesajModel.setProperty(i, "medya", mesaj.medya);
                if (mesaj.buyukMedya) mesajModel.setProperty(i, "buyukMedya", mesaj.buyukMedya);
                if (mesaj.sure) mesajModel.setProperty(i, "sure", mesaj.sure);
            }
        }
        onYuklemeIlerleme: {
            if (sohbet !== acik) return;
            var i = mesajBul(geciciId);
            if (i >= 0) mesajModel.setProperty(i, "yuzde", yuzde);
        }
        onMesajDuzenlendi: {
            if (sohbet !== acik) return;
            var i = mesajBul("" + mesaj.id);
            if (i < 0) return;
            if (mesaj.metin !== undefined) mesajModel.setProperty(i, "metin", mesaj.metin);
            mesajModel.setProperty(i, "duzenlendi", !!mesaj.duzenlendi);
            if (mesaj.tepki !== undefined) { mesajModel.setProperty(i, "tepki", mesaj.tepki || ""); mesajModel.setProperty(i, "benimTepki", mesaj.benimTepki || ""); }
        }
        onMesajlarSilindi: {
            if (acik === "" || (sohbet !== "" && sohbet !== acik) || (sohbet === "" && acik.charAt(0) === "k")) return;
            for (var k = 0; k < kimlikler.length; k++) {
                var i = mesajBul("" + kimlikler[k]);
                if (i >= 0) mesajModel.remove(i);
            }
        }
        onOkunduBilgi: {
            if (sohbet !== acik) return;
            for (var i = mesajModel.count - 1; i >= 0; i--) {
                var m = mesajModel.get(i);
                if (!m.benden || Util.gecici(m.mid)) continue;
                if (parseInt(m.mid) > enBuyuk) continue;
                if (m.okundu) break;
                mesajModel.setProperty(i, "okundu", true);
            }
        }
        onTepkiDegisti: {
            if (sohbet !== acik) return;
            var i = mesajBul(id);
            if (i >= 0) { mesajModel.setProperty(i, "tepki", tepki); mesajModel.setProperty(i, "benimTepki", benim); }
        }
        onYaziyorBilgi: {
            var i = sohbetBul(sohbet);
            if (i >= 0) { sohbetModel.setProperty(i, "yaziyor", metin); if (metin !== "") yaziyorSil.restart(); }
        }
        onSohbetOzellik: {
            var i = sohbetBul(sohbet);
            if (i < 0) return;
            sohbetModel.setProperty(i, ad, deger);
            if (ad === "sabit") {
                if (deger) sohbetModel.move(i, 0, 1);
                else { var h = sabitlenenSonu(); if (i < h) sohbetModel.move(i, h, 1); }
            }
        }
        onSohbetSilindi: {
            var i = sohbetBul(sohbet);
            if (i >= 0) sohbetModel.remove(i);
            if (sohbet === acik) sohbetKapat();
        }
        onMesajGitmedi: {
            if (sohbet === acik) {
                var i = mesajBul(geciciId);
                if (i >= 0) { mesajModel.setProperty(i, "bekliyor", false); mesajModel.setProperty(i, "hata", true); }
            }
            toast.show(neden);
        }
        onHataOldu: toast.show(mesaj)
        onBilgi: toast.show(mesaj)
        onDurumDegisti: if (tg.durum === "hazir") sohbetYukleniyor = true
    }

    LoginPage {
        id: girisSayfasi
        anchors.fill: parent
        visible: app.girisEkrani
    }

    ChatListPage {
        id: listeSayfasi
        anchors.fill: parent
        visible: !app.girisEkrani && app.acik === ""
    }

    ChatPage {
        id: sohbetSayfasi
        anchors.fill: parent
        visible: !app.girisEkrani && app.acik !== ""
    }

    AyarPanel {
        anchors.fill: parent
        visible: app.ayarAcik
    }

    KisilerPage {
        id: kisilerSayfasi
        anchors.fill: parent
    }

    Menu {
        id: menu
        anchors.fill: parent
        onSecildi: {
            if (baglam.tur === "mesaj") sohbetSayfasi.menuSecimi(kod, baglam.i, baglam.mid);
            else if (baglam.tur === "sohbet") {
                var i = sohbetBul(baglam.sid);
                if (i < 0) return;
                var o = sohbetModel.get(i);
                if (kod === "sessiz") tg.sessizAyarla(o.sid, !o.sessiz);
                else if (kod === "sabit") tg.sabitle(o.sid, !o.sabit);
                else if (kod === "okundu") { tg.okundu(o.sid); sohbetModel.setProperty(i, "okunmamis", 0); bildirim.temizle(o.sid); }
                else if (kod === "sil") menu.ac(qsTr("Emin misiniz? ") + o.ad, [["evetSil", qsTr("Evet, sil / ayrıl"), true], ["vazgec", qsTr("Vazgeç")]], { tur: "sohbet", sid: o.sid });
                else if (kod === "evetSil") tg.sohbetSil(o.sid);
            }
        }
    }

    // yaziyor bilgisi sohbet listesinde birkac saniye kalir
    Timer {
        id: yaziyorSil
        interval: 6000
        onTriggered: {
            for (var i = 0; i < sohbetModel.count; i++) if (sohbetModel.get(i).yaziyor !== "") sohbetModel.setProperty(i, "yaziyor", "");
        }
    }

    Toast { id: toast; z: 40 }

    focus: true
    Keys.onPressed: {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back) {
            if (geri()) event.accepted = true;
        }
    }

    Component.onCompleted: tg.basla()
}
