#include "audioextract.h"
#include "dil.h"

#include <QtCore/QFileInfo>

// ---- kutu yardimcilari ----

static quint32 rd32(const QByteArray &b, int p)
{
    const uchar *u = reinterpret_cast<const uchar *>(b.constData()) + p;
    return (quint32(u[0]) << 24) | (quint32(u[1]) << 16) | (quint32(u[2]) << 8) | quint32(u[3]);
}
static quint64 rd64(const QByteArray &b, int p) { return (quint64(rd32(b, p)) << 32) | rd32(b, p + 4); }
static void wr32(QByteArray &b, quint32 v)
{
    b.append(char(v >> 24)); b.append(char(v >> 16)); b.append(char(v >> 8)); b.append(char(v));
}
static QByteArray box(const char *type, const QByteArray &content)
{
    QByteArray b;
    wr32(b, quint32(8 + content.size()));
    b.append(type, 4);
    b.append(content);
    return b;
}

struct Box { int start; int hl; int size; QByteArray type; int payload() const { return start + hl; } int end() const { return start + size; } };

// buf icindeki [pos, end) araligindan siradaki kutu
static bool nextBox(const QByteArray &buf, int &pos, int end, Box &b)
{
    if (pos + 8 > end) return false;
    qint64 size = rd32(buf, pos);
    int hl = 8;
    if (size == 1) { if (pos + 16 > end) return false; size = qint64(rd64(buf, pos + 8)); hl = 16; }
    else if (size == 0) size = end - pos;
    if (size < hl || pos + size > end) return false;
    b.start = pos; b.hl = hl; b.size = int(size); b.type = buf.mid(pos + 4, 4);
    pos += int(size);
    return true;
}
static bool child(const QByteArray &buf, const Box &parent, const char *type, Box &out)
{
    int p = parent.payload();
    Box b;
    while (nextBox(buf, p, parent.end(), b)) if (b.type == type) { out = b; return true; }
    return false;
}

// ---- AudioExtract ----

AudioExtract::AudioExtract(QObject *parent)
    : QObject(parent), m_chunk(0), m_sample(0), m_total(0), m_done(0)
{
    m_timer.setInterval(30);
    connect(&m_timer, SIGNAL(timeout()), this, SLOT(step()));
}

int AudioExtract::progress() const
{
    if (!busy() || m_total <= 0) return 0;
    return int(100 * m_done / m_total);
}

void AudioExtract::cancel()
{
    if (!m_timer.isActive()) return;
    m_timer.stop();
    m_in.close();
    m_out.close();
    QFile::remove(m_dst + ".part");
    m_src.clear();
}

void AudioExtract::fail(const QString &msg)
{
    m_timer.stop();
    m_in.close();
    m_out.close();
    QFile::remove(m_dst + ".part");
    m_err = msg;
    const QString s = m_src, d = m_dst;
    m_src.clear();
    emit finished(s, d, false, msg);
}

bool AudioExtract::start(const QString &src, const QString &dst)
{
    if (QFile::exists(dst)) return true;
    if (busy() && src == m_src) return false;
    cancel();
    m_src = src;
    m_dst = dst;
    m_err.clear();
    m_mvhd.clear(); m_tkhd.clear(); m_mdhd.clear(); m_hdlr.clear(); m_smhd.clear();
    m_stsd.clear(); m_stts.clear(); m_stsz.clear();
    m_sizes.clear(); m_chunkOffsets.clear(); m_chunkSamples.clear();
    m_chunk = 0; m_sample = 0; m_total = 0; m_done = 0;

    m_in.setFileName(src);
    if (!m_in.open(QIODevice::ReadOnly)) { fail(Dil::t("Dosya açılamadı")); return false; }
    if (!parse()) { fail(m_err.isEmpty() ? Dil::t("Ses izi bulunamadı") : m_err); return false; }

    QByteArray head;
    if (!buildHeader(head)) { fail(Dil::t("Başlık yazılamadı")); return false; }
    m_out.setFileName(dst + ".part");
    if (!m_out.open(QIODevice::WriteOnly | QIODevice::Truncate) || m_out.write(head) != head.size()) {
        fail(Dil::t("Ses dosyası yazılamadı"));
        return false;
    }
    m_timer.start();
    return false;
}

