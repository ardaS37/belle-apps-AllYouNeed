import QtQuick 1.1
import "Util.js" as U
import "IsDurum.js" as ID

// Yedekler: Nokia'nin kendi yedegi (Backup klasoru: telefon ayarlari, rehber, mesajlar...) Drive'a yuklenir ve
// Drive'dan yine ayni konuma indirilir (geri yuklemeyi Nokia Dosya yoneticisi yapar); rehber, SMS,
// uygulama ayarlari (aynalar), C:\Data. Hepsi kartta E:/BelleYedek altinda; Drive'da "Nokia E6 Yedek".
// Klavye: Yukari/Asagi • Enter sec • T tam yedek • U Drive'a yukle • G Nokia yedegini Drive'dan geri yukle • Sol/Sag sekme
Rectangle {
    id: root
    color: app.bg
    property variant oz: ({})
    property int kisi: -1
    property int sms: -1
    property string driveKok: qsTr("Nokia E6 Yedek")
    // Tum yedekler (BelleYedek: rehber, SMS, uygulama ayarlari, C:\Data kopyasi + Nokia'nin Backup klasoru) tek,
    // sikistirmasiz bir zip'e konur (Drive'a binlerce kucuk dosya yerine tek dosya: cok daha hizli).
    // Zip'te ogeler surucu harfiyle durur ("E/BelleYedek/...", "F/Backup/..."): acilinca her biri kendi yerine doner.
    property string zipAdi: qsTr("NokiaE6_Yedek.zip")

    function takeFocus() { list.forceActiveFocus(); }
    function uygYerel() { return yedek.kok + "/Uygulamalar"; }
    function zipYol() { return yedek.kok.substring(0, 2) + "/" + zipAdi; }      // kartin kokunde (BelleYedek'in disinda)
    function driveZipYol() { return driveKok + "/" + zipAdi; }
    function zipKaynaklar() { var y = [yedek.kok]; if (oz.sistemYol) y.push(oz.sistemYol); return y; }
    function reload() {
        oz = yedek.ozet();
        var keep = list.currentIndex;
        var ns = qsTr("Nokia yedeği (telefon ayarları, rehber, mesajlar…)");
        m.clear();
        m.append({ k: "tam", sec: qsTr("Hızlı"), icon: "backup", title: qsTr("Tam yedek al"), sub: qsTr("Rehber + SMS şimdi yedeklenir; uygulama ayarları zaten kartta güncel (T)"), dosya: "" });
        m.append({ k: "drive", sec: qsTr("Hızlı"), icon: "drive", title: qsTr("Tümünü zip'le ve Drive'a yükle"),
                   sub: qsTr("BelleYedek (") + (oz.toplamBoyut || "-") + ")" + (oz.sistemYol ? qsTr(" + Nokia yedeği (") + oz.sistemBoyut + ")" : "") + qsTr(" → tek sıkıştırmasız zip → Drive: ") + driveZipYol() + " (U)", dosya: "" });
        m.append({ k: "geri", sec: qsTr("Hızlı"), icon: "import", title: qsTr("Drive'dan indir, aç ve yerlerine koy"),
                   sub: qsTr("Zip iner, açılır: ") + yedek.kok + (oz.sistemYol ? ", " + oz.sistemYol : qsTr(", Backup")) + qsTr(" eski yerlerine döner (G)"), dosya: "" });
        if (drive.fileExists(zipYol()))
            m.append({ k: "zip", sec: qsTr("Hızlı"), icon: "doc", title: qsTr("Karttaki son zip • ") + U.sizeText(drive.fileSize(zipYol())), sub: zipYol() + qsTr(" • dokunun: aç / yerlerine koy / sil"), dosya: "" });
        m.append({ k: "nokia", sec: ns, icon: "gear", title: qsTr("Nokia yedeği") + (oz.sistemYol ? " • " + oz.sistemBoyut : qsTr(" bulunamadı")),
                   sub: oz.sistemYol ? oz.sistemYol + " • " + oz.sistemAdet + qsTr(" dosya") + (oz.sistemTarih ? " • " + oz.sistemTarih : "") + qsTr(" • zip'e dahil")
                                     : qsTr("E:, F: köklerinde Backup klasörü yok: dokunun, nasıl alınır"), dosya: "" });
        m.append({ k: "rehber", sec: qsTr("Neler yedekleniyor"), icon: "doc", title: qsTr("Rehber") + (kisi >= 0 ? " • " + kisi + qsTr(" kişi") : ""), sub: oz.rehberSon ? qsTr("Son yedek ") + oz.rehberSon + " • " + oz.rehberAdet + qsTr(" dosya") : qsTr("Henüz yedek yok"), dosya: "" });
        m.append({ k: "sms", sec: qsTr("Neler yedekleniyor"), icon: "doc", title: "SMS" + (sms >= 0 ? " • " + sms + qsTr(" mesaj") : ""), sub: oz.smsSon ? qsTr("Son yedek ") + oz.smsSon + " • " + oz.smsAdet + qsTr(" dosya") : qsTr("Henüz yedek yok"), dosya: "" });
        m.append({ k: "uyg", sec: qsTr("Neler yedekleniyor"), icon: "folder", title: qsTr("Uygulama ayarları • ") + oz.uygulamaAdet + qsTr(" uygulama"), sub: qsTr("Uygulamalar ayarlarını kendileri karta kopyalar; ROM sonrası otomatik geri gelir"), dosya: "" });
        m.append({ k: "cdata", sec: qsTr("Neler yedekleniyor"), icon: "copy", title: qsTr("Telefon hafızası (C:\\Data) • ") + (oz.cDataBoyut || "-"), sub: qsTr("Resim, ses, belge ve uygulama dosyaları karta kopyalanır (") + yedek.kok + "/Data)", dosya: "" });
        var r = yedek.dosyalar(qsTr("Rehber"));
        for (var i = 0; i < r.length; i++) m.append({ k: "dosya", sec: qsTr("Rehber yedekleri"), icon: "doc", title: r[i].tarih + " • " + r[i].adet + qsTr(" kişi"), sub: r[i].ad + " • " + r[i].boyut, dosya: r[i].dosya });
        var s = yedek.dosyalar("SMS");
        for (i = 0; i < s.length; i++) m.append({ k: "dosya", sec: qsTr("SMS yedekleri"), icon: "doc", title: s[i].tarih + " • " + s[i].adet + qsTr(" mesaj"), sub: s[i].ad + " • " + s[i].boyut, dosya: s[i].dosya });
        list.currentIndex = Math.max(0, Math.min(keep, m.count - 1));
    }
    function sayilariOku() { kisi = yedek.rehberKisi(); sms = yedek.smsSayisi(); reload(); }
    onVisibleChanged: if (visible) { reload(); sayTimer.restart(); }
    Timer { id: sayTimer; interval: 150; onTriggered: root.sayilariOku() }

    function cur() { return list.currentIndex >= 0 && list.currentIndex < m.count ? m.get(list.currentIndex) : null; }
    function smsMi(d) { return d.indexOf(".xml") > 0; }

    // Tum yedekler -> tek sikistirmasiz zip -> Drive (tek dosya)
    function driveYukle() {
        if (!app.driveHazirMi()) return;
        if (drive.isAktif || drive.busy) { app.showToast(qsTr("Drive'da başka bir aktarım sürüyor")); isPanel.goster(); return; }
        paketle(function () { app.driveIsBaslat([zipYol()], driveKok, false, false, qsTr("Yedek zip'i Drive'a yükleniyor")); });
    }
    // BelleYedek + Nokia Backup klasorunu sikistirmasiz tek zip yapar, bitince sonra() cagrilir
    function paketle(sonra) {
        if (isci.calisiyor) { app.showToast(qsTr("Başka bir dosya işi sürüyor")); return; }
        ID.sonra = function (ok, sonuc) { root.reload(); if (ok) sonra(); else bilgi(qsTr("Zip yapılamadı"), isci.hata()); };
        if (!isci.baslat("zipsurucu", zipKaynaklar(), zipYol())) { ID.sonra = null; app.showToast(qsTr("Paketleme başlatılamadı")); return; }
        isPanel.ac(qsTr("Yedekler paketleniyor (sıkıştırmasız) → ") + zipYol());
    }
    function nokiaNasil() {
        var t = oz.sistemTum || [];
        bilgi(qsTr("Nokia yedeği"),
              qsTr("Nokia'nın kendi yedeği telefon ayarlarını, rehberi, mesajları, takvimi ve uygulama verilerini birlikte alır; bunları başka hiçbir uygulama okuyamaz.\n\n") +
              qsTr("Yedek almak:\n1. Menü > Dosya yöneticisi\n2. Seçenekler > Telefon hafızasını yedekle\n3. Yedek seçtiğiniz sürücünün kökündeki Backup klasörüne yazılır (E: telefon hafızası ya da F: hafıza kartı).\n\n") +
              qsTr("Sonra burada \"Tümünü zip'le ve Drive'a yükle\" deyin: Nokia yedeği de zip'e girer.\n\n") +
              qsTr("Geri yüklemek (ROM sonrası, yeni kart…):\n1. \"Drive'dan indir, aç ve yerlerine koy\" ile Backup klasörü eski yerine döner.\n") +
              qsTr("2. Dosya yöneticisi > Seçenekler > Geri yükle.\n\n") +
              (oz.sistemYol ? qsTr("Bulunan yedek: ") + oz.sistemYol + " (" + oz.sistemAdet + qsTr(" dosya, ") + oz.sistemBoyut + ", " + oz.sistemTarih + ")" +
                              (t.length > 1 ? qsTr("\nDiğerleri: ") + t.join(", ") : "")
                            : qsTr("E: ve F: kökünde dosya içeren bir Backup klasörü bulunamadı. Yedeği Dosyalar sekmesinde bulursanız yerini bildirin.")));
    }
    // Drive'daki zip'i indirir, acar, her parcayi eski yerine koyar
    function geriSor() {
        sheet.open(qsTr("Drive'daki yedek zip'i indirilip yerlerine açılsın mı?"), [
            { label: qsTr("Evet: indir, aç, yerlerine koy (aynı adlı dosyaların üzerine yazılır)"), icon: "check", key: "y" },
            { label: qsTr("Vazgeç"), icon: "close", key: "n" }
        ], function (k) {
            if (k !== "y") return;
            if (!app.driveHazirMi()) return;
            if (drive.isAktif || drive.busy) { app.showToast(qsTr("Drive'da başka bir aktarım sürüyor")); isPanel.goster(); return; }
            app.driveIsSessiz = false;
            ID.driveSonra = function (ok, mesaj) {
                if (!ok) { root.reload(); bilgi(qsTr("İndirilemedi"), mesaj); return; }
                zipAcKoy();
            };
            if (!drive.dosyaIndir(driveZipYol(), zipYol())) { ID.driveSonra = null; app.showToast(qsTr("Drive işi başlatılamadı")); return; }
            drivePage.harici = true;
            isPanel.ac(qsTr("Yedek zip'i Drive'dan indiriliyor → ") + zipYol());
        });
    }
    function zipAcKoy() {
        if (!drive.fileExists(zipYol())) { bilgi(qsTr("Zip bulunamadı"), zipYol() + qsTr(" yok.")); return; }
        if (isci.calisiyor) { app.showToast(qsTr("Başka bir dosya işi sürüyor")); return; }
        ID.sonra = function (ok, sonuc) {
            root.reload();
            if (!ok) { bilgi(qsTr("Zip açılamadı"), isci.hata()); return; }
            bilgi(qsTr("Yedekler yerlerine kondu"), qsTr("Rehber, SMS, uygulama ayarları ve Nokia yedeği (Backup) eski yerlerine açıldı.\n\n") +
                  qsTr("Nokia yedeğini telefona geri yüklemek için:\nMenü > Dosya yöneticisi > Seçenekler > Geri yükle.\n\n") +
                  qsTr("Uygulama ayarları: uygulamaları (yeniden kurulduysa) açtığınızda kendiliğinden geri gelir.\nRehber / SMS: aşağıdaki yedek dosyalarından \"Geri yükle\"."));
        };
        if (!isci.baslat("zipacsurucu", [zipYol()], yedek.kok.substring(0, 2))) { ID.sonra = null; app.showToast(qsTr("Zip açma başlatılamadı")); return; }
        isPanel.ac(qsTr("Yedekler açılıp yerlerine konuyor"));
    }
    function zipMenu() {
        sheet.open(zipAdi + " • " + U.sizeText(drive.fileSize(zipYol())), [
            { label: qsTr("Yerlerine aç (Drive'dan indirmeden)"), icon: "import", key: "a" },
            { label: qsTr("Drive'a yükle (yeniden paketlemeden)"), icon: "drive", key: "d" },
            { label: qsTr("Sil (yer açar; Drive'daki kalır)"), icon: "trash", key: "s", danger: true }
        ], function (k) {
            if (k === "a") zipAcKoy();
            else if (k === "d") app.driveIsBaslat([zipYol()], driveKok, false, false, qsTr("Yedek zip'i Drive'a yükleniyor"));
            else if (k === "s") sheet.open(qsTr("Karttaki zip silinsin mi? (Drive'daki kopya kalır)"), [
                    { label: qsTr("Evet, sil"), icon: "trash", key: "y", danger: true },
                    { label: qsTr("Vazgeç"), icon: "close", key: "n" }
                ], function (k2) {
                    if (k2 !== "y") return;
                    ID.sonra = function () { root.reload(); };
                    if (!isci.baslat("sil", [zipYol()], "")) { ID.sonra = null; app.showToast(qsTr("Başka bir dosya işi sürüyor")); }
                });
        });
    }
    function sec(it) {
        if (!it) return;
        if (yedek.calisiyor && (it.k === "tam" || it.k === "rehber" || it.k === "sms" || it.k === "dosya")) { app.showToast(yedek.durum); return; }
        if (it.k === "tam") yedek.tamYedek();
        else if (it.k === "drive") driveYukle();
        else if (it.k === "nokia") nokiaNasil();
        else if (it.k === "geri") geriSor();
        else if (it.k === "zip") zipMenu();
        else if (it.k === "rehber") sheet.open(qsTr("Rehber"), [
                { label: qsTr("Şimdi yedekle"), icon: "backup", key: "y" },
                { label: qsTr("Yedek klasörünü aç"), icon: "folder", key: "a" }
            ], function (k) { if (k === "y") yedek.rehberYedekle(); else app.showFolder(yedek.kok + "/Rehber"); });
        else if (it.k === "sms") sheet.open("SMS", [
                { label: qsTr("Şimdi yedekle"), icon: "backup", key: "y" },
                { label: qsTr("Yedek klasörünü aç"), icon: "folder", key: "a" }
            ], function (k) { if (k === "y") yedek.smsYedekle(); else app.showFolder(yedek.kok + "/SMS"); });
        else if (it.k === "uyg") uygGoster();
        else if (it.k === "cdata") sheet.open(qsTr("C:\\Data → kart (") + (oz.cDataBoyut || "") + ")", [
                { label: qsTr("Karta kopyala"), icon: "copy", key: "y" },
                { label: qsTr("Vazgeç"), icon: "close", key: "n" }
            ], function (k) { if (k === "y") { if (isci.baslat("kopyala", ["C:/Data"], yedek.kok)) isPanel.ac(qsTr("C:\\Data karta kopyalanıyor")); else app.showToast(qsTr("Başka bir dosya işi sürüyor")); } });
        else if (it.k === "dosya") dosyaMenu(it.dosya);
    }
    function dosyaMenu(d) {
        var sm = smsMi(d);
        sheet.open(fs.fileName(d), [
            { label: qsTr("İçine bak"), icon: "eye", key: "o" },
            { label: qsTr("Geri yükle"), icon: "import", key: "g" },
            { label: qsTr("Drive'a yükle"), icon: "drive", key: "d" },
            { label: qsTr("Sil"), icon: "trash", key: "s", danger: true }
        ], function (k) {
            if (k === "o") bilgi(fs.fileName(d), yedek.onizle(d, 14));
            else if (k === "d") app.driveIsBaslat([d], driveKok + "/" + (sm ? "SMS" : qsTr("Rehber")), false, false, qsTr("Drive'a yükleniyor"));
            else if (k === "g") sheet.open(sm ? qsTr("SMS'ler geri yüklensin mi?") : qsTr("Kişiler geri yüklensin mi?"), [
                    { label: sm ? qsTr("Evet: telefonda olmayan mesajları ekle") : qsTr("Evet: rehberde olmayan kişileri ekle"), icon: "check", key: "y" },
                    { label: qsTr("Vazgeç"), icon: "close", key: "n" }
                ], function (k2) { if (k2 === "y") { if (sm) yedek.smsGeriYukle(d); else yedek.rehberGeriYukle(d); } });
            else if (k === "s") sheet.open(qsTr("Yedek silinsin mi? (geri alınamaz)"), [
                    { label: qsTr("Evet, sil"), icon: "trash", key: "y", danger: true },
                    { label: qsTr("Vazgeç"), icon: "close", key: "n" }
                ], function (k2) { if (k2 === "y") { if (yedek.sil(d)) app.showToast(qsTr("Silindi")); root.reload(); } });
        });
    }
    function uygGoster() {
        var l = yedek.uygulamalar(), t = "";
        for (var i = 0; i < l.length; i++) t += l[i].ad + "\n    " + l[i].tarih + " • " + l[i].adet + qsTr(" dosya • ") + l[i].boyut + "\n";
        bilgi(qsTr("Uygulama ayarları (") + l.length + ")", (t || qsTr("Henüz hiçbir uygulama ayarlarını karta kopyalamadı.\n")) +
              qsTr("\nKonum: ") + uygYerel() + qsTr("\n\nUygulamalar (WhatsBelle, ApiLauncher, Belle Browser, BelleTube…) açılırken, arka plana geçerken ve kapanırken kendi ayarlarını buraya kopyalar. ") +
              qsTr("Telefon sıfırlanır ya da ROM yüklenirse uygulamayı yeniden kurup açmanız yeterli: ayarlar karttan kendiliğinden geri gelir."));
    }
    function bilgi(t, metin) { bilgiBaslik.text = t; bilgiMetin.text = metin; bilgiKutu.visible = true; bilgiFlick.contentY = 0; bilgiFlick.forceActiveFocus(); }

    Connections {
        target: yedek
        onBitti: { root.sayilariOku(); bilgi(ok ? qsTr("Tamamlandı") : qsTr("Sorun var"), mesaj); }
    }
    Connections { target: isci; onBitti: if (root.visible) root.reload() }
    Connections { target: drive; onIsBitti: if (root.visible) root.reload() }

    ListModel { id: m }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: qsTr("Yedekler")
        subtitle: yedek.calisiyor ? yedek.durum : yedek.kok
        IconButton { icon: "backup"; tone: "w"; iconSize: 24; onClicked: root.sec({ k: "tam" }) }
        IconButton { icon: "drive"; tone: "w"; iconSize: 24; onClicked: root.driveYukle() }
    }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        clip: true
        model: m
        focus: true
        section.property: "sec"
        section.delegate: Rectangle {
            width: list.width; height: 30; color: app.bg
            Text { anchors { left: parent.left; leftMargin: 14; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter } text: section; color: app.brand; font.pixelSize: 15; font.bold: true; elide: Text.ElideRight }
        }
        delegate: FileRow {
            width: list.width
            icon: model.icon
            title: model.title
            sub: model.sub
            selected: ListView.isCurrentItem && list.activeFocus
            onClicked: { list.currentIndex = index; root.sec(m.get(index)); }
            onPressAndHold: { list.currentIndex = index; root.sec(m.get(index)); }
            onAction: { list.currentIndex = index; root.sec(m.get(index)); }
        }
        Keys.onPressed: {
            var k = event.key, t = U.tus(event);
            if (U.ctrl(event) && (k === Qt.Key_Q || t === "q")) { app.quit(); event.accepted = true; }
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select || k === Qt.Key_Space || k === Qt.Key_Menu || k === Qt.Key_Context1) { root.sec(root.cur()); event.accepted = true; }
            else if (k === Qt.Key_Left) { app.stepTab(-1); event.accepted = true; }
            else if (k === Qt.Key_Right) { app.stepTab(1); event.accepted = true; }
            else if (t === "t") { root.sec({ k: "tam" }); event.accepted = true; }
            else if (t === "u") { root.driveYukle(); event.accepted = true; }
            else if (t === "g") { root.geriSor(); event.accepted = true; }
            else if (t === "h" || t === "?") { help.open(); event.accepted = true; }
        }
    }

    // ---- Bilgi / sonuc penceresi ----
    Rectangle {
        id: bilgiKutu
        anchors.fill: parent
        color: "#C0000000"; visible: false; z: 30
        onVisibleChanged: if (!visible) list.forceActiveFocus()
        MouseArea { anchors.fill: parent; onClicked: bilgiKutu.visible = false }
        Rectangle {
            anchors { fill: parent; margins: 24 }
            radius: 14; color: app.surface
            MouseArea { anchors.fill: parent; onClicked: bilgiKutu.visible = false }
            Text { id: bilgiBaslik; x: 18; y: 14; width: parent.width - 36; color: app.textPrimary; font.pixelSize: 20; font.bold: true; elide: Text.ElideRight }
            Flickable {
                id: bilgiFlick
                anchors { left: parent.left; right: parent.right; top: bilgiBaslik.bottom; bottom: tamamText.top; margins: 18 }
                clip: true
                contentHeight: bilgiMetin.paintedHeight + 10
                Text { id: bilgiMetin; width: bilgiFlick.width; wrapMode: Text.Wrap; color: app.textPrimary; font.pixelSize: 16 }
                Keys.onPressed: {
                    if (event.key === Qt.Key_Down) { contentY = Math.min(Math.max(0, contentHeight - height), contentY + 60); event.accepted = true; }
                    else if (event.key === Qt.Key_Up) { contentY = Math.max(0, contentY - 60); event.accepted = true; }
                    else { bilgiKutu.visible = false; event.accepted = true; }
                }
            }
            Text { id: tamamText; anchors { right: parent.right; bottom: parent.bottom; margins: 16 } text: qsTr("Tamam"); color: app.brand; font.pixelSize: 17; font.bold: true }
        }
    }
}
