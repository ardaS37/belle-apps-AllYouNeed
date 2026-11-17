import QtQuick 1.1

// Ortada acilan soru penceresi; withInput ile metin kutulu (klasor adi gibi)
Rectangle {
    id: root
    property string title: ""
    property string message: ""
    property string okText: qsTr("Tamam")
    property bool danger: false
    property bool withInput: false
    property string tag: ""
    signal accepted(string text)

    // deger: kutuda hazir yazi; gizli: parola gibi yildizli
    function open(t, m, ok, input, tg, dng, deger, gizli) {
        title = t; message = m; okText = ok || qsTr("Tamam"); withInput = !!input; tag = tg || ""; danger = !!dng;
        field.echoMode = gizli ? TextInput.Password : TextInput.Normal;
        field.text = deger || "";
        field.cursorPosition = field.text.length;
        visible = true;
        if (withInput) { field.forceActiveFocus(); field.openSoftwareInputPanel(); }
        else box.forceActiveFocus();
    }
    function yapistir() {
        var c = fs.clipboardText().replace(/[\r\n\t]/g, "");
        if (c === "") { app.toast(qsTr("Pano boş")); return; }
        var p = field.cursorPosition;
        field.text = field.text.substring(0, p) + c + field.text.substring(p);
        field.cursorPosition = p + c.length;
        field.forceActiveFocus();
    }
    function close() { visible = false; field.closeSoftwareInputPanel(); app.focusMain(); }
    function accept() {
        field.focus = false; box.forceActiveFocus();          // E6: son sozcugu kutuya islet
        if (withInput && field.text.replace(/\s+/g, "") === "") return;
        var t = field.text.replace(/[\r\n\t]/g, "");
        close();
        accepted(t);
    }

    anchors.fill: parent
    color: "#99000000"
    visible: false
    z: 150
    MouseArea { anchors.fill: parent; onClicked: root.close() }

    Rectangle {
        id: box
        anchors.centerIn: parent
        width: Math.min(parent.width - 60, 520)
        height: col.height + 32
        radius: 10
        color: "#ffffff"
        focus: true
        Keys.onPressed: {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) { root.accept(); event.accepted = true; }
            else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) { root.close(); event.accepted = true; }
        }
        MouseArea { anchors.fill: parent }

        Column {
            id: col
            x: 20; y: 16
            width: parent.width - 40
            spacing: 14
            Text { width: parent.width; text: root.title; font.pixelSize: 23; font.bold: true; color: app.textPrimary; wrapMode: Text.Wrap }
            Text { width: parent.width; text: root.message; visible: root.message !== ""; font.pixelSize: 19; color: app.textSecondary; wrapMode: Text.Wrap }
            Rectangle {
                width: parent.width; height: 46; radius: 6
                visible: root.withInput
                border.width: 2; border.color: field.activeFocus ? app.brand : "#c4c7c5"
                TextInput {
                    id: field
                    anchors { left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    font.pixelSize: 21
                    color: app.textPrimary
                    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    onAccepted: root.accept()
                    Keys.onEscapePressed: root.close()
                    Keys.onPressed: {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select || event.text === "\r" || event.text === "\n") { root.accept(); event.accepted = true; }
                        else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V || event.text === "\u0016") { root.yapistir(); event.accepted = true; }
                    }
                }
                MouseArea { anchors.fill: parent; enabled: !field.activeFocus; onClicked: { field.forceActiveFocus(); field.openSoftwareInputPanel(); } }
            }
            Row {
                anchors.right: parent.right
                spacing: 10
                DriveBtn { text: qsTr("Yapıştır"); visible: root.withInput; onClicked: root.yapistir() }
                DriveBtn { text: qsTr("Vazgeç"); onClicked: root.close() }
                DriveBtn { text: root.okText; primary: !root.danger; danger: root.danger; onClicked: root.accept() }
            }
        }
    }
}
