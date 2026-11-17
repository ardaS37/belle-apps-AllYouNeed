import QtQuick 1.1

// Kapak resmi: yuklenene kadar (ya da kapak kapaliysa) yer tutucu
Rectangle {
    id: root
    property string source: ""
    property int size: 56
    width: size
    height: size
    radius: 6
    color: app.surface2
    clip: true
    Image {
        anchors.fill: parent
        source: "../images/cover.png"
        smooth: true
        visible: img.status !== Image.Ready
    }
    Image {
        id: img
        anchors.fill: parent
        source: app.showCovers ? app.coverUrl(root.source, root.size <= 64 ? 96 : 300) : ""
        sourceSize.width: root.size <= 64 ? 96 : 300
        sourceSize.height: root.size <= 64 ? 96 : 300
        asynchronous: true
        smooth: true
        fillMode: Image.PreserveAspectCrop
    }
}
