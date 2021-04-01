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

            property var _unfocusedOpacity: 1.0
            property alias contextMenu: contextMenuItem
            property Item expandItem
            property real expandHeight: contextMenu.height
            property int minOffsetIndex: expandItem != null
                                         ? expandItem.modelIndex + (4-Math.floor(scale.scale)) - (expandItem.modelIndex % (4-Math.floor(scale.scale)))
                                         : 0

            ContextMenu {
                id: contextMenuItem
                x: parent !== null ? -parent.x : 0.0

                MenuItem {
                    text: qsTr("Delete")
                    onClicked: gridView.expandItem.remove()
                }
            }

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

            delegate: ThumbnailImage {
                id: thumbnail
                source: resizeAnimation.running ? "" : model.url
                size: gridView.cellWidth
                height: isItemExpanded ? grid.contextMenu.height + grid.cellWidth : grid.cellWidth
                contentYOffset: index >= grid.minOffsetIndex ? grid.expandHeight : 0.0
                anchors.bottomMargin: isItemExpanded ? grid.contextMenu.height : 0
                z: isItemExpanded ? 1000 : 1

                property bool isItemExpanded: grid.expandItem === thumbnail
                property int modelIndex: index

                onClicked: pageStack.push(videoPlayerPage, {url: videosModel.get(index).url, isLocal: true})
                onPressAndHold: {
                    grid.expandItem = thumbnail
                    gridView.contextMenu.open(thumbnail)
                }

                function remove() {
                    var remorse = removalComponent.createObject(null)
                    remorse.z = thumbnail.z + 1

                    remorse.execute(remorseContainerComponent.createObject(thumbnail),
                                    remorse.text,
                                    function() {
                                        fileHelper.deleteFile(videosModel.get(index).url)
                                    })
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottomMargin: isItemExpanded ? grid.contextMenu.height : 0

                    color: parent.down ? Theme.rgba(Theme.highlightBackgroundColor, Theme.highlightBackgroundOpacity) : "transparent"
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: isItemExpanded ? grid.contextMenu.height : 0
                    width: parent.width
                    height: parent.height / 2
                    opacity: Theme.opacityOverlay
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Theme.highlightDimmerColor }
                    }
                }

                Label {
                    id: durationLabel
                    text: model.duration > 3600 ? formatter.formatDuration(model.duration, Formatter.DurationLong) : formatter.formatDuration(model.duration, Formatter.DurationShort)

                    font {
                        pixelSize: Theme.fontSizeSmall
                    }
                    anchors.bottom: titleLabel.top
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.paddingMedium
                }

                Label {
                    id: titleLabel
                    text: model.title

                    font {
                        pixelSize: Theme.fontSizeExtraSmall
                    }
                    color: Theme.highlightColor
                    truncationMode: TruncationMode.Elide
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: isItemExpanded ? grid.contextMenu.height + Theme.paddingMedium : Theme.paddingMedium
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.paddingMedium
                    anchors.right: parent.right
                }
            }
        }
    }

    Component {
        id: remorseContainerComponent
        Item {
            y: parent.contentYOffset
            width: parent.width
            height: parent.height
        }
    }

    Component {
        id: removalComponent
        RemorseItem {
            objectName: "remorseItem"
            font.pixelSize: Theme.fontSizeSmallBase
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
