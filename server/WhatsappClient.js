// WhatsBelle sunucusu - WhatsApp Web oturumlari ve mesaj kaydi
// whatsapp-web.js uzerine kendi yazdigimiz kopru: oturumlar, sohbet/mesaj okuma, medya donusturme, bildirim kuyrugu.

const { Client, LocalAuth, MessageMedia, Location } = require("whatsapp-web.js");
const fs = require("fs");
const path = require("path");
const os = require("os");
const { PhoneNumberUtil, PhoneNumberFormat } = require("google-libphonenumber");
const phoneUtil = PhoneNumberUtil.getInstance();
const ffmpeg = require("fluent-ffmpeg");
const { db: getDb } = require("./connect.js");

// Telefona gonderilen veri miktarini sinirlayan ayarlar
const CHAT_LIMIT = parseInt(process.env.CHAT_LIMIT || "10", 10);       // sohbet listesinde en fazla
const MSG_LIMIT = parseInt(process.env.MSG_LIMIT || "50", 10);         // bir sohbette varsayilan son mesaj sayisi
const MSG_MAX = 200;                                                   // "daha eski mesajlar" ile en fazla
const KEEP_PER_CHAT = parseInt(process.env.KEEP_PER_CHAT || "20", 10); // sunucuda sohbet basina saklanan
const CHROME_PATH = process.env.CHROME_PATH || "/usr/bin/google-chrome";
// Sohbet listesinde gosterilecek gruplar: adinda bu kelime gecenler ("" = tum gruplar)
const GROUP_FILTER = (process.env.GROUP_FILTER === undefined ? "" : process.env.GROUP_FILTER).toLocaleLowerCase("tr-TR");
const AVATAR_SIZE = parseInt(process.env.AVATAR_SIZE || "40", 10);
const AUTH_DIR = path.join(__dirname, ".wwebjs_auth");
const MEDIA_DIR = path.join(__dirname, "media");

const clients = {};
const authenticatedClients = {};
const qrcodes = {};
const takilma = {};     // hazir olmadan takilan istemciler icin yeniden kurma sayaci
const baslatmaDenemesi = {};  // initialize() hata verince tekrar deneme sayaci

function clean(id) {
    return ("" + (id || "")).replace(/;interface=wifi/i, "").replace(/@c\.us$/, "").trim();
}

function readyClient(id) {
    const c = clients[clean(id)];
    if (c && authenticatedClients[clean(id)] && c.info && c.info.wid) return c;
    return undefined;
}

const NO_SESSION = { status: 401, data: { error: "User session not found" } };

function startClient(id) {
    if (clients[id]) return;

    const client = new Client({
        authStrategy: new LocalAuth({ clientId: id, dataPath: AUTH_DIR }),
        puppeteer: {
            headless: true,
            executablePath: CHROME_PATH,
            args: ["--no-sandbox", "--disable-dev-shm-usage", "--disable-gpu", "--no-first-run", "--mute-audio"]
        }
    });
    clients[id] = client;

    client.on("loading_screen", (percent, message) => console.log(`[${id}] yukleniyor %${percent} ${message || ""}`));
    client.on("authenticated", () => {
        console.log(`[${id}] kimlik dogrulandi`);
        // Kutuphane hatasi: sayfa yeniden enjekte edilince "ready" bazen hic gelmiyor.
        // 45 sn icinde hazir olmazsa kurulumu elle tetikle.
        setTimeout(async () => {
            if (authenticatedClients[id] || clients[id] !== client || !client.pupPage) return;
            console.log(`[${id}] hazir olayi gelmedi, kurulum elle tetikleniyor`);
            try {
                await client.pupPage.evaluate(() => {
                    try { delete window.WWebJS; } catch (e) { window.WWebJS = undefined; }
                    if (typeof window.onAppStateHasSyncedEvent === "function") window.onAppStateHasSyncedEvent();
                });
            } catch (e) {
                console.log(`[${id}] elle tetikleme basarisiz: ${e.message}`);
            }
            // Hala hazir degilse sayfa kopmus demektir (detached frame): istemciyi bastan kur
            setTimeout(() => {
                if (authenticatedClients[id] || clients[id] !== client) return;
                const n = (takilma[id] = (takilma[id] || 0) + 1);
                if (n > 3) { console.log(`[${id}] 3 kez hazir olmadi, birakildi`); return; }
                console.log(`[${id}] hazir olmadi, istemci yeniden kuruluyor (${n}/3)`);
                restartClient(id);
            }, 30000);
        }, 45000);
    });
    client.on("auth_failure", (m) => console.log(`[${id}] kimlik dogrulama hatasi: ${m}`));
    client.on("change_state", (s) => console.log(`[${id}] durum: ${s}`));

    client.on("qr", (qr) => {
        qrcodes[id] = qr;
        console.log(`[${id}] QR kodu olusturuldu`);
    });

    client.on("ready", () => {
        authenticatedClients[id] = id;
        delete qrcodes[id];
        delete takilma[id];
        delete baslatmaDenemesi[id];
        console.log(`[${id}] oturum hazir`);
        // Kisi listesi buyuk olabilir; telefon beklemesin diye onceden hazirla
        setTimeout(() => { loadContacts(id).catch(() => { }); }, 30000);
    });

    client.on("disconnected", async (reason) => {
        console.log(`[${id}] baglanti koptu: ${reason}`);
        delete authenticatedClients[id];
        try { await client.destroy(); } catch (e) { }
        delete clients[id];
        if (reason !== "LOGOUT") setTimeout(() => startClient(id), 10000);
    });

    // Yeni mesaj gelince sohbet listesi onbellegini bosalt
    client.on("message_create", () => { delete chatCache[id]; });
    // Telefona bildirim icin gelen mesajlari kuyruga al
    client.on("message", (msg) => { queueNotify(id, msg).catch(() => { }); });

    client.initialize().catch((err) => {
        console.log(`[${id}] baslatilamadi: ${err.message}`);
        if (clients[id] === client) delete clients[id];
        // Acilista Chrome/sayfa bazen kopuyor ("frame got detached"); oturum dosyalari saglam,
        // telefonda cihaz bagli gorunur. Birakmak yerine Chrome'u kapatip artan aralikla tekrar dene.
        client.destroy().catch(() => { });
        try { require("child_process").execSync("pkill -9 -f 'session-" + id + "' || true"); } catch (e) { }
        const n = (baslatmaDenemesi[id] = (baslatmaDenemesi[id] || 0) + 1);
        if (n > 6) { console.log(`[${id}] 6 kez baslatilamadi, birakildi`); delete baslatmaDenemesi[id]; return; }
        const bekle = Math.min(300, 20 * n);
        console.log(`[${id}] ${bekle} sn sonra tekrar denenecek (${n}/6)`);
        setTimeout(() => { if (!clients[id]) startClient(id); }, bekle * 1000);
    });
}

