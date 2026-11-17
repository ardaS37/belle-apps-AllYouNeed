import QtQuick 1.1
import "Util.js" as U

// Ayarlar. Enter / Bosluk: degistir. Sol/Sag: sekme.
Rectangle {
    id: root
    color: app.bg

    function takeFocus() { liste.forceActiveFocus(); kur(); }
    function acikKapali(b) { return b ? qsTr("Açık") : qsTr("Kapalı"); }
    function dilAdi() { return (dil.secim === "auto" ? dil.kod : dil.secim) === "en" ? "English" : "Türkçe"; }
    function ekle(k, etiket, deger, simge) { smodel.append({ k: k, etiket: etiket, deger: "" + deger, simge: simge }); }
    function kur() {
        var keep = liste.currentIndex;
        smodel.clear();
        ekle("dil", "Dil / Language", dilAdi() + (dil.yenidenBaslat ? " ↻" : ""), "font");
        ekle("yazi", qsTr("Yazı boyutu"), app.fontSize + qsTr(" piksel"), "font");
        ekle("ulke", qsTr("Ülkem (popüler radyo ve podcast)"), app.evUlkeAd, "globe");
        ekle("aktarma", qsTr("Radyo: telefon içi aktarma"), acikKapali(app.aktarmaAcik), "muzik");
        ekle("uyku", qsTr("Uyku zamanlayıcısı süresi"), app.uykuVarsayilan + qsTr(" dk"), "clock");
        ekle("tam", qsTr("Haberde tam metni otomatik getir"), acikKapali(app.tamMetinOto), "doc");
        ekle("kaynak", qsTr("Haber kaynakları"), "", "doc");
        ekle("klasor", qsTr("Podcast indirme klasörü"), yayin.indirmeKlasoru(), "folder");
        ekle("gunluk", qsTr("Günlüğü göster"), "", "lines");
        ekle("hakkinda", qsTr("Hakkında"), "BelleCast " + app.version, "info");
        ekle("cikis", qsTr("Çıkış"), "Ctrl+Q", "quit");
        liste.currentIndex = Math.max(0, Math.min(keep, smodel.count - 1));
    }
    function sec(i) {
        if (i < 0 || i >= smodel.count) return;
        var k = smodel.get(i).k;
        if (k === "dil") {
            var dk = dil.secim === "auto" ? dil.kod : dil.secim;
            dil.sec(dk === "en" ? "tr" : "en");
            app.showToast(dil.yenidenBaslat ? "Dil değişti; uygulamayı yeniden açın. / Language changed; please restart the app." : "Dil / Language: " + dilAdi());
            kur();
        } else if (k === "yazi") {
            var l = [14, 16, 18, 19, 21, 24, 28, 32], it = [];
            for (var j = 0; j < l.length; j++) it.push({ label: (l[j] === app.fontSize ? "● " : "") + l[j] + qsTr(" piksel") + (l[j] === 19 ? qsTr(" (varsayılan)") : ""), icon: "font", key: "f" + l[j] });
            sheet.open(qsTr("Yazı boyutu"), it, function (v) { var n = parseInt(("" + v).replace(/[^0-9]/g, ""), 10); if (n > 0) { app.fontSize = n; app.ayarYaz("fontSize", n); root.kur(); } });
        } else if (k === "ulke") {
            var hazir = [["TR", "Türkiye"], ["DE", "Germany"], ["GB", "United Kingdom"], ["US", "United States"], ["FR", "France"], ["NL", "Netherlands"], ["AZ", "Azerbaijan"], ["CY", "Cyprus"]], it2 = [];
            for (var h = 0; h < hazir.length; h++) it2.push({ label: (hazir[h][0] === app.evUlke ? "● " : "") + hazir[h][1], icon: "globe", key: hazir[h][0] + "|" + hazir[h][1] });
            it2.push({ label: qsTr("Başka ülke: Radyo > Ülkeler > … > Ülkem yap"), icon: "info", key: "x" });
            sheet.open(qsTr("Ülkem"), it2, function (v) { if (v === "x") return; var p = v.split("|"); app.evUlkeAyarla(p[0], p[1]); root.kur(); });
        } else if (k === "aktarma") {
            app.aktarmaAcik = !app.aktarmaAcik;
            app.ayarYaz("aktarma", app.aktarmaAcik ? "1" : "0");
            app.showToast(app.aktarmaAcik ? qsTr("Aktarma açık: şarkı adı görünür, HTTPS ve eski yayınlar çalar") : qsTr("Aktarma kapalı: yayın doğrudan oynatıcıya verilir"));
            kur();
        } else if (k === "uyku") {
            var u = [15, 30, 45, 60, 90, 120], it3 = [];
            for (var m = 0; m < u.length; m++) it3.push({ label: (u[m] === app.uykuVarsayilan ? "● " : "") + u[m] + qsTr(" dakika"), icon: "clock", key: "" + u[m] });
            sheet.open(qsTr("Çalar çubuğundaki saat düğmesinin süresi"), it3, function (v) { app.uykuVarsayilan = parseInt(v, 10); app.ayarYaz("uyku", v); root.kur(); });
        } else if (k === "tam") {
            app.tamMetinOto = !app.tamMetinOto;
            app.ayarYaz("tamMetin", app.tamMetinOto ? "1" : "0");
            kur();
        } else if (k === "kaynak") { app.selectTab(2); haberSayfasi.kaynakMenu(); }
        else if (k === "gunluk") logView.goster(qsTr("Günlük"), yayin.gunluk());
        else if (k === "hakkinda") logView.goster("BelleCast " + app.version,
            qsTr("Nokia E6 için internet radyosu, podcast ve haber okuyucu.\n\n") +
            qsTr("Radyo: radio-browser.info'daki dünya istasyonları (arama, ülkeler, popüler), favoriler, adresle ekleme. Yayınlar telefon içi aktarma katmanından çalar: eski Shoutcast (ICY), HTTPS, HLS (m3u8, TRT dahil) ve çalan şarkı adı.\n\n") +
            qsTr("Podcast: iTunes'ta arama ve ülkeye göre popüler, RSS ile ekleme, abonelik, indirme (çevrimdışı, kaldığı yerden devam), dinlendi işareti.\n\n") +
            qsTr("Haberler: RSS/Atom kaynakları, birleşik akış, okunmamış işareti, tam metin.\n\n") +
            qsTr("Kısayollar: P çal/duraklat, U çalar menüsü, +/- ses, Sol/Sağ sekme, Ctrl+Q çıkış.\n\n") +
            qsTr("Veriler: ") + yayin.veriKlasoru() + qsTr("\nİndirilenler: ") + yayin.indirmeKlasoru());
        else if (k === "cikis") Qt.quit();
    }

    ListModel { id: smodel }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: qsTr("Ayarlar")
        subtitle: "BelleCast " + app.version
    }
    ListView {
        id: liste
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        clip: true
        model: smodel
        delegate: Item {
            width: liste.width
            height: Math.round(32 * app.yazi + 20)
            property bool cur: ListView.isCurrentItem && liste.activeFocus
            Rectangle { anchors.fill: parent; color: ma.pressed ? app.pressed : (parent.cur ? app.highlight : "transparent") }
            Rectangle { visible: parent.cur; anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 4; color: app.brand }
            Image { anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter } width: 24; height: 24; smooth: true; source: "../images/" + simge + "_a.png" }
            Text { id: lbl; anchors { left: parent.left; leftMargin: 54; verticalCenter: parent.verticalCenter } text: etiket; color: app.textPrimary; font.pixelSize: Math.round(18 * app.yazi) }
            Text { anchors { left: lbl.right; leftMargin: 12; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter } horizontalAlignment: Text.AlignRight; text: deger; color: app.textSecondary; font.pixelSize: Math.round(15 * app.yazi); elide: Text.ElideLeft }
            Rectangle { anchors { left: parent.left; leftMargin: 54; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
            MouseArea { id: ma; anchors.fill: parent; onClicked: { liste.currentIndex = index; root.sec(index); } }
        }
        Keys.onPressed: {
            var k = event.key;
            if (app.ortakTus(event)) { event.accepted = true; return; }
            if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select || k === Qt.Key_Space) root.sec(currentIndex);
            else if (k === Qt.Key_Left) app.stepTab(-1);
            else if (k === Qt.Key_Right) app.stepTab(1);
            else return;
            event.accepted = true;
        }
    }
    Rectangle {
        id: logView
        anchors.fill: parent
        color: app.bg
        visible: false
        z: 5
        property string baslik: ""
        function goster(b, m) { baslik = b; lt.text = m; visible = true; lf.contentY = 0; lf.forceActiveFocus(); }
        function gizle() { visible = false; liste.forceActiveFocus(); }
        Header { id: lh; anchors { left: parent.left; right: parent.right; top: parent.top } title: logView.baslik; showBack: true; onBack: logView.gizle() }
        Flickable {
            id: lf
            anchors { left: parent.left; right: parent.right; top: lh.bottom; bottom: parent.bottom; margins: 12 }
            clip: true
            contentHeight: lt.paintedHeight + 20
            Text { id: lt; width: lf.width; wrapMode: Text.Wrap; color: app.textPrimary; font.pixelSize: Math.round(15 * app.yazi); textFormat: Text.PlainText }
            Keys.onPressed: {
                var k = event.key;
                if (k === Qt.Key_Down) contentY = Math.min(Math.max(0, contentHeight - height), contentY + 60);
                else if (k === Qt.Key_Up) contentY = Math.max(0, contentY - 60);
                else if (k === Qt.Key_Escape || k === Qt.Key_Backspace || k === Qt.Key_Context2 || k === Qt.Key_Left || k === Qt.Key_Return || k === Qt.Key_Select) logView.gizle();
                else return;
                event.accepted = true;
            }
        }
    }
}
