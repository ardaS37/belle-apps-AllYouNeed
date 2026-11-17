import QtQuick 1.1
import "Util.js" as U

// Haber okuma sayfasi (ve podcast aciklamasi). Tam metin haber sayfasindan C++ ile ayiklanir.
// Klavye: Yukari/Asagi kaydir, Sol/Sag onceki/sonraki haber, T tam metin, O tarayicida ac,
// +/- yazi boyutu, Geri kapat.
Rectangle {
    id: root
    color: app.bg
    property variant kaynak: null           // HaberPage (oge(i), adet(), okunduIsaretle(i))
    property int sira: -1
    property string baslik: ""
    property string alt: ""
    property string metin: ""
    property string link: ""
    property string resim: ""
    property bool tamMetin: false
    property bool getiriliyor: false

    function takeFocus() { akis.forceActiveFocus(); }
    function haberAc(sayfa, i) {
        kaynak = sayfa;
        goster(i);
        visible = true;
        takeFocus();
    }
    function goster(i) {
        var o = kaynak ? kaynak.oge(i) : null;
        if (!o) return;
        sira = i;
        baslik = o.baslik;
        alt = o.kaynak + "  •  " + app.zamanYazi(o.zaman);
        metin = o.ozet || "";
        link = o.link;
        resim = o.resim || "";
        tamMetin = false;
        getiriliyor = false;
        akis.contentY = 0;
        kaynak.okunduIsaretle(i);
        if (app.tamMetinOto && link !== "") tamGetir();
    }
    function metinGoster(b, a, m, l) {
        kaynak = null;
        sira = -1;
        baslik = b; alt = a; metin = m; link = l || ""; resim = "";
        tamMetin = true;
        getiriliyor = false;
        akis.contentY = 0;
        visible = true;
        takeFocus();
    }
    function tamGetir() {
        if (link === "" || getiriliyor) return;
        getiriliyor = true;
        yayin.metinCek(link);
    }
    function kapat() { visible = false; app.focusCurrent(); }
    function sonraki(d) {
        if (!kaynak) return;
        var j = sira + d;
        if (j < 0 || j >= kaynak.adet()) { app.showToast(d > 0 ? qsTr("Son haber") : qsTr("İlk haber")); return; }
        goster(j);
    }
    function yaziBoyu(d) {
        app.fontSize = Math.max(14, Math.min(32, app.fontSize + d));
        app.ayarYaz("fontSize", app.fontSize);
    }

    Connections {
        target: yayin
        onMetinHazir: {
            if (url !== root.link) return;
            root.getiriliyor = false;
            if (hata !== "") { if (!app.tamMetinOto || root.metin === "") app.showToast(qsTr("Tam metin alınamadı: ") + hata); return; }
            if (metin.length > root.metin.length * 0.8) { root.metin = metin; root.tamMetin = true; }
        }
    }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        showBack: true
        onBack: root.kapat()
        title: root.kaynak ? (root.sira + 1) + " / " + root.kaynak.adet() : qsTr("Açıklama")
        subtitle: root.getiriliyor ? qsTr("tam metin getiriliyor…") : (root.tamMetin ? "" : qsTr("özet"))
        busy: root.getiriliyor
        IconButton { visible: !!root.kaynak; icon: "prev"; tone: "w"; iconSize: 24; onClicked: root.sonraki(-1) }
        IconButton { visible: !!root.kaynak; icon: "next"; tone: "w"; iconSize: 24; onClicked: root.sonraki(1) }
        IconButton { visible: root.link !== "" && !root.tamMetin; icon: "doc"; tone: "a"; iconSize: 24; onClicked: root.tamGetir() }
        IconButton { visible: root.link !== ""; icon: "globe"; tone: "w"; iconSize: 24; onClicked: yayin.disaridaAc(root.link) }
    }
    Flickable {
        id: akis
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        clip: true
        contentHeight: kol.height + 40
        flickableDirection: Flickable.VerticalFlick
        Column {
            id: kol
            x: 16; y: 14
            width: akis.width - 32
            spacing: 10
            Text { width: parent.width; text: root.alt; color: app.brand; font.pixelSize: Math.round(14 * app.yazi) }
            Text { width: parent.width; text: root.baslik; color: app.textPrimary; font.pixelSize: Math.round(23 * app.yazi); font.bold: true; wrapMode: Text.Wrap; textFormat: Text.PlainText }
            Image {
                id: gorsel
                visible: root.resim !== "" && status === Image.Ready
                width: Math.min(parent.width, 420)
                height: visible ? width * sourceSize.height / Math.max(1, sourceSize.width) : 0
                source: root.resim
                sourceSize.width: 420
                asynchronous: true
                smooth: true
                fillMode: Image.PreserveAspectFit
            }
            Text {
                width: parent.width
                text: root.metin !== "" ? root.metin : (root.getiriliyor ? qsTr("Yükleniyor…") : qsTr("Bu haberin özeti yok. Tam metin (T) ya da tarayıcıda aç (O)."))
                color: app.textPrimary
                font.pixelSize: Math.round(18 * app.yazi)
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                lineHeight: 1.15
            }
            Row {
                spacing: 10
                visible: root.link !== ""
                Hap { visible: !root.tamMetin; yazi: qsTr("Tam metni getir"); onTiklandi: root.tamGetir() }
                Hap { yazi: qsTr("Tarayıcıda aç"); onTiklandi: yayin.disaridaAc(root.link) }
                Hap { visible: !!root.kaynak; yazi: qsTr("Sonraki haber ›"); onTiklandi: root.sonraki(1) }
            }
        }
        Keys.onPressed: {
            var k = event.key, t = U.tus(event);
            if (app.ortakTus(event)) { event.accepted = true; return; }
            if (k === Qt.Key_Down) contentY = Math.min(Math.max(0, contentHeight - height), contentY + 80);
            else if (k === Qt.Key_Up) contentY = Math.max(0, contentY - 80);
            else if (k === Qt.Key_Space) contentY = Math.min(Math.max(0, contentHeight - height), contentY + height - 40);
            else if (k === Qt.Key_Right) root.sonraki(1);
            else if (k === Qt.Key_Left) root.sonraki(-1);
            else if (k === Qt.Key_Backspace || k === Qt.Key_Escape || k === Qt.Key_Context2) root.kapat();
            else if (t === "t") root.tamGetir();
            else if (t === "o") { if (root.link !== "") yayin.disaridaAc(root.link); }
            else if (t === "=" || t === "*") root.yaziBoyu(2);
            else if (t === "_" || t === "#") root.yaziBoyu(-2);
            else return;
            event.accepted = true;
        }
    }
}