// Sunucu yeniden basladiginda kayitli oturumlari otomatik ac (QR gerekmez)
function restoreSessions() {
    if (!fs.existsSync(AUTH_DIR)) return;
    // Onceki calismadan kalan Chrome surecleri profili kilitler; temizle
    try { require("child_process").execSync("pkill -9 -f 'wwebjs_auth' || true"); } catch (e) { }
    for (const name of fs.readdirSync(AUTH_DIR)) {
        for (const lock of ["SingletonLock", "SingletonSocket", "SingletonCookie"]) {
            try { fs.unlinkSync(path.join(AUTH_DIR, name, lock)); } catch (e) { }
        }
    }
    for (const name of fs.readdirSync(AUTH_DIR)) {
        if (name.indexOf("session-") === 0) {
            const id = name.substring("session-".length);
            console.log(`Oturum geri yukleniyor: ${id}`);
            startClient(id);
        }
    }
}

const SUPPORTED = ["chat", "image", "video", "audio", "ptt", "sticker", "document", "location", "vcard"];

function runFfmpeg(input, output, options) {
    return new Promise((resolve, reject) => {
        ffmpeg().input(input).outputOptions(options).output(output)
            .on("end", resolve).on("error", reject).run();
    });
}

async function saveMedia(msg, newId) {
    const media = await msg.downloadMedia();
    if (!media || !media.data) return;
    const buf = Buffer.from(media.data, "base64");
    const tmp = path.join(os.tmpdir(), `wa_${newId}_${Date.now()}`);
    fs.writeFileSync(tmp, buf);
    try {
        if (msg.type === "image") {
            // E6 icin kucult: en fazla 640 piksel genislik, JPEG
            await runFfmpeg(tmp, path.join(MEDIA_DIR, `${newId}.jpg`), ["-vf scale='min(640,iw)':-2", "-q:v 5", "-frames:v 1"]);
        } else if (msg.type === "audio" || msg.type === "ptt") {
            await runFfmpeg(tmp, path.join(MEDIA_DIR, `${newId}.mp3`), ["-vn", "-ac 1", "-ar 22050", "-b:a 48k"]);
        } else if (msg.type === "video") {
            await runFfmpeg(tmp, path.join(MEDIA_DIR, `${newId}.3gp`), ["-s 352x288", "-r 15", "-acodec aac", "-ac 1", "-ar 8000", "-b:a 24k"]);
        }
    } finally {
        fs.unlink(tmp, () => { });
    }
}

function removeMediaFiles(id) {
    for (const ext of [".jpg", ".mp3", ".3gp"]) {
        fs.unlink(path.join(MEDIA_DIR, id + ext), () => { });
    }
}

async function prune(owner, peer) {
    const old = await getDb().all(
        `SELECT _id FROM msgs WHERE owner = ? AND peer = ? ORDER BY _id DESC LIMIT -1 OFFSET ?`,
        [owner, peer, KEEP_PER_CHAT]);
    for (const row of old) {
        removeMediaFiles(row._id);
        await getDb().run(`DELETE FROM msgs WHERE _id = ?`, [row._id]);
    }
}

async function saveMessage(owner, client, msg) {
    if (msg.isStatus || msg.from === "status@broadcast" || msg.to === "status@broadcast") return;
    if (SUPPORTED.indexOf(msg.type) < 0) return;

    const fromMe = !!msg.fromMe;
    const peer = fromMe ? msg.to : msg.from;

    let peerName = "";
    try {
        const chat = await msg.getChat();
        peerName = chat && chat.name ? chat.name : "";
    } catch (e) { }

    let senderName = "";
    if (fromMe) {
        senderName = client.info && client.info.pushname ? client.info.pushname : "Ben";
    } else {
        senderName = msg._data && msg._data.notifyName ? msg._data.notifyName : "";
        if (!senderName) {
            try {
                const c = await msg.getContact();
                senderName = c.pushname || c.name || c.number || "";
            } catch (e) { }
        }
    }
    if (!peerName) peerName = fromMe ? clean(peer) : (senderName || clean(peer));

    let text;
    if (msg.type === "chat") text = msg.body || "";
    else if (msg.type === "location") text = "Konum";
    else if (msg.type === "vcard") text = "Kişi kartı";
    else if (msg.body && msg.type !== "sticker" && msg.body.length < 2000) text = msg.body;
    else text = `${msg.type} received`;

    const waId = msg.id && msg.id._serialized ? msg.id._serialized : null;
    const r = await getDb().run(
        `INSERT OR IGNORE INTO msgs(owner, peer, peer_name, from_me, sender_name, message, chat_type, wa_id)
         VALUES(?, ?, ?, ?, ?, ?, ?, ?)`,
        [owner, peer, peerName, fromMe ? 1 : 0, senderName, text, msg.type, waId]);
    if (!r.changes) return;

    console.log(`[${owner}] ${fromMe ? "giden" : "gelen"} ${msg.type} (${peer})`);

    if (msg.hasMedia && ["image", "audio", "ptt", "video"].indexOf(msg.type) >= 0) {
        try { await saveMedia(msg, r.lastID); } catch (e) { console.log(`[${owner}] medya kaydedilemedi: ${e.message}`); }
    }
    await prune(owner, peer);
}

function getStatus(clientId) {
    const c = clients[clientId];
    const ok = authenticatedClients[clientId] !== undefined;
    return {
        isAuthenticated: ok,
        qr: qrcodes[clientId],
        pushname: ok && c && c.info ? (c.info.pushname || "") : null,
        user: ok && c && c.info && c.info.wid ? (c.info.wid.user || "") : null,
        platform: ok && c && c.info ? (c.info.platform || "") : null
    };
}

function getQr(clientId) {
    return qrcodes[clientId];
}

// Tani: sunucudaki WhatsApp Web sayfasinin ekran goruntusu
async function debugScreenshot(clientId) {
    const c = clients[clientId];
    if (!c || !c.pupPage) return null;
    return c.pupPage.screenshot({ type: "png" });
}

async function debugState(clientId) {
    const c = clients[clientId];
    if (!c || !c.pupPage) return null;
    return c.pupPage.evaluate(() => ({
        waVersion: window.Debug && window.Debug.VERSION,
        store: typeof window.Store,
        storeKeys: window.Store ? Object.keys(window.Store).length : 0,
        chatModel: !!(window.Store && window.Store.Chat),
        wwebjs: typeof window.WWebJS,
        authStore: typeof window.AuthStore,
        requireFn: typeof window.require,
        title: document.title
    }));
}

