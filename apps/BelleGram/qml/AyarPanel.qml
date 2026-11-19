import QtQuick 1.1

// Ayarlar: hesap bilgisi, tema, dil, gunluk, cikis
Rectangle {
    id: root
    color: "#99000000"
    MouseArea { anchors.fill: parent; onClicked: app.ayarAcik = false }

    property bool gunlukAcik: false

    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 80
        height: Math.min(parent.height - 40, kolon.height + 40)
        radius: 16
        color: app.surface
        MouseArea { anchors.fill: parent }

        Flickable {
            anchors { fill: parent; margins: 20 }
            contentHeight: kolon.height
            clip: true
            Column {
                id: kolon
                width: parent.width
                spacing: 14
                Text { text: tg.benAd; color: app.textPrimary; font.pixelSize: 24; font.bold: true; width: parent.width; elide: Text.ElideRight }
                Text { text: "+" + tg.telefon; color: app.textSecondary; font.pixelSize: 19 }
                Dugme { width: parent.width; birincil: false; text: app.dark ? qsTr("Açık tema") : qsTr("Koyu tema"); onClicked: app.dark = !app.dark }
                DilSatiri { width: parent.width }
                DepoSatiri { width: parent.width }
                Dugme { width: parent.width; birincil: false; text: root.gunlukAcik ? qsTr("Günlüğü gizle") : qsTr("Günlüğü göster"); onClicked: root.gunlukAcik = !root.gunlukAcik }
                Text {
                    visible: root.gunlukAcik
                    width: parent.width
                    wrapMode: Text.WrapAnywhere
                    text: root.gunlukAcik ? tg.gunluk() : ""
                    color: app.textSecondary
                    font.pixelSize: 13
                }
                Dugme { width: parent.width; text: qsTr("Çıkış yap"); onClicked: { app.ayarAcik = false; app.sohbetKapat(); sohbetModel.clear(); tg.cikis(); } }
                Dugme { width: parent.width; birincil: false; text: qsTr("API bilgilerini değiştir (çıkış yapar)"); onClicked: { app.ayarAcik = false; app.sohbetKapat(); sohbetModel.clear(); tg.apiDegistir(); } }
                Dugme { width: parent.width; birincil: false; text: qsTr("Uygulamayı kapat"); onClicked: Qt.quit() }
            }
        }
    }
}
