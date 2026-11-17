# Translating

Source strings are **Turkish**. English (and any future language) is applied at runtime by a tiny translator in
`apps/kutuphane/dil/` that looks strings up in a plain-text dictionary bundled into each app as `:/dil/en.txt`.
No `lupdate` / `lrelease` / `.qm` files are needed.

## How strings are marked

| Where | Syntax |
|---|---|
| QML / JS | `qsTr("Ayarlar")`, `qsTr("%1 yeni mesaj").arg(n)` |
| `ListElement` | `label: QT_TR_NOOP("Sohbetler")` and `text: qsTr(label)` where it is shown |
| C++ | `Dil::t("Kaydedildi")` (UTF-8 literal) |
| C# (PC apps) | `L.T("Kaydet")` |

Language choice: `dil.secim` (`auto` / `tr` / `en`) and `dil.sec("en")` in QML; stored in `C:\Data\E6\dil.ini`,
shared by all apps, applied on the next start (`dil.yenidenBaslat` tells the UI to show a hint).

## Dictionary files

The master dictionary lives in `apps/kutuphane/dil/sozluk/*.txt`, one file per app group:

```
# comment
Ayarlar ¦ Settings
 kişi ¦  contacts
Yedek yok.\nYedekler vCard dosyasıdır. ¦ No backups.\nBackups are vCard files.
```

- separator is exactly `space ¦ space`; leading/trailing spaces of each side are kept (they matter when strings
  are concatenated, e.g. `count + qsTr(" kişi")`)
- escapes are written as in the source code (`\n`, `\"`)
- a line whose Turkish side starts with `#` is a comment, so such strings stay untranslated

`tools/dil_cikar.ps1 -Uygulama apps/<App>` collects every marked string of that app (and of the shared libraries
it includes), writes the app's `dil/en.txt` from the master dictionary and reports what is missing
(`-EksikDosya missing.txt`). Missing strings simply show in Turkish.

## Adding a language

1. Add `sozluk_<code>/` dictionaries (same format) and generate `dil/<code>.txt`.
2. In `dil.cpp` load `:/dil/<code>.txt` when that language is selected and extend `Dil::sec()` / the settings row.

## Helper scripts (Windows PowerShell)

| Script | Purpose |
|---|---|
| `tools/dil_sar.ps1` | wraps Turkish string literals in QML/JS with `qsTr()` (report first, `-Uygula` to write) |
| `tools/dil_sar_cpp.ps1` | wraps `QString::fromUtf8("…")` UI strings in C++ with `Dil::t()` |
| `tools/dil_sar_cs.ps1` | wraps C# UI strings with `L.T()` |
| `tools/dil_kur.ps1` | wires the translator into an app (`.pro` include + `main.cpp`) |
| `tools/dil_cikar.ps1` | builds `dil/en.txt` and lists missing translations |

Always review the wrappers' output: they skip comparisons, object keys, regular expressions, SQL and JavaScript
code, but a human should check the diff.
