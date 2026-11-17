.pragma library
// BelleCeviri servisleri: istek kurma ve yanit cozme. Tasima C++'ta (cv.istek), burada yalnizca bicim.
// tur: "ceviri" | "sozluk"; anahtarli: API anahtari ister; llm: buyuk dil modeli (anlami yorumlar).

var servisler = [
    { kod: "google", ad: "Google Çeviri", alt: "resmî olmayan yol", tur: "ceviri", anahtarli: false, llm: false, varsayilan: true,
      bilgi: "Anahtar gerekmez. Google'ın web çevirisinin kullandığı açık uç; resmî bir API değildir, Google değiştirebilir." },
    { kod: "mymemory", ad: "MyMemory", alt: "", tur: "ceviri", anahtarli: false, llm: false, varsayilan: false,
      bilgi: "Anahtar gerekmez. İstek başına en çok 500 karakter, günlük kota düşüktür." },
    { kod: "deepl", ad: "DeepL", alt: "Free", tur: "ceviri", anahtarli: true, llm: false, varsayilan: false,
      bilgi: "Ücretsiz anahtar: deepl.com/pro-api (DeepL API Free, aylık kota). Free anahtarlar :fx ile biter." },
    { kod: "gemini", ad: "Gemini", alt: "", tur: "ceviri", anahtarli: true, llm: true, varsayilan: false, model: "gemini-3.5-flash",
      bilgi: "Ücretsiz anahtar: aistudio.google.com (faturalandırması kapalı proje). Hızlı modeller: gemini-3.5-flash, gemini-flash-lite-latest." },
    { kod: "groq", ad: "Groq", alt: "", tur: "ceviri", anahtarli: true, llm: true, varsayilan: false, model: "llama-3.3-70b-versatile",
      bilgi: "Ücretsiz anahtar: console.groq.com. Çok hızlıdır." },
    { kod: "mistral", ad: "Mistral", alt: "", tur: "ceviri", anahtarli: true, llm: true, varsayilan: false, model: "mistral-small-latest",
      bilgi: "Ücretsiz deneme anahtarı: console.mistral.ai." },
    { kod: "openai", ad: "OpenAI", alt: "ücretli", tur: "ceviri", anahtarli: true, llm: true, varsayilan: false, model: "gpt-4o-mini",
      bilgi: "Ücretli anahtar: platform.openai.com." },
    { kod: "claude", ad: "Claude", alt: "ücretli", tur: "ceviri", anahtarli: true, llm: true, varsayilan: false, model: "claude-haiku-5-5",
      bilgi: "Ücretli anahtar: console.anthropic.com." },
    { kod: "tdk", ad: "TDK Sözlük", alt: "", tur: "sozluk", anahtarli: false, llm: false, varsayilan: true,
      bilgi: "Anahtar gerekmez. Türkçe kelimelerin resmî anlamları, örnekler, atasözleri (sozluk.gov.tr)." },
    { kod: "wiktionary", ad: "Wiktionary", alt: "", tur: "sozluk", anahtarli: false, llm: false, varsayilan: true,
      bilgi: "Anahtar gerekmez. Çok dilli sözlük (en.wiktionary.org); anlamlar İngilizce açıklanır." }
];

function servis(kod) { for (var i = 0; i < servisler.length; i++) if (servisler[i].kod === kod) return servisler[i]; return null; }