async function restartClient(clientId) {
    const c = clients[clientId];
    delete authenticatedClients[clientId];
    if (c) { try { await c.destroy(); } catch (e) { } delete clients[clientId]; }
    try { require("child_process").execSync("pkill -9 -f 'session-" + clientId + "' || true"); } catch (e) { }
    setTimeout(() => startClient(clientId), 2000);
}

// Giris sayfasindan "QR kodu olustur": oturum hazirsa dokunma; QR zaten varsa bekle;
// aksi halde (takili ya da telefondan cikis yapilmis oturum) eski profili silip temiz QR uret.
async function pairClient(id) {
    if (authenticatedClients[id]) return "hazir";
    if (clients[id] && qrcodes[id]) return "qr";
    const c = clients[id];
    delete clients[id];
    delete qrcodes[id];
    delete takilma[id];
    if (c) { try { await c.destroy(); } catch (e) { } }
    try { require("child_process").execSync("pkill -9 -f 'session-" + id + "' || true"); } catch (e) { }
    try { fs.rmSync(path.join(AUTH_DIR, "session-" + id), { recursive: true, force: true }); } catch (e) { }
    console.log(`[${id}] temiz eslestirme baslatiliyor (QR)`);
    setTimeout(() => startClient(id), 1500);
    return "yeni";
}

function validate(input, countryCode) {
    try {
        if (countryCode == "0") return { valid: false, reason: "Ülke seçin" };
        // Ulke secili olsa da numara 90..., +90..., 0090... ya da 05... bicimlerinde yazilabilir
        let digits = ("" + input).replace(/[^0-9+]/g, "").replace(/^00/, "+");
        let number = phoneUtil.parse(digits, countryCode);
        if (!phoneUtil.isValidNumber(number) && digits.charAt(0) !== "+") {
            const cc = "" + phoneUtil.getCountryCodeForRegion(countryCode);
            if (digits.indexOf(cc) === 0) {
                const alt = phoneUtil.parse("+" + digits, countryCode);
                if (phoneUtil.isValidNumber(alt)) number = alt;
            }
        }
        return {
            valid: phoneUtil.isValidNumber(number),
            reason: phoneUtil.isValidNumber(number) ? "" : "Geçersiz numara",
            formatted: phoneUtil.format(number, PhoneNumberFormat.E164),
            country: phoneUtil.getRegionCodeForNumber(number)
        };
    } catch (e) {
        return { valid: false, reason: e.message };
    }
}

async function loginUser(mobileNumber) {
    try {
        const client = readyClient(mobileNumber);
        if (!client) return NO_SESSION;
        return {
            status: 200,
            data: { pushname: client.info.pushname, user: client.info.wid.user, platform: client.info.platform }
        };
    } catch (error) {
        console.log(error);
        return { status: 500, data: { error: error.message } };
    }
}

// ---- Canli WhatsApp verisi (son N sohbet, sohbet basina son M mesaj) ----

const chatCache = {};      // owner -> { at, data }
const contactCache = {};   // owner -> { at, list, promise }
const CHAT_TTL_MS = 10000;
const CONTACT_TTL_MS = 30 * 60 * 1000;

function tsToStr(unix) {
    if (!unix) return "";
    return new Date(unix * 1000).toISOString().replace("T", " ").substring(0, 19);
}

// Konum mesaji: telefon haritada acabilsin diye koordinat + ad + Google Maps baglantisi
function konumOf(m) {
    if (!m || m.type !== "location" || !m.location) return null;
    const l = m.location;
    const lat = parseFloat(l.latitude), lng = parseFloat(l.longitude);
    if (!isFinite(lat) || !isFinite(lng)) return null;
    const ad = l.name || ("" + (l.description || "")).split("\n")[0] || "";
    const adres = l.address || ("" + (l.description || "")).split("\n").slice(1).join(" ") || "";
    return { lat, lng, ad, adres, url: googleHarita(lat, lng) };
}
function googleHarita(lat, lng) { return "https://maps.google.com/?q=" + (+lat).toFixed(6) + "," + (+lng).toFixed(6); }

function messageText(msg) {
    if (msg.type === "chat") return msg.body || "";
    if (msg.type === "location") { const k = konumOf(msg); return k && k.ad ? "Konum: " + k.ad : "Konum"; }
    if (msg.type === "vcard" || msg.type === "multi_vcard") return "Kişi kartı";
    if (msg.type === "revoked") return "Bu mesaj silindi";
    if (msg.type === "call_log") return msg.fromMe ? "Giden arama" : "Gelen arama";
    if (msg.type === "ciphertext") return "Mesaj bekleniyor...";
    if (msg.type === "poll_creation") return "Anket";
    if (msg.type === "event_creation") return "Etkinlik";
    if (msg.type === "e2e_notification" || msg.type === "notification_template" || msg.type === "gp2" || msg.type === "notification" || msg.type === "protocol") return "Bildirim";
    if (msg.body && msg.type !== "sticker" && msg.body.length < 2000) return msg.body;
    if (MEDIA_TYPES.indexOf(msg.type) >= 0) return `${msg.type} received`;
    // Isletme hesaplari (Meta, Dolap ...): sablon / dugmeli / liste mesajlari; metin baska alanlarda
    const extra = richText(msg);
    if (extra) return extra;
    return `[Bu mesaj türü gösterilemiyor: ${msg.type}. WhatsApp'ta açın.]`;
}

const MEDIA_TYPES = ["image", "video", "audio", "ptt", "sticker", "document"];