// moov kutusunu okuyup ses izinin tablolarini cikarir
bool AudioExtract::parse()
{
    const qint64 fsize = m_in.size();
    qint64 pos = 0;
    QByteArray moov;
    while (pos + 8 <= fsize) {
        m_in.seek(pos);
        const QByteArray h = m_in.read(16);
        if (h.size() < 8) break;
        qint64 size = rd32(h, 0);
        if (size == 1 && h.size() >= 16) size = qint64(rd64(h, 8));
        else if (size == 0) size = fsize - pos;
        if (size < 8) break;
        if (h.mid(4, 4) == "moov") {
            if (size > 16 * 1024 * 1024) { m_err = Dil::t("Video başlığı çok büyük"); return false; }
            m_in.seek(pos);
            moov = m_in.read(size);
            break;
        }
        pos += size;
    }
    if (moov.size() < 16) { m_err = Dil::t("MP4 değil ya da parçalı MP4"); return false; }

    Box root;
    int p0 = 0;
    if (!nextBox(moov, p0, moov.size(), root)) return false;
    Box mvhd;
    if (!child(moov, root, "mvhd", mvhd)) return false;
    m_mvhd = moov.mid(mvhd.start, mvhd.size);

    int p = root.payload();
    Box trak;
    while (nextBox(moov, p, root.end(), trak)) {
        if (trak.type != "trak") continue;
        Box mdia, hdlr, minf, stbl, tkhd, mdhd;
        if (!child(moov, trak, "tkhd", tkhd) || !child(moov, trak, "mdia", mdia)) continue;
        if (!child(moov, mdia, "hdlr", hdlr) || !child(moov, mdia, "mdhd", mdhd)) continue;
        if (hdlr.size < hdlr.hl + 12 || moov.mid(hdlr.payload() + 8, 4) != "soun") continue;
        if (!child(moov, mdia, "minf", minf) || !child(moov, minf, "stbl", stbl)) continue;

        Box stsd, stts, stsz, stsc, stco, smhd;
        if (!child(moov, stbl, "stsd", stsd) || !child(moov, stbl, "stts", stts)
            || !child(moov, stbl, "stsz", stsz) || !child(moov, stbl, "stsc", stsc)) continue;
        bool co64 = false;
        if (!child(moov, stbl, "stco", stco)) { if (!child(moov, stbl, "co64", stco)) continue; co64 = true; }

        // yalnizca AAC/MP3 (mp4a) ses
        if (stsd.size < stsd.hl + 16 || moov.mid(stsd.payload() + 12, 4) != "mp4a") {
            m_err = Dil::t("Ses biçimi desteklenmiyor (") + QString::fromLatin1(moov.mid(stsd.payload() + 12, 4)) + ")";
            return false;
        }

        m_tkhd = moov.mid(tkhd.start, tkhd.size);
        m_mdhd = moov.mid(mdhd.start, mdhd.size);
        m_hdlr = moov.mid(hdlr.start, hdlr.size);
        if (child(moov, minf, "smhd", smhd)) m_smhd = moov.mid(smhd.start, smhd.size);
        m_stsd = moov.mid(stsd.start, stsd.size);
        m_stts = moov.mid(stts.start, stts.size);
        m_stsz = moov.mid(stsz.start, stsz.size);

        // ornek boyutlari
        const int zp = stsz.payload();
        const quint32 fixedSize = rd32(moov, zp + 4);
        const quint32 count = rd32(moov, zp + 8);
        if (count == 0 || count > 2000000) { m_err = Dil::t("Ses izi boş"); return false; }
        if (fixedSize == 0 && zp + 12 + qint64(count) * 4 > stsz.end()) return false;
        m_sizes.resize(count);
        for (quint32 i = 0; i < count; ++i) {
            m_sizes[i] = fixedSize ? fixedSize : rd32(moov, zp + 12 + int(i) * 4);
            m_total += m_sizes[i];
        }

        // parca konumlari
        const int op = stco.payload();
        const quint32 nChunks = rd32(moov, op + 4);
        if (op + 8 + qint64(nChunks) * (co64 ? 8 : 4) > stco.end()) return false;
        m_chunkOffsets.resize(nChunks);
        for (quint32 i = 0; i < nChunks; ++i)
            m_chunkOffsets[i] = co64 ? qint64(rd64(moov, op + 8 + int(i) * 8)) : qint64(rd32(moov, op + 8 + int(i) * 4));

        // parca basina ornek sayisi
        const int cp = stsc.payload();
        const quint32 nEntries = rd32(moov, cp + 4);
        if (nEntries == 0 || cp + 8 + qint64(nEntries) * 12 > stsc.end()) return false;
        m_chunkSamples.resize(nChunks);
        quint32 e = 0, left = count;
        for (quint32 c = 0; c < nChunks; ++c) {
            while (e + 1 < nEntries && rd32(moov, cp + 8 + int(e + 1) * 12) <= c + 1) ++e;
            quint32 n = rd32(moov, cp + 8 + int(e) * 12 + 4);
            if (n > left) n = left;
            m_chunkSamples[c] = n;
            left -= n;
        }
        if (left != 0) { m_err = Dil::t("Ses tablosu tutarsız"); return false; }
        return true;
    }
    return false;
}

