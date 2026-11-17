// BelleTube - Google hesabi entegrasyonu (YouTube Data API v3, yalnizca okuma)
//
// Giris: OAuth 2.0 "cihaz akisi" (TV ve sinirli giris cihazlari icin). Telefon kisa bir kod
// gosterir; kullanici bilgisayardan/baska telefondan google.com/device adresine girip kodu yazar.
// Telefonda Google parolasi girilmez; yenileme anahtari yalnizca bu sunucuda (data/) saklanir.
//
// Kurulum (bir kez): Google Cloud Console'da "TVs and Limited Input devices" turunde OAuth
// istemcisi olusturulur, istemci kimligi ve gizli anahtari /yt/setup sayfasindan girilir.

const express = require("express");
const fs = require("fs");
const path = require("path");
const os = require("os");
const ffmpeg = require("fluent-ffmpeg");

const router = new express.Router();
router.use(express.urlencoded({ extended: false, limit: "16kb" }));

const DATA_DIR = path.join(__dirname, "data");
const CFG_FILE = path.join(DATA_DIR, "google.json");
const TOKEN_FILE = path.join(DATA_DIR, "google_token.json");
const IMG_DIR = path.join(__dirname, "media", "yt", "img");
const SCOPE = "https://www.googleapis.com/auth/youtube.readonly";
const API = "https://www.googleapis.com/youtube/v3/";

for (const d of [DATA_DIR, IMG_DIR]) if (!fs.existsSync(d)) fs.mkdirSync(d, { recursive: true });

function readJson(file) { try { return JSON.parse(fs.readFileSync(file, "utf8")); } catch (e) { return null; } }
function writeJson(file, obj) { fs.writeFileSync(file, JSON.stringify(obj, null, 1), { mode: 0o600 }); }

let cfg = readJson(CFG_FILE);        // { client_id, client_secret }
let token = readJson(TOKEN_FILE);    // { refresh_token, access_token, expires_at, channel }
let pending = null;                  // devam eden cihaz akisi

// ---------- Yardimcilar ----------

function form(obj) { return new URLSearchParams(obj).toString(); }

async function postForm(url, obj) {
    const r = await fetch(url, { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: form(obj) });
    let j = {};
    try { j = await r.json(); } catch (e) { }
    return { ok: r.ok, status: r.status, body: j };
}

async function accessToken() {
    if (!token || !token.refresh_token) throw Object.assign(new Error("Google hesabı bağlı değil"), { code: 401 });
    if (token.access_token && token.expires_at > Date.now() + 60000) return token.access_token;
    const r = await postForm("https://oauth2.googleapis.com/token", {
        client_id: cfg.client_id, client_secret: cfg.client_secret,
        refresh_token: token.refresh_token, grant_type: "refresh_token"
    });
    if (!r.ok) {
        if (r.body.error === "invalid_grant") {           // izin geri alinmis / suresi dolmus
            token = null;
            try { fs.unlinkSync(TOKEN_FILE); } catch (e) { }
            throw Object.assign(new Error("Google izni geçersiz; hesabı yeniden bağlayın"), { code: 401 });
        }
        throw new Error("Google anahtarı yenilenemedi: " + (r.body.error_description || r.body.error || r.status));
    }
    token.access_token = r.body.access_token;
    token.expires_at = Date.now() + (r.body.expires_in || 3600) * 1000;
    writeJson(TOKEN_FILE, token);
    return token.access_token;
}

async function yt(endpoint, params) {
    const at = await accessToken();
    const url = API + endpoint + "?" + new URLSearchParams(params).toString();
    const r = await fetch(url, { headers: { Authorization: "Bearer " + at } });
    const j = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error("YouTube API: " + ((j.error && j.error.message) || r.status));
    return j;
}

function sendErr(res, e) {
    const code = e.code === 401 ? 401 : 502;
    if (code !== 401) console.log("[google]", e.message);
    // 401'i WhatsApp oturumu hatasiyla karistirmamak icin uygulama "needLogin" alanina bakar
    res.status(code === 401 ? 409 : 502).json({ error: e.message, needLogin: code === 401 });
}

