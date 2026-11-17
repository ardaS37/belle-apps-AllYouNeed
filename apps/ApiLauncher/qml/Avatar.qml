import QtQuick 1.1
import "Util.js" as Util

// Profil resmi (sunucudan 40x40 yuvarlak PNG); yoksa bas harfli renkli daire
Item {
    id: root
    property string name: ""
    property string key: name
    property string peer: ""          // WhatsApp kimligi; doluysa profil resmi istenir
    property int size: 56

    width: size
    height: size

    Rectangle {
        anchors.fill: parent
        radius: root.size / 2
        color: Util.colorFor(root.key)
        smooth: true
        visible: pic.status !== Image.Ready
        Text {
            anchors.centerIn: parent
            text: Util.initials(root.name)
            color: "#FFFFFF"
            font.pixelSize: Math.round(root.size * 0.40)
            font.bold: true
        }
    }
    Image {
        id: pic
        anchors.fill: parent
        smooth: true
        asynchronous: true
        cache: true
        source: root.peer !== "" ? app.avatarUrl(root.peer) : ""
    }
}
