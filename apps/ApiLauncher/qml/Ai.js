// ApiLauncher ag katmani: OpenAI (GPT), Anthropic (Claude), Google (Gemini), xAI (Grok)
//  - "dogrudan": telefon saglayiciya HTTPS ile baglanir; TLS kurulamazsa istek kendiliginden sunucudan gider
//  - "sunucu": istek kendi sunucumuz uzerinden gider (anahtarlar sunucuda saklanir; foto, resim, Grok dahil)
// Foto: mesajda img (JPEG base64) varsa dort servise de resimli gonderilir.
// Resim olusturma: GPT (images API), Gemini (resim modeli), Grok (images API). Claude resim cizmez.
.pragma library

var ANTHROPIC_VERSION = "2026-10-21";
// Claude'un guvenlik reddinde istegi uygun modelde yeniden calistiran sunucu tarafi yedek
var FALLBACK_MODELS = ["claude-fable-5-1", "claude-opus-5-5", "claude-opus-5", "claude-sonnet-5-5"];

var IMG_DEFAULTS = { openai: "gpt-image-1", gemini: "gemini-2.5-flash-image", grok: "grok-2-image" };

var cfg = {
    mode: "direct",          // "direct" | "relay"
    server: "https://e6.msahincelen.xyz",
    serverKey: "",
    keys: { openai: "", claude: "", gemini: "", grok: "" },
    imgModels: { openai: IMG_DEFAULTS.openai, gemini: IMG_DEFAULTS.gemini, grok: IMG_DEFAULTS.grok },
    system: ""
};

function canDraw(provider) { return provider === "openai" || provider === "gemini" || provider === "grok"; }

function httpError(xhr) {
    if (xhr.status === 0) return qsTr("Bağlantı kurulamadı (HTTPS/TLS veya internet sorunu). Ayarlar'dan bağlantıyı test edin.");
    var j = null;
    try { j = JSON.parse(xhr.responseText); } catch (e) { }
    if (j && j.error) return (typeof j.error === "string" ? j.error : (j.error.message || JSON.stringify(j.error))) + " (" + xhr.status + ")";
    return qsTr("HTTP ") + xhr.status;
}

var yardim = null;     // main.qml baglar (C++ "yardim"): XHR'in gizledigi hata ayrintisi icin

// Sunucunun hata govdesinden okunur mesaj
function govdeHatasi(status, govde) {
    var j = null;
    try { j = JSON.parse(govde); } catch (e) { }
    var m = "";
    if (j && j.error) m = typeof j.error === "string" ? j.error : (j.error.message || "");
    if (status === 402) m = qsTr("Ödeme gerekli: bu API anahtarının projesinde kredi/bakiye bitmiş. Ücretsiz kullanım için faturalandırması kapalı bir projeden anahtar alın.") + (m ? "\n" + m : "");
    else if (status === 429) m = qsTr("Kota/sınır aşıldı, biraz sonra yeniden deneyin.") + (m ? "\n" + m : "");
    else if (status === 401 && !m) m = qsTr("API anahtarı geçersiz ya da iptal edilmiş");
    return (m ? m : qsTr("HTTP hatası")) + " (" + status + ")";
}

function send(method, url, headers, body, onOk, onFail) {
    var xhr = new XMLHttpRequest();
    var started = new Date().getTime();
    var govde = body === null ? null : JSON.stringify(body);
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        var ms = new Date().getTime() - started;
        if (xhr.status >= 200 && xhr.status < 300) {
            var j = null;
            try { j = JSON.parse(xhr.responseText); } catch (e) { onFail(qsTr("Geçersiz yanıt"), ms); return; }
            onOk(j, ms);
        } else if (yardim && (xhr.status === 0 || (xhr.status >= 400 && !xhr.responseText))) {
            // Qt 4.7 XHR 402/429 gibi kodlarda durum 0 verir, 401'de govdeyi gizler: ayni istegi C++ ile yinele
            var d = yardim.istekHatasi(method, url, headers, govde === null ? "" : govde);
            if (d.status >= 200 && d.status < 300) {
                var j2 = null;
                try { j2 = JSON.parse(d.body); } catch (e2) { onFail(qsTr("Geçersiz yanıt"), ms); return; }
                onOk(j2, ms);
            } else if (d.status > 0) onFail(govdeHatasi(d.status, d.body), ms, d.status);
            else onFail(httpError(xhr), ms, xhr.status);
        } else {
            onFail(httpError(xhr), ms, xhr.status);
        }
    };
    xhr.open(method, url);
    for (var h in headers) xhr.setRequestHeader(h, headers[h]);
    xhr.send(govde);
}

function hasImage(hist) { for (var i = 0; i < hist.length; i++) if (hist[i].img) return true; return false; }

