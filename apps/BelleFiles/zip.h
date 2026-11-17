#ifndef BELLE_ZIP_H
#define BELLE_ZIP_H

// Belle Files — bagimsiz zip destegi (zlib gerekmez): okuma (stored + deflate), acma, olusturma.
// Inflate RFC 1951'e gore yazildi (akisli: 32 KB pencere, buyuk dosyalar bellege alinmaz).
// Olusturma: 16 MB'a kadar dosyalar sabit Huffman + LZ77 ile sikistirilir, buyukler sikistirmasiz (stored) eklenir.

#include <QtCore/QString>
#include <QtCore/QList>
#include <QtCore/QStringList>

class QFile;

struct ZipOge {
    QString ad;          // arsiv icindeki yol ("klasor/dosya.txt"); klasorler "/" ile biter
    quint32 crc;
    qint64 boyut;        // acilmis boyut
    qint64 sBoyut;       // sikistirilmis boyut
    int yontem;          // 0 stored, 8 deflate, 99 WinZip AES (asil yontem: aesYontem)
    int bayrak;          // bit 0: sifreli
    int aesGuc;          // 0 AES degil, 1/2/3 = AES-128/192/256
    int aesSurum;        // 1 AE-1 (CRC gecerli), 2 AE-2 (CRC yok)
    int aesYontem;       // AES icindeki asil sikistirma yontemi
    bool sifreli() const { return bayrak & 1; }
    ZipOge() : crc(0), boyut(0), sBoyut(0), yontem(0), bayrak(0), aesGuc(0), aesSurum(0), aesYontem(0), zaman(0), yerelOfset(0) {}
    uint zaman;          // time_t
    qint64 yerelOfset;   // yerel baslik konumu
    bool klasor() const { return ad.endsWith('/'); }
};

// Ilerleme / iptal icin geri cagirma (is parcacigindan cagrilir): false donerse islem durur
class ZipIzleyici {
public:
    virtual ~ZipIzleyici() {}
    virtual bool zipIlerleme(qint64 bayt) = 0;   // eklenen bayt
};

namespace Zip {
    // Merkezi dizini okur; hata varsa false ve hata metni
    bool listele(const QString &arsiv, QList<ZipOge> *ogeler, QString *hata);
    // Tek ogeyi hedef dosyaya acar (klasorleri hedef olusturur).
    // Sifreli ogede parola kullanilir (ZipCrypto ya da WinZip AES); parola yok/yanlissa
    // parolaSorunu true olur ve false doner.
    bool ac(QFile &arsiv, const ZipOge &o, const QString &hedefDosya, ZipIzleyici *iz, QString *hata,
            const QByteArray &parola = QByteArray(), bool *parolaSorunu = 0);

    // Zip yazici: ekle() ile dosya/klasor, bitir() ile merkezi dizin
    class Yazici {
    public:
        explicit Yazici(QFile *f);
        void sadeceSakla(bool b) { m_sakla = b; }     // true: hic sikistirma yok (stored), hizli

        // Var olan zip'e ekleme: f ReadWrite acik olmali. Eski merkezi dizin saklanir, yeni ogeler
        // onun yerine yazilir; bitir() eski + yeni dizini yazar. Hata olursa geriAl() arsivi eski haline getirir.
        bool eklemeyeAc(QString *hata);
        void geriAl();
        bool varMi(const QString &arsivAdi) const { return m_adlar.contains(arsivAdi); }

        bool dosyaEkle(const QString &yerel, const QString &arsivAdi, ZipIzleyici *iz, QString *hata);
        bool klasorEkle(const QString &arsivAdi, uint zaman);
        bool bitir(QString *hata);
    private:
        QFile *m_f;
        bool m_sakla;
        QList<ZipOge> m_ogeler;
        QByteArray m_eskiCD, m_eskiSon;   // ekleme kipinde: eski merkezi dizin ve dizin sonu kaydi
        qint64 m_eskiCdOfs;
        int m_eskiAdet;
        QStringList m_adlar;              // arsivdeki adlar (cakisma onlemek icin)
    };

    quint32 crc32(quint32 crc, const char *p, qint64 n);
}

#endif
