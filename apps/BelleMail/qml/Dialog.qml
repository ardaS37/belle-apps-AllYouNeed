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

    function open(t, m, ok, input, tg, dng) {
        title = t; message = m; okText = ok || qsTr("Tamam"); withInput = !!input; tag = tg || ""; danger = !!dng;
        field.text = "";
        visible = true;
        if (withInput) { field.forceActiveFocus(); field.openSoftwareInputPanel(); }
        else box.forceActiveFocus();
    }
    function close() { visible = false; field.closeSoftwareInputPanel(); app.focusMain(); }
    function accept() {
        if (withInput && field.text.replace(/\s+/g, "") === "") return;
        var t = field.text;
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
                    // Ctrl+V yapistir / Ctrl+A tumunu sec (E6: Ctrl+V "7" ya da kod 22 gonderir)
                    Keys.onPressed: {
                        if (((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_V || event.text === "7" || event.text === "v")) || event.text === "\u0016") { pano.yapistir(field); event.accepted = true; }
                        else if (((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_A || event.text === "a")) || event.text === "\u0001") { field.selectAll(); event.accepted = true; }
                    }
                    anchors { left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    font.pixelSize: 21
                    color: app.textPrimary
                    onAccepted: root.accept()
                    Keys.onEscapePressed: root.close()
                }
                MouseArea { anchors.fill: parent; enabled: !field.activeFocus; onClicked: { field.forceActiveFocus(); field.openSoftwareInputPanel(); } }
            }
            Row {
                anchors.right: parent.right
                spacing: 10
                Btn { text: qsTr("Vazgeç"); onClicked: root.close() }
                Btn { text: root.okText; primary: !root.danger; danger: root.danger; onClicked: root.accept() }
            }
        }
    }
}