// OpenAI ve Grok ayni bicimi kullanir
function openaiMessages(hist) {
    var msgs = [];
    if (cfg.system) msgs.push({ role: "system", content: cfg.system });
    for (var i = 0; i < hist.length; i++) {
        if (hist[i].img && hist[i].role === "user") {
            msgs.push({ role: "user", content: [
                { type: "text", text: hist[i].text || qsTr("Bu resimde ne var?") },
                { type: "image_url", image_url: { url: "data:image/jpeg;base64," + hist[i].img } }
            ] });
        } else msgs.push({ role: hist[i].role, content: hist[i].text });
    }
    return msgs;
}

// ---- Sunucu uzerinden (relay) ----
// Dogrudan HTTPS (TLS) kurulamazsa ayni istek sunucudan yeniden denenir. Sunucuda anahtar yoksa
// bu saglayicinin anahtari bir kez sunucuya kaydedilir ve istek tekrarlanir.
var onLog = null;      // main.qml baglar: function(metin)
function log(s) { if (onLog) onLog(s); }

function relay(path, body, onOk, onFail, ikinci) {
    if (!cfg.serverKey) { onFail(qsTr("Sunucu parolası yok (Ayarlar > Bağlantı).")); return; }
    send("POST", cfg.server + path, { "Content-Type": "application/json", "X-Api-Key": cfg.serverKey, "X-Lang": cfg.lang || "tr" }, body,
         function (j, ms) { j.ms = ms; j.relay = true; onOk(j); },
         function (m, ms, st) {
             var p = body.provider;
             if (!ikinci && /anahtarı yok/.test(m) && cfg.keys[p]) {
                 log(p + " anahtari sunucuya kaydediliyor");
                 var k = {}; k[p] = cfg.keys[p];
                 send("POST", cfg.server + "/ai/keys", { "Content-Type": "application/json", "X-Api-Key": cfg.serverKey, "X-Lang": cfg.lang || "tr" }, k,
                      function () { relay(path, body, onOk, onFail, true); }, function (m2) { onFail(m2); });
                 return;
             }
             onFail(m);
         });
}

// Dogrudan istegin hata geri cagrisi: TLS/baglanti hatasinda (durum 0) sunucuya gec
function yedekli(path, body, onFail, onOk) {
    return function (m, ms, st) {
        if (st === 0 && cfg.serverKey) {
            log(body.provider + " dogrudan baglanamadi, sunucu uzerinden deneniyor");
            relay(path, body, onOk, function (m2) { onFail(m2 + qsTr(" (doğrudan bağlantı da kurulamadı)")); });
        } else onFail(m);
    };
}

// messages: [{ role: "user"|"assistant", text, img? (JPEG base64) }]
// onOk({ text, model, refusal?, ms, relay? }), onFail(mesaj)
function chat(provider, model, messages, onOk, onFail) {
    var hist = messages.slice(-60);
    var rbody = { provider: provider, model: model, system: cfg.system, messages: hist };
    if (cfg.mode === "relay") { relay("/ai/chat", rbody, onOk, onFail); return; }
    var key = cfg.keys[provider];
    if (!key) { onFail(qsTr("Ayarlar'dan ") + label(provider) + qsTr(" API anahtarını girin.")); return; }
    onFail = yedekli("/ai/chat", rbody, onFail, onOk);
    var i;
    if (provider === "openai" || provider === "grok") {
        var url = provider === "openai" ? "https://api.openai.com/v1/chat/completions" : "https://api.x.ai/v1/chat/completions";
        send("POST", url,
             { "Content-Type": "application/json", "Authorization": qsTr("Bearer ") + key },
             { model: model, messages: openaiMessages(hist) },
             function (j, ms) {
                 var c = j.choices && j.choices[0];
                 onOk({ text: c && c.message && c.message.content ? c.message.content : "", model: j.model || model, ms: ms });
             }, function (m) { onFail(m); });
    } else if (provider === "claude") {
        var cm = [];
        for (i = 0; i < hist.length; i++) {
            if (hist[i].img && hist[i].role === "user")
                cm.push({ role: "user", content: [
                    { type: "image", source: { type: "base64", media_type: "image/jpeg", data: hist[i].img } },
                    { type: "text", text: hist[i].text || qsTr("Bu resimde ne var?") }
                ] });
            else cm.push({ role: hist[i].role, content: hist[i].text });
        }
        var body = { model: model, max_tokens: 16000, messages: cm };
        if (cfg.system) body.system = cfg.system;
        var headers = { "Content-Type": "application/json", "x-api-key": key, "anthropic-version": ANTHROPIC_VERSION };
        if (FALLBACK_MODELS.indexOf(model) >= 0) { body.fallbacks = "default"; headers["anthropic-beta"] = "server-side-fallback-2026-07-01"; }
        send("POST", "https://api.anthropic.com/v1/messages", headers, body,
             function (j, ms) {
                 if (j.stop_reason === "refusal") {
                     var d = j.stop_details || {};
                     onOk({ text: "", refusal: d.explanation ? d.explanation : qsTr("Claude bu isteği yanıtlamadı") + (d.category ? " (" + d.category + ")" : ""), model: j.model || model, ms: ms });
                     return;
                 }
                 var t = "";
                 var content = j.content || [];
                 for (var k = 0; k < content.length; k++) if (content[k].type === "text") t += content[k].text;
                 onOk({ text: t, model: j.model || model, ms: ms });
             }, function (m) { onFail(m); });
    } else if (provider === "gemini") {
        var contents = [];
        for (i = 0; i < hist.length; i++) {
            var parts = [];
            if (hist[i].img && hist[i].role === "user") parts.push({ inline_data: { mime_type: "image/jpeg", data: hist[i].img } });
            parts.push({ text: hist[i].text || (hist[i].img ? qsTr("Bu resimde ne var?") : "") });
            contents.push({ role: hist[i].role === "assistant" ? "model" : "user", parts: parts });
        }
        var gb = { contents: contents };
        if (cfg.system) gb.systemInstruction = { parts: [{ text: cfg.system }] };
        send("POST", "https://generativelanguage.googleapis.com/v1beta/models/" + encodeURIComponent(model) + ":generateContent",
             { "Content-Type": "application/json", "x-goog-api-key": key }, gb,
             function (j, ms) {
                 var c = j.candidates && j.candidates[0];
                 var t = "";
                 if (c && c.content && c.content.parts) for (var p = 0; p < c.content.parts.length; p++) t += c.content.parts[p].text || "";
                 if (!t && j.promptFeedback && j.promptFeedback.blockReason) { onOk({ text: "", refusal: qsTr("Gemini yanıtlamadı (") + j.promptFeedback.blockReason + ")", model: model, ms: ms }); return; }
                 onOk({ text: t, model: j.modelVersion || model, ms: ms });
             }, function (m) { onFail(m); });
    } else {
        onFail(qsTr("Bilinmeyen sağlayıcı"));
    }
}

