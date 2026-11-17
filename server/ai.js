// ApiLauncher / ApiLauncher - yapay zeka aktarma ucu (telefon dogrudan HTTPS kuramazsa "sunucu uzerinden" modu)
//
// Anahtarlar bu modda telefondan bir kez gonderilir ve sunucuda data/ai_keys.json'da saklanir;
// sonraki isteklerde telefon anahtar gondermez. Desteklenen saglayicilar:
//   openai  -> https://api.openai.com/v1/chat/completions   (+ /v1/images/generations)
//   claude  -> https://api.anthropic.com/v1/messages
//   gemini  -> https://generativelanguage.googleapis.com/v1beta/models/<model>:generateContent
//   grok    -> https://api.x.ai/v1/chat/completions         (+ /v1/images/generations)
// Mesajda img (JPEG base64) varsa resimli gonderilir. /ai/draw resim olusturur (GPT, Gemini, Grok).

const express = require("express");
const fs = require("fs");
const path = require("path");

const router = new express.Router();
const KEYS_FILE = path.join(__dirname, "data", "ai_keys.json");
const ANTHROPIC_VERSION = "2026-10-21";
// Claude'un guvenlik reddinde ayni istegi uygun modelde yeniden calistiran sunucu tarafi yedek
const FALLBACK_MODELS = ["claude-fable-5-1", "claude-opus-5-5", "claude-opus-5", "claude-sonnet-5-5"];
const PROVIDERS = ["openai", "claude", "gemini", "grok"];
const IMG_DEFAULTS = { openai: "gpt-image-1", gemini: "gemini-2.5-flash-image", grok: "grok-2-image" };
const SORU = "Bu resimde ne var?";

function readKeys() { try { return JSON.parse(fs.readFileSync(KEYS_FILE, "utf8")); } catch (e) { return {}; } }

async function readJson(r) { try { return await r.json(); } catch (e) { return {}; } }
function errMsg(j, status) {
    if (j && j.error) return typeof j.error === "string" ? j.error : (j.error.message || JSON.stringify(j.error));
    return "HTTP " + status;
}
function adi(p) { return { openai: "GPT", claude: "Claude", gemini: "Gemini", grok: "Grok" }[p] || p; }
function anahtarYok(p) {
    return new Error("Sunucuda " + adi(p) + " anahtarı yok. Ayarlar > Bağlantı > 'Anahtarları sunucuya kaydet'e basın.");
}

async function postJson(url, headers, body) {
    const r = await fetch(url, { method: "POST", headers: Object.assign({ "Content-Type": "application/json" }, headers), body: JSON.stringify(body) });
    const j = await readJson(r);
    if (!r.ok) throw new Error(errMsg(j, r.status));
    return j;
}

// OpenAI ve Grok ayni bicim
function openaiMessages(system, messages) {
    const msgs = [];
    if (system) msgs.push({ role: "system", content: system });
    for (const m of messages) {
        if (m.img && m.role === "user") {
            msgs.push({ role: "user", content: [
                { type: "text", text: m.text || SORU },
                { type: "image_url", image_url: { url: "data:image/jpeg;base64," + m.img } }
            ] });
        } else msgs.push({ role: m.role, content: m.text || "" });
    }
    return msgs;
}

