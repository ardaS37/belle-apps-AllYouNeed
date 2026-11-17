import QtQuick 1.1

// Yuvarlak kenarli metin kutusu, yer tutucu yazili. Ctrl+V yapistirir, Ctrl+A tumunu secer
// (E6'da Ctrl basiliyken harf yerine kontrol kodu ya da tusun rakami gelir: V=7 / kod 22)
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
    function yapistir() {
        var p = "" + cihaz.pano();
        if (p === "") return;
        var a = input.selectionStart, b = input.selectionEnd;
        if (a === b) { a = input.cursorPosition; b = a; }
        input.text = input.text.substring(0, a) + p + input.text.substring(b);
        input.cursorPosition = a + p.length;
    }

    TextInput {
        id: input
        anchors { left: parent.left; right: parent.right; leftMargin: 22; rightMargin: 22; verticalCenter: parent.verticalCenter }
        font.pixelSize: root.fontSize
        color: app.textPrimary
        selectByMouse: true
        selectionColor: app.brand
        onAccepted: { cihaz.girisiTamamla(); root.accepted(); }
        Keys.onPressed: {
            var ctrlBasili = (event.modifiers & Qt.ControlModifier) !== 0;
            var kod = event.text && event.text.length === 1 ? event.text.charCodeAt(0) : 0;
            if ((ctrlBasili && (event.key === Qt.Key_V || event.text === "7" || event.text === "v")) || kod === 22) {
                root.yapistir(); event.accepted = true;
            } else if ((ctrlBasili && (event.key === Qt.Key_A || event.text === "a")) || kod === 1) {
                input.selectAll(); event.accepted = true;
            }
        }
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
