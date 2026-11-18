// BelleTube - YouTube koprusu
//  - Arama / video bilgisi / ilgili videolar: YouTube InnerTube (anahtarsiz), sade JSON'a indirgenir
//  - Video: yt-dlp ile 360p (veya 480p) H.264 goruntu + AAC ses, yeniden kodlamadan birlestirilir (faststart MP4)
//  - Telefona dosya olarak verilir (Range destekli); telefon bir kez indirir, sarma telefonda yapilir

const express = require("express");
const fs = require("fs");
const path = require("path");
const os = require("os");
const { execFile } = require("child_process");
const ffmpeg = require("fluent-ffmpeg");

const router = new express.Router();

const YTDLP = process.env.YTDLP_PATH || path.join(os.homedir(), "bin", "yt-dlp");
const CACHE_DIR = path.join(__dirname, "media", "yt");
const THUMB_DIR = path.join(CACHE_DIR, "thumbs");
const CACHE_MAX_BYTES = parseInt(process.env.YT_CACHE_MAX_MB || "4000", 10) * 1024 * 1024;
const CACHE_MAX_AGE_MS = 12 * 60 * 60 * 1000;
const WEB_CLIENT = { clientName: "WEB", clientVersion: "2.20261003.00.00", hl: "tr", gl: "TR" };

for (const d of [CACHE_DIR, THUMB_DIR]) if (!fs.existsSync(d)) fs.mkdirSync(d, { recursive: true });

const ID_RE = /^[A-Za-z0-9_-]{11}$/;

// ---------- InnerTube yardimcilari ----------

async function innertube(endpoint, body) {
    const r = await fetch(`https://www.youtube.com/youtubei/v1/${endpoint}?prettyPrint=false`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "User-Agent": "Mozilla/5.0", "Accept-Language": "tr-TR,tr;q=0.9" },
        body: JSON.stringify(Object.assign({ context: { client: WEB_CLIENT } }, body))
    });
    if (!r.ok) throw new Error(`YouTube HTTP ${r.status}`);
    return r.json();
}

function txt(t) {
    if (!t) return "";
    if (typeof t === "string") return t;
    if (t.simpleText) return t.simpleText;
    if (t.runs) return t.runs.map((x) => x.text).join("");
    if (t.content) return t.content;
    return "";
}

// Hem eski (videoRenderer/compactVideoRenderer) hem yeni (lockupViewModel) yapilari tanir
function ownerId(v) {
    try {
        for (const t of [v.ownerText, v.shortBylineText, v.longBylineText])
            if (t && t.runs && t.runs[0].navigationEndpoint) return t.runs[0].navigationEndpoint.browseEndpoint.browseId || "";
    } catch (e) { }
    return "";
}

function imgPathOf(url, w) {
    if (!url) return "";
    if (url.indexOf("//") === 0) url = "https:" + url;
    return "/yt/img?w=" + (w || 48) + "&u=" + encodeURIComponent(url);
}

