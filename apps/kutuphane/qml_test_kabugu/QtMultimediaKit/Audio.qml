import QtQuick 1.1
Item {
    property url source: ""
    property real volume: 0.5
    property int position: 0
    property int duration: 0
    property bool playing: false
    property bool paused: false
    property int status: 1
    property string errorString: ""
    signal error
    function play() { playing = true; paused = false }
    function pause() { paused = true }
    function stop() { playing = false }
}