// messages: [{ role: "user"|"assistant", text, img? }]
async function chat(provider, key, model, system, messages) {
    if (!key) throw anahtarYok(provider);
    if (provider === "openai" || provider === "grok") {
        const url = provider === "openai" ? "https://api.openai.com/v1/chat/completions" : "https://api.x.ai/v1/chat/completions";
        const j = await postJson(url, { Authorization: "Bearer " + key }, { model, messages: openaiMessages(system, messages) });
        const c = j.choices && j.choices[0];
        return { text: (c && c.message && c.message.content) || "", model: j.model || model, stop: c && c.finish_reason };
    }
    if (provider === "claude") {
        const cm = messages.map((m) => (m.img && m.role === "user")
            ? { role: "user", content: [
                { type: "image", source: { type: "base64", media_type: "image/jpeg", data: m.img } },
                { type: "text", text: m.text || SORU }] }
            : { role: m.role, content: m.text || "" });
        const body = { model, max_tokens: 16000, messages: cm };
        if (system) body.system = system;
        const headers = { "x-api-key": key, "anthropic-version": ANTHROPIC_VERSION };
        if (FALLBACK_MODELS.indexOf(model) >= 0) { body.fallbacks = "default"; headers["anthropic-beta"] = "server-side-fallback-2026-07-01"; }
        const j = await postJson("https://api.anthropic.com/v1/messages", headers, body);
        if (j.stop_reason === "refusal") {
            const d = j.stop_details || {};
            return { text: "", refusal: d.explanation || "Claude bu isteği yanıtlamadı" + (d.category ? " (" + d.category + ")" : ""), model: j.model || model };
        }
        const text = (j.content || []).filter((b) => b.type === "text").map((b) => b.text).join("");
        return { text, model: j.model || model, stop: j.stop_reason };
    }
    if (provider === "gemini") {
        const contents = messages.map((m) => {
            const parts = [];
            if (m.img && m.role === "user") parts.push({ inline_data: { mime_type: "image/jpeg", data: m.img } });
            parts.push({ text: m.text || (m.img ? SORU : "") });
            return { role: m.role === "assistant" ? "model" : "user", parts };
        });
        const body = { contents };
        if (system) body.systemInstruction = { parts: [{ text: system }] };
        const j = await postJson("https://generativelanguage.googleapis.com/v1beta/models/" + encodeURIComponent(model) + ":generateContent",
            { "x-goog-api-key": key }, body);
        const c = j.candidates && j.candidates[0];
        const text = c && c.content && c.content.parts ? c.content.parts.map((p) => p.text || "").join("") : "";
        if (!text && j.promptFeedback && j.promptFeedback.blockReason) return { text: "", refusal: "Gemini yanıtlamadı (" + j.promptFeedback.blockReason + ")", model };
        return { text, model: j.modelVersion || model, stop: c && c.finishReason };
    }
    throw new Error("Bilinmeyen sağlayıcı");
}

// Resim olusturma -> { b64, ext, text, model }
async function draw(provider, key, model, prompt) {
    if (!key) throw anahtarYok(provider);
    model = model || IMG_DEFAULTS[provider];
    if (provider === "openai" || provider === "grok") {
        const body = { model, prompt, n: 1 };
        if (provider === "openai") body.size = "1024x1024"; else body.response_format = "b64_json";
        const j = await postJson(provider === "openai" ? "https://api.openai.com/v1/images/generations" : "https://api.x.ai/v1/images/generations",
            { Authorization: "Bearer " + key }, body);
        const d = j.data && j.data[0];
        if (d && d.b64_json) return { b64: d.b64_json, ext: provider === "openai" ? "png" : "jpg", text: d.revised_prompt || "", model };
        if (d && d.url) {   // yalnizca baglanti dondu: sunucu indirip base64 yapar
            const r = await fetch(d.url);
            if (!r.ok) throw new Error("Resim indirilemedi (" + r.status + ")");
            const buf = Buffer.from(await r.arrayBuffer());
            return { b64: buf.toString("base64"), ext: /png/.test(r.headers.get("content-type") || "") ? "png" : "jpg", text: d.revised_prompt || "", model };
        }
        throw new Error("Resim gelmedi");
    }
    if (provider === "gemini") {
        const j = await postJson("https://generativelanguage.googleapis.com/v1beta/models/" + encodeURIComponent(model) + ":generateContent",
            { "x-goog-api-key": key },
            { contents: [{ role: "user", parts: [{ text: prompt }] }], generationConfig: { responseModalities: ["TEXT", "IMAGE"] } });
        const c = j.candidates && j.candidates[0];
        let b64 = "", mime = "image/png", t = "";
        for (const pt of (c && c.content && c.content.parts) || []) {
            const inl = pt.inlineData || pt.inline_data;
            if (inl && inl.data) { b64 = inl.data; mime = inl.mimeType || inl.mime_type || mime; } else if (pt.text) t += pt.text;
        }
        if (!b64) throw new Error(t ? "Resim yerine metin döndü: " + t.substring(0, 120) : "Resim gelmedi");
        return { b64, ext: mime.indexOf("jpeg") >= 0 ? "jpg" : "png", text: t, model };
    }
    throw new Error(adi(provider) + " resim çizmiyor");
}

