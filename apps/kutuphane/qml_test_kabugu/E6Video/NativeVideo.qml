import QtQuick 1.1
Rectangle {
    color: "#202020"
    property string source: ""
    property int volume: 50
    property int position: 0
    property int duration: 0
    property bool playing: false
    property bool paused: false
    property int status: 0
    property string errorString: ""
    property bool showVideo: true
    signal clicked
    signal error
    function play() { playing = true; paused = false }
    function pause() { paused = true }
    function stop() { playing = false }
    function debugInfo() { return "stub" }
}