bool AudioExtract::buildHeader(QByteArray &out)
{
    QByteArray ftyp;
    wr32(ftyp, 28); ftyp.append("ftyp"); ftyp.append("M4A "); wr32(ftyp, 0); ftyp.append("M4A mp42isom");

    QByteArray smhd = m_smhd;
    if (smhd.isEmpty()) { wr32(smhd, 16); smhd.append("smhd"); wr32(smhd, 0); wr32(smhd, 0); }
    QByteArray dinf;
    { QByteArray url; wr32(url, 12); url.append("url "); wr32(url, 1);
      QByteArray dref; wr32(dref, 0); wr32(dref, 1); dref.append(url);
      dinf = box("dinf", box("dref", dref)); }
    QByteArray stsc;
    wr32(stsc, 0); wr32(stsc, 1); wr32(stsc, 1); wr32(stsc, quint32(m_sizes.size())); wr32(stsc, 1);

    // tum ornekler tek parcada (mdat'in hemen basinda); konum moov boyutuna bagli, iki kez kurulur
    QByteArray moov;
    quint32 offset = 0;
    for (int pass = 0; pass < 2; ++pass) {
        QByteArray stco; wr32(stco, 0); wr32(stco, 1); wr32(stco, offset);
        const QByteArray stbl = box("stbl", m_stsd + m_stts + box("stsc", stsc) + m_stsz + box("stco", stco));
        const QByteArray minf = box("minf", smhd + dinf + stbl);
        const QByteArray mdia = box("mdia", m_mdhd + m_hdlr + minf);
        const QByteArray trak = box("trak", m_tkhd + mdia);
        moov = box("moov", m_mvhd + trak);
        offset = quint32(ftyp.size() + moov.size() + 8);
    }
    if (m_total + offset > Q_INT64_C(0xFFFFFFFF)) return false;
    out = ftyp + moov;
    wr32(out, quint32(8 + m_total));
    out.append("mdat");
    return true;
}

void AudioExtract::step()
{
    qint64 budget = 160 * 1024;
    while (budget > 0 && m_chunk < m_chunkOffsets.size()) {
        const quint32 n = m_chunkSamples.at(m_chunk);
        qint64 bytes = 0;
        for (quint32 i = 0; i < n; ++i) bytes += m_sizes.at(m_sample + int(i));
        if (bytes > 0) {
            if (!m_in.seek(m_chunkOffsets.at(m_chunk))) { fail(Dil::t("Okuma hatası")); return; }
            const QByteArray d = m_in.read(bytes);
            if (d.size() != bytes || m_out.write(d) != bytes) { fail(Dil::t("Kopyalama hatası")); return; }
        }
        m_sample += int(n);
        m_done += bytes;
        budget -= qMax<qint64>(bytes, 4096);
        ++m_chunk;
    }
    if (m_chunk < m_chunkOffsets.size()) return;

    m_timer.stop();
    m_in.close();
    m_out.close();
    QFile::remove(m_dst);
    const bool ok = QFile::rename(m_dst + ".part", m_dst);
    const QString s = m_src, d = m_dst;
    m_src.clear();
    if (!ok) { QFile::remove(d + ".part"); emit finished(s, d, false, Dil::t("Dosya adı verilemedi")); return; }
    emit finished(s, d, true, Dil::t("Ses hazır (") + QString::number(QFileInfo(d).size() / 1024) + " KB)");
}
