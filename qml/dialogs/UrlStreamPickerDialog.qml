import QtQuick 2.2
import Sailfish.Silica 1.0

Dialog {
    property string url
    acceptDestination: Qt.resolvedUrl("../pages/VideoPlayer.qml")
    acceptDestinationProperties: { url: url }

    Column {
        width: parent.width

        DialogHeader { }

        TextField {
            id: urlField
            width: parent.width
            placeholderText: "https://…"
            label: "Stream URL"
            focus: true
        }
    }

    onDone: {
        if (result == DialogResult.Accepted) {
            url = urlField.text
        }
    }
}
