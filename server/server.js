const express = require("express");
const fileUpload = require("express-fileupload");
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const messageRouter = require("./messageRouter.js");
const { initializeDatabase } = require("./connect.js");
const { restoreSessions } = require("./WhatsappClient.js");

const KEY = process.env.BELLE_KEY || process.env.E6_KEY || "";   // E6_KEY: eski ad
const PORT = parseInt(process.env.PORT || "3000", 10);

if (!KEY) {
    console.error("BELLE_KEY ortam degiskeni tanimli degil; sunucu parolasiz calismayacak.");
    process.exit(1);
}

function safeEqual(a, b) {
    if (typeof a !== "string" || typeof b !== "string") return false;
    const ba = Buffer.from(a);
    const bb = Buffer.from(b);
    return ba.length === bb.length && crypto.timingSafeEqual(ba, bb);
}

// Parola kontrolu:
//  - WhatsBelle uygulamasi:  "X-Api-Key" basligi
//  - Medya/indirme linkleri: ?key=... (telefonun tarayicisi baslik gonderemez)
//  - Bilgisayardaki QR sayfasi: tarayicinin kullanici adi/parola penceresi (Basic auth)
const anahtar = require("./anahtar.js");   // asil + ikinci parola (.bellekey2)
const keyOk = anahtar.ok;
// panel.js parolayi safeEqual(girilen, KEY) ile denetler: KEY ile karsilastirmada ikinci parola da gecerli olsun
const panelEsit = (a, b) => (b === KEY ? keyOk(a) : safeEqual(a, b));
const MAIL_TOKEN = crypto.createHmac("sha256", KEY || "-").update("e6mail-cerez").digest("hex");

function auth(req, res, next) {
    if (req.path === "/panel/giris" || req.path === "/panel/stil.css") return next();      // panel giris sayfasi parolasiz acilir
    const header = req.get("x-api-key");
    const query = typeof req.query.key === "string" ? req.query.key.replace(/;interface=wifi/i, "") : undefined;
    let basic;
    const a = req.get("authorization");
    if (a && a.indexOf("Basic ") === 0) {
        const decoded = Buffer.from(a.substring(6), "base64").toString("utf8");
        basic = decoded.substring(decoded.indexOf(":") + 1);
    }
    if (keyOk(header) || keyOk(query) || keyOk(basic)) {
        // Posta sayfalari ?key= ile acildiysa: cerez ver, parolasiz adrese yonlendir
        if (query && req.method === "GET" && (req.path.indexOf("/mail") === 0 || req.path.indexOf("/drive") === 0 || req.path.indexOf("/panel") === 0 || req.path === "/tb/oku")) {
            res.set("Set-Cookie", `e6m=${MAIL_TOKEN}; Path=/; Max-Age=31536000; HttpOnly; SameSite=Lax`);
            const rest = Object.keys(req.query).filter((k) => k !== "key").map((k) => encodeURIComponent(k) + "=" + encodeURIComponent(req.query[k])).join("&");
            return res.redirect(req.path + (rest ? "?" + rest : ""));
        }
        return next();
    }
    // Posta sayfalari: "Mail" uygulamasinin verdigi cerez (parolanin kendisi degil, ondan turetilmis anahtar)
    if (req.path.indexOf("/mail") === 0 || req.path.indexOf("/drive") === 0 || req.path.indexOf("/panel") === 0 || req.path.indexOf("/tb/") === 0 || req.path.indexOf("/yt/") === 0 || req.path.indexOf("/ai/") === 0) {
        const m = /(?:^|;\s*)e6m=([0-9a-f]{64})/.exec(req.get("cookie") || "");
        if (m && safeEqual(m[1], MAIL_TOKEN)) return next();
    }

    if (req.path.indexOf("/panel") === 0) return res.redirect("/panel/giris");
    if (req.path.indexOf("/api/") === 0) {
        return res.status(403).json({ error: "Sunucu parolası hatalı. WhatsBelle ayarlarından parolayı kontrol edin." });
    }
    res.set("WWW-Authenticate", 'Basic realm="WhatsBelle", charset="UTF-8"');
    return res.status(401).send("Parola gerekli");
}

