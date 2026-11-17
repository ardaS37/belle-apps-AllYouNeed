#ifndef ARAC_H
#define ARAC_H

#include <QtCore/QObject>
#include <QtCore/QSettings>
#include <QtGui/QApplication>
#include <QtGui/QClipboard>
#include "haritaag.h"

// QML yardimcilari: pano, ayarlar, onbellek
class Arac : public QObject
{
    Q_OBJECT
public:
    explicit Arac(QObject *parent = 0) : QObject(parent), m_s("BelleHarita", "Genel") {}
    Q_INVOKABLE void pano(const QString &t) { QApplication::clipboard()->setText(t); }
    Q_INVOKABLE QString ayar(const QString &k, const QString &v) const { return m_s.value(k, v).toString(); }
    Q_INVOKABLE void setAyar(const QString &k, const QString &v) { m_s.setValue(k, v); m_s.sync(); }
    Q_INVOKABLE QString onbellekMetni() const {
        const qint64 b = HaritaAg::onbellekBoyutu();
        return b > 1048576 ? QString::number(b / 1048576.0, 'f', 1) + " MB" : QString::number(b / 1024) + " KB";
    }
    Q_INVOKABLE void onbellekSil() { HaritaAg::onbellekSil(); }
    Q_INVOKABLE QString klasor() const { return HaritaNam::onbellekKlasoru(); }
private:
    QSettings m_s;
};

#endif
