import QtQuick 1.1

// Alt gezinme cubugu: aktif sekmede yesil hap (pill) arka plan
Rectangle {
    id: root
    property int current: 0
    signal selected(int index)

    height: 72
    color: app.surface

    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 1
        color: app.divider
    }

    ListModel {
        id: items
        ListElement { label: QT_TR_NOOP("Sohbetler"); icon: "nav_chats" }
        ListElement { label: QT_TR_NOOP("Kişiler"); icon: "nav_contacts" }
        ListElement { label: QT_TR_NOOP("Posta"); icon: "nav_mail" }
        ListElement { label: QT_TR_NOOP("Ayarlar"); icon: "nav_settings" }
    }

    Row {
        anchors.fill: parent
        Repeater {
            model: items
            delegate: Item {
                // Posta kapaliysa sekme gizlenir, digerleri genisler
                visible: index !== 2 || app.mailOn
                width: root.width / (app.mailOn ? 4 : 3)
                height: root.height
                property bool active: index === root.current

                Rectangle {
                    id: pillBg
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 7 }
                    width: 72
                    height: 34
                    radius: 17
                    color: active ? app.pill : (ma.pressed ? app.pressed : "transparent")
                }
                Image {
                    anchors.centerIn: pillBg
                    width: 30
                    height: 30
                    smooth: true
                    source: "../images/" + icon + (active ? (app.dark ? "_on_d" : "_on") : (app.dark ? "_light" : "")) + ".png"
                }
                Text {
                    anchors { horizontalCenter: parent.horizontalCenter; top: pillBg.bottom; topMargin: 3 }
                    text: qsTr(label)
                    color: app.textPrimary
                    font.pixelSize: 17
                    font.bold: active
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    onClicked: root.selected(index)
                }
            }
        }
    }
}
