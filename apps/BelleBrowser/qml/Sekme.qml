import QtQuick 1.1
import QtWebKit 1.0
import "Util.js" as U

// Tek sekme: kaydirilabilir WebView. Sayfa yuklenince U.BETIK eklenir (indirmeler, uzun basma, videolar).
// Akicilik (Star Browser yontemi): WebKit sayfayi parcalar halinde onceden cizer (main.cpp TiledBackingStore),
// kaydirma / yakinlastirma sirasinda yeni cizim dondurulur (renderingEnabled), PinchArea WebView'in ALTINDA durur
// (ustte olursa dokunmalari yutar, baglantilar tiklanmaz). Sayfa yuksekligi sabit: ust cubuk gizlenip acilinca
// WebKit sayfayi yeniden dizmez.
Item {
    id: sekme
    property string url: ""
    property string baslik: web.title
    property bool yukleniyor: web.status === WebView.Loading
    property real ilerleme: web.progress
    property bool geriVar: web.back.enabled
    property bool ileriVar: web.forward.enabled
    property bool hata: web.status === WebView.Error
    property variant videolar: []
    property real olcek: web.contentsScale
    property real temelOlcek: 1
    property int yaziBoyu: 16
    property int sayfaYuksekligi: height        // sabit tutulur (main.qml ekran yuksekligini verir)
    property alias web: web
    property alias flick: flick
    signal kaydirildi(real dy)
    signal dosyaIstendi(string u, string ad)
    signal baglamIstendi(string json)
    signal yuklendi()
    signal dokunuldu()
    signal yeniPencere(string u)

    function ac(u) { url = u; videolar = []; web.url = u; }
    function geri() { web.back.trigger(); }
    function ileri() { web.forward.trigger(); }
    function yenile() { web.reload.trigger(); }
    function dur() { web.stop.trigger(); }
    function js(s) { return web.evaluateJavaScript(s); }
    function cizim(acik) { try { web.renderingEnabled = acik; } catch (e) { } }
    function kaydir(dx, dy) {
        flick.contentX = Math.max(0, Math.min(flick.contentX + dx, flick.contentWidth - flick.width));
        flick.contentY = Math.max(0, Math.min(flick.contentY + dy, flick.contentHeight - flick.height));
    }
    function sayfa(n) { kaydir(0, n * (flick.height - 50)); }
    function basaGit() { flick.contentY = 0; }
    function odakGirdiMi() { return "" + js(U.ODAK) === "1"; }
    function odakBirak() { js("document.activeElement&&document.activeElement.blur&&document.activeElement.blur()"); }
    // Gorunumdeki nokta -> sayfadaki oge (baglanti / resim / video)
    function hedefAl(vx, vy) {
        var s = olcek;
        var r = js("window.__bbHedef?window.__bbHedef(" + Math.round((flick.contentX + vx) / s) + "," + Math.round((flick.contentY + vy) / s) + "):'{}'");
        return "" + (r || "{}");
    }
    function bul(t) {
        if (!t) return false;
        var ok = js("window.find(" + JSON.stringify(t) + ",false,false,true)");
        var yer = "" + js(U.SECIM_YERI);
        if (yer) {
            var a = yer.split(",");
            flick.contentY = Math.max(0, Math.min(parseInt(a[0], 10) * olcek - flick.height / 3, flick.contentHeight - flick.height));
            flick.contentX = Math.max(0, Math.min(parseInt(a[1], 10) * olcek - 20, flick.contentWidth - flick.width));
        }
        return ok === true || ok === "true";
    }
    function gece(acik) { js(acik ? U.GECE : U.GECE_KAPAT); }
    function yakinlas(hedef, cx, cy) {
        // cx, cy: gorunumdeki nokta (bu nokta yerinde kalir)
        var eski = web.contentsScale;
        hedef = Math.max(temelOlcek * 0.5, Math.min(4, hedef));
        var sx = (flick.contentX + cx) / eski, sy = (flick.contentY + cy) / eski;
        web.contentsScale = hedef;
        flick.contentX = Math.max(0, Math.min(sx * hedef - cx, web.width - flick.width));
        flick.contentY = Math.max(0, Math.min(sy * hedef - cy, web.height - flick.height));
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: Math.max(width, web.width)
        contentHeight: Math.max(height, web.height)
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.AutoFlickDirection
        maximumFlickVelocity: 4000
        flickDeceleration: 1800
        property real sonY: 0
        onContentYChanged: {
            var d = contentY - sonY;
            if (Math.abs(d) > 12) { if (moving) sekme.kaydirildi(d); sonY = contentY; }
        }
        onMovementStarted: { sekme.cizim(false); sekme.dokunuldu(); }
        onMovementEnded: sekme.cizim(true)

        PinchArea {
            id: pa
            width: Math.max(flick.width, web.width)
            height: Math.max(flick.height, web.height)
            enabled: !sekme.hata
            property real basOlcek: 1
            property real mx: 0
            property real my: 0
            onPinchStarted: {
                sekme.cizim(false);
                basOlcek = web.contentsScale;
                mx = pinch.startCenter.x - flick.contentX; my = pinch.startCenter.y - flick.contentY;
            }
            onPinchUpdated: sekme.yakinlas(basOlcek * pinch.scale, mx, my)
            onPinchFinished: sekme.cizim(true)

            WebView {
                id: web
                transformOrigin: Item.TopLeft
                smooth: false
                preferredWidth: tb.ua === "masa" ? 980 : flick.width
                preferredHeight: sekme.sayfaYuksekligi
                pressGrabTime: 400
                settings.javascriptCanOpenWindows: true
                settings.javascriptCanAccessClipboard: true
                settings.localStorageDatabaseEnabled: true
                settings.offlineStorageDatabaseEnabled: true
                settings.minimumFontSize: 9
                settings.defaultFontSize: sekme.yaziBoyu
                settings.autoLoadImages: tb.ayar("resimler", "1") === "1"
                // target=_blank / window.open / "yeni pencerede ac": gizli bir WebView acilir, adresi yeni sekmeye aktarilir
                newWindowComponent: yeniPencereBileseni
                newWindowParent: gizliPencereler
                javaScriptWindowObjects: QtObject {
                    WebView.windowObjectName: "belle"
                    function dosya(u, ad) { sekme.dosyaIstendi("" + u, "" + ad); }
                    function baglam(j) { sekme.baglamIstendi("" + j); }
                    function videolar(l) { var s = "" + l; sekme.videolar = s ? s.split("\n") : []; }
                }
                onUrlChanged: sekme.url = url.toString()
                onLoadStarted: {
                    sekme.videolar = [];
                    if (tb.ua === "masa") { sekme.temelOlcek = flick.width / 980; contentsScale = sekme.temelOlcek; }
                    else { sekme.temelOlcek = 1; contentsScale = 1; }
                    flick.contentX = 0; flick.contentY = 0;
                    sekme.cizim(true);
                }
                onLoadFinished: {
                    evaluateJavaScript(U.BETIK);
                    if (app.gece) evaluateJavaScript(U.GECE);
                    sekme.yuklendi();
                }
                onLoadFailed: tb.log("yuklenemedi " + sekme.url)
                onDoubleClick: {
                    var hedef = contentsScale < sekme.temelOlcek * 1.4 ? sekme.temelOlcek * 2 : sekme.temelOlcek;
                    sekme.yakinlas(hedef, clickX * contentsScale - flick.contentX, clickY * contentsScale - flick.contentY);
                }
                onAlert: app.bildir(message)
            }
        }
    }
    Item { id: gizliPencereler; visible: false; width: 1; height: 1 }
    Component {
        id: yeniPencereBileseni
        WebView {
            id: yp
            width: 1; height: 1
            property bool bitti: false
            settings.autoLoadImages: false
            onUrlChanged: {
                var u = url.toString();
                if (bitti || u === "" || u === "about:blank") return;
                bitti = true;
                yp.stop.trigger();
                sekme.yeniPencere(u);
                yp.destroy(1000);
            }
        }
    }
    // kaydirma cubugu
    Rectangle {
        visible: flick.moving && flick.contentHeight > flick.height * 1.5
        anchors.right: parent.right
        width: 4; radius: 2
        color: "#80808080"
        y: flick.height * flick.contentY / flick.contentHeight
        height: Math.max(24, flick.height * flick.height / flick.contentHeight)
    }
}
