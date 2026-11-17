const express = require("express");
const path = require("path");
const qrimage = require("qr-image");
const router = new express.Router();
const dil = require("./dil.js");
// Telefon icin uretilen etiketler (Konum, Fotograf, "Sen: " ...) Ingilizce istemcide cevrilir; kullanici metnine dokunulmaz
function etiket(s, d) {
    if (d !== "en" || typeof s !== "string") return s;
    if (s.indexOf("Sen: ") === 0) return "You: " + dil.t(s.substring(5), d);
    return dil.t(s, d);
}

const {
    startClient, pairClient, sendMessage, sendLocation, reactMessage, getStatus, getQr, validate, debugScreenshot, debugState, restartClient,
    loginUser, getChats, getContacts, uploadMedia, getMessages, listUsers, getAvatar, getNotifications, debugMessages
} = require("./WhatsappClient");

const WIFI = /;interface=wifi/i;
function q(v, def) {
    if (v === undefined || v === "") return def;
    return ("" + v).replace(WIFI, "");
}

router.get("/whatsapp", (req, res) => res.sendFile("index.html", { root: __dirname }));   // ana sayfa artik panel (server.js)
router.get("/login", (req, res) => dil.dosyaGonder(req, res, path.join(__dirname, "login.html")));

// Medya dosyalari: sadece rakam + uzanti kabul edilir (dizin disina cikis yok)
router.get("/api/mediafile/:filename", (req, res) => {
    const filename = q(req.params.filename, "");
    if (!/^\d+\.(jpg|mp3|3gp)$/.test(filename)) return res.status(404).json({ error: "Dosya bulunamadı" });
    res.sendFile(filename, { root: path.join(__dirname, "media") }, (err) => {
        if (err && !res.headersSent) res.status(404).json({ error: "Dosya bulunamadı" });
    });
});

// Profil resmi: /api/avatar/905xx/905yy@c.us.png?key=...
router.get("/api/avatar/:owner/:peer.png", async (req, res) => {
    try {
        const file = await getAvatar(q(req.params.owner, ""), q(req.params.peer, ""));
        if (!file) return res.status(404).end();
        res.set("Cache-Control", "private, max-age=86400");
        res.sendFile(file);
    } catch (e) {
        res.status(404).end();
    }
});

router.get("/login-status/:phoneNumber", (req, res) => {
    const st = getStatus(req.params.phoneNumber);
    res.json({ isAuthenticated: st.isAuthenticated, hasQr: !!st.qr, pushname: st.pushname, user: st.user, platform: st.platform });
});

router.get("/qr/:phoneNumber.png", (req, res) => {
    const qr = getQr(req.params.phoneNumber);
    if (!qr) return res.status(404).send("QR yok");
    res.type("png");
    res.set("Cache-Control", "no-store");
    qrimage.image(qr, { type: "png", size: 8, margin: 2 }).pipe(res);
});

router.get("/:country/:phoneNumber/start", (req, res) => {
    const result = validate(req.params.phoneNumber, req.params.country);
    if (!result.valid) return res.status(200).json(result);
    const id = result.formatted.replace("+", "");
    console.log(`Oturum baslatiliyor: ${id}`);
    pairClient(id).then((d) => res.status(200).json({ valid: true, formatted: id, durum: d }))
        .catch((e) => res.status(200).json({ valid: false, reason: e.message }));
});

router.get("/api/login/:user", async (req, res) => {
    const result = await loginUser(q(req.params.user, ""));
    res.status(result.status).json(result.data);
});

router.get("/api/chats/:receiver", async (req, res) => {
    const result = await getChats(q(req.params.receiver, ""), q(req.query.page, 0), q(req.query.page_size, ""));
    if (req.dil() === "en" && result.data && result.data.chats) for (const c of result.data.chats) c.message = etiket(c.message, "en");
    res.status(result.status).json(result.data);
});

router.get("/api/contacts/:user", async (req, res) => {
    const result = await getContacts(q(req.params.user, ""), q(req.query.search_term, ""), q(req.query.page, 0), q(req.query.page_size, 30));
    res.status(result.status).json(result.data);
});

