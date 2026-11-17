// Belle Drive - Google Drive'a telefondan sade HTML sayfalarla erisim (agir isi sunucu yapar)
//
// Giris: OAuth "Masaustu uygulamasi" istemcisi + PKCE. Kullanici bilgisayarda Google iznini verir,
// tarayici acilamayan bir 127.0.0.1 adresine yonlenir; o adres /drive/setup sayfasina yapistirilir.
// Yenileme anahtari yalnizca sunucuda (data/drive_token.json) saklanir.
//
// Sayfalar: klasorler, arama, son acilanlar, paylasilanlar, yildizlilar; dosya ayrintisi,
// Google dokumanlarini metin/PDF olarak alma, resimleri kucultme, indirme, yukleme, yeni klasor, cop.

const express = require("express");
const fs = require("fs");
const path = require("path");
const os = require("os");
const crypto = require("crypto");
const { Readable } = require("stream");
const compression = require("compression");
const ffmpeg = require("fluent-ffmpeg");

const router = new express.Router();
const DATA = path.join(__dirname, "data");
const CFG_FILE = path.join(DATA, "drive.json");          // { client_id, client_secret }
const TOKEN_FILE = path.join(DATA, "drive_token.json");  // { refresh_token, access_token, expires_at, email }
const SCOPE = "https://www.googleapis.com/auth/drive";
const REDIRECT = "http://127.0.0.1:8765/";
const API = "https://www.googleapis.com/drive/v3/";
const PAGE = 30;

function readJson(f) { try { return JSON.parse(fs.readFileSync(f, "utf8")); } catch (e) { return null; } }
function writeJson(f, o) { fs.writeFileSync(f, JSON.stringify(o), { mode: 0o600 }); }
let cfg = readJson(CFG_FILE);
let token = readJson(TOKEN_FILE);
const pkces = {};  // state -> { verifier, t }  (son 30 dk'da acilan izin baglantilari)

const esc = (s) => ("" + (s == null ? "" : s)).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
const b64url = (b) => b.toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

// ---------- Kimlik ----------

async function postForm(url, obj) {
    const r = await fetch(url, { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: new URLSearchParams(obj).toString() });
    let j = {};
    try { j = await r.json(); } catch (e) { }
    return { ok: r.ok, body: j };
}

async function accessToken() {
    if (!token || !token.refresh_token) throw Object.assign(new Error("Drive bağlı değil"), { code: 401 });
    if (token.access_token && token.expires_at > Date.now() + 60000) return token.access_token;
    const r = await postForm("https://oauth2.googleapis.com/token", {
        client_id: cfg.client_id, client_secret: cfg.client_secret, refresh_token: token.refresh_token, grant_type: "refresh_token"
    });
    if (!r.ok) {
        if (r.body.error === "invalid_grant") { token = null; try { fs.unlinkSync(TOKEN_FILE); } catch (e) { } throw Object.assign(new Error("Drive izni geçersiz; yeniden bağlayın"), { code: 401 }); }
        throw new Error("Drive anahtarı yenilenemedi: " + (r.body.error_description || r.body.error));
    }
    token.access_token = r.body.access_token;
    token.expires_at = Date.now() + (r.body.expires_in || 3600) * 1000;
    writeJson(TOKEN_FILE, token);
    return token.access_token;
}

async function api(method, endpoint, params, body, extraHeaders) {
    const at = await accessToken();
    const url = (endpoint.indexOf("http") === 0 ? endpoint : API + endpoint) + (params ? "?" + new URLSearchParams(params).toString() : "");
    const headers = Object.assign({ Authorization: "Bearer " + at }, extraHeaders || {});
    const r = await fetch(url, { method, headers, body });
    if (!r.ok) {
        let msg = "HTTP " + r.status;
        try { const j = await r.json(); if (j.error) msg = j.error.message || msg; } catch (e) { }
        throw new Error(msg);
    }
    return r;
}
async function apiJson(method, endpoint, params, body, headers) { return (await api(method, endpoint, params, body, headers)).json(); }

// ---------- Bicimleme ----------

const FIELDS = "nextPageToken,files(id,name,mimeType,size,modifiedTime,starred,parents,owners(displayName),shortcutDetails)";
const FOLDER = "application/vnd.google-apps.folder";
const EXPORTS = {   // Google dosyalari -> metin / indirilebilir bicim
    "application/vnd.google-apps.document": { text: "text/plain", file: "application/pdf", ext: "pdf", label: "Doküman" },
    "application/vnd.google-apps.spreadsheet": { text: "text/csv", file: "application/pdf", ext: "pdf", label: "E-Tablo" },
    "application/vnd.google-apps.presentation": { text: "text/plain", file: "application/pdf", ext: "pdf", label: "Sunu" },
    "application/vnd.google-apps.drawing": { text: null, file: "image/jpeg", ext: "jpg", label: "Çizim" }
};