// Sablon, dugme, liste ve etkilesimli mesajlardan okunabilir metni toplar
function richText(msg) {
    const d = msg._data || {};
    const parts = [];
    const add = (v) => {
        if (typeof v !== "string") return;
        v = v.trim();
        if (v && v.length < 3000 && parts.indexOf(v) < 0) parts.push(v);
    };
    add(msg.body); add(d.body); add(d.caption); add(d.title); add(d.headerText);
    // Meta AI yanitlari (rich_response): metin parcalari
    try {
        const rr = d.richResponse;
        if (rr && rr.fragments) {
            const t = rr.fragments.map((f) => (f && typeof f.text === "string" ? f.text : (f && f.code ? f.code : ""))).filter(Boolean).join("\n");
            add(t.slice(0, 2900));
        }
        if (!parts.length && d.unifiedResponse && d.unifiedResponse.sections) {
            add(d.unifiedResponse.sections.map((s) => { try { return s.view_model.primitive.text || ""; } catch (e) { return ""; } }).filter(Boolean).join("\n").slice(0, 2900));
        }
    } catch (e) { }
    add(d.description); add(d.contentText); add(d.footer); add(d.footerText);
    add(d.selectedButtonId ? d.selectedDisplayText || "" : ""); add(d.selectedDisplayText);
    add(d.listResponse && d.listResponse.title); add(d.listResponse && d.listResponse.description);
    try {
        const ib = d.interactiveMessage || d.nativeFlowMessage || null;
        if (ib) { add(ib.header && ib.header.title); add(ib.body && ib.body.text); add(ib.footer && ib.footer.text); }
    } catch (e) { }
    try {
        const tp = d.hydratedTemplate || (d.templateMessage && (d.templateMessage.hydratedTemplate || d.templateMessage.hydratedFourRowTemplate));
        if (tp) { add(tp.hydratedTitleText); add(tp.hydratedContentText); add(tp.hydratedFooterText); }
    } catch (e) { }
    try {
        const btns = d.dynamicReplyButtons || d.buttons || d.hydratedButtons || [];
        const labels = [];
        for (const b of btns) {
            const t = (b && (b.buttonText && (b.buttonText.displayText || b.buttonText)) || (b.quickReplyButton && b.quickReplyButton.displayText) || (b.urlButton && b.urlButton.displayText) || (b.callButton && b.callButton.displayText)) || "";
            if (typeof t === "string" && t.trim()) labels.push("[" + t.trim() + "]");
        }
        if (labels.length) parts.push(labels.join(" "));
    } catch (e) { }
    try { if (d.list && d.list.description) add(d.list.description); if (d.list && d.list.buttonText) parts.push("[" + d.list.buttonText + "]"); } catch (e) { }
    return parts.join("\n");
}

// Tani: bir sohbetin son mesajlarinin turleri ve doldurulmus alan adlari
async function debugMessages(receiver, name, limit) {
    const owner = clean(receiver);
    const client = readyClient(owner);
    if (!client) return { error: "oturum yok" };
    const key = ("" + name).toLocaleLowerCase("tr-TR");
    const chats = await client.pupPage.evaluate((k) => {
        const ser = (id) => (id ? (id._serialized || id.$1 || (id.user && id.server ? id.user + "@" + id.server : "")) : "");
        const col = window.require("WAWebCollections");
        return col.Chat.getModelsArray().filter((c) => {
            let t = ""; try { t = (c.formattedTitle || c.name || "").toLocaleLowerCase("tr-TR"); } catch (e) { }
            return t.indexOf(k) >= 0;
        }).slice(0, 3).map((c) => ser(c.id));
    }, key);
    const out = [];
    for (const id of chats) {
        const chat = await client.getChatById(id);
        const msgs = await chat.fetchMessages({ limit: limit || 5 });
        out.push({
            chat: id, msgs: msgs.map((m) => {
                const d = m._data || {};
                const fields = {};
                for (const k of Object.keys(d)) {
                    const v = d[k];
                    if (v === null || v === undefined || v === "" || v === false) continue;
                    if (typeof v === "string") fields[k] = v.slice(0, 120);
                    else if (typeof v === "object") { try { fields[k] = JSON.stringify(v).slice(0, 300); } catch (e) { fields[k] = "[obj]"; } }
                }
                return { type: m.type, body: (m.body || "").slice(0, 100), shown: messageText(m).slice(0, 200), fields };
            })
        });
    }
    return { chats: out };
}

// Medya dosyalari sayisal kimlikle adlandirilir; WhatsApp mesaj kimligini sayiya esle
async function mediaIdFor(owner, peer, msg) {
    const waId = msg.id && msg.id._serialized ? msg.id._serialized : null;
    if (!waId) return null;
    await getDb().run(
        `INSERT OR IGNORE INTO msgs(owner, peer, from_me, chat_type, wa_id) VALUES(?, ?, ?, ?, ?)`,
        [owner, peer, msg.fromMe ? 1 : 0, msg.type, waId]);
    const row = await getDb().get(`SELECT _id FROM msgs WHERE wa_id = ?`, [waId]);
    return row ? row._id : null;
}

function mediaPathFor(type, id) {
    if (type === "image") return path.join(MEDIA_DIR, `${id}.jpg`);
    if (type === "audio" || type === "ptt") return path.join(MEDIA_DIR, `${id}.mp3`);
    if (type === "video") return path.join(MEDIA_DIR, `${id}.3gp`);
    return null;
}

const mediaJobs = {};
function ensureMedia(msg, id) {
    const p = mediaPathFor(msg.type, id);
    if (!p || fs.existsSync(p)) return Promise.resolve();
    if (!mediaJobs[id]) {
        mediaJobs[id] = saveMedia(msg, id)
            .catch((e) => console.log(`medya indirilemedi (${id}): ${e.message}`))
            .then(() => { delete mediaJobs[id]; });
    }
    return mediaJobs[id];
}

function withTimeout(promise, ms) {
    return Promise.race([promise, new Promise((resolve) => setTimeout(resolve, ms))]);
}

