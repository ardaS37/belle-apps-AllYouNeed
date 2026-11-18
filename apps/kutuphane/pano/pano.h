// Ortak pano yardimcisi (QML'e "pano" adiyla acilir).
// E6'da (Symbian Qt 4.7) QML TextInput/TextEdit'in kendi paste() islevi panoyu okumuyor;
// metin C++'ta QApplication::clipboard() ile alinip kutuya elle yazilir.
//   QML:  Keys.onPressed: Ctrl+V (E6: "7" ya da kod 22) -> pano.yapistir(kutuId)
#ifndef BELLE_PANO_H
#define BELLE_PANO_H

#include <QtCore/QObject>
#include <QtCore/QVariant>
#include <QtGui/QApplication>
#include <QtGui/QClipboard>
#include <QtGui/QWidget>
#include <QtGui/QInputContext>

class Pano : public QObject
{
    Q_OBJECT
public:
    explicit Pano(QObject *parent = 0) : QObject(parent) {}

    Q_INVOKABLE QString metin() const { return QApplication::clipboard()->text(); }
    Q_INVOKABLE void kopyala(const QString &s) const { QApplication::clipboard()->setText(s); }

    // Tahmini yazimdaki (alti cizili) kelimeyi metne isle; yoksa Enter'dan once text eksik kalir
    Q_INVOKABLE void girisiTamamla() const
    {
        QWidget *w = QApplication::focusWidget();
        if (w && w->inputContext()) w->inputContext()->reset();
    }

    // Panodaki metni kutunun imlecine (secim varsa onun yerine) yazar. Tek satirlik kutuda satir sonlari bosluk olur.
    Q_INVOKABLE bool yapistir(QObject *kutu) const
    {
        if (!kutu) return false;
        girisiTamamla();
        QString p = QApplication::clipboard()->text();
        if (p.isEmpty()) return false;
        const bool tekSatir = QString::fromLatin1(kutu->metaObject()->className()).contains(QLatin1String("TextInput"));
        if (tekSatir) { p.replace(QLatin1String("\r\n"), QLatin1String(" ")); p.replace(QLatin1Char('\n'), QLatin1Char(' ')); p.replace(QLatin1Char('\r'), QLatin1Char(' ')); }
        const QString t = kutu->property("text").toString();
        int a = kutu->property("selectionStart").toInt(), b = kutu->property("selectionEnd").toInt();
        if (a == b) { a = kutu->property("cursorPosition").toInt(); b = a; }
        if (a < 0 || a > t.size()) a = t.size();
        if (b < a || b > t.size()) b = a;
        kutu->setProperty("text", t.left(a) + p + t.mid(b));
        kutu->setProperty("cursorPosition", a + p.size());
        return true;
    }
};

#endif
