#include "rotacizgi.h"
#include <QtDeclarative/qdeclarative.h>
#include <QtGui/QPainter>
#include <QtGui/QPolygonF>
#include <qmath.h>
#include <QtCore/QDebug>

RotaCizgi::RotaCizgi(QDeclarativeItem *parent)
    : QDeclarativeItem(parent), m_cx(0), m_cy(0), m_kal(6), m_zoom(12), m_renk(26, 115, 232, 217), m_ilkCizim(false), m_sonZoom(-1)
{
    setFlag(QGraphicsItem::ItemHasNoContents, false);
}

void RotaCizgi::kaydet()
{
    static bool bir = false;
    if (bir) return;
    bir = true;
    qmlRegisterType<RotaCizgi>("BelleMaps", 1, 0, "RotaCizgi");
}

void RotaCizgi::setNoktalar(const QVariant &v)
{
    m_ham = v;
    m_n.clear();
    const QVariantList l = v.toList();
    m_n.reserve(l.size());
    for (int i = 0; i < l.size(); i++) {
        const QVariantList p = l.at(i).toList();
        if (p.size() < 2) continue;
        const double lat = qBound(-85.0511, p.at(0).toDouble(), 85.0511), lng = p.at(1).toDouble();
        const double s = qSin(lat * M_PI / 180.0);
        m_n.append(QPointF((lng + 180.0) / 360.0, 0.5 - qLn((1 + s) / (1 - s)) / (4 * M_PI)));
    }
    qDebug("iz: rota cizgisi %d nokta aldi", m_n.size());
    m_ilkCizim = true;
    update();
    emit degisti();
}

// a (ekranda) ile b arasindaki dogruyu b ekran sinirinin (genisletilmis) disindaysa oraya kirpar:
// cizime cok buyuk koordinat (yuz binlerce piksel) gitmesin
static QPointF kirp(const QPointF &a, const QPointF &b, const QRectF &r)
{
    if (r.contains(b)) return b;
    qreal t = 1.0;
    const qreal dx = b.x() - a.x(), dy = b.y() - a.y();
    if (dx > 0 && b.x() > r.right()) t = qMin(t, (r.right() - a.x()) / dx);
    if (dx < 0 && b.x() < r.left()) t = qMin(t, (r.left() - a.x()) / dx);
    if (dy > 0 && b.y() > r.bottom()) t = qMin(t, (r.bottom() - a.y()) / dy);
    if (dy < 0 && b.y() < r.top()) t = qMin(t, (r.top() - a.y()) / dy);
    t = qBound(qreal(0), t, qreal(1));
    return QPointF(a.x() + dx * t, a.y() + dy * t);
}

void RotaCizgi::paint(QPainter *p, const QStyleOptionGraphicsItem *, QWidget *)
{
    if (m_n.size() < 2) return;
    const bool yaz = m_ilkCizim || m_zoom != m_sonZoom;
    if (yaz) { m_ilkCizim = false; m_sonZoom = m_zoom; qDebug("iz: rota cizgisi ciziliyor (z%d)", m_zoom); }
    const qreal dunya = 256.0 * (1 << qBound(0, m_zoom, 24));
    const qreal ox = m_cx - width() / 2, oy = m_cy - height() / 2;
    const QRectF ekran(-50, -50, width() + 100, height() + 100);       // "icerde" sayilan alan
    const QRectF sinir(-600, -600, width() + 1200, height() + 1200);   // cizime giden en uzak nokta
    // yumusatma ve yuvarlak uclar kapali: Symbian OpenVG kalin/yumusatilmis cizgide cokebiliyor
    p->setRenderHint(QPainter::Antialiasing, false);
    p->setPen(QPen(m_renk, m_kal, Qt::SolidLine, Qt::FlatCap, Qt::BevelJoin));
    int cizilen = 0;
    p->setBrush(Qt::NoBrush);
    QPolygonF parca;
    QPointF onceki, son(-1e9, -1e9);
    bool oncekiIcerde = false;
    for (int i = 0; i < m_n.size(); i++) {
        const QPointF e(m_n.at(i).x() * dunya - ox, m_n.at(i).y() * dunya - oy);
        const bool icerde = ekran.contains(e);
        if (i > 0 && (icerde || oncekiIcerde)) {
            if (parca.isEmpty()) { parca.append(oncekiIcerde ? onceki : kirp(e, onceki, sinir)); son = parca.last(); }
            const QPointF h = icerde ? e : kirp(onceki, e, sinir);
            // ayni noktayi iki kez ekleme (sifir uzunlukta parca yok)
            if (qAbs(h.x() - son.x()) + qAbs(h.y() - son.y()) >= 2) { parca.append(h); son = h; }
            if (!icerde) { if (parca.size() > 1) { p->drawPolyline(parca); cizilen += parca.size(); } parca.clear(); son = QPointF(-1e9, -1e9); }
        }
        onceki = e; oncekiIcerde = icerde;
    }
    if (parca.size() > 1) { p->drawPolyline(parca); cizilen += parca.size(); }
    if (yaz) qDebug("iz: rota cizgisi cizildi (z%d, %d nokta)", m_zoom, cizilen);
}