function collectVideos(root, limit) {
    const out = [];
    const channels = [];
    const seen = {};
    let continuation = null;
    (function walk(o) {
        if (!o || typeof o !== "object" || out.length >= limit) return;
        if (o.continuationCommand && o.continuationCommand.token && !continuation) continuation = o.continuationCommand.token;
        const ch = o.channelRenderer;
        if (ch && ch.channelId && !seen[ch.channelId]) {
            seen[ch.channelId] = true;
            const th = ch.thumbnail && ch.thumbnail.thumbnails ? ch.thumbnail.thumbnails[0].url : "";
            const counts = [txt(ch.subscriberCountText), txt(ch.videoCountText)].filter((x) => x && x.indexOf("@") !== 0);
            channels.push({ id: ch.channelId, title: txt(ch.title), thumb: imgPathOf(th, 64), subscribers: counts[0] || "" });
            return;
        }
        const v = o.videoRenderer || o.compactVideoRenderer || o.gridVideoRenderer;
        if (v && v.videoId && !seen[v.videoId]) {
            seen[v.videoId] = true;
            out.push({
                id: v.videoId,
                title: txt(v.title),
                channelId: ownerId(v),
                channel: txt(v.ownerText || v.shortBylineText || v.longBylineText),
                length: txt(v.lengthText),
                views: txt(v.shortViewCountText || v.viewCountText),
                published: txt(v.publishedTimeText),
                live: !v.lengthText
            });
            return;
        }
        const lv = o.lockupViewModel;
        if (lv && lv.contentId && lv.contentType === "LOCKUP_CONTENT_TYPE_VIDEO" && !seen[lv.contentId]) {
            seen[lv.contentId] = true;
            const meta = lv.metadata && lv.metadata.lockupMetadataViewModel;
            const rows = [];
            try {
                for (const row of meta.metadata.contentMetadataViewModel.metadataRows)
                    for (const p of row.metadataParts || []) if (p.text && p.text.content) rows.push(p.text.content);
            } catch (e) { }
            let length = "";
            try {
                const b = JSON.stringify(lv.contentImage).match(/"text":"(\d+:\d{2}(?::\d{2})?)"/);
                if (b) length = b[1];
            } catch (e) { }
            out.push({
                id: lv.contentId,
                title: meta ? txt(meta.title) : "",
                channel: rows[0] || "",
                length: length,
                views: rows[1] || "",
                published: rows[2] || "",
                live: !length
            });
            return;
        }
        for (const k in o) walk(o[k]);
    })(root);
    return { items: out, channels, continuation };
}

// ---------- Uc noktalar ----------

router.get("/yt/search", async (req, res) => {
    try {
        const q = ("" + (req.query.q || "")).trim();
        const cont = req.query.cont ? "" + req.query.cont : "";
        if (!q && !cont) return res.status(400).json({ error: "Arama metni boş" });
        const data = await innertube("search", cont ? { continuation: cont } : { query: q });
        const r = collectVideos(data, 20);
        res.json({ items: r.items.filter((v) => !v.live), channels: cont ? [] : r.channels.slice(0, 3), continuation: r.continuation });
    } catch (e) {
        console.log("yt arama hatasi:", e.message);
        res.status(502).json({ error: "Arama yapılamadı: " + e.message });
    }
});

router.get("/yt/video/:id", async (req, res) => {
    const id = req.params.id;
    if (!ID_RE.test(id)) return res.status(400).json({ error: "Geçersiz video" });
    try {
        const [player, next] = await Promise.all([
            innertube("player", { videoId: id }).catch(() => null),
            innertube("next", { videoId: id }).catch(() => null)
        ]);
        const d = (player && player.videoDetails) || {};
        let published = "";
        try { published = player.microformat.playerMicroformatRenderer.publishDate || ""; } catch (e) { }
        const related = next ? collectVideos(next, 15).items.filter((v) => v.id !== id && !v.live) : [];
        res.json({
            id: id,
            title: d.title || "",
            channel: d.author || "",
            channelId: d.channelId || "",
            seconds: parseInt(d.lengthSeconds || "0", 10),
            views: d.viewCount || "",
            published: published,
            description: (d.shortDescription || "").slice(0, 1500),
            related: related
        });
    } catch (e) {
        console.log("yt video bilgisi hatasi:", e.message);
        res.status(502).json({ error: "Video bilgisi alınamadı: " + e.message });
    }
});

// Kucuk resim: 160x90 JPEG (telefon icin hafif), 7 gun onbellek
const thumbJobs = {};
router.get("/yt/thumb/:id.jpg", async (req, res) => {
    const id = req.params.id;
    if (!ID_RE.test(id)) return res.status(404).end();
    const file = path.join(THUMB_DIR, id + ".jpg");
    try {
        if (!fs.existsSync(file)) {
            if (!thumbJobs[id]) {
                thumbJobs[id] = (async () => {
                    const r = await fetch(`https://i.ytimg.com/vi/${id}/mqdefault.jpg`);
                    if (!r.ok) throw new Error("resim yok");
                    const tmp = path.join(os.tmpdir(), `th_${id}_${Date.now()}.jpg`);
                    fs.writeFileSync(tmp, Buffer.from(await r.arrayBuffer()));
                    await new Promise((ok, fail) => ffmpeg().input(tmp).outputOptions(["-vf scale=160:90", "-q:v 6", "-frames:v 1"])
                        .output(file).on("end", ok).on("error", fail).run());
                    fs.unlink(tmp, () => { });
                })().finally(() => { delete thumbJobs[id]; });
            }
            await thumbJobs[id];
        }
        res.set("Cache-Control", "private, max-age=604800");
        res.sendFile(file);
    } catch (e) {
        res.status(404).end();
    }
});

