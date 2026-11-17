#include "opusses.h"
#include <opus.h>
#include <QtCore/QList>
#include <QtCore/QVector>
#include <string.h>

// ---------------------------------------------------------------- OGG yardimcilari
static quint32 sCrcTablo[256];
static bool sCrcHazir = false;

static void crcHazirla()
{
    if (sCrcHazir) return;
    for (quint32 i = 0; i < 256; ++i) {
        quint32 r = i << 24;
        for (int k = 0; k < 8; ++k) r = (r & 0x80000000u) ? (r << 1) ^ 0x04C11DB7u : (r << 1);
        sCrcTablo[i] = r;
    }
    sCrcHazir = true;
}

static quint32 oggCrc(const QByteArray &b)
{
    crcHazirla();
    quint32 c = 0;
    const uchar *p = reinterpret_cast<const uchar *>(b.constData());
    for (int i = 0; i < b.size(); ++i) c = (c << 8) ^ sCrcTablo[((c >> 24) & 0xFF) ^ p[i]];
    return c;
}

static void le16(QByteArray &b, quint16 v) { b.append(char(v & 0xFF)); b.append(char(v >> 8)); }
static void le32(QByteArray &b, quint32 v) { for (int i = 0; i < 4; ++i) b.append(char((v >> (8 * i)) & 0xFF)); }
static void le64(QByteArray &b, quint64 v) { for (int i = 0; i < 8; ++i) b.append(char((v >> (8 * i)) & 0xFF)); }
static quint16 oku16(const uchar *p) { return quint16(p[0] | (p[1] << 8)); }

// tip: 0x02 baslangic, 0x04 son
static void sayfaYaz(QByteArray &out, quint8 tip, quint64 granul, quint32 seri, quint32 sira, const QList<QByteArray> &paketler)
{
    QByteArray segler;
    QByteArray veri;
    for (int i = 0; i < paketler.size(); ++i) {
        int n = paketler[i].size();
        while (n >= 255) { segler.append(char(255)); n -= 255; }
        segler.append(char(n));
        veri.append(paketler[i]);
    }
    QByteArray s("OggS", 4);
    s.append(char(0));
    s.append(char(tip));
    le64(s, granul);
    le32(s, seri);
    le32(s, sira);
    le32(s, 0);                       // crc yeri
    s.append(char(segler.size()));
    s.append(segler);
    s.append(veri);
    const quint32 c = oggCrc(s);
    for (int i = 0; i < 4; ++i) s[22 + i] = char((c >> (8 * i)) & 0xFF);
    out.append(s);
}

// ---------------------------------------------------------------- cozme
QByteArray OpusSes::coz(const QByteArray &ogg, int hz, QString *hata)
{
    const uchar *p = reinterpret_cast<const uchar *>(ogg.constData());
    const int boy = ogg.size();
    int pos = 0, paketNo = 0, atla = 0;
    OpusDecoder *d = 0;
    QByteArray paket, cikis;
    const int enFazla = hz * 2 * 60 * 15;      // 15 dakika
    QVector<opus_int16> tampon(5760);
    QString h;

    while (pos + 27 <= boy && h.isEmpty()) {
        if (memcmp(p + pos, "OggS", 4) != 0) {
            const int n = ogg.indexOf("OggS", pos + 1);
            if (n < 0) break;
            pos = n;
            continue;
        }
        const int nseg = p[pos + 26];
        if (pos + 27 + nseg > boy) break;
        const uchar *lac = p + pos + 27;
        int o = pos + 27 + nseg;
        int toplam = 0;
        for (int i = 0; i < nseg; ++i) toplam += lac[i];
        if (o + toplam > boy) break;
        for (int i = 0; i < nseg && h.isEmpty(); ++i) {
            paket.append(reinterpret_cast<const char *>(p + o), lac[i]);
            o += lac[i];
            if (lac[i] == 255) continue;
            // paket tamam
            if (paketNo == 0) {
                if (paket.size() < 19 || !paket.startsWith("OpusHead")) { h = QString::fromLatin1("OpusHead yok"); break; }
                const int onAtla = oku16(reinterpret_cast<const uchar *>(paket.constData()) + 10);
                atla = int(qint64(onAtla) * hz / 48000);
                int e = 0;
                d = opus_decoder_create(hz, 1, &e);
                if (!d || e != OPUS_OK) { h = QString::fromLatin1("opus cozucu: %1").arg(e); d = 0; break; }
            } else if (paketNo >= 2 && d && !paket.isEmpty()) {
                const int n = opus_decode(d, reinterpret_cast<const unsigned char *>(paket.constData()), paket.size(),
                                          tampon.data(), tampon.size(), 0);
                if (n > 0) {
                    int bas = 0;
                    if (atla > 0) { bas = qMin(atla, n); atla -= bas; }
                    if (n > bas) cikis.append(reinterpret_cast<const char *>(tampon.constData() + bas), (n - bas) * 2);
                    if (cikis.size() > enFazla) break;
                }
            }
            ++paketNo;
            paket.clear();
        }
        pos = o;
    }
    if (d) opus_decoder_destroy(d);
    if (cikis.isEmpty() && h.isEmpty()) h = QString::fromLatin1("ses verisi yok");
    if (hata) *hata = h;
    return h.isEmpty() ? cikis : QByteArray();
}