const app = express();
app.disable("x-powered-by");
app.set("trust proxy", "loopback");
// Tarayicinin kendiliginden istedigi site simgesi parolaya takilip her sayfada parola penceresi acmasin
app.get(/^\/(favicon\.ico|apple-touch-icon[\w-]*\.png)$/, (req, res) => res.set("Cache-Control", "public, max-age=2592000").status(204).end());
// Ana sayfa: web paneli (giris yapilmamissa panel giris ekranina yonlenir). Eski WhatsApp sayfasi: /whatsapp
app.get("/", (req, res) => res.redirect("/panel"));
// Dil: JSON hata mesajlari ve HTML sayfalar istegin diline cevrilir (dil.js; BELLE_LANG / X-Lang)
app.use(require("./dil.js").araKatman);
app.use(auth);
app.use(fileUpload({ limits: { fileSize: 16 * 1024 * 1024 } }));
app.use(express.json({ limit: "6mb" }));   // ApiLauncher fotografli sohbet gecmisi icin
app.use(require("./youtube.js"));   // BelleTube: /yt/...
app.use(require("./google.js"));    // BelleTube: Google hesabi (/yt/auth, /yt/feed ...)
app.use(require("./ai.js"));        // ApiLauncher: /ai/... (sunucu uzerinden mod)
// BelleMail: /mail (sunucu tarafli e-posta sayfalari); yeni postalar WhatsBelle bildirimine gider
const mail = require("./mail.js");
mail.setNotifyHook(require("./WhatsappClient.js").pushExternalNotify);
app.use(mail.router);
// Belle Drive: /drive (Google Drive sayfalari, yukleme); Drive'a yeni dosya gelince WhatsBelle bildirimi
const drive = require("./drive.js");
drive.setNotifyHook(require("./WhatsappClient.js").pushExternalNotify);
app.use(drive);
// BelleRemote: telefon <-> PC aktarıcı (/uzak/liste burada; /uzak/baglan HTTP upgrade ile, aşağıda)
const uzak = require("./uzak.js");
app.use(uzak.router);
// Sunucu tarayicisi (Belle Remote "Tarayici" sekmesi): /uzak/baglan?hedef=tarayici, indirme: /uzak/indir/:id
const tarayici = require("./tarayici.js");
tarayici.driveBagla(drive);
app.use(tarayici.router);
// Belle Browser sunucu katmani: /tb/g (vekil + resim kucultme), /tb/oku (okuma modu), /tb/durum
// Okuma modu (Readability) ve sade gorunum (Chrome'da acilip tek sutuna indirilmis sayfa): /tb/oku, /tb/sade
app.use(require("./okuyucu.js").router);
const katman = require("./katman.js");
katman.reklamBagla(tarayici.reklamMi);
app.use(katman.router);
// Web paneli: /panel (uygulamalar + basit yonetim); parola: tarayicinin kullanici adi/parola penceresi
const panel = require("./panel.js")({ KEY, TOKEN: MAIL_TOKEN, safeEqual: panelEsit, katman, tarayici, uzak, drive });
app.use(panel.router);
app.use(messageRouter);

const mediaPath = path.join(__dirname, "media");
if (!fs.existsSync(mediaPath)) fs.mkdirSync(mediaPath);

initializeDatabase().then(() => {
    const httpServer = app.listen(PORT, "127.0.0.1", () => console.log(`Sunucu hazir: 127.0.0.1:${PORT}`));
    uzak.attach(httpServer, KEY);
    panel.attach(httpServer);     // /panel/ws: web uzak masaustu / sunucu tarayicisi (WebSocket kopru)
    restoreSessions();
}).catch((err) => {
    console.error("Veritabani baslatilamadi:", err);
    process.exit(1);
});
