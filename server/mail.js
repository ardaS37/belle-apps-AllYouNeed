// BelleMail - sunucu tarafli e-posta: agir isi sunucu yapar, telefon sade HTML sayfasi acar.
//
//  - Sunucu posta kutusuna IMAP ile surekli bagli kalir (IDLE); yeni posta gelince WhatsBelle'nin
//    bildirim kuyruguna eklenir (telefonda kose bildirimi).
//  - /mail sayfalari: liste, okuma, yanitlama/yeni posta (SMTP), arsiv, cop, okunmadi isareti.
//    Sayfalar gzip ile sikistirilir, resim/betik icermez; ekler istege bagli indirilir.
//  - Kimlik: sunucunun mevcut parola korumasi (tarayici kullanici adi/parola penceresi).
//  - Hesap: /mail/setup sayfasindan girilir (Gmail icin "uygulama sifresi"); data/mail.json'da saklanir.

const express = require("express");
const fs = require("fs");
const path = require("path");
const os = require("os");
const { ImapFlow } = require("imapflow");
const nodemailer = require("nodemailer");
const compression = require("compression");
const ffmpeg = require("fluent-ffmpeg");

const router = new express.Router();
const CFG_FILE = path.join(__dirname, "data", "mail.json");
const PAGE = 20;

let cfg = null;
try { cfg = JSON.parse(fs.readFileSync(CFG_FILE, "utf8")); } catch (e) { }

let notifyHook = null;   // server.js baglar: (title, text) => WhatsBelle bildirim kuyruguna ekle
function setNotifyHook(fn) { notifyHook = fn; }

const PRESETS = {
    gmail: { host: "imap.gmail.com", port: 993, smtpHost: "smtp.gmail.com", smtpPort: 465 },
    outlook: { host: "outlook.office365.com", port: 993, smtpHost: "smtp.office365.com", smtpPort: 587 },
    yandex: { host: "imap.yandex.com", port: 993, smtpHost: "smtp.yandex.com", smtpPort: 465 },
    yahoo: { host: "imap.mail.yahoo.com", port: 993, smtpHost: "smtp.mail.yahoo.com", smtpPort: 465 },
    icloud: { host: "imap.mail.me.com", port: 993, smtpHost: "smtp.mail.me.com", smtpPort: 587 }
};

// ---------- Yardimcilar ----------

const esc = (s) => ("" + (s == null ? "" : s)).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));

function addrName(a) {
    if (!a) return "";
    return a.name || a.address || "";
}
function addrList(list) { return (list || []).map((a) => a.name ? `${a.name} <${a.address}>` : a.address).join(", "); }

function shortDate(d) {
    if (!d) return "";
    const t = new Date(d);
    const now = new Date();
    const pad = (n) => (n < 10 ? "0" : "") + n;
    if (t.toDateString() === now.toDateString()) return pad(t.getHours()) + ":" + pad(t.getMinutes());
    const y = new Date(now); y.setDate(now.getDate() - 1);
    if (t.toDateString() === y.toDateString()) return "Dün";
    if (now - t < 6 * 86400000) return ["Paz", "Pzt", "Sal", "Çar", "Per", "Cum", "Cmt"][t.getDay()];
    return pad(t.getDate()) + "." + pad(t.getMonth() + 1) + (t.getFullYear() !== now.getFullYear() ? "." + t.getFullYear() : "");
}
function longDate(d) {
    if (!d) return "";
    const t = new Date(d);
    const pad = (n) => (n < 10 ? "0" : "") + n;
    return pad(t.getDate()) + "." + pad(t.getMonth() + 1) + "." + t.getFullYear() + " " + pad(t.getHours()) + ":" + pad(t.getMinutes());
}
function sizeText(b) {
    if (b >= 1048576) return (b / 1048576).toFixed(1) + " MB";
    return Math.max(1, Math.round(b / 1024)) + " KB";
}

// HTML postayi okunur duz metne cevirir (bagliantilar korunur)
function htmlToText(html) {
    let s = ("" + html)
        .replace(/<(script|style|head|title)[\s\S]*?<\/\1>/gi, "")
        .replace(/<(script|style|head)\b[\s\S]*$/i, "")      // onizlemede yarida kesilmis blok
        .replace(/<!--[\s\S]*?-->/g, "")
        .replace(/<a\s[^>]*href\s*=\s*["']?([^"' >]+)["']?[^>]*>([\s\S]*?)<\/a>/gi, (m, href, txt) => {
            const t = txt.replace(/<[^>]+>/g, "").trim();
            if (!/^https?:/i.test(href)) return t;
            return t && t !== href ? `${t} [${href}]` : href;
        })
        .replace(/<br\s*\/?>/gi, "\n")
        .replace(/<\/(p|div|tr|h[1-6]|li|table|blockquote)>/gi, "\n")
        .replace(/<li[^>]*>/gi, "• ")
        .replace(/<td[^>]*>/gi, " ")
        .replace(/<[^>]+>/g, "");
    s = s.replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;/g, "'")
        .replace(/&#(\d+);/g, (m, n) => String.fromCharCode(+n));
    return s.replace(/[ \t ]+/g, " ").replace(/ *\n */g, "\n").replace(/\n{3,}/g, "\n\n").trim();
}

// Duz metni guvenli HTML'e cevirir; adresleri tiklanabilir yapar, uzun alinti bloklarini kisaltir
function textToHtml(text) {
    let lines = ("" + text).replace(/\r/g, "").split("\n");
    // "On ... wrote:" sonrasindaki alintilari (> ile baslayan) 3 satira indir
    const out = [];
    let quoted = 0;
    for (const l of lines) {
        if (/^\s*>/.test(l)) { quoted++; if (quoted <= 3) out.push(l); else if (quoted === 4) out.push("> …"); continue; }
        quoted = 0;
        out.push(l);
    }
    return esc(out.join("\n"))
        .replace(/(https?:\/\/[^\s<\]\)]+)/g, (u) => `<a href="${u}">${u.length > 60 ? u.slice(0, 57) + "…" : u}</a>`)
        .replace(/\n/g, "<br>");
}

