import QtQuick 1.1
import "Ai.js" as Ai

Rectangle {
    id: app
    width: 640
    height: 480
    color: bg

    // ---- Tema (karanlik varsayilan, mor vurgu) ----
    property bool dark: true
    property color brand: dark ? "#9B87FF" : "#6E56CF"
    property color brandPressed: dark ? "#8470F0" : "#5B45B8"
    property color accentText: brand
    property color pill: dark ? "#2C2550" : "#ECE8FF"
    property color bg: dark ? "#111B21" : "#FFFFFF"
    property color surface: dark ? "#1F2C34" : "#F5F6F7"
    property color textPrimary: dark ? "#E9EDEF" : "#111B21"
    property color textSecondary: dark ? "#8696A0" : "#667781"
    property color divider: dark ? "#222D34" : "#E9EDEF"
    property color pressed: dark ? "#202C33" : "#E9EDEF"
    property color fieldBg: dark ? "#2A3942" : "#F0F2F5"
    property color danger: dark ? "#F15C6D" : "#D93025"
    property color placeholder: "#8696A0"
    property color userBubble: dark ? "#3B2F7A" : "#E3DDFF"
    property color aiBubble: dark ? "#1F2C34" : "#F0F2F5"
    property color codeBg: dark ? "#0B141A" : "#E4E7EA"
    property string iconTone: dark ? "_light" : "_gray"

    // ---- Sekmeler: 0 GPT, 1 Claude, 2 Gemini, 3 Grok, 4 Ayarlar ----
    property int tab: 1
    property variant providers: ["openai", "claude", "gemini", "grok"]
    property int settingsTab: 4
    property string modelOpenai: "gpt-5"
    property string modelClaude: "claude-opus-5-5"
    property string modelGemini: "gemini-flash-latest"
    property string modelGrok: "grok-4"

    function avatarUrl(id) { return ""; }   // Header/Avatar bileseni icin
    function showToast(msg) { toast.show(msg); }
    function ai() { return Ai; }
    function modelFor(p) { return p === "openai" ? modelOpenai : (p === "claude" ? modelClaude : (p === "gemini" ? modelGemini : modelGrok)); }
    function setModel(p, m) {
        if (p === "openai") modelOpenai = m; else if (p === "claude") modelClaude = m; else if (p === "gemini") modelGemini = m; else modelGrok = m;
        setSetting("model_" + p, m);
    }

    // ---- Kalici depo (LocalStorage / SQLite) ----
    function db() { return openDatabaseSync("E6AI", "1.0", qsTr("ApiLauncher sohbetleri ve ayarlari"), 5000000); }
    function initDb() {
        db().transaction(function (tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS kv(k TEXT UNIQUE, v TEXT)");
            tx.executeSql("CREATE TABLE IF NOT EXISTS convs(id INTEGER PRIMARY KEY AUTOINCREMENT, provider TEXT, title TEXT, model TEXT, updated INTEGER)");
            tx.executeSql("CREATE TABLE IF NOT EXISTS msgs(id INTEGER PRIMARY KEY AUTOINCREMENT, conv INTEGER, role TEXT, text TEXT, model TEXT, ms INTEGER, ts INTEGER)");
        });
        // 1.3: mesajlara resim yolu (gonderilen foto / olusturulan resim)
        try { db().transaction(function (tx) { tx.executeSql("ALTER TABLE msgs ADD COLUMN img TEXT"); }); } catch (e) { }
        db().transaction(function (tx) {
        });
        // 1.1: onceki surumde bos kaydedilmis sistem istemine bir kez varsayilani yaz
        if (setting("sysdef", "0") !== "1") {
            if (setting("system", "") === "") setSetting("system", defaultSystem);
            setSetting("sysdef", "1");
        }
    }
    // Bos ya da eski IP adresi (203.0.113.10) -> https://e6.msahincelen.xyz
    function sunucuTasi(s) { s = ("" + (s || "")).replace(/^\s+|\s+$/g, "").replace(/\/+$/, ""); return (s === "" || s.indexOf("203.0.113.10") >= 0) ? "https://e6.msahincelen.xyz" : s; }
    function setting(k, def) {
        var v = def;
        db().readTransaction(function (tx) {
            var rs = tx.executeSql("SELECT v FROM kv WHERE k = ?", [k]);
            if (rs.rows.length > 0) v = rs.rows.item(0).v;
        });
        if (k === "server") v = sunucuTasi(v);   // eski IP -> yeni adres
        return v;
    }
    function setSetting(k, v) {
        db().transaction(function (tx) { tx.executeSql("INSERT OR REPLACE INTO kv(k, v) VALUES(?, ?)", [k, "" + v]); });
    }
    function newConv(provider, title, model) {
        var id = 0;
        db().transaction(function (tx) {
            var r = tx.executeSql("INSERT INTO convs(provider, title, model, updated) VALUES(?, ?, ?, ?)", [provider, title, model, new Date().getTime()]);
            id = parseInt(r.insertId, 10);
        });
        return id;
    }
    function addMsg(conv, role, text, model, ms, img) {
        db().transaction(function (tx) {
            tx.executeSql("INSERT INTO msgs(conv, role, text, model, ms, ts, img) VALUES(?, ?, ?, ?, ?, ?, ?)", [conv, role, text, model, ms, new Date().getTime(), img || ""]);
            tx.executeSql("UPDATE convs SET updated = ? WHERE id = ?", [new Date().getTime(), conv]);
        });
    }
    function loadMsgs(conv) {
        var out = [];
        db().readTransaction(function (tx) {
            var rs = tx.executeSql("SELECT role, text, model, ms, img FROM msgs WHERE conv = ? ORDER BY id", [conv]);
            for (var i = 0; i < rs.rows.length; i++) out.push(rs.rows.item(i));
        });
        return out;
    }
    function listConvs(provider) {
        var out = [];
        db().readTransaction(function (tx) {
            var rs = tx.executeSql("SELECT c.id, c.title, c.model, c.updated, (SELECT COUNT(*) FROM msgs m WHERE m.conv = c.id) AS n FROM convs c WHERE c.provider = ? ORDER BY c.updated DESC LIMIT 200", [provider]);
            for (var i = 0; i < rs.rows.length; i++) out.push(rs.rows.item(i));
        });
        return out;
    }
    function deleteConv(id) {
        db().transaction(function (tx) {
            tx.executeSql("DELETE FROM msgs WHERE conv = ?", [id]);
            tx.executeSql("DELETE FROM convs WHERE id = ?", [id]);
        });
    }

    function applyConfig() {
        Ai.cfg.mode = setting("mode", "direct");
        Ai.cfg.server = setting("server", "") || "https://e6.msahincelen.xyz";   // eski hata bos kaydetmis olabilir
        Ai.cfg.lang = dil.kod;   // sunucu hata mesajlari uygulamanin dilinde (X-Lang)
        Ai.cfg.serverKey = setting("serverKey", "");
        Ai.cfg.keys = { openai: setting("key_openai", ""), claude: setting("key_claude", ""), gemini: setting("key_gemini", ""), grok: setting("key_grok", "") };
        Ai.cfg.imgModels = { openai: setting("img_openai", Ai.IMG_DEFAULTS.openai), gemini: setting("img_gemini", Ai.IMG_DEFAULTS.gemini), grok: setting("img_grok", Ai.IMG_DEFAULTS.grok) };
        Ai.cfg.system = setting("system", defaultSystem);
        Ai.onLog = function (s) { yardim.log(s); };
        Ai.yardim = yardim;
    }
    // Ayarlarda sistem istemi hic kaydedilmemisse kullanilir
    property string defaultSystem: qsTr("Kısa ve net yanıt ver. Giriş cümlesi, tekrar ve gereksiz açıklama yapma; gerekiyorsa maddeler halinde yaz. Soruyu hangi dilde sorarsam o dilde yanıtla.")

    Component.onCompleted: {
        initDb();
        dark = setting("dark", "1") === "1";
        modelOpenai = setting("model_openai", "gpt-5");
        modelClaude = setting("model_claude", "claude-opus-5-5");
        modelGemini = setting("model_gemini", "gemini-flash-latest");
        modelGrok = setting("model_grok", "grok-4");
        applyConfig();
        var anyKey = Ai.cfg.keys.openai !== "" || Ai.cfg.keys.claude !== "" || Ai.cfg.keys.gemini !== "" || Ai.cfg.keys.grok !== "" || Ai.cfg.mode === "relay";
        tab = anyKey ? parseInt(setting("tab", "1"), 10) : 4;
        if (tab > 4 || tab < 0) tab = 1;
        if (tab === 4) settingsPage.forceActiveFocus();
        yardim.log("sekme " + tab);
    }

    function selectTab(i) {
        tab = i;
        setSetting("tab", i);
        if (i < 4) chatAt(i).focusInput();
        else settingsPage.forceActiveFocus();
    }
    // Sol/sag yon tuslari: alt sekmeler arasinda dolas (GPT, Claude, Gemini, Grok, Ayarlar)
    function stepTab(d) { selectTab((tab + d + 5) % 5); }
    function chatAt(i) { return i === 0 ? gptView : (i === 1 ? claudeView : (i === 2 ? geminiView : grokView)); }

    Item {
        anchors.fill: parent
        ChatView {
            id: gptView
            provider: "openai"; label: "GPT"; badge: "nav_gpt_on"
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: nav.top }
            visible: app.tab === 0
        }
        ChatView {
            id: claudeView
            provider: "claude"; label: qsTr("Claude"); badge: "nav_claude_on"
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: nav.top }
            visible: app.tab === 1
        }
        ChatView {
            id: geminiView
            provider: "gemini"; label: qsTr("Gemini"); badge: "nav_gemini_on"
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: nav.top }
            visible: app.tab === 2
        }
        ChatView {
            id: grokView
            provider: "grok"; label: qsTr("Grok"); badge: "nav_grok_on"
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: nav.top }
            visible: app.tab === 3
        }
        SettingsPage {
            id: settingsPage
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: nav.top }
            visible: app.tab === 4
        }
        BottomNav {
            id: nav
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            current: app.tab
            onSelected: app.selectTab(index)
        }
    }

    // Kopyalama icin gizli metin kutusu (QML 1'de pano API'si yok)
    TextEdit { id: clip; visible: false }
    function copyText(t) {
        clip.text = t;
        clip.selectAll();
        clip.copy();
        showToast(qsTr("Kopyalandı"));
    }

    Toast { id: toast }
}
