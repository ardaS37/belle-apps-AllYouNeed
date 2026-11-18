// Web sitesindeki "Hata bildir" sayfasi (https://msahincelen.xyz/hata/) icin herkese acik uc.
// POST /api/hata-bildir  {raporlar: [{uygulama, mesaj}], iletisim, telefon}
//  - parola istemez (auth'tan ONCE baglanir); IP basina saatte 10 gonderim, govde en cok 64 KB
//  - her gonderim data/reports/<zaman>_web-<uygulamalar>.txt olarak yazilir: web panelinde /panel/raporlar'da gorunur
const express = require("express");
const fs = require("fs");
const path = require("path");

const router = new express.Router();
const RAPOR = path.join(__dirname, "data", "reports");
const UYGULAMALAR = ["WhatsBelle", "BelleMail", "BelleGram", "BelleTube", "BelleMusic", "Belle Files", "ApiLauncher", "Belle Browser",
    "Belle Maps", "Belle Remote", "BelleCast", "BelleKitap", "BelleCeviri", "BelleVideo", "BelleWidgets", "BelleMiddleKey",
    "BelleAppCenter", "Web sitesi", "Diğer"];
const sayac = {};   // ip -> [zamanlar]

function temiz(s, n) { return ("" + (s == null ? "" : s)).replace(/\r/g, "").replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, "").trim().slice(0, n); }

router.post("/api/hata-bildir", express.json({ limit: "64kb" }), (req, res) => {
    const ip = req.ip || "?";
    const simdi = Date.now();
    const l = (sayac[ip] || []).filter((t) => simdi - t < 3600 * 1000);
    if (l.length >= 10) return res.status(429).json({ error: "Çok fazla gönderim. Lütfen bir saat sonra tekrar deneyin." });
    const b = req.body || {};
    const raporlar = (Array.isArray(b.raporlar) ? b.raporlar : []).slice(0, 25)
        .map((r) => ({ uygulama: temiz(r && r.uygulama, 40), mesaj: temiz(r && r.mesaj, 4000) }))
        .filter((r) => UYGULAMALAR.indexOf(r.uygulama) >= 0 && r.mesaj.length > 0);
    if (!raporlar.length) return res.status(400).json({ error: "En az bir uygulama seçip ne olduğunu yazın." });
    l.push(simdi);
    sayac[ip] = l;
    const iletisim = temiz(b.iletisim, 200), telefon = temiz(b.telefon, 120);
    const zaman = new Date(simdi).toISOString().replace(/[-:]/g, "").replace("T", "_").slice(0, 15);
    const adlar = raporlar.map((r) => r.uygulama.replace(/[^A-Za-z0-9]/g, "")).join("-").slice(0, 80);
    const metin = [
        "Web hata bildirimi (msahincelen.xyz/hata)",
        "Zaman: " + new Date(simdi).toISOString(),
        "İletişim: " + (iletisim || "-"),
        "Telefon/yazılım: " + (telefon || "-"),
        ""
    ].concat(raporlar.map((r) => "==== " + r.uygulama + " ====\n" + r.mesaj + "\n")).join("\n");
    try {
        fs.mkdirSync(RAPOR, { recursive: true });
        fs.writeFileSync(path.join(RAPOR, `${zaman}_web-${adlar}.txt`), metin);
    } catch (e) {
        console.log("[hata-bildir] yazilamadi:", e.message);
        return res.status(500).json({ error: "Bildirim kaydedilemedi, lütfen sonra tekrar deneyin." });
    }
    console.log(`[hata-bildir] ${raporlar.length} uygulama: ${raporlar.map((r) => r.uygulama).join(", ")}`);
    res.json({ ok: true, adet: raporlar.length });
});

// Uygulama listesi (sayfa da kendi listesini tasir; bu uc ileride guncellemek icin)
router.get("/api/hata-bildir/uygulamalar", (req, res) => res.json({ uygulamalar: UYGULAMALAR }));

module.exports = router;
