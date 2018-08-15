import QtQuick 2.0
import Sailfish.Silica 1.0
import QtMultimedia 5.6
import Sailfish.Media 1.0
import org.nemomobile.mpris 1.0

Page {
    id: page

    allowedOrientations: Orientation.All
    showNavigationIndicator: !(!_controlsVisible && page.orientation === Orientation.Landscape)

    property string url
    property bool isLocal
    property bool _controlsVisible: true

    Component.onCompleted: mediaPlayer.videoPlay()

    function showHideControls() {
        if (_controlsVisible) {
            showAnimation.start()
        } else {
            hideAnimation.start()
        }

        if ((_controlsVisible && page.orientation === Orientation.Landscape) || page.orientation === Orientation.Portrait)
            showAnimation3.start()
        else
            hideAnimation3.start()
    }

    onOrientationChanged: {

        if ((_controlsVisible && page.orientation === Orientation.Landscape) || page.orientation === Orientation.Portrait)
            showAnimation3.start()
        else
            hideAnimation3.start()
    }

    on_ControlsVisibleChanged: {
        showHideControls()
    }

    SilicaFlickable {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "black"

            MediaPlayer {
                id: mediaPlayer
                source: url.trim()

                function videoPlay() {
                    videoPlaying = true
                    if (mediaPlayer.bufferProgress == 1) {
                        mediaPlayer.play()
                    } else if (isLocal) {
                        mediaPlayer.play()
                    }
                }

                function videoPause() {
                    videoPlaying = false
                    mediaPlayer.pause()
                }

                property bool videoPlaying: false
                property string errorMsg: ""

                onPlaybackStateChanged: {
                    if (mediaPlayer.playbackState == MediaPlayer.StoppedState) {
                        app.playing = ""
                    }

                    mprisPlayer.playbackState = mediaPlayer.playbackState === MediaPlayer.PlayingState ?
                                Mpris.Playing : mediaPlayer.playbackState === MediaPlayer.PausedState ?
                                    Mpris.Paused : Mpris.Stopped
                }

                onError: {
                    if ( error === MediaPlayer.ResourceError ) errorMsg = "Error: Problem with allocating resources"
                    else if ( error === MediaPlayer.ServiceMissing ) errorMsg = "Error: Media service error"
                    else if ( error === MediaPlayer.FormatError ) errorMsg = "Error: Video or Audio format is not supported"
                    else if ( error === MediaPlayer.AccessDenied ) errorMsg = "Error: Access denied to the video"
                    else if ( error === MediaPlayer.NetworkError ) errorMsg = "Error: Network error"
                    stop()
                }

                onBufferProgressChanged: {
                    if (!isLocal && videoPlaying && mediaPlayer.bufferProgress == 1) {
                        mediaPlayer.play();
                    }

                    if (!isLocal && mediaPlayer.bufferProgress == 0) {
                        mediaPlayer.pause();
                    }
                }

                onPositionChanged: proggress.value = mediaPlayer.position
            }

            VideoOutput {
                id: videoOutput
                anchors.fill: parent
                width : page.width
                height: page.width/1.777777777777778
                source: mediaPlayer

                Rectangle {
                    id: errorPane
                    z: 99
                    anchors.fill: parent
                    color: Theme.rgba("black", 0.8)
                    visible: mediaPlayer.errorMsg !== ""
                    Label {
                        id: errorText
                        text: mediaPlayer.errorMsg
                        visible: parent.visible
                        anchors.centerIn: parent
                        font.pixelSize: Theme.fontSizeExtraLarge
                        font.family: Theme.fontFamilyHeading
                    }
                }

                BusyIndicator {
                    size: BusyIndicatorSize.Large
                    anchors.centerIn: parent
                    running: !isLocal && mediaPlayer.bufferProgress != 1
                }

                MouseArea {
                    anchors.fill: videoOutput
                    onClicked: {
                        _controlsVisible = !_controlsVisible
                    }
                }

                Label {
                    id: progress
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: Theme.paddingLarge
                    text:  Format.formatDuration(Math.round(mediaPlayer.position/1000), Formatter.DurationShort)
                }

                Label {
                    id: duration
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Theme.paddingLarge
                    text: Format.formatDuration(Math.round(mediaPlayer.duration/1000), Formatter.DurationShort)
                }

                NumberAnimation {
                    id: showAnimation
                    targets: [progress, duration, playButton]
                    properties: "opacity"
                    to: 1
                    duration: 100
                }
                NumberAnimation {
                    id: hideAnimation
                    targets: [progress, duration, playButton]
                    properties: "opacity"
                    to: 0
                    duration: 100
                }

                IconButton {
                    id: playButton
                    enabled: opacity != 0
                    icon.source: mediaPlayer.playbackState == MediaPlayer.PlayingState ? "image://theme/icon-m-pause" : "image://theme/icon-m-play"
                    anchors.centerIn: parent
                    onClicked: mediaPlayer.playbackState == MediaPlayer.PlayingState ? mediaPlayer.videoPause() : mediaPlayer.videoPlay()
                }

                Slider {
                    id: proggress
                    minimumValue: 0
                    maximumValue: mediaPlayer.duration
                    anchors.left: videoOutput.left
                    anchors.right: videoOutput.right
                    anchors.bottom: videoOutput.bottom
                    visible: _controlsVisible

                    Behavior on value {
                        NumberAnimation {
                            duration: 10
                        }
                    }

                    NumberAnimation on opacity {
                        id: showAnimation3
                        to: 1
                        duration: 100

                    }
                    NumberAnimation on opacity {
                        id: hideAnimation3
                        to: 0
                        duration: 100
                    }

                    onValueChanged: down && mediaPlayer.seek(proggress.value)
                }
            }

            ScreenBlank {
                suspend: mediaPlayer.playbackState == MediaPlayer.PlayingState
            }
        }
    }


    CoverActionList {
        id: coverAction
        enabled: mediaPlayer.playbackState !== MediaPlayer.StoppedState

        CoverAction {
            iconSource: mediaPlayer.playbackState == MediaPlayer.PlayingState ? "image://theme/icon-cover-pause" : "image://theme/icon-cover-play"
            onTriggered: {
                mediaPlayer.playbackState == MediaPlayer.PlayingState ? mediaPlayer.videoPause() : mediaPlayer.videoPlay()
            }
        }
    }

    MprisPlayer {
        id: mprisPlayer

        serviceName: "microtube"
        property string title: ""
        property var playbackState: Mpris.Playing

        onTitleChanged: {
            var metadata = mprisPlayer.metadata

            metadata[Mpris.metadataToString(Mpris.Title)] = song // String

            mprisPlayer.metadata = metadata
        }

        identity: "microtube"

        canControl: true

        canGoNext: false
        canGoPrevious: false
        canPause: true
        canPlay: true
        canSeek: true

        playbackStatus: playbackState

        loopStatus: Mpris.None
        shuffle: false
        volume: 1

        onPauseRequested: {
            console.log("pause")
            mediaPlayer.videoPause()
        }

        onPlayRequested: {
            console.log("play")
            mediaPlayer.videoPlay()
        }

        onPlayPauseRequested: {
            console.log("pauseplay")
            mediaPlayer.playbackState == MediaPlayer.PlayingState ? mediaPlayer.videoPause() : mediaPlayer.videoPlay()
        }

        onStopRequested: {
            console.log("stop")
            mediaPlayer.stop()
        }

        onSeekRequested: {
            mediaPlayer.seek(offset)
        }
    }
}
