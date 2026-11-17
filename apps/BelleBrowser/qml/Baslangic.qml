import QtQuick 1.1
import "Db.js" as Db
import "Siteler.js" as S
import "Util.js" as U

// Yeni sekme sayfasi: arama kutusu, hizli erisim, Symbian'a uygun siteler, HTTP siteler
Rectangle {
    id: root
    color: app.cZemin
    signal ac(string url)
    function yenile() {
        hm.clear();
        var f = Db.favlar(), g = {}, n = 0;
        for (var i = 0; i < f.length && n < 8; i++) { hm.append({ b: f[i].baslik, u: f[i].url }); g[f[i].url] = 1; n++; }
        var s = Db.sikZiyaret(8);
        for (var j = 0; j < s.length && n < 8; j++) if (!g[s[j].url]) { hm.append({ b: s[j].baslik, u: s[j].url }); g[s[j].url] = 1; n++; }
        for (var k = 0; k < S.HIZLI.length && n < 8; k++) if (!g[S.HIZLI[k].u]) { hm.append({ b: S.HIZLI[k].b, u: S.HIZLI[k].u }); n++; }
    }
    Component.onCompleted: { yenile(); for (var i = 0; i < S.SYMBIAN.length; i++) sm.append(S.SYMBIAN[i]); for (var j = 0; j < S.HTTP.length; j++) pm.append(S.HTTP[j]); }
    onVisibleChanged: if (visible) yenile()

    ListModel { id: hm }
    ListModel { id: sm }
    ListModel { id: pm }

    Component {
        id: kutuBilesen
        Item {
            width: 92; height: 92
            Rectangle {
                id: harf
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 6 }
                width: 52; height: 52; radius: 26
                color: U.renk(U.host(u))
                Text { anchors.centerIn: parent; text: (b || U.host(u)).charAt(0).toUpperCase(); color: "#fff"; font.pixelSize: 30; font.bold: true }
            }
            Text { anchors { top: harf.bottom; topMargin: 6; horizontalCenter: parent.horizontalCenter } width: 88; horizontalAlignment: Text.AlignHCenter
                text: b; elide: Text.ElideRight; font.pixelSize: 16; color: app.cYazi }
            MouseArea { anchors.fill: parent; onClicked: root.ac(u); onPressAndHold: app.baglantiMenusu(u, b) }
        }
    }
    Component {
        id: satirBilesen
        Item {
            width: parent ? parent.width : 300; height: 48
            Rectangle { anchors.fill: parent; color: app.cYuzey; visible: sma.pressed }
            Rectangle { id: nokta; anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter } width: 30; height: 30; radius: 15; color: U.renk(U.host(u))
                Text { anchors.centerIn: parent; text: b.charAt(0).toUpperCase(); color: "#fff"; font.pixelSize: 19; font.bold: true } }
            Column {
                anchors { left: nokta.right; leftMargin: 12; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                Text { width: parent.width; text: b; color: app.cYazi; font.pixelSize: 20; elide: Text.ElideRight }
                Text { width: parent.width; text: u.replace(/^https?:\/\//, ""); color: app.cIkinci; font.pixelSize: 15; elide: Text.ElideRight }
            }
            MouseArea { id: sma; anchors.fill: parent; onClicked: root.ac(u); onPressAndHold: app.baglantiMenusu(u, b) }
        }
    }

    Flickable {
        id: fl
        anchors.fill: parent
        contentHeight: kol.height + 30
        clip: true
        Column {
            id: kol
            width: fl.width
            spacing: 6
            Item { width: 1; height: 18 }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2
                Text { text: qsTr("Belle"); font.pixelSize: 42; font.bold: true; color: app.cVurgu }
                Text { text: qsTr(" Browser"); font.pixelSize: 42; color: app.cYazi }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width - 32, 560); height: 48; radius: 24
                color: app.cYuzey
                Image { id: ai; anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter } width: 22; height: 22; smooth: true; source: "../images/ara_" + (app.gece ? "b" : "k") + ".png" }
                Text { anchors { left: ai.right; leftMargin: 12; verticalCenter: parent.verticalCenter } text: qsTr("Ara ya da adres yaz"); color: app.cIkinci; font.pixelSize: 21 }
                MouseArea { anchors.fill: parent; onClicked: app.adresAc("") }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (tb.parolaVar ? (tb.mod === "dogrudan" ? qsTr("Doğrudan bağlantı") : (tb.mod === "akilli" ? qsTr("Akıllı mod: HTTPS sunucudan") : qsTr("Sıkıştırılmış mod: tüm sayfalar sunucudan")))
                                    : qsTr("Sunucu katmanı kapalı • Menü > Ayarlar")) + (tb.tasarruf ? "  •  " + tb.tasarruf : "")
                color: app.cIkinci; font.pixelSize: 16
            }
            Item { width: 1; height: 6 }
            Grid {
                anchors.horizontalCenter: parent.horizontalCenter
                columns: Math.max(3, Math.min(8, Math.floor((root.width - 16) / 96)))
                spacing: 4
                Repeater { model: hm; delegate: kutuBilesen }
            }
            Text { x: 16; text: qsTr("Symbian için uygun siteler"); font.pixelSize: 19; font.bold: true; color: app.cIkinci; height: 34; verticalAlignment: Text.AlignBottom }
            Column { width: parent.width; Repeater { model: sm; delegate: satirBilesen } }
            Text { x: 16; text: qsTr("HTTP (şifresiz, sunucusuz açılan) siteler"); font.pixelSize: 19; font.bold: true; color: app.cIkinci; height: 34; verticalAlignment: Text.AlignBottom }
            Column { width: parent.width; Repeater { model: pm; delegate: satirBilesen } }
        }
    }
}
