.pragma library
// Arka plan isi bitince calisacak geri cagirma ve sirali Drive isleri (QML ozelligine islev konamaz)
var sonra = null;        // function(ok, sonuc)
var driveSonra = null;   // function(ok) — Drive klasor isi bitince
var driveKuyruk = [];    // [{ yollar: [...], hedef: "...", degisen: bool }]
var zipParola = {};      // arsiv yolu -> dogru cikan parola (uygulama acik kaldikca; diske yazilmaz)
