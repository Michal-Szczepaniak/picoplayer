import QtQuick 2.0
import Sailfish.Silica 1.0
import "pages"

ApplicationWindow
{
    id: app
    initialPage: Component { Main { } }
    cover: !videoCover ? Qt.resolvedUrl("cover/CoverPage.qml") : null
    allowedOrientations: Orientation.All
    property bool videoCover: false
}
