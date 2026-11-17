import QtQuick 1.1

// Posta kutusundaki tum klasorler (IMAP LIST): ozel klasorler ustte, etiketler/klasorler alfabetik
Rectangle {
    id: page
    color: "#ffffff"
    visible: false
    z: 55
    property bool yukleniyor: false
    property string hata: ""
    signal closed

    ListModel { id: klasorler }

    function adi(o) {
        var t = { inbox: qsTr("Gelen kutusu"), starred: qsTr("Yıldızlı"), sent: qsTr("Gönderilen"), drafts: qsTr("Taslaklar"),
                  all: qsTr("Tüm postalar"), spam: qsTr("Spam"), trash: qsTr("Çöp kutusu") };
        return o.ozel !== "" && t[o.ozel] ? t[o.ozel] : o.ad;
    }
    function ac() {
        visible = true;
        liste.forceActiveFocus();
        if (klasorler.count > 0) return;
        yenile();
    }
    function yenile() {
        yukleniyor = true;
        hata = "";
        app.istek("klasorler", {}, function (ok, j) {
            yukleniyor = false;
            if (!ok) { hata = j.error; return; }
            klasorler.clear();
            // yildizli her hesapta var (Gmail disinda gelen kutusundaki yildizlilar)
            var yildizVar = false;
            for (var i = 0; i < j.items.length; i++) if (j.items[i].ozel === "starred") yildizVar = true;
            for (var k = 0; k < j.items.length; k++) {
                var o = j.items[k];
                klasorler.append({ k: o.k, ad: page.adi(o), ozel: o.ozel });
                if (o.ozel === "inbox" && !yildizVar) klasorler.append({ k: "starred", ad: qsTr("Yıldızlı"), ozel: "starred" });
            }
        });
    }
    function kapat() { visible = false; closed(); }
    function secIndex(i) {
        if (i < 0 || i >= klasorler.count) return;
        var o = klasorler.get(i);
        kapat();
        app.klasorAc(o.k, o.ad);
    }

    MouseArea { anchors.fill: parent }

    Rectangle {
        id: bar
        width: parent.width; height: 56; color: app.brand
        Btn { id: geri; flat: true; text: qsTr("‹ Geri"); anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter } onClicked: page.kapat() }
        Text { anchors { left: geri.right; leftMargin: 10; verticalCenter: parent.verticalCenter } text: qsTr("Klasörler"); color: "#ffffff"; font.pixelSize: 22; font.bold: true }
        Btn { flat: true; text: qsTr("Yenile"); anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter } onClicked: { klasorler.clear(); page.yenile(); } }
    }

    ListView {
        id: liste
        anchors { top: bar.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        clip: true
        model: klasorler
        highlightMoveDuration: 0
        highlight: Rectangle { color: "#e8eaed" }
        Keys.onPressed: {
            if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Escape) { page.kapat(); event.accepted = true; }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) { page.secIndex(liste.currentIndex); event.accepted = true; }
        }
        delegate: Item {
            width: liste.width
            height: 58
            Rectangle { anchors.fill: parent; color: km.pressed ? "#e8eaed" : "transparent" }
            Text {
                anchors { left: parent.left; leftMargin: 20; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                text: (model.ozel !== "" ? "• " : "") + model.ad
                textFormat: Text.PlainText
                font.pixelSize: 20
                font.bold: app.folder === model.k
                color: app.folder === model.k ? app.brand : app.textPrimary
                elide: Text.ElideRight
            }
            Rectangle { anchors.bottom: parent.bottom; x: 20; width: parent.width - 20; height: 1; color: app.divider }
            MouseArea { id: km; anchors.fill: parent; onClicked: { liste.currentIndex = index; page.secIndex(index); } }
        }
    }
    Text {
        anchors.centerIn: liste
        width: liste.width - 60
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        visible: page.yukleniyor || page.hata !== ""
        text: page.yukleniyor ? qsTr("Yükleniyor…") : page.hata
        color: page.hata !== "" ? "#c5221f" : app.textSecondary
        font.pixelSize: 19
    }
}
