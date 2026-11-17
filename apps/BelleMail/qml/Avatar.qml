import QtQuick 1.1

// Gonderenin bas harfi, isme gore sabit renkli daire
Rectangle {
    id: root
    property string name: ""
    property int size: 46
    width: size
    height: size
    radius: size / 2

    property variant palette: ["#e8710a", "#1a73e8", "#188038", "#d93025", "#9334e6", "#e52592", "#12b5cb", "#f9ab00", "#5f6368", "#7cb342"]
    function hash(s) { var h = 0; for (var i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) % 1000003; return h; }
    function initial(s) {
        var t = ("" + s).replace(/^[^A-Za-z0-9ÇĞİÖŞÜçğıöşü]+/, "");
        return t.length ? t.charAt(0).toUpperCase() : "?";
    }
    color: palette[hash(name) % palette.length]

    Text {
        anchors.centerIn: parent
        text: root.initial(root.name)
        color: "#ffffff"
        font.pixelSize: root.size * 0.46
        font.bold: true
    }
}
