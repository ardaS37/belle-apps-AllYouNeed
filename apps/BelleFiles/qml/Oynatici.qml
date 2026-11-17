import QtQuick 1.1
import QtMultimediaKit 1.1

// Dahili ses calar (alt cubuk). Klasordeki ses dosyalarini sirayla calar.
// Symbian'in kendi ses cozuculerini kullanir (X-plore'daki gibi); videonun sesini de calmayi dener.
Rectangle {
    id: root
    height: 66
    color: app.surface
    property string yol: ""
    property variant liste: []
    property int sira: -1

    function cal(p, l) {
        liste = l;
        sira = l.indexOf(p);
        yol = p;
        ses.stop();
        ses.source = "file:///" + p;
        ses.play();
    }
    function durdur() { ses.stop(); ses.source = ""; }
    function atla(d) {
        var l = liste;
        if (!l.length) return;
        var n = sira + d;
        if (n < 0 || n >= l.length) { if (d > 0) { ses.stop(); app.showToast(qsTr("Liste bitti")); } return; }
        cal(l[n], l);
    }
    function sure(ms) {
        var s = Math.floor(ms / 1000), m = Math.floor(s / 60);
        s = s % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    Audio {
        id: ses
        onStatusChanged: if (status === Audio.EndOfMedia) root.atla(1)
        onError: app.showToast(qsTr("Çalınamadı: ") + errorString)
    }

    Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: app.divider }
    // ilerleme cubugu (dokunarak sarma)
    Rectangle {
        id: bar
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 1 }
        height: 6
        color: app.divider
        Rectangle { height: parent.height; color: app.brand; width: ses.duration > 0 ? parent.width * ses.position / ses.duration : 0 }
        MouseArea {
            anchors { fill: parent; topMargin: -8; bottomMargin: -8 }
            onClicked: if (ses.seekable && ses.duration > 0) ses.position = Math.floor(ses.duration * mouse.x / bar.width)
        }
    }
    Row {
        id: tuslar
        anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter; verticalCenterOffset: 3 }
        IconButton { icon: "prev"; tone: "w"; iconSize: 24; onClicked: root.atla(-1) }
        IconButton { icon: ses.playing && !ses.paused ? "pause" : "play"; tone: "a"; iconSize: 28
            onClicked: { if (ses.playing && !ses.paused) ses.pause(); else ses.play(); } }
        IconButton { icon: "next"; tone: "w"; iconSize: 24; onClicked: root.atla(1) }
    }
    Column {
        anchors { left: tuslar.right; leftMargin: 6; right: kapat.left; rightMargin: 4; verticalCenter: parent.verticalCenter; verticalCenterOffset: 3 }
        Text { width: parent.width; text: fs.fileName(root.yol); color: app.textPrimary; font.pixelSize: 17; elide: Text.ElideMiddle }
        Text {
            width: parent.width
            text: root.sure(ses.position) + " / " + root.sure(ses.duration) + (root.liste.length > 1 ? "   •   " + (root.sira + 1) + "/" + root.liste.length : "")
            color: app.textSecondary; font.pixelSize: 14
        }
    }
    IconButton { id: kapat; anchors { right: parent.right; verticalCenter: parent.verticalCenter; verticalCenterOffset: 3 } icon: "close"; tone: "g"; iconSize: 22; onClicked: app.sesKapat() }
}