function findParts(node, acc) {
    acc = acc || { text: null, html: null, att: [] };
    if (!node) return acc;
    if (node.childNodes && node.childNodes.length) {
        for (const c of node.childNodes) findParts(c, acc);
        return acc;
    }
    const type = (node.type || "").toLowerCase();
    const disp = (node.disposition || "").toLowerCase();
    const name = (node.dispositionParameters && node.dispositionParameters.filename) || (node.parameters && node.parameters.name) || "";
    if (disp === "attachment" || (name && type.indexOf("text/") !== 0)) {
        acc.att.push({ part: node.part || "1", name: name || "ek", type, size: node.size || 0 });
    } else if (type === "text/plain" && !acc.text) acc.text = node.part || "1";
    else if (type === "text/html" && !acc.html) acc.html = node.part || "1";
    else if (type.indexOf("image/") === 0 && node.id) { /* govdeye gomulu resim: atla */ }
    return acc;
}

async function streamToString(stream, max) {
    const chunks = [];
    let n = 0;
    for await (const c of stream) { chunks.push(c); n += c.length; if (max && n >= max) break; }
    return Buffer.concat(chunks).toString("utf8");
}

// ---------- IMAP baglantilari ----------
// "worker": sayfa istekleri icin (5 dk bos kalinca kapanir); "watcher": INBOX'u IDLE ile izler

let worker = null, workerTimer = null, workerBusy = Promise.resolve();
let folders = null;   // { inbox, sent, trash, spam, all, drafts }

function newClient() {
    return new ImapFlow({
        host: cfg.host, port: cfg.port || 993, secure: true,
        auth: { user: cfg.user, pass: cfg.pass },
        logger: false, emitLogs: false
    });
}

async function getWorker() {
    if (!cfg) throw new Error("Posta hesabı girilmemiş");
    if (worker && worker.usable) return worker;
    worker = newClient();
    worker.on("error", () => { });
    await worker.connect();
    if (!folders) {
        const list = await worker.list();
        const by = (u) => { const f = list.find((x) => x.specialUse === u); return f ? f.path : null; };
        folders = { inbox: "INBOX", sent: by("\\Sent"), trash: by("\\Trash"), spam: by("\\Junk"), all: by("\\All"), drafts: by("\\Drafts"), starred: by("\\Flagged") };
    }
    return worker;
}

// Ayni anda tek islem (kutu kilidi sirayla)
function withMailbox(box, fn) {
    const run = workerBusy.then(async () => {
        const c = await getWorker();
        clearTimeout(workerTimer);
        const lock = await c.getMailboxLock(box);
        try { return await fn(c); } finally {
            lock.release();
            workerTimer = setTimeout(() => { if (worker) worker.logout().catch(() => { }); worker = null; }, 5 * 60 * 1000);
        }
    });
    workerBusy = run.catch(() => { });
    return run;
}

let watcher = null, watchRetry = 5000, lastExists = -1;
async function startWatcher() {
    if (!cfg) return;
    try {
        watcher = newClient();
        watcher.on("error", (e) => console.log("[posta] izleme hatasi:", e.message));
        watcher.on("close", () => { watcher = null; setTimeout(startWatcher, watchRetry); watchRetry = Math.min(watchRetry * 2, 5 * 60 * 1000); });
        await watcher.connect();
        const box = await watcher.mailboxOpen("INBOX");
        lastExists = box.exists;
        watchRetry = 5000;
        console.log("[posta] gelen kutusu izleniyor:", cfg.user, "(" + box.exists + " posta)");
        watcher.on("exists", async (d) => {
            const from = lastExists > 0 ? lastExists + 1 : d.count;
            lastExists = d.count;
            if (d.count < from) return;
            try {
                for await (const m of watcher.fetch(`${from}:${d.count}`, { envelope: true, flags: true })) {
                    if (m.flags && m.flags.has("\\Seen")) continue;
                    const sender = addrName(m.envelope.from && m.envelope.from[0]) || "E-posta";
                    if (notifyHook) notifyHook("✉ " + sender, m.envelope.subject || "(konu yok)");
                }
            } catch (e) { console.log("[posta] yeni posta okunamadi:", e.message); }
        });
        // imapflow komut olmayinca kendiliginden IDLE'a gecer
    } catch (e) {
        console.log("[posta] baglanilamadi:", e.message);
        watcher = null;
        setTimeout(startWatcher, watchRetry);
        watchRetry = Math.min(watchRetry * 2, 5 * 60 * 1000);
    }
}

function stopAll() {
    if (watcher) { const w = watcher; watcher = null; w.removeAllListeners("close"); w.logout().catch(() => { }); }
    if (worker) { worker.logout().catch(() => { }); worker = null; }
    folders = null;
}

// ---------- Onizleme onbellegi ----------
const snippetCache = new Map();   // "kutu:uidValidity:uid" -> metin
function cacheKey(box, uv, uid) { return box + ":" + uv + ":" + uid; }

async function snippetFor(c, box, uv, msg) {
    const k = cacheKey(box, uv, msg.uid);
    if (snippetCache.has(k)) return snippetCache.get(k);
    const p = findParts(msg.bodyStructure);
    const part = p.text || p.html;
    let s = "";
    if (part) {
        try {
            const lim = p.text ? 4000 : 24000;   // HTML basinda uzun stil bloklari olabiliyor
            const dl = await c.download(msg.uid, part, { uid: true, maxBytes: lim });
            let t = await streamToString(dl.content, lim);
            if (!p.text) t = htmlToText(t);
            s = t.replace(/[^{}\n]*\{[^}]*\}/g, " ").replace(/\[image:[^\]]*\]/gi, "").replace(/\s+/g, " ").trim().slice(0, 140);
        } catch (e) { }
    }
    snippetCache.set(k, s);
    if (snippetCache.size > 3000) snippetCache.delete(snippetCache.keys().next().value);
    return s;
}

