import QtQuick 1.1
import "Util.js" as U

// Gecmis ve favoriler. Dokun: sonucu kopyala. Basili tut / ...: menu (kaynagi kopyala, yeniden cevir, favori, sil).
Rectangle {
    id: root
    color: app.bg
    property bool yalnizFav: false

    function takeFocus() { liste.forceActiveFocus(); }
    function adet() { return gm.count; }
    function yukle() {
        var l = app.sorgu("SELECT rowid AS id, * FROM gecmis " + (yalnizFav ? "WHERE fav = 1 " : "") + "ORDER BY t DESC LIMIT 300");
        gm.clear();
        for (var i = 0; i < l.length; i++)
            gm.append({ kid: Number(l[i].id), kaynak: l[i].kaynak || "", sonuc: l[i].sonuc || "", sl: l[i].sl || "", tl: l[i].tl || "", servis: l[i].servis || "", t: Number(l[i].t) || 0, fav: Number(l[i].fav) === 1 });
        liste.currentIndex = gm.count ? 0 : -1;
    }
    function menu(i) {
        if (i < 0 || i >= gm.count) { genel(); return; }
        var o = gm.get(i);
        sheet.open(o.kaynak.substring(0, 60), [
            { label: qsTr("Sonucu kopyala"), icon: "copy", key: "s", hint: qsTr("Enter") },
            { label: qsTr("Kaynak yazıyı kopyala"), icon: "copy", key: "k" },
            { label: qsTr("Yeniden çevir"), icon: "swap", key: "c" },
            { label: o.fav ? qsTr("Favoriden çıkar") : qsTr("Favorilere ekle"), icon: o.fav ? "star_o" : "star", key: "f", hint: "F" },
            { label: qsTr("Sil"), icon: "trash", key: "d", danger: true, hint: "D" }
        ], function (k) {
            if (k === "s") app.kopyala(o.sonuc);
            else if (k === "k") app.kopyala(o.kaynak);
            else if (k === "c") { cevirSayfasi.dilleriVer(o.sl || "auto", o.tl || "en"); cevirSayfasi.metinVer(o.kaynak); app.selectTab(0); cevirSayfasi.cevir(); }
            else if (k === "f") { app.yurut("UPDATE gecmis SET fav = ? WHERE rowid = ?", [o.fav ? 0 : 1, o.kid]); root.yukle(); }
            else if (k === "d") { app.yurut("DELETE FROM gecmis WHERE rowid = ?", [o.kid]); root.yukle(); }
        });
    }
    function genel() {
        sheet.open(qsTr("Geçmiş"), [
            { label: qsTr("Favoriler dışındakileri temizle"), icon: "trash", key: "t", danger: true }
        ], function (k) { if (k === "t") { app.yurut("DELETE FROM gecmis WHERE fav = 0"); root.yukle(); } });
    }

    ListModel { id: gm }
    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: root.yalnizFav ? qsTr("Favoriler") : qsTr("Geçmiş")
        subtitle: gm.count + qsTr(" kayıt")
        IconButton { icon: "more"; tone: "w"; iconSize: 24; onClicked: root.genel() }
    }
    Row {
        id: haplar
        anchors { left: parent.left; leftMargin: 10; top: header.bottom; topMargin: 6 }
        height: 36
        spacing: 8
        Hap { yazi: qsTr("Tümü"); secili: !root.yalnizFav; onTiklandi: { root.yalnizFav = false; root.yukle(); } }
        Hap { yazi: qsTr("★ Favoriler"); secili: root.yalnizFav; onTiklandi: { root.yalnizFav = true; root.yukle(); } }
    }
    ListView {
        id: liste
        anchors { left: parent.left; right: parent.right; top: haplar.bottom; topMargin: 6; bottom: parent.bottom }
        clip: true
        model: gm
        highlightMoveDuration: 100
        delegate: Rectangle {
            id: sat
            width: liste.width
            height: kol.height + 16
            property bool cur: ListView.isCurrentItem && liste.activeFocus
            color: gma.pressed ? app.pressed : (cur ? app.highlight : "transparent")
            Rectangle { visible: sat.cur; anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 4; color: app.brand }
            Column {
                id: kol
                anchors { left: parent.left; leftMargin: 14; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 2
                Text { width: parent.width; text: (fav ? "★ " : "") + app.dilAdi(sl) + " → " + app.dilAdi(tl) + "  ·  " + servis + "  ·  " + Qt.formatDateTime(new Date(t), "d MMM hh:mm"); color: app.brand; font.pixelSize: Math.round(12 * app.yazi); elide: Text.ElideRight }
                Text { width: parent.width; text: kaynak; color: app.textSecondary; font.pixelSize: Math.round(15 * app.yazi); elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap }
                Text { width: parent.width; text: sonuc; color: app.textPrimary; font.pixelSize: Math.round(17 * app.yazi); elide: Text.ElideRight; maximumLineCount: 3; wrapMode: Text.Wrap }
            }
            Rectangle { anchors { left: parent.left; leftMargin: 14; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
            MouseArea { id: gma; anchors.fill: parent; onClicked: { liste.currentIndex = index; app.kopyala(sonuc); } onPressAndHold: { liste.currentIndex = index; root.menu(index); } }
        }
        Keys.onPressed: {
            if (app.ortakTus(event)) { event.accepted = true; return; }
            var k = event.key, t = U.tus(event), o = currentIndex >= 0 && currentIndex < gm.count ? gm.get(currentIndex) : null;
            if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) { if (o) app.kopyala(o.sonuc); }
            else if (k === Qt.Key_Space || k === Qt.Key_Menu || k === Qt.Key_Context1) root.menu(currentIndex);
            else if (k === Qt.Key_Left) app.stepTab(-1);
            else if (k === Qt.Key_Right) app.stepTab(1);
            else if (t === "f") { if (o) { app.yurut("UPDATE gecmis SET fav = ? WHERE rowid = ?", [o.fav ? 0 : 1, o.kid]); root.yukle(); } }
            else if (t === "d") { if (o) { app.yurut("DELETE FROM gecmis WHERE rowid = ?", [o.kid]); root.yukle(); } }
            else return;
            event.accepted = true;
        }
    }
    Text {
        anchors.centerIn: liste
        visible: gm.count === 0
        width: liste.width - 40
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: root.yalnizFav ? qsTr("Favori yok. Sonuç kartındaki ★ ile ekleyin.") : qsTr("Geçmiş boş.")
        color: app.textSecondary
        font.pixelSize: Math.round(16 * app.yazi)
    }
}
