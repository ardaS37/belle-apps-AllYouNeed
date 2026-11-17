import QtQuick 1.1
import "Util.js" as Util

// Bas harfli renkli daire (profil fotograflari ileride)
Item {
    id: root
    property string name: ""
    property string key: name
    property string peer: ""
    property int size: 56

    width: size
    height: size

    Rectangle {
        anchors.fill: parent
        radius: root.size / 2
        color: Util.colorFor(root.key)
        smooth: true
        Text {
            anchors.centerIn: parent
            text: Util.initials(root.name)
            color: "#FFFFFF"
            font.pixelSize: Math.round(root.size * 0.40)
            font.bold: true
        }
    }
}
