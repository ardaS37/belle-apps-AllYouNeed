.pragma library
// QML ozelliklerine islev/dizi konamadigi icin paylasilan durum burada
var indirKuyruk = [];      // [{ url, ad, guid, podcast }]
var haberBekleyen = 0;     // yenilenen kaynak sayisi
var haberHam = [];         // gosterilen birlesik haber listesi (en yeni once)
var haberYeni = [];        // yenileme sirasinda toplananlar
var sonrakiIs = null;      // input/sheet sonrasi
