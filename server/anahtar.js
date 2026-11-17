// Sunucu parolalari: asil parola (BELLE_KEY, .bellekey) + istege bagli ikinci parola (.bellekey2, bu klasorde, 600 izinli).
// Iki parola da her yerde gecerlidir (uygulamalar, panel girisi, Belle Remote / BelleRemote baglantilari).
// Ikinci parola kodda yazmaz; dosya yoksa yalnizca asil parola gecerlidir.
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

function oku(dosya) { try { return fs.readFileSync(path.join(__dirname, dosya), "utf8").trim(); } catch (e) { return ""; } }

const ASIL = process.env.BELLE_KEY || process.env.E6_KEY || "";   // E6_KEY: eski ad
const IKINCI = oku(".bellekey2") || oku(".e6key2");   // .e6key2: eski ad

function esit(a, b) {
    if (typeof a !== "string" || typeof b !== "string" || !b) return false;
    const ba = Buffer.from(a), bb = Buffer.from(b);
    return ba.length === bb.length && crypto.timingSafeEqual(ba, bb);
}

// Verilen deger gecerli parolalardan biri mi?
function ok(v) { return esit(v, ASIL) || esit(v, IKINCI); }

module.exports = { ok, ikinciVar: !!IKINCI };