// [kod, Turkce ad, English name]
var diller = [
    ["auto", "Dili algıla", "Detect language"], ["tr", "Türkçe", "Turkish"], ["en", "İngilizce", "English"], ["de", "Almanca", "German"],
    ["fr", "Fransızca", "French"], ["es", "İspanyolca", "Spanish"], ["it", "İtalyanca", "Italian"], ["pt", "Portekizce", "Portuguese"],
    ["ru", "Rusça", "Russian"], ["ar", "Arapça", "Arabic"], ["fa", "Farsça", "Persian"], ["az", "Azerice", "Azerbaijani"],
    ["ku", "Kürtçe (Kurmanci)", "Kurdish (Kurmanji)"], ["ckb", "Kürtçe (Sorani)", "Kurdish (Sorani)"], ["el", "Yunanca", "Greek"], ["bg", "Bulgarca", "Bulgarian"],
    ["ro", "Rumence", "Romanian"], ["nl", "Felemenkçe", "Dutch"], ["sv", "İsveççe", "Swedish"], ["no", "Norveççe", "Norwegian"],
    ["da", "Danca", "Danish"], ["fi", "Fince", "Finnish"], ["pl", "Lehçe", "Polish"], ["cs", "Çekçe", "Czech"],
    ["sk", "Slovakça", "Slovak"], ["hu", "Macarca", "Hungarian"], ["uk", "Ukraynaca", "Ukrainian"], ["be", "Belarusça", "Belarusian"],
    ["sr", "Sırpça", "Serbian"], ["hr", "Hırvatça", "Croatian"], ["bs", "Boşnakça", "Bosnian"], ["sq", "Arnavutça", "Albanian"],
    ["mk", "Makedonca", "Macedonian"], ["sl", "Slovence", "Slovenian"], ["ka", "Gürcüce", "Georgian"], ["hy", "Ermenice", "Armenian"],
    ["he", "İbranice", "Hebrew"], ["hi", "Hintçe", "Hindi"], ["ur", "Urduca", "Urdu"], ["bn", "Bengalce", "Bengali"],
    ["pa", "Pencapça", "Punjabi"], ["ja", "Japonca", "Japanese"], ["ko", "Korece", "Korean"], ["zh-CN", "Çince (Basit)", "Chinese (Simplified)"],
    ["zh-TW", "Çince (Geleneksel)", "Chinese (Traditional)"], ["th", "Tayca", "Thai"], ["vi", "Vietnamca", "Vietnamese"], ["id", "Endonezce", "Indonesian"],
    ["ms", "Malayca", "Malay"], ["tl", "Filipince", "Filipino"], ["sw", "Svahili", "Swahili"], ["af", "Afrikaanca", "Afrikaans"],
    ["kk", "Kazakça", "Kazakh"], ["uz", "Özbekçe", "Uzbek"], ["ky", "Kırgızca", "Kyrgyz"], ["tk", "Türkmence", "Turkmen"],
    ["tt", "Tatarca", "Tatar"], ["ug", "Uygurca", "Uyghur"], ["mn", "Moğolca", "Mongolian"], ["ps", "Peştuca", "Pashto"],
    ["ta", "Tamilce", "Tamil"], ["te", "Telugu dili", "Telugu"], ["ml", "Malayalamca", "Malayalam"], ["mr", "Marathi", "Marathi"],
    ["gu", "Güceratça", "Gujarati"], ["ne", "Nepalce", "Nepali"], ["si", "Seylanca", "Sinhala"], ["my", "Birmanca", "Burmese"],
    ["km", "Kmerce", "Khmer"], ["lo", "Laoca", "Lao"], ["am", "Amharca", "Amharic"], ["so", "Somalice", "Somali"],
    ["ha", "Hausa dili", "Hausa"], ["yo", "Yoruba dili", "Yoruba"], ["zu", "Zuluca", "Zulu"], ["ca", "Katalanca", "Catalan"],
    ["eu", "Baskça", "Basque"], ["gl", "Galiçyaca", "Galician"], ["et", "Estonca", "Estonian"], ["lv", "Letonca", "Latvian"],
    ["lt", "Litvanca", "Lithuanian"], ["is", "İzlandaca", "Icelandic"], ["ga", "İrlandaca", "Irish"], ["cy", "Galce", "Welsh"],
    ["mt", "Maltaca", "Maltese"], ["la", "Latince", "Latin"], ["eo", "Esperanto", "Esperanto"], ["lb", "Lüksemburgca", "Luxembourgish"]
];
function dilAdi(kod, ing) { for (var i = 0; i < diller.length; i++) if (diller[i][0] === kod) return diller[i][ing ? 2 : 1]; return kod; }

