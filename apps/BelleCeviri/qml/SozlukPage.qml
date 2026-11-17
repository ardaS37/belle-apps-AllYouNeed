import QtQuick 1.1
import "Util.js" as U
import "Servis.js" as S
import "Durum.js" as D

// Sozluk: kelime/deyim ara. TDK (Turkce), Wiktionary (cok dilli) ve istenirse ilk acik LLM ile aciklama.
Rectangle {
    id: root
    color: app.bg
    property string sonKelime: ""
    property bool llmAcik: true

    function takeFocus() { kelime.focusInput(); }
    function ozet() {
        var s = [];
        for (var i = 0; i < km.count; i++) { var k = km.get(i); s.push(k.ad + "=" + (k.durum === "tamam" ? k.metin.length + " krk '" + k.metin.substring(0, 50).replace(/\n/g, " / ") + "'" : k.durum + " " + k.hata)); }
        return s.join(" | ");
    }
    function ara(w) {
        if (w !== undefined) kelime.text = w;
        var m = kelime.text.replace(/^\s+|\s+$/g, "");
        if (m === "") return;
        if (D.sozlukOnEk !== "") cv.iptal(D.sozlukOnEk + ":");
        D.sozlukOnEk = "s" + new Date().getTime();
        sonKelime = m;
        km.clear();
        var l = app.aktifler("sozluk");
        for (var i = 0; i < l.length; i++) {
            var r = app.gonder(D.sozlukOnEk, l[i].kod, m, "auto", "tr");
            km.append({ kod: l[i].kod, ad: l[i].ad, etiket: app.etiket(l[i]), durum: r.hata ? "hata" : "bekliyor", metin: "", ek: "", hata: r.hata || "", alg: "" });
        }
        var llm = app.ilkLlm();
        if (llm && llmAcik) {
            var r2 = app.gonder(D.sozlukOnEk, llm.kod, m, "auto", cevirSayfasi.tl, app.ing);
            km.append({ kod: llm.kod, ad: llm.ad + qsTr(" · açıklama"), etiket: app.etiket(llm), durum: r2.hata ? "hata" : "bekliyor", metin: "", ek: "", hata: r2.hata || "", alg: "" });
        }
        if (!km.count) app.showToast(qsTr("Açık sözlük servisi yok: Ayarlar > Servisler"));
        cv.kayit("sozluk '" + m + "' " + km.count + " servis");
    }
    Connections { target: cv; onYanit: root.isle(id, kod, govde, hata) }
    function isle(id, durum, govde, hata) {
        if (D.sozlukOnEk === "" || id.indexOf(D.sozlukOnEk + ":") !== 0) return;
        var sk = id.split(":")[1], r = S.coz(sk, durum, govde);
        if (durum === 0 && hata) r = { hata: qsTr("Bağlantı kurulamadı: ") + hata };
        for (var i = 0; i < km.count; i++) {
            if (km.get(i).kod !== sk) continue;
            if (r.hata) { km.setProperty(i, "durum", "hata"); km.setProperty(i, "hata", r.hata); }
            else { km.setProperty(i, "metin", r.metin || ""); km.setProperty(i, "durum", "tamam"); }
            break;
        }
    }

    Item {
        id: sol
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: Math.round(parent.width * 0.40)
        Column {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
            spacing: 10
            Text { text: qsTr("Sözlük"); color: app.brand; font.pixelSize: Math.round(20 * Math.min(app.yazi, 1.3)); font.bold: true }
            TextField {
                id: kelime
                width: parent.width
                placeholder: qsTr("Kelime ya da deyim")
                onAccepted: root.ara()
                onTabbed: if (km.count) kartlar.forceActiveFocus()
            }
            Rectangle {
                width: parent.width; height: 40; radius: 20
                color: ama.pressed ? app.brandPressed : app.brand
                Text { anchors.centerIn: parent; text: qsTr("Ara"); color: "#101418"; font.pixelSize: 18; font.bold: true }
                MouseArea { id: ama; anchors.fill: parent; onClicked: root.ara() }
            }
            Hap {
                visible: { var n = app.surum; return app.ilkLlm() !== null; }
                yazi: (root.llmAcik ? "☑ " : "☐ ") + qsTr("Yapay zekâ açıklaması")
                secili: root.llmAcik
                onTiklandi: root.llmAcik = !root.llmAcik
            }
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                color: app.textSecondary
                font.pixelSize: Math.round(14 * app.yazi)
                text: { var n = app.surum, l = app.aktifler("sozluk"), a = []; for (var i = 0; i < l.length; i++) a.push(l[i].ad);
                        var m = app.ilkLlm();
                        return qsTr("Açık: ") + (a.length ? a.join(", ") : qsTr("yok")) + (m ? ", " + m.ad + qsTr(" (açıklama)") : "")
                             + qsTr("\n\nTDK: Türkçe kelimeler. Wiktionary: tüm diller, anlamlar İngilizce. Yapay zekâ: herhangi bir dilde açıklama ve örnek (Ayarlar'dan bir LLM açın)."); }
            }
        }
    }
    Rectangle { anchors { left: sol.right; top: parent.top; bottom: parent.bottom } width: 1; color: app.divider }
    ListModel { id: km }
    ListView {
        id: kartlar
        anchors { left: sol.right; leftMargin: 8; right: parent.right; rightMargin: 8; top: parent.top; topMargin: 8; bottom: parent.bottom; bottomMargin: 8 }
        clip: true
        spacing: 8
        model: km
        delegate: Kart {
            width: kartlar.width
            ad: model.ad; etiket: model.etiket; durum: model.durum; metin: model.metin; ek: model.ek; hata: model.hata; alg: ""
            yildizVar: false
            secili: ListView.isCurrentItem && kartlar.activeFocus
            onKopyala: app.kopyala(model.metin)
        }
        Keys.onPressed: {
            if (app.ortakTus(event)) { event.accepted = true; return; }
            var k = event.key, o = currentIndex >= 0 && currentIndex < km.count ? km.get(currentIndex) : null;
            if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) { if (o && o.durum === "tamam") app.kopyala(o.metin); }
            else if (k === Qt.Key_Left || k === Qt.Key_Backspace || k === Qt.Key_Escape) kelime.focusInput();
            else return;
            event.accepted = true;
        }
    }
    Text {
        anchors.centerIn: kartlar
        width: kartlar.width - 30
        visible: km.count === 0
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        color: app.textSecondary
        font.pixelSize: Math.round(16 * app.yazi)
        text: qsTr("Bir kelime yazıp Ara'ya basın.")
    }
}
