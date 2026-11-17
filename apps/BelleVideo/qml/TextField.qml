import QtQuick 1.1

// Yuvarlak kenarli metin kutusu, yer tutucu yazili
Rectangle {
    id: root
    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property alias inputMethodHints: input.inputMethodHints
    property int fontSize: 19
    signal accepted
    signal escaped

    height: 46
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
        anchors { left: parent.left; right: parent.right; leftMargin: 18; rightMargin: 18; verticalCenter: parent.verticalCenter }
        font.pixelSize: root.fontSize
        color: app.textPrimary
        selectByMouse: true
        selectionColor: app.brand
        selectedTextColor: "#101418"
        onAccepted: root.accepted()
        Keys.onEscapePressed: root.escaped()
    }
    Text {
        anchors { left: input.left; right: input.right; verticalCenter: parent.verticalCenter }
        text: root.placeholder
        color: app.textSecondary
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