QByteArray OpusSes::wav(const QByteArray &pcm, int hz)
{
    QByteArray b("RIFF", 4);
    le32(b, 36 + pcm.size());
    b.append("WAVEfmt ", 8);
    le32(b, 16);
    le16(b, 1);          // PCM
    le16(b, 1);          // tek kanal
    le32(b, hz);
    le32(b, hz * 2);
    le16(b, 2);
    le16(b, 16);
    b.append("data", 4);
    le32(b, pcm.size());
    b.append(pcm);
    return b;
}

// ---------------------------------------------------------------- kodlama
QByteArray OpusSes::kodla(const QByteArray &pcm, int hz, int *sureSn, QString *hata)
{
    int e = 0;
    OpusEncoder *k = opus_encoder_create(hz, 1, OPUS_APPLICATION_VOIP, &e);
    if (!k || e != OPUS_OK) {
        if (hata) *hata = QString::fromLatin1("opus kodlayici: %1").arg(e);
        return QByteArray();
    }
    opus_encoder_ctl(k, OPUS_SET_BITRATE(hz <= 8000 ? 12000 : 20000));
    opus_encoder_ctl(k, OPUS_SET_COMPLEXITY(3));
    opus_encoder_ctl(k, OPUS_SET_SIGNAL(OPUS_SIGNAL_VOICE));
    opus_int32 bakis = 0;
    opus_encoder_ctl(k, OPUS_GET_LOOKAHEAD(&bakis));
    const quint32 onAtla48 = quint32(qint64(bakis) * 48000 / hz);

    const quint32 seri = 0x42454C4Cu;     // "BELL"
    quint32 sira = 0;
    QByteArray out;

    QByteArray bas("OpusHead", 8);
    bas.append(char(1));
    bas.append(char(1));
    le16(bas, quint16(onAtla48));
    le32(bas, quint32(hz));
    le16(bas, 0);
    bas.append(char(0));
    sayfaYaz(out, 0x02, 0, seri, sira++, QList<QByteArray>() << bas);

    QByteArray etiket("OpusTags", 8);
    const QByteArray satici("BelleGram");
    le32(etiket, satici.size());
    etiket.append(satici);
    le32(etiket, 0);
    sayfaYaz(out, 0, 0, seri, sira++, QList<QByteArray>() << etiket);

    const int cerceve = hz / 50;                     // 20 ms
    const int ornek = pcm.size() / 2;
    const opus_int16 *s = reinterpret_cast<const opus_int16 *>(pcm.constData());
    QVector<opus_int16> son(cerceve, 0);
    unsigned char paket[1500];
    QList<QByteArray> sayfa;
    int segSayisi = 0;
    qint64 islenen = 0;
    for (int i = 0; i < ornek; i += cerceve) {
        const opus_int16 *giris = s + i;
        if (i + cerceve > ornek) {
            son.fill(0);
            memcpy(son.data(), s + i, (ornek - i) * 2);
            giris = son.constData();
        }
        const int n = opus_encode(k, giris, cerceve, paket, sizeof(paket));
        if (n < 0) continue;
        islenen += cerceve;
        sayfa.append(QByteArray(reinterpret_cast<const char *>(paket), n));
        segSayisi += n / 255 + 1;
        const bool sonuncu = i + cerceve >= ornek;
        if (sayfa.size() >= 50 || segSayisi > 200 || sonuncu) {
            sayfaYaz(out, sonuncu ? 0x04 : 0, onAtla48 + quint64(islenen) * 48000 / hz, seri, sira++, sayfa);
            sayfa.clear();
            segSayisi = 0;
        }
    }
    opus_encoder_destroy(k);
    if (sureSn) *sureSn = int((ornek + hz / 2) / hz);
    if (sira <= 2) {
        if (hata) *hata = QString::fromLatin1("kayit bos");
        return QByteArray();
    }
    return out;
}

QByteArray OpusSes::dalga(const QByteArray &pcm, int adet)
{
    const int ornek = pcm.size() / 2;
    const qint16 *s = reinterpret_cast<const qint16 *>(pcm.constData());
    QVector<int> tepe(adet, 0);
    int enBuyuk = 1;
    if (ornek > 0) {
        for (int i = 0; i < ornek; ++i) {
            const int j = int(qint64(i) * adet / ornek);
            const int v = qAbs(int(s[i]));
            if (v > tepe[j]) tepe[j] = v;
        }
        for (int j = 0; j < adet; ++j) enBuyuk = qMax(enBuyuk, tepe[j]);
    }
    QByteArray out((adet * 5 + 7) / 8 + 1, 0);
    for (int j = 0; j < adet; ++j) {
        const int v = qMin(31, tepe[j] * 31 / enBuyuk);
        const int bit = j * 5;
        const int b = bit / 8, kay = bit % 8;
        const int deger = v << kay;
        out[b] = char(uchar(out.at(b)) | (deger & 0xFF));
        out[b + 1] = char(uchar(out.at(b + 1)) | ((deger >> 8) & 0xFF));
    }
    out.chop(1);
    return out;
}
