import QtQuick 1.1

// Ince alt cubuk: amblem ve isim yan yana (sohbete daha cok yer kalsin)
Rectangle {
    id: root
    property int current: 0
    signal selected(int index)

    height: 46
    color: app.surface

    Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: app.divider }

    ListModel {
        id: items
        ListElement { label: "GPT"; icon: "nav_gpt" }
        ListElement { label: QT_TR_NOOP("Claude"); icon: "nav_claude" }
        ListElement { label: QT_TR_NOOP("Gemini"); icon: "nav_gemini" }
        ListElement { label: QT_TR_NOOP("Grok"); icon: "nav_grok" }
        ListElement { label: QT_TR_NOOP("Ayarlar"); icon: "nav_gear" }
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
                    anchors { centerIn: parent }
                    width: Math.min(parent.width - 8, content.width + 24)
                    height: 34; radius: 17
                    color: active ? app.pill : (ma.pressed ? app.pressed : "transparent")
                }
                Row {
                    id: content
                    anchors.centerIn: parent
                    spacing: 5
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26; height: 26; smooth: true
                        source: "../images/" + icon + (active && icon !== "nav_gear" ? "_on" : (app.dark ? "_light" : "")) + ".png"
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr(label)
                        color: active ? app.accentText : app.textPrimary
                        font.pixelSize: 16
                        font.bold: active
                    }
                }
                MouseArea { id: ma; anchors.fill: parent; onClicked: root.selected(index) }
            }
        }
    }
}
