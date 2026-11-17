const sqlite3 = require('sqlite3');
const { open } = require('sqlite');
const fs = require("fs");
const path = require("path");

let db;

async function initializeDatabase() {
    const dataPath = path.join(__dirname, "data");
    if (!fs.existsSync(dataPath)) fs.mkdirSync(dataPath);

    db = await open({
        filename: path.join(dataPath, "whatse6.db"),
        driver: sqlite3.Database
    });
    console.log("Veritabani baglandi.");

    // Tek tablo: her satir bir mesaj (gelen veya giden).
    //   owner  : oturum sahibinin numarasi (ornek 905321234567)
    //   peer   : karsi taraf / grup kimligi (ornek 905xx@c.us, 1203xx@g.us, 12345@lid)
    //   from_me: 1 = giden, 0 = gelen
    await db.exec(`CREATE TABLE IF NOT EXISTS msgs (
        _id INTEGER PRIMARY KEY AUTOINCREMENT,
        owner TEXT NOT NULL,
        peer TEXT NOT NULL,
        peer_name TEXT NOT NULL DEFAULT '',
        from_me INTEGER NOT NULL DEFAULT 0,
        sender_name TEXT NOT NULL DEFAULT '',
        message TEXT NOT NULL DEFAULT '',
        chat_type TEXT NOT NULL DEFAULT 'chat',
        wa_id TEXT UNIQUE,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
    )`);
    await db.exec(`CREATE INDEX IF NOT EXISTS idx_msgs_owner_peer ON msgs(owner, peer, _id)`);
    console.log("Tablolar hazir.");
}

module.exports = {
    db: () => db,
    initializeDatabase
};
