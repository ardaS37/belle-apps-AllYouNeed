import QtQuick 1.1

// Yuvarlak kenarli metin kutusu, yer tutucu yazili
Rectangle {
    id: root
    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property alias inputMethodHints: input.inputMethodHints
    property alias echoMode: input.echoMode
    property int fontSize: 22
    signal accepted

    height: 56
    radius: height / 2
    color: app.fieldBg
    border.width: input.activeFocus ? 2 : 0
    border.color: app.brand

    function focusInput() {
        input.forceActiveFocus();
        input.openSoftwareInputPanel();
    }

    TextInput {
        id: input
        // Ctrl+V yapistir / Ctrl+A tumunu sec (E6: Ctrl+V "7" ya da kod 22 gonderir)
        Keys.onPressed: {
            if (((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_V || event.text === "7" || event.text === "v")) || event.text === "\u0016") { input.paste(); event.accepted = true; }
            else if (((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_A || event.text === "a")) || event.text === "\u0001") { input.selectAll(); event.accepted = true; }
        }
        anchors { left: parent.left; right: parent.right; leftMargin: 22; rightMargin: 22; verticalCenter: parent.verticalCenter }
        font.pixelSize: root.fontSize
        color: app.textPrimary
        selectByMouse: true
        selectionColor: app.brand
        onAccepted: root.accepted()
    }
    Text {
        anchors { left: input.left; right: input.right; verticalCenter: parent.verticalCenter }
        text: root.placeholder
        color: app.placeholder
        font.pixelSize: root.fontSize
        elide: Text.ElideRight
        visible: input.text.length === 0 && !input.activeFocus
    }
    MouseArea {
        anchors.fill: parent
        enabled: !input.activeFocus
        onClicked: root.focusInput()
    }
}
