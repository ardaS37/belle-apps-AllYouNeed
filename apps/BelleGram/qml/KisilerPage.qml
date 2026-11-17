import QtQuick 1.1
import "Util.js" as Util

// Arama / yeni mesaj / iletme: sohbetler + rehberdeki Telegram kisileri + genel arama (@kullanici, ad)
//  kip "yeni": kisiler; "ara": sohbet ve kisi arama; "ilet": hedef sohbet secimi
Rectangle {
    id: root
    visible: false
    color: app.bg
    z: 20
    property string kip: "yeni"
    property string iletMid: ""
    property string iletKaynak: ""
    property variant kisiler: []
    property variant genel: []
    property string sorgu: ""
    property bool araniyor: false

    function ac(k, mid) {
        kip = k;
        iletMid = mid || "";
        iletKaynak = app.acik;
        alan.text = "";
        sorgu = "";
        genel = [];
        visible = true;
        doldur();
        if (kisiler.length === 0) tg.kisileriYukle();
        alan.focusInput();
    }
    function kapat() { visible = false; alan.input.closeSoftwareInputPanel(); }

    function uyar(ad, q) { return q === "" || ad.toLowerCase().indexOf(q) >= 0; }
    function doldur() {
        sonucModel.clear();
        var q = sorgu.toLowerCase().replace(/^\s+|\s+$/g, "");
        var eklenen = {};
        if (q === "" && kip !== "ara") {
            sonucModel.append({ sid: tg.kayitliSohbet(), ad: qsTr("Kayıtlı Mesajlar"), alt: qsTr("kendinize not"), tur: "kisi", bolum: "" });
            eklenen[tg.kayitliSohbet()] = true;
        }
        // sohbetler (ara / ilet)
        if (kip !== "yeni") {
            var n = 0;
            for (var i = 0; i < sohbetModel.count && n < 40; i++) {
                var s = sohbetModel.get(i);
                if (eklenen[s.sid] || !uyar(s.ad, q)) continue;
                if (kip === "ilet" && s.tur === "kanal") continue;
                eklenen[s.sid] = true;
                sonucModel.append({ sid: s.sid, ad: s.ad, alt: s.tur === "kisi" ? "" : (s.tur === "grup" ? qsTr("grup") : qsTr("kanal")), tur: s.tur, bolum: qsTr("Sohbetler") });
                n++;
            }
        }
        // rehber
        var k = kisiler;
        for (var j = 0; j < k.length; j++) {
            if (eklenen[k[j].id] || !uyar(k[j].ad + " " + k[j].alt, q)) continue;
            eklenen[k[j].id] = true;
            sonucModel.append({ sid: k[j].id, ad: k[j].ad, alt: k[j].alt, tur: k[j].tur === "bot" ? "kisi" : k[j].tur, bolum: qsTr("Kişiler") });
        }
        // genel arama
        var g = genel;
        for (var m = 0; m < g.length; m++) {
            if (eklenen[g[m].id]) continue;
            eklenen[g[m].id] = true;
            sonucModel.append({ sid: g[m].id, ad: g[m].ad, alt: g[m].alt || "", tur: g[m].tur === "bot" ? "kisi" : g[m].tur, bolum: qsTr("Genel arama") });
        }
    }
    function sec(i) {
        var o = sonucModel.get(i);
        if (kip === "ilet") {
            tg.ilet(iletKaynak, iletMid, o.sid);
            kapat();
            return;
        }
        kapat();
        app.sohbetAc(o.sid, o.ad, o.tur);
    }

    Connections {
        target: tg
        onKisiListesi: {
            var l = [];
            for (var i = 0; i < liste.length; i++) l.push(liste[i]);
            l.sort(function (a, b) { return a.ad.toLowerCase() < b.ad.toLowerCase() ? -1 : 1; });
            root.kisiler = l;
            if (root.visible) root.doldur();
        }
        onAramaSonucu: {
            if (sorgu !== root.sorgu) return;
            root.araniyor = false;
            root.genel = liste;
            root.doldur();
        }
    }
    Timer {
        id: aramaZaman
        interval: 700
        onTriggered: if (root.sorgu.replace(/\s+/g, "").length >= 3 && root.kip !== "ilet") { root.araniyor = true; tg.kisiAra(root.sorgu); }
    }

    MouseArea { anchors.fill: parent }

    Header {
        id: baslik
        anchors { left: parent.left; right: parent.right; top: parent.top }
        showBack: true
        title: root.kip === "ilet" ? qsTr("İlet…") : (root.kip === "ara" ? qsTr("Ara") : qsTr("Yeni mesaj"))
        busy: root.araniyor
        onBack: root.kapat()
    }

    TextField {
        id: alan
        anchors { left: parent.left; right: parent.right; top: baslik.bottom; margins: 10 }
        placeholder: root.kip === "ilet" ? qsTr("Sohbet ara") : qsTr("Ad, @kullanıcı adı ya da numara")
        onTextChanged: { root.sorgu = text; root.genel = []; root.doldur(); aramaZaman.restart(); }
        onAccepted: if (sonucModel.count > 0) root.sec(0)
    }

    ListModel { id: sonucModel }

    ListView {
        id: liste
        anchors { left: parent.left; right: parent.right; top: alan.bottom; topMargin: 6; bottom: parent.bottom }
        model: sonucModel
        clip: true
        section.property: "bolum"
        section.criteria: ViewSection.FullString
        section.delegate: Item {
            width: liste.width
            height: section !== "" ? 40 : 0
            Text { visible: section !== ""; x: 20; anchors.verticalCenter: parent.verticalCenter; text: section; color: app.accentText; font.pixelSize: 17; font.bold: true }
        }
        delegate: Rectangle {
            width: liste.width
            height: 76
            color: kFare.pressed ? app.pressed : app.bg
            Avatar {
                id: av
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                name: ad
                key: sid
                size: 54
            }
            Column {
                anchors { left: av.right; leftMargin: 14; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                Text { width: parent.width; text: ad; color: app.textPrimary; font.pixelSize: 21; font.bold: true; elide: Text.ElideRight }
                Text { width: parent.width; visible: alt !== ""; text: alt; color: app.textSecondary; font.pixelSize: 17; elide: Text.ElideRight }
            }
            Rectangle { anchors { left: av.right; leftMargin: 14; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
            MouseArea { id: kFare; anchors.fill: parent; onClicked: root.sec(index) }
        }
        Text {
            anchors.centerIn: parent
            visible: liste.count === 0
            width: parent.width - 60
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: root.araniyor ? qsTr("Aranıyor…") : (root.sorgu === "" ? qsTr("Kişiler yükleniyor…") : qsTr("Sonuç yok"))
            color: app.textSecondary
            font.pixelSize: 19
        }
    }
}
