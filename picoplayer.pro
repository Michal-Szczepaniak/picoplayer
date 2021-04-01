TARGET = picoplayer

CONFIG += link_pkgconfig sailfishapp
PKGCONFIG += \
    dbus-1 \
    dbus-glib-1

QT += dbus

HEADERS += \
    src/filehelper.h \
    src/volume/pulseaudiocontrol.h

SOURCES += \
    src/filehelper.cpp \
    src/picoplayer.cpp \
    src/volume/pulseaudiocontrol.cpp

DISTFILES += qml/picoplayer.qml \
    qml/cover/CoverPage.qml \
    qml/dialogs/UrlStreamPickerDialog.qml \
    qml/pages/Main.qml \
    qml/pages/VideoPlayer.qml \
    qml/pages/About.qml \
    rpm/picoplayer.spec \
    translations/*.ts \
    picoplayer.desktop

RESOURCES += \
    qml/resources/resources.qrc

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172

CONFIG += sailfishapp_i18n

TRANSLATIONS += \
    translations/picoplayer-fr.ts \
    translations/picoplayer-zh_CN.ts \
    translations/picoplayer-es.ts
