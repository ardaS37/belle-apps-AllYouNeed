import QtQuick 1.1
import "Util.js" as U

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
    // Panodaki yaziyi imlecin yerine (secim varsa onun yerine) koy. E6'da Ctrl+V TextInput'a ulasmiyor.
    function yapistir() {
        var p = cv.pano();
        if (!p) { app.showToast(qsTr("Pano boş")); return; }
        p = ("" + p).replace(/[\r\n]+/g, " ");
        var t = input.text, a = input.selectionStart, b = input.selectionEnd;
        if (a === b) { a = input.cursorPosition; b = a; }
        input.text = t.substring(0, a) + p + t.substring(b);
        input.cursorPosition = a + p.length;
    }

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
            if (U.ctrl(event) && U.tus(event) === "v") { root.yapistir(); event.accepted = true; }
            else if (U.ctrl(event) && U.tus(event) === "a") { input.selectAll(); event.accepted = true; }
            else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Context2) { root.escaped(); event.accepted = true; }
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
