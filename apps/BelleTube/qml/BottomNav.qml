import QtQuick 1.1

Rectangle {
    id: root
    property int current: 0
    signal selected(int index)

    height: 72
    color: app.surface

    Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: app.divider }

    ListModel {
        id: items
        ListElement { label: QT_TR_NOOP("Akış"); icon: "nav_home" }
        ListElement { label: QT_TR_NOOP("Kanallar"); icon: "nav_subs" }
        ListElement { label: QT_TR_NOOP("Ara"); icon: "nav_search" }
        ListElement { label: QT_TR_NOOP("Kitaplık"); icon: "nav_library" }
        ListElement { label: QT_TR_NOOP("Ayarlar"); icon: "nav_settings" }
    }

    Row {
        anchors.fill: parent
        Repeater {
            model: items
            delegate: Item {
                width: root.width / 5
                height: root.height
                property bool active: index === root.current
                Rectangle {
                    id: pillBg
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 7 }
                    width: 64; height: 34; radius: 17
                    color: active ? app.pill : (ma.pressed ? app.pressed : "transparent")
                }
                Image {
                    anchors.centerIn: pillBg
                    width: 30; height: 30; smooth: true
                    // Ayarlar'in aktif kirmizi ikonu ayri adla uretildi
                    source: "../images/" + (active ? (icon === "nav_settings" ? (app.dark ? "nav_settings_on_rd" : "nav_settings_on_r") : icon + (app.dark ? "_on_d" : "_on"))
                                                   : icon + (app.dark ? "_light" : "")) + ".png"
                }
                Text {
                    anchors { horizontalCenter: parent.horizontalCenter; top: pillBg.bottom; topMargin: 3 }
                    text: qsTr(label)
                    color: app.textPrimary
                    font.pixelSize: 16
                    font.bold: active
                }
                MouseArea { id: ma; anchors.fill: parent; onClicked: root.selected(index) }
            }
        }
    }
}
