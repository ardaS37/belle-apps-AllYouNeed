import QtQuick 1.1
import "Util.js" as U
import "Convert.js" as C

// Metin duzenleyici / goruntuleyici.
// Kisayollar (Ctrl ile): S kaydet • F bul • N sonrakini bul • H bul-degistir • G satira git
//   Z geri al • Y yinele • A tumunu sec • C/X/V kopyala/kes/yapistir • B tum yaziyi panoya
//   D satiri cogalt • K satiri sil • T tarih-saat • E uzanti/donustur • P sistemde ac / onizle
//   R salt okunur ac/kapa • W satir kaydirma • + / - yazi boyutu • L istatistik • U buyuk harf
//   J yapilacak isareti [ ] / [x] • Yukari/Asagi en basa / sona • Q kapat
// Orta tus ya da sol yazilim tusu: menu. Esc / sag yazilim tusu: kapat.
// Salt okunur kipte harfler: Bosluk/J sayfa asagi, Z/K sayfa yukari, N/P buyuk dosyada sonraki/onceki parca.
Rectangle {
    id: root
    color: app.editorBg

    property string path: ""
    property string encoding: "UTF-8"
    property string eol: "crlf"
    property bool bom: false
    property bool dirty: false
    property bool readOnly: false
    property bool loading: false
    property bool binary: false
    // Buyuk dosya: parcali goruntuleme
    property bool chunked: false
    property real chunkOffset: 0
    property real chunkNext: 0
    property real fileSize: 0
    property int chunkSize: 48 * 1024
    property int line: 1
    property int col: 1
    property string lastFind: ""
    property string lastReplace: ""
    property bool caseSensitive: false

    function takeFocus() { edit.forceActiveFocus(); }
    function title() { return path === "" ? qsTr("Adsız") : fs.fileName(path); }

    // ---- Acma ----
    function open(p, ro, enc) {
        var info = fs.info(p);
        var big = info.size > app.bigFileKB * 1024;
        path = p;
        readOnly = ro || big || info.readOnly;
        chunked = big;
        loading = true;
        if (big) {
            fileSize = info.size;
            loadChunk(0, enc || app.defaultEncoding);
            app.showToast(qsTr("Büyük dosya (") + U.sizeText(info.size) + qsTr("): salt okunur, parça parça • N/P"));
        } else {
            var r = fs.readText(p, enc || app.defaultEncoding);
            if (!r.ok) { app.showToast(qsTr("Açılamadı: ") + r.error); loading = false; path = ""; return false; }
            encoding = r.encoding;
            eol = r.eol || app.newEol;
            bom = r.bom;
            binary = r.binary;
            edit.text = r.text;
            if (r.binary) { readOnly = true; app.showToast(qsTr("Metin olmayan dosya: salt okunur açıldı")); }
            var pos = app.recentPos(p);
            edit.cursorPosition = Math.min(pos, edit.text.length);
        }
        dirty = false;
        loading = false;
        flick.contentY = 0;
        flick.contentX = 0;
        flick.ensureVisible(edit.cursorRectangle);
        app.addRecent(p, edit.cursorPosition);
        fs.log("ac " + p + " " + encoding + (readOnly ? " ro" : ""));
        posTimer.restart();
        return true;
    }
    function openText(p, text) {
        path = p;
        readOnly = false; chunked = false; binary = false;
        encoding = "UTF-8"; eol = app.newEol; bom = false;
        loading = true;
        edit.text = text;
        loading = false;
        dirty = false;
    }
    function setText(t) {
        edit.text = t;
        dirty = true;
    }
    function loadChunk(offset, enc) {
        var r = fs.readPart(path, offset, chunkSize, enc || encoding);
        if (!r.ok) { app.showToast(qsTr("Okunamadı: ") + r.error); return; }
        loading = true;
        encoding = r.encoding;
        chunkOffset = r.offset;
        chunkNext = r.next;
        fileSize = r.size;
        edit.text = r.text;
        edit.cursorPosition = 0;
        flick.contentY = 0;
        loading = false;
    }
    function nextChunk() { if (chunked && chunkNext < fileSize) loadChunk(chunkNext, encoding); }
    function prevChunk() { if (chunked && chunkOffset > 0) loadChunk(Math.max(0, chunkOffset - chunkSize), encoding); }
    function cursorToEnd() { edit.cursorPosition = edit.text.length; }

    // ---- Kaydetme ----
    function save(cb) {
        if (readOnly) { app.showToast(qsTr("Salt okunur (Ctrl+R ile düzenlemeye aç)")); return false; }
        if (path === "") { saveAs(cb); return false; }
        var w = fs.writeText(path, edit.text, encoding, eol, bom, app.makeBackup);
        if (!w.ok) { app.showToast(qsTr("Kaydedilemedi: ") + w.error); return false; }
        dirty = false;
        fs.removePath(fs.draftPath());
        app.addRecent(path, edit.cursorPosition);
        app.showToast(qsTr("Kaydedildi") + (w.lost > 0 ? " • " + w.lost + qsTr(" karakter ") + encoding + qsTr(" kodlamasında yok (? oldu)") : ""));
        app.refreshAll();
        app.notKaydedildi(path);
        if (cb) cb();
        return true;
    }
    // Drive yedegi: degisiklik varsa once kaydeder, sonra Drive > Belle Files Yedek klasorune (ayni adliyi gunceller)
    function yedekle() {
        if (root.chunked && root.dirty) { app.showToast(qsTr("Önce kaydedin")); return; }
        if (root.path === "" || (root.dirty && !root.readOnly)) { root.save(function () { app.notYedekle(root.path); }); return; }
        app.notYedekle(root.path);
    }
    function saveAs(cb) {
        var dir = path === "" ? fs.notesDir() : fs.folderOf(path);
        var name = path === "" ? qsTr("Not ") + fs.now("yyyy-MM-dd HH.mm") + ".txt" : fs.fileName(path);
        input.open({ title: qsTr("Farklı kaydet"), label1: qsTr("Klasör"), text1: dir, label2: qsTr("Dosya adı"), text2: name, ok: qsTr("Kaydet") }, function (d, n) {
            if (!fs.validName(n)) { app.showToast(qsTr("Geçersiz ad")); return; }
            var p = fs.join(d, n);
            var go = function () {
                root.path = p;
                root.readOnly = false;
                root.chunked = false;
                root.save(cb);
            };
            if (fs.exists(p) && p !== root.path) {
                sheet.open(n + qsTr(" zaten var"), [
                    { label: qsTr("Üzerine yaz"), icon: "save", key: "y", danger: true },
                    { label: qsTr("Vazgeç"), icon: "close", key: "n" }
                ], function (k) { if (k === "y") go(); });
            } else go();
        });
    }
    function close() {
        if (dirty) { askClose(function () { root.doClose(); }); return; }
        doClose();
    }
    function askClose(after) {
        sheet.open(qsTr("Değişiklikler kaydedilsin mi? ") + title(), [
            { label: qsTr("Kaydet"), icon: "save", key: "save" },
            { label: qsTr("Kaydetmeden çık"), icon: "trash", key: "drop", danger: true },
            { label: qsTr("Vazgeç"), icon: "back", key: "no" }
        ], function (k) {
            if (k === "save") root.save(after);
            else if (k === "drop") { root.dirty = false; fs.removePath(fs.draftPath()); after(); }
        });
    }
    function doClose() {
        if (path !== "" && !chunked) app.addRecent(path, edit.cursorPosition);
        loading = true;
        edit.text = "";
        loading = false;
        dirty = false;
        path = "";
        app.editorOpen = false;
        app.focusCurrent();
    }

    // ---- Bul / degistir ----
    function norm(s) { return caseSensitive ? s : U.fold(s); }
    function findText(q, from) {
        if (!q) return false;
        lastFind = q;
        var t = norm(edit.text), nq = norm(q);
        var i = t.indexOf(nq, from);
        if (i < 0 && from > 0) { i = t.indexOf(nq, 0); if (i >= 0) app.showToast(qsTr("Başa dönüldü")); }
        if (i < 0) {
            if (chunked && chunkNext < fileSize) { app.showToast(qsTr("Bu parçada yok • N: sonraki parça")); }
            else app.showToast(qsTr("Bulunamadı: ") + q);
            return false;
        }
        edit.select(i, i + q.length);
        flick.ensureVisible(edit.positionToRectangle(i));
        return true;
    }
    function findNext() {
        if (!lastFind) { askFind(); return; }
        findText(lastFind, edit.selectionEnd > edit.selectionStart ? edit.selectionEnd : edit.cursorPosition);
    }
    function askFind() {
        var sel = edit.selectedText;
        input.open({ title: qsTr("Bul"), label1: caseSensitive ? qsTr("Büyük/küçük harf duyarlı") : qsTr("Büyük/küçük harf ve Türkçe harf fark etmez"), text1: sel && sel.indexOf("\n") < 0 ? sel : lastFind, ok: qsTr("Bul") }, function (q) {
            root.findText(q, edit.cursorPosition);
        });
    }
    function askReplace() {
        if (readOnly) { app.showToast(qsTr("Salt okunur")); return; }
        input.open({ title: qsTr("Bul ve değiştir"), label1: qsTr("Aranan"), text1: edit.selectedText || lastFind, label2: qsTr("Yerine"), text2: lastReplace, ok: qsTr("Devam") }, function (a, b) {
            if (!a) return;
            root.lastFind = a;
            root.lastReplace = b;
            var t = root.norm(edit.text), na = root.norm(a), n = 0, i = 0;
            while ((i = t.indexOf(na, i)) >= 0) { n++; i += na.length; }
            if (n === 0) { app.showToast(qsTr("Bulunamadı: ") + a); return; }
            sheet.open(n + qsTr(" eşleşme • \"") + a + "\" → \"" + b + "\"", [
                { label: qsTr("Tümünü değiştir"), icon: "swap", key: "all" },
                { label: qsTr("Sıradakini değiştir"), icon: "edit", key: "one" },
                { label: qsTr("Vazgeç"), icon: "close", key: "no" }
            ], function (k) {
                if (k === "all") root.replaceAll(a, b);
                else if (k === "one") root.replaceOne(a, b);
            });
        });
    }
    function replaceAll(a, b) {
        var src = edit.text, t = norm(src), na = norm(a), out = "", last = 0, i, n = 0;
        while ((i = t.indexOf(na, last)) >= 0) { out += src.substring(last, i) + b; last = i + a.length; n++; }
        out += src.substring(last);
        var pos = edit.cursorPosition;
        edit.text = out;
        edit.cursorPosition = Math.min(pos, out.length);
        app.showToast(n + qsTr(" yer değiştirildi"));
    }
    function replaceOne(a, b) {
        var s = edit.selectionStart, e = edit.selectionEnd;
        if (e > s && norm(edit.selectedText) === norm(a)) {
            edit.text = edit.text.substring(0, s) + b + edit.text.substring(e);
            edit.cursorPosition = s + b.length;
        }
        if (findText(a, edit.cursorPosition)) app.showToast(qsTr("Tekrar değiştirmek için Ctrl+H > Sıradakini değiştir"));
    }
    function askGoto() {
        var total = edit.text.split("\n").length;
        input.open({ title: qsTr("Satıra git"), label1: "1 - " + total, text1: "" + line, ok: qsTr("Git") }, function (v) {
            var n = parseInt(v, 10);
            if (isNaN(n)) return;
            root.gotoLine(n);
        });
    }
    function gotoLine(n) {
        var t = edit.text, pos = 0;
        for (var i = 1; i < n; i++) {
            var j = t.indexOf("\n", pos);
            if (j < 0) break;
            pos = j + 1;
        }
        edit.cursorPosition = pos;
        flick.ensureVisible(edit.cursorRectangle);
    }

    // ---- Satir islemleri ----
    function lineBounds() {
        var t = edit.text, p = edit.cursorPosition;
        var s = t.lastIndexOf("\n", p - 1) + 1;
        var e = t.indexOf("\n", p);
        if (e < 0) e = t.length;
        return { s: s, e: e };
    }
    function duplicateLine() {
        var b = lineBounds(), t = edit.text, l = t.substring(b.s, b.e), col = edit.cursorPosition - b.s;
        edit.text = t.substring(0, b.e) + "\n" + l + t.substring(b.e);
        edit.cursorPosition = b.e + 1 + col;
    }
    function deleteLine() {
        var b = lineBounds(), t = edit.text;
        var e = b.e < t.length ? b.e + 1 : b.e, s = b.s;
        if (e === t.length && s > 0 && b.e === t.length) s = s - 1;
        fs.setClipboardText(t.substring(b.s, b.e));
        edit.text = t.substring(0, s) + t.substring(e);
        edit.cursorPosition = Math.min(s, edit.text.length);
    }
    function toggleTodoLine() {
        var b = lineBounds(), t = edit.text;
        var nl = C.toggleTodo(t.substring(b.s, b.e));
        edit.text = t.substring(0, b.s) + nl + t.substring(b.e);
        edit.cursorPosition = b.s + nl.length;
    }
    function insertText(s) {
        if (readOnly) return;
        var a = edit.selectionStart, b = edit.selectionEnd, t = edit.text;
        edit.text = t.substring(0, a) + s + t.substring(b);
        edit.cursorPosition = a + s.length;
    }
    // Secim varsa secime, yoksa tum metne uygula
    function transform(fn, label) {
        if (readOnly) { app.showToast(qsTr("Salt okunur")); return; }
        var a = edit.selectionStart, b = edit.selectionEnd, t = edit.text;
        if (b > a) {
            var r = fn(t.substring(a, b));
            edit.text = t.substring(0, a) + r + t.substring(b);
            edit.select(a, a + r.length);
        } else {
            var pos = edit.cursorPosition;
            edit.text = fn(t);
            edit.cursorPosition = Math.min(pos, edit.text.length);
        }
        app.showToast(label + (b > a ? qsTr(" (seçime)") : qsTr(" (tüm metne)")));
    }
    function toolsMenu() {
        sheet.open(qsTr("Metin araçları") + (edit.selectedText ? qsTr(" • seçime uygulanır") : qsTr(" • tüm metne uygulanır")), [
            { label: qsTr("BÜYÜK HARF"), icon: "font", key: "up", hint: qsTr("Ctrl+U") },
            { label: qsTr("küçük harf"), icon: "font", key: "low" },
            { label: qsTr("Kelime Başları Büyük"), icon: "font", key: "title" },
            { label: qsTr("Satırları sırala (A→Z)"), icon: "sort", key: "sort" },
            { label: qsTr("Satırları sırala (Z→A)"), icon: "sort", key: "sortd" },
            { label: qsTr("Tekrarlanan satırları kaldır"), icon: "lines", key: "uniq" },
            { label: qsTr("Boş satırları sil"), icon: "lines", key: "blank" },
            { label: qsTr("Satır sonu boşluklarını sil"), icon: "lines", key: "trim" },
            { label: qsTr("Satırları numarala"), icon: "lines", key: "num" },
            { label: qsTr("Satırları ters çevir"), icon: "swap", key: "rev" },
            { label: qsTr("Satırları birleştir"), icon: "wrap", key: "join" },
            { label: qsTr("HTML etiketlerini temizle"), icon: "code", key: "strip" },
            { label: qsTr("Yapılacak işareti [ ] / [x]"), icon: "check", key: "todo", hint: qsTr("Ctrl+J") }
        ], function (k) {
            if (k === "up") root.transform(U.upperTr, qsTr("Büyük harf"));
            else if (k === "low") root.transform(U.lowerTr, qsTr("Küçük harf"));
            else if (k === "title") root.transform(U.titleTr, qsTr("Kelime başları"));
            else if (k === "sort") root.transform(function (s) { return C.sortLines(s, false); }, qsTr("Sıralandı"));
            else if (k === "sortd") root.transform(function (s) { return C.sortLines(s, true); }, qsTr("Sıralandı"));
            else if (k === "uniq") root.transform(C.uniqLines, qsTr("Tekrarlar kaldırıldı"));
            else if (k === "blank") root.transform(C.removeBlank, qsTr("Boş satırlar silindi"));
            else if (k === "trim") root.transform(C.trimLines, qsTr("Boşluklar silindi"));
            else if (k === "num") root.transform(C.numberLines, qsTr("Numaralandı"));
            else if (k === "rev") root.transform(C.reverseLines, qsTr("Ters çevrildi"));
            else if (k === "join") root.transform(C.joinLines, qsTr("Birleştirildi"));
            else if (k === "strip") root.transform(C.htmlToText, qsTr("Etiketler temizlendi"));
            else if (k === "todo") root.toggleTodoLine();
        });
    }

    // ---- Kodlama / satir sonu ----
    function encodingMenu() {
        var encs = ["UTF-8", "windows-1254", "ISO-8859-9", "ISO-8859-1", "UTF-16LE", "UTF-16BE"];
        var items = [];
        for (var i = 0; i < encs.length; i++)
            items.push({ label: (encs[i] === encoding ? "● " : "") + U.encodingLabel(encs[i]), icon: "font", key: encs[i] });
        items.push({ label: (bom ? "● " : "") + qsTr("BOM (bayt sırası işareti) ekle"), icon: "check", key: "bom" });
        items.push({ label: qsTr("Satır sonu: ") + U.eolLabel(eol), icon: "wrap", key: "eol" });
        sheet.open(qsTr("Kodlama • şu an ") + U.encodingLabel(encoding), items, function (k) {
            if (k === "bom") { root.bom = !root.bom; root.dirty = true; app.showToast(root.bom ? qsTr("BOM eklenecek") : qsTr("BOM eklenmeyecek")); return; }
            if (k === "eol") { root.eolMenu(); return; }
            sheet.open(U.encodingLabel(k), [
                { label: qsTr("Bu kodlamayla yeniden aç (yazı bozuksa)"), icon: "undo", key: "reopen" },
                { label: qsTr("Kaydederken bu kodlamayı kullan"), icon: "save", key: "saveas" }
            ], function (kk) {
                if (kk === "reopen") {
                    if (root.path === "") return;
                    if (root.dirty) { app.showToast(qsTr("Önce kaydedin ya da değişiklikleri atın")); return; }
                    root.open(root.path, root.readOnly, k);
                    app.showToast(qsTr("Yeniden açıldı: ") + U.encodingLabel(k));
                } else { root.encoding = k; root.dirty = true; app.showToast(qsTr("Kaydedince ") + U.encodingLabel(k) + qsTr(" olacak")); }
            });
        });
    }
    function eolMenu() {
        sheet.open(qsTr("Satır sonu"), [
            { label: qsTr("CRLF (Windows, Nokia)"), icon: "wrap", key: "crlf" },
            { label: qsTr("LF (Unix, Linux, Android)"), icon: "wrap", key: "lf" },
            { label: qsTr("CR (eski Mac)"), icon: "wrap", key: "cr" }
        ], function (k) { root.eol = k; root.dirty = true; app.showToast(qsTr("Satır sonu: ") + U.eolLabel(k)); });
    }

    function stats() {
        var t = edit.selectedText || edit.text;
        var s = U.stats(t);
        sheet.open((edit.selectedText ? qsTr("Seçim") : title()) + qsTr(" istatistiği"), [
            { label: s.lines + qsTr(" satır"), icon: "lines", key: "x" },
            { label: s.words + qsTr(" kelime"), icon: "doc", key: "x" },
            { label: s.chars + qsTr(" karakter (") + s.nospace + qsTr(" boşluksuz)"), icon: "font", key: "x" },
            { label: qsTr("Kodlama: ") + U.encodingLabel(encoding) + (bom ? qsTr(" + BOM") : ""), icon: "font", key: "x" },
            { label: qsTr("Satır sonu: ") + U.eolLabel(eol), icon: "wrap", key: "x" },
            { label: qsTr("İmleç: satır ") + line + qsTr(", sütun ") + col, icon: "info", key: "x" }
        ], function () { });
    }
    function setFont(d) {
        app.fontSize = Math.max(12, Math.min(36, app.fontSize + d));
        app.setSetting("fontSize", app.fontSize);
        app.showToast(qsTr("Yazı boyutu: ") + app.fontSize);
    }
    function toggleWrap() {
        app.wrap = !app.wrap;
        app.setSetting("wrap", app.wrap ? "1" : "0");
        app.showToast(app.wrap ? qsTr("Satır kaydırma açık") : qsTr("Satır kaydırma kapalı"));
    }
    function toggleReadOnly() {
        if (chunked) { app.showToast(qsTr("Büyük dosya parça parça açıldığı için düzenlenemez")); return; }
        if (binary) { app.showToast(qsTr("Metin olmayan dosya düzenlenemez")); return; }
        readOnly = !readOnly;
        app.showToast(readOnly ? qsTr("Salt okunur") : qsTr("Düzenleme açık"));
    }
    function preview() {
        if (path === "") { app.showToast(qsTr("Önce kaydedin")); return; }
        var go = function () { app.openExternal(root.path); };
        if (dirty) save(go); else go();
    }
    function convert() {
        if (path === "") { app.showToast(qsTr("Önce kaydedin")); return; }
        var go = function () { app.extensionMenu(root.path); };
        if (dirty) save(go); else go();
    }
    function undo() { edit.forceActiveFocus(); fs.sendKey(Qt.Key_Z, Qt.ControlModifier); }
    function redo() { edit.forceActiveFocus(); fs.sendKey(Qt.Key_Y, Qt.ControlModifier); }
    function copyAll() { fs.setClipboardText(edit.text); app.showToast(qsTr("Tüm yazı panoda (") + edit.text.length + qsTr(" karakter)")); }

    function menu() {
        var items = [];
        if (!readOnly) items.push({ label: qsTr("Kaydet"), icon: "save", key: "save", hint: qsTr("Ctrl+S") });
        items.push({ label: qsTr("Farklı kaydet…"), icon: "save", key: "saveas" });
        items.push({ label: qsTr("Bul"), icon: "search", key: "find", hint: qsTr("Ctrl+F") });
        if (lastFind) items.push({ label: qsTr("Sonrakini bul: ") + lastFind, icon: "search", key: "next", hint: qsTr("Ctrl+N") });
        if (!readOnly) items.push({ label: qsTr("Bul ve değiştir"), icon: "swap", key: "repl", hint: qsTr("Ctrl+H") });
        items.push({ label: qsTr("Satıra git"), icon: "lines", key: "goto", hint: qsTr("Ctrl+G") });
        if (!readOnly) {
            items.push({ label: qsTr("Geri al"), icon: "undo", key: "undo", hint: qsTr("Ctrl+Z") });
            items.push({ label: qsTr("Yinele"), icon: "redo", key: "redo", hint: qsTr("Ctrl+Y") });
        }
        if (edit.selectedText) {
            items.push({ label: qsTr("Seçimi kopyala"), icon: "copy", key: "copy", hint: qsTr("Ctrl+C") });
            if (!readOnly) items.push({ label: qsTr("Seçimi kes"), icon: "cut", key: "cut", hint: qsTr("Ctrl+X") });
        }
        if (!readOnly) items.push({ label: qsTr("Yapıştır"), icon: "paste", key: "paste", hint: qsTr("Ctrl+V") });
        items.push({ label: qsTr("Tümünü seç"), icon: "mark", key: "selall", hint: qsTr("Ctrl+A") });
        items.push({ label: qsTr("Tüm yazıyı panoya kopyala"), icon: "copy", key: "copyall", hint: qsTr("Ctrl+B") });
        if (!readOnly) {
            items.push({ label: qsTr("Tarih / saat ekle"), icon: "clock", key: "date", hint: qsTr("Ctrl+T") });
            items.push({ label: qsTr("Satırı çoğalt"), icon: "copy", key: "dup", hint: qsTr("Ctrl+D") });
            items.push({ label: qsTr("Satırı sil (panoya)"), icon: "trash", key: "dell", hint: qsTr("Ctrl+K") });
            items.push({ label: qsTr("Metin araçları…"), icon: "lines", key: "tools" });
        }
        items.push({ label: qsTr("Uzantı / dönüştür…"), icon: "swap", key: "conv", hint: qsTr("Ctrl+E") });
        items.push({ label: qsTr("Sistemde aç / önizle"), icon: "globe", key: "prev", hint: qsTr("Ctrl+P") });
        items.push({ label: qsTr("Kodlama ve satır sonu…"), icon: "font", key: "enc" });
        items.push({ label: readOnly ? qsTr("Düzenlemeye aç") : qsTr("Salt okunur yap"), icon: readOnly ? "edit" : "eye", key: "ro", hint: qsTr("Ctrl+R") });
        items.push({ label: app.wrap ? qsTr("Satır kaydırmayı kapat") : qsTr("Satır kaydırmayı aç"), icon: "wrap", key: "wrap", hint: qsTr("Ctrl+W") });
        items.push({ label: qsTr("Yazıyı büyüt"), icon: "plus", key: "fbig", hint: qsTr("Ctrl++") });
        items.push({ label: qsTr("Yazıyı küçült"), icon: "font", key: "fsmall", hint: qsTr("Ctrl+-") });
        items.push({ label: qsTr("İstatistik"), icon: "info", key: "stats", hint: qsTr("Ctrl+L") });
        if (path !== "") {
            items.push({ label: app.isFav(path) ? qsTr("Favoriden çıkar") : qsTr("Favorilere ekle"), icon: "star", key: "fav" });
            items.push({ label: qsTr("Klasöründe göster"), icon: "folder", key: "show" });
        }
        items.push({ label: qsTr("Kısayollar"), icon: "help", key: "help" });
        items.push({ label: qsTr("Kapat"), icon: "close", key: "close", hint: qsTr("Esc") });
        sheet.open(title() + (dirty ? " •" : ""), items, function (k) {
            if (k === "save") root.save();
            else if (k === "saveas") root.saveAs();
            else if (k === "find") root.askFind();
            else if (k === "next") root.findNext();
            else if (k === "repl") root.askReplace();
            else if (k === "goto") root.askGoto();
            else if (k === "undo") root.undo();
            else if (k === "redo") root.redo();
            else if (k === "copy") { edit.copy(); app.showToast(qsTr("Kopyalandı")); }
            else if (k === "cut") edit.cut();
            else if (k === "paste") pano.yapistir(edit);
            else if (k === "selall") edit.selectAll();
            else if (k === "copyall") root.copyAll();
            else if (k === "date") root.insertText(fs.now("dd.MM.yyyy HH:mm"));
            else if (k === "dup") root.duplicateLine();
            else if (k === "dell") root.deleteLine();
            else if (k === "tools") root.toolsMenu();
            else if (k === "conv") root.convert();
            else if (k === "prev") root.preview();
            else if (k === "enc") root.encodingMenu();
            else if (k === "ro") root.toggleReadOnly();
            else if (k === "wrap") root.toggleWrap();
            else if (k === "fbig") root.setFont(2);
            else if (k === "fsmall") root.setFont(-2);
            else if (k === "stats") root.stats();
            else if (k === "fav") app.toggleFav(root.path);
            else if (k === "show") { var p = root.path; root.close(); app.showFolder(fs.folderOf(p), p); }
            else if (k === "help") help.open();
            else if (k === "close") root.close();
        });
    }

    // ---- Zamanlayicilar ----
    Timer {
        id: posTimer
        interval: 350
        onTriggered: {
            var t = edit.text, p = edit.cursorPosition, n = 1, i = -1, last = -1;
            while ((i = t.indexOf("\n", i + 1)) >= 0 && i < p) { n++; last = i; }
            root.line = n;
            root.col = p - last;
        }
    }
    Timer {
        id: draftTimer
        interval: 4000
        onTriggered: if (root.dirty && app.draftGuard && !root.readOnly) fs.writeText(fs.draftPath(), root.path + "\n" + edit.text, "UTF-8", "lf", false, false)
    }
    Timer {
        id: autoTimer
        interval: 30000
        onTriggered: if (root.dirty && app.autoSave && root.path !== "" && !root.readOnly) root.save()
    }

    // ---- Ust cubuk ----
    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 46
        showBack: true
        title: (root.dirty ? "• " : "") + root.title()
        subtitle: (root.readOnly ? qsTr("salt okunur  ") : "") + (root.path === "" ? "" : fs.folderOf(root.path))
        onBack: root.close()
        IconButton { visible: root.chunked && root.chunkOffset > 0; icon: "up"; tone: "w"; iconSize: 22; onClicked: root.prevChunk() }
        IconButton { visible: root.chunked && root.chunkNext < root.fileSize; icon: "back"; tone: "w"; iconSize: 22; rotation: 270; onClicked: root.nextChunk() }
        IconButton { icon: "yukle"; tone: "a"; iconSize: 28; onClicked: root.yedekle() }      // Drive'a yedekle
        IconButton { visible: !root.readOnly; icon: "save"; tone: root.dirty ? "a" : "g"; iconSize: 24; onClicked: root.save() }
        IconButton { icon: "search"; tone: "w"; iconSize: 22; onClicked: root.askFind() }
        IconButton { icon: "more"; tone: "w"; iconSize: 24; onClicked: root.menu() }
    }

    // ---- Duzenleme alani ----
    Flickable {
        id: flick
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: status.top }
        clip: true
        contentWidth: app.wrap ? width : Math.max(width, edit.paintedWidth + 24)
        contentHeight: Math.max(height, edit.paintedHeight + 24)
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: app.wrap ? Flickable.VerticalFlick : Flickable.HorizontalAndVerticalFlick

        function ensureVisible(r) {
            var m = 8;
            if (contentX >= r.x - m) contentX = Math.max(0, r.x - m);
            else if (contentX + width <= r.x + r.width + m + 12) contentX = r.x + r.width + m + 12 - width;
            if (contentY >= r.y - m) contentY = Math.max(0, r.y - m);
            else if (contentY + height <= r.y + r.height + m) contentY = r.y + r.height + m - height;
        }

        TextEdit {
            id: edit
            x: 10
            y: 8
            width: app.wrap ? flick.width - 20 : 4000
            wrapMode: app.wrap ? TextEdit.Wrap : TextEdit.NoWrap
            textFormat: TextEdit.PlainText
            font.pixelSize: app.fontSize
            font.family: "Nokia Sans"
            color: app.textPrimary
            selectionColor: app.brand
            selectedTextColor: "#0B1A22"
            selectByMouse: !root.readOnly
            persistentSelection: true
            readOnly: root.readOnly
            cursorVisible: activeFocus
            focus: true
            onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
            onCursorPositionChanged: posTimer.restart()
            onTextChanged: {
                if (root.loading) return;
                root.dirty = true;
                draftTimer.restart();
                if (!autoTimer.running) autoTimer.start();
                posTimer.restart();
            }

            Keys.onPressed: {
                var k = event.key, ctrl = U.ctrl(event), shift = (event.modifiers & Qt.ShiftModifier) !== 0;
                if (k === Qt.Key_Select || k === Qt.Key_Context1 || k === Qt.Key_Menu) { root.menu(); event.accepted = true; return; }
                if (k === Qt.Key_Escape || k === Qt.Key_Context2) { root.close(); event.accepted = true; return; }
                if (ctrl) {
                    // E6: Ctrl+harf denetim karakteri / kucuk harf kodu olarak gelebilir -> Qt.Key_A..Z
                    if (U.ctrlKod(event) || (k >= 97 && k <= 122)) { var L = U.tus(event); if (L >= "a" && L <= "z") k = 0x41 + L.charCodeAt(0) - 97; }
                    var done = true;
                    if (k === Qt.Key_S) { if (shift) root.saveAs(); else root.save(); }
                    else if (k === Qt.Key_F) root.askFind();
                    else if (k === Qt.Key_N) root.findNext();
                    else if (k === Qt.Key_H) root.askReplace();
                    else if (k === Qt.Key_G) root.askGoto();
                    else if (k === Qt.Key_B) root.copyAll();
                    else if (k === Qt.Key_D) { if (!root.readOnly) root.duplicateLine(); }
                    else if (k === Qt.Key_K) { if (!root.readOnly) root.deleteLine(); }
                    else if (k === Qt.Key_T) root.insertText(fs.now("dd.MM.yyyy HH:mm"));
                    else if (k === Qt.Key_E) root.convert();
                    else if (k === Qt.Key_P) root.preview();
                    else if (k === Qt.Key_R) root.toggleReadOnly();
                    else if (k === Qt.Key_W) root.toggleWrap();
                    else if (k === Qt.Key_L) root.stats();
                    else if (k === Qt.Key_U) root.transform(shift ? U.lowerTr : U.upperTr, shift ? qsTr("Küçük harf") : qsTr("Büyük harf"));
                    else if (k === Qt.Key_J) { if (!root.readOnly) root.toggleTodoLine(); }
                    else if (k === Qt.Key_Q) app.quit();
                    else if (k === Qt.Key_Plus || k === Qt.Key_Equal) root.setFont(2);
                    else if (k === Qt.Key_Minus) root.setFont(-2);
                    else if (k === Qt.Key_Up) { edit.cursorPosition = 0; }
                    else if (k === Qt.Key_Down) { edit.cursorPosition = edit.text.length; }
                    else done = false;   // Z, Y, A, C, X, V ve diger duzenleme kisayollari TextEdit'e gider
                    if (done) event.accepted = true;
                    return;
                }
                if (root.readOnly) {
                    var t = U.tus(event);
                    var page = flick.height - 40;
                    if (k === Qt.Key_Space || t === "j") { flick.contentY = Math.min(flick.contentHeight - flick.height, flick.contentY + page); event.accepted = true; }
                    else if (t === "z" || t === "k") { flick.contentY = Math.max(0, flick.contentY - page); event.accepted = true; }
                    else if (t === "n") { root.chunked ? root.nextChunk() : root.findNext(); event.accepted = true; }
                    else if (t === "p") { root.prevChunk(); event.accepted = true; }
                    else if (t === "b" || t === "f") { root.askFind(); event.accepted = true; }
                    else if (t === "g") { root.askGoto(); event.accepted = true; }
                    else if (t === "e") { root.toggleReadOnly(); event.accepted = true; }
                    else if (k === Qt.Key_Backspace) { root.close(); event.accepted = true; }
                    else if (k === Qt.Key_Down) { flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY + 40); event.accepted = true; }
                    else if (k === Qt.Key_Up) { flick.contentY = Math.max(0, flick.contentY - 40); event.accepted = true; }
                    else if (k === Qt.Key_Right && app.wrap) { flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY + page); event.accepted = true; }
                    else if (k === Qt.Key_Left && app.wrap) { flick.contentY = Math.max(0, flick.contentY - page); event.accepted = true; }
                    else if (U.printable(event)) event.accepted = true;
                }
            }
        }
    }
    // ---- Durum cubugu ----
    Rectangle {
        id: status
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 30
        color: app.surface
        Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: app.divider }
        Text {
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            text: root.chunked
                  ? U.sizeText(root.chunkOffset) + " – " + U.sizeText(root.chunkNext) + " / " + U.sizeText(root.fileSize) + qsTr("  •  N sonraki  P önceki")
                  : qsTr("Satır ") + root.line + qsTr(", Sütun ") + root.col + (edit.selectedText ? "  •  " + edit.selectedText.length + qsTr(" seçili") : "")
            color: app.textSecondary
            font.pixelSize: 14
        }
        Text {
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            text: (root.readOnly ? qsTr("SALT OKUNUR  •  ") : "") + root.encoding + (root.bom ? "+BOM" : "") + "  •  " + root.eol.toUpperCase() + qsTr("  •  Menü: orta tuş")
            color: root.readOnly ? app.brand : app.textSecondary
            font.pixelSize: 14
        }
    }
}
