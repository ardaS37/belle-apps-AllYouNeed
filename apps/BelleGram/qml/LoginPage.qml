import QtQuick 1.1

// Giris: telefon numarasi -> Telegram'dan gelen kod -> (varsa) iki adimli dogrulama sifresi
Rectangle {
    id: root
    color: app.bg

    property string adim: tg.durum   // baslangic | api | baglaniyor | telefon | kod | sifre

    function apiKaydet() {
        cihaz.girisiTamamla();
        var h = tg.apiAyarla(apiIdKutu.text, apiHashKutu.text);
        if (h !== "") toast.show(h);
        else { apiHashKutu.text = ""; }
    }

    onAdimChanged: odakla.restart()
    Timer { id: odakla; interval: 300; onTriggered: {
        if (root.adim === "api") apiIdKutu.focusInput();
        else if (root.adim === "telefon") telefonKutu.focusInput();
        else if (root.adim === "kod") kodKutu.focusInput();
        else if (root.adim === "sifre") sifreKutu.focusInput();
    } }

    Column {
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 60 }
        spacing: 18

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.adim !== "api"   // ekrana sigsin: API adiminda aciklama uzun
            width: 84; height: 84; radius: 42
            color: app.brand
            Text { anchors.centerIn: parent; text: "B"; color: "#FFFFFF"; font.pixelSize: 46; font.bold: true }
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.adim === "api" ? qsTr("Telegram API bilgileri") : root.adim === "kod" ? qsTr("Kodu girin") : root.adim === "sifre" ? qsTr("İki adımlı doğrulama") : "BelleGram"
            color: app.textPrimary
            font.pixelSize: 30
            font.bold: true
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: app.textSecondary
            font.pixelSize: root.adim === "api" ? 16 : 19
            text: root.adim === "api" ? qsTr("Kendi Telegram uygulama kimliğiniz gerekir: bilgisayardan my.telegram.org → \"API development tools\" bölümünde bir uygulama oluşturun, api_id ve api_hash değerlerini yazın (Ctrl+V ile yapıştırabilirsiniz). Yalnızca bu telefonda saklanır.")
                : root.adim === "baglaniyor" || root.adim === "baslangic" ? qsTr("Telegram'a bağlanılıyor…")
                : root.adim === "telefon" ? qsTr("Telefon numaranızı ülke koduyla yazın. Telegram size bir giriş kodu gönderecek.")
                : root.adim === "kod" ? tg.kodBilgi + "\n+" + tg.telefon
                : qsTr("Hesabınızda bulut şifresi açık. Şifrenizi girin.") + (tg.sifreIpucu !== "" ? "\n" + qsTr("İpucu: ") + tg.sifreIpucu : "")
        }

        TextField {
            id: apiIdKutu
            width: parent.width
            visible: root.adim === "api"
            placeholder: qsTr("api_id (rakam)")
            inputMethodHints: Qt.ImhDigitsOnly
            onAccepted: apiHashKutu.focusInput()
        }
        TextField {
            id: apiHashKutu
            width: parent.width
            visible: root.adim === "api"
            placeholder: qsTr("api_hash (32 karakter)")
            fontSize: 18
            inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase | Qt.ImhPreferLowercase
            onAccepted: root.apiKaydet()
        }
        TextField {
            id: telefonKutu
            width: parent.width
            visible: root.adim === "telefon"
            placeholder: qsTr("Örn. 905321234567")
            inputMethodHints: Qt.ImhDialableCharactersOnly
            onAccepted: tg.kodGonder(text)
        }
        TextField {
            id: kodKutu
            width: parent.width
            visible: root.adim === "kod"
            placeholder: qsTr("Giriş kodu")
            inputMethodHints: Qt.ImhDigitsOnly
            onAccepted: tg.kodOnayla(text)
        }
        TextField {
            id: sifreKutu
            width: parent.width
            visible: root.adim === "sifre"
            placeholder: qsTr("Şifre")
            echoMode: TextInput.Password
            onAccepted: tg.sifreOnayla(text)
        }

        Dugme {
            width: parent.width
            visible: root.adim === "api"
            text: qsTr("Kaydet ve devam et")
            onClicked: root.apiKaydet()
        }
        Dugme {
            width: parent.width
            visible: root.adim === "telefon" || root.adim === "kod" || root.adim === "sifre"
            text: root.adim === "telefon" ? qsTr("Kod gönder") : qsTr("Giriş yap")
            onClicked: {
                cihaz.girisiTamamla();
                if (root.adim === "telefon") tg.kodGonder(telefonKutu.text);
                else if (root.adim === "kod") tg.kodOnayla(kodKutu.text);
                else tg.sifreOnayla(sifreKutu.text);
            }
        }
        Dugme {
            width: parent.width
            visible: root.adim === "kod" || root.adim === "sifre"
            birincil: false
            text: qsTr("Numarayı değiştir")
            onClicked: { kodKutu.text = ""; sifreKutu.text = ""; tg.numaraDegistir(); }
        }
        Dugme {
            width: parent.width
            visible: root.adim === "telefon"
            birincil: false
            text: qsTr("API bilgilerini değiştir")
            onClicked: { apiIdKutu.text = tg.apiId; tg.apiDegistir(); }
        }
    }

    Text {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 14 }
        visible: root.adim !== "api"
        text: tg.bagli ? qsTr("Telegram sunucusuna bağlı") : qsTr("Bağlantı kuruluyor…")
        color: app.textSecondary
        font.pixelSize: 16
    }
}