// ---------- Sayfa iskeleti ----------
const CSS = `body{margin:0;font-family:sans-serif;font-size:15px;background:#fff;color:#111}
a{color:#0b57d0;text-decoration:none}.top{background:#202124;color:#fff;padding:6px 8px}.top a{color:#fff;margin-right:10px}
.top b{margin-right:12px}.bar{padding:6px 8px;background:#f1f3f4;border-bottom:1px solid #ddd}
.m{display:block;padding:6px 8px;border-bottom:1px solid #e3e3e3;color:#111}.u{font-weight:bold;background:#eef4ff}
.d{float:right;color:#666;font-size:13px;font-weight:normal}.s{color:#555;font-size:13px}.n{color:#444}
.h{padding:8px;border-bottom:1px solid #ddd}.b{padding:8px;line-height:1.35;word-wrap:break-word}
.btn{display:inline-block;padding:5px 9px;margin:2px;border:1px solid #bbb;background:#f8f8f8;color:#111}
input,textarea{width:96%;font-size:15px}.p{padding:8px;text-align:center}.e{color:#b00020;padding:8px}`;

function page(title, body) {
    return `<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>${esc(title)}</title><style>${CSS}</style></head><body>${body}</body></html>`;
}

function topBar(active) {
    const t = (id, label) => (active === id ? `<b>${label}</b>` : `<a href="/mail?f=${id}">${label}</a>`);
    return `<div class="top">${t("inbox", "Gelen")}${t("starred", "Yıldızlı")}${t("sent", "Giden")}${t("spam", "Spam")}${t("trash", "Çöp")}<a href="/mail/new">✎ Yeni</a></div>`;
}

function boxPath(f) {
    if (!folders) return "INBOX";
    return (f && folders[f]) || "INBOX";
}

// ---------- Uc noktalar ----------

router.use("/mail", compression());

router.get("/mail/setup", (req, res) => {
    const opts = Object.keys(PRESETS).map((k) => `<option value="${k}"${cfg && cfg.preset === k ? " selected" : ""}>${k}</option>`).join("");
    res.type("html").send(page("Posta kurulumu", `<div class="top"><b>Posta kurulumu</b><a href="/mail">Gelen kutusu</a></div><div class="b">
${cfg ? `<p>Kayıtlı hesap: <b>${esc(cfg.user)}</b></p>` : ""}
<p>Gmail için hesabınızda 2 adımlı doğrulama açık olmalı. Sonra myaccount.google.com → Güvenlik → <b>Uygulama şifreleri</b> bölümünden 16 haneli bir şifre oluşturup aşağıya girin (normal Gmail şifreniz değil).</p>
<form method="post" action="/mail/setup">Sağlayıcı<br><select name="preset">${opts}</select><br><br>
E-posta adresi<br><input name="user" value="${cfg ? esc(cfg.user) : ""}"><br><br>
Uygulama şifresi<br><input name="pass" type="password"><br><br>
Görünen ad (giden postalarda)<br><input name="name" value="${cfg ? esc(cfg.name || "") : ""}"><br><br>
<input type="submit" value="Kaydet ve bağlan" style="width:auto"></form></div>`));
});

router.post("/mail/setup", express.urlencoded({ extended: false, limit: "8kb" }), async (req, res) => {
    const p = PRESETS[req.body.preset] || PRESETS.gmail;
    const user = ("" + (req.body.user || "")).trim();
    const pass = ("" + (req.body.pass || "")).replace(/\s+/g, "") || (cfg && cfg.user === user ? cfg.pass : "");
    if (!/@/.test(user) || !pass) return res.type("html").send(page("Hata", `<div class="e">Adres ve şifre gerekli.</div><div class="p"><a href="/mail/setup">Geri</a></div>`));
    const next = Object.assign({ preset: req.body.preset, user, pass, name: ("" + (req.body.name || "")).trim() }, p);
    // Once dene
    const test = new ImapFlow({ host: next.host, port: next.port, secure: true, auth: { user, pass }, logger: false });
    try {
        await test.connect();
        await test.logout();
    } catch (e) {
        return res.type("html").send(page("Hata", `<div class="e">Bağlanılamadı: ${esc(e.responseText || e.message)}</div><div class="p"><a href="/mail/setup">Geri</a></div>`));
    }
    stopAll();
    cfg = next;
    fs.writeFileSync(CFG_FILE, JSON.stringify(cfg), { mode: 0o600 });
    startWatcher();
    res.redirect("/mail");
});

