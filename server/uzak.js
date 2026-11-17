// BelleRemote aktarıcı: telefon ile PC'yi sunucu üzerinden eşleştirip baytları olduğu gibi aktarır.
// Protokol: Kaynak kod\BelleRemote\PROTOKOL.md
//   GET /uzak/baglan?rol=pc&ad=..&lan=..   (Upgrade: e6uzak)  -> PC bekler
//   GET /uzak/baglan?rol=tel&hedef=..      (Upgrade: e6uzak)  -> bekleyen PC'ye bağlanır
//   GET /uzak/liste                        (normal HTTP)      -> çevrimiçi PC'ler
// Kimlik: X-Api-Key (ya da ?key=) = sunucu parolası (BELLE_KEY).
const crypto = require("crypto");
const express = require("express");

const PING = Buffer.from([0x50, 0, 0, 0, 0]);      // 'P' + uzunluk 0
const waiting = new Map();                          // ad -> { sock, lan, since, ping }
let active = 0;

function safeEqual(a, b) {
    if (typeof a !== "string" || typeof b !== "string") return false;
    const ba = Buffer.from(a), bb = Buffer.from(b);
    return ba.length === bb.length && crypto.timingSafeEqual(ba, bb);
}
const cleanName = (s) => ("" + (s || "")).replace(/[^\w .\-]/g, "").trim().slice(0, 40);

function reject(sock, code, text) {
    try { sock.end(`HTTP/1.1 ${code} ${text}\r\nContent-Type: text/plain; charset=utf-8\r\nConnection: close\r\n\r\n${text}`); } catch (e) { }
    setTimeout(() => { try { sock.destroy(); } catch (e) { } }, 1000);
}

function accept(sock) {
    sock.write("HTTP/1.1 101 Switching Protocols\r\nUpgrade: e6uzak\r\nConnection: Upgrade\r\n\r\n");
    sock.setNoDelay(true);
    sock.setKeepAlive(true, 20000);
}

function dropWaiter(name, w) {
    if (waiting.get(name) === w) waiting.delete(name);
    clearInterval(w.ping);
}

// Bekleyen PC'yi verilen (yukseltilmis) baglantiya bagla: telefon uygulamasi ve web paneli (WebSocket) kullanir
function pcBagla(sock, name, head, kimden) {
    if (!name && waiting.size === 1) name = waiting.keys().next().value;
    const w = name ? waiting.get(name) : null;
    if (!w) return false;
    dropWaiter(name, w);
    w.sock.removeListener("data", w.onData);
    const pc = w.sock;
    if (head && head.length) pc.write(head);
    sock.pipe(pc);
    pc.pipe(sock);
    active++;
    const t0 = Date.now();
    let closed = false;
    const close = () => {
        if (closed) return;
        closed = true;
        active--;
        try { sock.destroy(); } catch (e) { }
        try { pc.destroy(); } catch (e) { }
        console.log(`[uzak] oturum bitti: ${name} (${Math.round((Date.now() - t0) / 1000)} sn)`);
    };
    sock.on("close", close); pc.on("close", close);
    sock.on("error", close); pc.on("error", close);
    console.log(`[uzak] oturum: ${name} <- ${kimden || "?"}`);
    return true;
}

function attach(server, KEY) {
    server.on("upgrade", (req, sock, head) => {
        let u;
        try { u = new URL(req.url, "http://x"); } catch (e) { return sock.destroy(); }
        if (u.pathname !== "/uzak/baglan") return;          // başka yükseltmeler (yoksa) kendi yoluna
        if (("" + req.headers.upgrade).toLowerCase() !== "e6uzak") return reject(sock, 400, "Upgrade: e6uzak bekleniyor");
        const key = req.headers["x-api-key"] || u.searchParams.get("key") || "";
        if (!require("./anahtar.js").ok(key)) return reject(sock, 403, "Parola hatali");   // asil ya da ikinci parola
        sock.on("error", () => { });
        const rol = u.searchParams.get("rol");

        if (rol === "pc") {
            const name = cleanName(u.searchParams.get("ad")) || "PC";
            const old = waiting.get(name);
            if (old) { dropWaiter(name, old); try { old.sock.destroy(); } catch (e) { } }
            accept(sock);
            const w = { sock, lan: ("" + (u.searchParams.get("lan") || "")).slice(0, 120), since: Date.now(), ping: null };
            w.ping = setInterval(() => { try { sock.write(PING); } catch (e) { } }, 25000);
            waiting.set(name, w);
            // Beklerken PC'den gelen veri (olmamalı) yok sayılır
            const onData = () => { };
            sock.on("data", onData);
            w.onData = onData;
            sock.on("close", () => dropWaiter(name, w));
            console.log(`[uzak] PC bekliyor: ${name} ${w.lan}`);
            return;
        }

        if (rol === "tel") {
            let name = cleanName(u.searchParams.get("hedef"));
            // Sunucu tarayicisi: PC yerine sunucudaki basliksiz Chrome (tarayici.js)
            if (name === "tarayici") {
                accept(sock);
                require("./tarayici.js").baglan(sock, head, KEY);
                console.log(`[uzak] tarayici oturumu <- ${req.socket.remoteAddress || "?"}`);
                return;
            }
            if (!name && waiting.size === 1) name = waiting.keys().next().value;
            if (!name || !waiting.get(name)) return reject(sock, 404, "Bekleyen PC yok");
            accept(sock);
            pcBagla(sock, name, head, req.socket.remoteAddress);
            return;
        }
        reject(sock, 400, "rol=pc ya da rol=tel");
    });
}

const router = express.Router();
router.get("/uzak/liste", (req, res) => {
    const now = Date.now();
    const pcler = [];
    for (const [ad, w] of waiting) pcler.push({ ad, lan: w.lan, sure: Math.round((now - w.since) / 1000) });
    pcler.push({ ad: "tarayici", lan: "", sure: 0, tur: "tarayici" });     // her zaman hazir sunucu tarayicisi
    res.json({ pcler, aktif: active });
});

function pcListesi() { const now = Date.now(); const l = []; for (const [ad, w] of waiting) l.push({ ad, lan: w.lan, sure: Math.round((now - w.since) / 1000) }); return { pcler: l, aktif: active }; }
module.exports = { attach, router, pcBagla, pcListesi };