function icon(m) {
    if (m === FOLDER) return "📁";
    if (m === "application/vnd.google-apps.shortcut") return "↪";
    if (m.indexOf("image/") === 0) return "🖼";
    if (m.indexOf("video/") === 0) return "🎬";
    if (m.indexOf("audio/") === 0) return "🎵";
    if (m === "application/pdf") return "📕";
    if (/spreadsheet|excel|csv/.test(m)) return "📊";
    if (/presentation|powerpoint/.test(m)) return "📽";
    if (/zip|rar|7z|compressed/.test(m)) return "🗜";
    return "📄";
}
function sizeText(b) {
    b = parseInt(b || "0", 10);
    if (!b) return "";
    if (b >= 1073741824) return (b / 1073741824).toFixed(1) + " GB";
    if (b >= 1048576) return (b / 1048576).toFixed(1) + " MB";
    return Math.max(1, Math.round(b / 1024)) + " KB";
}
function dateText(d) {
    if (!d) return "";
    const t = new Date(d), now = new Date();
    const pad = (n) => (n < 10 ? "0" : "") + n;
    if (t.toDateString() === now.toDateString()) return pad(t.getHours()) + ":" + pad(t.getMinutes());
    return pad(t.getDate()) + "." + pad(t.getMonth() + 1) + (t.getFullYear() !== now.getFullYear() ? "." + t.getFullYear() : "");
}
function isText(m, name) { return /^text\//.test(m) || /json|xml|javascript/.test(m) || /\.(txt|md|csv|log|ini|json)$/i.test(name || ""); }

const CSS = `body{margin:0;font-family:sans-serif;font-size:15px;background:#fff;color:#111}a{color:#0b57d0;text-decoration:none}
.top{background:#1a73e8;color:#fff;padding:6px 8px}.top a{color:#fff;margin-right:10px}.top b{margin-right:12px}
.bar{padding:6px 8px;background:#f1f3f4;border-bottom:1px solid #ddd}.r{display:block;padding:7px 8px;border-bottom:1px solid #e3e3e3;color:#111}
.d{float:right;color:#666;font-size:13px}.s{color:#555;font-size:13px}.h{padding:8px;border-bottom:1px solid #ddd}
.b{padding:8px;line-height:1.35;word-wrap:break-word}.btn{display:inline-block;padding:5px 9px;margin:2px;border:1px solid #bbb;background:#f8f8f8;color:#111}
input,textarea{font-size:15px}.p{padding:8px;text-align:center}.e{color:#b00020;padding:8px}pre{white-space:pre-wrap;font-size:13px}`;
function page(title, body) {
    return `<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>${esc(title)}</title><style>${CSS}</style></head><body>${body}</body></html>`;
}
function topBar(active) {
    const t = (id, label) => (active === id ? `<b>${label}</b>` : `<a href="/drive?v=${id}">${label}</a>`);
    return `<div class="top">${t("all", "Tümü")}${t("my", "Klasörler")}${t("shared", "Paylaşılan")}${t("starred", "★")}</div>`;
}
function errPage(res, e, v) {
    if (e.code === 401) return res.redirect("/drive/setup");
    console.log("[drive]", e.message);
    res.status(502).type("html").send(page("Hata", topBar(v || "") + `<div class="e">${esc(e.message)}</div><div class="p"><a href="/drive">Drive'a dön</a></div>`));
}

// ---------- Kurulum ----------

router.use("/drive", compression());

router.get("/drive/setup", (req, res) => {
    let html = `<div class="top"><b>Drive kurulumu</b><a href="/drive">Drive</a></div><div class="b">`;
    if (token && token.refresh_token) html += `<p>✔ Bağlı hesap: <b>${esc(token.email || "Google hesabı")}</b></p><form method="post" action="/drive/logout"><input type="submit" value="Bağlantıyı kes"></form><hr>`;
    html += `<p><b>1)</b> Google Cloud Console → API'ler ve Hizmetler → Kimlik bilgileri → <b>Kimlik bilgisi oluştur → OAuth istemci kimliği</b>, uygulama türü: <b>Masaüstü uygulaması</b>. (İzin ekranı daha önce YouTube için ayarlandıysa yenisi gerekmez; kendi Gmail adresiniz test kullanıcısı olmalı.)</p>
<form method="post" action="/drive/config">İstemci kimliği<br><input name="client_id" style="width:96%" value="${cfg ? esc(cfg.client_id) : ""}"><br>
İstemci gizli anahtarı<br><input name="client_secret" type="password" style="width:96%" placeholder="${cfg ? "(kayıtlı)" : ""}"><br><input type="submit" value="Kaydet"></form>`;
    if (cfg) {
        const verifier = b64url(crypto.randomBytes(48));
        const state = b64url(crypto.randomBytes(12));
        for (const k in pkces) if (Date.now() - pkces[k].t > 30 * 60 * 1000) delete pkces[k];
        pkces[state] = { verifier, t: Date.now() };
        const url = "https://accounts.google.com/o/oauth2/v2/auth?" + new URLSearchParams({
            client_id: cfg.client_id, redirect_uri: REDIRECT, response_type: "code", scope: SCOPE + " email",
            access_type: "offline", prompt: "consent", state,
            code_challenge: b64url(crypto.createHash("sha256").update(verifier).digest()), code_challenge_method: "S256"
        }).toString();
        html += `<hr><p><b>2)</b> Bu bağlantıyı <b>bilgisayarda</b> açın, Google hesabınızla giriş yapıp izin verin (uygulama doğrulanmadı uyarısında "Gelişmiş → Devam"):</p>
<p><a href="${esc(url)}" target="_blank">Google Drive iznini ver</a></p>
<p><b>3)</b> Sonunda tarayıcı "bu siteye ulaşılamıyor" diyen <code>127.0.0.1:8765</code> adresine gider. <b>Adres çubuğundaki tam adresi</b> kopyalayıp buraya yapıştırın:</p>
<form method="post" action="/drive/code"><input name="url" style="width:96%" placeholder="http://127.0.0.1:8765/?state=...&code=..."><br><input type="submit" value="Bağlan"></form>
<p class="s">Not: Bağlantı her açılışta yenilenir; adımı bu sayfayı yeniledikten sonra yapın.</p>`;
    }
    res.type("html").send(page("Drive kurulumu", html + "</div>"));
});

router.post("/drive/config", express.urlencoded({ extended: false, limit: "8kb" }), (req, res) => {
    const id = ("" + (req.body.client_id || "")).trim();
    const secret = ("" + (req.body.client_secret || "")).trim() || (cfg && cfg.client_id === id ? cfg.client_secret : "");
    if (!/\.apps\.googleusercontent\.com$/.test(id) || !secret) return res.type("html").send(page("Hata", `<div class="e">İstemci kimliği …apps.googleusercontent.com ile bitmeli ve gizli anahtar girilmeli.</div><div class="p"><a href="/drive/setup">Geri</a></div>`));
    cfg = { client_id: id, client_secret: secret };
    writeJson(CFG_FILE, cfg);
    res.redirect("/drive/setup");
});

router.post("/drive/code", express.urlencoded({ extended: false, limit: "8kb" }), async (req, res) => {
    let code = "", state = "";
    try { const u = new URL(("" + req.body.url).trim()); code = u.searchParams.get("code") || ""; state = u.searchParams.get("state") || ""; } catch (e) { code = ("" + req.body.url).trim(); }
    const fail = (m) => (console.log("[drive] baglanti hatasi:", m), res.type("html")).send(page("Hata", `<div class="e">${esc(m)}</div><div class="p"><a href="/drive/setup">Yeniden dene</a></div>`));
    let pk = state ? pkces[state] : null;
    if (!pk && !state) { const keys = Object.keys(pkces); if (keys.length) pk = pkces[keys[keys.length - 1]]; }
    if (!cfg || !code) return fail("Kod bulunamadı. Adres çubuğundaki adresin tamamını yapıştırın.");
    if (!pk) return fail("Bu adres eski ya da süresi dolmuş bir denemeye ait. Kurulum sayfasını yenileyip bağlantıyı yeniden açın.");
    const r = await postForm("https://oauth2.googleapis.com/token", {
        client_id: cfg.client_id, client_secret: cfg.client_secret, code, code_verifier: pk.verifier,
        redirect_uri: REDIRECT, grant_type: "authorization_code"
    });
    if (!r.ok || !r.body.refresh_token) return fail("Google izni alınamadı: " + (r.body.error_description || r.body.error || "yenileme anahtarı yok"));
    if ((r.body.scope || "").split(" ").indexOf(SCOPE) < 0) {
        fetch("https://oauth2.googleapis.com/revoke?token=" + encodeURIComponent(r.body.refresh_token), { method: "POST" }).catch(() => { });
        return fail("Drive izni verilmedi. Google izin ekranında \"Google Drive dosyalarınızın tümünü görme, düzenleme, oluşturma ve silme\" satırının yanındaki kutucuğu işaretleyip Devam deyin. Kurulum sayfasını yenileyip bağlantıyı yeniden açın.");
    }
    token = { refresh_token: r.body.refresh_token, access_token: r.body.access_token, expires_at: Date.now() + (r.body.expires_in || 3600) * 1000 };
    try { const a = await apiJson("GET", "about", { fields: "user(emailAddress,displayName)" }); token.email = a.user.emailAddress; } catch (e) { }
    writeJson(TOKEN_FILE, token);
    delete pkces[state];
    console.log("[drive] hesap baglandi:", token.email);
    res.redirect("/drive");
});

router.post("/drive/logout", async (req, res) => {
    if (token && token.refresh_token) await fetch("https://oauth2.googleapis.com/revoke?token=" + encodeURIComponent(token.refresh_token), { method: "POST" }).catch(() => { });
    token = null;
    try { fs.unlinkSync(TOKEN_FILE); } catch (e) { }
    res.redirect("/drive/setup");
});

// ---------- Listeleme ----------

const nameCache = {};   // klasor id -> { name, parent }
async function folderInfo(id) {
    if (id === "root") return { name: "Drive'ım", parent: null };
    if (nameCache[id]) return nameCache[id];
    const f = await apiJson("GET", "files/" + id, { fields: "name,parents", supportsAllDrives: "true" });
    nameCache[id] = { name: f.name, parent: f.parents ? f.parents[0] : null };
    return nameCache[id];
}

router.get("/drive", async (req, res) => {
    if (!cfg || !token) return res.redirect("/drive/setup");
    const folder = /^[\w-]{5,}$/.test(req.query.f || "") ? req.query.f : "root";
    // Varsayilan: tum Drive (dosya/klasor ayrimi yok) degistirme tarihine gore
    const v = ["all", "my", "shared", "starred"].indexOf(req.query.v) >= 0 ? req.query.v : (req.query.f ? "my" : "all");
    const q = ("" + (req.query.q || "")).trim();
    try {
        const params = { pageSize: PAGE, fields: FIELDS, supportsAllDrives: "true", includeItemsFromAllDrives: "true" };
        if (req.query.p) params.pageToken = "" + req.query.p;
        let title = "", up = "";
        if (q) {
            params.q = `name contains '${q.replace(/\\/g, "\\\\").replace(/'/g, "\\'")}' and trashed=false`;
            params.orderBy = "modifiedTime desc";
            title = `“${q}” araması`;
        } else if (v === "all") { params.q = "trashed=false"; params.orderBy = "modifiedTime desc"; title = "Tüm dosya ve klasörler (son değişen üstte)"; }
        else if (v === "shared") { params.q = "sharedWithMe and trashed=false"; params.orderBy = "modifiedTime desc"; title = "Benimle paylaşılanlar"; }
        else if (v === "starred") { params.q = "starred and trashed=false"; params.orderBy = "modifiedTime desc"; title = "Yıldızlı"; }
        else {
            params.q = `'${folder}' in parents and trashed=false`;
            params.orderBy = "modifiedTime desc";
            const info = await folderInfo(folder);
            title = info.name;
            if (info.parent) up = `<a class="btn" href="/drive?f=${info.parent}">⬆ Üst klasör</a>`;
        }
        const j = await apiJson("GET", "files", params);
        const rows = (j.files || []).map((f) => {
            let id = f.id, mime = f.mimeType;
            if (mime === "application/vnd.google-apps.shortcut" && f.shortcutDetails) { id = f.shortcutDetails.targetId; mime = f.shortcutDetails.targetMimeType; }
            if (mime === FOLDER) nameCache[id] = { name: f.name, parent: v === "my" ? folder : (f.parents ? f.parents[0] : null) };
            const href = mime === FOLDER ? `/drive?f=${id}` : `/drive/file/${id}`;
            const meta = [EXPORTS[mime] ? EXPORTS[mime].label : sizeText(f.size), f.owners && v === "shared" ? f.owners[0].displayName : ""].filter(Boolean).join(" · ");
            return `<a class="r" href="${href}"><span class="d">${dateText(f.modifiedTime)}</span>${icon(mime)} ${f.starred ? "★ " : ""}${esc(f.name)}${meta ? `<br><span class="s">${esc(meta)}</span>` : ""}</a>`;
        }).join("");
        const more = j.nextPageToken ? `<div class="p"><a class="btn" href="/drive?v=${v}&f=${folder}${q ? "&q=" + encodeURIComponent(q) : ""}&p=${encodeURIComponent(j.nextPageToken)}">Daha fazla ›</a></div>` : "";
        const tools = !q && (v === "my" || v === "all") ? `<a class="btn" href="/drive/up?f=${folder}">⬆ Dosya yükle</a><a class="btn" href="/drive/mkdir?f=${folder}">+ Klasör</a>` : "";
        res.type("html").send(page("Drive", topBar(q ? "" : v) +
            `<div class="bar"><form action="/drive" method="get"><input name="q" value="${esc(q)}" style="width:62%" placeholder="Drive'da ara"> <input type="submit" value="Ara"></form></div>` +
            `<div class="h"><b>${esc(title)}</b><br>${up}${tools}</div>` + (rows || `<div class="p">Boş.</div>`) + more));
    } catch (e) { errPage(res, e, v); }
});

// ---------- Dosya ----------

router.get("/drive/file/:id", async (req, res) => {
    if (!token) return res.redirect("/drive/setup");
    const id = req.params.id;
    try {
        const f = await apiJson("GET", "files/" + id, { fields: "id,name,mimeType,size,modifiedTime,starred,parents,owners(displayName),webViewLink", supportsAllDrives: "true" });
        const ex = EXPORTS[f.mimeType];
        const btn = (href, label) => `<a class="btn" href="${href}">${label}</a>`;
        let actions = "";
        let preview = "";
        if (ex) {
            if (ex.text) actions += btn(`/drive/text/${id}`, "📖 Metin olarak oku");
            actions += btn(`/drive/dl/${id}`, `⬇ ${ex.ext.toUpperCase()} olarak indir`);
        } else {
            if (f.mimeType.indexOf("image/") === 0) preview = `<div class="p"><img src="/drive/img/${id}?w=600" style="max-width:100%"></div>`;
            if (isText(f.mimeType, f.name) && parseInt(f.size || "0", 10) < 2000000) actions += btn(`/drive/text/${id}`, "📖 Oku");
            actions += btn(`/drive/dl/${id}`, "⬇ İndir" + (f.size ? " (" + sizeText(f.size) + ")" : ""));
            if (f.mimeType.indexOf("image/") === 0) actions += btn(`/drive/img/${id}?w=1200`, "Büyük resim");
        }
        const act = (a, label) => `<form method="post" action="/drive/act/${id}" style="display:inline"><input type="hidden" name="a" value="${a}"><input type="submit" value="${label}" class="btn"></form>`;
        actions += act(f.starred ? "unstar" : "star", f.starred ? "☆ Yıldızı kaldır" : "★ Yıldızla");
        actions += btn(`/drive/trash/${id}`, "🗑 Çöpe at");
        const parent = f.parents ? f.parents[0] : "root";
        res.type("html").send(page(f.name, topBar("") +
            `<div class="h">${icon(f.mimeType)} <b>${esc(f.name)}</b><br><span class="s">${esc(ex ? ex.label : f.mimeType)}${f.size ? " · " + sizeText(f.size) : ""} · ${dateText(f.modifiedTime)}` +
            `${f.owners ? " · " + esc(f.owners[0].displayName) : ""}</span><br>${actions}</div>${preview}<div class="p"><a href="/drive?f=${parent}">‹ Klasöre dön</a></div>`));
    } catch (e) { errPage(res, e); }
});

router.get("/drive/text/:id", async (req, res) => {
    if (!token) return res.redirect("/drive/setup");
    const id = req.params.id;
    try {
        const f = await apiJson("GET", "files/" + id, { fields: "name,mimeType", supportsAllDrives: "true" });
        const ex = EXPORTS[f.mimeType];
        const r = ex ? await api("GET", "files/" + id + "/export", { mimeType: ex.text }) : await api("GET", "files/" + id, { alt: "media", supportsAllDrives: "true" });
        let text = await r.text();
        if (text.length > 300000) text = text.slice(0, 300000) + "\n\n… (devamı kesildi)";
        let body;
        if (ex && ex.text === "text/csv") {
            const lines = text.split(/\r?\n/).slice(0, 400);
            body = "<table border=1 cellpadding=3 style='border-collapse:collapse;font-size:13px'>" + lines.map((l) => "<tr>" + l.split(",").map((c) => "<td>" + esc(c.replace(/^"|"$/g, "")) + "</td>").join("") + "</tr>").join("") + "</table>";
        } else {
            body = `<pre>${esc(text).replace(/(https?:\/\/[^\s<]+)/g, '<a href="$1">$1</a>')}</pre>`;
        }
        res.type("html").send(page(f.name, topBar("") + `<div class="h"><b>${esc(f.name)}</b> · <a href="/drive/file/${id}">Dosya</a></div><div class="b">${body}</div>`));
    } catch (e) { errPage(res, e); }
});

// Indirme: Google dosyalari PDF/JPEG'e cevrilir, digerleri oldugu gibi akitilir
router.get("/drive/dl/:id", async (req, res) => {
    if (!token) return res.redirect("/drive/setup");
    const id = req.params.id;
    try {
        const f = await apiJson("GET", "files/" + id, { fields: "name,mimeType,size", supportsAllDrives: "true" });
        const ex = EXPORTS[f.mimeType];
        const r = ex ? await api("GET", "files/" + id + "/export", { mimeType: ex.file }) : await api("GET", "files/" + id, { alt: "media", supportsAllDrives: "true" });
        const name = ex ? f.name.replace(/\.[^.]*$/, "") + "." + ex.ext : f.name;
        res.set("Content-Disposition", `attachment; filename*=UTF-8''${encodeURIComponent(name)}`);
        res.type(ex ? ex.file : (f.mimeType || "application/octet-stream"));
        const len = r.headers.get("content-length");
        if (len) res.set("Content-Length", len);
        Readable.fromWeb(r.body).pipe(res);
    } catch (e) { errPage(res, e); }
});

// Resim: telefona uygun genislige kucultulmus JPEG (onbellekli)
const IMG_DIR = path.join(os.tmpdir(), "e6drive_img");
if (!fs.existsSync(IMG_DIR)) fs.mkdirSync(IMG_DIR, { recursive: true });
router.get("/drive/img/:id", async (req, res) => {
    if (!token) return res.status(401).end();
    const id = req.params.id;
    if (!/^[\w-]+$/.test(id)) return res.status(400).end();
    const w = Math.min(1600, Math.max(100, parseInt(req.query.w || "600", 10)));
    const out = path.join(IMG_DIR, `${id}_${w}.jpg`);
    try {
        if (!fs.existsSync(out)) {
            const r = await api("GET", "files/" + id, { alt: "media", supportsAllDrives: "true" });
            const tmp = path.join(IMG_DIR, `${id}_src_${Date.now()}`);
            fs.writeFileSync(tmp, Buffer.from(await r.arrayBuffer()));
            await new Promise((ok, fail) => ffmpeg().input(tmp).outputOptions([`-vf scale='min(${w},iw)':-2`, "-q:v 5", "-frames:v 1"]).output(out).on("end", ok).on("error", fail).run());
            fs.unlink(tmp, () => { });
        }
        res.set("Cache-Control", "private, max-age=86400");
        res.type("image/jpeg").sendFile(out);
    } catch (e) { res.status(502).type("text/plain").send("Resim alınamadı: " + e.message); }
});

router.post("/drive/act/:id", express.urlencoded({ extended: false, limit: "4kb" }), async (req, res) => {
    const id = req.params.id;
    try {
        if (req.body.a === "star" || req.body.a === "unstar")
            await apiJson("PATCH", "files/" + id, { supportsAllDrives: "true" }, JSON.stringify({ starred: req.body.a === "star" }), { "Content-Type": "application/json" });
        res.redirect("/drive/file/" + id);
    } catch (e) { errPage(res, e); }
});

router.get("/drive/trash/:id", async (req, res) => {
    try {
        const f = await apiJson("GET", "files/" + req.params.id, { fields: "name", supportsAllDrives: "true" });
        res.type("html").send(page("Çöpe at", topBar("") + `<div class="b">“${esc(f.name)}” çöp kutusuna taşınsın mı? (Drive'ın çöpünden 30 gün içinde geri alınabilir)<br><br>
<form method="post" action="/drive/trash/${req.params.id}" style="display:inline"><input type="submit" value="Evet, çöpe at" class="btn"></form> <a class="btn" href="/drive/file/${req.params.id}">Vazgeç</a></div>`));
    } catch (e) { errPage(res, e); }
});
router.post("/drive/trash/:id", async (req, res) => {
    try {
        const f = await apiJson("PATCH", "files/" + req.params.id, { supportsAllDrives: "true", fields: "parents" }, JSON.stringify({ trashed: true }), { "Content-Type": "application/json" });
        res.redirect("/drive?f=" + (f.parents ? f.parents[0] : "root"));
    } catch (e) { errPage(res, e); }
});

// ---------- Yukleme ve klasor ----------

router.get("/drive/up", async (req, res) => {
    if (!token) return res.redirect("/drive/setup");
    const folder = /^[\w-]{4,}$/.test(req.query.f || "") ? req.query.f : "root";
    try {
        const info = await folderInfo(folder);
        res.type("html").send(page("Dosya yükle", topBar("") + `<div class="b"><b>“${esc(info.name)}” klasörüne yükle</b><br><br>
<form method="post" action="/drive/upload?f=${folder}" enctype="multipart/form-data">
<input type="file" name="file1"><br><br><input type="file" name="file2"><br><br><input type="file" name="file3"><br><br>
<input type="submit" value="Yükle" class="btn"> <a class="btn" href="/drive?f=${folder}">Vazgeç</a></form>
<p class="s">Dosya başına en fazla 16 MB.</p></div>`));
    } catch (e) { errPage(res, e); }
});

async function uploadOne(file, folder) {
    const boundary = "e6drive" + crypto.randomBytes(8).toString("hex");
    const meta = JSON.stringify({ name: file.name, parents: [folder] });
    const head = Buffer.from(`--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${meta}\r\n--${boundary}\r\nContent-Type: ${file.mimetype || "application/octet-stream"}\r\n\r\n`);
    const tail = Buffer.from(`\r\n--${boundary}--`);
    const body = Buffer.concat([head, file.data, tail]);
    return apiJson("POST", "https://www.googleapis.com/upload/drive/v3/files", { uploadType: "multipart", supportsAllDrives: "true", fields: "id,name" },
        body, { "Content-Type": "multipart/related; boundary=" + boundary });
}

router.post("/drive/upload", async (req, res) => {
    if (!token) return res.redirect("/drive/setup");
    const folder = /^[\w-]{4,}$/.test(req.query.f || "") ? req.query.f : "root";
    const files = Object.values(req.files || {}).flatMap((x) => (Array.isArray(x) ? x : [x])).filter((x) => x && x.size > 0);
    if (!files.length) return res.type("html").send(page("Yükleme", topBar("") + `<div class="e">Dosya seçilmedi.</div><div class="p"><a href="/drive/up?f=${folder}">Geri</a></div>`));
    const done = [], failed = [];
    for (const f of files) {
        try { await uploadOne(f, folder); done.push(f.name); } catch (e) { failed.push(f.name + ": " + e.message); }
    }
    res.type("html").send(page("Yükleme", topBar("") + `<div class="b">${done.map((n) => "✔ " + esc(n)).join("<br>")}${failed.length ? "<br><span class='e'>" + failed.map(esc).join("<br>") + "</span>" : ""}
<br><br><a class="btn" href="/drive?f=${folder}">Klasöre dön</a> <a class="btn" href="/drive/up?f=${folder}">Başka dosya yükle</a></div>`));
});

router.get("/drive/mkdir", async (req, res) => {
    const folder = /^[\w-]{4,}$/.test(req.query.f || "") ? req.query.f : "root";
    res.type("html").send(page("Yeni klasör", topBar("") + `<form method="post" action="/drive/mkdir?f=${folder}" class="b">Klasör adı<br><input name="name" style="width:90%"><br><br><input type="submit" value="Oluştur" class="btn"> <a class="btn" href="/drive?f=${folder}">Vazgeç</a></form>`));
});
router.post("/drive/mkdir", express.urlencoded({ extended: false, limit: "4kb" }), async (req, res) => {
    const folder = /^[\w-]{4,}$/.test(req.query.f || "") ? req.query.f : "root";
    const name = ("" + (req.body.name || "")).trim();
    if (!name) return res.redirect("/drive?f=" + folder);
    try {
        const f = await apiJson("POST", "files", { supportsAllDrives: "true", fields: "id" }, JSON.stringify({ name, mimeType: FOLDER, parents: [folder] }), { "Content-Type": "application/json" });
        res.redirect("/drive?f=" + f.id);
    } catch (e) { errPage(res, e); }
});

// ---------- JSON API (Drive uygulamasi icin; X-Api-Key basligi ile) ----------

const apiErr = (res, e) => {
    if (e.code !== 401) console.log("[drive api]", e.message);
    res.status(e.code === 401 ? 409 : 502).json({ error: e.message, needSetup: e.code === 401 });
};
const validId = (s) => /^[\w-]{4,}$/.test(s || "");
function itemOf(f) {
    let id = f.id, mime = f.mimeType;
    if (mime === "application/vnd.google-apps.shortcut" && f.shortcutDetails) { id = f.shortcutDetails.targetId; mime = f.shortcutDetails.targetMimeType; }
    const ex = EXPORTS[mime];
    let kind = "file";
    if (mime === FOLDER) kind = "folder";
    else if (mime.indexOf("image/") === 0) kind = "image";
    else if (mime.indexOf("video/") === 0) kind = "video";
    else if (mime.indexOf("audio/") === 0) kind = "audio";
    else if (mime === "application/pdf") kind = "pdf";
    else if (/spreadsheet|excel|csv/.test(mime)) kind = "sheet";
    else if (/presentation|powerpoint/.test(mime)) kind = "slides";
    else if (/document|msword|wordprocessing/.test(mime)) kind = "doc";
    else if (/zip|rar|7z|compressed|tar/.test(mime)) kind = "archive";
    else if (isText(mime, f.name)) kind = "text";
    const m = /\.([A-Za-z0-9]{1,5})$/.exec(f.name || "");
    return {
        id, name: f.name, mime, kind, ext: (m ? m[1] : (ex ? ex.ext : "")).toUpperCase(),
        size: parseInt(f.size || "0", 10), sizeText: ex ? ex.label : sizeText(f.size),
        modified: f.modifiedTime || "", date: dateText(f.modifiedTime), starred: !!f.starred,
        parent: f.parents ? f.parents[0] : "", owner: f.owners && f.owners[0] ? f.owners[0].displayName : "",
        google: !!ex, dlExt: ex ? ex.ext : "", canText: ex ? !!ex.text : (isText(mime, f.name) && parseInt(f.size || "0", 10) < 2000000)
    };
}

router.get("/drive/api/status", (req, res) => {
    res.json({ configured: !!cfg, connected: !!(token && token.refresh_token), email: token ? token.email || "" : "" });
});

router.get("/drive/api/list", async (req, res) => {
    const v = ["all", "my", "shared", "starred"].indexOf(req.query.v) >= 0 ? req.query.v : "all";
    const folder = validId(req.query.f) ? req.query.f : "root";
    const q = ("" + (req.query.q || "")).trim();
    try {
        const params = { pageSize: 40, fields: FIELDS, supportsAllDrives: "true", includeItemsFromAllDrives: "true", orderBy: "modifiedTime desc" };
        if (req.query.p) params.pageToken = "" + req.query.p;
        let title = "", parent = "";
        if (q) { params.q = `name contains '${q.replace(/\\/g, "\\\\").replace(/'/g, "\\'")}' and trashed=false`; title = "“" + q + "”"; }
        else if (v === "all") { params.q = "trashed=false"; title = "Tümü"; }
        else if (v === "shared") { params.q = "sharedWithMe and trashed=false"; title = "Paylaşılan"; }
        else if (v === "starred") { params.q = "starred and trashed=false"; title = "Yıldızlı"; }
        else {
            params.q = `'${folder}' in parents and trashed=false`;
            const info = await folderInfo(folder);
            title = info.name; parent = info.parent || "";
        }
        const j = await apiJson("GET", "files", params);
        const items = (j.files || []).map(itemOf);
        items.forEach((it) => { if (it.kind === "folder") nameCache[it.id] = nameCache[it.id] || { name: it.name, parent: it.parent || null }; });
        res.json({ title, folder: v === "my" ? folder : "", parent, items, next: j.nextPageToken || "" });
    } catch (e) { apiErr(res, e); }
});

router.get("/drive/api/file/:id", async (req, res) => {
    if (!validId(req.params.id)) return res.status(400).json({ error: "geçersiz" });
    try {
        const f = await apiJson("GET", "files/" + req.params.id, { fields: "id,name,mimeType,size,modifiedTime,starred,parents,owners(displayName),shortcutDetails", supportsAllDrives: "true" });
        res.json(itemOf(f));
    } catch (e) { apiErr(res, e); }
});

router.get("/drive/api/text/:id", async (req, res) => {
    if (!validId(req.params.id)) return res.status(400).end();
    try {
        const f = await apiJson("GET", "files/" + req.params.id, { fields: "mimeType", supportsAllDrives: "true" });
        const ex = EXPORTS[f.mimeType];
        const r = ex ? await api("GET", "files/" + req.params.id + "/export", { mimeType: ex.text }) : await api("GET", "files/" + req.params.id, { alt: "media", supportsAllDrives: "true" });
        let text = await r.text();
        if (text.length > 150000) text = text.slice(0, 150000) + "\n\n… (devamı kesildi)";
        res.type("text/plain; charset=utf-8").send(text);
    } catch (e) { res.status(502).type("text/plain; charset=utf-8").send("Okunamadı: " + e.message); }
});

// Yukleme: govde dosyanin kendisi (multipart degil); Google'a akitilarak gonderilir
// ?folderName=X : Drive'im altindaki X klasoru (yoksa olusturulur)
// ?replace=1    : klasorde ayni adli dosya varsa yenisi onun uzerine yazilir (ayni dosya, yeni surum)
const qstr = (s) => s.replace(/\\/g, "\\\\").replace(/'/g, "\\'");
async function findOrCreateFolder(name) {
    const j = await apiJson("GET", "files", { q: `name='${qstr(name)}' and mimeType='${FOLDER}' and 'root' in parents and trashed=false`, fields: "files(id)", pageSize: 1 });
    if (j.files && j.files.length) return j.files[0].id;
    const f = await apiJson("POST", "files", { fields: "id" }, JSON.stringify({ name, mimeType: FOLDER, parents: ["root"] }), { "Content-Type": "application/json" });
    return f.id;
}

router.post("/drive/api/upload", async (req, res) => {
    let folder = validId(req.query.f) ? req.query.f : "root";
    const name = ("" + (req.query.name || "")).trim().slice(0, 250) || "dosya";
    const len = parseInt(req.get("content-length") || "0", 10);
    if (!len) return res.status(400).json({ error: "Boş dosya" });
    if (len > 300 * 1024 * 1024) return res.status(413).json({ error: "Dosya 300 MB'tan büyük" });
    try {
        if (req.query.folderName) folder = await findOrCreateFolder(("" + req.query.folderName).trim().slice(0, 200));
        if (req.query.replace === "1") {
            const ex = await apiJson("GET", "files", { q: `name='${qstr(name)}' and '${folder}' in parents and trashed=false`, fields: "files(id)", pageSize: 1, supportsAllDrives: "true", includeItemsFromAllDrives: "true" });
            if (ex.files && ex.files.length) {
                const at0 = await accessToken();
                const r0 = await fetch("https://www.googleapis.com/upload/drive/v3/files/" + ex.files[0].id + "?uploadType=media&supportsAllDrives=true&fields=id,name,mimeType,size,modifiedTime,starred,parents", {
                    method: "PATCH", body: req, duplex: "half",
                    headers: { Authorization: "Bearer " + at0, "Content-Type": req.get("content-type") || "application/octet-stream", "Content-Length": "" + len }
                });
                const f0 = await r0.json().catch(() => ({}));
                if (!r0.ok || !f0.id) throw new Error((f0.error && f0.error.message) || "HTTP " + r0.status);
                console.log("[drive api] guncellendi:", name, len);
                return res.json(Object.assign(itemOf(f0), { replaced: true }));
            }
        }
        const at = await accessToken();
        const r = await fetch("https://www.googleapis.com/upload/drive/v3/files?uploadType=media&supportsAllDrives=true&fields=id", {
            method: "POST", body: req, duplex: "half",
            headers: { Authorization: "Bearer " + at, "Content-Type": req.get("content-type") || "application/octet-stream", "Content-Length": "" + len }
        });
        const j = await r.json().catch(() => ({}));
        if (!r.ok || !j.id) throw new Error((j.error && j.error.message) || "HTTP " + r.status);
        const p = { supportsAllDrives: "true", fields: "id,name,mimeType,size,modifiedTime,starred,parents" };
        if (folder !== "root") { p.addParents = folder; p.removeParents = "root"; }
        const f = await apiJson("PATCH", "files/" + j.id, p, JSON.stringify({ name }), { "Content-Type": "application/json" });
        console.log("[drive api] yuklendi:", name, len);
        res.json(itemOf(f));
    } catch (e) { apiErr(res, e); }
});

// Klasorde ayni adli dosya var mi: ?f=klasor &name=ad -> { exists }
router.get("/drive/api/exists", async (req, res) => {
    const parent = validId(req.query.f) ? req.query.f : "root";
    const name = ("" + (req.query.name || "")).trim();
    try {
        const j = await apiJson("GET", "files", { q: `name='${qstr(name)}' and '${parent}' in parents and trashed=false`, fields: "files(id)", pageSize: 1, supportsAllDrives: "true", includeItemsFromAllDrives: "true" });
        res.json({ exists: !!(j.files && j.files.length) });
    } catch (e) { apiErr(res, e); }
});

// Klasor bul ya da olustur: ?f=ust klasor id (varsayilan root) &name=ad  -> { id, name, created }
router.post("/drive/api/folder", async (req, res) => {
    const parent = validId(req.query.f) ? req.query.f : "root";
    const name = ("" + (req.query.name || "")).trim().slice(0, 250);
    if (!name) return res.status(400).json({ error: "Ad boş" });
    try {
        const j = await apiJson("GET", "files", { q: `name='${qstr(name)}' and mimeType='${FOLDER}' and '${parent}' in parents and trashed=false`, fields: "files(id,name)", pageSize: 1, supportsAllDrives: "true", includeItemsFromAllDrives: "true" });
        if (j.files && j.files.length) return res.json({ id: j.files[0].id, name, created: false });
        const f = await apiJson("POST", "files", { supportsAllDrives: "true", fields: "id" }, JSON.stringify({ name, mimeType: FOLDER, parents: [parent] }), { "Content-Type": "application/json" });
        res.json({ id: f.id, name, created: true });
    } catch (e) { apiErr(res, e); }
});

router.post("/drive/api/mkdir", async (req, res) => {
    const folder = validId(req.query.f) ? req.query.f : "root";
    const name = ("" + (req.query.name || "")).trim().slice(0, 250);
    if (!name) return res.status(400).json({ error: "Ad boş" });
    try {
        const f = await apiJson("POST", "files", { supportsAllDrives: "true", fields: "id,name,mimeType,modifiedTime,parents" }, JSON.stringify({ name, mimeType: FOLDER, parents: [folder] }), { "Content-Type": "application/json" });
        res.json(itemOf(f));
    } catch (e) { apiErr(res, e); }
});

router.post("/drive/api/star/:id", async (req, res) => {
    if (!validId(req.params.id)) return res.status(400).end();
    try {
        await apiJson("PATCH", "files/" + req.params.id, { supportsAllDrives: "true" }, JSON.stringify({ starred: req.query.on === "1" }), { "Content-Type": "application/json" });
        res.json({ ok: true, starred: req.query.on === "1" });
    } catch (e) { apiErr(res, e); }
});

router.post("/drive/api/trash/:id", async (req, res) => {
    if (!validId(req.params.id)) return res.status(400).end();
    try {
        await apiJson("PATCH", "files/" + req.params.id, { supportsAllDrives: "true" }, JSON.stringify({ trashed: true }), { "Content-Type": "application/json" });
        res.json({ ok: true });
    } catch (e) { apiErr(res, e); }
});

// ---------- Yeni dosya bildirimi (WhatsBelle'ya, posta bildirimi gibi) ----------
// Drive "changes" listesi 2 dakikada bir okunur; yeni olusturulan (guncellenen degil) dosyalar
// icin bildirim gonderilir. Kaldigi yer data/drive_watch.json'da tutulur.
const WATCH_FILE = path.join(DATA, "drive_watch.json");
const RECENT_FILE = path.join(DATA, "drive_recent.json");
// WhatsBelle Posta sekmesi: son yuklenen Drive dosyalari
router.get("/drive/api/recent", (req, res) => res.json({ items: readJson(RECENT_FILE) || [] }));
let notifyHook = null;
let watch = readJson(WATCH_FILE) || {};
router.setNotifyHook = (fn) => { notifyHook = fn; };

async function checkDriveChanges() {
    if (!cfg || !token || !token.refresh_token || !notifyHook) return;
    try {
        if (!watch.pageToken) {
            const s = await apiJson("GET", "changes/startPageToken", { supportsAllDrives: "true" });
            watch = { pageToken: s.startPageToken, since: Date.now() };
            writeJson(WATCH_FILE, watch);
            console.log("[drive] yeni dosya izleme basladi");
            return;
        }
        const fresh = [];
        let pageToken = watch.pageToken, next = null;
        for (let guard = 0; guard < 10 && pageToken; guard++) {
            const r = await apiJson("GET", "changes", {
                pageToken, pageSize: "100", spaces: "drive", includeRemoved: "false",
                fields: "nextPageToken,newStartPageToken,changes(fileId,time,file(name,mimeType,createdTime,trashed,size))"
            });
            for (const c of r.changes || []) {
                const f = c.file;
                if (!f || f.trashed || f.mimeType === "application/vnd.google-apps.folder") continue;
                const created = Date.parse(f.createdTime || "") || 0;
                // yalnizca son kontrolden beri olusturulanlar (5 dk pay)
                if (created < (watch.since || 0) - 5 * 60 * 1000) continue;
                if (fresh.find((x) => x.id === c.fileId)) continue;
                fresh.push({ id: c.fileId, name: f.name || "(adsız)", size: +f.size || 0 });
            }
            if (r.newStartPageToken) { next = r.newStartPageToken; break; }
            pageToken = r.nextPageToken;
            next = pageToken;
        }
        if (next) { watch.pageToken = next; watch.since = Date.now(); writeJson(WATCH_FILE, watch); }
        if (!fresh.length) return;
        // Posta sekmesinde gosterilmek uzere son yuklenenler (en yeni 20)
        const recent = readJson(RECENT_FILE) || [];
        for (const x of fresh) recent.unshift({ id: x.id, name: x.name, size: x.size, ts: Date.now() });
        writeJson(RECENT_FILE, recent.slice(0, 20));
        const kb =(b) => b >= 1048576 ? (b / 1048576).toFixed(1) + " MB" : Math.max(1, Math.round(b / 1024)) + " KB";
        if (fresh.length === 1) notifyHook("Drive: dosya yüklendi", fresh[0].name + (fresh[0].size ? " (" + kb(fresh[0].size) + ")" : ""));
        else notifyHook(`Drive: ${fresh.length} dosya yüklendi`, fresh.map((x) => x.name).join(", "));
        console.log(`[drive] ${fresh.length} yeni dosya bildirildi: ${fresh.map((x) => x.name).join(", ")}`);
    } catch (e) {
        console.log("[drive] degisiklikler okunamadi:", e.message);
        if (/pageToken|Invalid Value/i.test(e.message)) { watch = {}; writeJson(WATCH_FILE, watch); }
    }
}
setTimeout(checkDriveChanges, 20 * 1000);
setInterval(checkDriveChanges, 2 * 60 * 1000);

module.exports = router;
// Diger modullerin (sunucu tarayicisi indirmeleri) kullanimi icin
router.uploadOne = uploadOne;
router.apiJson = apiJson;     // web paneli (Nokia E6 SIS listesi)
router.apiJson = apiJson;
router.bagli = () => !!(token && token.refresh_token);