// Resim olusturma. onOk({ b64, ext, text, model, ms }), onFail(mesaj)
function draw(provider, prompt, onOk, onFail) {
    if (!canDraw(provider)) { onFail(label(provider) + qsTr(" resim çizmiyor; GPT, Gemini ya da Grok sekmesini kullanın.")); return; }
    var model = cfg.imgModels[provider] || IMG_DEFAULTS[provider];
    var rbody = { provider: provider, model: model, prompt: prompt };
    if (cfg.mode === "relay") { relay("/ai/draw", rbody, onOk, onFail); return; }
    var key = cfg.keys[provider];
    if (!key) { onFail(qsTr("Ayarlar'dan ") + label(provider) + qsTr(" API anahtarını girin.")); return; }
    onFail = yedekli("/ai/draw", rbody, onFail, onOk);
    if (provider === "openai" || provider === "grok") {
        var body = { model: model, prompt: prompt, n: 1 };
        if (provider === "openai") body.size = "1024x1024";
        else body.response_format = "b64_json";
        send("POST", provider === "openai" ? "https://api.openai.com/v1/images/generations" : "https://api.x.ai/v1/images/generations",
             { "Content-Type": "application/json", "Authorization": qsTr("Bearer ") + key }, body,
             function (j, ms) {
                 var d = j.data && j.data[0];
                 if (!d || !d.b64_json) { onFail(qsTr("Resim gelmedi") + (d && d.url ? qsTr(" (yalnızca bağlantı döndü)") : "")); return; }
                 onOk({ b64: d.b64_json, ext: provider === "openai" ? "png" : "jpg", text: d.revised_prompt || "", model: model, ms: ms });
             }, function (m) { onFail(m); });
    } else {
        send("POST", "https://generativelanguage.googleapis.com/v1beta/models/" + encodeURIComponent(model) + ":generateContent",
             { "Content-Type": "application/json", "x-goog-api-key": key },
             { contents: [{ role: "user", parts: [{ text: prompt }] }], generationConfig: { responseModalities: ["TEXT", "IMAGE"] } },
             function (j, ms) {
                 var c = j.candidates && j.candidates[0];
                 var b64 = "", mime = "image/png", t = "";
                 if (c && c.content && c.content.parts) {
                     for (var p = 0; p < c.content.parts.length; p++) {
                         var pt = c.content.parts[p];
                         var inl = pt.inlineData || pt.inline_data;
                         if (inl && inl.data) { b64 = inl.data; mime = inl.mimeType || inl.mime_type || mime; }
                         else if (pt.text) t += pt.text;
                     }
                 }
                 if (!b64) { onFail(t ? qsTr("Resim yerine metin döndü: ") + t.substring(0, 120) : qsTr("Resim gelmedi")); return; }
                 onOk({ b64: b64, ext: mime.indexOf("jpeg") >= 0 ? "jpg" : "png", text: t, model: model, ms: ms });
             }, function (m) { onFail(m); });
    }
}