// Telefonun arka plan bildirimleri: since (ms) sonrasinda gelen mesajlar
const notifyPolls = [];   // tani: son sorgularin zamani ve dondurulen sayisi
router.get("/api/notify/:receiver", (req, res) => {
    const result = getNotifications(q(req.params.receiver, ""), q(req.query.since, ""));
    if (req.dil() === "en" && result.data && result.data.items) result.data.items = result.data.items.map((n) => Object.assign({}, n, { text: etiket(n.text, "en") }));
    notifyPolls.push({ t: new Date().toISOString(), since: q(req.query.since, ""), n: (result.data.items || []).length, bg: q(req.query.bg, "") });
    while (notifyPolls.length > 40) notifyPolls.shift();
    res.status(result.status).json(result.data);
});

// ---- Hata raporlari: uygulamalardaki "Rapor gönder" dugmesi ----
// data/reports/<zaman>_<uygulama>.txt, en yeni 60 rapor tutulur
const fs = require("fs");
const REPORT_DIR = path.join(__dirname, "data", "reports");
router.post("/api/report", (req, res) => {
    try {
        const b = req.body || {};
        const appName = ("" + (b.app || "uygulama")).replace(/[^A-Za-z0-9_-]/g, "").slice(0, 30) || "uygulama";
        const text = ("" + (b.text || "")).slice(0, 200000);
        if (!text) return res.status(400).json({ error: "Rapor boş" });
        fs.mkdirSync(REPORT_DIR, { recursive: true });
        const stamp = new Date().toISOString().replace(/[:.]/g, "-");
        const head = `Uygulama: ${appName} ${b.version || ""}\nZaman (sunucu): ${new Date().toISOString()}\nNot: ${b.note || ""}\n\n`;
        fs.writeFileSync(path.join(REPORT_DIR, `${stamp}_${appName}.txt`), head + text);
        const all = fs.readdirSync(REPORT_DIR).filter((f) => f.endsWith(".txt")).sort();
        for (let i = 0; i < all.length - 60; i++) fs.unlinkSync(path.join(REPORT_DIR, all[i]));
        console.log(`[rapor] ${appName} ${b.version || ""} (${text.length} karakter)`);
        res.json({ ok: true });
    } catch (e) {
        res.status(500).json({ error: "Rapor kaydedilemedi: " + e.message });
    }
});

router.get("/api/diag/msgs/:receiver", async (req, res) => {
    try { res.json(await debugMessages(q(req.params.receiver, ""), q(req.query.name, ""), parseInt(req.query.limit, 10) || 5)); }
    catch (e) { res.status(500).json({ error: e.message }); }
});

// Tani: bildirim sorgulari ve kuyruk
router.get("/api/diag/notify/:receiver", (req, res) => {
    res.json({ polls: notifyPolls, queue: getNotifications(q(req.params.receiver, ""), "1").data.items.slice(-15) });
});

router.get("/api/messages/:receiver/:sender", async (req, res) => {
    const result = await getMessages(q(req.params.receiver, ""), q(req.params.sender, ""), q(req.query.limit, ""));
    if (req.dil() === "en" && result.data && result.data.messages) for (const m of result.data.messages) {
        if (m.chatType !== "chat") m.message = etiket(m.message, "en");
        if (m.quote) { m.quote.text = etiket(m.quote.text, "en"); if (m.quote.name === "Sen") m.quote.name = "You"; }
    }
    res.status(result.status).json(result.data);
});

router.post(["/api/messages", "/api/messages/:id"], async (req, res) => {
    const b = req.body || {};
    const result = await sendMessage(b.sender, b.receiver, b.message);
    res.status(result.status).json(result.data);
});

// Konum: { sender, receiver, lat, lng, name?, address? } -> WhatsApp konum mesaji + Google Maps baglantisi
router.post("/api/location", async (req, res) => {
    const b = req.body || {};
    const result = await sendLocation(q(b.sender, ""), q(b.receiver, ""), b.lat, b.lng, b.name, b.address);
    res.status(result.status).json(result.data);
});

