import QtQuick 1.1

// Dosya turune gore renkli simge; resimlerde kucuk onizleme
Item {
    id: root
    property string kind: "file"
    property string ext: ""
    property string thumb: ""
    width: 48
    height: 48

    function colorOf(k) {
        if (k === "folder") return "#f4b400";
        if (k === "image") return "#d93025";
        if (k === "video") return "#c2185b";
        if (k === "audio") return "#8e24aa";
        if (k === "pdf") return "#ea4335";
        if (k === "sheet") return "#188038";
        if (k === "slides") return "#f29900";
        if (k === "doc") return "#1a73e8";
        if (k === "archive") return "#5f6368";
        if (k === "text") return "#455a64";
        return "#80868b";
    }

    // Klasor: sekmeli dikdortgen
    Item {
        anchors.fill: parent
        visible: root.kind === "folder"
        Rectangle { x: 4; y: 9; width: 18; height: 8; radius: 2; color: "#e3a300" }
        Rectangle { x: 4; y: 13; width: 40; height: 28; radius: 3; color: "#f4b400" }
    }
    // Diger dosyalar: renkli kart, uzerinde uzanti
    Rectangle {
        anchors { fill: parent; leftMargin: 6; rightMargin: 6; topMargin: 2; bottomMargin: 2 }
        visible: root.kind !== "folder"
        radius: 4
        color: root.colorOf(root.kind)
        Text {
            anchors.centerIn: parent
            width: parent.width - 2
            horizontalAlignment: Text.AlignHCenter
            text: root.ext !== "" ? root.ext.substring(0, 4) : "?"
            color: "#ffffff"
            font.pixelSize: root.ext.length > 3 ? 11 : 13
            font.bold: true
        }
        Image {
            anchors.fill: parent
            source: root.thumb
            fillMode: Image.PreserveAspectCrop
            clip: true
            asynchronous: true
            smooth: false
            sourceSize.width: 72
            visible: status === Image.Ready
        }
    }
}
