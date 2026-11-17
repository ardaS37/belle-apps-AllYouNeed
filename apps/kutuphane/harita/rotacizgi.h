#ifndef ROTACIZGI_H
#define ROTACIZGI_H

// Rota cizgisi: tek QML ogesi, QPainter ile tek polyline.
// Eskiden her rota parcasi ayri dondurulmus Rectangle idi; 100+ km'lik rotada binlerce oge grafik bellegini
// doldurup uygulamayi kapatiyordu ("hafiza dolu"). Noktalar bir kez Mercator'a (0..1) cevrilir, cizimde
// ekrana yansitilir; ekranda 2 pikselden yakin noktalar atlanir.
#include <QtDeclarative/QDeclarativeItem>
#include <QtCore/QVector>
#include <QtCore/QPointF>
#include <QtGui/QColor>

class RotaCizgi : public QDeclarativeItem
{
    Q_OBJECT
    Q_PROPERTY(QVariant noktalar READ noktalar WRITE setNoktalar NOTIFY degisti)   // [[lat,lng], ...]
    Q_PROPERTY(qreal cx READ cx WRITE setCx NOTIFY degisti)                          // harita merkezi (dunya pikseli)
    Q_PROPERTY(qreal cy READ cy WRITE setCy NOTIFY degisti)
    Q_PROPERTY(int zoom READ zoom WRITE setZoom NOTIFY degisti)
    Q_PROPERTY(QColor renk READ renk WRITE setRenk NOTIFY degisti)
    Q_PROPERTY(qreal kalinlik READ kalinlik WRITE setKalinlik NOTIFY degisti)
public:
    explicit RotaCizgi(QDeclarativeItem *parent = 0);
    static void kaydet();                     // qmlRegisterType: import BelleMaps 1.0

    QVariant noktalar() const { return m_ham; }
    void setNoktalar(const QVariant &v);
    qreal cx() const { return m_cx; }
    void setCx(qreal v) { if (v != m_cx) { m_cx = v; update(); emit degisti(); } }
    qreal cy() const { return m_cy; }
    void setCy(qreal v) { if (v != m_cy) { m_cy = v; update(); emit degisti(); } }
    int zoom() const { return m_zoom; }
    void setZoom(int v) { if (v != m_zoom) { m_zoom = v; update(); emit degisti(); } }
    QColor renk() const { return m_renk; }
    void setRenk(const QColor &c) { m_renk = c; update(); emit degisti(); }
    qreal kalinlik() const { return m_kal; }
    void setKalinlik(qreal k) { m_kal = k; update(); emit degisti(); }

    void paint(QPainter *p, const QStyleOptionGraphicsItem *, QWidget *);

signals:
    void degisti();

private:
    QVariant m_ham;
    QVector<QPointF> m_n;                     // Mercator 0..1
    qreal m_cx, m_cy, m_kal;
    int m_zoom;
    QColor m_renk;
    bool m_ilkCizim;
    int m_sonZoom;
};

#endif
