#include <sailfishapp.h>
#include <QtQuick>
#include "volume/pulseaudiocontrol.h"
#include "filehelper.h"

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
    QSharedPointer<QQuickView> view(SailfishApp::createView());

    PulseAudioControl pacontrol;
    pacontrol.setVolume(5);
    view->rootContext()->setContextProperty("pacontrol", &pacontrol);

    FileHelper fileHelper;
    view->rootContext()->setContextProperty("fileHelper", &fileHelper);

    view->setSource(SailfishApp::pathTo("qml/picoplayer.qml"));
    view->show();

    return app->exec();
}
