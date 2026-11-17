import QtQuick 1.1

// BelleWidgets (eski BelleWidgets). Ana ekranda tam genislikte kartlar: Hava, Pil, Sistem, Ana ekran widget'i.
// Karta dokununca / Enter: tam ekran ayrinti (hava: saatlik + 7 gunluk). Ayarlar ayri menude (Ayarlar dugmesi / S / Menu tusu).
// Klavye: Yukari/Asagi kart, Enter ac, Esc geri (ana sayfada: arka plana al), R yenile, S ayarlar, Ctrl+Q kapat.
Rectangle {
    id: app
    width: 640
    height: 480
    color: "#101418"

    property color surface: "#1A2026"
    property color surface2: "#222A32"
    property color textPrimary: "#ECEFF1"
    property color textSecondary: "#8C98A4"
    property color divider: "#252D35"
    property color highlight: "#26303A"
    property color accent: "#5BC0EB"
    property string page: "main"       // main | hava | pil | sistem | widget | ayarlar
    property int sel: 0                // ana sayfada secili kart

    function levelColor(l, s) {
        if (s === 2) return "#5BC0EB";
        if (l <= 15) return "#F15C6D";
        if (l <= 40) return "#FFB300";
        return "#4CD787";
    }
    function loadColor(p) { return p >= 85 ? "#F15C6D" : (p >= 60 ? "#FFB300" : "#5BC0EB"); }
    function deg(v) { return Math.round(v) + "°"; }

    // ---- Gecmis (son 24 saat, 96 dilim = 15 dk) ----
    ListModel { id: hist }
    function loadHistory() {
        var h = pil.history(24);
        var now = Math.floor(new Date().getTime() / 1000);
        var slots = [];
        for (var i = 0; i < 96; i++) slots.push({ level: -1, charging: false });
        for (var j = 0; j < h.length; j++) {
            var k = 95 - Math.floor((now - h[j].t) / 900);
            if (k >= 0 && k < 96) slots[k] = { level: h[j].level, charging: h[j].charging };
        }
        var last = -1, lastC = false;
        hist.clear();
        for (i = 0; i < 96; i++) {
            if (slots[i].level >= 0) { last = slots[i].level; lastC = slots[i].charging; }
            hist.append({ level: last, charging: lastC });
        }
    }
    Connections { target: pil; onHistoryVersionChanged: app.loadHistory() }

    // ---- Ayarlar (ayri menu) ----
    ListModel { id: rows }
    function buildRows() {
        var keep = setList.currentIndex;
        rows.clear();
        rows.append({ k: "city", label: qsTr("Şehir (hava durumu)"), value: pil.city === "" ? qsTr("Seçin") : pil.city });
        rows.append({ k: "style", label: qsTr("Ana ekran görünümü"), value: pil.style === "wide" ? qsTr("Geniş (çizim)") : qsTr("Yüzde + 2 satır") });
        rows.append({ k: "full", label: qsTr("Tam dolunca titreşim"), value: pil.fullAlert ? qsTr("Açık") : qsTr("Kapalı") });
        rows.append({ k: "low", label: qsTr("Düşük pil uyarısı"), value: pil.lowAlert > 0 ? "%" + pil.lowAlert : qsTr("Kapalı") });
        rows.append({ k: "retry", label: qsTr("Widget'ı yeniden dene"), value: "" });
        rows.append({ k: "lang", label: "Dil / Language", value: (dil.secim === "auto" ? dil.kod : dil.secim) === "en" ? "English" : "Türkçe" });
        rows.append({ k: "how", label: qsTr("Ana ekrana nasıl eklenir?"), value: "" });
        rows.append({ k: "log", label: qsTr("Günlük"), value: "" });
        rows.append({ k: "bg", label: qsTr("Arka plana al"), value: qsTr("Esc") });
        rows.append({ k: "quit", label: qsTr("Kapat (widget durur)"), value: qsTr("Ctrl+Q") });
        setList.currentIndex = Math.max(0, Math.min(keep, rows.count - 1));
    }
    Connections { target: pil; onSettingsChanged: app.buildRows(); onWidgetChanged: app.buildRows(); onWeatherChanged: app.buildRows() }

    function change(i, d) {
        var k = rows.get(i).k;
        if (k === "style") pil.setStyle(pil.style === "wide" ? "rows" : "wide");
        else if (k === "full") pil.setFullAlert(!pil.fullAlert);
        else if (k === "low") {
            var steps = [0, 5, 10, 15, 20, 30], at = steps.indexOf(pil.lowAlert);
            if (at < 0) at = 3;
            pil.setLowAlert(steps[(at + (d < 0 ? -1 : 1) + steps.length) % steps.length]);
        }
    }
    function activate(i) {
        var k = rows.get(i).k;
        if (k === "style" || k === "full" || k === "low") change(i, 1);
        else if (k === "lang") { app.dilDegistir(); app.buildRows(); }
        else if (k === "city") askCity();
        else if (k === "retry") { pil.retryWidget(); toast(pil.widgetStatus); }
        else if (k === "how") showInfo(qsTr("Ana ekrana ekleme"),
            qsTr("1. Ana ekranda boş bir yere uzun basın (ya da Seçenekler > İçerik ekle).\n") +
            qsTr("2. \"İçerik ekle\"yi seçin, listede \"BelleWidgets\"i bulun.\n") +
            qsTr("3. Widget'a dokununca bu uygulama açılır ve veriler yenilenir.\n\n") +
            qsTr("İki widget var: \"BelleWidgets\" (solda büyük yüzde; 1. satır pil süresi ve RAM/CPU, 2. satır hava) ve \"BelleWidgets genis\" (hepsi tek çizimde). ") +
            qsTr("Eskiden eklediğiniz BelleWidgets widget'ları yerinde kalır.\n\n") +
            qsTr("Pil 5 dakikada bir okunur. RAM/CPU yalnızca ana ekran görünürken dakikada bir ölçülür. Hava durumu saatte bir ve yalnızca ") +
            qsTr("telefonda açık bir internet bağlantısı varsa güncellenir (bağlantı kurdurmaz). Kaynak: Open-Meteo.\n\n") +
            qsTr("Durum: ") + pil.widgetStatus);
        else if (k === "log") showInfo(qsTr("Günlük"), pil.logText());
        else if (k === "bg") ui.hide();
        else if (k === "quit") pil.quitApp();
    }
    function showInfo(t, body) { infoTitle.text = t; infoBody.text = body; info.visible = true; infoFlick.contentY = 0; infoFlick.forceActiveFocus(); }
    // Dil / Language: Turkce <-> English (tum uygulamalarda ortak, yeniden acinca gecerli)
    function dilDegistir() {
        var k = dil.secim === "auto" ? dil.kod : dil.secim;
        dil.sec(k === "en" ? "tr" : "en");
        app.toast(dil.yenidenBaslat ? "Dil değişti; uygulamayı yeniden açın. / Language changed; restart the app." : "Dil / Language: " + (k === "en" ? "Türkçe" : "English"));
    }
    function toast(m) { toastText.text = m; toastBox.opacity = 1; toastTimer.restart(); }
    function askCity() { cityInput.text = pil.city; cityBox.visible = true; cityInput.forceActiveFocus(); cityInput.selectAll(); }
    function acceptCity() { cityBox.visible = false; keys.forceActiveFocus(); if (cityInput.text.length > 0) pil.setCity(cityInput.text); }
    function refresh() { pil.refreshAll(); toast(pil.city !== "" ? qsTr("Yenileniyor • şehir yeniden aranıyor") : qsTr("Pil ve RAM/CPU yenilendi")); }
    function weatherRefresh() { pil.refreshWeather(); toast(qsTr("Şehir yeniden aranıyor, hava güncelleniyor")); }

    property variant cards: ["hava", "pil", "sistem", "widget"]
    function open(p) { page = p; if (p === "ayarlar") { buildRows(); setList.forceActiveFocus(); } else keys.forceActiveFocus(); detailFlick.contentY = 0; }
    function back() { if (page === "main") ui.hide(); else { page = "main"; keys.forceActiveFocus(); } }

    Component.onCompleted: { buildRows(); loadHistory(); keys.forceActiveFocus(); }

    // ---- Hava simgesi (kod -> basit cizim) ----
    Component {
        id: wIconComp
        Item {
            property int code: -1
            property real s: 40
            width: s; height: s
            property bool sun: code === 0 || code === 1 || code === 2
            property bool cloud: code >= 2
            property bool rain: (code >= 51 && code <= 67) || (code >= 80 && code <= 82) || code >= 95
            property bool snow: (code >= 71 && code <= 77) || code === 85 || code === 86
            property bool storm: code >= 95
            Rectangle { visible: sun; x: cloud ? s * 0.46 : s * 0.18; y: cloud ? s * 0.02 : s * 0.18; width: s * (cloud ? 0.46 : 0.64); height: width; radius: width / 2; color: "#FFC93C" }
            Rectangle { visible: cloud; x: s * 0.12; y: s * 0.32; width: s * 0.78; height: s * 0.38; radius: height / 2; color: code === 3 || rain || snow ? "#9AA6B2" : "#DDE3E8" }
            Rectangle { visible: cloud; x: s * 0.3; y: s * 0.18; width: s * 0.4; height: s * 0.4; radius: width / 2; color: code === 3 || rain || snow ? "#9AA6B2" : "#DDE3E8" }
            Row {
                visible: rain || snow
                x: s * 0.24; y: s * 0.74; spacing: s * 0.12
                Repeater { model: 3; Rectangle { width: s * 0.08; height: snow ? s * 0.08 : s * 0.18; radius: width / 2; color: snow ? "#FFFFFF" : "#5BC0EB" } }
            }
            Rectangle { visible: storm; x: s * 0.44; y: s * 0.6; width: s * 0.1; height: s * 0.36; rotation: 20; color: "#FFC93C" }
            Rectangle { visible: code < 0; anchors.centerIn: parent; width: s * 0.5; height: width; radius: width / 2; color: "#33FFFFFF" }
        }
    }

    // ---- Ust cubuk ----
    Rectangle {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 46
        color: app.surface
        z: 5
        Rectangle {
            id: backBtn
            visible: app.page !== "main"
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: 46; height: 46; color: bMa.pressed ? app.highlight : "transparent"
            Text { anchors.centerIn: parent; text: "‹"; color: app.textPrimary; font.pixelSize: 30 }
            MouseArea { id: bMa; anchors.fill: parent; onClicked: app.back() }
        }
        Text {
            anchors { left: backBtn.visible ? backBtn.right : parent.left; leftMargin: backBtn.visible ? 0 : 14; verticalCenter: parent.verticalCenter }
            text: ({ main: qsTr("BelleWidgets"), hava: qsTr("Hava durumu"), pil: qsTr("Pil"), sistem: qsTr("Sistem"), widget: qsTr("Ana ekran widget'ı"), ayarlar: qsTr("Ayarlar") })[app.page]
            color: app.textPrimary; font.pixelSize: 20; font.bold: true
        }
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            Rectangle {
                width: 80; height: 46; color: rMa.pressed ? app.highlight : "transparent"
                visible: app.page !== "ayarlar"
                Text { anchors.centerIn: parent; text: qsTr("Yenile"); color: app.accent; font.pixelSize: 16 }
                MouseArea { id: rMa; anchors.fill: parent; onClicked: app.page === "hava" ? app.weatherRefresh() : app.refresh() }
            }
            Rectangle {
                width: 96; height: 46; color: sMa.pressed ? app.highlight : "transparent"
                visible: app.page === "main"
                Text { anchors.centerIn: parent; text: qsTr("Ayarlar"); color: app.accent; font.pixelSize: 16 }
                MouseArea { id: sMa; anchors.fill: parent; onClicked: app.open("ayarlar") }
            }
        }
        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
    }

    // ---- Klavye (ana sayfa ve ayrinti sayfalari) ----
    Item {
        id: keys
        focus: true
        Keys.onPressed: {
            var k = event.key, ctrl = (event.modifiers & Qt.ControlModifier) !== 0, t = event.text.toLowerCase();
            if (ctrl && k === Qt.Key_Q) { pil.quitApp(); event.accepted = true; return; }
            if (k === Qt.Key_Escape || k === Qt.Key_Context2 || k === Qt.Key_Backspace || t === "b") { app.back(); event.accepted = true; return; }
            if (t === "r") { app.page === "hava" ? app.weatherRefresh() : app.refresh(); event.accepted = true; return; }
            if (t === "s" || k === Qt.Key_Menu || k === Qt.Key_Context1) { app.open("ayarlar"); event.accepted = true; return; }
            if (app.page === "main") {
                if (k === Qt.Key_Down) { app.sel = (app.sel + 1) % 4; mainFlick.goster(app.sel); event.accepted = true; }
                else if (k === Qt.Key_Up) { app.sel = (app.sel + 3) % 4; mainFlick.goster(app.sel); event.accepted = true; }
                else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) { app.open(app.cards[app.sel]); event.accepted = true; }
            } else {
                if (k === Qt.Key_Down) { detailFlick.contentY = Math.min(Math.max(0, detailFlick.contentHeight - detailFlick.height), detailFlick.contentY + 80); event.accepted = true; }
                else if (k === Qt.Key_Up) { detailFlick.contentY = Math.max(0, detailFlick.contentY - 80); event.accepted = true; }
                else if (app.page === "hava" && (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select)) { app.weatherRefresh(); event.accepted = true; }
            }
        }
    }

    // =================== ANA SAYFA: tam genislikte kartlar ===================
    Flickable {
        id: mainFlick
        visible: app.page === "main"
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        contentHeight: cardCol.height + 20
        clip: true
        function goster(i) {
            var it = cardCol.children[i];
            if (!it) return;
            if (it.y < contentY) contentY = it.y;
            else if (it.y + it.height > contentY + height) contentY = Math.min(contentHeight - height, it.y + it.height - height + 10);
        }
        Column {
            id: cardCol
            x: 10; y: 10
            width: parent.width - 20
            spacing: 10

            // ---- Hava ----
            Rectangle {
                width: cardCol.width; height: 132; radius: 12
                color: hMa.pressed ? app.highlight : app.surface
                border.width: app.sel === 0 ? 2 : 0; border.color: app.accent
                Loader { id: hIcon; x: 14; y: 14; sourceComponent: wIconComp; onLoaded: item.s = 64 }
                Binding { target: hIcon.item; property: "code"; value: pil.hasWeather ? app.pilKod() : -1; when: hIcon.status === Loader.Ready }
                Column {
                    x: 92; y: 12
                    width: parent.width - 92 - 14
                    Text { text: pil.city === "" ? qsTr("Şehir seçin (Ayarlar)") : pil.city; color: app.textPrimary; font.pixelSize: 18; font.bold: true; width: parent.width; elide: Text.ElideRight }
                    Row {
                        spacing: 10
                        Text { visible: pil.hasWeather; text: app.deg(pil.temp); color: app.textPrimary; font.pixelSize: 38; font.bold: true }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: pil.weatherText; color: app.textPrimary; font.pixelSize: 15 }
                            Text { visible: pil.forecast.length > 0; text: pil.forecast.length > 0 ? qsTr("En yüksek ") + app.deg(pil.forecast[0].max) + qsTr(" • en düşük ") + app.deg(pil.forecast[0].min) : ""; color: app.textSecondary; font.pixelSize: 13 }
                        }
                    }
                    Text { text: pil.weatherStatus + (pil.weatherUpdated !== "" ? (pil.weatherStatus !== "" ? " • " : "") + pil.weatherUpdated : ""); color: app.textSecondary; font.pixelSize: 12; width: parent.width; elide: Text.ElideRight }
                }
                Row {
                    anchors { right: parent.right; rightMargin: 14; bottom: parent.bottom; bottomMargin: 10 }
                    spacing: 14
                    Repeater {
                        model: pil.forecast.length > 1 ? Math.min(4, pil.forecast.length - 1) : 0
                        delegate: Column {
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: pil.forecast[index + 1].day; color: app.textSecondary; font.pixelSize: 12 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: app.deg(pil.forecast[index + 1].max) + " " + app.deg(pil.forecast[index + 1].min); color: app.textPrimary; font.pixelSize: 13 }
                        }
                    }
                }
                Text { anchors { right: parent.right; top: parent.top; margins: 10 } text: qsTr("Ayrıntı ›"); color: app.accent; font.pixelSize: 13 }
                MouseArea { id: hMa; anchors.fill: parent; onClicked: { app.sel = 0; app.open("hava"); } }
            }

            // ---- Pil ----
            Rectangle {
                width: cardCol.width; height: 104; radius: 12
                color: pMa.pressed ? app.highlight : app.surface
                border.width: app.sel === 1 ? 2 : 0; border.color: app.accent
                Row {
                    x: 14; y: 14
                    spacing: 14
                    Item {
                        width: 84; height: 42
                        Rectangle {
                            id: body
                            width: 76; height: 42; radius: 6
                            color: "transparent"; border.color: "#E6FFFFFF"; border.width: 3
                            Rectangle { x: 5; y: 5; height: parent.height - 10; radius: 3; width: Math.max(3, (parent.width - 10) * pil.level / 100); color: app.levelColor(pil.level, pil.state) }
                        }
                        Rectangle { anchors { left: body.right; leftMargin: 1; verticalCenter: body.verticalCenter } width: 5; height: 14; radius: 2; color: "#E6FFFFFF" }
                    }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: pil.level + "%"; color: app.textPrimary; font.pixelSize: 36; font.bold: true }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: pil.stateText + (pil.finePercent ? "" : qsTr(" (yaklaşık)")); color: app.levelColor(pil.level, pil.state); font.pixelSize: 15 }
                        Text { text: pil.estimate; color: app.textPrimary; font.pixelSize: 14 }
                    }
                }
                Row {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
                    height: 22
                    Repeater {
                        model: hist
                        delegate: Item {
                            width: (cardCol.width - 24) / 96; height: 22
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: level < 0 ? 0 : Math.max(1, parent.height * level / 100); color: charging ? "#5BC0EB" : app.levelColor(level, 1); opacity: 0.85 }
                        }
                    }
                }
                Text { anchors { right: parent.right; top: parent.top; margins: 10 } text: qsTr("Ayrıntı ›"); color: app.accent; font.pixelSize: 13 }
                MouseArea { id: pMa; anchors.fill: parent; onClicked: { app.sel = 1; app.open("pil"); } }
            }

            // ---- Sistem ----
            Rectangle {
                width: cardCol.width; height: 76; radius: 12
                color: yMa.pressed ? app.highlight : app.surface
                border.width: app.sel === 2 ? 2 : 0; border.color: app.accent
                Row {
                    x: 14; anchors.verticalCenter: parent.verticalCenter
                    spacing: 24
                    Repeater {
                        model: 2
                        delegate: Column {
                            property int pct: index === 0 ? pil.ramPercent : pil.cpuPercent
                            spacing: 5
                            Text { text: (index === 0 ? qsTr("RAM %") : qsTr("CPU %")) + (pct >= 0 ? pct : "-"); color: app.textPrimary; font.pixelSize: 16; font.bold: true }
                            Rectangle {
                                width: (cardCol.width - 28 - 24) / 2 - 20; height: 9; radius: 4; color: "#33FFFFFF"
                                Rectangle { height: parent.height; radius: 4; width: parent.width * Math.max(0.03, (pct < 0 ? 0 : pct) / 100); color: app.loadColor(pct) }
                            }
                        }
                    }
                }
                MouseArea { id: yMa; anchors.fill: parent; onClicked: { app.sel = 2; app.open("sistem"); } }
            }

            // ---- Widget ----
            Rectangle {
                width: cardCol.width; height: 66; radius: 12
                color: wMa.pressed ? app.highlight : app.surface
                border.width: app.sel === 3 ? 2 : 0; border.color: app.accent
                Column {
                    x: 14; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 28
                    Text { text: qsTr("Ana ekran widget'ı"); color: app.textPrimary; font.pixelSize: 16; font.bold: true }
                    Text { text: pil.widgetStatus; color: app.textSecondary; font.pixelSize: 13; width: parent.width; elide: Text.ElideRight }
                }
                MouseArea { id: wMa; anchors.fill: parent; onClicked: { app.sel = 3; app.open("widget"); } }
            }
        }
    }
    function pilKod() { return pil.hasWeather ? pil.wcode : -1; }

    // =================== AYRINTI SAYFALARI (tam ekran) ===================
    Flickable {
        id: detailFlick
        visible: app.page !== "main" && app.page !== "ayarlar"
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        contentHeight: (app.page === "hava" ? havaCol.height : app.page === "pil" ? pilCol.height : app.page === "sistem" ? sysCol.height : wCol.height) + 24
        clip: true

        // ---- Hava ayrintisi ----
        Column {
            id: havaCol
            visible: app.page === "hava"
            x: 12; y: 12; width: parent.width - 24
            spacing: 12
            Row {
                spacing: 16
                Loader { id: bigIcon; sourceComponent: wIconComp; onLoaded: item.s = 84 }
                Binding { target: bigIcon.item; property: "code"; value: pil.hasWeather ? app.pilKod() : -1; when: bigIcon.status === Loader.Ready }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: pil.city === "" ? qsTr("Şehir seçilmedi") : pil.city; color: app.textPrimary; font.pixelSize: 20; font.bold: true }
                    Row {
                        spacing: 12
                        Text { visible: pil.hasWeather; text: app.deg(pil.temp); color: app.textPrimary; font.pixelSize: 46; font.bold: true }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: pil.weatherText; color: app.textPrimary; font.pixelSize: 17 }
                            Text { text: qsTr("Rüzgâr ") + Math.round(pil.wind) + qsTr(" km/sa") + (pil.forecast.length > 0 && pil.forecast[0].sunrise !== "" ? qsTr(" • gün doğumu ") + pil.forecast[0].sunrise + qsTr(", batımı ") + pil.forecast[0].sunset : ""); color: app.textSecondary; font.pixelSize: 13 }
                            Text { text: pil.weatherStatus + (pil.weatherUpdated !== "" ? (pil.weatherStatus !== "" ? " • " : "") + pil.weatherUpdated : ""); color: app.textSecondary; font.pixelSize: 12 }
                        }
                    }
                }
            }
            Row {
                spacing: 10
                Rectangle { width: 210; height: 40; radius: 20; color: wr.pressed ? "#3A8FB8" : app.accent
                    Text { anchors.centerIn: parent; text: qsTr("Yenile (şehri yeniden ara)"); color: "#101418"; font.pixelSize: 14; font.bold: true }
                    MouseArea { id: wr; anchors.fill: parent; onClicked: app.weatherRefresh() } }
                Rectangle { width: 140; height: 40; radius: 20; color: wc.pressed ? app.highlight : app.surface2
                    Text { anchors.centerIn: parent; text: qsTr("Şehri değiştir"); color: app.textPrimary; font.pixelSize: 14 }
                    MouseArea { id: wc; anchors.fill: parent; onClicked: app.askCity() } }
            }
            Text { text: qsTr("Saatlik (24 saat)"); color: app.textSecondary; font.pixelSize: 14; visible: pil.hourly.length > 0 }
            Flickable {
                width: parent.width; height: 112
                visible: pil.hourly.length > 0
                contentWidth: hourRow.width
                flickableDirection: Flickable.HorizontalFlick
                clip: true
                Row {
                    id: hourRow
                    spacing: 6
                    Repeater {
                        model: pil.hourly
                        delegate: Rectangle {
                            width: 62; height: 112; radius: 10; color: app.surface
                            Column {
                                anchors.centerIn: parent
                                spacing: 3
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: index === 0 ? qsTr("Şimdi") : modelData.saat; color: app.textSecondary; font.pixelSize: 12 }
                                Loader { anchors.horizontalCenter: parent.horizontalCenter; sourceComponent: wIconComp; onLoaded: { item.s = 34; item.code = modelData.code; } }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: app.deg(modelData.temp); color: app.textPrimary; font.pixelSize: 16; font.bold: true }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.rain > 0 ? "%" + modelData.rain : " "; color: app.accent; font.pixelSize: 11 }
                            }
                        }
                    }
                }
            }
            Text { text: qsTr("7 günlük"); color: app.textSecondary; font.pixelSize: 14; visible: pil.forecast.length > 0 }
            Column {
                width: parent.width
                spacing: 4
                Repeater {
                    model: pil.forecast
                    delegate: Rectangle {
                        width: havaCol.width; height: 52; radius: 10; color: app.surface
                        Text { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 62; text: modelData.day; color: app.textPrimary; font.pixelSize: 16; font.bold: index === 0 }
                        Loader { x: 78; anchors.verticalCenter: parent.verticalCenter; sourceComponent: wIconComp; onLoaded: { item.s = 34; item.code = modelData.code; } }
                        Column {
                            x: 122; anchors.verticalCenter: parent.verticalCenter
                            Text { text: modelData.desc; color: app.textPrimary; font.pixelSize: 14 }
                            Text { text: (modelData.rain >= 0 ? qsTr("Yağış %") + modelData.rain : "") + (modelData.wind >= 0 ? qsTr("  •  rüzgâr ") + Math.round(modelData.wind) + qsTr(" km/sa") : ""); color: app.textSecondary; font.pixelSize: 12 }
                        }
                        Text { anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter } text: app.deg(modelData.max) + "  /  " + app.deg(modelData.min); color: app.textPrimary; font.pixelSize: 17 }
                    }
                }
            }
            Text { width: parent.width; wrapMode: Text.Wrap; text: qsTr("Kaynak: Open-Meteo. Ana ekrandaki widget hava durumunu saatte bir, yalnızca açık bir internet bağlantısı varken günceller."); color: app.textSecondary; font.pixelSize: 12 }
        }

        // ---- Pil ayrintisi ----
        Column {
            id: pilCol
            visible: app.page === "pil"
            x: 12; y: 12; width: parent.width - 24
            spacing: 12
            Row {
                spacing: 16
                Text { text: pil.level + "%"; color: app.textPrimary; font.pixelSize: 56; font.bold: true }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: pil.stateText + (pil.finePercent ? "" : qsTr(" (yaklaşık; telefon yalnızca 7 basamak veriyor)")); color: app.levelColor(pil.level, pil.state); font.pixelSize: 17 }
                    Text { text: pil.estimate; color: app.textPrimary; font.pixelSize: 16 }
                    Text { text: qsTr("Son okuma ") + pil.updated; color: app.textSecondary; font.pixelSize: 13 }
                }
            }
            Text { text: qsTr("Son 24 saat (mavi: şarjda)"); color: app.textSecondary; font.pixelSize: 14 }
            Rectangle {
                width: parent.width; height: 170; radius: 10; color: app.surface
                Repeater { model: 4; Rectangle { x: 8; width: parent.width - 16; y: 8 + (index * (parent.height - 16) / 4); height: 1; color: app.divider } }
                Row {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 }
                    height: parent.height - 16
                    Repeater {
                        model: hist
                        delegate: Item {
                            width: (pilCol.width - 16) / 96; height: parent.height
                            Rectangle { anchors.bottom: parent.bottom; width: Math.max(1, parent.width - 1); height: level < 0 ? 0 : Math.max(1, parent.height * level / 100); color: charging ? "#5BC0EB" : app.levelColor(level, 1); opacity: 0.9 }
                        }
                    }
                }
                Text { anchors { left: parent.left; top: parent.top; margins: 8 } text: "%100"; color: app.textSecondary; font.pixelSize: 10 }
            }
            Text { text: qsTr("Uyarılar: tam dolunca ") + (pil.fullAlert ? qsTr("titreşim") : qsTr("kapalı")) + qsTr(" • düşük pil ") + (pil.lowAlert > 0 ? "%" + pil.lowAlert : qsTr("kapalı")) + qsTr("  (Ayarlar'dan değiştirilir)"); color: app.textSecondary; font.pixelSize: 13; width: parent.width; wrapMode: Text.Wrap }
        }

        // ---- Sistem ayrintisi ----
        Column {
            id: sysCol
            visible: app.page === "sistem"
            x: 12; y: 12; width: parent.width - 24
            spacing: 16
            Repeater {
                model: 2
                delegate: Rectangle {
                    property int pct: index === 0 ? pil.ramPercent : pil.cpuPercent
                    width: sysCol.width; height: 96; radius: 12; color: app.surface
                    Column {
                        x: 14; y: 12; width: parent.width - 28; spacing: 8
                        Text { text: (index === 0 ? qsTr("Bellek (RAM) %") : qsTr("İşlemci (CPU) %")) + (pct >= 0 ? pct : "-"); color: app.textPrimary; font.pixelSize: 20; font.bold: true }
                        Rectangle {
                            width: parent.width; height: 14; radius: 7; color: "#33FFFFFF"
                            Rectangle { height: parent.height; radius: 7; width: parent.width * Math.max(0.03, (pct < 0 ? 0 : pct) / 100); color: app.loadColor(pct) }
                        }
                        Text { text: index === 0 ? (pil.ramFreeMB >= 0 ? pil.ramFreeMB + qsTr(" MB boş / ") + pil.ramTotalMB + qsTr(" MB") : "") : qsTr("Ana ekran görünürken dakikada bir ölçülür"); color: app.textSecondary; font.pixelSize: 13 }
                    }
                }
            }
        }

        // ---- Widget ayrintisi ----
        Column {
            id: wCol
            visible: app.page === "widget"
            x: 12; y: 12; width: parent.width - 24
            spacing: 12
            Text { text: qsTr("Durum: ") + pil.widgetStatus; color: app.textPrimary; font.pixelSize: 15; width: parent.width; wrapMode: Text.Wrap }
            Text { text: qsTr("Ana ekrandaki görünüm"); color: app.textSecondary; font.pixelSize: 13 }
            Rectangle {
                width: Math.min(parent.width, 340); height: 90
                color: "#2A3540"; radius: 10
                Image { anchors.centerIn: parent; source: pil.previewUrl; cache: false; smooth: true; visible: pil.style === "wide" }
                Row {
                    visible: pil.style !== "wide"
                    anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    spacing: 8
                    Image { source: pil.previewUrl; cache: false; width: 70; height: 70; smooth: true }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text { text: pil.stateText + "  " + pil.estimate + qsTr(" | RAM %") + pil.ramPercent + qsTr(" CPU %") + pil.cpuPercent; color: "white"; font.pixelSize: 13; width: 240; elide: Text.ElideRight }
                        Text { text: pil.weatherLine; color: "white"; font.pixelSize: 13; width: 240; elide: Text.ElideRight }
                    }
                }
            }
            Row {
                spacing: 10
                Rectangle { width: 180; height: 40; radius: 20; color: ws.pressed ? app.highlight : app.surface2
                    Text { anchors.centerIn: parent; text: pil.style === "wide" ? qsTr("Yüzde + 2 satıra geç") : qsTr("Geniş çizime geç"); color: app.textPrimary; font.pixelSize: 14 }
                    MouseArea { id: ws; anchors.fill: parent; onClicked: pil.setStyle(pil.style === "wide" ? "rows" : "wide") } }
                Rectangle { width: 150; height: 40; radius: 20; color: wy.pressed ? app.highlight : app.surface2
                    Text { anchors.centerIn: parent; text: qsTr("Yeniden dene"); color: app.textPrimary; font.pixelSize: 14 }
                    MouseArea { id: wy; anchors.fill: parent; onClicked: { pil.retryWidget(); app.toast(pil.widgetStatus); } } }
            }
            Text { width: parent.width; wrapMode: Text.Wrap; color: app.textSecondary; font.pixelSize: 13
                text: qsTr("Eklemek için: ana ekranda boş yere uzun basın > İçerik ekle > \"BelleWidgets\" ya da \"BelleWidgets genis\". Widget'a dokununca bu uygulama açılır.") }
        }
    }

    // =================== AYARLAR (ayri menu) ===================
    ListView {
        id: setList
        visible: app.page === "ayarlar"
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom; topMargin: 4 }
        clip: true
        model: rows
        delegate: Item {
            width: setList.width; height: 48
            property bool cur: ListView.isCurrentItem && setList.activeFocus
            Rectangle { anchors.fill: parent; color: ma.pressed ? "#232B33" : (parent.cur ? app.highlight : "transparent") }
            Rectangle { visible: parent.cur; anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 4; color: app.accent }
            Text { id: lbl; anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter } text: label; color: app.textPrimary; font.pixelSize: 17 }
            Text {
                anchors { left: lbl.right; leftMargin: 8; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft
                text: value; color: app.accent; font.pixelSize: 15
            }
            Rectangle { anchors { left: parent.left; leftMargin: 16; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
            MouseArea { id: ma; anchors.fill: parent; onClicked: { setList.currentIndex = index; app.activate(index); } }
        }
        Keys.onPressed: {
            var k = event.key, ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
            if (k === Qt.Key_Down) { currentIndex = (currentIndex + 1) % rows.count; event.accepted = true; }
            else if (k === Qt.Key_Up) { currentIndex = (currentIndex - 1 + rows.count) % rows.count; event.accepted = true; }
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) { app.activate(currentIndex); event.accepted = true; }
            else if (k === Qt.Key_Left) { app.change(currentIndex, -1); event.accepted = true; }
            else if (k === Qt.Key_Right) { app.change(currentIndex, 1); event.accepted = true; }
            else if (ctrl && k === Qt.Key_Q) { pil.quitApp(); event.accepted = true; }
            else if (k === Qt.Key_Escape || k === Qt.Key_Context2 || k === Qt.Key_Backspace) { app.back(); event.accepted = true; }
        }
    }

    // ---- Sehir girisi ----
    Rectangle {
        id: cityBox
        anchors.fill: parent
        color: "#B0000000"
        visible: false
        z: 15
        MouseArea { anchors.fill: parent; onClicked: { cityBox.visible = false; keys.forceActiveFocus(); } }
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 40; topMargin: 50 }
            height: 130; radius: 12; color: app.surface
            MouseArea { anchors.fill: parent }
            Text { x: 16; y: 12; text: qsTr("Şehir ya da ilçe adı"); color: app.textPrimary; font.pixelSize: 18; font.bold: true }
            Rectangle {
                x: 16; y: 44; width: parent.width - 32; height: 42; radius: 8
                color: "#252E37"; border.width: 2; border.color: app.accent
                TextInput {
                    id: cityInput
                    anchors { left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    font.pixelSize: 19; color: app.textPrimary; selectByMouse: true
                    onAccepted: app.acceptCity()
                    Keys.onPressed: {
                        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Context2) { cityBox.visible = false; keys.forceActiveFocus(); event.accepted = true; }
                        else if (event.key === Qt.Key_Select) { app.acceptCity(); event.accepted = true; }
                    }
                }
            }
            Text { x: 16; y: 96; text: qsTr("Enter: ara ve kaydet   •   Esc: vazgeç   (internet gerekir)"); color: app.textSecondary; font.pixelSize: 13 }
        }
    }

    // ---- Bilgi penceresi ----
    Rectangle {
        id: info
        anchors.fill: parent
        color: "#101418"
        visible: false
        z: 10
        Text { id: infoTitle; anchors { left: parent.left; top: parent.top; margins: 14 } color: app.textPrimary; font.pixelSize: 20; font.bold: true }
        Flickable {
            id: infoFlick
            anchors { left: parent.left; right: parent.right; top: infoTitle.bottom; bottom: parent.bottom; margins: 14 }
            clip: true
            contentHeight: infoBody.paintedHeight + 20
            Text { id: infoBody; width: infoFlick.width; wrapMode: Text.Wrap; color: app.textPrimary; font.pixelSize: 16 }
            Keys.onPressed: {
                if (event.key === Qt.Key_Down) { contentY = Math.min(Math.max(0, contentHeight - height), contentY + 60); event.accepted = true; }
                else if (event.key === Qt.Key_Up) { contentY = Math.max(0, contentY - 60); event.accepted = true; }
                else { info.visible = false; setList.forceActiveFocus(); event.accepted = true; }
            }
        }
        MouseArea { anchors.fill: parent; onClicked: { info.visible = false; setList.forceActiveFocus(); } }
    }

    // ---- Kisa bildirim ----
    Rectangle {
        id: toastBox
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 30 }
        width: toastText.paintedWidth + 40; height: 40; radius: 12
        color: "#ECEFF1"; opacity: 0; visible: opacity > 0; z: 20
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Text { id: toastText; anchors.centerIn: parent; color: "#101418"; font.pixelSize: 17 }
        Timer { id: toastTimer; interval: 2500; onTriggered: toastBox.opacity = 0 }
    }
}