// Resim modeli mi (model listesinden ayiklamak icin)
function isImageModel(provider, id) {
    if (provider === "openai") return /^(gpt-image|dall-e|chatgpt-image)/.test(id);
    if (provider === "gemini") return /image|imagen/.test(id);
    if (provider === "grok") return /image|imagine/.test(id);
    return false;
}

// Resim modelleri: once bilinenler, sonra saglayicinin listesindekiler
function imageModels(provider, onOk, onFail) {
    var bilinen = { openai: ["gpt-image-1", "gpt-image-1-mini", "dall-e-3", "dall-e-2"],
                    gemini: ["gemini-2.5-flash-image", "gemini-2.0-flash-preview-image-generation", "imagen-4.0-generate-001"],
                    grok: ["grok-2-image", "grok-2-image-1212"] }[provider] || [];
    models(provider, function (list) {
        var out = [], i;
        for (i = 0; i < list.length; i++) if (isImageModel(provider, list[i]) && out.indexOf(list[i]) < 0) out.push(list[i]);
        for (i = 0; i < bilinen.length; i++) if (out.indexOf(bilinen[i]) < 0) out.push(bilinen[i]);
        onOk(out);
    }, function (m) { onOk(bilinen.length ? bilinen : []); if (!bilinen.length) onFail(m); }, true);
}

function relayModels(provider, img, onOk, onFail) {
    send("GET", cfg.server + "/ai/models?provider=" + provider + (img ? "&img=1" : ""), { "X-Api-Key": cfg.serverKey, "X-Lang": cfg.lang || "tr" }, null,
         function (j) { onOk(j.models || []); }, function (m) { onFail(m); });
}

// onOk([modelId...]), onFail(mesaj)
function models(provider, onOk, onFail, img) {
    if (cfg.mode === "relay") { relayModels(provider, img, onOk, onFail); return; }
    var key = cfg.keys[provider];
    if (!key) { onFail(qsTr("Önce API anahtarını girin.")); return; }
    var asil = onFail;
    onFail = function (m, ms, st) {
        if (st === 0 && cfg.serverKey) relayModels(provider, img, onOk, function (m2) { asil(m2 + qsTr(" (doğrudan bağlantı da kurulamadı)")); });
        else asil(m);
    };
    if (provider === "openai" || provider === "grok") {
        send("GET", provider === "openai" ? "https://api.openai.com/v1/models" : "https://api.x.ai/v1/models",
             { "Authorization": qsTr("Bearer ") + key }, null, function (j) {
            var out = [];
            var d = j.data || [];
            for (var i = 0; i < d.length; i++) if (img || provider === "grok" || (/^(gpt|o\d|chatgpt)/.test(d[i].id) && !isImageModel(provider, d[i].id))) out.push(d[i].id);
            out.sort(); out.reverse();
            onOk(out);
        }, function (m) { onFail(m); });
    } else if (provider === "claude") {
        send("GET", "https://api.anthropic.com/v1/models?limit=100", { "x-api-key": key, "anthropic-version": ANTHROPIC_VERSION }, null, function (j) {
            var out = [];
            var d = j.data || [];
            for (var i = 0; i < d.length; i++) out.push(d[i].id);
            onOk(out);
        }, function (m) { onFail(m); });
    } else if (provider === "gemini") {
        send("GET", "https://generativelanguage.googleapis.com/v1beta/models?pageSize=200", { "x-goog-api-key": key }, null, function (j) {
            var out = [];
            var d = j.models || [];
            for (var i = 0; i < d.length; i++) {
                var m = d[i].supportedGenerationMethods || [];
                if (m.indexOf("generateContent") >= 0) out.push(d[i].name.replace(/^models\//, ""));
            }
            onOk(out);
        }, function (m) { onFail(m); });
    }
}

// "Sunucu uzerinden" modu icin anahtarlari sunucuya kaydeder (bos alanlar degismez)
function saveKeysToServer(onOk, onFail) {
    send("POST", cfg.server + "/ai/keys", { "Content-Type": "application/json", "X-Api-Key": cfg.serverKey, "X-Lang": cfg.lang || "tr" },
         { openai: cfg.keys.openai, claude: cfg.keys.claude, gemini: cfg.keys.gemini, grok: cfg.keys.grok },
         function (j) { onOk(j); }, function (m) { onFail(m); });
}

function label(p) {
    return p === "openai" ? qsTr("GPT (OpenAI)") : (p === "claude" ? qsTr("Claude (Anthropic)") : (p === "gemini" ? qsTr("Gemini (Google)") : qsTr("Grok (xAI)")));
}
