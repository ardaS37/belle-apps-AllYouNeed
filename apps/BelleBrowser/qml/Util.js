.pragma library
// E6 tus sorunu: yazi kutusu disinda harf tuslari harf yerine ustundeki rakami/isareti gonderir (R=1, T=2 ...).
var E6TUS = { "1": "r", "2": "t", "3": "y", "4": "f", "5": "g", "6": "h", "7": "v", "8": "b", "9": "n", "0": "m",
              "-": "d", "%": "x", "#": "j", "ş": "k", "ğ": "i" };
function tus(event) {
    var k = event.key;
    var t = event.text || "";
    var c = t.length === 1 ? t.charCodeAt(0) : 0;
    if (c >= 1 && c <= 26 && c !== 8 && c !== 9 && c !== 10 && c !== 13) return String.fromCharCode(96 + c);
    if (k >= 0x41 && k <= 0x5a) return String.fromCharCode(k + 32);
    if (k >= 97 && k <= 122) return String.fromCharCode(k);
    if (t.length !== 1) return "";
    var l = t.toLowerCase();
    if (E6TUS[l] !== undefined) return E6TUS[l];
    return l;
}
function boyut(b) {
    if (b < 0) return "?";
    if (b < 1024) return b + " B";
    if (b < 1048576) return Math.round(b / 1024) + qsTr(" KB");
    return (b / 1048576).toFixed(1) + qsTr(" MB");
}
function host(u) { var m = /^[a-z]+:\/\/([^\/?#:]+)/i.exec(u || ""); return m ? m[1].replace(/^www\./, "") : (u || ""); }
// Adres mi arama mi?
function adresMi(t) {
    if (/^[a-z]+:\/\//i.test(t)) return true;
    if (/\s/.test(t)) return false;
    return /^[^\s.]+(\.[^\s.]+)+(:\d+)?(\/.*)?$/.test(t) || /^localhost/.test(t);
}
var MOTORLAR = {
    ddg: { ad: qsTr("DuckDuckGo (hafif)"), url: "https://html.duckduckgo.com/html/?q=" },
    google: { ad: qsTr("Google"), url: "https://www.google.com/search?q=" },
    bing: { ad: qsTr("Bing"), url: "https://www.bing.com/search?q=" },
    yandex: { ad: qsTr("Yandex"), url: "https://yandex.com.tr/search/?text=" },
    frogfind: { ad: qsTr("FrogFind (HTTP, sade)"), url: "http://frogfind.com/?q=" },
    wiby: { ad: qsTr("Wiby (HTTP, hafif siteler)"), url: "http://wiby.me/?q=" },
    wiki: { ad: qsTr("Vikipedi"), url: "https://tr.m.wikipedia.org/w/index.php?search=" }
};
// Kisa harf rengi (hizli erisim kutulari)
var RENKLER = ["#1a73e8", "#d93025", "#188038", "#f29900", "#a142f4", "#12b5cb", "#e8710a", "#c5221f", "#1e8e3e", "#9334e6"];
function renk(s) { var h = 0; s = s || ""; for (var i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) & 0xffff; return RENKLER[h % RENKLER.length]; }
function youtubeId(u) {
    var m = /(?:youtube\.com\/(?:watch\?(?:.*&)?v=|shorts\/|embed\/)|youtu\.be\/)([\w-]{11})/.exec(u || "");
    return m ? m[1] : "";
}

// Sayfaya her yuklemede eklenen betik: indirilebilir baglantilar, uzun basma menusu, videolar, yeni pencere -> ayni sekme
var BETIK = "(function(){if(window.__bb)return;window.__bb=1;" +
 "var DOS=/\\.(mp4|3gp|3g2|m4v|mov|avi|mkv|webm|mp3|m4a|aac|amr|wav|ogg|flac|zip|rar|7z|sis|sisx|jar|jad|apk|pdf|exe|nth|deb|mid)(\\?|#|$)/i;" +
 "function bul(e){while(e&&e.nodeType==1){if(e.tagName=='A'&&e.href)return e;e=e.parentNode}return null}" +
 "function hedef(x,y){var e=document.elementFromPoint(x,y);var r={};if(!e)return r;var a=bul(e);if(a){r.a=a.href;r.at=(a.innerText||a.textContent||'').replace(/\\s+/g,' ').substring(0,80)}" +
 "var t=e;while(t&&t.nodeType==1){if(t.tagName=='IMG'){r.img=t.src;break}if(t.tagName=='VIDEO'){var so=t.getElementsByTagName('source');r.video=t.currentSrc||t.src||(so.length?so[0].src:'');break}t=t.parentNode}" +
 "r.girdi=/^(INPUT|TEXTAREA|SELECT)$/.test(e.tagName)?1:0;return r}" +
 "window.__bbHedef=function(x,y){return JSON.stringify(hedef(x,y))};" +
 "var uz=null,bx=0,by=0,uzun=false;" +
 "document.addEventListener('mousedown',function(e){uzun=false;bx=e.clientX;by=e.clientY;clearTimeout(uz);uz=setTimeout(function(){uzun=true;try{belle.baglam(JSON.stringify(hedef(bx,by)))}catch(x){}},800)},true);" +
 "document.addEventListener('mousemove',function(e){if(Math.abs(e.clientX-bx)+Math.abs(e.clientY-by)>14)clearTimeout(uz)},true);" +
 "document.addEventListener('mouseup',function(){clearTimeout(uz)},true);" +
 "document.addEventListener('click',function(e){if(uzun){e.preventDefault();e.stopPropagation();uzun=false;return}" +
 "var a=bul(e.target);if(!a)return;var h=a.href;" +
 "if(DOS.test(h)||a.hasAttribute('download')){e.preventDefault();try{belle.dosya(h,a.getAttribute('download')||'')}catch(x){}}" +
 "else if(a.target&&a.target!='_self'&&a.target!='_top'&&a.target!='_parent'&&!/^javascript:/i.test(h)){e.preventDefault();location.href=h}},true);" +
 "window.open=function(u){if(u)location.href=u;return window};" +
 "function vid(){var l=[],v=document.getElementsByTagName('video');for(var i=0;i<v.length;i++){var s=v[i].currentSrc||v[i].src;if(!s){var so=v[i].getElementsByTagName('source');if(so.length)s=so[0].src}if(s&&l.indexOf(s)<0)l.push(s)}" +
 "var f=document.getElementsByTagName('iframe');for(var j=0;j<f.length;j++){var m=/youtube(?:-nocookie)?\\.com\\/embed\\/([\\w-]{11})/.exec(f[j].src||'');if(m)l.push('https://www.youtube.com/watch?v='+m[1])}" +
 "try{belle.videolar(l.join('\\n'))}catch(x){}}" +
 "vid();setTimeout(vid,2500);" +
 "})()";

var GECE = "(function(){var s=document.getElementById('__bbgece');if(!s){s=document.createElement('style');s.id='__bbgece';" +
 "s.textContent='html,body,div,section,article,main,header,footer,nav,aside,table,tr,td,th,ul,ol,li,p,span,form,input,textarea,select,button,h1,h2,h3,h4,h5,h6{background-color:#16181c !important;color:#d8dade !important;border-color:#3a3f46 !important}a,a *{color:#8ab4f8 !important}img,video{opacity:.88}';" +
 "(document.head||document.documentElement).appendChild(s)}})()";
var GECE_KAPAT = "(function(){var s=document.getElementById('__bbgece');if(s)s.parentNode.removeChild(s)})()";
var ODAK = "(function(){var e=document.activeElement;if(!e)return 0;var t=e.tagName;return ((t=='INPUT'&&!/^(button|submit|checkbox|radio|reset|image|file|hidden)$/i.test(e.type))||t=='TEXTAREA'||e.isContentEditable)?1:0})()";
var SECIM_YERI = "(function(){var s=window.getSelection();if(!s.rangeCount)return '';var r=s.getRangeAt(0).getBoundingClientRect();return Math.round(r.top+window.pageYOffset)+','+Math.round(r.left+window.pageXOffset)})()";