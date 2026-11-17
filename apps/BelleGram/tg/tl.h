// BelleGram TL katmani: Telegram'in ikili serilestirmesi + sema guduml genel kodlayici.
// Nesneler QVariantMap olarak tasinir: {"_": "message", "id": 5, "message": "selam", ...}.
//   int -> int, long -> qlonglong, double -> double, string -> QString, bytes/int128/int256 -> QByteArray,
//   Bool/true -> bool, Vector<T> -> QVariantList, nesne -> QVariantMap. Flags'i kapali alan haritada yer almaz.
// Sema: kaynak dosya ":/tl/sema.txt" (araclar\tl_sema.ps1 uretir, Telegram api.tl + mtproto.tl).
#ifndef TG_TL_H
#define TG_TL_H

#include <QtCore/QByteArray>
#include <QtCore/QString>
#include <QtCore/QVariant>
#include <QtCore/QHash>
#include <QtCore/QVector>

class TlYazici
{
public:
    void int32(qint32 v) { ham(reinterpret_cast<const char *>(&v), 4); }
    void uint32(quint32 v) { ham(reinterpret_cast<const char *>(&v), 4); }
    void int64(qint64 v) { ham(reinterpret_cast<const char *>(&v), 8); }
    void cift(double v) { ham(reinterpret_cast<const char *>(&v), 8); }
    void ham(const char *p, int n) { veri.append(p, n); }
    void ham(const QByteArray &b) { veri.append(b); }
    void bayt(const QByteArray &b);
    void dize(const QString &s) { bayt(s.toUtf8()); }
    QByteArray veri;
};

class TlOkuyucu
{
public:
    explicit TlOkuyucu(const QByteArray &v) : veri(v), konum(0), hata(false) {}
    qint32 int32();
    quint32 uint32() { return quint32(int32()); }
    qint64 int64();
    double cift();
    QByteArray ham(int n);
    QByteArray bayt();
    QString dize() { return QString::fromUtf8(bayt()); }
    bool bitti() const { return konum >= veri.size(); }
    int kalan() const { return veri.size() - konum; }
    QByteArray veri;
    int konum;
    bool hata;
};

class TlSema
{
public:
    struct Param {
        QByteArray ad, tur;     // tur: kosulsuz tur (flags.N? kismi atilmis)
        int flagAlan;           // kosullu alan: bayraklari tutan parametrenin sirasi, degilse -1
        int flagBit;
    };
    struct Tanim {
        quint32 id;
        QByteArray ad, tur;     // tur: sonuc turu (fonksiyon) ya da ait oldugu tur (constructor)
        bool fonk;
        QVector<Param> par;
    };

    static TlSema &tek();
    bool yuklu() const { return !m_ad.isEmpty(); }
    int katman() const { return m_katman; }
    const Tanim *idIle(quint32 id) const { return m_id.value(id, 0); }
    const Tanim *adIle(const QByteArray &ad) const { return m_ad.value(ad, 0); }

    // Okuma: tur ornekleri "Object", "auth.SentCode", "Vector<User>", "Bool", "long"
    QVariant oku(TlOkuyucu &r, const QByteArray &tur) const;
    QVariant nesneOku(TlOkuyucu &r) const;
    QVariant govdeOku(TlOkuyucu &r, const Tanim *t) const;   // kimlik okunmus, govde

    // Yazma: harita "_" ile constructor/fonksiyon adini tasir. Hata (bilinmeyen ad) olursa false.
    bool yaz(TlYazici &w, const QVariant &deger, const QByteArray &tur) const;
    bool nesneYaz(TlYazici &w, const QVariantMap &m) const;
    // Fonksiyon cagrisini serilestirir; sonucTuru, yanitin nasil okunacagini verir
    QByteArray cagri(const QString &ad, const QVariantMap &param, QByteArray *sonucTuru = 0) const;

    QString sonHata;

private:
    TlSema();
    void yukle();
    QByteArray ic(const QByteArray &s);
    QHash<quint32, Tanim *> m_id;
    QHash<QByteArray, Tanim *> m_ad;
    QHash<QByteArray, QByteArray> m_ic;   // ayni dizeleri tek kopya tutar (bellek)
    int m_katman;
};

// TL nesnesini okunur metne cevirir (gunluk ve test icin)
QString tlMetin(const QVariant &v, int derinlik = 0);

#endif
