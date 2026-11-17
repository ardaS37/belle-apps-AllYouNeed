import QtQuick 1.1
// Test kabugu: C++ nesnelerinin (lib, keys, sys) taklitleri + main.qml
Rectangle {
    width: 640; height: 480
    QtObject {
        id: lib
        property bool scanning: false
        property int scanFound: 0
        property int libraryVersion: 1
        property bool downloading: false
        property string downloadName: ""
        signal scanProgress
        signal libraryChanged
        signal downloadProgress(variant received, variant total, int speedKBs)
        signal downloadFinished(bool ok, string path, string message)
        function videos() { return [
            { path: "E:/Videos/Tatil 2025.mp4", name: "Tatil 2025", folder: "Videos", size: 52428800, time: 1762600000 },
            { path: "E:/Videos/E6Tube/abc_360.mp4", name: "Bir YouTube videosu", folder: "E6Tube", size: 12428800, time: 1762500000 },
            { path: "E:/Indirilen/klip.3gp", name: "klip", folder: "Indirilen", size: 2428800, time: 1762400000 } ]; }
        function rescan() { }
        function listDir(p) { if (p === "") return [ { name: "Hafıza kartı (E:)", path: "E:/", dir: true, kind: "dir", size: 0, time: 0 } ];
            return [ { name: "Videos", path: "E:/Videos", dir: true, kind: "dir", size: 0, time: 0 },
                     { name: "Tatil 2025.mp4", path: "E:/Videos/Tatil 2025.mp4", dir: false, kind: "video", size: 52428800, time: 1762600000 },
                     { name: "sarki.mp3", path: "E:/sarki.mp3", dir: false, kind: "audio", size: 4428800, time: 1762600000 } ]; }
        function parentDir(p) { return p === "E:/" ? "" : "E:/"; }
        function mediaInDir(p) { return ["E:/Videos/Tatil 2025.mp4"]; }
        function isVideo(p) { return p.indexOf(".mp4") > 0; }
        function isAudio(p) { return p.indexOf(".mp3") > 0; }
        function isRemote(p) { return p.indexOf("://") > 0; }
        function exists(p) { return true; }
        function removeFile(p) { return true; }
        function baseName(p) { var s = p.split("/"); return s[s.length - 1].replace(/\.[^.]*$/, ""); }
        function folderName(p) { var s = p.split("/"); return s.length > 1 ? s[s.length - 2] : ""; }
        function sizeText(b) { return b + " B"; }
        function fileSize(p) { return 1; }
        function videoUrl(p, d) { return "http://127.0.0.1:1/f/1.mp4"; }
        function audioUrl(p) { return "file:///" + p; }
        function savedPosition(p) { return p.indexOf("Tatil") > 0 ? 65000 : 0; }
        function savedDuration(p) { return p.indexOf("Tatil") > 0 ? 300000 : 0; }
        function savePosition(p, m, d) { }
        function clearPosition(p) { }
        function recent() { return ["E:/Videos/Tatil 2025.mp4"]; }
        function forgetRecent(p) { }
        function downloadDir() { return "E:/Videos/E6Video"; }
        function download(u, n) { }
        function cancelDownload() { }
        function downloads() { return [ { path: "E:/Videos/E6Video/film.mp4", name: "film.mp4", size: 1000000, time: 1762600000 } ]; }
        function sendToBackground() { }
        function openExternally(p) { return true; }
        function log(l) { console.log("LOG " + l); }
        function logText() { return "gunluk"; }
        function clearLog() { }
    }
    QtObject { id: keys; signal up; signal down; signal playPause; signal next; signal previous; signal stop }
    QtObject { id: sys; property bool locked: false; property bool foreground: true; function keepScreenOn(o) { } }
    Loader { anchors.fill: parent; source: "file:///C:/E6Video/qml/main.qml"; focus: true }
}