// ---------- Video / ses hazirlama (yt-dlp) ----------

const jobs = {};

function runYtdlp(args) {
    return new Promise((resolve, reject) => {
        execFile(YTDLP, ["--js-runtimes", "node", "--no-warnings", "--no-progress", "-q", "--no-playlist"].concat(args),
            { timeout: 10 * 60 * 1000, maxBuffer: 4 * 1024 * 1024 }, (err, stdout, stderr) => {
                if (err) return reject(new Error((stderr || err.message).split("\n").filter(Boolean).pop() || "yt-dlp hatasi"));
                resolve(stdout);
            });
    });
}

// Yalnizca ses: telefon oynaticilari (ve harici oynaticilar) YouTube'un m4a/AAC dosyasini
// "bozuk" diye reddedebildigi icin AAC dosyasi MP3'e (128 kbps, 44.1 kHz) cevrilir.
function prepareMp3(id) {
    const file = path.join(CACHE_DIR, `${id}_audio.mp3`);
    if (fs.existsSync(file)) {
        const now = new Date();
        fs.utimes(file, now, now, () => { });
        return Promise.resolve(file);
    }
    const key = id + "_mp3";
    if (jobs[key]) return jobs[key];
    const tmp = path.join(CACHE_DIR, `${id}_audio.tmp.mp3`);
    const started = Date.now();
    jobs[key] = prepare(id, "aac").then((aac) => new Promise((ok, fail) => {
        execFile("ffmpeg", ["-y", "-loglevel", "error", "-i", aac, "-vn", "-map_metadata", "-1", "-c:a", "libmp3lame",
            "-b:a", "128k", "-ar", "44100", "-ac", "2", "-id3v2_version", "3", "-write_xing", "1", "-f", "mp3", tmp],
            { timeout: 10 * 60 * 1000 }, (err, so, se) => (err ? fail(new Error("mp3: " + (se || err.message).trim().split("\n").pop())) : ok()));
    })).then(() => {
        fs.renameSync(tmp, file);
        console.log(`[yt] ${id} mp3 hazir (${Math.round((Date.now() - started) / 100) / 10} sn, ${Math.round(fs.statSync(file).size / 1024 / 1024 * 10) / 10} MB)`);
        return file;
    }).finally(() => { delete jobs[key]; fs.unlink(tmp, () => { }); });
    return jobs[key];
}

