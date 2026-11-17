import QtQuick 1.1
import "Util.js" as U
import "Servis.js" as S

// Ayarlar: servisleri ac/kapat (dokun), anahtar / model / bilgi (… ya da basili tut), genel ayarlar.
Rectangle {
    id: root
    color: app.bg

    function takeFocus() { liste.forceActiveFocus(); }
    function kur() {
        var keep = liste.currentIndex;
        am.clear();
        for (var i = 0; i < S.servisler.length; i++) {
            var s = S.servisler[i], ak = app.aktif(s.kod), an = app.anahtar(s.kod);
            am.append({ k: "s:" + s.kod, bolum: s.tur === "ceviri" ? qsTr("Çeviri servisleri (dokun: aç/kapat)") : qsTr("Sözlük servisleri"),
                        etiket: s.ad, deger: app.etiket(s) + (s.anahtarli ? (an !== "" ? qsTr(" · anahtar var") : qsTr(" · anahtar yok")) : "") + (s.llm ? " · " + app.model(s.kod) : ""),
                        acik: ak, servis: true });
        }
        var g = qsTr("Genel");
        am.append({ k: "ice", bolum: g, etiket: qsTr("Anahtarları dosyadan içe aktar"), deger: "E:/BelleCeviri_anahtarlar.txt", acik: false, servis: false });
        am.append({ k: "dil", bolum: g, etiket: "Dil / Language", deger: (app.ing ? "English" : "Türkçe") + (dil.yenidenBaslat ? " \u21BB" : ""), acik: false, servis: false });
        am.append({ k: "yazi", bolum: g, etiket: qsTr("Yazı boyutu"), deger: app.fontSize + qsTr(" piksel"), acik: false, servis: false });
        am.append({ k: "pano", bolum: g, etiket: qsTr("Açılışta panodaki yazıyı al"), deger: app.panodanAl ? qsTr("Açık") : qsTr("Kapalı"), acik: false, servis: false });
        am.append({ k: "gecmis", bolum: g, etiket: qsTr("Geçmiş tut"), deger: app.gecmisTut ? qsTr("Açık") : qsTr("Kapalı"), acik: false, servis: false });
        am.append({ k: "gunluk", bolum: g, etiket: qsTr("Günlüğü göster"), deger: "", acik: false, servis: false });
        am.append({ k: "hakkinda", bolum: g, etiket: qsTr("Hakkında"), deger: "BelleCeviri " + app.version, acik: false, servis: false });
        am.append({ k: "cikis", bolum: g, etiket: qsTr("Çıkış"), deger: "Ctrl+Q", acik: false, servis: false });
        liste.currentIndex = Math.max(0, Math.min(keep, am.count - 1));
    }
    function anahtarGir(kod, sonra) {
        var s = S.servis(kod);
        input.open({ title: s.ad + qsTr(" API anahtarı"), label1: s.bilgi, text1: app.anahtar(kod), ok: qsTr("Kaydet"), password: true }, function (v) {
            v = v.replace(/^\s+|\s+$/g, "");
            if (v === "") return;
            app.ayarYaz("anahtar_" + kod, v);
            app.aktifYap(kod, true);
            app.showToast(s.ad + qsTr(" açıldı"));
            root.kur();
            if (sonra) sonra();
        });
    }
    function degistir(kod) {
        var s = S.servis(kod);
        if (app.aktif(kod)) { app.aktifYap(kod, false); kur(); return; }
        if (s.anahtarli && app.anahtar(kod) === "") { anahtarGir(kod); return; }
        app.aktifYap(kod, true);
        kur();
    }
    function servisMenu(kod) {
        var s = S.servis(kod), items = [];
        items.push({ label: app.aktif(kod) ? qsTr("Kapat") : qsTr("Aç"), icon: app.aktif(kod) ? "close" : "check", key: "ac" });
        if (s.anahtarli) {
            items.push({ label: app.anahtar(kod) !== "" ? qsTr("Anahtarı değiştir") : qsTr("Anahtar gir"), icon: "key", key: "anahtar" });
            if (app.anahtar(kod) !== "") items.push({ label: qsTr("Anahtarı sil"), icon: "trash", key: "sil", danger: true });
        }
        if (s.llm) items.push({ label: qsTr("Model: ") + app.model(kod), icon: "edit", key: "model" });
        items.push({ label: s.bilgi, icon: "info", key: "x" });
        sheet.open(s.ad + " \u00B7 " + app.etiket(s), items, function (k) {
            if (k === "ac") root.degistir(kod);
            else if (k === "anahtar") root.anahtarGir(kod);
            else if (k === "sil") { app.ayarSil("anahtar_" + kod); app.aktifYap(kod, false); root.kur(); app.showToast(qsTr("Anahtar silindi")); }
            else if (k === "model") input.open({ title: s.ad + qsTr(" modeli"), label1: qsTr("Varsayılan: ") + s.model, text1: app.model(kod), ok: qsTr("Kaydet") }, function (v) {
                v = v.replace(/^\s+|\s+$/g, "");
                if (v === "" || v === s.model) app.ayarSil("model_" + kod); else app.ayarYaz("model_" + kod, v);
                app.surum++;
                root.kur();
            });
        });
    }
    function sec(i) {
        if (i < 0 || i >= am.count) return;
        var k = am.get(i).k;
        if (k.indexOf("s:") === 0) { degistir(k.substring(2)); return; }
        if (k === "ice") { app.anahtarIceAktar(false); kur(); }
        else if (k === "dil") { var dk = app.ing ? "tr" : "en"; dil.sec(dk); app.showToast("Dil değişti; uygulamayı yeniden açın. / Language changed; please restart the app."); kur(); }
        else if (k === "yazi") {
            var l = [14, 16, 18, 19, 21, 24, 28, 32], it = [];
            for (var j = 0; j < l.length; j++) it.push({ label: (l[j] === app.fontSize ? "\u25CF " : "") + l[j] + qsTr(" piksel"), icon: "font", key: "f" + l[j] });
            sheet.open(qsTr("Yazı boyutu"), it, function (v) { var n = parseInt(("" + v).replace(/[^0-9]/g, ""), 10); if (n > 0) { app.fontSize = n; app.ayarYaz("fontSize", n); root.kur(); } });
        }
        else if (k === "pano") { app.panodanAl = !app.panodanAl; app.ayarYaz("pano", app.panodanAl ? "1" : "0"); kur(); }
        else if (k === "gecmis") { app.gecmisTut = !app.gecmisTut; app.ayarYaz("gecmis", app.gecmisTut ? "1" : "0"); kur(); }
        else if (k === "gunluk") yazilar.goster(qsTr("Günlük"), cv.gunluk());
        else if (k === "hakkinda") yazilar.goster("BelleCeviri " + app.version,
            qsTr("Nokia E6 için çeviri ve sözlük.\n\nServisler: Google Çeviri (resmî olmayan yol, anahtarsız), MyMemory (anahtarsız), DeepL (anahtarlı), Gemini, Groq, Mistral, OpenAI, Claude (anahtarlı, LLM); sözlük: TDK ve Wiktionary (anahtarsız). Hangisini açarsanız o çalışır; her biri ayrı kartta.\n\nAnahtarlar uygulamaya gömülü değildir; burada girilir ve yalnız telefonda saklanır. Toplu giriş: E:/BelleCeviri_anahtarlar.txt dosyasına satır başına kod=anahtar yazın (ör. gemini=..., deepl=..., groq=...); uygulama okuyup dosyayı siler.\n\nKısayollar: yazı kutusunda Enter çevirir, Sağ ok kartlara geçer, kartta Enter kopyalar, F favori, Ctrl+Q çıkış."));
        else if (k === "cikis") Qt.quit();
    }

    ListModel { id: am }
    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: qsTr("Ayarlar")
        subtitle: { var n = app.surum; return app.aktifler("ceviri").length + qsTr(" çeviri, ") + app.aktifler("sozluk").length + qsTr(" sözlük servisi açık"); }
    }
    ListView {
        id: liste
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        clip: true
        model: am
        highlightMoveDuration: 80
        section.property: "bolum"
        section.delegate: Item {
            width: liste.width; height: 32
            Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: section; color: app.brand; font.pixelSize: 14; font.bold: true }
        }
        delegate: Rectangle {
            id: sat
            width: liste.width
            height: Math.round(36 * app.yazi + 20)
            property bool cur: ListView.isCurrentItem && liste.activeFocus
            color: ma.pressed ? app.pressed : (cur ? app.highlight : "transparent")
            Rectangle { visible: sat.cur; anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 4; color: app.brand }
            // ac/kapa gostergesi
            Rectangle {
                id: anahtar
                visible: servis
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                width: 44; height: 24; radius: 12
                color: acik ? app.brand : app.fieldBg
                Rectangle { width: 18; height: 18; radius: 9; y: 3; x: acik ? 23 : 3; color: acik ? "#101418" : app.textSecondary }
            }
            Column {
                anchors { left: servis ? anahtar.right : parent.left; leftMargin: servis ? 12 : 18; right: menuBtn.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                Text { width: parent.width; text: etiket; color: app.textPrimary; font.pixelSize: Math.round(18 * app.yazi); elide: Text.ElideRight }
                Text { width: parent.width; visible: deger !== ""; text: deger; color: app.textSecondary; font.pixelSize: Math.round(13 * app.yazi); elide: Text.ElideRight }
            }
            IconButton { id: menuBtn; visible: servis; anchors { right: parent.right; rightMargin: 2; verticalCenter: parent.verticalCenter } icon: "more"; tone: "g"; iconSize: 24; onClicked: root.servisMenu(k.substring(2)) }
            Rectangle { anchors { left: parent.left; leftMargin: 14; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
            MouseArea { id: ma; anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: menuBtn.visible ? menuBtn.left : parent.right }
                onClicked: { liste.currentIndex = index; root.sec(index); }
                onPressAndHold: { liste.currentIndex = index; if (servis) root.servisMenu(k.substring(2)); } }
        }
        Keys.onPressed: {
            if (app.ortakTus(event)) { event.accepted = true; return; }
            var kk = event.key, o = currentIndex >= 0 && currentIndex < am.count ? am.get(currentIndex) : null;
            if (kk === Qt.Key_Return || kk === Qt.Key_Enter || kk === Qt.Key_Select) root.sec(currentIndex);
            else if (kk === Qt.Key_Space || kk === Qt.Key_Menu || kk === Qt.Key_Context1) { if (o && o.servis) root.servisMenu(o.k.substring(2)); }
            else if (kk === Qt.Key_Left) app.stepTab(-1);
            else if (kk === Qt.Key_Right) app.stepTab(1);
            else return;
            event.accepted = true;
        }
    }
    Rectangle {
        id: yazilar
        anchors.fill: parent
        color: app.bg
        visible: false
        z: 5
        property string baslik: ""
        function goster(b, m) { baslik = b; yt.text = m; visible = true; yf.contentY = 0; yf.forceActiveFocus(); }
        function gizle() { visible = false; liste.forceActiveFocus(); }
        Header { id: yh; anchors { left: parent.left; right: parent.right; top: parent.top } title: yazilar.baslik; showBack: true; onBack: yazilar.gizle() }
        Flickable {
            id: yf
            anchors { left: parent.left; right: parent.right; top: yh.bottom; bottom: parent.bottom; margins: 12 }
            clip: true
            contentHeight: yt.paintedHeight + 20
            Text { id: yt; width: yf.width; wrapMode: Text.Wrap; color: app.textPrimary; font.pixelSize: Math.round(15 * app.yazi); textFormat: Text.PlainText }
            Keys.onPressed: {
                var k = event.key;
                if (k === Qt.Key_Down) contentY = Math.min(Math.max(0, contentHeight - height), contentY + 60);
                else if (k === Qt.Key_Up) contentY = Math.max(0, contentY - 60);
                else if (k === Qt.Key_Escape || k === Qt.Key_Backspace || k === Qt.Key_Left || k === Qt.Key_Return || k === Qt.Key_Select) yazilar.gizle();
                else return;
                event.accepted = true;
            }
        }
    }
}
