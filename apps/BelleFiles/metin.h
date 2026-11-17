#ifndef METIN_H
#define METIN_H

#include <QtCore/QObject>
#include <QtCore/QStringList>
#include <QtCore/QVariantList>
#include <QtCore/QVariantMap>

// QML'e "fs" adiyla acilir. Dosya sistemi, metin okuma / yazma (kodlama ve satir sonu tanima),
// kopyalama / tasima / silme, pano, disa / ice aktarma paketleri, dosyalarda arama ve gunluk.
//
// Klasorler (telefonda):
//   kok      E:/E6Metin  (kart yoksa C:/Data/E6Metin)
//   notlar   <kok>/Notlar        (Ayarlar'dan degistirilebilir)
//   disa     <kok>/Disa aktarilan
//   yedek    <kok>/Yedek
//   veri     C:/Data/E6Metin     (gunluk, taslak)
class Metin : public QObject
{
    Q_OBJECT
public:
    explicit Metin(QObject *parent = 0);

    // ---- Klasorler ----
    Q_INVOKABLE QString baseDir() const { return m_base; }
    Q_INVOKABLE QString notesDir() const { return m_notes; }
    Q_INVOKABLE void setNotesDir(const QString &path);
    Q_INVOKABLE QString exportDir() const;
    Q_INVOKABLE QString backupDir() const;
    Q_INVOKABLE QString dataDir() const { return m_data; }
    Q_INVOKABLE QString draftPath() const { return m_data + "/taslak.txt"; }

    // ---- Gezinme ----
    // path bos: kokler. Ogeler: { name, path, dir, size, time, ext, text }
    // allFiles=false ise yalnizca metin olarak taninan dosyalar gelir. sort: "name" | "date" | "size"
    Q_INVOKABLE QVariantList listDir(const QString &path, bool allFiles, const QString &filter, const QString &sort) const;
    Q_INVOKABLE QString parentDir(const QString &path) const;
    Q_INVOKABLE bool isRoot(const QString &path) const;
    Q_INVOKABLE bool isText(const QString &path) const;
    Q_INVOKABLE QString textExtensions() const;
    Q_INVOKABLE QVariantMap info(const QString &path) const;
    Q_INVOKABLE bool exists(const QString &path) const;
    Q_INVOKABLE bool isDir(const QString &path) const;
    Q_INVOKABLE QString fileName(const QString &path) const;
    Q_INVOKABLE QString baseName(const QString &path) const;     // uzantisiz ad
    Q_INVOKABLE QString suffix(const QString &path) const;       // kucuk harf uzanti
    Q_INVOKABLE QString folderOf(const QString &path) const;
    Q_INVOKABLE QString join(const QString &dir, const QString &name) const;
    Q_INVOKABLE QString uniquePath(const QString &dir, const QString &name) const;
    Q_INVOKABLE QString sizeText(qint64 bytes) const;
    Q_INVOKABLE bool validName(const QString &name) const;
    // Klavyede henuz islenmemis (alti cizili) kelimeyi metin kutusuna isle. Enter'dan once cagrilir.
    Q_INVOKABLE void girisiTamamla() const;

    // ---- Okuma / yazma ----
    // encoding bos: otomatik (BOM, gecerli UTF-8, yoksa Windows-1254).
    // Donus: { ok, text (satir sonlari \n), encoding, eol: "crlf"|"lf"|"cr", bom, binary, size, error }
    Q_INVOKABLE QVariantMap readText(const QString &path, const QString &encoding) const;
    // Buyuk dosyalar icin parca: { ok, text, offset, next, size, encoding }
    Q_INVOKABLE QVariantMap readPart(const QString &path, qint64 offset, int length, const QString &encoding) const;
    // Guvenli yazma (gecici dosya + yeniden adlandirma). backup: eskisini .bak olarak sakla.
    // Donus: { ok, error, lost (kodlamada karsiligi olmayan karakter sayisi), size }
    Q_INVOKABLE QVariantMap writeText(const QString &path, const QString &text, const QString &encoding,
                                      const QString &eol, bool bom, bool backup);

    // ---- Dosya islemleri (hata metni lastError()) ----
    Q_INVOKABLE bool makeDir(const QString &path);
    Q_INVOKABLE QString copyPath(const QString &src, const QString &dstDir);   // yeni yol ya da ""
    Q_INVOKABLE QString movePath(const QString &src, const QString &dstDir);
    Q_INVOKABLE QString renamePath(const QString &src, const QString &newName);
    Q_INVOKABLE QString changeExtension(const QString &path, const QString &ext, bool keepOriginal);
    Q_INVOKABLE bool removePath(const QString &path);
    Q_INVOKABLE QString lastError() const { return m_error; }

    // ---- Pano ve sistem ----
    Q_INVOKABLE QString clipboardText() const;
    Q_INVOKABLE void setClipboardText(const QString &text);
    Q_INVOKABLE void sendKey(int key, int modifiers);       // odaktaki ogeye tus gonder (geri al / yinele)
    Q_INVOKABLE bool openExternally(const QString &path) const;
    // Resmin gercek boyutu (dosyayi acmadan, baslıktan): { w, h } (okunamazsa 0)
    Q_INVOKABLE QVariantMap resimBoyutu(const QString &path) const;
    Q_INVOKABLE QString now(const QString &format) const;

    // ---- Arama ----
    // Klasorde (alt klasorlerle) ad ya da icerik aramasi. [{ path, name, lineNo, line }]
    Q_INVOKABLE QVariantList searchFiles(const QString &dir, const QString &query, bool inContent) const;

    // ---- Disa / ice aktarma ----
    // Paket: tek bir UTF-8 metin dosyasinda birden cok dosya ("@@@E6METIN@@@ ad" satirlariyla ayrilir)
    Q_INVOKABLE QString exportBundle(const QStringList &paths, const QString &outPath);
    Q_INVOKABLE bool isBundle(const QString &path) const;
    Q_INVOKABLE QStringList importBundle(const QString &bundlePath, const QString &targetDir);
    Q_INVOKABLE QStringList textFilesIn(const QString &dir, bool recursive) const;
    Q_INVOKABLE QString backupFolder(const QString &srcDir);

    // ---- Gunluk ----
    Q_INVOKABLE void log(const QString &line);
    Q_INVOKABLE QString logText() const;
    Q_INVOKABLE void clearLog();

private:
    bool copyRec(const QString &src, const QString &dst);
    bool removeRec(const QString &path);
    QString decode(const QByteArray &bytes, const QString &want, QString *used, bool *bom, bool *binary) const;

    QString m_base;
    QString m_notes;
    QString m_data;
    mutable QString m_error;
    QStringList m_log;
    bool m_logLoaded;
};

#endif