function prepare(id, kind) {
    // kind: "360" | "480" | "audio" (MP3) | "aac" (ic kullanim: video birlestirme ve MP3 kaynagi)
    if (kind === "audio") return prepareMp3(id);
    const file = path.join(CACHE_DIR, kind === "aac" ? `${id}_audio.m4a` : `${id}_${kind}.mp4`);
    if (fs.existsSync(file)) {
        const now = new Date();
        fs.utimes(file, now, now, () => { });   // son kullanim
        return Promise.resolve(file);
    }
    const key = id + "_" + kind;
    if (jobs[key]) return jobs[key];

    const url = `https://www.youtube.com/watch?v=${id}`;
    const fast = ["-N", "6", "--http-chunk-size", "2M"];   // parcali paralel indirme (YouTube hiz sinirini asar)
    const started = Date.now();
    const done = (f) => {
        fs.renameSync(f, file);
        console.log(`[yt] ${id} ${kind} hazir (${Math.round((Date.now() - started) / 100) / 10} sn, ${Math.round(fs.statSync(file).size / 1024 / 1024 * 10) / 10} MB)`);
        cleanCache();
        return file;
    };
    if (kind === "aac") {
        const out = path.join(CACHE_DIR, `${id}_audio.tmp.m4a`);
        jobs[key] = runYtdlp(fast.concat(["-f", "140/139/bestaudio[ext=m4a]", "-o", out, url]))
            .then(() => done(out)).finally(() => { delete jobs[key]; });
        return jobs[key];
    }
    // Goruntu ve ses ayni anda iner, sonra yeniden kodlamadan birlestirilir (moov basta: inerken oynatilabilir)
    const h = kind === "480" ? 480 : 360;
    const vOut = path.join(CACHE_DIR, `${id}_${kind}.tmp.v.mp4`);
    const aOut = path.join(CACHE_DIR, `${id}_${kind}.tmp.a.m4a`);
    const mOut = path.join(CACHE_DIR, `${id}_${kind}.tmp.mp4`);
    const audioJob = prepare(id, "aac").catch(() => runYtdlp(["-f", "140/139/bestaudio[ext=m4a]", "-o", aOut, url]).then(() => aOut));
    jobs[key] = Promise.all([
        runYtdlp(fast.concat(["-f", `bestvideo[vcodec^=avc1][height<=${h}][ext=mp4]/bestvideo[vcodec^=avc1][height<=${h}]`, "-o", vOut, url])),
        audioJob
    ]).then(([, aFile]) => new Promise((ok, fail) => {
        execFile("ffmpeg", ["-y", "-loglevel", "error", "-i", vOut, "-i", aFile, "-map", "0:v:0", "-map", "1:a:0", "-c", "copy", "-movflags", "+faststart", mOut],
            { timeout: 5 * 60 * 1000 }, (err, so, se) => (err ? fail(new Error("birlestirme: " + (se || err.message).trim().split("\n").pop())) : ok()));
    })).then(() => done(mOut)).catch((e) => {
        // Yedek yol: yt-dlp kendi birlestirsin (ornegin ayri avc1 goruntu bulunamazsa)
        console.log(`[yt] ${id} ${kind} hizli yol olmadi (${e.message}), yedek yol`);
        const tmpl = path.join(CACHE_DIR, `${id}_${kind}.tmp2.%(ext)s`);
        return runYtdlp(["-f", `bestvideo[vcodec^=avc1][height<=${h}]+bestaudio[ext=m4a]/18/best[ext=mp4][height<=${h}]`,
            "--merge-output-format", "mp4", "--postprocessor-args", "Merger+ffmpeg_o1:-movflags +faststart", "-o", tmpl, url]).then(() => {
            const produced = fs.readdirSync(CACHE_DIR).find((f) => f.indexOf(`${id}_${kind}.tmp2.`) === 0 && !f.endsWith(".part") && !/\.f\d+\./.test(f));
            if (!produced) throw new Error("Dosya oluşmadı");
            return done(path.join(CACHE_DIR, produced));
        });
    }).finally(() => {
        delete jobs[key];
        for (const f of [vOut, aOut]) fs.unlink(f, () => { });
    });
    return jobs[key];
}

function serveMedia(kind) {
    return async (req, res) => {
        const id = req.params.id;
        if (!ID_RE.test(id)) return res.status(400).json({ error: "Geçersiz video" });
        try {
            const file = await prepare(id, kind);
            res.set("Cache-Control", "private, max-age=3600");
            res.type(kind === "audio" ? "audio/mpeg" : "video/mp4");
            res.sendFile(file);   // Range (206) destegi Express'te hazir
        } catch (e) {
            console.log(`[yt] ${id} ${kind} hazirlanamadi: ${e.message}`);
            res.status(502).json({ error: "Video hazırlanamadı: " + e.message });
        }
    };
}

// Oynaticidan once cagrilir: dosya sunucuda hazir olunca yanit doner (oynatici bekleyip zaman asimina dusmesin)
router.get("/yt/prepare/:id", async (req, res) => {
    const id = req.params.id;
    if (!ID_RE.test(id)) return res.status(400).json({ error: "Geçersiz video" });
    const kind = req.query.k === "audio" ? "audio" : (req.query.k === "480" ? "480" : "360");
    try {
        const file = await prepare(id, kind);
        res.json({ ok: true, kind, size: fs.statSync(file).size });
    } catch (e) {
        console.log(`[yt] ${id} ${kind} hazirlanamadi: ${e.message}`);
        res.status(502).json({ error: "Video hazırlanamadı: " + e.message });
    }
});

