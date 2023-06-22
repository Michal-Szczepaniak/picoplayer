#include <sailfishapp.h>
#include <QtQuick>
#include "player/player.h"
#include "volume/pulseaudiocontrol.h"
#include "filehelper.h"
#include <execinfo.h>
#include <unistd.h>
#include <cxxabi.h>

void handler(int sig) {
    void *array[10];
    size_t size;

    size = backtrace(array, 10);

    fprintf(stderr, "Error: signal %d:\n", sig);
    backtrace_symbols_fd(array, size, STDERR_FILENO);
    exit(1);
}

int main(int argc, char *argv[])
{
    signal(SIGSEGV, handler);
    signal(SIGABRT, handler);
    gst_init (&argc, &argv);

    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
    QSharedPointer<QQuickView> view(SailfishApp::createView());

    PulseAudioControl pacontrol;
    view->rootContext()->setContextProperty("pacontrol", &pacontrol);

    FileHelper fileHelper;
    view->rootContext()->setContextProperty("fileHelper", &fileHelper);


    qmlRegisterType<VideoPlayer>("com.verdanditeam.yt", 1, 0, "VideoPlayer");

    view->setSource(SailfishApp::pathTo("qml/picoplayer.qml"));
    view->show();

    return app->exec();
}