router.get("/mail", async (req, res) => {
    if (!cfg) return res.redirect("/mail/setup");
    const f = ["inbox", "sent", "trash", "spam", "starred", "all"].indexOf(req.query.f) >= 0 ? req.query.f : "inbox";
    const pg = Math.max(0, parseInt(req.query.p || "0", 10));
    const q = ("" + (req.query.q || "")).trim();
    try {
        await getWorker();
        const box = boxPath(f);
        const data = await withMailbox(box, async (c) => {
            const mb = c.mailbox;
            let uids;
            if (q) {
                const isGmail = /gmail/.test(cfg.host);
                uids = await c.search(isGmail ? { gmraw: q } : { or: [{ subject: q }, { from: q }, { body: q }] }, { uid: true });
                uids = (uids || []).sort((a, b) => b - a);
            } else {
                const total = mb.exists;
                const hi = total - pg * PAGE, lo = Math.max(1, hi - PAGE + 1);
                if (hi < 1) return { items: [], total, more: false };
                const items = [];
                for await (const m of c.fetch(`${lo}:${hi}`, { uid: true, envelope: true, flags: true, bodyStructure: true, size: true })) items.push(m);
                items.sort((a, b) => b.uid - a.uid);
                for (const m of items) m.snippet = await snippetFor(c, box, mb.uidValidity, m);
                return { items, total, more: lo > 1 };
            }
            const pageUids = uids.slice(pg * PAGE, pg * PAGE + PAGE);
            const items = [];
            if (pageUids.length) for await (const m of c.fetch(pageUids.join(","), { uid: true, envelope: true, flags: true, bodyStructure: true, size: true }, { uid: true })) items.push(m);
            items.sort((a, b) => b.uid - a.uid);
            for (const m of items) m.snippet = await snippetFor(c, box, mb.uidValidity, m);
            return { items, total: uids.length, more: uids.length > (pg + 1) * PAGE };
        });
        const rows = data.items.map((m) => {
            const unread = !(m.flags && m.flags.has("\\Seen"));
            const who = f === "sent" ? "Kime: " + addrName(m.envelope.to && m.envelope.to[0]) : addrName(m.envelope.from && m.envelope.from[0]);
            const att = findParts(m.bodyStructure).att.length ? " 📎" : "";
            const star = m.flags && m.flags.has("\\Flagged") ? "★ " : "";
            return `<a class="m${unread ? " u" : ""}" href="/mail/m/${f}/${m.uid}"><span class="d">${shortDate(m.envelope.date)}</span>${star}${esc(who)}${att}<br>` +
                `<span class="n">${esc(m.envelope.subject || "(konu yok)")}</span><br><span class="s">${esc(m.snippet || "")}</span></a>`;
        }).join("");
        const qs = (p) => `/mail?f=${f}&p=${p}${q ? "&q=" + encodeURIComponent(q) : ""}`;
        const nav = `<div class="p">${pg > 0 ? `<a class="btn" href="${qs(pg - 1)}">‹ Yeni</a>` : ""}${data.more ? `<a class="btn" href="${qs(pg + 1)}">Eski ›</a>` : ""}</div>`;
        res.type("html").send(page("Posta", topBar(f) +
            `<div class="bar"><form action="/mail" method="get"><input type="hidden" name="f" value="${f}"><input name="q" value="${esc(q)}" style="width:62%" placeholder="Ara"> <input type="submit" value="Ara" style="width:auto"> <a href="/mail?f=${f}">↻</a></form>` +
            `<span class="s">${esc(cfg.user)} · ${data.total} posta</span></div>` + (rows || `<div class="p">Posta yok.</div>`) + nav));
    } catch (e) {
        console.log("[posta] liste hatasi:", e.message);
        res.status(502).type("html").send(page("Hata", topBar(f) + `<div class="e">Posta kutusuna ulaşılamadı: ${esc(e.responseText || e.message)}</div><div class="p"><a href="/mail/setup">Hesap ayarları</a></div>`));
    }
});

router.get("/mail/m/:f/:uid", async (req, res) => {
    if (!cfg) return res.redirect("/mail/setup");
    const f = req.params.f, uid = parseInt(req.params.uid, 10);
    try {
        await getWorker();
        const box = boxPath(f);
        const r = await withMailbox(box, async (c) => {
            const m = await c.fetchOne(uid, { uid: true, envelope: true, flags: true, bodyStructure: true, size: true }, { uid: true });
            if (!m) return null;
            const p = findParts(m.bodyStructure);
            let text = "";
            const part = p.text || p.html;
            if (part) {
                const dl = await c.download(uid, part, { uid: true, maxBytes: 400000 });
                text = await streamToString(dl.content, 400000);
                if (!p.text) text = htmlToText(text);
            }
            if (!(m.flags && m.flags.has("\\Seen"))) await c.messageFlagsAdd(uid, ["\\Seen"], { uid: true });
            return { m, text, att: p.att };
        });
        if (!r) return res.status(404).type("html").send(page("Yok", topBar(f) + `<div class="e">Posta bulunamadı.</div>`));
        const e = r.m.envelope;
        const att = r.att.map((a) => `<a class="btn" href="/mail/att/${f}/${uid}/${encodeURIComponent(a.part)}">📎 ${esc(a.name)} (${sizeText(a.size)})</a>`).join(" ");
        const starred = r.m.flags && r.m.flags.has("\\Flagged");
        const act = (a, label) => `<form method="post" action="/mail/act/${f}/${uid}" style="display:inline"><input type="hidden" name="a" value="${a}"><input type="submit" value="${label}" style="width:auto" class="btn"></form>`;
        res.type("html").send(page(e.subject || "Posta", topBar(f) +
            `<div class="h"><b>${esc(e.subject || "(konu yok)")}</b><br><span class="s">Kimden: ${esc(addrList(e.from))}<br>Kime: ${esc(addrList(e.to))}` +
            (e.cc && e.cc.length ? `<br>Bilgi: ${esc(addrList(e.cc))}` : "") + `<br>${longDate(e.date)}</span><br>` +
            `<a class="btn" href="/mail/new?re=${f}:${uid}">↩ Yanıtla</a><a class="btn" href="/mail/new?re=${f}:${uid}&all=1">Tümüne</a><a class="btn" href="/mail/new?fw=${f}:${uid}">İlet</a>` +
            (f !== "trash" ? act("archive", "Arşivle") + act("trash", "Sil") : "") + act("unread", "Okunmadı") + act(starred ? "unstar" : "star", starred ? "☆ Yıldızı kaldır" : "★ Yıldız") +
            `</div>` + (att ? `<div class="bar">${att}</div>` : "") +
            `<div class="b">${textToHtml(r.text) || "<i>(metin yok)</i>"}</div><div class="p"><a href="/mail?f=${f}">‹ Listeye dön</a></div>`));
    } catch (e) {
        res.status(502).type("html").send(page("Hata", topBar(f) + `<div class="e">${esc(e.responseText || e.message)}</div>`));
    }
});

