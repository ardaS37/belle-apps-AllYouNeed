.pragma library

function pad(x) { return (x < 10 ? "0" : "") + x; }

// saniye -> "3:07" / "1:02:05"
function dur(sec) {
    sec = Math.max(0, Math.floor(sec || 0));
    var h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
    return h > 0 ? h + ":" + pad(m) + ":" + pad(s) : m + ":" + pad(s);
}

function totalDur(sec) {
    sec = Math.floor(sec || 0);
    var h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60);
    return h > 0 ? h + qsTr(" sa ") + m + qsTr(" dk") : m + qsTr(" dk");
}

function shuffled(arr) {
    var a = arr.slice(0);
    for (var i = a.length - 1; i > 0; i--) {
        var j = Math.floor(Math.random() * (i + 1));
        var t = a[i]; a[i] = a[j]; a[j] = t;
    }
    return a;
}

function when(ms) {
    var d = new Date(ms), now = new Date();
    if (d.toDateString() === now.toDateString()) return qsTr("Bugün ") + pad(d.getHours()) + ":" + pad(d.getMinutes());
    var y = new Date(now.getTime() - 86400000);
    if (d.toDateString() === y.toDateString()) return qsTr("Dün ") + pad(d.getHours()) + ":" + pad(d.getMinutes());
    return pad(d.getDate()) + "." + pad(d.getMonth() + 1) + "." + d.getFullYear();
}