function isoDur(s) {        // PT1H2M3S -> "1:02:03"
    const m = /PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/.exec(s || "");
    if (!m) return { text: "", sec: 0 };
    const h = +(m[1] || 0), mi = +(m[2] || 0), se = +(m[3] || 0);
    const sec = h * 3600 + mi * 60 + se;
    const pad = (n) => (n < 10 ? "0" : "") + n;
    return { text: h ? `${h}:${pad(mi)}:${pad(se)}` : `${mi}:${pad(se)}`, sec };
}

function ago(iso) {
    const t = Date.parse(iso);
    if (!t) return "";
    const s = Math.max(0, (Date.now() - t) / 1000);
    if (s < 3600) return Math.max(1, Math.floor(s / 60)) + " dk önce";
    if (s < 86400) return Math.floor(s / 3600) + " saat önce";
    if (s < 86400 * 7) return Math.floor(s / 86400) + " gün önce";
    if (s < 86400 * 30) return Math.floor(s / 86400 / 7) + " hafta önce";
    if (s < 86400 * 365) return Math.floor(s / 86400 / 30) + " ay önce";
    return Math.floor(s / 86400 / 365) + " yıl önce";
}

function views(n) {
    n = parseInt(n || "0", 10);
    if (!n) return "";
    if (n >= 1e9) return (n / 1e9).toFixed(1).replace(".", ",").replace(",0", "") + " Mr görüntüleme";
    if (n >= 1e6) return (n / 1e6).toFixed(1).replace(".", ",").replace(",0", "") + " Mn görüntüleme";
    if (n >= 1e3) return Math.floor(n / 1e3) + " B görüntüleme";
    return n + " görüntüleme";
}

function decodeXml(s) {
    return (s || "").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;/g, "'");
}

function bestThumb(th) {
    if (!th) return "";
    return (th.default || th.medium || th.high || {}).url || "";
}

// Kanal avatari / liste resmi icin bizim kucultulmus resim adresimiz
function imgPath(url, w) {
    if (!url) return "";
    return "/yt/img?w=" + (w || 48) + "&u=" + encodeURIComponent(url);
}

// Video sureleri ve izlenmeleri (50'serlik gruplar, her grup 1 kota birimi)
async function videoDetails(ids) {
    const out = {};
    for (let i = 0; i < ids.length; i += 50) {
        const j = await yt("videos", { part: "contentDetails,statistics,snippet", id: ids.slice(i, i + 50).join(","), maxResults: 50 });
        for (const v of j.items || []) {
            const d = isoDur(v.contentDetails && v.contentDetails.duration);
            out[v.id] = {
                length: d.text, sec: d.sec,
                views: views(v.statistics && v.statistics.viewCount),
                live: v.snippet && v.snippet.liveBroadcastContent !== "none"
            };
        }
    }
    return out;
}

// ---------- Kanal yuklemeleri ----------
// YouTube RSS akislari bu sunucudan 404 donuyor. Hesap bagliyken kanalin "UU..." yuklemeler
// listesi Data API ile (istek basina 1 kota birimi), bagli degilken InnerTube ile okunur.

function uploadsId(cid) { return "UU" + cid.slice(2); }

const upCache = {};   // channelId -> { t, items }
async function uploads(cid, max) {
    const c = upCache[cid];
    if (c && Date.now() - c.t < 15 * 60 * 1000) return c.items;
    const j = await yt("playlistItems", { part: "snippet,contentDetails", playlistId: uploadsId(cid), maxResults: max || 5 });
    const items = mapPlaylistItems(j);
    upCache[cid] = { t: Date.now(), items };
    return items;
}

