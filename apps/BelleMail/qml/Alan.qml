import QtQuick 1.1

// Etiketli metin kutusu (hesap ekrani). Ctrl+V yapistirir, Ctrl+A tumunu secer.
// E6'da Ctrl basiliyken harf yerine kontrol kodu ya da tusun rakami gelir: V = 7 / kod 22, A = kod 1.
Column {
    id: root
    property alias text: input.text
    property alias input: input
    property string etiket: ""
    property string ipucu: ""
    property alias echoMode: input.echoMode
    property alias inputMethodHints: input.inputMethodHints
    signal accepted

    function odakla() { input.forceActiveFocus(); input.openSoftwareInputPanel(); }
    function yapistir() {
        var p = "" + mail.pano();
        if (p === "") return;
        var a = input.selectionStart, b = input.selectionEnd;
        if (a === b) { a = input.cursorPosition; b = a; }
        input.text = input.text.substring(0, a) + p.replace(/[\r\n]+/g, " ") + input.text.substring(b);
        input.cursorPosition = a + p.length;
    }

    spacing: 4
    Text { text: root.etiket; font.pixelSize: 16; color: app.textSecondary; visible: root.etiket !== "" }
    Rectangle {
        width: root.width
        height: 46
        radius: 6
        color: "#ffffff"
        border.width: 2
        border.color: input.activeFocus ? app.brand : "#c4c7c5"
        TextInput {
            id: input
            anchors { left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10; verticalCenter: parent.verticalCenter }
            font.pixelSize: 20
            color: app.textPrimary
            selectByMouse: true
            onAccepted: { mail.girisiTamamla(); root.accepted(); }
            Keys.onPressed: {
                var ctrlBasili = (event.modifiers & Qt.ControlModifier) !== 0;
                var kod = event.text && event.text.length === 1 ? event.text.charCodeAt(0) : 0;
                if ((ctrlBasili && (event.key === Qt.Key_V || event.text === "7" || event.text === "v")) || kod === 22) { root.yapistir(); event.accepted = true; }
                else if ((ctrlBasili && (event.key === Qt.Key_A || event.text === "a")) || kod === 1) { input.selectAll(); event.accepted = true; }
            }
        }
        Text {
            anchors { left: input.left; right: input.right; verticalCenter: parent.verticalCenter }
            text: root.ipucu
            color: "#9aa0a6"
            font.pixelSize: 18
            elide: Text.ElideRight
            visible: input.text === "" && !input.activeFocus
        }
        MouseArea { anchors.fill: parent; enabled: !input.activeFocus; onClicked: root.odakla() }
    }
}
