import QtQuick 1.1

// Yuvarlak metin kutusu, yer tutucu yazili
Rectangle {
    id: root
    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property int fontSize: 20
    property string icon: ""
    property bool yapistirDugmesi: true   // sagda "yapistir" simgesi (E6'da Ctrl+V her zaman ulasmiyor)
    signal accepted
    signal downPressed

    height: 52
    radius: height / 2
    color: app.surface2
    border.width: input.activeFocus ? 2 : 0
    border.color: app.accent

    function focusInput() { input.forceActiveFocus(); input.openSoftwareInputPanel(); }

    Image {
        id: ic
        visible: root.icon !== ""
        anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
        width: 24; height: 24; smooth: true
        source: root.icon !== "" ? "../images/" + root.icon + "_g.png" : ""
    }
    TextInput {
        id: input
        // Ctrl+V yapistir / Ctrl+A tumunu sec (E6: Ctrl+V "7" ya da kod 22 gonderir)
        Keys.onPressed: {
            if (((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_V || event.text === "7" || event.text === "v")) || event.text === "\u0016") { pano.yapistir(input); event.accepted = true; }
            else if (((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_A || event.text === "a")) || event.text === "\u0001") { input.selectAll(); event.accepted = true; }
        }
        anchors { left: root.icon !== "" ? ic.right : parent.left; leftMargin: root.icon !== "" ? 10 : 20; right: yapistirSimge.visible ? yapistirSimge.left : parent.right; rightMargin: yapistirSimge.visible ? 4 : 20; verticalCenter: parent.verticalCenter }
        font.pixelSize: root.fontSize
        color: app.textPrimary
        selectByMouse: true
        selectionColor: app.accent
        inputMethodHints: Qt.ImhNoPredictiveText
        onAccepted: root.accepted()
        // Yazi doluyken kenarda sol/sag basinca sekme degismesin; asagi ok sonuclara gecer
        Keys.onLeftPressed: event.accepted = input.text.length > 0 && input.cursorPosition === 0
        Keys.onRightPressed: event.accepted = input.text.length > 0 && input.cursorPosition >= input.text.length
        Keys.onDownPressed: { root.downPressed(); event.accepted = true; }
    }
    // Panodaki metni imlecin yerine yapistirir (C++ kutuphane/pano)
    IconButton {
        id: yapistirSimge
        visible: root.yapistirDugmesi
        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
        width: 44; height: 44; iconSize: 24; icon: "paste"; tone: "g"
        onClicked: { if (!pano.yapistir(input)) app.showToast(qsTr("Pano boş")); input.forceActiveFocus(); }
    }
    Text {
        anchors { left: input.left; right: input.right; verticalCenter: parent.verticalCenter }
        text: root.placeholder
        color: app.textSecondary
        font.pixelSize: root.fontSize
        elide: Text.ElideRight
        visible: input.text.length === 0 && !input.activeFocus
    }
    MouseArea { anchors.fill: parent; enabled: !input.activeFocus; onClicked: root.focusInput() }
}
