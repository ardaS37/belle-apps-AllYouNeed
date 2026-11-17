import QtQuick 1.1

// Basili tutma menusu: menu.ac("Baslik", [["kod","Etiket"], ...], baglam) -> secildi(kod, baglam)
Item {
    id: root
    visible: false
    z: 30
    property string baslik: ""
    property variant baglam
    signal secildi(string kod, variant baglam)

    function ac(b, ogeler, bg) {
        baslik = b || "";
        baglam = bg;
        ogeModel.clear();
        for (var i = 0; i < ogeler.length; i++) ogeModel.append({ kod: ogeler[i][0], etiket: ogeler[i][1], tehlike: !!ogeler[i][2] });
        visible = true;
        liste.currentIndex = 0;
        liste.forceActiveFocus();
    }
    function kapat() { visible = false; }

    ListModel { id: ogeModel }

    Rectangle { anchors.fill: parent; color: "#88000000" }
    MouseArea { anchors.fill: parent; onClicked: root.kapat() }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 60, 460)
        height: Math.min(parent.height - 40, kolon.height + 16)
        radius: 14
        color: app.surface
        clip: true
        MouseArea { anchors.fill: parent }
        Column {
            id: kolon
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
            Text {
                visible: root.baslik !== ""
                width: parent.width - 40
                x: 20
                height: visible ? 50 : 0
                verticalAlignment: Text.AlignVCenter
                text: root.baslik
                color: app.textSecondary
                font.pixelSize: 18
                elide: Text.ElideRight
            }
            ListView {
                id: liste
                width: parent.width
                height: Math.min(count * 62, root.height - 120)
                interactive: count * 62 > height
                clip: true
                model: ogeModel
                Keys.onReturnPressed: if (currentIndex >= 0) { var o = ogeModel.get(currentIndex); root.kapat(); root.secildi(o.kod, root.baglam); }
                Keys.onEnterPressed: if (currentIndex >= 0) { var o = ogeModel.get(currentIndex); root.kapat(); root.secildi(o.kod, root.baglam); }
                Keys.onEscapePressed: root.kapat()
                delegate: Rectangle {
                    width: liste.width
                    height: 62
                    color: fare.pressed || (ListView.isCurrentItem && liste.activeFocus) ? app.pressed : "transparent"
                    Text {
                        anchors { left: parent.left; leftMargin: 24; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                        text: etiket
                        color: tehlike ? app.danger : app.textPrimary
                        font.pixelSize: 22
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: fare
                        anchors.fill: parent
                        onClicked: { root.kapat(); root.secildi(kod, root.baglam); }
                    }
                }
            }
        }
    }
}
