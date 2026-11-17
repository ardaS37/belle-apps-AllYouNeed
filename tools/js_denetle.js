// QML'in JS dosyalarini sozdizimi icin denetler (calistirmaz): cscript //nologo //E:{16d51579-a30b-4c8b-a276-0ff4dc41e755} js_denetle.js dosya1.js dosya2.js ...
// .pragma / .import satirlari atilir; qsTr ve Qt tanimsiz olsa da yalnizca ayristirma yapildigi icin sorun olmaz.
var hata = 0;
for (var i = 0; i < WScript.Arguments.length; i++) {
    var yol = WScript.Arguments(i);
    var s = new ActiveXObject("ADODB.Stream");
    s.Type = 2; s.Charset = "utf-8"; s.Open(); s.LoadFromFile(yol);
    var src = s.ReadText(); s.Close();
    src = src.replace(/^\s*\.(pragma|import)[^\n]*/mg, "");
    try { new Function(src); }
    catch (e) { hata++; WScript.Echo("HATA " + yol + ": " + e.message); }
}
WScript.Echo("denetlenen: " + WScript.Arguments.length + ", hatali: " + hata);
