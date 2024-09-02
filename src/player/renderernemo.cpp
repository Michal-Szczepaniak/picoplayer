/*
 * gst-droid
 *
 * Copyright (C) 2014 Mohammed Sameer <msameer@foolab.org>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.    See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#include "renderernemo.h"
#include <QDebug>
#include <gst/video/video.h>
#include <QtOpenGL/QGLShaderProgram>
#include <gst/interfaces/nemoeglimagememory.h>
#include <QOpenGLContext>
#include <QOpenGLExtensions>

typedef void *EGLSyncKHR;
#define EGL_SYNC_FENCE_KHR                                             0x30F9

typedef EGLSyncKHR(EGLAPIENTRYP PFNEGLCREATESYNCKHRPROC)(EGLDisplay dpy, EGLenum type,
                                                            const EGLint *attrib_list);

PFNEGLCREATESYNCKHRPROC eglCreateSyncKHR = 0;

static const QString FRAGMENT_SHADER = ""
        "#extension GL_OES_EGL_image_external: enable\n"
        "uniform samplerExternalOES texture0;"
        "varying lowp vec2 fragTexCoord;"
        "void main() {"
        "    gl_FragColor = texture2D(texture0, fragTexCoord);"
        "}"
    "";

static const QString VERTEX_SHADER = ""
        "attribute highp vec4 inputVertex;"
        "attribute lowp vec2 textureCoord;"
        "uniform highp mat4 matrix;"
        "uniform highp mat4 matrixWorld;"
        "varying lowp vec2 fragTexCoord;"
        ""
        "void main() {"
        "    gl_Position = matrix * matrixWorld * inputVertex;"
        "    fragTexCoord = textureCoord;"
        "}"
    "";

QtCamViewfinderRendererNemo::QtCamViewfinderRendererNemo(QObject *parent) :
    QObject(parent),
    _sink(0),
    _queuedBuffer(nullptr),
    _currentBuffer(nullptr),
    _showFrameId(0),
    _buffersInvalidatedId(0),
    _notify(0),
    _needsInit(true),
    _program(0),
    _displaySet(false),
    _buffersInvalidated(false),
    _bufferChanged(false),
    _img(0) {

    _texCoords.resize(8);
    _vertexCoords.resize(8);

    _texCoords[0] = 0;             _texCoords[1] = 0;
    _texCoords[2] = 1;             _texCoords[3] = 0;
    _texCoords[4] = 1;             _texCoords[5] = 1;
    _texCoords[6] = 0;             _texCoords[7] = 1;

    for (int x = 0; x < 8; x++) {
        _vertexCoords[x] = 0;
    }
}

QtCamViewfinderRendererNemo::~QtCamViewfinderRendererNemo() {
    cleanup();

    if (_program) {
        delete _program;
        _program = 0;
    }

    if (_img) {
        delete _img;
        _img = 0;
    }
}

bool QtCamViewfinderRendererNemo::needsNativePainting() {
    return true;
}

void QtCamViewfinderRendererNemo::paint(const QMatrix4x4& matrix, const QRectF& viewport) {
    if (!_img) {
        QOpenGLContext *ctx = QOpenGLContext::currentContext();
        if (!ctx) {
            qCritical() << "No current OpenGL context";
            return;
        }

        if (!ctx->hasExtension("GL_OES_EGL_image")) {
            qCritical() << "GL_OES_EGL_image not supported";
            return;
        }

        _img = new QOpenGLExtension_OES_EGL_image;

        if (!_img->initializeOpenGLFunctions()) {
            qCritical() << "Failed to initialize GL_OES_EGL_image";
            delete _img;
            _img = 0;
            return;
        }
    }

    if (_dpy == EGL_NO_DISPLAY) {
        _dpy = eglGetCurrentDisplay();
    }

    if (_dpy == EGL_NO_DISPLAY) {
        qCritical() << "Failed to obtain EGL Display";
    }

    if (_sink && _dpy != EGL_NO_DISPLAY && !_displaySet) {
        g_object_set(G_OBJECT(_sink), "egl-display", _dpy, NULL);
        _displaySet = true;
    }

    QMutexLocker locker(&_frameMutex);
    if (!_queuedBuffer) {
        GstBuffer *currentBuffer = _currentBuffer;
        _currentBuffer = nullptr;

        locker.unlock();

        if (currentBuffer) {
            gst_buffer_unref(currentBuffer);
        }

        qDebug() << "No queued buffer";
        return;
    }

    if (_needsInit) {
        calculateProjectionMatrix(viewport);

        _needsInit = false;
    }

    if (!_program) {
        createProgram();
    }

    paintFrame(matrix);
}

void QtCamViewfinderRendererNemo::resize(const QSizeF& size) {
    if (size == _size) {
        return;
    }

    _size = size;

    _renderArea = QRectF();

    calculateVertexCoords();

    _needsInit = true;

    emit renderAreaChanged();
}

void QtCamViewfinderRendererNemo::reset() {
    QMutexLocker locker(&_frameMutex);

    destroyCachedTextures();
}

GstElement *QtCamViewfinderRendererNemo::sinkElement() {
    if (!_sink) {
        _sink = gst_element_factory_make("droideglsink",
                                            "QtCamViewfinderRendererNemoSink");
        if (!_sink) {
            qCritical() << "Failed to create droideglsink";
            return 0;
        }

        g_object_add_toggle_ref(G_OBJECT(_sink), (GToggleNotify)sink_notify, this);
        _displaySet = false;
    }

    _dpy = eglGetCurrentDisplay();
    if (_dpy == EGL_NO_DISPLAY) {
        qCritical() << "Failed to obtain EGL Display";
    } else {
        g_object_set(G_OBJECT(_sink), "egl-display", _dpy, NULL);
        _displaySet = true;
    }

    _showFrameId = g_signal_connect(G_OBJECT(_sink), "show-frame", G_CALLBACK(show_frame), this);
    _buffersInvalidatedId = g_signal_connect(
            G_OBJECT(_sink), "buffers-invalidated", G_CALLBACK(buffers_invalidated), this);

    GstPad *pad = gst_element_get_static_pad(_sink, "sink");
    _notify = g_signal_connect(G_OBJECT(pad), "notify::caps",
                                    G_CALLBACK(sink_caps_changed), this);
    gst_object_unref(pad);

    return _sink;
}

void QtCamViewfinderRendererNemo::sink_notify(QtCamViewfinderRendererNemo *q, GObject *object, gboolean is_last_ref) {
    Q_UNUSED(object);

    if (is_last_ref) {
        q->cleanup();
    }
}

void QtCamViewfinderRendererNemo::sink_caps_changed(GObject *obj, GParamSpec *pspec, QtCamViewfinderRendererNemo *q) {
    Q_UNUSED(pspec);

    if (!obj) {
        return;
    }

    if (!GST_IS_PAD (obj)) {
        return;
    }

    GstPad *pad = GST_PAD (obj);
    GstCaps *caps = gst_pad_get_current_caps (pad);
    if (!caps) {
        return;
    }

    if (gst_caps_get_size (caps) < 1) {
        gst_caps_unref (caps);
        return;
    }

    GstVideoInfo info;
    if (!gst_video_info_from_caps (&info, caps)) {
        qWarning() << "failed to get video info";
        gst_caps_unref (caps);
        return;
    }

    QMetaObject::invokeMethod(q, "setVideoSize", Qt::QueuedConnection,
                                Q_ARG(QSizeF, QSizeF(info.width, info.height)));

    gst_caps_unref (caps);
}

void QtCamViewfinderRendererNemo::calculateProjectionMatrix(const QRectF& rect) {
    _projectionMatrix = QMatrix4x4();
    _projectionMatrix.ortho(rect);
}

void QtCamViewfinderRendererNemo::createProgram() {
    if (_program) {
        delete _program;
    }

    _program = new QGLShaderProgram;

    if (!_program->addShaderFromSourceCode(QGLShader::Vertex, VERTEX_SHADER)) {
        qCritical() << "Failed to add vertex shader";
        return;
    }

    if (!_program->addShaderFromSourceCode(QGLShader::Fragment, FRAGMENT_SHADER)) {
        qCritical() << "Failed to add fragment shader";
        return;
    }

    _program->bindAttributeLocation("inputVertex", 0);
    _program->bindAttributeLocation("textureCoord", 1);

    if (!_program->link()) {
        qCritical() << "Failed to link program!";
        return;
    }

    if (!_program->bind()) {
        qCritical() << "Failed to bind program";
        return;
    }

    _program->setUniformValue("texture0", 0);
    _program->release();
}

void QtCamViewfinderRendererNemo::paintFrame(const QMatrix4x4& matrix) {
    if (_buffersInvalidated) {
        _buffersInvalidated = false;
        destroyCachedTextures();
    }


    GstBuffer *bufferToRelease = nullptr;
    if (_currentBuffer != _queuedBuffer && _bufferChanged) {
        bufferToRelease = _currentBuffer;

        _currentBuffer = gst_buffer_ref(_queuedBuffer);
    }

    _bufferChanged = false;

    if (!_currentBuffer || gst_buffer_n_memory(_currentBuffer) == 0) {
        return;
    }

    std::vector<GLfloat> texCoords(_texCoords);

    GLuint texture;

    GstMemory *memory = gst_buffer_peek_memory(_currentBuffer, 0);

    for (CachedTexture &cachedTexture : _textures) {
        if (cachedTexture.memory == memory) {
            texture = cachedTexture.textureId;
            glBindTexture(GL_TEXTURE_EXTERNAL_OES, texture);
            _img->glEGLImageTargetTexture2DOES(GL_TEXTURE_EXTERNAL_OES, cachedTexture.image);
        }
    }

    if (texture == 0) {
        if (EGLImageKHR img = nemo_gst_egl_image_memory_create_image(memory, _dpy, nullptr)) {
            glGenTextures(1, &texture);
            glBindTexture(GL_TEXTURE_EXTERNAL_OES, texture);
            glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
            glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
            glActiveTexture(GL_TEXTURE0);

            _img->glEGLImageTargetTexture2DOES (GL_TEXTURE_EXTERNAL_OES, (GLeglImageOES)img);

            CachedTexture cachedTexture = { gst_memory_ref(memory), img, texture };
            _textures.push_back(cachedTexture);
        }
    }

    _program->link();
    _program->bind();

    _program->setUniformValue("matrix", _projectionMatrix);
    _program->setUniformValue("matrixWorld", matrix);

    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, &_vertexCoords[0]);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, &texCoords[0]);

    glEnableVertexAttribArray(0);
    glEnableVertexAttribArray(1);

    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);

    glDisableVertexAttribArray(1);
    glDisableVertexAttribArray(0);

    _program->release();

    glBindTexture(GL_TEXTURE_EXTERNAL_OES, 0);

    if (bufferToRelease) {
        gst_buffer_unref(bufferToRelease);
    }
}

void QtCamViewfinderRendererNemo::calculateVertexCoords() {
    if (!_size.isValid() || !_videoSize.isValid()) {
        return;
    }

    QRectF area = renderArea();

    qreal leftMargin = area.x();
    qreal topMargin = area.y();
    QSizeF renderSize = area.size();

    _vertexCoords[0] = leftMargin;
    _vertexCoords[1] = topMargin + renderSize.height();

    _vertexCoords[2] = renderSize.width() + leftMargin;
    _vertexCoords[3] = topMargin + renderSize.height();

    _vertexCoords[4] = renderSize.width() + leftMargin;
    _vertexCoords[5] = topMargin;

    _vertexCoords[6] = leftMargin;
    _vertexCoords[7] = topMargin;
}

QRectF QtCamViewfinderRendererNemo::renderArea() {
    if (!_renderArea.isNull()) {
        return _renderArea;
    }

    QSizeF renderSize = _videoSize;
    renderSize.scale(_size, Qt::KeepAspectRatio);

    qreal leftMargin = (_size.width() - renderSize.width())/2.0;
    qreal topMargin = (_size.height() - renderSize.height())/2.0;

    _renderArea = QRectF(QPointF(leftMargin, topMargin), renderSize);

    return _renderArea;
}

QSizeF QtCamViewfinderRendererNemo::videoResolution() {
    return _videoSize;
}

void QtCamViewfinderRendererNemo::setVideoSize(const QSizeF& size) {
    if (size == _videoSize) {
        return;
    }

    _videoSize = size;

    _renderArea = QRectF();

    calculateVertexCoords();

    _needsInit = true;

    emit renderAreaChanged();
    emit videoResolutionChanged();
}

void QtCamViewfinderRendererNemo::show_frame(GstVideoSink *, GstBuffer *buffer, QtCamViewfinderRendererNemo *r)
{
    QMutexLocker locker(&r->_frameMutex);

    GstBuffer * const bufferToRelease = r->_queuedBuffer;
    r->_queuedBuffer = buffer ? gst_buffer_ref(buffer) : nullptr;
    r->_bufferChanged = true;

    locker.unlock();

    if (bufferToRelease) {
        gst_buffer_unref(bufferToRelease);
    }

    QMetaObject::invokeMethod(r, "updateRequested", Qt::QueuedConnection);
}

void QtCamViewfinderRendererNemo::buffers_invalidated(GstVideoSink *, QtCamViewfinderRendererNemo *r)
{
    {
        QMutexLocker locker(&r->_frameMutex);
        r->_buffersInvalidated = true;
    }
    QMetaObject::invokeMethod(r, "updateRequested", Qt::QueuedConnection);
}

void QtCamViewfinderRendererNemo::cleanup() {
    if (!_sink) {
        return;
    }

    destroyCachedTextures();

    if (_showFrameId) {
        g_signal_handler_disconnect(_sink, _showFrameId);
        _showFrameId = 0;
    }

    if (_buffersInvalidatedId) {
        g_signal_handler_disconnect(_sink, _buffersInvalidatedId);
        _buffersInvalidatedId = 0;
    }


    if (_notify) {
        g_signal_handler_disconnect(_sink, _notify);
        _notify = 0;
    }

    g_object_remove_toggle_ref(G_OBJECT(_sink), (GToggleNotify)sink_notify, this);
    _sink = 0;
}

void QtCamViewfinderRendererNemo::destroyCachedTextures()
{
    static const PFNEGLDESTROYIMAGEKHRPROC eglDestroyImageKHR
        = reinterpret_cast<PFNEGLDESTROYIMAGEKHRPROC>(eglGetProcAddress("eglDestroyImageKHR"));

    for (CachedTexture &texture : _textures) {
        glDeleteTextures(1, &texture.textureId);

        eglDestroyImageKHR(_dpy, texture.image);

        gst_memory_unref(texture.memory);
    }
    _textures.clear();
}

void QtCamViewfinderRendererNemo::updateCropInfo(const GstStructure *s,
                                                 std::vector<GLfloat>& texCoords) {
    int right = 0, bottom = 0, top = 0, left = 0;

    if (!gst_structure_get_int(s, "top", &top) ||
            !gst_structure_get_int(s, "left", &left) ||
            !gst_structure_get_int(s, "bottom", &bottom) ||
            !gst_structure_get_int(s, "right", &right)) {
        qWarning() << "incomplete crop info";
        return;
    }

    if ((right - left) <= 0 || (bottom - top) <= 0) {
        return;
    }

    int width = right - left;
    int height = bottom - top;
    qreal tx = 0.0f, ty = 0.0f, sx = 1.0f, sy = 1.0f;
    int bufferWidth = _videoSize.width();
    int bufferHeight = _videoSize.height();
    if (width < bufferWidth) {
        tx = (qreal)left / (qreal)bufferWidth;
        sx = (qreal)right / (qreal)bufferWidth;
    }

    if (height < bufferHeight) {
        ty = (qreal)top / (qreal)bufferHeight;
        sy = (qreal)bottom / (qreal)bufferHeight;
    }

    texCoords[0] = tx;             texCoords[1] = ty;
    texCoords[2] = sx;             texCoords[3] = ty;
    texCoords[4] = sx;             texCoords[5] = sy;
    texCoords[6] = tx;             texCoords[7] = sy;
}
