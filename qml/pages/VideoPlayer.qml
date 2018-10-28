import QtQuick 2.0
import Sailfish.Silica 1.0
import QtMultimedia 5.6
import Sailfish.Media 1.0
import org.nemomobile.mpris 1.0
import com.jolla.settings.system 1.0
import org.nemomobile.systemsettings 1.0


Page {
    id: page

    allowedOrientations: Orientation.All
    showNavigationIndicator: _controlsVisible

    property string url
    property bool isLocal
    property bool _controlsVisible: true
    property int autoBrightness: -1
    property int inactiveBrightness: -1
    property int activeBrightness: -1

    DisplaySettings {
        id: displaySettings
    }

    Timer {
        id: hideControlsAutomatically
        interval: 3000
        running: false
        repeat: false
        onTriggered: _controlsVisible = false
    }

    Timer {
        id: hideVolumeSlider
        interval: 500
        running: false
        repeat: false
        onTriggered: volumeSlider.visible = false
    }

    Timer {
        id: hideBrightnessSlider
        interval: 500
        running: false
        repeat: false
        onTriggered: brightnessSlider.visible = false
    }

    Component.onDestruction: {
        displaySettings.autoBrightnessEnabled = autoBrightness
        displaySettings.brightness = inactiveBrightness
    }

    Component.onCompleted: {
        showHideControls()
        hideControlsAutomatically.restart()
        autoBrightness = displaySettings.autoBrightnessEnabled
        displaySettings.autoBrightnessEnabled = false
        inactiveBrightness = displaySettings.brightness
    }

    function showHideControls() {
        if (_controlsVisible) {
            showAnimation.start()
            hideControlsAutomatically.restart()
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

    Connections {
        target: pacontrol
        onVolumeChanged: {
            volumeSlider.value = volume
        }
    }

    Connections {
        target: Qt.application
        onStateChanged: {
            if ( state === Qt.ApplicationInactive ) {
                displaySettings.autoBrightnessEnabled = autoBrightness
                activeBrightness = brightnessSlider.value * mousearea.brightnessStep
                displaySettings.brightness = inactiveBrightness
            } else if ( state === Qt.ApplicationActive ) {
                displaySettings.autoBrightnessEnabled = false
                displaySettings.brightness = activeBrightness
            }
        }
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

                onPositionChanged: progressBar.value = mediaPlayer.position
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
                    id: mousearea
                    anchors.fill: videoOutput
                    property int offset: page.height/20
                    property int offsetHeight: height - (offset*2)
                    property int step: offsetHeight / 10
                    property int brightnessStep: displaySettings.maximumBrightness / 10
                    property int lambdaVolumeStep: -1
                    property int lambdaBrightnessStep: -1

                    function calculateStep(mouse) {
                        return Math.round((offsetHeight - (mouse.y-offset)) / step)
                    }

                    onReleased: {
                        if(lambdaVolumeStep === -1 && lambdaBrightnessStep === -1)
                            _controlsVisible = !_controlsVisible
                        lambdaVolumeStep = -1
                        lambdaBrightnessStep = -1
                    }

                    onPositionChanged: {
                        var step = calculateStep(mouse)
                        if((mouse.y - offset) > 0 && (mouse.y - offset) < offsetHeight && mouse.x < mousearea.width/2 && lambdaVolumeStep !== step) {
                            lambdaVolumeStep = step
                            pacontrol.setVolume(lambdaVolumeStep)
                            volumeSlider.value = lambdaVolumeStep
                            volumeSlider.visible = true
                            hideVolumeSlider.restart()
                        } else if ((mouse.y - offset) > 0 && (mouse.y - offset) < offsetHeight && mouse.x > mousearea.width/2 && lambdaBrightnessStep !== step) {
                            lambdaBrightnessStep = step
                            displaySettings.brightness = lambdaBrightnessStep * brightnessStep
                            brightnessSlider.value = lambdaBrightnessStep
                            brightnessSlider.visible = true
                            hideBrightnessSlider.restart()
                        }
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
                    id: volumeSlider
                    visible: false
                    x: page.width - height
                    y: page.height
                    width: page.height
                    minimumValue: 0
                    maximumValue: 10
                    transform: Rotation { angle: -90}
                    enabled: false

                    Behavior on opacity {
                        PropertyAction {}
                    }
                }

                Slider {
                    id: brightnessSlider
                    visible: false
                    x: 0
                    y: page.height
                    width: page.height
                    transform: Rotation { angle: -90}
                    enabled: false
                    maximumValue: 10
                    minimumValue: 0
                    onValueChanged: {
                        activeBrightness = value
                    }

                    Behavior on opacity {
                        PropertyAction {}
                    }
                }

                Slider {
                    id: progressBar
                    minimumValue: 0
                    maximumValue: mediaPlayer.duration
                    anchors.left: progress.right
                    anchors.right: duration.left
                    anchors.bottom: videoOutput.bottom
                    visible: _controlsVisible

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

                    onReleased: mediaPlayer.seek(progressBar.value)
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

        serviceName: "picoplayer"
        property string title: mediaPlayer.metaData.title ? mediaPlayer.metaData.title : "picoplayer"
        property var playbackState: Mpris.Playing


        Component.onCompleted: {
            title = mediaPlayer.metaData.title !== undefined ? mediaPlayer.metaData.title : "picoplayer"
        }

        onTitleChanged: {
            var metadata = mprisPlayer.metadata

            metadata[Mpris.metadataToString(Mpris.Title)] = title // String

            mprisPlayer.metadata = metadata
        }

        identity: "picoplayer"

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