// Sohbet listesi sayfali: page_size (varsayilan 20, en fazla 100), page (0..). "Daha eski sohbetler" icin
// istemci ya page degerini artirir ya da page_size degerini buyutur. Yanitta more: daha fazla sohbet var mi.
async function getChats(receiver, pageParam, sizeParam) {
    const size = Math.max(1, Math.min(100, parseInt(sizeParam, 10) || Math.max(CHAT_LIMIT, 20)));
    const page = Math.max(0, parseInt(pageParam, 10) || 0);
    const want = Math.min(400, (page + 1) * size);
    try {
        const owner = clean(receiver);
        const client = readyClient(owner);
        if (!client) return NO_SESSION;

        const kes = (all) => ({ status: 200, data: { chats: all.slice(page * size, (page + 1) * size), more: all.length > want } });
        const cached = chatCache[owner];
        if (cached && cached.want >= want + 1 && Date.now() - cached.at < CHAT_TTL_MS) return kes(cached.data);

        // whatsapp-web.js getChats() guncel WhatsApp Web'de hata verdigi icin
        // sohbetleri dogrudan WhatsApp Web'in kendi deposundan, sadece gereken alanlarla okuyoruz.
        const top = await client.pupPage.evaluate((limit, groupFilter) => {
            // WhatsApp Eylul 2026'da id._serialized alanini id.$1 olarak yeniden adlandirdi
            const ser = (id) => (id ? (id._serialized || id.$1 || (id.user && id.server ? id.user + "@" + id.server : "")) : "");
            const titleOf = (c) => {
                try { return c.formattedTitle || c.name || (c.contact && (c.contact.name || c.contact.pushname)) || ""; } catch (e) { return ""; }
            };
            const isCommunity = (c) => {
                try {
                    const gm = c.groupMetadata;
                    return !!(gm && (gm.isParentGroup || gm.groupType === "COMMUNITY" || gm.isCommunityAnnounce)) || !!c.isParentGroup;
                } catch (e) { return false; }
            };
            const col = window.require("WAWebCollections");
            const models = col.Chat.getModelsArray();
            const list = models
                .filter((c) => {
                    if (!c || !c.id) return false;
                    const s = c.id.server;
                    if (ser(c.id) === "status@broadcast" || s === "newsletter" || s === "broadcast") return false;
                    if (s === "g.us") {
                        // Gruplar: sadece adinda istenen kelime gecenler, topluluklar haric
                        if (isCommunity(c)) return false;
                        const title = titleOf(c).toLocaleLowerCase("tr-TR");
                        return groupFilter === "" || title.indexOf(groupFilter) >= 0;
                    }
                    return true;
                })
                .sort((a, b) => (b.t || 0) - (a.t || 0))
                .slice(0, limit);
            return list.map((c) => {
                let lm = null;
                try {
                    const arr = c.msgs && c.msgs.getModelsArray ? c.msgs.getModelsArray() : [];
                    const m = arr.length ? arr[arr.length - 1] : null;
                    if (m) lm = { body: m.body || m.caption || "", type: m.type, fromMe: !!(m.id && m.id.fromMe), t: m.t };
                } catch (e) { }
                let name = "";
                try { name = c.formattedTitle || c.name || (c.contact && (c.contact.name || c.contact.pushname)) || ""; } catch (e) { }
                return {
                    id: ser(c.id),
                    user: c.id.user,
                    name: name,
                    t: c.t || 0,
                    unread: c.unreadCount || 0,
                    isGroup: c.id.server === "g.us",
                    lm: lm
                };
            });
        }, want + 1, GROUP_FILTER);

        const chats = top.map((c) => {
            const lm = c.lm;
            let text = "";
            if (lm) text = lm.type === "chat" ? lm.body : messageText({ type: lm.type, body: lm.body, fromMe: lm.fromMe });
            const labels = { image: "Fotoğraf", video: "Video", audio: "Ses", ptt: "Sesli mesaj", sticker: "Çıkartma", document: "Belge" };
            if (lm && text === `${lm.type} received`) text = labels[lm.type] || "Medya";
            return {
                _id: c.id,
                sender: c.id,
                senderName: c.name || ("+" + c.user),
                message: (lm && lm.fromMe ? "Sen: " : "") + text,
                chatType: lm ? lm.type : "chat",
                fromMe: !!(lm && lm.fromMe),
                unreadCount: c.unread,
                isGroup: c.isGroup,
                status: 0,
                createdAt: tsToStr(c.t),
                updatedAt: tsToStr(c.t)
            };
        });
        chatCache[owner] = { at: Date.now(), data: chats, want: want + 1 };
        return kes(chats);
    } catch (error) {
        console.log(`getChats hatasi: ${error.message}`);
        kopukKontrol(receiver, error);
        return { status: 500, data: { error: "Sohbetler alınamadı: " + error.message } };
    }
}

async function getMessages(receiver, sender, limitParam) {
    const limit = Math.max(1, Math.min(MSG_MAX, parseInt(limitParam, 10) || MSG_LIMIT));
    try {
        const owner = clean(receiver);
        const client = readyClient(owner);
        if (!client) return NO_SESSION;
        const peer = ("" + sender).replace(/;interface=wifi/i, "");
        const chatId = peer.indexOf("@") >= 0 ? peer : peer + "@c.us";

        const chat = await client.getChatById(chatId);
        if (!chat) return { status: 404, data: { error: "Sohbet bulunamadı" } };

        const msgs = (await chat.fetchMessages({ limit: limit }))
            .filter((m) => m.type !== "e2e_notification" && m.type !== "notification_template" && m.type !== "gp2");
        msgs.reverse();   // en yeni ilk (uygulama tersine cevirip gosterir)

        const me = owner + "@c.us";
        const out = [];
        const waits = [];
        for (const m of msgs) {
            let id = m.id && m.id._serialized ? m.id._serialized : "" + m.timestamp;
            if (m.hasMedia && ["image", "audio", "ptt", "video"].indexOf(m.type) >= 0) {
                const numId = await mediaIdFor(owner, chatId, m);
                if (numId) {
                    id = numId;
                    const job = ensureMedia(m, numId);
                    if (m.type === "image") waits.push(job);   // resimler hazir olsun, ses/video arkada insin
                }
            }
            let senderName = "";
            if (m.fromMe) senderName = client.info.pushname || "Ben";
            else senderName = (m._data && m._data.notifyName) || "";
            const quote = quoteOf(m, me, chat);
            out.push({
                _id: id,
                sender: m.fromMe ? me : chatId,
                receiver: m.fromMe ? chatId : me,
                message: messageText(m),
                status: m.ack || 0,
                senderName: senderName,
                chatType: m.type,
                quote: quote,
                waId: m.id && m.id._serialized ? m.id._serialized : "",     // ifade (tepki) gondermek icin
                location: konumOf(m),
                deviceType: "",
                createdAt: tsToStr(m.timestamp),
                updatedAt: tsToStr(m.timestamp)
            });
        }
        if (waits.length) await withTimeout(Promise.all(waits), 15000);
        return { status: 200, data: { messages: out } };
    } catch (error) {
        console.log(`getMessages hatasi: ${error.message}`);
        kopukKontrol(receiver, error);
        return { status: 500, data: { error: "Mesajlar alınamadı: " + error.message } };
    }
}

// ---- Alinti (yanitlanan mesaj) ----
const QUOTE_LABELS = {
    image: "Alıntılanan fotoğraf", video: "Alıntılanan video", audio: "Alıntılanan ses", ptt: "Alıntılanan sesli mesaj",
    sticker: "Alıntılanan çıkartma", document: "Alıntılanan belge", location: "Alıntılanan konum", vcard: "Alıntılanan kişi kartı"
};
function firstWords(s, n) {
    const w = ("" + (s || "")).replace(/\s+/g, " ").trim().split(" ");
    return w.length > n ? w.slice(0, n).join(" ") + "…" : w.join(" ");
}
function quoteOf(m, me, chat) {
    try {
        if (!m.hasQuotedMsg || !m._data || !m._data.quotedMsg) return null;
        const q = m._data.quotedMsg;
        const text = q.type === "chat" ? firstWords(q.body, 10) : (QUOTE_LABELS[q.type] || "Alıntılanan mesaj");
        let qp = m._data.quotedParticipant;
        if (qp && typeof qp === "object") qp = qp._serialized || qp.$1 || (qp.user ? qp.user + "@" + qp.server : "");
        qp = "" + (qp || "");
        let name = "";
        if (qp && clean(qp) === clean(me)) name = "Sen";
        else if (chat && !chat.isGroup) name = chat.name || "";
        else if (qp) name = contactName(qp) || ("+" + clean(qp).replace(/@.*/, ""));
        return { name: name, text: text || "…" };
    } catch (e) { return null; }
}
function contactName(waId) {
    try {
        const num = clean(waId).replace(/@.*/, "");
        const list = contactsFromFile();
        if (!list) return "";
        const hit = list.find((c) => ("" + c.id).replace(/@.*/, "").replace(/\D/g, "").slice(-10) === num.slice(-10));
        return hit ? (hit.name || "") : "";
    } catch (e) { return ""; }
}

