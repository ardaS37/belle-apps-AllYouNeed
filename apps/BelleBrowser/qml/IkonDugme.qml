import QtQuick 1.1

// Yuvarlak basma efektli ikon dugmesi. ikon: "geri" gibi; vurgu: mavi
Item {
    id: root
    property string ikon: ""
    property bool vurgu: false
    property int boy: 26
    signal clicked
    signal pressAndHold
    width: 46; height: 46
    opacity: enabled ? 1 : 0.35
    Rectangle {
        anchors.centerIn: parent
        width: 40; height: 40; radius: 20
        color: app.cIkinci
        opacity: ma.pressed ? 0.25 : 0
    }
    Image {
        anchors.centerIn: parent
        width: root.boy; height: root.boy
        smooth: true
        source: root.ikon === "" ? "" : "../images/" + root.ikon + "_" + (root.vurgu ? "m" : (app.gece ? "b" : "k")) + ".png"
    }
    MouseArea { id: ma; anchors.fill: parent; onClicked: root.clicked(); onPressAndHold: root.pressAndHold() }
}
