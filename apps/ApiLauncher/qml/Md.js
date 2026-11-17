// Yapay zeka yanitlari icin hafif Markdown -> Qt zengin metin donusturucu
// Desteklenen: ```kod blogu```, `satir ici kod`, **kalin**, *italik*, # basliklar, - madde
.pragma library

function esc(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function inline(s) {
    s = esc(s);
    s = s.replace(/`([^`]+)`/g, qsTr("<tt><font color=\"#C792EA\">$1</font></tt>"));
    s = s.replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>");
    s = s.replace(/(^|[^*])\*([^*\s][^*]*)\*/g, "$1<i>$2</i>");
    return s;
}

function toRich(text, codeBg) {
    var lines = text.split("\n");
    var out = [];
    var inCode = false;
    var code = [];
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i];
        if (/^\s*```/.test(l)) {
            if (inCode) {
                out.push(qsTr("<table width=\"100%\" cellpadding=\"6\" bgcolor=\"") + codeBg + "\"><tr><td><pre>" + esc(code.join("\n")) + "</pre></td></tr></table>");
                code = [];
                inCode = false;
            } else {
                inCode = true;
            }
            continue;
        }
        if (inCode) { code.push(l); continue; }
        var h = /^(#{1,4})\s+(.*)$/.exec(l);
        if (h) { out.push(qsTr("<b><font size=\"") + (h[1].length <= 2 ? "+1" : "+0") + "\">" + inline(h[2]) + "</font></b>"); continue; }
        var li = /^\s*[-*•]\s+(.*)$/.exec(l);
        if (li) { out.push(qsTr("&nbsp;&nbsp;• ") + inline(li[1])); continue; }
        var ol = /^\s*(\d+)[.)]\s+(.*)$/.exec(l);
        if (ol) { out.push("&nbsp;&nbsp;" + ol[1] + ". " + inline(ol[2])); continue; }
        out.push(inline(l));
    }
    if (inCode && code.length) out.push("<pre>" + esc(code.join("\n")) + "</pre>");
    return out.join("<br>");
}
