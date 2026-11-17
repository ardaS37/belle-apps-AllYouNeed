import QtQuick 1.1

// Klavye kisayollari. Yukari/Asagi kaydirir, Esc / Geri / Enter kapatir.
Rectangle {
    id: root
    property bool shown: false
    anchors.fill: parent
    color: app.bg
    visible: shown

    function open() { shown = true; flick.contentY = 0; flick.forceActiveFocus(); }
    function close() { shown = false; app.focusCurrent(); }
    function takeFocus() { flick.forceActiveFocus(); }

    property string body:
        qsTr("<h3>Listeler (Notlar, Dosyalar)</h3>") +
        qsTr("<b>Enter</b> aç &nbsp; <b>Geri/Esc</b> üst klasör &nbsp; <b>Boşluk</b> veya <b>sol yazılım tuşu</b> seçenekler<br>") +
        qsTr("<b>Sol/Sağ</b> sekme değiştir &nbsp; <b>J / Z</b> 8 satır aşağı / yukarı<br>") +
        qsTr("<b>N</b> yeni dosya (şablonlar) &nbsp; <b>K</b> yeni klasör &nbsp; <b>P</b> panodaki yazıdan yeni not<br>") +
        qsTr("<b>C</b> kopyala &nbsp; <b>X</b> kes &nbsp; <b>V</b> yapıştır (hedef klasörde)<br>") +
        qsTr("<b>M</b> işaretle (çoklu seçim) &nbsp; <b>A</b> tümünü işaretle / kaldır &nbsp; uzun bas: işaretle<br>") +
        qsTr("<b>R</b> yeniden adlandır &nbsp; <b>D</b> sil &nbsp; <b>U</b> uzantı değiştir / dönüştür<br>") +
        qsTr("<b>Y</b> dosyanın yazısını panoya &nbsp; <b>W</b> salt okunur görüntüle &nbsp; <b>G</b> metin olarak aç<br>") +
        qsTr("<b>O</b> sistemde aç (html → tarayıcı, vcf → rehber, vcs → takvim, m3u → müzik)<br>") +
        qsTr("<b>E</b> dışa aktar &nbsp; <b>I</b> içe aktar &nbsp; <b>F</b> favori &nbsp; <b>L</b> bilgi<br>") +
        qsTr("<b>B</b> dosyalarda ara (ad + içerik) &nbsp; <b>/</b> adla süz &nbsp; <b>S</b> sıralama &nbsp; <b>T</b> tüm dosyalar<br>") +
        qsTr("<b>H</b> bu yardım &nbsp; <b>Ctrl+Q</b> çıkış") +
        qsTr("<h3>Düzenleyici</h3>") +
        qsTr("<b>Orta tuş</b> / <b>sol yazılım tuşu</b> menü &nbsp; <b>Esc</b> / <b>sağ yazılım tuşu</b> kapat<br>") +
        qsTr("<b>Ctrl+S</b> kaydet &nbsp; <b>Ctrl+Shift+S</b> farklı kaydet<br>") +
        qsTr("<b>Ctrl+F</b> bul &nbsp; <b>Ctrl+N</b> sonrakini bul &nbsp; <b>Ctrl+H</b> bul-değiştir &nbsp; <b>Ctrl+G</b> satıra git<br>") +
        qsTr("<b>Ctrl+Z</b> geri al &nbsp; <b>Ctrl+Y</b> yinele &nbsp; <b>Ctrl+A</b> tümünü seç<br>") +
        qsTr("<b>Ctrl+C / X / V</b> kopyala / kes / yapıştır &nbsp; <b>Ctrl+B</b> tüm yazıyı panoya<br>") +
        qsTr("<b>Shift + yön tuşları</b> seçim &nbsp; <b>Ctrl+Yukarı/Aşağı</b> başa / sona<br>") +
        qsTr("<b>Ctrl+D</b> satırı çoğalt &nbsp; <b>Ctrl+K</b> satırı sil &nbsp; <b>Ctrl+T</b> tarih-saat<br>") +
        qsTr("<b>Ctrl+J</b> yapılacak işareti [ ] / [x] &nbsp; <b>Ctrl+U</b> BÜYÜK harf (<b>Ctrl+Shift+U</b> küçük)<br>") +
        qsTr("<b>Ctrl+E</b> uzantı / dönüştür &nbsp; <b>Ctrl+P</b> sistemde aç / önizle<br>") +
        qsTr("<b>Ctrl+R</b> salt okunur &nbsp; <b>Ctrl+W</b> satır kaydırma &nbsp; <b>Ctrl+ +/-</b> yazı boyutu &nbsp; <b>Ctrl+L</b> istatistik") +
        qsTr("<h3>Salt okunur / büyük dosya</h3>") +
        qsTr("<b>Boşluk/J</b> sayfa aşağı &nbsp; <b>Z/K</b> sayfa yukarı &nbsp; <b>N/P</b> sonraki / önceki parça &nbsp; <b>E</b> düzenlemeye aç") +
        qsTr("<h3>Uzantı değiştirme</h3>") +
        qsTr("<b>.html</b>: # başlık, - madde, boş satır paragraf, adresler bağlantı olur.<br>") +
        qsTr("<b>.vcf</b>: her satıra bir kişi (\"Ali Veli 0555 111 22 33\") ya da Ad:/Tel:/E-posta: blokları.<br>") +
        qsTr("<b>.vcs</b>: \"12.11.2026 14:30 Toplantı\" ya da \"2026-11-12 09:00-10:30 Doktor\".<br>") +
        qsTr("<b>.m3u</b>: her satıra bir dosya yolu ya da adres.<br>") +
        qsTr("<b>.csv / .json / .xml / .srt</b>: satırlar tabloya / nesneye / öğelere dönüşür.<br>") +
        qsTr("<b>.txt</b>: HTML etiketleri temizlenir, JSON / CSV / vCard okunur hale gelir.") +
        qsTr("<h3>Dışa / içe aktarma</h3>") +
        qsTr("Paket .txt birçok dosyayı tek dosyada taşır; aynı paketi <b>I</b> ya da dosya menüsünden geri açabilirsiniz.<br>") +
        qsTr("Dışa aktarılanlar ve yedekler hafıza kartında BelleFiles klasöründedir.")

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: qsTr("Kısayollar")
        showBack: true
        onBack: root.close()
    }
    Flickable {
        id: flick
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom; leftMargin: 14; rightMargin: 14 }
        clip: true
        contentHeight: txt.paintedHeight + 30
        Text {
            id: txt
            width: flick.width
            wrapMode: Text.Wrap
            textFormat: Text.RichText
            color: app.textPrimary
            font.pixelSize: 16
            text: "<style>h3{color:" + app.brand + ";}</style>" + root.body
        }
        Keys.onPressed: {
            var k = event.key;
            if (k === Qt.Key_Down) { contentY = Math.min(Math.max(0, contentHeight - height), contentY + 60); event.accepted = true; }
            else if (k === Qt.Key_Up) { contentY = Math.max(0, contentY - 60); event.accepted = true; }
            else if (k === Qt.Key_Right || k === Qt.Key_Space) { contentY = Math.min(Math.max(0, contentHeight - height), contentY + height - 40); event.accepted = true; }
            else if (k === Qt.Key_Left) { contentY = Math.max(0, contentY - height + 40); event.accepted = true; }
            else if (k === Qt.Key_Escape || k === Qt.Key_Backspace || k === Qt.Key_Context2 || k === Qt.Key_Return
                     || k === Qt.Key_Enter || k === Qt.Key_Select || event.text === "h" || event.text === "H") { root.close(); event.accepted = true; }
        }
    }
}