// ---- Bildirim kuyrugu (telefon belli araliklarla sorar) ----
const notifyQueue = {};   // owner -> [{ t, chat, title, text }]
async function queueNotify(owner, msg) {
    if (msg.fromMe || msg.isStatus || msg.from === "status@broadcast") return;
    if (!msg.from || /@(newsletter|broadcast)$/.test(msg.from)) return;
    if (["e2e_notification", "notification_template", "gp2", "protocol", "revoked", "ciphertext"].indexOf(msg.type) >= 0) return;
    let chat = null;
    try { chat = await msg.getChat(); } catch (e) { }
    const isGroup = /@g\.us$/.test(msg.from);
    const chatName = (chat && chat.name) || "";
    if (isGroup) {
        if (GROUP_FILTER && chatName.toLocaleLowerCase("tr-TR").indexOf(GROUP_FILTER) < 0) return;
        try { const gm = chat.groupMetadata; if (gm && (gm.isParentGroup || gm.announce && gm.isCommunityAnnounce)) return; } catch (e) { }
    }
    const labels = { image: "Fotoğraf", video: "Video", audio: "Ses", ptt: "Sesli mesaj", sticker: "Çıkartma", document: "Belge", location: "Konum", vcard: "Kişi kartı" };
    let text;
    if (msg.type === "chat") text = msg.body || "";
    else if (labels[msg.type]) {
        text = labels[msg.type];
        if (msg.body && msg.type !== "sticker" && msg.body.length < 300) text += ": " + msg.body;
    } else text = richText(msg) || "Mesaj";
    const sender = (msg._data && msg._data.notifyName) || "";
    if (isGroup && sender) text = sender + ": " + text;
    text = text.replace(/\s+/g, " ").trim();
    if (text.length > 90) text = text.slice(0, 88) + "…";
    const q = notifyQueue[owner] || (notifyQueue[owner] = []);
    q.push({ t: Date.now(), chat: msg.from, title: chatName || sender || ("+" + clean(msg.from).replace(/@.*/, "")), text });
    while (q.length > 60) q.shift();
}
// Baska kaynaklardan (e-posta) gelen bildirimleri tum oturumlarin kuyruguna ekler
function pushExternalNotify(title, text) {
    const owners = Object.keys(clients).length ? Object.keys(clients) : Object.keys(notifyQueue);
    for (const owner of owners) {
        const q = notifyQueue[owner] || (notifyQueue[owner] = []);
        q.push({ t: Date.now(), chat: "mail", title: ("" + title).slice(0, 60), text: ("" + text).replace(/\s+/g, " ").slice(0, 90) });
        while (q.length > 60) q.shift();
    }
    console.log(`[bildirim] posta kuyruga eklendi (${owners.length} oturum)`);
}
function getNotifications(receiver, since) {
    const owner = clean(receiver);
    const now = Date.now();
    const s = parseInt(since || "0", 10) || now;
    const items = (notifyQueue[owner] || []).filter((n) => n.t > s);
    return { status: 200, data: { now: now, items: items, session: !!readyClient(owner) } };
}

// Kullanicinin sectigi kisiler (data/contacts.json, rehberden aktarilan .vcf'den uretilir).
// Dosya varsa WhatsApp'in binlerce kisilik listesi yerine bu kullanilir.
const CONTACTS_FILE = path.join(__dirname, "data", "contacts.json");
let fileContacts = null;
let fileContactsMtime = 0;
function contactsFromFile() {
    try {
        const st = fs.statSync(CONTACTS_FILE);
        if (!fileContacts || st.mtimeMs !== fileContactsMtime) {
            const arr = JSON.parse(fs.readFileSync(CONTACTS_FILE, "utf8"));
            fileContacts = arr.filter((c) => c && c.id && c.name).map((c) => ({ id: c.id, name: c.name, saved: true }));
            fileContacts.sort((a, b) => a.name.localeCompare(b.name, "tr"));
            fileContactsMtime = st.mtimeMs;
            console.log(`${fileContacts.length} secili kisi dosyadan yuklendi`);
        }
        return fileContacts;
    } catch (e) {
        return null;
    }
}

function loadContacts(owner) {
    const client = readyClient(owner);
    if (!client) return Promise.reject(new Error("no session"));
    const fromFile = contactsFromFile();
    if (fromFile) return Promise.resolve(fromFile);
    const c = contactCache[owner];
    if (c && c.list && Date.now() - c.at < CONTACT_TTL_MS) return Promise.resolve(c.list);
    if (c && c.promise) return c.promise;

    const started = Date.now();
    const promise = client.getContacts().then((contacts) => {
        const seen = {};
        const list = [];
        for (const x of contacts) {
            if (!x.id || x.id.server !== "c.us" || x.isWAContact !== true || x.isMe) continue;
            if (seen[x.id._serialized]) continue;
            seen[x.id._serialized] = true;
            const saved = x.isMyContact === true && x.name;
            list.push({ id: x.id._serialized, name: saved ? x.name : (x.pushname || ("+" + x.id.user)), saved: !!saved });
        }
        // Rehberde kayitli olanlar once, sonra alfabetik
        list.sort((a, b) => (a.saved === b.saved ? a.name.localeCompare(b.name, "tr") : (a.saved ? -1 : 1)));
        contactCache[owner] = { at: Date.now(), list: list };
        console.log(`[${owner}] ${list.length} kisi hazirlandi (${Math.round((Date.now() - started) / 1000)} sn)`);
        return list;
    }).catch((e) => {
        delete contactCache[owner];
        throw e;
    });
    contactCache[owner] = { at: 0, list: c ? c.list : null, promise: promise };
    return promise;
}