router.post("/mail/act/:f/:uid", express.urlencoded({ extended: false, limit: "4kb" }), async (req, res) => {
    const f = req.params.f, uid = parseInt(req.params.uid, 10), a = req.body.a;
    try {
        await getWorker();
        await withMailbox(boxPath(f), async (c) => {
            if (a === "archive") {
                if (/gmail/.test(cfg.host)) await c.messageDelete(uid, { uid: true });   // Gmail: gelen kutusundan kaldirmak = arsiv
                else if (folders.all) await c.messageMove(uid, folders.all, { uid: true });
            } else if (a === "trash" && folders.trash) await c.messageMove(uid, folders.trash, { uid: true });
            else if (a === "unread") await c.messageFlagsRemove(uid, ["\\Seen"], { uid: true });
            else if (a === "star") await c.messageFlagsAdd(uid, ["\\Flagged"], { uid: true });
            else if (a === "unstar") await c.messageFlagsRemove(uid, ["\\Flagged"], { uid: true });
        });
        res.redirect(a === "star" || a === "unstar" ? `/mail/m/${f}/${uid}` : `/mail?f=${f}`);
    } catch (e) {
        res.status(502).type("html").send(page("Hata", topBar(f) + `<div class="e">${esc(e.responseText || e.message)}</div>`));
    }
});

// Ek indirme: resimler telefona uygun boyuta kucultulur
router.get("/mail/att/:f/:uid/:part", async (req, res) => {
    const f = req.params.f, uid = parseInt(req.params.uid, 10), part = req.params.part;
    if (!/^[\d.]+$/.test(part)) return res.status(400).end();
    try {
        await getWorker();
        const r = await withMailbox(boxPath(f), async (c) => {
            const dl = await c.download(uid, part, { uid: true, maxBytes: 25 * 1024 * 1024 });
            const chunks = [];
            for await (const ch of dl.content) chunks.push(ch);
            return { meta: dl.meta || {}, buf: Buffer.concat(chunks) };
        });
        const type = (r.meta.contentType || "application/octet-stream").toLowerCase();
        const name = r.meta.filename || ("ek_" + part);
        if (/^image\/(jpeg|png|gif|webp|bmp)/.test(type) && r.buf.length > 150 * 1024 && req.query.raw !== "1") {
            const tmpIn = path.join(os.tmpdir(), `att_${uid}_${part}_${Date.now()}`);
            const tmpOut = tmpIn + ".jpg";
            fs.writeFileSync(tmpIn, r.buf);
            await new Promise((ok, fail) => ffmpeg().input(tmpIn).outputOptions(["-vf scale='min(800,iw)':-2", "-q:v 5", "-frames:v 1"]).output(tmpOut).on("end", ok).on("error", fail).run());
            res.type("image/jpeg").send(fs.readFileSync(tmpOut));
            fs.unlink(tmpIn, () => { }); fs.unlink(tmpOut, () => { });
            return;
        }
        res.set("Content-Disposition", `attachment; filename*=UTF-8''${encodeURIComponent(name)}`);
        res.type(type).send(r.buf);
    } catch (e) {
        res.status(502).type("text/plain").send("Ek indirilemedi: " + e.message);
    }
});

router.get("/mail/new", async (req, res) => {
    if (!cfg) return res.redirect("/mail/setup");
    let to = "", subject = "", body = "", ref = "";
    try {
        const src = req.query.re || req.query.fw;
        if (src) {
            const [f, u] = ("" + src).split(":");
            const uid = parseInt(u, 10);
            await getWorker();
            const r = await withMailbox(boxPath(f), async (c) => {
                const m = await c.fetchOne(uid, { uid: true, envelope: true, bodyStructure: true }, { uid: true });
                const p = findParts(m.bodyStructure);
                let text = "";
                const part = p.text || p.html;
                if (part) {
                    const dl = await c.download(uid, part, { uid: true, maxBytes: 60000 });
                    text = await streamToString(dl.content, 60000);
                    if (!p.text) text = htmlToText(text);
                }
                return { e: m.envelope, text };
            });
            const e = r.e;
            const subj = e.subject || "";
            if (req.query.re) {
                const me = cfg.user.toLowerCase();
                const replyTo = (e.replyTo && e.replyTo.length ? e.replyTo : e.from) || [];
                let list = replyTo.map((a) => a.address);
                if (req.query.all) list = list.concat((e.to || []).concat(e.cc || []).map((a) => a.address));
                to = Array.from(new Set(list.filter((x) => x && x.toLowerCase() !== me))).join(", ");
                subject = /^re:/i.test(subj) ? subj : "Re: " + subj;
                ref = e.messageId || "";
                const quoted = r.text.split("\n").slice(0, 40).map((l) => "> " + l).join("\n");
                body = `\n\n${longDate(e.date)} tarihinde ${addrName(e.from && e.from[0])} yazdı:\n${quoted}`;
            } else {
                subject = /^(fw|fwd|ilt):/i.test(subj) ? subj : "Fwd: " + subj;
                body = `\n\n---------- İletilen posta ----------\nKimden: ${addrList(e.from)}\nTarih: ${longDate(e.date)}\nKonu: ${subj}\n\n${r.text.slice(0, 20000)}`;
            }
        }
    } catch (e) { console.log("[posta] yanit hazirlanamadi:", e.message); }
    res.type("html").send(page("Yeni posta", topBar("") +
        `<form method="post" action="/mail/send" class="b"><input type="hidden" name="ref" value="${esc(ref)}">
Kime<br><input name="to" value="${esc(to)}"><br>Konu<br><input name="subject" value="${esc(subject)}"><br>
<textarea name="body" rows="12">${esc(body)}</textarea><br><input type="submit" value="Gönder" style="width:auto"> <a href="/mail">Vazgeç</a></form>`));
});

