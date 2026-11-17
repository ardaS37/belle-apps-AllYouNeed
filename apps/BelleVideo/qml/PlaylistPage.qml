import QtQuick 1.1
import "Util.js" as U

// Kalici calma listesi. Bitince sonrakine gecer; karisik ve tekrar ayarlari oynaticiyla ortak.
// Klavye: Enter oynatir, Sil/Geri listeden cikarir, Bosluk secenekler, Sol/Sag sekme
Rectangle {
    id: root
    color: app.bg

    function takeFocus() { list.forceActiveFocus(); }

    function menuAt(i) {
        if (i < 0 || i >= app.playlist.count) return;
        var it = app.playlist.get(i);
        sheet.open(it.title, [
            { label: qsTr("Buradan oynat"), icon: "play", key: "play" },
            { label: qsTr("Buradan sadece ses ile çal"), icon: "phones", key: "audio" },
            { label: qsTr("Yukarı taşı"), icon: "up", key: "up" },
            { label: qsTr("Aşağı taşı"), icon: "download", key: "down" },
            { label: qsTr("Listeden çıkar"), icon: "close", key: "rm", danger: true }
        ], function (k) {
            if (k === "play") app.playList(i, false);
            else if (k === "audio") app.playList(i, true);
            else if (k === "up") list.currentIndex = app.moveInList(i, -1);
            else if (k === "down") list.currentIndex = app.moveInList(i, 1);
            else if (k === "rm") app.removeFromList(i);
        });
    }
    function confirmClear() {
        if (app.playlist.count === 0) return;
        sheet.open(qsTr("Liste temizlensin mi? (dosyalar silinmez)"), [
            { label: qsTr("Evet, temizle"), icon: "trash", key: "yes", danger: true },
            { label: qsTr("Vazgeç"), icon: "close", key: "no" }
        ], function (k) { if (k === "yes") app.clearList(); });
    }

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: qsTr("Liste")
        subtitle: app.playlist.count + qsTr(" dosya") + (app.shuffle ? qsTr(" • karışık") : "") + (app.repeatMode === 1 ? qsTr(" • tümünü tekrarla") : app.repeatMode === 2 ? qsTr(" • tek tekrar") : "")
        IconButton {
            icon: "shuffle"; iconSize: 26; tone: "g"
            active: app.shuffle
            onClicked: { app.shuffle = !app.shuffle; app.setSetting("shuffle", app.shuffle ? 1 : 0); }
        }
        IconButton {
            icon: app.repeatMode === 2 ? "repeat1" : "repeat"; iconSize: 26; tone: "g"
            active: app.repeatMode > 0
            onClicked: { app.repeatMode = (app.repeatMode + 1) % 3; app.setSetting("repeat", app.repeatMode); }
        }
        IconButton { icon: "trash"; iconSize: 24; tone: "g"; onClicked: root.confirmClear() }
    }

    Row {
        id: actions
        anchors { left: parent.left; right: parent.right; top: header.bottom; leftMargin: 12; topMargin: 8 }
        height: app.playlist.count > 0 ? 40 : 0
        visible: app.playlist.count > 0
        spacing: 10
        Pill { label: qsTr("Oynat"); icon: "play"; accent: true; onClicked: app.playList(app.shuffle ? Math.floor(Math.random() * app.playlist.count) : 0, false) }
        Pill { label: qsTr("Sadece ses ile çal"); icon: "phones"; onClicked: app.playList(0, true) }
    }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: actions.bottom; bottom: parent.bottom; topMargin: actions.visible ? 8 : 0 }
        clip: true
        model: app.playlist
        focus: true
        highlightMoveDuration: 120
        delegate: FileRow {
            width: list.width
            icon: lib.isAudio(path) ? "note" : (lib.isRemote(path) ? "globe" : "film")
            title: (index + 1) + ".  " + model.title
            sub: lib.isRemote(path) ? path : lib.folderName(path) + (lib.exists(path) ? "" : qsTr("  •  dosya bulunamadı"))
            selected: ListView.isCurrentItem && list.activeFocus
            playing: app.playerOpen && app.nowSource === "list" && app.nowPath === path
            onClicked: { list.currentIndex = index; app.playList(index, false); }
            onPressAndHold: { list.currentIndex = index; root.menuAt(index); }
            onAction: { list.currentIndex = index; root.menuAt(index); }
        }
        Keys.onPressed: {
            var k = event.key;
            if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) { app.playList(currentIndex, false); event.accepted = true; }
            else if (k === Qt.Key_Delete || k === Qt.Key_Backspace) { app.removeFromList(currentIndex); event.accepted = true; }
            else if (k === Qt.Key_Left) { app.stepTab(-1); event.accepted = true; }
            else if (k === Qt.Key_Right) { app.stepTab(1); event.accepted = true; }
            else if (k === Qt.Key_Space || k === Qt.Key_Menu || k === Qt.Key_Context1) { root.menuAt(currentIndex); event.accepted = true; }
        }
    }

    Text {
        anchors.centerIn: list
        width: parent.width - 80
        visible: app.playlist.count === 0
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: qsTr("Liste boş.\nVideolar ya da Klasörler'de bir dosyada + tuşuna basın ya da sağdaki üç nokta düğmesinden \"Listeye ekle\"yi seçin.")
        color: app.textSecondary
        font.pixelSize: 18
    }
}
