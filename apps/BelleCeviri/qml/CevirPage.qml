import QtQuick 1.1
import "Util.js" as U
import "Servis.js" as S
import "Durum.js" as D

// Ceviri: solda diller + yazi kutusu, sagda acik servislerin sonuc kartlari.
// Klavye: yazi kutusunda Enter cevirir (Shift+Enter yeni satir), Sag ok kartlara gecer;
// kartlarda Enter kopyalar, F favori, Sol ok yazi kutusuna doner.
Rectangle {
    id: root
    color: app.bg
    property string sl: "auto"
    property string tl: "en"
    property string sonMetin: ""

    function takeFocus() { girdi.forceActiveFocus(); }
    function hazirla() {
        sl = app.ayar("sl", "auto");
        tl = app.ayar("tl", app.ing ? "tr" : "en");
        if (app.panodanAl) { var p = cv.pano(); if (p && p.length < 5000) girdi.text = p; }
    }
    function metinVer(t) { girdi.text = t; }
    function dilleriVer(a, b) { sl = a; tl = b; }
    function ozet() {
        var s = [];
        for (var i = 0; i < kartModel.count; i++) { var k = kartModel.get(i); s.push(k.ad + "=" + (k.durum === "tamam" ? "'" + k.metin.substring(0, 60) + "'" : k.durum + " " + k.hata)); }
        return s.join(" | ");
    }
    function dilSec(kaynak) {
        dilSecici.ac(kaynak, kaynak ? sl : tl, function (k) {
            if (kaynak) { root.sl = k; app.ayarYaz("sl", k); } else { root.tl = k; app.ayarYaz("tl", k); }
            app.sonDillerEkle(k);
        });
    }
    function takas() {
        var a = sl === "auto" ? (kartModel.count && kartModel.get(0).alg ? kartModel.get(0).alg : "") : sl;
        if (a === "") { app.showToast(qsTr("Kaynak dil algılanmadı; önce bir kez çevirin")); return; }
        var ilk = "";
        for (var i = 0; i < kartModel.count; i++) if (kartModel.get(i).durum === "tamam") { ilk = kartModel.get(i).metin; break; }
        sl = tl; tl = a;
        app.ayarYaz("sl", sl); app.ayarYaz("tl", tl);
        if (ilk !== "") { girdi.text = ilk; cevir(); }
    }
    function cevir() {
        var m = girdi.text.replace(/^\s+|\s+$/g, "");
        if (m === "") { app.showToast(qsTr("Çevrilecek yazı yok")); return; }
        if (D.cevirOnEk !== "") cv.iptal(D.cevirOnEk + ":");
        D.cevirOnEk = "c" + new Date().getTime();
        D.gecmisYazildi = false;
        sonMetin = m;
        kartModel.clear();
        var l = app.aktifler("ceviri");
        if (!l.length) { app.showToast(qsTr("Açık çeviri servisi yok: Ayarlar > Servisler")); return; }
        for (var i = 0; i < l.length; i++) {
            var r = app.gonder(D.cevirOnEk, l[i].kod, m, sl, tl);
            kartModel.append({ kod: l[i].kod, ad: l[i].ad, etiket: app.etiket(l[i]), durum: r.hata ? "hata" : "bekliyor", metin: "", ek: "", hata: r.hata || "", alg: "" });
        }
        kartlar.currentIndex = 0;
        cv.kayit("cevir " + sl + ">" + tl + " " + m.length + " krk, " + l.length + " servis");
    }

    // yanit isleme islevde (sinyal parametresi 'kod' HTTP durumu)
    Connections {
        target: cv
        onYanit: root.isle(id, kod, govde, hata)
    }
    function isle(id, durum, govde, hata) {
        if (D.cevirOnEk === "" || id.indexOf(D.cevirOnEk + ":") !== 0) return;
        var sk = id.split(":")[1];
        var r = S.coz(sk, durum, govde);
        if (durum === 0 && hata) r = { hata: qsTr("Bağlantı kurulamadı: ") + hata };
        for (var i = 0; i < kartModel.count; i++) {
            if (kartModel.get(i).kod !== sk) continue;
            if (r.hata) { kartModel.setProperty(i, "durum", "hata"); kartModel.setProperty(i, "hata", r.hata); }
            else {
                kartModel.setProperty(i, "metin", r.metin || "");
                kartModel.setProperty(i, "ek", r.ek || "");
                kartModel.setProperty(i, "alg", sl === "auto" ? (r.alg || "") : "");
                kartModel.setProperty(i, "durum", "tamam");
                if (!D.gecmisYazildi && r.metin) { D.gecmisYazildi = true; app.gecmiseYaz(sonMetin, r.metin, sl === "auto" && r.alg ? r.alg : sl, tl, kartModel.get(i).ad, false); }
            }
            cv.kayit("yanit " + sk + " " + durum + (r.hata ? " hata: " + r.hata : ""));
            break;
        }
    }

    // ---- sol: diller + yazi ----
    Item {
        id: sol
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: Math.round(parent.width * 0.46)
        Row {
            id: dilSatiri
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
            height: 40
            spacing: 4
            DilDugme { width: (dilSatiri.width - 48) / 2; yazi: app.dilAdi(root.sl); onTiklandi: root.dilSec(true) }
            IconButton { width: 40; height: 40; icon: "swap"; tone: "a"; iconSize: 24; onClicked: root.takas() }
            DilDugme { width: (dilSatiri.width - 48) / 2; yazi: app.dilAdi(root.tl); onTiklandi: root.dilSec(false) }
        }
        Rectangle {
            id: kutu
            anchors { left: parent.left; right: parent.right; top: dilSatiri.bottom; bottom: dugmeler.top; margins: 8 }
            radius: 10
            color: app.fieldBg
            border.width: girdi.activeFocus ? 2 : 0
            border.color: app.brand
            Flickable {
                id: gf
                anchors { fill: parent; margins: 10 }
                clip: true
                contentHeight: girdi.paintedHeight + 10
                function goster(r) { if (contentY >= r.y) contentY = r.y; else if (contentY + height <= r.y + r.height) contentY = r.y + r.height - height; }
                TextEdit {
                    id: girdi
                    width: gf.width
                    wrapMode: TextEdit.Wrap
                    color: app.textPrimary
                    font.pixelSize: Math.round(19 * app.yazi)
                    selectByMouse: true
                    selectionColor: app.brand
                    selectedTextColor: "#101418"
                    onCursorRectangleChanged: gf.goster(cursorRectangle)
                    Keys.onPressed: {
                        if (app.ortakTus(event)) { event.accepted = true; return; }
                        if (U.ctrl(event) && U.tus(event) === "v") { var p = "" + cv.pano(); girdi.text = girdi.text.substring(0, girdi.selectionStart) + p + girdi.text.substring(girdi.selectionEnd); event.accepted = true; return; }
                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) && !(event.modifiers & Qt.ShiftModifier)) { root.cevir(); event.accepted = true; }
                        else if (event.key === Qt.Key_Right && cursorPosition === text.length && kartModel.count) { kartlar.forceActiveFocus(); event.accepted = true; }
                    }
                }
            }
            Text {
                anchors { left: parent.left; top: parent.top; margins: 12 }
                visible: girdi.text.length === 0
                text: qsTr("Çevrilecek yazı…\nEnter: çevir")
                color: app.textSecondary
                font.pixelSize: Math.round(17 * app.yazi)
            }
            MouseArea { anchors.fill: parent; enabled: !girdi.activeFocus; onClicked: { girdi.forceActiveFocus(); girdi.openSoftwareInputPanel(); } }
        }
        Row {
            id: dugmeler
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 }
            height: 40
            spacing: 6
            Hap { anchors.verticalCenter: parent.verticalCenter; yazi: qsTr("Yapıştır"); onTiklandi: { girdi.text = cv.pano(); girdi.cursorPosition = girdi.text.length; } }
            Hap { anchors.verticalCenter: parent.verticalCenter; yazi: qsTr("Temizle"); onTiklandi: { girdi.text = ""; kartModel.clear(); girdi.forceActiveFocus(); } }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(90, dugmeler.width - x); height: 38; radius: 19
                color: cma.pressed ? app.brandPressed : app.brand
                Text { anchors.centerIn: parent; text: qsTr("Çevir"); color: "#101418"; font.pixelSize: 18; font.bold: true }
                MouseArea { id: cma; anchors.fill: parent; onClicked: root.cevir() }
            }
        }
    }
    Rectangle { anchors { left: sol.right; top: parent.top; bottom: parent.bottom } width: 1; color: app.divider }

    // ---- sag: sonuc kartlari ----
    ListModel { id: kartModel }
    ListView {
        id: kartlar
        anchors { left: sol.right; leftMargin: 8; right: parent.right; rightMargin: 8; top: parent.top; topMargin: 8; bottom: parent.bottom; bottomMargin: 8 }
        clip: true
        spacing: 8
        model: kartModel
        delegate: Kart {
            width: kartlar.width
            ad: model.ad
            etiket: model.etiket
            durum: model.durum
            metin: model.metin
            ek: model.ek
            hata: model.hata
            alg: model.alg
            secili: ListView.isCurrentItem && kartlar.activeFocus
            onKopyala: app.kopyala(model.metin)
            onYildiz: { app.gecmiseYaz(root.sonMetin, model.metin, root.sl, root.tl, model.ad, true); app.showToast(qsTr("Favorilere eklendi")); }
        }
        Keys.onPressed: {
            if (app.ortakTus(event)) { event.accepted = true; return; }
            var k = event.key, t = U.tus(event), o = currentIndex >= 0 && currentIndex < kartModel.count ? kartModel.get(currentIndex) : null;
            if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) { if (o && o.durum === "tamam") app.kopyala(o.metin); }
            else if (k === Qt.Key_Left || k === Qt.Key_Backspace || k === Qt.Key_Escape) girdi.forceActiveFocus();
            else if (t === "f") { if (o && o.durum === "tamam") { app.gecmiseYaz(root.sonMetin, o.metin, root.sl, root.tl, o.ad, true); app.showToast(qsTr("Favorilere eklendi")); } }
            else return;
            event.accepted = true;
        }
    }
    Column {
        anchors.centerIn: kartlar
        width: kartlar.width - 30
        visible: kartModel.count === 0
        spacing: 8
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: app.textSecondary
            font.pixelSize: Math.round(16 * app.yazi)
            text: {
                var n = app.surum, l = app.aktifler("ceviri"), a = [];
                for (var i = 0; i < l.length; i++) a.push(l[i].ad);
                return a.length ? qsTr("Açık servisler: ") + a.join(", ") + qsTr("\n\nSonuçlar burada, her servis ayrı kartta. Kopyala düğmesiyle ya da kartı seçip Enter ile kopyalanır.")
                                : qsTr("Açık çeviri servisi yok.\nAyarlar > Servisler'den açın.");
            }
        }
    }
}
