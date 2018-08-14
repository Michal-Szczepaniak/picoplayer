import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0
import "../dialogs"

Page {
    id: page

    Column {
        anchors.centerIn: parent
        spacing: Theme.paddingLarge


        Button {
            text: "Open file…"
            width: streamButton.width
            onClicked: pageStack.push(videoPickerPage)
        }

        Button {
            id: streamButton
            text: "Open URL Stream…"
            onClicked: {
                var dialog = pageStack.push(Qt.resolvedUrl("../dialogs/UrlStreamPickerDialog.qml"))
            }
        }

        Button {
            text: "About"
            width: streamButton.width
        }
    }

    Component {
        id: videoPickerPage
        FilePickerPage {
            onSelectedContentPropertiesChanged: {
                pageStack.push(Qt.resolvedUrl("VideoPlayer.qml"), {url: selectedContentProperties.filePath})
            }
        }
    }
}
