project(picoplayer CXX)
cmake_minimum_required(VERSION 3.5)
include(CMakeDependentOption)

find_package(PkgConfig)

pkg_search_module(SAILFISH sailfishapp)
cmake_dependent_option(TARGET_SAILFISH "Is target SailfishOS" ON "SAILFISH_FOUND" OFF)
if (TARGET_SAILFISH)
    message(STATUS "Building for SailfishOS")
else()
    message(STATUS "Building for linux")
endif()

find_package(Qt5 COMPONENTS Core Network Qml Gui Quick DBus Sql OpenGL OpenGLExtensions LinguistTools REQUIRED)
find_package(DBus1 REQUIRED)

pkg_search_module(GLIB glib-2.0 REQUIRED)
pkg_search_module(DBUSGLIB dbus-glib-1 REQUIRED)
pkg_search_module(GSTREAMER gstreamer-1.0 REQUIRED)
pkg_search_module(GSTREAMER_PLAYER gstreamer-player-1.0 REQUIRED)
pkg_search_module(GSTREAMER_VIDEO gstreamer-video-1.0 REQUIRED)
pkg_search_module(EGL egl REQUIRED)
pkg_search_module(OPENGL_EXTENSIONS Qt5OpenGLExtensions REQUIRED)

if (TARGET_SAILFISH)
    find_package(Qt5 COMPONENTS SystemInfo REQUIRED)

    pkg_search_module(AUDIORESOURCE audioresource-qt REQUIRED)
    pkg_search_module(NEMO_GSTREAMER_INTERFACES nemo-gstreamer-interfaces-1.0 REQUIRED)
endif()

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

file(GLOB TsFiles "translations/*.ts")
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/translations)
set_source_files_properties(${TsFiles} PROPERTIES OUTPUT_LOCATION "translations/")
qt5_create_translation(QM_FILES ${TsFiles})

file( GLOB_RECURSE SOURCES src/*.cpp )
file( GLOB_RECURSE HEADERS src/*.h )
add_executable(picoplayer
    ${SOURCES}
    ${HEADERS}
    qml/resources/resources.qrc
    ${QM_FILES}
    )
target_compile_definitions(picoplayer PRIVATE
    $<$<OR:$<CONFIG:Debug>,$<CONFIG:RelWithDebInfo>>:QT_QML_DEBUG>
)

target_include_directories(picoplayer PRIVATE
    $<BUILD_INTERFACE:
    src
    ${GLIB_INCLUDE_DIRS}
    ${DBUSGLIB_INCLUDE_DIRS}
    ${SAILFISH_INCLUDE_DIRS}
    ${AUDIORESOURCE_INCLUDE_DIRS}
    ${GSTREAMER_INCLUDE_DIRS}
    ${GSTREAMER_PLAYER_INCLUDE_DIRS}
    ${GSTREAMER_VIDEO_INCLUDE_DIRS}
    ${EGL_INCLUDE_DIRS}
    >)
target_link_libraries(picoplayer PUBLIC
    Qt5::Quick
    Qt5::DBus
    Qt5::Gui
    Qt5::Sql
    Qt5::OpenGL
    Qt5::OpenGLExtensions
    $<$<CONFIG:TARGET_SAILFISH>:Qt5::SystemInfo>
    ${DBus1_LDFLAGS}
    ${GLIB_LDFLAGS}
    ${DBUSGLIB_LDFLAGS}
    ${SAILFISH_LDFLAGS}
    ${AUDIORESOURCE_LDFLAGS}
    ${GSTREAMER_LDFLAGS}
    ${GSTREAMER_PLAYER_LDFLAGS}
    ${GSTREAMER_VIDEO_LDFLAGS}
    ${EGL_LDFLAGS}
    ${OPENGL_EXTENSIONS_STATIC_LDFLAGS}
    ${NEMO_GSTREAMER_INTERFACES_LDFLAGS}
)
target_compile_options(picoplayer PUBLIC
    ${EGL_CFLAGS_OTHER}
)
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -O0")
set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} -O0")

install(TARGETS picoplayer
    RUNTIME DESTINATION bin
)
install(DIRECTORY qml
    DESTINATION share/picoplayer
)
install(DIRECTORY js
    DESTINATION share/picoplayer
)
install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/translations
    DESTINATION share/picoplayer
    FILES_MATCHING PATTERN "*.qm"
)
install(FILES picoplayer.desktop picoplayer-url.desktop
    DESTINATION share/applications
)
install(FILES icons/86x86/picoplayer.png
    DESTINATION share/icons/hicolor/86x86/apps
)
install(FILES icons/108x108/picoplayer.png
    DESTINATION share/icons/hicolor/108x108/apps
)
install(FILES icons/128x128/picoplayer.png
    DESTINATION share/icons/hicolor/128x128/apps
)
install(FILES icons/172x172/picoplayer.png
    DESTINATION share/icons/hicolor/172x172/apps
)

file(GLOB_RECURSE QML_FILES qml/*.qml)

add_custom_target(distfiles
    SOURCES
        picoplayer.desktop
        rpm/picoplayer.spec
        ${QML_FILES}
        ${TsFiles})

file(WRITE "${CMAKE_BINARY_DIR}/QtCreatorDeployment.txt"
    "${CMAKE_INSTALL_PREFIX}
${CMAKE_BINARY_DIR}/picoplayer:bin
")

