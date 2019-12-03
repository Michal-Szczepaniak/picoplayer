import QtQuick 2.0
import Sailfish.Silica 1.0
import QtMultimedia 5.6
import Sailfish.Media 1.0
import org.nemomobile.mpris 1.0
import com.jolla.settings.system 1.0
import org.nemomobile.systemsettings 1.0
import Nemo.KeepAlive 1.2


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
    property bool landscape: true
    property bool fillMode: false

    DisplaySettings {
        id: displaySettings
        onBrightnessChanged: {
            if (inactiveBrightness === -1) {
                inactiveBrightness = brightness
                activeBrightness = brightness
                autoBrightness = displaySettings.autoBrightnessEnabled
                displaySettings.autoBrightnessEnabled = false
            }
        }
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
        onTriggered: {
            volumeSlider.visible = false
            volumeIndicator.visible = false
        }
    }

    Timer {
        id: hideBrightnessSlider
        interval: 500
        running: false
        repeat: false
        onTriggered: {
            brightnessSlider.visible = false
            brightnessIndicator.visible = false
        }
    }

    Component.onDestruction: {
        displaySettings.autoBrightnessEnabled = autoBrightness
        displaySettings.brightness = inactiveBrightness
    }

    Component.onCompleted: {
        Theme.setColorScheme("dark")
        showHideControls()
        hideControlsAutomatically.restart()
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
                    if ( error === MediaPlayer.ResourceError ) errorMsg = qsTr("Error: Problem with allocating resources")
                    else if ( error === MediaPlayer.ServiceMissing ) errorMsg = qsTr("Error: Media service error")
                    else if ( error === MediaPlayer.FormatError ) errorMsg = qsTr("Error: Video or Audio format is not supported")
                    else if ( error === MediaPlayer.AccessDenied ) errorMsg = qsTr("Error: Access denied to the video")
                    else if ( error === MediaPlayer.NetworkError ) errorMsg = qsTr("Error: Network error")
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

                onPositionChanged: progressSlider.value = mediaPlayer.position
            }

            VideoOutput {
                id: videoOutput
                width : page.width
                source: mediaPlayer
                anchors.centerIn: parent
                height: landscape ? (page.fillMode ? page.width : page.height) : page.width/1.777777777777778


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
                    property bool stepChanged: false
                    property int brightnessStep: displaySettings.maximumBrightness / 10
                    property int lambdaVolumeStep: -1
                    property int lambdaBrightnessStep: -1
                    property int currentVolume: -1

                    Timer{
                        id: doubleClickTimer
                        interval: 200
                    }

                    function calculateStep(mouse) {
                        return Math.round((offsetHeight - (mouse.y-offset)) / step)
                    }

                    onReleased: {
                        if (doubleClickTimer.running) doubleClicked(mouse)
                        if (!doubleClickTimer.running) doubleClickTimer.start()
                        if (!stepChanged) _controlsVisible = !_controlsVisible

                        if ( landscape ) {
                            lambdaVolumeStep = -1
                            lambdaBrightnessStep = -1
                            stepChanged = false
                        }
                    }

                    onPressed: {
                        if ( landscape ) {
                            pacontrol.update()
                            lambdaBrightnessStep = lambdaVolumeStep = calculateStep(mouse)
                        }
                    }

                    function doubleClicked(mouse) {
                        if ( landscape ) {
                            var newPos = null
                            if(mouse.x < mousearea.width/2 ) {
                                newPos = mediaPlayer.position - 5000
                                if(newPos < 0) newPos = 0
                                mediaPlayer.seek(newPos)
                                backwardIndicator.visible = true
                            } else if (mouse.x > mousearea.width/2) {
                                newPos = mediaPlayer.position + 5000
                                if(newPos > mediaPlayer.duration) {
                                    mediaPlayer.nextVideo()
                                    return
                                }
                                mediaPlayer.seek(newPos)
                                forwardIndicator.visible = true
                            }
                        }
                    }

                    Connections {
                        target: pacontrol
                        onVolumeChanged: {
                            mousearea.currentVolume = volume
                            if (volume > 10) {
                                mousearea.currentVolume = 10
                            } else if (volume < 0) {
                                mousearea.currentVolume = 0
                            }
                        }
                    }

                    onPositionChanged: {
                        if ( landscape ) {
                            var step = calculateStep(mouse)
                            if((mouse.y - offset) > 0 && (mouse.y + offset) < offsetHeight && mouse.x < mousearea.width/2 && lambdaVolumeStep !== step) {
                                pacontrol.setVolume(currentVolume - (lambdaVolumeStep - step))
                                volumeSlider.value = currentVolume - (lambdaVolumeStep - step)
                                lambdaVolumeStep = step
                                volumeSlider.visible = true
                                volumeIndicator.visible = true
                                hideVolumeSlider.restart()
                                pacontrol.update()
                                stepChanged = true
                            } else if ((mouse.y - offset) > 0 && (mouse.y + offset) < offsetHeight && mouse.x > mousearea.width/2 && lambdaBrightnessStep !== step) {
                                var relativeStep = Math.round(displaySettings.brightness/brightnessStep) - (lambdaBrightnessStep - step)
                                if (relativeStep > 10) relativeStep = 10;
                                if (relativeStep < 0) relativeStep = 0;
                                displaySettings.brightness = relativeStep * brightnessStep
                                activeBrightness = relativeStep * brightnessStep
                                lambdaBrightnessStep = step
                                brightnessSlider.value = relativeStep
                                brightnessSlider.visible = true
                                brightnessIndicator.visible = true
                                hideBrightnessSlider.restart()
                                stepChanged = true
                            }
                        }
                    }
                }

                Row {
                    id: volumeIndicator
                    anchors.centerIn: parent
                    visible: false
                    spacing: Theme.paddingLarge

                    Image {
                        width: Theme.itemSizeLarge
                        height: Theme.itemSizeLarge
                        source: "image://theme/icon-m-speaker-on"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Label {
                        text: (mousearea.currentVolume * 10) + "%"
                        font.pixelSize: Theme.fontSizeHuge
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    id: brightnessIndicator
                    anchors.centerIn: parent
                    visible: false
                    spacing: Theme.paddingLarge

                    Image {
                        width: Theme.itemSizeLarge
                        height: Theme.itemSizeLarge
                        source: "image://theme/icon-m-light-contrast"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Label {
                        text: (Math.round(displaySettings.brightness/mousearea.brightnessStep) * 10) + "%"
                        font.pixelSize: Theme.fontSizeHuge
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    id: backwardIndicator
                    anchors.centerIn: parent
                    visible: false
                    spacing: -Theme.paddingLarge*2

                    Image {
                        id: prev1
                        width: Theme.itemSizeLarge
                        height: Theme.itemSizeLarge
                        anchors.verticalCenter: parent.verticalCenter
                        fillMode: Image.PreserveAspectFit
                        source: "image://theme/icon-cover-play"

                        transform: Rotation{
                            angle: 180
                            origin.x: prev1.width/2
                            origin.y: prev1.height/2
                        }
                    }
                    Image {
                        id: prev2
                        width: Theme.itemSizeLarge
                        height: Theme.itemSizeLarge
                        anchors.verticalCenter: parent.verticalCenter
                        fillMode: Image.PreserveAspectFit
                        source: "image://theme/icon-cover-play"

                        transform: Rotation{
                            angle: 180
                            origin.x: prev2.width/2
                            origin.y: prev2.height/2
                        }
                    }

                    Timer {
                        id: hideBackward
                        interval: 300
                        onTriggered: backwardIndicator.visible = false
                    }

                    onVisibleChanged: if (backwardIndicator.visible) hideBackward.start()
                }

                Row {
                    id: forwardIndicator
                    anchors.centerIn: parent
                    visible: false
                    spacing: -Theme.paddingLarge*2

                    Image {
                        width: Theme.itemSizeLarge
                        height: Theme.itemSizeLarge
                        anchors.verticalCenter: parent.verticalCenter
                        fillMode: Image.PreserveAspectFit
                        source: "image://theme/icon-cover-play"

                    }
                    Image {
                        width: Theme.itemSizeLarge
                        height: Theme.itemSizeLarge
                        anchors.verticalCenter: parent.verticalCenter
                        fillMode: Image.PreserveAspectFit
                        source: "image://theme/icon-cover-play"
                    }

                    Timer {
                        id: hideForward
                        interval: 300
                        onTriggered: forwardIndicator.visible = false
                    }

                    onVisibleChanged: if (forwardIndicator.visible) hideForward.start()
                }

                NumberAnimation {
                    id: showAnimation
                    targets: [progress, duration, playButton, prevButton, nextButton, fillModeButton]
                    properties: "opacity"
                    to: 1
                    duration: 100
                }
                NumberAnimation {
                    id: hideAnimation
                    targets: [progress, duration, playButton, prevButton, nextButton, fillModeButton]
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

                IconButton {
                    id: nextButton
                    enabled: opacity != 0
                    icon.source: "image://theme/icon-m-next"
                    anchors.top: playButton.top
                    anchors.left: playButton.right
                    anchors.leftMargin: page.width/4 - playButton.width/2
                    onClicked: mediaPlayer.nextVideo()
                }

                IconButton {
                    id: prevButton
                    enabled: opacity != 0
                    icon.source: "image://theme/icon-m-previous"
                    anchors.top: playButton.top
                    anchors.right: playButton.left
                    anchors.rightMargin: page.width/4 - playButton.width/2
                    onClicked: mediaPlayer.prevVideo()
                }
            }

            DisplayBlanking {
                preventBlanking: mediaPlayer.playbackState == MediaPlayer.PlayingState
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

                Behavior on opacity {
                    PropertyAction {}
                }
            }

            Label {
                id: progress
                width: Theme.itemSizeExtraSmall
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Theme.paddingLarge
                text:  Format.formatDuration(Math.round(mediaPlayer.position/1000), ((mediaPlayer.duration/1000) > 3600 ? Formatter.DurationLong : Formatter.DurationShort))
            }

            Label {
                id: duration
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.paddingLarge
                text: Format.formatDuration(Math.round(mediaPlayer.duration/1000), ((mediaPlayer.duration/1000) > 3600 ? Formatter.DurationLong : Formatter.DurationShort))
            }

            Slider {
                id: progressSlider
                value: mediaPlayer.position
                minimumValue: 0
                maximumValue: mediaPlayer.duration
                anchors.bottom: parent.bottom
                x: progress.width
                width: parent.width - progress.width - duration.width
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

                onReleased: mediaPlayer.seek(progressSlider.value)
            }

            IconButton {
                id: fillModeButton
                visible: opacity != 0 && landscape
                icon.source: page.fillMode ? "image://theme/icon-m-scale" : "image://theme/icon-m-tablet"
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.paddingMedium
                onClicked: page.fillMode = !page.fillMode
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
