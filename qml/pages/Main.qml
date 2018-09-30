import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0

Page {
    id: page
    allowedOrientations: Orientation.All
    property bool startup: true

    PageHeader {
        title: "Pico Player"
    }

    onStatusChanged: {
        if(status === PageStatus.Active && startup === true) {
            startup = false
            if(typeof Qt.application.arguments[1] !== "undefined") {
                pageStack.push(Qt.resolvedUrl("VideoPlayer.qml"), {url: Qt.application.arguments[1], isLocal: true})
            }
        }
    }

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
                pageStack.push(urlPickerPage)
            }
        }

        Button {
            text: "About"
            width: streamButton.width
            onClicked: pageStack.push(Qt.resolvedUrl("About.qml"))
        }
    }

    Component {
        id: videoPickerPage
        FilePickerPage {
            onSelectedContentPropertiesChanged: {
                pageStack.push(Qt.resolvedUrl("VideoPlayer.qml"), {url: selectedContentProperties.filePath, isLocal: true})
            }
        }
    }

    Component {
        id: urlPickerPage
        Dialog {
            allowedOrientations: Orientation.All
//            acceptDestination: Qt.resolvedUrl("VideoPlayer.qml")

            onAccepted: pageStack.push(Qt.resolvedUrl("VideoPlayer.qml"), {url: urlField.text, isLocal: false})

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
        }

    }
}