function formKodla(s) { return encodeURIComponent(s).replace(/%20/g, "+"); }

// DeepL dil kodlari
function deeplDil(k, hedef) {
    var u = k.toUpperCase();
    if (u === "ZH-CN" || u === "ZH-TW") return "ZH";
    if (hedef && u === "EN") return "EN-US";
    if (hedef && u === "PT") return "PT-PT";
    if (u === "NO") return "NB";
    return u;
}

function llmSistem(sl, tl) {
    return "You are a translation engine. Translate the user's text " + (sl === "auto" ? "" : "from " + dilAdi(sl, true) + " ") + "into " + dilAdi(tl, true)
        + ". Output only the translation, preserving line breaks, numbers and formatting. No quotes, notes, alternatives or explanations.";
}
function llmAciklaSistem(arayuzIng, tl) {
    return "You are a concise bilingual dictionary. For the word or phrase the user sends, answer in " + (arayuzIng ? "English" : "Turkish")
        + ": its language, part of speech, main meanings (numbered, short), and two short example sentences with their translation into "
        + dilAdi(tl, true) + ". Plain text only, no markdown symbols.";
}

// --- istek: { yontem, url, basliklar, govde } ya da { hata } ---
function istek(kod, metin, sl, tl, anahtar, model, aciklaIng) {
    var s = servis(kod);
    if (s.anahtarli && !anahtar) return { hata: "Anahtar girilmemiş (Ayarlar > Servisler)" };
    var m = model || s.model;
    var sistem = aciklaIng !== undefined ? llmAciklaSistem(aciklaIng, tl) : llmSistem(sl, tl);
    if (kod === "google")
        return { yontem: "POST", url: "https://translate.googleapis.com/translate_a/single?client=gtx&dj=1&dt=t&dt=bd&sl=" + (sl === "ckb" ? "ckb" : sl) + "&tl=" + tl,
                 basliklar: { "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8" }, govde: "q=" + formKodla(metin) };
    if (kod === "mymemory") {
        var kisa = metin.length > 480 ? metin.substring(0, 480) : metin;
        return { yontem: "GET", url: "https://api.mymemory.translated.net/get?langpair=" + (sl === "auto" ? "Autodetect" : sl) + "|" + tl + "&q=" + encodeURIComponent(kisa), basliklar: {}, govde: "" };
    }
    if (kod === "deepl") {
        var host = /:fx$/.test(anahtar) ? "https://api-free.deepl.com" : "https://api.deepl.com";
        return { yontem: "POST", url: host + "/v2/translate", basliklar: { "Authorization": "DeepL-Auth-Key " + anahtar, "Content-Type": "application/x-www-form-urlencoded" },
                 govde: "text=" + formKodla(metin) + "&target_lang=" + deeplDil(tl, true) + (sl === "auto" ? "" : "&source_lang=" + deeplDil(sl, false)) };
    }
    if (kod === "gemini")
        return { yontem: "POST", url: "https://generativelanguage.googleapis.com/v1beta/models/" + encodeURIComponent(m) + ":generateContent",
                 basliklar: { "Content-Type": "application/json", "x-goog-api-key": anahtar },
                 govde: JSON.stringify({ systemInstruction: { parts: [{ text: sistem }] }, contents: [{ role: "user", parts: [{ text: metin }] }], generationConfig: { temperature: 0.2 } }) };
    if (kod === "groq" || kod === "mistral" || kod === "openai") {
        var u = kod === "groq" ? "https://api.groq.com/openai/v1/chat/completions" : (kod === "mistral" ? "https://api.mistral.ai/v1/chat/completions" : "https://api.openai.com/v1/chat/completions");
        return { yontem: "POST", url: u, basliklar: { "Content-Type": "application/json", "Authorization": "Bearer " + anahtar },
                 govde: JSON.stringify({ model: m, temperature: 0.2, messages: [{ role: "system", content: sistem }, { role: "user", content: metin }] }) };
    }
    if (kod === "claude")
        return { yontem: "POST", url: "https://api.anthropic.com/v1/messages",
                 basliklar: { "Content-Type": "application/json", "x-api-key": anahtar, "anthropic-version": "2023-06-01" },
                 govde: JSON.stringify({ model: m, max_tokens: 2048, system: sistem, messages: [{ role: "user", content: metin }] }) };
    if (kod === "tdk") return { yontem: "GET", url: "https://sozluk.gov.tr/gts?ara=" + encodeURIComponent(metin.toLocaleLowerCase()), basliklar: {}, govde: "" };
    if (kod === "wiktionary") return { yontem: "GET", url: "https://en.wiktionary.org/api/rest_v1/page/definition/" + encodeURIComponent(metin.replace(/ /g, "_")), basliklar: {}, govde: "" };
    return { hata: "Bilinmeyen servis" };
}