async function getContacts(mobileNumber, searchTerm, page, pageSize) {
    try {
        const owner = clean(mobileNumber);
        if (!readyClient(owner)) return NO_SESSION;

        const cached = contactCache[owner];
        let list = contactsFromFile();
        if (list) {
            // secili kisiler dosyasi kullaniliyor
        } else if (cached && cached.list) {
            list = cached.list;
            if (Date.now() - cached.at >= CONTACT_TTL_MS) loadContacts(owner).catch(() => { });
        } else {
            // Ilk yukleme uzun surebilir: 20 sn icinde bitmezse telefona "hazirlaniyor" de
            list = await withTimeout(loadContacts(owner), 20000);
            if (!list) return { status: 503, data: { error: "Kişi listesi hazırlanıyor, biraz sonra tekrar deneyin." } };
        }

        const term = ("" + searchTerm).toLowerCase();
        const filtered = term ? list.filter((c) => c.name.toLowerCase().indexOf(term) >= 0 || c.id.indexOf(term) >= 0) : list;
        const size = Math.min(parseInt(pageSize, 10) || 30, 50);
        const start = (parseInt(page, 10) || 0) * size;
        const pageItems = filtered.slice(start, start + size).map((c) => ({ id: c.id, name: c.name }));
        return { status: 200, data: { contacts: pageItems, count: filtered.length } };
    } catch (error) {
        console.log(`getContacts hatasi: ${error.message}`);
        kopukKontrol(mobileNumber, error);
        return { status: 500, data: { error: "Kişiler alınamadı: " + error.message } };
    }
}

// ---- Profil resimleri: kucuk, yuvarlak PNG (varsayilan 40x40) ----
const AVATAR_DIR = path.join(MEDIA_DIR, "avatars");
const AVATAR_TTL_MS = 24 * 60 * 60 * 1000;
const avatarJobs = {};

async function getAvatar(owner, peer) {
    const client = readyClient(owner);
    if (!client) return null;
    const id = ("" + peer).replace(/;interface=wifi/i, "");
    if (!/^[0-9A-Za-z.\-]+@(c\.us|g\.us|lid)$/.test(id)) return null;
    if (!fs.existsSync(AVATAR_DIR)) fs.mkdirSync(AVATAR_DIR, { recursive: true });
    const base = path.join(AVATAR_DIR, id.replace(/[@.]/g, "_"));
    const file = base + ".png";
    const none = base + ".none";
    try { if (Date.now() - fs.statSync(file).mtimeMs < AVATAR_TTL_MS) return file; } catch (e) { }
    try { if (Date.now() - fs.statSync(none).mtimeMs < AVATAR_TTL_MS) return null; } catch (e) { }
    if (avatarJobs[file]) return avatarJobs[file];

    avatarJobs[file] = (async () => {
        let url = null;
        try { url = await client.getProfilePicUrl(id); } catch (e) { }
        if (!url) { fs.writeFileSync(none, ""); return null; }
        const r = await fetch(url);
        if (!r.ok) { fs.writeFileSync(none, ""); return null; }
        const tmp = path.join(os.tmpdir(), `av_${Date.now()}_${Math.random().toString(36).slice(2)}.jpg`);
        fs.writeFileSync(tmp, Buffer.from(await r.arrayBuffer()));
        const s = AVATAR_SIZE, c = (s - 1) / 2, rad = s / 2;
        try {
            // Kare kirp, kucult, kenarlari yumusak daire seklinde saydam yap
            await runFfmpeg(tmp, file, [
                `-vf scale=${s}:${s}:force_original_aspect_ratio=increase,crop=${s}:${s},format=rgba,` +
                `geq=r='r(X\\,Y)':g='g(X\\,Y)':b='b(X\\,Y)':a='255*clip(${rad + 0.5}-hypot(X-${c}\\,Y-${c})\\,0\\,1)'`,
                "-frames:v 1", "-pix_fmt rgba"
            ]);
        } finally {
            fs.unlink(tmp, () => { });
        }
        try { fs.unlinkSync(none); } catch (e) { }
        return file;
    })().catch((e) => {
        console.log(`profil resmi alinamadi (${id}): ${e.message}`);
        return null;
    }).finally(() => { delete avatarJobs[file]; });
    return avatarJobs[file];
}

// ---- Telefondan medya gonderme ----
const IMAGE_EXT = [".jpg", ".jpeg", ".png", ".gif", ".bmp"];
const VIDEO_EXT = [".mp4", ".3gp", ".3g2", ".mov", ".avi", ".m4v", ".mkv"];
const AUDIO_EXT = [".amr", ".mp3", ".wav", ".aac", ".m4a", ".ogg", ".awb", ".wma"];

function mediaKind(media) {
    const ext = path.extname(media.name || "").toLowerCase();
    const mt = ("" + (media.mimetype || "")).toLowerCase();
    if (IMAGE_EXT.indexOf(ext) >= 0 || mt.indexOf("image/") === 0) return "image";
    if (VIDEO_EXT.indexOf(ext) >= 0 || mt.indexOf("video/") === 0) return "video";
    if (AUDIO_EXT.indexOf(ext) >= 0 || mt.indexOf("audio/") === 0) return "audio";
    return "document";
}

async function uploadMedia(media, sender, receiver) {
    const tmpFiles = [];
    try {
        const client = readyClient(sender);
        if (!client) return { status: 401, data: { statusCode: "002", statusDesc: "User session not found" } };
        const to = ("" + receiver).indexOf("@") >= 0 ? receiver : receiver + "@c.us";

        const kind = mediaKind(media);
        const ext = path.extname(media.name || "").toLowerCase() || ".bin";
        const tmpIn = path.join(os.tmpdir(), `up_${Date.now()}${ext}`);
        tmpFiles.push(tmpIn);
        fs.writeFileSync(tmpIn, media.data);
        console.log(`[${clean(sender)}] gonderiliyor: ${kind} ${ext} ${Math.round(media.data.length / 1024)} KB`);

        if (kind === "image") {
            let file = tmpIn;
            if (ext === ".bmp") {
                file = tmpIn + ".jpg"; tmpFiles.push(file);
                await runFfmpeg(tmpIn, file, ["-q:v 3", "-frames:v 1"]);
            }
            await client.sendMessage(to, MessageMedia.fromFilePath(file));
        } else if (kind === "video") {
            // WhatsApp icin MP4 / H.264 / AAC
            const out = tmpIn + ".mp4"; tmpFiles.push(out);
            await runFfmpeg(tmpIn, out, [
                "-vf scale='min(640,iw)':-2", "-c:v libx264", "-profile:v baseline", "-level 3.0",
                "-preset veryfast", "-crf 28", "-pix_fmt yuv420p", "-c:a aac", "-b:a 64k", "-ac 1", "-movflags +faststart"
            ]);
            await client.sendMessage(to, MessageMedia.fromFilePath(out));
        } else if (kind === "audio") {
            // WhatsApp sesli mesaj formati: OGG / Opus
            const out = tmpIn + ".ogg"; tmpFiles.push(out);
            await runFfmpeg(tmpIn, out, ["-vn", "-ac 1", "-ar 48000", "-c:a libopus", "-b:a 24k", "-application voip"]);
            await client.sendMessage(to, MessageMedia.fromFilePath(out), { sendAudioAsVoice: true });
        } else {
            const m = MessageMedia.fromFilePath(tmpIn);
            m.filename = media.name || ("dosya" + ext);
            await client.sendMessage(to, m, { sendMediaAsDocument: true });
        }
        delete chatCache[clean(sender)];
        return { status: 200, data: { statusCode: "000", statusDesc: "media uploaded successfully", kind: kind } };
    } catch (error) {
        console.log(`medya gonderilemedi: ${error && error.message ? error.message : error}`);
        kopukKontrol(sender, error);
        return { status: 500, data: { statusCode: "003", statusDesc: "Gönderilemedi: " + (error && error.message ? error.message.split("\n")[0] : error) } };
    } finally {
        for (const f of tmpFiles) fs.unlink(f, () => { });
    }
}

