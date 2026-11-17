import QtQuick 1.1

// Hap seklinde dugme: istege bagli simge + yazi
Rectangle {
    id: root
    property string text: ""
    property string icon: ""
    property bool primary: false
    signal clicked
    height: 46
    width: row.width + 36
    radius: 23
    color: primary ? (ma.pressed ? app.accentPressed : app.accent) : (ma.pressed ? app.pressed : app.surface2)
    opacity: enabled ? 1 : 0.4
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Image {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: 24; height: 24; smooth: true
            source: root.icon !== "" ? "../images/" + root.icon + (root.primary ? "_w" : "_w") + ".png" : ""
        }
        Text { anchors.verticalCenter: parent.verticalCenter; text: root.text; color: root.primary ? app.onAccent : app.textPrimary; font.pixelSize: 18; font.bold: root.primary }
    }
    MouseArea { id: ma; anchors.fill: parent; onClicked: root.clicked() }
}
