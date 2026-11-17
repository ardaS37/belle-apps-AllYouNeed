import QtQuick 1.1
import "SheetState.js" as St

// Bir ya da iki alanli giris penceresi.
// open({ title, label1, text1, label2 (istege bagli), text2, ok, selectBase, password }, geriCagirma(t1, t2))
// Enter: ikinci alan varsa ona gecer, yoksa onaylar. Yukari/Asagi alan degistirir. Esc kapatir.
// selectBase: ilk alanda uzanti haric adi secili getir (yeniden adlandirmada).
Rectangle {
    id: root
    property bool shown: false
    property string title: ""
    property string label1: ""
    property string label2: ""
    property string okText: qsTr("Tamam")
    property bool two: label2 !== ""

    anchors.fill: parent
    color: "#99000000"
    visible: shown
    z: 70

    function open(o, cb) {
        title = o.title || "";
        label1 = o.label1 || "";
        label2 = o.label2 || "";
        okText = o.ok || qsTr("Tamam");
        f1.text = o.text1 || "";
        f2.text = o.text2 || "";
        f1.input.echoMode = o.password ? TextInput.Password : TextInput.Normal;   // parola: yildizli
        St.inputCb = cb;
        shown = true;
        f1.focusInput();
        if (o.selectBase) {
            var dot = f1.text.lastIndexOf(".");
            f1.input.select(0, dot > 0 ? dot : f1.text.length);
        } else f1.selectAll();
    }
    function close() {
        shown = false;
        St.inputCb = null;
        f1.input.closeSoftwareInputPanel();
        app.focusCurrent();
    }
    function accept() {
        fs.girisiTamamla();     // E6: alti cizili (islenmemis) son kelime de metne girsin
        var cb = St.inputCb, a = f1.text, b = f2.text;
        St.inputCb = null;
        shown = false;
        f1.input.closeSoftwareInputPanel();
        app.focusCurrent();
        if (cb) cb(a, b);
    }

    MouseArea { anchors.fill: parent; onClicked: root.close() }

    Rectangle {
        id: panel
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 30; rightMargin: 30; topMargin: 24 }
        height: col.height + 24
        radius: 14
        color: app.surface
        MouseArea { anchors.fill: parent }

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 8
            Text { text: root.title; color: app.textPrimary; font.pixelSize: 19; font.bold: true; width: parent.width; elide: Text.ElideRight }
            Text { text: root.label1; color: app.textSecondary; font.pixelSize: 15; visible: text !== "" }
            TextField {
                id: f1
                width: parent.width
                onAccepted: root.two ? f2.focusInput() : root.accept()
                onEscaped: root.close()
                onTabbed: if (root.two) f2.focusInput()
            }
            Text { text: root.label2; color: app.textSecondary; font.pixelSize: 15; visible: root.two }
            TextField {
                id: f2
                visible: root.two
                width: parent.width
                onAccepted: root.accept()
                onEscaped: root.close()
                onTabbed: f1.focusInput()
            }
            Row {
                anchors.right: parent.right
                spacing: 10
                Rectangle {
                    width: 110; height: 40; radius: 20
                    color: cMa.pressed ? app.pressed : app.fieldBg
                    Text { anchors.centerIn: parent; text: qsTr("Vazgeç"); color: app.textPrimary; font.pixelSize: 17 }
                    MouseArea { id: cMa; anchors.fill: parent; onClicked: root.close() }
                }
                Rectangle {
                    width: Math.max(110, okLbl.paintedWidth + 30); height: 40; radius: 20
                    color: oMa.pressed ? app.brandPressed : app.brand
                    Text { id: okLbl; anchors.centerIn: parent; text: root.okText + "  ⏎"; color: "#0B1A22"; font.pixelSize: 17; font.bold: true }
                    MouseArea { id: oMa; anchors.fill: parent; onClicked: root.accept() }
                }
            }
        }
    }
}
