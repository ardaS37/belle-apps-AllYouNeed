import QtQuick 1.1

// Yuvarlak kenarli metin kutusu, yer tutucu yazili
Rectangle {
    id: root
    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property int fontSize: 19
    signal accepted
    signal escaped
    signal tabbed

    height: 44
    radius: 10
    color: app.fieldBg
    border.width: input.activeFocus ? 2 : 0
    border.color: app.brand

    function focusInput() {
        input.forceActiveFocus();
        input.openSoftwareInputPanel();
    }
    function selectAll() { input.selectAll(); }

    TextInput {
        id: input
        anchors { left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14; verticalCenter: parent.verticalCenter }
        font.pixelSize: root.fontSize
        color: app.textPrimary
        selectByMouse: true
        selectionColor: app.brand
        selectedTextColor: "#101418"
        onAccepted: root.accepted()
        Keys.onPressed: {
            // Ctrl+V yapistir / Ctrl+A tumunu sec (E6: Ctrl+V "7" ya da kod 22 gonderir)
            if (((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_V || event.text === "7" || event.text === "v")) || event.text === "\u0016") { input.paste(); event.accepted = true; return; }
            if (((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_A || event.text === "a")) || event.text === "\u0001") { input.selectAll(); event.accepted = true; return; }
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Context2) { root.escaped(); event.accepted = true; }
            else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up || event.key === Qt.Key_Tab) { root.tabbed(); event.accepted = true; }
            else if (event.key === Qt.Key_Select) { root.accepted(); event.accepted = true; }
        }
    }
    Text {
        anchors { left: input.left; right: input.right; verticalCenter: parent.verticalCenter }
        text: root.placeholder
        color: app.textSecondary
        font.pixelSize: root.fontSize
        elide: Text.ElideRight
        visible: input.text.length === 0
    }
    MouseArea {
        anchors.fill: parent
        enabled: !input.activeFocus
        onClicked: root.focusInput()
    }
}
