import QtQuick 1.1

// Metin girisi penceresi (yeni liste adi, yeniden adlandirma)
Rectangle {
    id: root
    color: "#99000000"
    property string title: ""
    property string okLabel: qsTr("Tamam")

    function show(t, initial, ok) {
        title = t;
        okLabel = ok || qsTr("Tamam");
        field.text = initial || "";
        focusTimer.restart();
    }
    Timer { id: focusTimer; interval: 40; onTriggered: field.focusInput() }
    function accept() { app.promptDone(field.text); }

    MouseArea { anchors.fill: parent; onClicked: { app.promptOpen = false; app.focusTop(); } }
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 60, 520)
        height: col.height + 40
        radius: 16
        color: app.surface
        MouseArea { anchors.fill: parent }
        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
            spacing: 16
            Text { text: root.title; color: app.textPrimary; font.pixelSize: 21; font.bold: true }
            TextField {
                id: field
                width: parent.width
                onAccepted: root.accept()
            }
            Row {
                anchors.right: parent.right
                spacing: 10
                Btn { text: qsTr("Yapıştır"); icon: "plus"; onClicked: { field.focusInput(); field.input.paste(); } }
                Btn { text: qsTr("İptal"); onClicked: { app.promptOpen = false; app.focusTop(); } }
                Btn { text: root.okLabel; primary: true; onClicked: root.accept() }
            }
        }
    }
}
