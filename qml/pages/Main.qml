import QtQuick 2.5
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0
import QtDocGallery 5.0
import Sailfish.Gallery 1.0
import Nemo.Configuration 1.0

Page {
    id: page

    allowedOrientations: Orientation.All
    property bool startup: true
    property bool landsacape: (page.orientation === Orientation.Landscape || page.orientation === Orientation.LandscapeInverted)

    onStatusChanged: {
        if(status === PageStatus.Active && startup === true) {
            startup = false
            if(typeof Qt.application.arguments[1] !== "undefined") {
                pageStack.push(Qt.resolvedUrl("VideoPlayer.qml"), {url: Qt.application.arguments[1], isLocal: true})
            }
        }
    }

    ConfigurationGroup {
        id: settings
        path: "/apps/picoplayer"

        property real scale: 2
    }


    DocumentGalleryModel {
        id: videosModel

        rootType: DocumentGallery.Video
        autoUpdate: true
        properties: ["url", "title", "lastModified", "duration"]
        sortProperties: ["-lastModified"]
        filter: GalleryStartsWithFilter { property: "title"; value: searchField.text.toLowerCase().trim() }
    }

    Formatter {
        id: formatter
    }

    SilicaFlickable {
        id: flickable
        anchors.fill: parent

        MultiPointTouchArea {
            id: multiPointTouchArea
            anchors.fill: parent
            minimumTouchPoints: 1
            maximumTouchPoints: 2
            onTouchUpdated: (touchPoints.length === 2) ? pullDownMenu.enabled = false : pullDownMenu.enabled = true

            PinchArea {
                id: pinchArea
                MouseArea{ anchors.fill: parent; propagateComposedEvents: true }
                enabled: true
                pinch.target: scale
                pinch.maximumScale: 2
                pinch.minimumScale: 0
                anchors.fill: parent
            }
        }


        Item {
            id: scale
            scale: settings.scale
            onScaleChanged: {
                if  (Math.round(scale.scale) !== settings.scale)
                    settings.scale = scale.scale
            }
        }


        PageHeader {
            id: pageHeader
            title: "Pico Player"
        }

        SearchField {
            id: searchField
            anchors.top: pageHeader.bottom
            width: parent.width
        }

        PullDownMenu {
            id: pullDownMenu
            enabled: !pinchArea.pinch.active
            onEnabledChanged: console.log(enabled)

            MenuItem {
                text: qsTr("About")
                onClicked: pageStack.push(Qt.resolvedUrl("About.qml"))
            }

            MenuItem {
                id: streamButton
                text: qsTr("Open URL Stream…")
                onClicked: {
                    pageStack.push(urlPickerPage)
                }
            }

            MenuItem {
                text: qsTr("Open file…")
                onClicked: pageStack.push(filePickerPage)
            }
        }

        SilicaGridView {
            id: gridView
            model: videosModel
            enabled: !pinchArea.pinch.active

            anchors.top: searchField.bottom
            width: parent.width
            height: parent.height - pageHeader.height - searchField.height

            cellWidth: landsacape ? Screen.height / Math.round(Screen.height / (Screen.width/(4-Math.floor(scale.scale)))) :  Screen.width/(4-Math.floor(scale.scale))
            cellHeight: cellWidth
            clip: true

            Behavior on cellWidth {
                PropertyAnimation {
                    id: resizeAnimation
                    easing.type: Easing.InOutQuad;
                    easing.amplitude: 2.0;
                    easing.period: 1.5
                }
            }

            ViewPlaceholder {
                text: qsTrId("No videos")
                enabled: videosModel.count === 0
            }

            delegate: ThumbnailVideo {
                id: thumbnail
                title: model.title
                source: resizeAnimation.running ? "" : model.url
                size: gridView.cellWidth
                duration: model.duration > 3600 ? formatter.formatDuration(model.duration, Formatter.DurationLong) : formatter.formatDuration(model.duration, Formatter.DurationShort)
                onClicked: pageStack.push(videoPlayerPage, {url: videosModel.get(index).url, isLocal: true})


                Rectangle {
                    anchors.fill: parent

                    color: parent.down ? Theme.rgba(Theme.highlightBackgroundColor, Theme.highlightBackgroundOpacity) : "transparent"
                }
            }
        }
    }

    Component {
        id: filePickerPage
        FilePickerPage {
            allowedOrientations: Orientation.All

            onSelectedContentPropertiesChanged: {
                pageStack.push(Qt.resolvedUrl("VideoPlayer.qml"), {url: selectedContentProperties.filePath, isLocal: true})
            }
        }
    }

    Component {
        id: urlPickerPage
        Dialog {
            allowedOrientations: Orientation.All

            onAccepted: pageStack.push(Qt.resolvedUrl("VideoPlayer.qml"), {url: urlField.text, isLocal: false})

            Column {
                width: parent.width

                DialogHeader { }

                TextField {
                    id: urlField
                    width: parent.width
                    placeholderText: "https://…"
                    label: qsTr("Stream URL")
                    focus: true
                }
            }
        }
    }

    VideoPlayer {
        id: videoPlayerPage
    }
}