// ---------- Yorumlar (InnerTube) ----------
function commentToken(next) {
    let tok = "";
    (function walk(o) {
        if (tok || !o || typeof o !== "object") return;
        if (o.itemSectionRenderer && o.itemSectionRenderer.sectionIdentifier === "comment-item-section") {
            const m = JSON.stringify(o.itemSectionRenderer).match(/"token":"([^"]+)"/);
            if (m) tok = m[1];
            return;
        }
        for (const k in o) walk(o[k]);
    })(next);
    return tok;
}
const commentCache = {};   // id -> { t, token }
router.get("/yt/comments/:id", async (req, res) => {
    const id = req.params.id;
    if (!ID_RE.test(id)) return res.status(400).json({ error: "Geçersiz video" });
    try {
        let token = req.query.cont ? "" + req.query.cont : "";
        if (!token) {
            const c = commentCache[id];
            if (c && Date.now() - c.t < 30 * 60 * 1000) token = c.token;
            else {
                token = commentToken(await innertube("next", { videoId: id }));
                if (token) commentCache[id] = { t: Date.now(), token };
            }
        }
        if (!token) return res.json({ items: [], next: "", disabled: true });
        const d = await innertube("next", { continuation: token });
        const muts = (((d.frameworkUpdates || {}).entityBatchUpdate || {}).mutations || []);
        const items = muts.map((m) => m.payload && m.payload.commentEntityPayload).filter(Boolean).map((p) => ({
            author: ((p.author && p.author.displayName) || "").replace(/^@/, ""),
            text: ((p.properties && p.properties.content && p.properties.content.content) || "").slice(0, 2000),
            published: (p.properties && p.properties.publishedTime) || "",
            likes: (p.toolbar && p.toolbar.likeCountNotliked) || "",
            replies: (p.toolbar && p.toolbar.replyCount) || ""
        }));
        // Sonraki sayfa: son endpoint'in son ogesindeki devam belirteci
        let next = "";
        try {
            const eps = d.onResponseReceivedEndpoints || [];
            const last = eps[eps.length - 1];
            const act = last.appendContinuationItemsAction || last.reloadContinuationItemsCommand;
            const ci = act.continuationItems[act.continuationItems.length - 1];
            if (ci.continuationItemRenderer) {
                const m = JSON.stringify(ci.continuationItemRenderer).match(/"token":"([^"]+)"/);
                if (m) next = m[1];
            }
        } catch (e) { }
        res.json({ items, next });
    } catch (e) {
        console.log("yt yorum hatasi:", e.message);
        res.status(502).json({ error: "Yorumlar alınamadı: " + e.message });
    }
});

router.get("/yt/stream/:id.mp4", (req, res, next) => {
    const q = req.query.q === "480" ? "480" : "360";
    return serveMedia(q)(req, res, next);
});
router.get("/yt/audio/:id.mp3", serveMedia("audio"));
router.get("/yt/audio/:id.m4a", serveMedia("audio"));   // eski surumler: artik MP3 verilir

// Onbellek temizligi: 12 saatten eski veya toplam 4 GB'i asan dosyalar (en eskiden baslayarak)
function cleanCache() {
    try {
        const files = fs.readdirSync(CACHE_DIR)
            .filter((f) => /\.(mp4|m4a|mp3)$/.test(f) && f.indexOf(".tmp.") < 0)
            .map((f) => { const p = path.join(CACHE_DIR, f); const st = fs.statSync(p); return { p, size: st.size, t: st.mtimeMs }; })
            .sort((a, b) => a.t - b.t);
        let total = files.reduce((s, f) => s + f.size, 0);
        const now = Date.now();
        for (const f of files) {
            if (now - f.t > CACHE_MAX_AGE_MS || total > CACHE_MAX_BYTES) {
                fs.unlinkSync(f.p);
                total -= f.size;
            }
        }
        // yarim kalmis gecici dosyalar
        for (const f of fs.readdirSync(CACHE_DIR)) {
            if (f.indexOf(".tmp.") >= 0) {
                const p = path.join(CACHE_DIR, f);
                if (now - fs.statSync(p).mtimeMs > 60 * 60 * 1000) fs.unlinkSync(p);
            }
        }
    } catch (e) {
        console.log("yt onbellek temizligi hatasi:", e.message);
    }
}
setInterval(cleanCache, 30 * 60 * 1000);