const WEB_CLIENT = { clientName: "WEB", clientVersion: "2.20261003.00.00", hl: "tr", gl: "TR" };
async function innertubeChannel(cid) {
    const r = await fetch("https://www.youtube.com/youtubei/v1/browse?prettyPrint=false", {
        method: "POST",
        headers: { "Content-Type": "application/json", "User-Agent": "Mozilla/5.0", "Accept-Language": "tr-TR,tr;q=0.9" },
        body: JSON.stringify({ context: { client: WEB_CLIENT }, browseId: cid, params: "EgZ2aWRlb3PyBgQKAjoA" })   // "Videolar" sekmesi
    });
    if (!r.ok) throw new Error("YouTube HTTP " + r.status);
    const j = await r.json();
    const md = (j.metadata && j.metadata.channelMetadataRenderer) || {};
    const title = md.title || "";
    const avatar = md.avatar && md.avatar.thumbnails && md.avatar.thumbnails[0] ? md.avatar.thumbnails[0].url : "";
    const items = [];
    const seen = {};
    (function walk(o) {
        if (!o || typeof o !== "object" || items.length >= 30) return;
        const lv = o.lockupViewModel;
        if (lv && lv.contentId && lv.contentType === "LOCKUP_CONTENT_TYPE_VIDEO" && !seen[lv.contentId]) {
            seen[lv.contentId] = true;
            const meta = lv.metadata && lv.metadata.lockupMetadataViewModel;
            let viewsTxt = "", pub = "";
            try {
                for (const row of meta.metadata.contentMetadataViewModel.metadataRows)
                    for (const p of row.metadataParts || []) {
                        const t = p.text && p.text.content;
                        if (!t) continue;
                        if (/görüntüleme|izlenme|views/i.test(t)) viewsTxt = t;
                        else if (/önce|ago/i.test(t)) pub = t;
                    }
            } catch (e) { }
            let length = "";
            try { const b = JSON.stringify(lv.contentImage).match(/"text":"(\d+:\d{2}(?::\d{2})?)"/); if (b) length = b[1]; } catch (e) { }
            const t = meta && meta.title ? (meta.title.content || meta.title.simpleText || "") : "";
            if (length) items.push({ id: lv.contentId, title: t, channel: title, channelId: cid, views: viewsTxt, published: pub, length });
            return;
        }
        const v = o.videoRenderer || o.gridVideoRenderer;
        if (v && v.videoId && !seen[v.videoId]) {
            seen[v.videoId] = true;
            const tx = (x) => (x ? x.simpleText || (x.runs || []).map((r) => r.text).join("") : "");
            if (v.lengthText) items.push({ id: v.videoId, title: tx(v.title), channel: title, channelId: cid, views: tx(v.shortViewCountText || v.viewCountText), published: tx(v.publishedTimeText), length: tx(v.lengthText) });
            return;
        }
        for (const k in o) walk(o[k]);
    })(j.contents);
    return { title, thumb: imgPath(avatar, 64), items };
}
async function mapLimit(list, n, fn) {
    const out = new Array(list.length);
    let i = 0;
    await Promise.all(new Array(Math.min(n, list.length)).fill(0).map(async () => {
        while (i < list.length) {
            const k = i++;
            try { out[k] = await fn(list[k]); } catch (e) { out[k] = null; }
        }
    }));
    return out;
}

// ---------- Abonelikler ve akis ----------
// Yerel abonelik listesi (data/yt_subs.json): Google hesabi olmadan da calisir. Hesap bagliyken
// Google abonelikleri bu listeye eklenir; boylece izin dusse bile liste kaybolmaz.

const LOCAL_SUBS_FILE = path.join(DATA_DIR, "yt_subs.json");
let localSubs = readJson(LOCAL_SUBS_FILE) || [];   // [{ id, title, thumb }]
function saveLocalSubs() { writeJson(LOCAL_SUBS_FILE, localSubs); }
function mergeIntoLocal(list) {
    let changed = false;
    for (const s of list) {
        const cur = localSubs.find((x) => x.id === s.id);
        if (!cur) { localSubs.push({ id: s.id, title: s.title, thumb: s.thumb || "" }); changed = true; }
        else if ((s.thumb && cur.thumb !== s.thumb) || (s.title && cur.title !== s.title)) { cur.title = s.title || cur.title; cur.thumb = s.thumb || cur.thumb; changed = true; }
    }
    if (changed) saveLocalSubs();
}
const trSort = (a, b) => a.title.localeCompare(b.title, "tr", { sensitivity: "base" });