function htmlSil(s) {
    return ("" + (s || "")).replace(/<[^>]*>/g, "").replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&#39;/g, "'").replace(/^\s+|\s+$/g, "");
}

// HTTP durumuna gore anlasilir hata
function durumHatasi(kod, govde) {
    var j = null, m = "";
    try { j = JSON.parse(govde); } catch (e) { }
    if (j) {
        if (j.error) m = typeof j.error === "string" ? j.error : (j.error.message || "");
        else if (j.message) m = j.message;
        else if (j.responseDetails) m = j.responseDetails;
    }
    if (kod === 401 || kod === 403) return "Anahtar geçersiz ya da yetkisiz (" + kod + ")" + (m ? ": " + m : "");
    if (kod === 402) return "Ödeme gerekli: anahtarın kredisi bitmiş (402)";
    if (kod === 429) return "Kota ya da hız sınırı doldu, biraz sonra deneyin (429)";
    if (kod === 456) return "DeepL aylık kotası doldu (456)";
    return (m ? m : "Hata") + " (" + kod + ")";
}

// --- yanit: { metin, ek, alg } ya da { hata } ---
function coz(kod, durum, govde) {
    if (durum === 0) return { hata: "Bağlantı kurulamadı" };
    if (kod === "tdk" && durum === 200) return tdkCoz(govde);
    if (kod === "wiktionary") return durum === 404 ? { hata: "Wiktionary'de bulunamadı" } : (durum === 200 ? wiktionaryCoz(govde) : { hata: durumHatasi(durum, govde) });
    if (durum < 200 || durum >= 300) return { hata: durumHatasi(durum, govde) };
    var j = null;
    try { j = JSON.parse(govde); } catch (e) { return { hata: "Geçersiz yanıt" }; }
    if (kod === "google") {
        var t = "", s = j.sentences || [];
        for (var i = 0; i < s.length; i++) if (s[i].trans) t += s[i].trans;
        var ek = [];
        var d = j.dict || [];
        for (var k = 0; k < d.length && k < 4; k++) ek.push((d[k].pos ? d[k].pos + ": " : "") + (d[k].terms || []).slice(0, 8).join(", "));
        return { metin: t, ek: ek.join("\n"), alg: j.src || "" };
    }
    if (kod === "mymemory") {
        if (j.responseStatus && j.responseStatus !== 200 && j.responseStatus !== "200") return { hata: (j.responseDetails || "Hata") + " (" + j.responseStatus + ")" };
        var tt = j.responseData ? htmlSil(j.responseData.translatedText) : "";
        if (/MYMEMORY WARNING|QUOTA/i.test(tt)) return { hata: "MyMemory günlük kotası doldu" };
        return { metin: tt, ek: "", alg: j.responseData && j.responseData.detectedLanguage ? j.responseData.detectedLanguage : "" };
    }
    if (kod === "deepl") {
        var tr = j.translations && j.translations[0];
        return tr ? { metin: tr.text, ek: "", alg: (tr.detected_source_language || "").toLowerCase() } : { hata: "Boş yanıt" };
    }
    if (kod === "gemini") {
        var c = j.candidates && j.candidates[0], g = "";
        if (c && c.content && c.content.parts) for (var p = 0; p < c.content.parts.length; p++) if (c.content.parts[p].text && !c.content.parts[p].thought) g += c.content.parts[p].text;
        if (!g && j.promptFeedback && j.promptFeedback.blockReason) return { hata: "Gemini yanıtlamadı: " + j.promptFeedback.blockReason };
        return { metin: g.replace(/^\s+|\s+$/g, ""), ek: "", alg: "" };
    }
    if (kod === "groq" || kod === "mistral" || kod === "openai") {
        var ch = j.choices && j.choices[0];
        return ch && ch.message ? { metin: ("" + ch.message.content).replace(/^\s+|\s+$/g, ""), ek: "", alg: "" } : { hata: "Boş yanıt" };
    }
    if (kod === "claude") {
        var cl = "", ct = j.content || [];
        for (var q = 0; q < ct.length; q++) if (ct[q].type === "text") cl += ct[q].text;
        return { metin: cl.replace(/^\s+|\s+$/g, ""), ek: "", alg: "" };
    }
    return { hata: "Bilinmeyen servis" };
}

