// Yalnizca main.qml'de ice aktarilir: dizi/nesne tutan uygulama durumu
// (QML 1 ozellikleri dizileri yerinde degistirmeye izin vermiyor)
var stack = [];          // acik ayrinti sayfalari
var fav = {};            // favori sarki anahtarlari
var favLists = {};       // favori liste anahtarlari
var dl = {};             // indirilmis sarki anahtari -> dosya yolu
var orig = [];           // karisik calmadan onceki kuyruk sirasi
var sheetCb = null;      // acik secenek penceresinin geri cagirimi
var promptCb = null;     // metin girisi penceresinin geri cagirimi
var pickTracks = [];     // "Listeye ekle" icin secilen sarkilar
var dlPending = {};      // indirme kuyrugundaki sarkilar (anahtar -> sarki)