async function allSubs(force) {
    if (token) {
        try { mergeIntoLocal(await subscriptions(force)); }
        catch (e) { if (e.code !== 401) console.log("[google] abonelikler alinamadi:", e.message); }
    }
    return localSubs.slice().sort(trSort);
}

// "3 gün önce" / "2 hours ago" -> yaklasik zaman damgasi (siralama icin)
function relTime(s) {
    const m = /(\d+)\s*(saniye|second|dakika|minute|saat|hour|gün|day|hafta|week|ay|month|yıl|year)/i.exec(s || "");
    if (!m) return 0;
    const n = +m[1], u = m[2].toLowerCase();
    const mult = /san|sec/.test(u) ? 1 : /dak|min/.test(u) ? 60 : /saat|hour/.test(u) ? 3600 : /gün|day/.test(u) ? 86400
        : /hafta|week/.test(u) ? 604800 : /^ay|month/.test(u) ? 2592000 : 31536000;
    return Date.now() - n * mult * 1000;
}

const itCache = {};   // innertube kanal onbellegi: cid -> { t, r }
async function channelLatest(cid) {
    const c = itCache[cid];
    if (c && Date.now() - c.t < 20 * 60 * 1000) return c.r;
    const r = await innertubeChannel(cid);
    itCache[cid] = { t: Date.now(), r };
    return r;
}

let subsCache = null;   // { t, items }
async function subscriptions(force) {
    if (!force && subsCache && Date.now() - subsCache.t < 6 * 3600 * 1000) return subsCache.items;
    const items = [];
    let pageToken = "";
    for (let guard = 0; guard < 20; guard++) {
        const p = { part: "snippet", mine: "true", maxResults: 50, order: "alphabetical" };
        if (pageToken) p.pageToken = pageToken;
        const j = await yt("subscriptions", p);
        for (const s of j.items || []) {
            const sn = s.snippet || {};
            const cid = sn.resourceId && sn.resourceId.channelId;
            if (!cid) continue;
            items.push({ id: cid, title: sn.title || "", thumb: imgPath(bestThumb(sn.thumbnails), 48) });
        }
        pageToken = j.nextPageToken;
        if (!pageToken) break;
    }
    subsCache = { t: Date.now(), items };
    return items;
}

let feedCache = null;   // { t, items }
async function feed(force) {
    if (!force && feedCache && Date.now() - feedCache.t < 10 * 60 * 1000) return feedCache.items;
    const subs = await allSubs(force);
    if (force) for (const k in itCache) delete itCache[k];
    // Hesap bagliyken Data API (kesin tarih); degilse veya API hata verirse InnerTube
    const lists = await mapLimit(subs, 8, async (s) => {
        if (token) { try { return await uploads(s.id, 5); } catch (e) { if (e.code !== 401) console.log("[google] yuklemeler:", e.message); } }
        const r = await channelLatest(s.id);
        return r.items.slice(0, 6).map((v) => Object.assign({}, v, { channel: v.channel || s.title, publishedAt: new Date(relTime(v.published) || 0).toISOString() }));
    });
    let all = [];
    for (const l of lists) if (l) all = all.concat(l);
    all.sort((a, b) => Date.parse(b.publishedAt) - Date.parse(a.publishedAt));
    all = all.slice(0, 150);
    feedCache = { t: Date.now(), items: all };
    return all;
}

// Sayfadaki videolara sure ekler; Shorts'lari (<= 60 sn) ve canli yayinlari ayiklar
async function enrich(items, dropShorts) {
    const need = items.filter((v) => !v.length).map((v) => v.id);
    if (need.length && token) {
        try {
            const d = await videoDetails(need);
            for (const v of items) if (d[v.id]) { v.length = d[v.id].length; v.sec = d[v.id].sec; if (!v.views) v.views = d[v.id].views; v.live = d[v.id].live; }
        } catch (e) { console.log("[google] sure alinamadi:", e.message); }
    }
    return items.filter((v) => !v.live && !(dropShorts && v.sec && v.sec <= 60));
}

