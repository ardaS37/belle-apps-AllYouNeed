import QtQuick 1.1
import QtMultimediaKit 1.1

// Dahili video oynatici (tam ekran). Symbian'in kendi cozuculeri; acamazsa harici oynatici / indirme onerilir.
Rectangle {
    id: root
    anchors.fill: parent
    color: "#000"
    property string baslik: ""
    property bool denetim: true
    function oynat(kaynak, b) { baslik = b || ""; video.source = kaynak; video.play(); denetim = true; gizle.restart(); odak.forceActiveFocus(); }
    function durdur() { video.stop(); video.source = ""; }
    function sure(ms) { var s = Math.floor(ms / 1000), m = Math.floor(s / 60); s = s % 60; return m + ":" + (s < 10 ? "0" : "") + s; }

    Video {
        id: video
        anchors.fill: parent
        fillMode: Video.PreserveAspectFit
        onError: app.videoHatasi(errorString)
        onStatusChanged: if (status === Video.EndOfMedia) root.denetim = true
    }
    Text { anchors.centerIn: parent; visible: video.status === Video.Loading || video.status === Video.Buffering || video.status === Video.Stalled
        text: video.status === Video.Loading ? qsTr("Yükleniyor…") : qsTr("Arabelleğe alınıyor… %") + Math.round(video.bufferProgress * 100); color: "#fff"; font.pixelSize: 22 }
    Timer { id: gizle; interval: 3500; onTriggered: if (video.playing && !video.paused) root.denetim = false }
    MouseArea { anchors.fill: parent; onClicked: { root.denetim = !root.denetim; gizle.restart(); } }
    Item {
        id: odak
        focus: true
        Keys.onPressed: {
            var k = event.key;
            root.denetim = true; gizle.restart();
            if (k === Qt.Key_Select || k === Qt.Key_Return || k === Qt.Key_Space) { if (video.paused || !video.playing) video.play(); else video.pause(); }
            else if (k === Qt.Key_Right) { if (video.seekable) video.position = Math.min(video.duration, video.position + 10000); }
            else if (k === Qt.Key_Left) { if (video.seekable) video.position = Math.max(0, video.position - 10000); }
            else if (k === Qt.Key_Up) video.volume = Math.min(1, video.volume + 0.1);
            else if (k === Qt.Key_Down) video.volume = Math.max(0, video.volume - 0.1);
            else if (k === Qt.Key_Backspace || k === Qt.Key_Escape || k === Qt.Key_Context2) app.videoKapat();
            event.accepted = true;
        }
    }
    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 50; color: "#99000000"; visible: root.denetim
        IkonDugme { id: kp; anchors { left: parent.left; verticalCenter: parent.verticalCenter } ikon: "geri"; onClicked: app.videoKapat() }
        Text { anchors { left: kp.right; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } text: root.baslik; color: "#fff"; font.pixelSize: 21; elide: Text.ElideRight }
    }
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 66; color: "#99000000"; visible: root.denetim
        Rectangle {
            id: cubuk
            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 12; rightMargin: 12; topMargin: 8 }
            height: 6; radius: 3; color: "#55ffffff"
            Rectangle { height: parent.height; radius: 3; color: "#1a73e8"; width: video.duration > 0 ? parent.width * video.position / video.duration : 0 }
            MouseArea { anchors { fill: parent; topMargin: -12; bottomMargin: -12 } onClicked: if (video.seekable && video.duration > 0) video.position = Math.floor(video.duration * mouse.x / cubuk.width) }
        }
        IkonDugme { id: oy; anchors { left: parent.left; bottom: parent.bottom; leftMargin: 4 } ikon: video.playing && !video.paused ? "dur" : "video"; vurgu: true
            onClicked: { if (video.playing && !video.paused) video.pause(); else video.play(); gizle.restart(); } }
        Text { anchors { left: oy.right; leftMargin: 8; verticalCenter: oy.verticalCenter } text: root.sure(video.position) + " / " + root.sure(video.duration); color: "#fff"; font.pixelSize: 19 }
    }
}