// Adres arama (telefon TLS 1.2 konusamadigi icin Photon/Nominatim'e sunucu sorar):
//   GET /api/geo/ara?q=...&lat=..&lng=..   -> { sonuclar: [{ ad, adres, lat, lng }] }
//   GET /api/geo/adres?lat=..&lng=..       -> { ad, adres }  (koordinattan adres)
const GEO_UA = "WhatsBelle/1.9 (Nokia E6 istemcisi)";
function photonOge(f) {
    const p = f.properties || {}, c = (f.geometry && f.geometry.coordinates) || [];
    const ad = p.name || [p.street, p.housenumber].filter(Boolean).join(" ") || p.city || "";
    const adres = [p.name ? [p.street, p.housenumber].filter(Boolean).join(" ") : "", p.district, p.city || p.county, p.state, p.country]
        .filter((x, i, a) => x && a.indexOf(x) === i && x !== ad).join(", ");
    return { ad, adres, lat: +c[1], lng: +c[0] };
}
router.get("/api/geo/ara", async (req, res) => {
    const q = ("" + (req.query.q || "")).trim().slice(0, 200);
    if (!q) return res.json({ sonuclar: [] });
    const lat = parseFloat(req.query.lat), lng = parseFloat(req.query.lng);
    let url = "https://photon.komoot.io/api/?limit=10&q=" + encodeURIComponent(q);
    if (isFinite(lat) && isFinite(lng)) url += "&lat=" + lat + "&lon=" + lng;
    try {
        const r = await fetch(url, { headers: { "user-agent": GEO_UA }, signal: AbortSignal.timeout(12000) });
        const j = await r.json();
        return res.json({ sonuclar: (j.features || []).map(photonOge).filter((o) => isFinite(o.lat) && isFinite(o.lng)) });
    } catch (e) {
        try {   // yedek: Nominatim
            const r = await fetch("https://nominatim.openstreetmap.org/search?format=jsonv2&limit=10&accept-language=tr&q=" + encodeURIComponent(q),
                { headers: { "user-agent": GEO_UA }, signal: AbortSignal.timeout(12000) });
            const j = await r.json();
            return res.json({ sonuclar: (j || []).map((o) => { const p = ("" + o.display_name).split(", "); return { ad: o.name || p[0], adres: p.slice(1).join(", "), lat: +o.lat, lng: +o.lon }; }) });
        } catch (e2) { return res.status(502).json({ error: "Arama yapılamadı: " + e2.message }); }
    }
});
router.get("/api/geo/adres", async (req, res) => {
    const lat = parseFloat(req.query.lat), lng = parseFloat(req.query.lng);
    if (!isFinite(lat) || !isFinite(lng)) return res.status(400).json({ error: "Geçersiz koordinat" });
    try {
        const r = await fetch(`https://photon.komoot.io/reverse?lat=${lat}&lon=${lng}&limit=1`, { headers: { "user-agent": GEO_UA }, signal: AbortSignal.timeout(12000) });
        const j = await r.json();
        const o = j.features && j.features[0] ? photonOge(j.features[0]) : { ad: "", adres: "" };
        res.json({ ad: o.ad, adres: o.adres });
    } catch (e) { res.status(502).json({ error: "Adres bulunamadı: " + e.message }); }
});

// Ifade (tepki): { sender, waId, emoji } (emoji bos: kaldir)
router.post("/api/react", async (req, res) => {
    const b = req.body || {};
    const result = await reactMessage(q(b.sender, ""), b.waId, b.emoji);
    res.status(result.status).json(result.data);
});

router.post(["/api/upload/:id", "/api/upload"], async (req, res) => {
    if (!req.files || !req.files.media) return res.status(400).json({ statusCode: "001", statusDesc: "Dosya gönderilmedi" });
    const result = await uploadMedia(req.files.media, req.body.sender, req.body.receiver);
    res.status(result.status).json(result.data);
});

router.get("/listusers", (req, res) => res.send(listUsers()));

router.get("/debug/screen/:id.png", async (req, res) => {
    try {
        const png = await debugScreenshot(req.params.id);
        if (!png) return res.status(404).send("Oturum yok");
        res.type("png").set("Cache-Control", "no-store").send(png);
    } catch (e) {
        res.status(500).send(e.message);
    }
});

router.get("/debug/state/:id", async (req, res) => {
    try {
        const st = await debugState(req.params.id);
        if (!st) return res.status(404).json({ error: "Oturum yok" });
        res.json(st);
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

router.post("/debug/restart/:id", async (req, res) => {
    await restartClient(req.params.id);
    res.json({ ok: true });
});

module.exports = router;
