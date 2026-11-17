// BelleGram sesli mesajlari: OGG/Opus (RFC 7845) <-> 16 bit PCM (tek kanal).
// Telegram sesli mesajlari OGG kabinda Opus paketleridir. Cozme/kodlama libopus (third_party/opus) ile.
#ifndef TG_OPUSSES_H
#define TG_OPUSSES_H

#include <QtCore/QByteArray>
#include <QtCore/QString>

namespace OpusSes
{
    // Tum dosyayi hz (8000/12000/16000/24000/48000) hizinda tek kanal PCM'e cozer. Hata: bos.
    QByteArray coz(const QByteArray &ogg, int hz, QString *hata = 0);
    // PCM -> WAV dosya icerigi (Audio ogesi calabilsin)
    QByteArray wav(const QByteArray &pcm, int hz);
    // Tek kanal PCM -> OGG/Opus. sureSn: saniye
    QByteArray kodla(const QByteArray &pcm, int hz, int *sureSn, QString *hata = 0);
    // Telegram dalga bicimi: 100 ornek, 0..31, 5 bit paketli (LSB once)
    QByteArray dalga(const QByteArray &pcm, int adet = 100);
}

#endif
