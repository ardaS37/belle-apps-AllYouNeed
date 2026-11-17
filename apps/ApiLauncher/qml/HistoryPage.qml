import QtQuick 1.1

// Gecmis sohbetler (saglayici basina)
Rectangle {
    id: root
    color: app.bg
    property string provider: ""
    property string label: ""
    property int currentConv: 0
    property int confirmId: 0
    signal openConv(int id)
    signal close
    signal newChat
    signal deleted(int id)

    function reload() {
        convModel.clear();
        var rows = app.listConvs(provider);
        for (var i = 0; i < rows.length; i++)
            convModel.append({ cid: rows[i].id, title: rows[i].title, mname: rows[i].model, updated: rows[i].updated, n: rows[i].n });
    }

    function when(ms) {
        var d = new Date(ms);
        var now = new Date();
        var pad = function (x) { return (x < 10 ? "0" : "") + x; };
        if (d.toDateString() === now.toDateString()) return qsTr("Bugün ") + pad(d.getHours()) + ":" + pad(d.getMinutes());
        return pad(d.getDate()) + "." + pad(d.getMonth() + 1) + "." + d.getFullYear();
    }

    MouseArea { anchors.fill: parent }   // alttaki sohbete dokunmayi engelle

    Header {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        showBack: true
        title: root.label + qsTr(" geçmişi")
        subtitle: convModel.count + qsTr(" sohbet")
        onBack: root.close()
        IconButton { source: "../images/plus" + app.iconTone + ".png"; iconSize: 32; onClicked: root.newChat() }
    }

    ListModel { id: convModel }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        clip: true
        model: convModel
        delegate: Item {
            width: list.width
            height: 78
            Rectangle { anchors.fill: parent; color: ma.pressed ? app.pressed : (cid === root.currentConv ? app.pill : "transparent") }
            Column {
                anchors { left: parent.left; leftMargin: 18; right: del.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                spacing: 3
                Text { width: parent.width; text: title; textFormat: Text.PlainText; color: app.textPrimary; font.pixelSize: 20; elide: Text.ElideRight }
                Text { width: parent.width; text: root.when(updated) + "  •  " + n + qsTr(" mesaj  •  ") + mname; color: app.textSecondary; font.pixelSize: 15; elide: Text.ElideRight }
            }
            MouseArea { id: ma; anchors { left: parent.left; right: del.left; top: parent.top; bottom: parent.bottom } onClicked: root.openConv(cid) }
            Rectangle {
                id: del
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                width: root.confirmId === cid ? 96 : 56; height: 44; radius: 22
                color: root.confirmId === cid ? app.danger : "transparent"
                Image { visible: root.confirmId !== cid; anchors.centerIn: parent; width: 30; height: 30; smooth: true; source: "../images/trash" + app.iconTone + ".png" }
                Text { visible: root.confirmId === cid; anchors.centerIn: parent; text: qsTr("Sil"); color: "#FFFFFF"; font.pixelSize: 18; font.bold: true }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (root.confirmId !== cid) { root.confirmId = cid; confirmReset.restart(); return; }
                        var id = cid;
                        app.deleteConv(id);
                        root.confirmId = 0;
                        root.deleted(id);
                        root.reload();
                    }
                }
            }
            Rectangle { anchors { left: parent.left; leftMargin: 18; right: parent.right; bottom: parent.bottom } height: 1; color: app.divider }
        }
    }
    Timer { id: confirmReset; interval: 3000; onTriggered: root.confirmId = 0 }

    Text {
        anchors.centerIn: list
        visible: convModel.count === 0
        text: qsTr("Henüz sohbet yok.")
        color: app.textSecondary
        font.pixelSize: 19
    }
}