function tdkCoz(govde) {
    var j = null;
    try { j = JSON.parse(govde); } catch (e) { return { hata: "Geçersiz yanıt" }; }
    if (!j || j.error || !j.length) return { hata: "TDK'da bulunamadı" };
    var out = [], atasozu = [];
    for (var i = 0; i < j.length && i < 4; i++) {
        var m = j[i];
        out.push(m.madde + (m.lisan ? "  (" + m.lisan + ")" : ""));
        var an = m.anlamlarListe || [];
        for (var k = 0; k < an.length && k < 12; k++) {
            var oz = (an[k].ozelliklerListe || []).map(function (x) { return x.tam_adi; }).join(", ");
            out.push((k + 1) + ". " + (oz ? "[" + oz + "] " : "") + an[k].anlam);
            var ornek = an[k].orneklerListe || [];
            if (ornek.length) out.push("    “" + ornek[0].ornek + "”" + (ornek[0].yazar && ornek[0].yazar.length ? " —" + ornek[0].yazar[0].tam_adi : ""));
        }
        var as = m.atasozu || [];
        for (var a = 0; a < as.length && atasozu.length < 6; a++) atasozu.push("• " + as[a].madde);
        out.push("");
    }
    if (atasozu.length) out.push("Atasözleri ve deyimler:\n" + atasozu.join("\n"));
    return { metin: out.join("\n").replace(/\n+$/, ""), ek: "", alg: "tr" };
}

function wiktionaryCoz(govde) {
    var j = null;
    try { j = JSON.parse(govde); } catch (e) { return { hata: "Geçersiz yanıt" }; }
    var out = [], n = 0, sira = [];
    // once Turkce ve Ingilizce girdiler, sonra digerleri
    if (j.tr) sira.push("tr");
    if (j.en) sira.push("en");
    for (var x in j) if (x !== "tr" && x !== "en") sira.push(x);
    for (var si = 0; si < sira.length; si++) {
        var dil = sira[si];
        var l = j[dil];
        if (!l || !l.length || n >= 4) continue;
        n++;
        out.push("■ " + (l[0].language || dil));
        for (var i = 0; i < l.length && i < 4; i++) {
            out.push(l[i].partOfSpeech + ":");
            var d = l[i].definitions || [], say = 0;
            for (var k = 0; k < d.length && say < 5; k++) {
                var t = htmlSil(d[k].definition);
                if (!t) continue;
                say++;
                out.push("  " + say + ". " + t);
                if (d[k].parsedExamples && d[k].parsedExamples.length) out.push("     “" + htmlSil(d[k].parsedExamples[0].example) + "”");
            }
        }
        out.push("");
    }
    return out.length ? { metin: out.join("\n").replace(/\n+$/, ""), ek: "", alg: "" } : { hata: "Wiktionary'de bulunamadı" };
}