function resimModeliMi(provider, id) {
    if (provider === "openai") return /^(gpt-image|dall-e|chatgpt-image)/.test(id);
    if (provider === "gemini") return /image|imagen/.test(id);
    if (provider === "grok") return /image|imagine/.test(id);
    return false;
}

async function listModels(provider, key, img) {
    if (!key) throw anahtarYok(provider);
    let out = [];
    if (provider === "openai" || provider === "grok") {
        const r = await fetch(provider === "openai" ? "https://api.openai.com/v1/models" : "https://api.x.ai/v1/models", { headers: { Authorization: "Bearer " + key } });
        const j = await readJson(r);
        if (!r.ok) throw new Error(errMsg(j, r.status));
        out = (j.data || []).map((m) => m.id);
        if (!img && provider === "openai") out = out.filter((id) => /^(gpt|o\d|chatgpt)/.test(id) && !resimModeliMi(provider, id));
        out.sort().reverse();
    } else if (provider === "claude") {
        const r = await fetch("https://api.anthropic.com/v1/models?limit=100", { headers: { "x-api-key": key, "anthropic-version": ANTHROPIC_VERSION } });
        const j = await readJson(r);
        if (!r.ok) throw new Error(errMsg(j, r.status));
        out = (j.data || []).map((m) => m.id);
    } else if (provider === "gemini") {
        const r = await fetch("https://generativelanguage.googleapis.com/v1beta/models?pageSize=200", { headers: { "x-goog-api-key": key } });
        const j = await readJson(r);
        if (!r.ok) throw new Error(errMsg(j, r.status));
        out = (j.models || []).filter((m) => (m.supportedGenerationMethods || []).indexOf("generateContent") >= 0)
            .map((m) => m.name.replace(/^models\//, ""));
    } else throw new Error("Bilinmeyen sağlayıcı");
    if (img) out = out.filter((id) => resimModeliMi(provider, id));
    return out;
}

router.post("/ai/chat", async (req, res) => {
    const b = req.body || {};
    if (PROVIDERS.indexOf(b.provider) < 0 || !b.model || !Array.isArray(b.messages)) return res.status(400).json({ error: "Eksik istek" });
    const started = Date.now();
    try {
        const r = await chat(b.provider, readKeys()[b.provider], "" + b.model, b.system ? "" + b.system : "", b.messages.slice(-60));
        r.ms = Date.now() - started;
        res.json(r);
    } catch (e) {
        res.status(502).json({ error: e.message, ms: Date.now() - started });
    }
});

router.post("/ai/draw", async (req, res) => {
    const b = req.body || {};
    if (PROVIDERS.indexOf(b.provider) < 0 || !b.prompt) return res.status(400).json({ error: "Eksik istek" });
    const started = Date.now();
    try {
        const r = await draw(b.provider, readKeys()[b.provider], b.model ? "" + b.model : "", "" + b.prompt);
        r.ms = Date.now() - started;
        res.json(r);
    } catch (e) {
        res.status(502).json({ error: e.message, ms: Date.now() - started });
    }
});

router.get("/ai/models", async (req, res) => {
    const p = "" + req.query.provider;
    if (PROVIDERS.indexOf(p) < 0) return res.status(400).json({ error: "Bilinmeyen sağlayıcı" });
    try { res.json({ models: await listModels(p, readKeys()[p], req.query.img === "1") }); } catch (e) { res.status(502).json({ error: e.message }); }
});

// Telefondan anahtarlari kaydet (bos gelen alan degistirilmez, "-" gelen silinir)
router.post("/ai/keys", (req, res) => {
    const k = readKeys();
    for (const p of PROVIDERS) {
        const v = req.body && req.body[p];
        if (v === "-") delete k[p];
        else if (v) k[p] = ("" + v).trim();
    }
    fs.writeFileSync(KEYS_FILE, JSON.stringify(k), { mode: 0o600 });
    res.json(keyStatus(k));
});

function keyStatus(k) { const s = {}; for (const p of PROVIDERS) s[p] = !!k[p]; return s; }
router.get("/ai/keys", (req, res) => res.json(keyStatus(readKeys())));

module.exports = router;