// =====================================================================================
// BelleMusic: s60tube muzik servisiyle ayni bicimde ({Items:[...]}) YouTube muzik uclari.
//   Sarki: {Name, Url, Singer, Duration, Image}  (Url: /yt/audio/<id>.mp3, uygulama sunucu adresi + parolayi ekler)
//   Liste: {ListKey, Name, Singer, Image}         (ListKey: yt:<playlistId>)
// =====================================================================================
const SRC_VIDEO = "EgIQAQ%3D%3D", SRC_PLAYLIST = "EgIQAw%3D%3D";

function saniye(s) {
    const p = ("" + (s || "")).split(":").map((x) => parseInt(x, 10) || 0);
    return p.reduce((a, b) => a * 60 + b, 0);
}
function sanatci(s) { return ("" + (s || "")).replace(/\s+-\s+Topic$/i, "").trim(); }
function sarki(id, ad, kanal, sure) {
    return { Name: ad || "", Url: `/yt/audio/${id}.mp3`, Singer: sanatci(kanal), Duration: sure || 0, Image: `https://i.ytimg.com/vi/${id}/mqdefault.jpg` };
}

function listeleriTopla(root, limit) {
    const out = [], seen = {};
    (function walk(o) {
        if (!o || typeof o !== "object" || out.length >= limit) return;
        const pr = o.playlistRenderer;
        if (pr && pr.playlistId && !seen[pr.playlistId]) {
            seen[pr.playlistId] = true;
            const th = (pr.thumbnails && pr.thumbnails[0] && pr.thumbnails[0].thumbnails) || [];
            out.push({ ListKey: "yt:" + pr.playlistId, Name: txt(pr.title), Singer: sanatci(txt(pr.shortBylineText || pr.longBylineText)), Image: th.length ? th[th.length - 1].url : "" });
            return;
        }
        const lv = o.lockupViewModel;
        if (lv && lv.contentId && lv.contentType === "LOCKUP_CONTENT_TYPE_PLAYLIST" && !seen[lv.contentId]) {
            seen[lv.contentId] = true;
            const meta = lv.metadata && lv.metadata.lockupMetadataViewModel;
            let kanal = "", resim = "";
            try { kanal = meta.metadata.contentMetadataViewModel.metadataRows[0].metadataParts[0].text.content; } catch (e) { }
            try { const m = JSON.stringify(lv.contentImage).match(/"url":"(https:[^"]+)"/); if (m) resim = m[1]; } catch (e) { }
            out.push({ ListKey: "yt:" + lv.contentId, Name: meta ? txt(meta.title) : "", Singer: sanatci(kanal), Image: resim });
            return;
        }
        for (const k in o) walk(o[k]);
    })(root);
    return out;
}

function listeSarkilari(root, limit) {
    const out = [], seen = {};
    (function walk(o) {
        if (!o || typeof o !== "object" || out.length >= limit) return;
        const v = o.playlistVideoRenderer || o.playlistPanelVideoRenderer;
        if (v && v.videoId && !seen[v.videoId]) {
            seen[v.videoId] = true;
            if (v.isPlayable === false) return;
            out.push(sarki(v.videoId, txt(v.title), txt(v.shortBylineText || v.longBylineText), parseInt(v.lengthSeconds || "0", 10) || saniye(txt(v.lengthText))));
            return;
        }
        for (const k in o) walk(o[k]);
    })(root);
    if (out.length) return out;
    // yeni liste sayfasi yapisi (lockupViewModel): arama ayristiricisi tanir
    return collectVideos(root, limit).items.filter((v) => !v.live).map((v) => sarki(v.id, v.title, v.channel, saniye(v.length)));
}

async function listeAra(q, limit) {
    return listeleriTopla(await innertube("search", { query: q, params: SRC_PLAYLIST }), limit || 20);
}

function muzikHata(res, e, ne) {
    console.log(`[muzik] ${ne}: ${e.message}`);
    res.status(502).json({ error: ne + ": " + e.message, Items: [] });
}