router.post("/mail/send", express.urlencoded({ extended: false, limit: "512kb" }), async (req, res) => {
    if (!cfg) return res.redirect("/mail/setup");
    const to = ("" + (req.body.to || "")).trim();
    if (!/@/.test(to)) return res.type("html").send(page("Hata", `<div class="e">Alıcı adresi gerekli.</div><div class="p"><a href="javascript:history.back()">Geri</a></div>`));
    try {
        const tr = nodemailer.createTransport({
            host: cfg.smtpHost, port: cfg.smtpPort, secure: cfg.smtpPort === 465,
            auth: { user: cfg.user, pass: cfg.pass }
        });
        const msg = {
            from: cfg.name ? { name: cfg.name, address: cfg.user } : cfg.user,
            to, subject: ("" + (req.body.subject || "")).trim() || "(konu yok)",
            text: ("" + (req.body.body || "")).replace(/\r\n/g, "\n")
        };
        if (req.body.ref) { msg.inReplyTo = req.body.ref; msg.references = req.body.ref; }
        await tr.sendMail(msg);
        res.type("html").send(page("Gönderildi", topBar("") + `<div class="p">✔ Posta gönderildi.<br><br><a class="btn" href="/mail">Gelen kutusu</a></div>`));
    } catch (e) {
        res.status(502).type("html").send(page("Hata", topBar("") + `<div class="e">Gönderilemedi: ${esc(e.response || e.message)}</div>`));
    }
});

// =====================================================================================
// Yerel Mail uygulamasi icin JSON uclari (/mail/api/...). Kimlik: X-Api-Key basligi.
// =====================================================================================

const FOLDER_KEYS = ["inbox", "starred", "sent", "spam", "trash", "all"];
function apiErr(res, e, code) {
    const msg = e && (e.responseText || e.message) || "Hata";
    if (!cfg) return res.status(409).json({ error: "Sunucuda posta hesabı kurulu değil (web: /mail/setup)", needSetup: true });
    console.log("[posta api]", msg);
    res.status(code || 502).json({ error: msg });
}

function msgSummary(m, f) {
    const e = m.envelope || {};
    const from = (e.from && e.from[0]) || {};
    const to = (e.to && e.to[0]) || {};
    return {
        uid: m.uid,
        from: f === "sent" ? addrName(to) : addrName(from),
        fromAddr: f === "sent" ? (to.address || "") : (from.address || ""),
        subject: e.subject || "(konu yok)",
        snippet: m.snippet || "",
        date: shortDate(e.date),
        ts: e.date ? new Date(e.date).getTime() : 0,
        unread: !(m.flags && m.flags.has("\\Seen")),
        starred: !!(m.flags && m.flags.has("\\Flagged")),
        att: findParts(m.bodyStructure).att.length > 0
    };
}

router.get("/mail/api/list", async (req, res) => {
    if (!cfg) return apiErr(res);
    const f = FOLDER_KEYS.indexOf(req.query.f) >= 0 ? req.query.f : "inbox";
    const pg = Math.max(0, parseInt(req.query.p || "0", 10));
    const q = ("" + (req.query.q || "")).trim();
    try {
        await getWorker();
        const box = boxPath(f);
        const data = await withMailbox(box, async (c) => {
            const mb = c.mailbox;
            let uids = null;
            if (q) {
                const isGmail = /gmail/.test(cfg.host);
                uids = await c.search(isGmail ? { gmraw: q } : { or: [{ subject: q }, { from: q }, { body: q }] }, { uid: true });
                uids = (uids || []).sort((a, b) => b - a);
            }
            const items = [];
            let total, more;
            if (uids) {
                total = uids.length;
                const pageUids = uids.slice(pg * PAGE, pg * PAGE + PAGE);
                more = uids.length > (pg + 1) * PAGE;
                if (pageUids.length) for await (const m of c.fetch(pageUids.join(","), { uid: true, envelope: true, flags: true, bodyStructure: true }, { uid: true })) items.push(m);
            } else {
                total = mb.exists;
                const hi = total - pg * PAGE, lo = Math.max(1, hi - PAGE + 1);
                more = lo > 1;
                if (hi >= 1) for await (const m of c.fetch(`${lo}:${hi}`, { uid: true, envelope: true, flags: true, bodyStructure: true })) items.push(m);
            }
            items.sort((a, b) => b.uid - a.uid);
            for (const m of items) m.snippet = await snippetFor(c, box, mb.uidValidity, m);
            return { items, total, more };
        });
        let unseen = 0;
        try { unseen = (await worker.status("INBOX", { unseen: true })).unseen; } catch (e) { }
        res.json({ user: cfg.user, folder: f, total: data.total, more: data.more, unseen, items: data.items.map((m) => msgSummary(m, f)) });
    } catch (e) { apiErr(res, e); }
});

