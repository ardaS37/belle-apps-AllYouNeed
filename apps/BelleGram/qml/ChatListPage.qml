import QtQuick 1.1
import "Util.js" as Util
import "Emoji.js" as Emoji

// Sohbet listesi: kisiler, gruplar, kanallar (son mesaj, saat, okunmamis, sessiz, sabit).
// Basili tut: sessize al / sabitle / okundu / sil. Ara ve yeni mesaj dugmeleri.
Rectangle {
    id: root
    color: app.bg

    function sohbetMenusu(i) {
        var o = sohbetModel.get(i);
        var l = [];
        l.push(["sessiz", o.sessiz ? qsTr("Sesi aç") : qsTr("Sessize al")]);
        l.push(["sabit", o.sabit ? qsTr("Sabitlemeyi kaldır") : qsTr("Başa sabitle")]);
        if (o.okunmamis > 0) l.push(["okundu", qsTr("Okundu olarak işaretle")]);
        l.push(["sil", o.tur === "kisi" ? qsTr("Sohbeti sil") : (o.sid.charAt(0) === "k" ? (o.tur === "kanal" ? qsTr("Kanaldan ayrıl") : qsTr("Gruptan ayrıl")) : qsTr("Geçmişi temizle")), true]);
        menu.ac(o.ad, l, { tur: "sohbet", sid: o.sid });
    }

    Header {
        id: baslik
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: "BelleGram"
        brandTitle: true
        subtitle: tg.bagli ? "" : qsTr("Bağlanıyor…")
        busy: app.sohbetYukleniyor || !tg.bagli
        IconButton {
            source: "../images/search" + app.iconTone + ".png"
            onClicked: app.kisilerAc("ara", "")
        }
        IconButton {
            source: "../images/refresh" + app.iconTone + ".png"
            onClicked: { app.sohbetYukleniyor = true; tg.sohbetleriYukle(false); }
        }
        IconButton {
            source: "../images/nav_settings" + (app.dark ? "_light" : "") + ".png"
            onClicked: app.ayarAcik = true
        }
    }

    ListView {
        id: liste
        anchors { left: parent.left; right: parent.right; top: baslik.bottom; bottom: parent.bottom }
        model: sohbetModel
        clip: true
        focus: visible
        highlightMoveDuration: 120
        onAtYEndChanged: {
            if (atYEnd && count > 0 && !app.sohbetSonu && !app.sohbetYukleniyor) {
                app.sohbetYukleniyor = true;
                tg.sohbetleriYukle(true);
            }
        }
        Keys.onReturnPressed: if (currentIndex >= 0) { var o = sohbetModel.get(currentIndex); app.sohbetAc(o.sid, o.ad, o.tur); }
        Keys.onEnterPressed: if (currentIndex >= 0) { var o = sohbetModel.get(currentIndex); app.sohbetAc(o.sid, o.ad, o.tur); }

        delegate: Rectangle {
            width: liste.width
            height: 86
            color: fare.pressed || (liste.activeFocus && ListView.isCurrentItem) ? app.pressed : app.bg

            Avatar {
                id: av
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                name: ad
                key: sid
                size: 60
            }
            Text {
                id: zamanYazi
                anchors { right: parent.right; rightMargin: 16; top: parent.top; topMargin: 16 }
                text: Util.listeZamani(zaman)
                color: okunmamis > 0 && !sessiz ? app.accentText : app.textSecondary
                font.pixelSize: 17
            }
            Row {
                id: simgeler
                anchors { right: zamanYazi.left; rightMargin: 6; verticalCenter: zamanYazi.verticalCenter }
                spacing: 2
                Image { visible: sessiz; width: 22; height: 22; smooth: true; source: "../images/mute.png" }
            }
            Text {
                anchors { left: av.right; leftMargin: 14; right: simgeler.left; rightMargin: 8; top: parent.top; topMargin: 14 }
                text: (tur === "kanal" ? qsTr("[Kanal] ") : "") + ad
                color: app.textPrimary
                font.pixelSize: 22
                font.bold: true
                elide: Text.ElideRight
            }
            Rectangle {
                id: rozet
                visible: okunmamis > 0
                anchors { right: parent.right; rightMargin: 16; bottom: parent.bottom; bottomMargin: 14 }
                height: 28
                width: Math.max(28, rozetYazi.paintedWidth + 16)
                radius: 14
                color: sessiz ? (app.dark ? "#3B4A5A" : "#B8C1C9") : app.unread
                Text { id: rozetYazi; anchors.centerIn: parent; text: okunmamis > 999 ? "999+" : okunmamis; color: "#FFFFFF"; font.pixelSize: 16; font.bold: true }
            }
            Image {
                id: igne
                visible: sabit && okunmamis === 0
                anchors { right: parent.right; rightMargin: 18; bottom: parent.bottom; bottomMargin: 16 }
                width: 22; height: 22; smooth: true
                source: "../images/pin.png"
            }
            Text {
                anchors { left: av.right; leftMargin: 14; right: rozet.visible ? rozet.left : (igne.visible ? igne.left : parent.right); rightMargin: 12; bottom: parent.bottom; bottomMargin: 16 }
                text: yaziyor !== "" ? yaziyor : (benden ? qsTr("Siz: ") : "") + son.replace(/\n/g, " ")
                color: yaziyor !== "" ? app.accentText : app.textSecondary
                font.pixelSize: 19
                font.italic: yaziyor !== ""
                elide: Text.ElideRight
            }
            Rectangle {
                anchors { left: av.right; leftMargin: 14; right: parent.right; bottom: parent.bottom }
                height: 1
                color: app.divider
            }
            MouseArea {
                id: fare
                anchors.fill: parent
                onClicked: { liste.currentIndex = index; app.sohbetAc(sid, ad, tur); }
                onPressAndHold: { liste.currentIndex = index; root.sohbetMenusu(index); }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: liste.count === 0 && !app.sohbetYukleniyor
            text: qsTr("Sohbet yok")
            color: app.textSecondary
            font.pixelSize: 20
        }
    }

    // yeni mesaj
    Rectangle {
        anchors { right: parent.right; bottom: parent.bottom; margins: 18 }
        width: 64; height: 64; radius: 32
        color: yFare.pressed ? app.brandPressed : app.brand
        smooth: true
        Image { anchors.centerIn: parent; width: 34; height: 34; smooth: true; source: "../images/newchat.png" }
        MouseArea { id: yFare; anchors.fill: parent; onClicked: app.kisilerAc("yeni", "") }
    }
}