// ---------- Uc noktalar: hesap ----------

router.get("/yt/auth/status", (req, res) => {
    res.json({
        configured: !!(cfg && cfg.client_id && cfg.client_secret),
        linked: !!(token && token.refresh_token),
        channel: token && token.channel ? token.channel : null,
        pending: pending && pending.status === "pending" ? {
            userCode: pending.user_code, url: pending.verification_url,
            expiresIn: Math.max(0, Math.round((pending.expires_at - Date.now()) / 1000))
        } : null,
        lastError: pending && pending.status !== "pending" && pending.status !== "ok" ? pending.message : ""
    });
});

function saveConfig(id, secret) {
    id = ("" + (id || "")).trim();
    secret = ("" + (secret || "")).trim();
    if (!/\.apps\.googleusercontent\.com$/.test(id) || secret.length < 8) return false;
    cfg = { client_id: id, client_secret: secret };
    writeJson(CFG_FILE, cfg);
    return true;
}

router.post("/yt/auth/config", (req, res) => {
    if (!saveConfig(req.body.client_id, req.body.client_secret)) return res.status(400).json({ error: "İstemci kimliği veya gizli anahtar geçersiz" });
    res.json({ ok: true });
});

const esc = (s) => ("" + s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
function setupPage(msg) {
    const st = token && token.channel ? "Bağlı hesap: " + esc(token.channel.title) : (token ? "Hesap bağlı" : "Hesap bağlı değil");
    return `<!doctype html><html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>BelleTube Google kurulumu</title><style>body{font-family:system-ui,sans-serif;max-width:640px;margin:24px auto;padding:0 16px;line-height:1.5;color:#222}
input{width:100%;padding:8px;margin:4px 0 12px;box-sizing:border-box}button{padding:10px 18px}code{background:#eee;padding:1px 4px}.m{padding:10px;background:#eef6ee;border-radius:6px}</style></head><body>
<h2>BelleTube – Google hesabı kurulumu</h2>${msg ? `<p class="m">${esc(msg)}</p>` : ""}
<p><b>Durum:</b> ${cfg ? "OAuth istemcisi girilmiş" : "OAuth istemcisi girilmemiş"} · ${st}</p>
<ol><li>Google Cloud Console → <b>API'ler ve Hizmetler → OAuth izin ekranı</b>: Harici, uygulama adı BelleTube; kapsam <code>youtube.readonly</code>; kendi Gmail adresinizi test kullanıcısı olarak ekleyin, sonra <b>Uygulamayı yayınla</b> (yayınlanmazsa izin 7 günde bir düşer).</li>
<li><b>Kimlik bilgileri → Kimlik bilgisi oluştur → OAuth istemci kimliği</b>, tür: <b>TV'ler ve Sınırlı Giriş cihazları</b>.</li>
<li>Çıkan istemci kimliğini ve gizli anahtarı aşağıya yapıştırıp kaydedin.</li>
<li>Telefonda BelleTube → Ayarlar → <b>Google hesabını bağla</b>. Telefonda çıkan kodu <code>google.com/device</code> adresine girin.</li></ol>
<form method="post" action="/yt/setup"><label>İstemci kimliği (…apps.googleusercontent.com)</label><input name="client_id" value="${cfg ? esc(cfg.client_id) : ""}">
<label>İstemci gizli anahtarı</label><input name="client_secret" type="password" placeholder="${cfg ? "(kayıtlı – değiştirmek için yeniden girin)" : ""}">
<button type="submit">Kaydet</button></form></body></html>`;
}

router.get("/yt/setup", (req, res) => res.type("html").send(setupPage("")));
router.post("/yt/setup", (req, res) => {
    const secret = req.body.client_secret || (cfg && req.body.client_id === cfg.client_id ? cfg.client_secret : "");
    const ok = saveConfig(req.body.client_id, secret);
    res.type("html").send(setupPage(ok ? "Kaydedildi. Şimdi telefondan hesabı bağlayabilirsiniz." : "Geçersiz bilgi: istemci kimliği …apps.googleusercontent.com ile bitmeli."));
});

async function fetchChannelInfo() {
    try {
        const j = await yt("channels", { part: "snippet", mine: "true" });
        const c = (j.items || [])[0];
        if (c) token.channel = { id: c.id, title: c.snippet.title, thumb: imgPath(bestThumb(c.snippet.thumbnails), 48) };
    } catch (e) {
        token.channel = { id: "", title: "Google hesabı", thumb: "" };   // kanali olmayan hesap
    }
    writeJson(TOKEN_FILE, token);
}

async function pollDevice(p) {
    while (pending === p && Date.now() < p.expires_at) {
        await new Promise((r) => setTimeout(r, p.interval * 1000));
        if (pending !== p) return;
        const r = await postForm("https://oauth2.googleapis.com/token", {
            client_id: cfg.client_id, client_secret: cfg.client_secret,
            device_code: p.device_code, grant_type: "urn:ietf:params:oauth:grant-type:device_code"
        }).catch((e) => ({ ok: false, body: { error: "network", error_description: e.message } }));
        if (r.ok && r.body.refresh_token) {
            token = { refresh_token: r.body.refresh_token, access_token: r.body.access_token, expires_at: Date.now() + (r.body.expires_in || 3600) * 1000 };
            writeJson(TOKEN_FILE, token);
            subsCache = null; feedCache = null;
            await fetchChannelInfo();
            p.status = "ok";
            console.log("[google] hesap baglandi:", token.channel && token.channel.title);
            return;
        }
        const err = r.body.error;
        if (err === "authorization_pending" || err === "network") continue;
        if (err === "slow_down") { p.interval += 5; continue; }
        p.status = err === "access_denied" ? "denied" : "error";
        p.message = err === "access_denied" ? "Google'da izin verilmedi" : "Bağlanamadı: " + (r.body.error_description || err);
        return;
    }
    if (pending === p && p.status === "pending") { p.status = "expired"; p.message = "Kodun süresi doldu; yeniden deneyin"; }
}

router.post("/yt/auth/start", async (req, res) => {
    if (!cfg) return res.status(400).json({ error: "Önce sunucuda OAuth istemcisi girilmeli (bilgisayardan /yt/setup sayfası)" });
    const r = await postForm("https://oauth2.googleapis.com/device/code", { client_id: cfg.client_id, scope: SCOPE })
        .catch((e) => ({ ok: false, body: { error: e.message } }));
    if (!r.ok) return res.status(502).json({ error: "Google kod vermedi: " + (r.body.error_description || r.body.error || r.status) });
    pending = {
        device_code: r.body.device_code, user_code: r.body.user_code,
        verification_url: r.body.verification_url || r.body.verification_uri || "https://www.google.com/device",
        interval: r.body.interval || 5, expires_at: Date.now() + (r.body.expires_in || 1800) * 1000, status: "pending"
    };
    pollDevice(pending);
    res.json({ userCode: pending.user_code, url: pending.verification_url, expiresIn: r.body.expires_in || 1800 });
});

router.post("/yt/auth/cancel", (req, res) => { pending = null; res.json({ ok: true }); });

router.post("/yt/auth/logout", async (req, res) => {
    if (token && token.refresh_token) {
        await fetch("https://oauth2.googleapis.com/revoke?token=" + encodeURIComponent(token.refresh_token), { method: "POST" }).catch(() => { });
    }
    token = null; subsCache = null; feedCache = null; pending = null;
    try { fs.unlinkSync(TOKEN_FILE); } catch (e) { }
    res.json({ ok: true });
});

// ---------- Uc noktalar: icerik ----------

const PAGE = 20;

router.get("/yt/feed", async (req, res) => {
    try {
        const page = Math.max(0, parseInt(req.query.page || "0", 10));
        const all = await feed(req.query.refresh === "1");
        const slice = all.slice(page * PAGE, page * PAGE + PAGE).map((v) => Object.assign({}, v));
        const items = await enrich(slice, true);
        res.json({ items, more: (page + 1) * PAGE < all.length });
    } catch (e) { sendErr(res, e); }
});

router.get("/yt/subs", async (req, res) => {
    try { res.json({ items: await allSubs(req.query.refresh === "1") }); } catch (e) { sendErr(res, e); }
});

// Uygulama icinden abone ol / abonelikten cik (yerel liste; Google hesabina yazilmaz)
router.post("/yt/subs/add", express.json({ limit: "8kb" }), (req, res) => {
    const b = req.body || {};
    const id = "" + (b.id || "");
    if (!/^UC[A-Za-z0-9_-]{22}$/.test(id)) return res.status(400).json({ error: "Geçersiz kanal" });
    if (!localSubs.find((x) => x.id === id)) {
        localSubs.push({ id, title: ("" + (b.title || "")).slice(0, 200), thumb: /^\/yt\/img\?/.test(b.thumb || "") ? b.thumb : "" });
        saveLocalSubs();
    }
    feedCache = null;
    res.json({ ok: true, subscribed: true, count: localSubs.length });
});
router.post("/yt/subs/remove", express.json({ limit: "8kb" }), (req, res) => {
    const id = "" + ((req.body || {}).id || "");
    localSubs = localSubs.filter((x) => x.id !== id);
    saveLocalSubs();
    feedCache = null;
    res.json({ ok: true, subscribed: false, count: localSubs.length });
});

router.get("/yt/channel/:cid", async (req, res) => {
    const cid = req.params.cid;
    if (!/^UC[A-Za-z0-9_-]{22}$/.test(cid)) return res.status(400).json({ error: "Geçersiz kanal" });
    try {
        if (token) {
            const p = { part: "snippet,contentDetails", playlistId: uploadsId(cid), maxResults: PAGE };
            if (req.query.pageToken) p.pageToken = "" + req.query.pageToken;
            const [list, info] = await Promise.all([
                yt("playlistItems", p),
                req.query.pageToken ? Promise.resolve(null) : yt("channels", { part: "snippet,statistics", id: cid }).catch(() => null)
            ]);
            const channel = { id: cid, title: "", thumb: "", subscribers: "", subscribed: !!localSubs.find((x) => x.id === cid) };
            const c = info && (info.items || [])[0];
            if (c) {
                channel.title = c.snippet.title;
                channel.thumb = imgPath(bestThumb(c.snippet.thumbnails), 64);
                const n = parseInt((c.statistics && c.statistics.subscriberCount) || "0", 10);
                if (n) channel.subscribers = views(n).replace("görüntüleme", "abone");
            }
            return res.json({ channel, items: await enrich(mapPlaylistItems(list), false), next: list.nextPageToken || "" });
        }
        const r = await channelLatest(cid);
        res.json({ channel: { id: cid, title: r.title, thumb: r.thumb, subscribers: r.subscribers || "", subscribed: !!localSubs.find((x) => x.id === cid) }, items: r.items, next: "" });
    } catch (e) { sendErr(res, e); }
});
router.get("/yt/playlists", async (req, res) => {
    try {
        const items = [];
        let pageToken = "";
        for (let guard = 0; guard < 5; guard++) {
            const p = { part: "snippet,contentDetails", mine: "true", maxResults: 50 };
            if (pageToken) p.pageToken = pageToken;
            const j = await yt("playlists", p);
            for (const pl of j.items || []) {
                items.push({
                    id: pl.id, title: pl.snippet.title,
                    count: (pl.contentDetails && pl.contentDetails.itemCount) || 0,
                    thumb: imgPath(bestThumb(pl.snippet.thumbnails), 96)
                });
            }
            pageToken = j.nextPageToken;
            if (!pageToken) break;
        }
        res.json({ items });
    } catch (e) { sendErr(res, e); }
});

function mapPlaylistItems(j) {
    return (j.items || []).map((it) => {
        const sn = it.snippet || {};
        const id = (it.contentDetails && it.contentDetails.videoId) || (sn.resourceId && sn.resourceId.videoId);
        return {
            id, title: sn.title || "",
            channel: sn.videoOwnerChannelTitle || sn.channelTitle || "",
            channelId: sn.videoOwnerChannelId || "",
            publishedAt: (it.contentDetails && it.contentDetails.videoPublishedAt) || sn.publishedAt || "",
            published: ago((it.contentDetails && it.contentDetails.videoPublishedAt) || sn.publishedAt),
            views: "", length: ""
        };
    }).filter((v) => v.id && v.title !== "Deleted video" && v.title !== "Private video");
}

router.get("/yt/playlist/:pid", async (req, res) => {
    const pid = req.params.pid;
    if (!/^[A-Za-z0-9_-]{2,64}$/.test(pid)) return res.status(400).json({ error: "Geçersiz liste" });
    try {
        const p = { part: "snippet,contentDetails", playlistId: pid, maxResults: PAGE };
        if (req.query.pageToken) p.pageToken = "" + req.query.pageToken;
        const j = await yt("playlistItems", p);
        res.json({ items: await enrich(mapPlaylistItems(j), false), next: j.nextPageToken || "" });
    } catch (e) { sendErr(res, e); }
});

router.get("/yt/liked", async (req, res) => {
    try {
        const p = { part: "snippet,contentDetails,statistics", myRating: "like", maxResults: PAGE };
        if (req.query.pageToken) p.pageToken = "" + req.query.pageToken;
        const j = await yt("videos", p);
        const items = (j.items || []).map((v) => {
            const d = isoDur(v.contentDetails && v.contentDetails.duration);
            return {
                id: v.id, title: v.snippet.title, channel: v.snippet.channelTitle, channelId: v.snippet.channelId,
                published: ago(v.snippet.publishedAt), views: views(v.statistics && v.statistics.viewCount),
                length: d.text, sec: d.sec
            };
        });
        res.json({ items, next: j.nextPageToken || "" });
    } catch (e) { sendErr(res, e); }
});

// Kanal avatari / liste kapagi: kucultulmus JPEG, 7 gun onbellek (yalnizca YouTube resim sunuculari)
const imgJobs = {};
router.get("/yt/img", async (req, res) => {
    let u = "" + (req.query.u || "");
    // Qt 4'un QML Image'i adresteki %XX'leri bir kez daha kodluyor (%3A -> %253A): coz
    for (let i = 0; i < 3 && /^https?%3A/i.test(u); i++) { try { u = decodeURIComponent(u); } catch (e) { break; } }
    const w =Math.min(160, Math.max(24, parseInt(req.query.w || "48", 10)));
    let host = "";
    try { host = new URL(u).hostname; } catch (e) { }
    if (!/(^|\.)(ggpht\.com|googleusercontent\.com|ytimg\.com)$/.test(host)) { console.log("[yt img] gecersiz adres:", req.originalUrl.slice(0, 160)); return res.status(400).end(); }
    const name = require("crypto").createHash("sha1").update(u + "|" + w).digest("hex") + ".jpg";
    const file = path.join(IMG_DIR, name);
    try {
        if (!fs.existsSync(file)) {
            if (!imgJobs[name]) {
                imgJobs[name] = (async () => {
                    const r = await fetch(u);
                    if (!r.ok) throw new Error("resim yok");
                    const tmp = path.join(os.tmpdir(), "img_" + name);
                    fs.writeFileSync(tmp, Buffer.from(await r.arrayBuffer()));
                    // yuvj420p: telefonun JPEG cozucusu 4:4:4 resimleri gosteremeyebiliyor
                    await new Promise((ok, fail) => ffmpeg().input(tmp).outputOptions([`-vf scale=${w}:-2`, "-pix_fmt yuvj420p", "-q:v 5", "-frames:v 1"])
                        .output(file).on("end", ok).on("error", fail).run());
                    fs.unlink(tmp, () => { });
                })().finally(() => { delete imgJobs[name]; });
            }
            await imgJobs[name];
        }
        res.set("Cache-Control", "private, max-age=604800");
        res.sendFile(file);
    } catch (e) { console.log("[yt img] alinamadi:", e.message); res.status(404).end(); }
});

module.exports = router;