async function sendMessage(sender, receiver, message) {
    try {
        const client = readyClient(sender);
        if (!client) return { status: 401, data: { statusCode: "002", statusDesc: "User session not found" } };
        if (!message || ("" + message).trim() === "") return { status: 400, data: { error: "Boş mesaj" } };

        const to = ("" + receiver).indexOf("@") >= 0 ? receiver : receiver + "@c.us";
        await client.sendMessage(to, "" + message);   // kayit message_create ile yapilir
        return { status: 200, data: { message: "message sent successfully" } };
    } catch (error) {
        const line = ("" + error.message).split(/\r?\n/)[0];
        console.log(`Mesaj gonderilemedi: ${line}`);
        kopukKontrol(sender, error);
        return { status: 500, data: { error: "Mesaj gönderilemedi: " + line } };
    }
}

// Konum gonder: gercek WhatsApp konum mesaji (Android/iOS'ta dokununca harita uygulamasi acilir) +
// Google Maps baglantisi (konumun "url" alani; desteklemeyen istemcide metin olarak gider)
async function sendLocation(sender, receiver, lat, lng, name, address) {
    try {
        const client = readyClient(sender);
        if (!client) return { status: 401, data: { statusCode: "002", statusDesc: "User session not found" } };
        lat = parseFloat(lat); lng = parseFloat(lng);
        if (!isFinite(lat) || !isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) return { status: 400, data: { error: "Geçersiz koordinat" } };
        const to = ("" + receiver).indexOf("@") >= 0 ? receiver : receiver + "@c.us";
        const url = googleHarita(lat, lng);
        const opt = { url };
        if (name) opt.name = ("" + name).slice(0, 120);
        if (address) opt.address = ("" + address).slice(0, 200);
        try {
            await client.sendMessage(to, new Location(lat, lng, opt));
        } catch (e) {
            // eski / uyumsuz surum: baglanti olarak gonder
            console.log(`konum mesaji gonderilemedi (${("" + e.message).split("\n")[0]}), baglanti olarak gidiyor`);
            await client.sendMessage(to, (name ? "📍 " + name + "\n" : "📍 ") + (address ? address + "\n" : "") + url);
        }
        return { status: 200, data: { message: "location sent", url } };
    } catch (error) {
        const line = ("" + error.message).split(/\r?\n/)[0];
        console.log(`Konum gonderilemedi: ${line}`);
        kopukKontrol(sender, error);
        return { status: 500, data: { error: "Konum gönderilemedi: " + line } };
    }
}

// Mesaja ifade (tepki) birak; bos emoji tepkiyi kaldirir
async function reactMessage(sender, waId, emoji) {
    try {
        const client = readyClient(sender);
        if (!client) return { status: 401, data: { statusCode: "002", statusDesc: "User session not found" } };
        if (!waId) return { status: 400, data: { error: "Mesaj kimliği yok" } };
        const m = await client.getMessageById("" + waId);
        if (!m) return { status: 404, data: { error: "Mesaj bulunamadı" } };
        await m.react(emoji ? "" + emoji : "");
        return { status: 200, data: { ok: true } };
    } catch (error) {
        const line = ("" + error.message).split(/\r?\n/)[0];
        console.log(`Ifade gonderilemedi: ${line}`);
        kopukKontrol(sender, error);
        return { status: 500, data: { error: "İfade gönderilemedi: " + line } };
    }
}

function listUsers() {
    let html = "<style>table,th,td{border:1px solid #ccc;border-collapse:collapse;padding:6px}</style><table>";
    html += "<tr><th>Numara</th><th>Ad</th><th>Durum</th></tr>";
    for (const id in clients) {
        const c = clients[id];
        html += `<tr><td>${id}</td><td>${c.info && c.info.pushname ? c.info.pushname : ""}</td><td>${authenticatedClients[id] ? "hazır" : "bekliyor"}</td></tr>`;
    }
    return html + "</table>";
}

// WhatsApp Web oturum hazir olduktan sonra sayfayi kendi kendine yeniden yukleyebiliyor; puppeteer eski cerceveye
// bagli kalinca her istek "detached Frame" hatasi verir ve telefon "oturum yok" gibi gorur. Boyle bir hata
// gorulunce istemci (QR gerekmeden) bastan kurulur; en fazla 3 dakikada bir.
const kopukZaman = {};
function kopukKontrol(id, err) {
    const m = "" + (err && err.message ? err.message : err);
    if (!/detached Frame|Execution context was destroyed|Session closed|Target closed|Protocol error/i.test(m)) return;
    id = clean(id);
    if (!clients[id] || Date.now() - (kopukZaman[id] || 0) < 180000) return;
    kopukZaman[id] = Date.now();
    console.log(`[${id}] sayfa baglantisi kopmus (${m.split("\n")[0].slice(0, 80)}), istemci yeniden kuruluyor`);
    restartClient(id);
}

// Web paneli: oturumu hazir WhatsApp hesaplari (numara + ad)
function hazirHesaplar() {
    return Object.keys(authenticatedClients).map((id) => { const c = clients[id]; return { id, ad: c && c.info ? (c.info.pushname || "") : "" }; });
}

module.exports = {
    hazirHesaplar, startClient, pairClient, restoreSessions, sendMessage, sendLocation, reactMessage, getStatus, getQr, validate, debugScreenshot, debugState, restartClient,
    loginUser, getChats, getContacts, uploadMedia, getMessages, listUsers, getAvatar, getNotifications, pushExternalNotify, debugMessages
};
