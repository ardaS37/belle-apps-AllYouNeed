import QtQuick 1.1

// Posta hesabi (sunucusuz): saglayici secilir, adres + uygulama sifresi girilir; "Kaydet" giris dener.
Rectangle {
    id: page
    color: "#ffffff"
    visible: false
    z: 70

    property string saglayici: "gmail"
    property bool deneniyor: false
    property string hata: ""
    signal closed

    property variant hazir: ({
        gmail: { imap: "imap.gmail.com", imapPort: 993, smtp: "smtp.gmail.com", smtpPort: 465 },
        yandex: { imap: "imap.yandex.com", imapPort: 993, smtp: "smtp.yandex.com", smtpPort: 465 },
        yahoo: { imap: "imap.mail.yahoo.com", imapPort: 993, smtp: "smtp.mail.yahoo.com", smtpPort: 465 },
        icloud: { imap: "imap.mail.me.com", imapPort: 993, smtp: "smtp.mail.me.com", smtpPort: 587 },
        diger: { imap: "", imapPort: 993, smtp: "", smtpPort: 465 }
    })

    function ac() {
        var h = mail.hesap();
        saglayici = h.preset && h.preset !== "" ? h.preset : "gmail";
        adres.text = h.user || "";
        sifre.text = "";
        ad.text = h.name || "";
        imapAlan.text = h.imap || "";
        imapPort.text = "" + (h.imapPort || 993);
        smtpAlan.text = h.smtp || "";
        smtpPort.text = "" + (h.smtpPort || 465);
        hata = "";
        deneniyor = false;
        visible = true;
        flick.contentY = 0;
        if (adres.text === "") adres.odakla();
    }
    function kapat() { mail.girisiTamamla(); visible = false; closed(); }
    function sec(k) {
        saglayici = k;
        if (k !== "diger") {
            var p = hazir[k];
            imapAlan.text = p.imap; imapPort.text = "" + p.imapPort; smtpAlan.text = p.smtp; smtpPort.text = "" + p.smtpPort;
        }
    }
    function kaydet() {
        if (deneniyor) return;
        mail.girisiTamamla();
        var p = saglayici === "diger" ? { imap: imapAlan.text, imapPort: parseInt(imapPort.text, 10) || 993, smtp: smtpAlan.text, smtpPort: parseInt(smtpPort.text, 10) || 465 } : hazir[saglayici];
        hata = "";
        deneniyor = true;
        mail.hesapDene({ preset: saglayici, user: adres.text.replace(/^\s+|\s+$/g, ""), pass: sifre.text, name: ad.text,
                         imap: p.imap, imapPort: p.imapPort, smtp: p.smtp, smtpPort: p.smtpPort });
    }

    Connections {
        target: mail
        onHesapSonuc: {
            page.deneniyor = false;
            if (!ok) { page.hata = mesaj; return; }
            app.toast(qsTr("Hesap kaydedildi"));
            page.kapat();
        }
    }

    MouseArea { anchors.fill: parent }
    Keys.onPressed: if (event.key === Qt.Key_Escape || (event.key === Qt.Key_Backspace && !sifre.input.activeFocus && !adres.input.activeFocus)) { if (mail.hesapVar) page.kapat(); event.accepted = true; }

    Rectangle {
        id: bar
        width: parent.width; height: 56; color: app.brand
        Btn { id: geri; flat: true; text: "✕"; fontSize: 22; visible: mail.hesapVar; anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter } onClicked: page.kapat() }
        Text { anchors { left: geri.visible ? geri.right : parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter } text: qsTr("Posta hesabı"); color: "#ffffff"; font.pixelSize: 22; font.bold: true }
        Rectangle {
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            width: kT.paintedWidth + 32; height: 42; radius: 21
            color: km.pressed ? "#f1f3f4" : "#ffffff"
            opacity: page.deneniyor ? 0.6 : 1
            Text { id: kT; anchors.centerIn: parent; text: page.deneniyor ? qsTr("Bağlanıyor…") : qsTr("Kaydet"); color: app.brand; font.pixelSize: 19; font.bold: true }
            MouseArea { id: km; anchors.fill: parent; onClicked: page.kaydet() }
        }
    }

    Flickable {
        id: flick
        anchors { top: bar.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentHeight: kolon.height + 30
        clip: true
        Column {
            id: kolon
            x: 18; y: 12
            width: flick.width - 36
            spacing: 12

            Text { width: parent.width; wrapMode: Text.Wrap; font.pixelSize: 16; color: app.textSecondary
                   text: qsTr("BelleMail posta kutunuza telefondan doğrudan, şifreli (TLS) bağlanır; arada sunucu yoktur. Bilgiler yalnızca bu telefonda saklanır.") }

            Flow {
                width: parent.width
                spacing: 8
                Repeater {
                    model: [{ k: "gmail", t: "Gmail" }, { k: "yandex", t: "Yandex" }, { k: "yahoo", t: "Yahoo" }, { k: "icloud", t: "iCloud" }, { k: "diger", t: qsTr("Diğer") }]
                    delegate: Btn { text: modelData.t; primary: page.saglayici === modelData.k; onClicked: page.sec(modelData.k) }
                }
            }

            Text {
                width: parent.width; wrapMode: Text.Wrap; font.pixelSize: 15; color: "#5f4b00"
                text: page.saglayici === "gmail" ? qsTr("Gmail: Google hesabınızda 2 adımlı doğrulama açık olmalı. Bilgisayardan myaccount.google.com → Güvenlik → \"Uygulama şifreleri\" bölümünden 16 harfli bir şifre oluşturup aşağıya yazın (normal şifreniz çalışmaz).")
                    : page.saglayici === "yandex" ? qsTr("Yandex: id.yandex.com → Güvenlik → Uygulama şifreleri (Posta) bölümünden şifre oluşturun; Yandex Posta ayarlarında IMAP erişimini açın.")
                    : page.saglayici === "yahoo" ? qsTr("Yahoo: Hesap güvenliği → \"Uygulama şifresi oluştur\" ile alınan şifreyi yazın.")
                    : page.saglayici === "icloud" ? qsTr("iCloud: appleid.apple.com → Oturum açma ve güvenlik → Uygulamaya özel parolalar.")
                    : qsTr("Kendi alan adınızın ya da başka bir sağlayıcının IMAP/SMTP bilgilerini girin (IMAP 993 TLS; SMTP 465 TLS ya da 587 STARTTLS). Outlook/Hotmail yalnızca OAuth kabul ettiği için şu an desteklenmiyor.")
            }

            Alan { id: adres; width: parent.width; etiket: qsTr("E-posta adresi"); ipucu: "ad@ornek.com"; inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText; onAccepted: sifre.odakla() }
            Alan { id: sifre; width: parent.width; etiket: qsTr("Uygulama şifresi"); ipucu: mail.hesapVar ? qsTr("(değiştirmeyecekseniz boş bırakın)") : ""; echoMode: TextInput.Password; inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText; onAccepted: ad.odakla() }
            Alan { id: ad; width: parent.width; etiket: qsTr("Görünen ad (giden postalarda)"); onAccepted: page.saglayici === "diger" ? imapAlan.odakla() : page.kaydet() }

            Row {
                width: parent.width; spacing: 10
                visible: page.saglayici === "diger"
                Alan { id: imapAlan; width: parent.width - 130; etiket: qsTr("IMAP sunucusu"); ipucu: "imap.ornek.com"; inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText }
                Alan { id: imapPort; width: 120; etiket: qsTr("Port"); inputMethodHints: Qt.ImhDigitsOnly }
            }
            Row {
                width: parent.width; spacing: 10
                visible: page.saglayici === "diger"
                Alan { id: smtpAlan; width: parent.width - 130; etiket: qsTr("SMTP sunucusu"); ipucu: "smtp.ornek.com"; inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText }
                Alan { id: smtpPort; width: 120; etiket: qsTr("Port"); inputMethodHints: Qt.ImhDigitsOnly }
            }

            Text { width: parent.width; wrapMode: Text.Wrap; visible: page.hata !== ""; text: page.hata; color: "#c5221f"; font.pixelSize: 17 }

            Row {
                spacing: 10
                Btn { text: page.deneniyor ? qsTr("Bağlanıyor…") : qsTr("Kaydet ve bağlan"); primary: true; onClicked: page.kaydet() }
                Btn { text: qsTr("Hesabı sil"); danger: true; visible: mail.hesapVar; onClicked: dialog.open(qsTr("Hesap silinsin mi?"), qsTr("Bu telefondaki posta hesabı bilgileri silinir; postalarınız sağlayıcıda kalır."), qsTr("Sil"), false, "hesapSil", true) }
            }
        }
    }
}