router.get("/muzik/tracks/search", async (req, res) => {
    const q = ("" + (req.query.q || "")).trim();
    if (!q) return res.json({ Items: [] });
    try {
        const r = collectVideos(await innertube("search", { query: q, params: SRC_VIDEO }), 30);
        res.json({ Items: r.items.filter((v) => !v.live).map((v) => sarki(v.id, v.title, v.channel, saniye(v.length))) });
    } catch (e) { muzikHata(res, e, "Şarkı aranamadı"); }
});

router.get("/muzik/search", async (req, res) => {
    const q = ("" + (req.query.q || "")).trim();
    if (!q) return res.json({ Items: [] });
    try { res.json({ Items: await listeAra(req.query.type === "album" ? q + " album" : q, 20) }); }
    catch (e) { muzikHata(res, e, "Liste aranamadı"); }
});

// YouTube Music albumu (MPREb_...) -> albumun oynatma listesi (OLAK5uy_...)
const albumOnbellek = {};
async function albumListesi(browseId) {
    if (albumOnbellek[browseId]) return albumOnbellek[browseId];
    const r = await fetch("https://music.youtube.com/youtubei/v1/browse?prettyPrint=false", {
        method: "POST",
        headers: { "Content-Type": "application/json", "User-Agent": "Mozilla/5.0", "Origin": "https://music.youtube.com", "Referer": "https://music.youtube.com/" },
        body: JSON.stringify({ context: { client: { clientName: "WEB_REMIX", clientVersion: "1.20261001.01.00", hl: "tr", gl: "TR" } }, browseId })
    });
    if (!r.ok) throw new Error(`YouTube Music HTTP ${r.status}`);
    const m = JSON.stringify(await r.json()).match(/OLAK5uy_[A-Za-z0-9_-]+/);
    if (!m) throw new Error("albüm listesi bulunamadı");
    albumOnbellek[browseId] = m[0];
    return m[0];
}

router.get("/muzik/tracks", async (req, res) => {
    // Kabul edilen bicimler: yt:<id>, ytmusic:playlist:[VL]<id> (s60tube/eski kayitlar), ytmusic:album:MPREb_...
    const anahtar = "" + (req.query.listkey || "");
    const m = /^(?:yt|ytmusic:playlist):(?:VL)?([A-Za-z0-9_-]{10,})$/.exec(anahtar);
    const a = /^(?:yt|ytmusic):album:(MPREb_[A-Za-z0-9_-]+)$/.exec(anahtar);
    if (!m && !a) return res.status(400).json({ error: "Geçersiz liste", Items: [] });
    try {
        const id = m ? m[1] : await albumListesi(a[1]);
        // RD (karisik) listeleri sayfa olarak acilmaz: "next" ile ilk sarkidan okunur
        const veri = id.indexOf("RD") === 0 ? await innertube("next", { playlistId: id }) : await innertube("browse", { browseId: "VL" + id });
        res.json({ Items: listeSarkilari(veri, 100) });
    } catch (e) { muzikHata(res, e, "Liste açılamadı"); }
});

// Kesfet: hazir aramalarla populer / yeni listeler (12 saat onbellek)
const kesfetOnbellek = {};
router.get("/muzik/playlist", async (req, res) => {
    const yeni = req.query.type === "new";
    const sayfa = Math.max(1, parseInt(req.query.page || "1", 10));
    const yil = new Date().getFullYear();
    const sorgular = yeni ? [`yeni çıkan şarkılar ${yil}`, `new music ${yil}`, `yeni türkçe pop ${yil}`]
                          : [`türkçe pop hit ${yil}`, `top 50 türkiye`, `en çok dinlenen şarkılar`];
    const q = sorgular[(sayfa - 1) % sorgular.length];
    if (sayfa > sorgular.length) return res.json({ Items: [] });
    try {
        const k = q;
        if (!kesfetOnbellek[k] || Date.now() - kesfetOnbellek[k].t > 12 * 3600 * 1000) kesfetOnbellek[k] = { t: Date.now(), items: await listeAra(q, 20) };
        res.json({ Items: kesfetOnbellek[k].items });
    } catch (e) { muzikHata(res, e, "Listeler alınamadı"); }
});

module.exports = router;