// ---- E-posta govdesini Qt'nin zengin metnine uygun sade, guvenli HTML'e cevirir ----
const RICH_TAGS = { a: 1, b: 1, strong: 1, i: 1, em: 1, u: 1, br: 1, p: 1, h1: 1, h2: 1, h3: 1, h4: 1, ul: 1, ol: 1, li: 1, blockquote: 1, pre: 1, hr: 1, img: 1, s: 1, small: 1, code: 1 };
function decodeEnt(s) {
    return s.replace(/&nbsp;/g, " ").replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
        .replace(/&#(\d+);/g, (m, n) => String.fromCharCode(+n)).replace(/&#x([0-9a-f]+);/gi, (m, n) => String.fromCharCode(parseInt(n, 16)))
        .replace(/&amp;/g, "&");
}
function attr(tag, name) {
    const m = new RegExp("\\s" + name + "\\s*=\\s*(\"([^\"]*)\"|'([^']*)'|([^\\s>]+))", "i").exec(tag);
    return m ? (m[2] !== undefined ? m[2] : m[3] !== undefined ? m[3] : m[4]) : "";
}
function htmlToRich(html, withImages) {
    let s = ("" + html)
        .replace(/<(script|style|head|title|noscript)[\s\S]*?<\/\1>/gi, "")
        .replace(/<!--[\s\S]*?-->/g, "")
        .replace(/<![^>]*>|<\?[^>]*>/g, "")
        .replace(/<\/?(table|tbody|thead|tfoot|center|font|span|section|article|header|footer|main|o:p)[^>]*>/gi, "")
        .replace(/<\/tr>/gi, "<br>").replace(/<tr[^>]*>/gi, "")
        .replace(/<\/td>|<\/th>/gi, " ").replace(/<t[dh][^>]*>/gi, "")
        .replace(/<div[^>]*>/gi, "").replace(/<\/div>/gi, "<br>");
    let imgs = 0;
    s = s.replace(/<\/?([a-zA-Z0-9:]+)([^>]*)>/g, (tag, name) => {
        const n = name.toLowerCase();
        if (!RICH_TAGS[n]) return "";
        const closing = tag[1] === "/";
        if (closing) return n === "br" || n === "img" || n === "hr" ? "" : `</${n}>`;
        if (n === "a") {
            const href = attr(tag, "href");
            return /^(https?:|mailto:)/i.test(href) ? `<a href="${esc(decodeEnt(href))}">` : "<a>";
        }
        if (n === "img") {
            const src = decodeEnt(attr(tag, "src"));
            const w = parseInt(attr(tag, "width") || "0", 10), h = parseInt(attr(tag, "height") || "0", 10);
            if ((w && w <= 3) || (h && h <= 3)) return "";                 // izleme pikselleri
            if (!withImages || !/^https?:/i.test(src) || imgs >= 25) return "";
            imgs++;
            return `<img src="/mail/api/img?w=330&u=${encodeURIComponent(src)}"><br>`;
        }
        if (n === "h1" || n === "h2") return `<h3>`;
        return `<${n}>`;
    }).replace(/<\/h[12]>/g, "</h3>");
    s = s.replace(/[ \t\r\n]+/g, " ").replace(/(<br>\s*){3,}/g, "<br><br>").replace(/^(\s|<br>)+/, "").trim();
    return { html: s.slice(0, 200000), images: imgs };
}
function countImages(html) { return (("" + html).match(/<img\s[^>]*src\s*=\s*["']?https?:/gi) || []).length; }

router.get("/mail/api/msg/:f/:uid", async (req, res) => {
    if (!cfg) return apiErr(res);
    const f = FOLDER_KEYS.indexOf(req.params.f) >= 0 ? req.params.f : "inbox";
    const uid = parseInt(req.params.uid, 10);
    const withImages = req.query.img === "1";
    try {
        await getWorker();
        const r = await withMailbox(boxPath(f), async (c) => {
            const m = await c.fetchOne(uid, { uid: true, envelope: true, flags: true, bodyStructure: true }, { uid: true });
            if (!m) return null;
            const p = findParts(m.bodyStructure);
            let html = "", text = "";
            if (p.html) { const dl = await c.download(uid, p.html, { uid: true, maxBytes: 600000 }); html = await streamToString(dl.content, 600000); }
            if (p.text && (!p.html || req.query.plain === "1")) { const dl = await c.download(uid, p.text, { uid: true, maxBytes: 300000 }); text = await streamToString(dl.content, 300000); }
            const wasUnread = !(m.flags && m.flags.has("\\Seen"));
            if (wasUnread) await c.messageFlagsAdd(uid, ["\\Seen"], { uid: true });
            return { m, html, text, att: p.att, wasUnread };
        });
        if (!r) return res.status(404).json({ error: "Posta bulunamadı" });
        const e = r.m.envelope;
        let body, images = 0, hasImages = false;
        if (r.html && req.query.plain !== "1") {
            const rich = htmlToRich(r.html, withImages);
            body = rich.html; images = rich.images; hasImages = countImages(r.html) > 0;
        } else {
            body = textToHtml(r.text || htmlToText(r.html));
        }
        res.json({
            uid, folder: f,
            subject: e.subject || "(konu yok)",
            from: addrName(e.from && e.from[0]), fromAddr: (e.from && e.from[0] && e.from[0].address) || "",
            to: addrList(e.to), cc: addrList(e.cc), date: longDate(e.date),
            starred: !!(r.m.flags && r.m.flags.has("\\Flagged")), wasUnread: r.wasUnread,
            att: r.att.map((a) => ({ part: a.part, name: a.name, size: a.size, sizeText: sizeText(a.size), type: a.type })),
            body: body || "<i>(metin yok)</i>", isHtml: !!r.html, hasImages, imagesShown: images
        });
    } catch (e) { apiErr(res, e); }
});

router.post("/mail/api/act/:f/:uid", express.json({ limit: "4kb" }), async (req, res) => {
    if (!cfg) return apiErr(res);
    const f = FOLDER_KEYS.indexOf(req.params.f) >= 0 ? req.params.f : "inbox";
    const uid = parseInt(req.params.uid, 10);
    const a = ("" + ((req.body && req.body.a) || req.query.a || ""));
    try {
        await getWorker();
        await withMailbox(boxPath(f), async (c) => {
            if (a === "archive") {
                if (/gmail/.test(cfg.host)) await c.messageDelete(uid, { uid: true });
                else if (folders.all) await c.messageMove(uid, folders.all, { uid: true });
            } else if (a === "trash") {
                if (f === "trash") await c.messageDelete(uid, { uid: true });
                else if (folders.trash) await c.messageMove(uid, folders.trash, { uid: true });
            } else if (a === "unread") await c.messageFlagsRemove(uid, ["\\Seen"], { uid: true });
            else if (a === "read") await c.messageFlagsAdd(uid, ["\\Seen"], { uid: true });
            else if (a === "star") await c.messageFlagsAdd(uid, ["\\Flagged"], { uid: true });
            else if (a === "unstar") await c.messageFlagsRemove(uid, ["\\Flagged"], { uid: true });
            else if (a === "notspam" && f === "spam") await c.messageMove(uid, "INBOX", { uid: true });
            else throw new Error("Geçersiz işlem");
        });
        res.json({ ok: true });
    } catch (e) { apiErr(res, e); }
});

// Yanit / iletme taslagi
router.get("/mail/api/compose", async (req, res) => {
    if (!cfg) return apiErr(res);
    let to = "", subject = "", body = "", ref = "";
    try {
        const src = req.query.re || req.query.fw;
        if (src) {
            const [f, u] = ("" + src).split(":");
            const uid = parseInt(u, 10);
            await getWorker();
            const r = await withMailbox(boxPath(f), async (c) => {
                const m = await c.fetchOne(uid, { uid: true, envelope: true, bodyStructure: true }, { uid: true });
                const p = findParts(m.bodyStructure);
                let text = "";
                const part = p.text || p.html;
                if (part) {
                    const dl = await c.download(uid, part, { uid: true, maxBytes: 60000 });
                    text = await streamToString(dl.content, 60000);
                    if (!p.text) text = htmlToText(text);
                }
                return { e: m.envelope, text };
            });
            const e = r.e, subj = e.subject || "";
            if (req.query.re) {
                const me = cfg.user.toLowerCase();
                const replyTo = (e.replyTo && e.replyTo.length ? e.replyTo : e.from) || [];
                let list = replyTo.map((a) => a.address);
                if (req.query.all === "1") list = list.concat((e.to || []).concat(e.cc || []).map((a) => a.address));
                to = Array.from(new Set(list.filter((x) => x && x.toLowerCase() !== me))).join(", ");
                subject = /^re:/i.test(subj) ? subj : "Re: " + subj;
                ref = e.messageId || "";
                const quoted = r.text.split("\n").slice(0, 40).map((l) => "> " + l).join("\n");
                body = `\n\n${longDate(e.date)} tarihinde ${addrName(e.from && e.from[0])} yazdı:\n${quoted}`;
            } else {
                subject = /^(fw|fwd|ilt):/i.test(subj) ? subj : "Fwd: " + subj;
                body = `\n\n---------- İletilen posta ----------\nKimden: ${addrList(e.from)}\nTarih: ${longDate(e.date)}\nKonu: ${subj}\n\n${r.text.slice(0, 20000)}`;
            }
        }
        res.json({ to, subject, body, ref, from: cfg.name ? `${cfg.name} <${cfg.user}>` : cfg.user });
    } catch (e) { apiErr(res, e); }
});

router.post("/mail/api/send", express.json({ limit: "512kb" }), async (req, res) => {
    if (!cfg) return apiErr(res);
    const b = req.body || {};
    const to = ("" + (b.to || "")).trim();
    if (!/@/.test(to)) return res.status(400).json({ error: "Alıcı adresi gerekli" });
    try {
        const tr = nodemailer.createTransport({ host: cfg.smtpHost, port: cfg.smtpPort, secure: cfg.smtpPort === 465, auth: { user: cfg.user, pass: cfg.pass } });
        const msg = {
            from: cfg.name ? { name: cfg.name, address: cfg.user } : cfg.user,
            to, subject: ("" + (b.subject || "")).trim() || "(konu yok)",
            text: ("" + (b.body || "")).replace(/\r\n/g, "\n")
        };
        if (b.ref) { msg.inReplyTo = b.ref; msg.references = b.ref; }
        await tr.sendMail(msg);
        res.json({ ok: true });
    } catch (e) { apiErr(res, e); }
});

// E-postadaki uzak resimler: telefona uygun genislige kucultulmus JPEG (yuvj420p), 1 gun onbellek
const MAIL_IMG_DIR = path.join(os.tmpdir(), "e6mail_img");
if (!fs.existsSync(MAIL_IMG_DIR)) fs.mkdirSync(MAIL_IMG_DIR, { recursive: true });
const mailImgJobs = {};
router.get("/mail/api/img", async (req, res) => {
    let u = "" + (req.query.u || "");
    // Qt 4'un QML'i adresteki %XX'leri bir kez daha kodluyor: coz
    for (let i = 0; i < 3 && /^https?%3A/i.test(u); i++) { try { u = decodeURIComponent(u); } catch (e) { break; } }
    if (!/^https?:\/\//i.test(u)) return res.status(400).end();
    const w = Math.min(600, Math.max(60, parseInt(req.query.w || "330", 10)));
    const name = require("crypto").createHash("sha1").update(u + "|" + w).digest("hex") + ".jpg";
    const file = path.join(MAIL_IMG_DIR, name);
    try {
        if (!fs.existsSync(file)) {
            if (!mailImgJobs[name]) {
                mailImgJobs[name] = (async () => {
                    const r = await fetch(u, { headers: { "User-Agent": "Mozilla/5.0" }, signal: AbortSignal.timeout(15000) });
                    if (!r.ok) throw new Error("resim yok");
                    const buf = Buffer.from(await r.arrayBuffer());
                    if (buf.length > 8 * 1024 * 1024) throw new Error("resim cok buyuk");
                    const tmp = path.join(MAIL_IMG_DIR, name + ".src");
                    fs.writeFileSync(tmp, buf);
                    await new Promise((ok, fail) => ffmpeg().input(tmp).outputOptions([`-vf scale='min(${w},iw)':-2`, "-pix_fmt yuvj420p", "-q:v 6", "-frames:v 1"])
                        .output(file).on("end", ok).on("error", fail).run());
                    fs.unlink(tmp, () => { });
                })().finally(() => { delete mailImgJobs[name]; });
            }
            await mailImgJobs[name];
        }
        res.set("Cache-Control", "private, max-age=86400");
        res.type("image/jpeg").sendFile(file);
    } catch (e) { res.status(404).end(); }
});
setInterval(() => {   // bir gunden eski resimler silinir
    try { for (const f of fs.readdirSync(MAIL_IMG_DIR)) { const p = path.join(MAIL_IMG_DIR, f); if (Date.now() - fs.statSync(p).mtimeMs > 86400000) fs.unlinkSync(p); } } catch (e) { }
}, 3600000);

// Telefon uygulamalari icin kucuk durum ucu (okunmamis sayisi)
router.get("/mail/status.json", async (req, res) => {
    if (!cfg) return res.json({ configured: false });
    try {
        await getWorker();
        const st = await worker.status("INBOX", { unseen: true, messages: true });
        res.json({ configured: true, user: cfg.user, unseen: st.unseen, messages: st.messages, watching: !!watcher });
    } catch (e) { res.status(502).json({ configured: true, error: e.message }); }
});

startWatcher();

module.exports = { router, setNotifyHook };
