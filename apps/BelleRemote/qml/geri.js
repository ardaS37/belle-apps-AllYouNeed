// Menu ve giris kutusu geri cagirmalari. QML 1'de islev 'property variant'a saklaninca dogru calismiyor
// (atama aninda bos degerle cagriliyor, sonra kayboluyor); duz JS degiskeninde sorunsuz.
var menu = null;
var giris = null;
// Menu yigini: alt menuden sol tusla ust menuye donulur
var yigin = [];
var su = null;
var secimde = false;
var geriDonus = false;