#include "player.h"
#include <QQmlInfo>
#include <QTimer>
#include <QPainter>
#include <QMatrix4x4>
#include <cmath>
#include <QTextDocument>
#include <QLocale>

VideoPlayer::VideoPlayer(QQuickItem *parent) :
    QQuickPaintedItem(parent),
    _renderer(nullptr),
    _audioResource((QObject*)this, AudioResourceQt::AudioResource::MediaType),
    _selectedVideoStream(0),
    _selectedAudioStream(0),
    _selectedSubtitleStream(0),
    _pipeline(nullptr),
    _pulsesink(nullptr),
    _scaletempo(nullptr),
    _playbin(nullptr),
    _state(VideoPlayer::StateStopped),
    _timer(new QTimer((QObject*)this)),
    _pos(0),
    _playbackSpeed(1.0),
    _created(false),
    _subtitleEnd(0) {

    _timer->setSingleShot(false);
    _timer->setInterval(100);
    connect(_timer, &QTimer::timeout, this, &VideoPlayer::positionChanged);

    setRenderTarget(QQuickPaintedItem::FramebufferObject);
    setSmooth(false);
    setAntialiasing(false);
    _audioResource.acquire();
}

VideoPlayer::~VideoPlayer() {
    stop();

    if (_pipeline) {
        gst_object_unref(_pipeline);
        _pipeline = nullptr;
    }
}

void VideoPlayer::componentComplete() {
    QQuickPaintedItem::componentComplete();
}

void VideoPlayer::classBegin() {
    QQuickPaintedItem::classBegin();

    _pipeline = gst_pipeline_new ("video-player");
    Q_ASSERT(_pipeline);

    _playbin = gst_element_factory_make ("playbin3", "Playbin3");
    Q_ASSERT(_playbin);

    _renderer = new QtCamViewfinderRendererNemo(this);
    Q_ASSERT(_renderer);

    QObject::connect(_renderer, SIGNAL(updateRequested()), this, SLOT(updateRequested()));

    _pulsesink = gst_element_factory_make("pulsesink", "PulseSink");
    Q_ASSERT(_pulsesink);

    _scaletempo = gst_element_factory_make("scaletempo", "Scaletempo");
    Q_ASSERT(_scaletempo);

    _appSink = gst_element_factory_make("appsink", "appsink");
    Q_ASSERT(_appSink);

    g_object_set(_appSink, "emit-signals", true, NULL);
    g_signal_connect(_appSink, "new-sample", G_CALLBACK (cbNewSample), this);

    gst_bin_add(GST_BIN(_pipeline), _playbin);

    g_object_set(_playbin, "audio-filter", _scaletempo, NULL);
    g_object_set(_playbin, "audio-sink", _pulsesink, NULL);
    g_object_set(_playbin, "video-sink", _renderer->sinkElement(), NULL);
    g_object_set(_playbin, "text-sink", _appSink, NULL);

    GstBus *bus = gst_element_get_bus(_pipeline);
    gst_bus_add_watch(bus, bus_call, this);
    gst_object_unref(bus);
}

QUrl VideoPlayer::getVideoSource() const {
    return _videoUrl;
}

void VideoPlayer::setVideoSource(const QUrl& videoSource) {
    if (_videoUrl != videoSource) {
        _videoUrl = videoSource;

        setState(StateStopped);

        g_object_set(_playbin, "uri", _videoUrl.toString().toUtf8().constData(), NULL);

        resetPlayer();

        emit videoSourceChanged();
    }
}

qint64 VideoPlayer::getDuration() const {
    if (!_pipeline) {
        return 0;
    }

    gint64 dur = 0;
    if (!gst_element_query_duration(_pipeline, GST_FORMAT_TIME, &dur)) {
        return 0;
    }

    dur /= 1000000;

    return dur;
}

qint64 VideoPlayer::getPosition() {
    if (!_pipeline) {
        return 0;
    }

    gint64 pos = 0;
    if (!gst_element_query_position(_pipeline, GST_FORMAT_TIME, &pos)) {
        return _pos;
    }

    pos /= 1000000;

    _pos = pos;

    return pos;
}

void VideoPlayer::setPosition(qint64 position) {
    seek(position);
}

QStringList VideoPlayer::getVideoStreams() const
{
    QStringList stringList = { tr("None") };

    for (QPair<QString, QString> lang : _videoStreams) {
        if (!lang.second.size()) {
            stringList.append(tr("Unknown"));
        } else {
            QLocale locale(lang.second);
            stringList.append(QLocale::languageToString(locale.language()));
        }
    }

    return stringList;
}

QStringList VideoPlayer::getAudioStreams() const
{
    QStringList stringList = { tr("None") };

    for (QPair<QString, QString> lang : _audioStreams) {
        if (!lang.second.size()) {
            stringList.append(tr("Unknown"));
        } else {
            QLocale locale(lang.second);
            stringList.append(QLocale::languageToString(locale.language()));
        }
    }

    return stringList;
}

QStringList VideoPlayer::getSubtitleStreams() const
{
    QStringList stringList = { tr("None") };

    for (QPair<QString, QString> lang : _subtitleStreams) {
        if (!lang.second.size()) {
            stringList.append(tr("Unknown"));
        } else {
            QLocale locale(lang.second);
            stringList.append(QLocale::languageToString(locale.language()));
        }
    }

    return stringList;
}

int VideoPlayer::getSelectedVideoStream() const
{
    return _selectedVideoStream;
}

int VideoPlayer::getSelectedAudioStream() const
{
    return _selectedAudioStream;
}

int VideoPlayer::getSelectedSubtitleStream() const
{
    return _selectedSubtitleStream;
}

QString VideoPlayer::getSubtitle() const
{
    return _currentSubtitle;
}

void VideoPlayer::setSubtitle(QString subtitle)
{
    if (subtitle == _currentSubtitle) return;

    _currentSubtitle = subtitle;

    setState(StateStopped);

    g_object_set(_playbin, "suburi", subtitle.toUtf8().constData(), NULL);

    emit subtitleChanged();
}

QString VideoPlayer::getDisplaySubtitle() const
{
    return _subtitle;
}

void VideoPlayer::setDisplaySubtitle(QString subtitle)
{
    QTextDocument d;
    d.setHtml(subtitle);

    _subtitle = d.toPlainText();

    emit displaySubtitleChanged();
}

bool VideoPlayer::pause() {
    return setState(VideoPlayer::StatePaused);
}

bool VideoPlayer::play() {
    _renderer->resize(QSizeF(width(), height()));

    if (!_pipeline) {
        qmlInfo(this) << "no playbin";
        return false;
    }

    qDebug() << "AudioResource: " << _audioResource.isAcquired();

    return setState(VideoPlayer::StatePlaying);
}

bool VideoPlayer::seek(qint64 offset) {
    if (!_pipeline) {
        qmlInfo(this) << "no playbin2";
        return false;
    }

    gint64 pos = offset;

    offset *= 1000000;

    gint64 dur = 0;
    if (!gst_element_query_duration(_pipeline, GST_FORMAT_TIME, &dur)) {
        return false;
    }

    if (offset > dur) {
        offset = dur;
        stop();
    }

    bool ret = gst_element_seek(
        _pipeline, _playbackSpeed, GST_FORMAT_TIME, (GstSeekFlags) (GST_SEEK_FLAG_FLUSH|GST_SEEK_FLAG_TRICKMODE|GST_SEEK_FLAG_ACCURATE), GST_SEEK_TYPE_SET, offset, GST_SEEK_TYPE_NONE, -1
    );

    if (ret) {
        _pos = pos;

        return TRUE;
    }

    return TRUE;
}

bool VideoPlayer::stop() {
    return setState(VideoPlayer::StateStopped);
}

bool VideoPlayer::setPlaybackSpeed(double speed)
{
    gint64 position;

    if (speed == _playbackSpeed) return false;

    if (!gst_element_query_position(_pipeline, GST_FORMAT_TIME, &position)) {
        g_printerr("Unable to retrieve current position.\n");
        return false;
    }

    bool ret = gst_element_seek(
        _pipeline, speed, GST_FORMAT_TIME, (GstSeekFlags) (GST_SEEK_FLAG_FLUSH|GST_SEEK_FLAG_TRICKMODE|GST_SEEK_FLAG_ACCURATE), GST_SEEK_TYPE_SET, position, GST_SEEK_TYPE_NONE, 0
    );

    if (!ret) {
        qDebug() << "Failed to change playback speed";
    }

    _playbackSpeed = speed;

    return true;
}

void VideoPlayer::selectVideoStream(int index)
{
    _selectedVideoStream = index;

    emit selectedVideoStreamChanged();

    selectStreams();
}

void VideoPlayer::selectAudioStream(int index)
{
    _selectedAudioStream = index;

    emit selectedAudioStreamChanged();

    selectStreams();
}

void VideoPlayer::selectSubtitle(int index)
{
    _selectedSubtitleStream = index;

    emit selectedSubtitleStreamChanged();

    selectStreams();
}

void VideoPlayer::geometryChanged(const QRectF& newGeometry, const QRectF& oldGeometry) {
    QQuickPaintedItem::geometryChanged(newGeometry, oldGeometry);

    if (_renderer) {
        _renderer->resize(newGeometry.size());
    }
}


void VideoPlayer::paint(QPainter *painter) {
    painter->fillRect(contentsBoundingRect(), Qt::black);

    if (!_renderer) {
        return;
    }

    bool needsNativePainting = _renderer->needsNativePainting();

    if (needsNativePainting) {
        painter->beginNativePainting();
    }

    gint64 pos;
    if (gst_element_query_position(_pipeline, GST_FORMAT_TIME, &pos) && pos > _subtitleEnd) {
        setDisplaySubtitle("");
    }

    _renderer->paint(QMatrix4x4(painter->combinedTransform()), painter->viewport());

    if (needsNativePainting) {
        painter->endNativePainting();
    }
}

VideoPlayer::State VideoPlayer::getState() const {
    return _state;
}

bool VideoPlayer::setState(const VideoPlayer::State& state) {
    if (state == _state) {
        return true;
    }

    if (!_pipeline) {
        qmlInfo(this) << "no playbin2";
        return false;
    }

    if (state == VideoPlayer::StatePaused || state == VideoPlayer::StateBuffering) {
        _timer->stop();

        int ret = gst_element_set_state(_pipeline, GST_STATE_PAUSED);
        if (ret == GST_STATE_CHANGE_FAILURE) {
            qmlInfo(this) << "error setting pipeline to PAUSED";
            return false;
        }

        if (ret != GST_STATE_CHANGE_ASYNC) {
            GstState st;
            if (gst_element_get_state(_pipeline, &st, NULL, GST_CLOCK_TIME_NONE)
                == GST_STATE_CHANGE_FAILURE) {
                qmlInfo(this) << "setting pipeline to PAUSED failed";
                return false;
            }

            if (st != GST_STATE_PAUSED) {
                qmlInfo(this) << "pipeline failed to transition to to PAUSED state";
                return false;
            }
        }

        _state = state;
        emit stateChanged();

        return true;
    } else if (state == VideoPlayer::StatePlaying) {
        if (gst_element_set_state(_pipeline, GST_STATE_PLAYING) == GST_STATE_CHANGE_FAILURE) {
                qmlInfo(this) << "error setting pipeline to PLAYING";
                return false;
        }

        _state = state;
        emit stateChanged();

        emit durationChanged();
        emit positionChanged();

        _timer->start();
        return true;
    } else {
        _timer->stop();
        _pos = 0;

        int ret = gst_element_set_state(_pipeline, GST_STATE_NULL);
        if (ret == GST_STATE_CHANGE_FAILURE) {
            qmlInfo(this) << "error setting pipeline to NULL";
            return false;
        }

        resetPlayer();

        if (ret != GST_STATE_CHANGE_ASYNC) {
            GstState st;
            if (gst_element_get_state(_pipeline, &st, NULL, GST_CLOCK_TIME_NONE)
            == GST_STATE_CHANGE_FAILURE) {
                qmlInfo(this) << "setting pipeline to NULL failed";
                return false;
            }

            if (st != GST_STATE_NULL) {
                qmlInfo(this) << "pipeline failed to transition to to NULL state";
                return false;
            }
        }

        _state = state;
        emit stateChanged();

        emit durationChanged();
        emit positionChanged();

        return true;
    }
}

void VideoPlayer::selectStreams()
{
    GList *selectedStreams = NULL;
    if (_videoStreams.size()) {
        if (_selectedVideoStream > -1) {
            selectedStreams = g_list_append(selectedStreams, g_strdup(_videoStreams.at(_selectedVideoStream).first.toUtf8().constData()));
        }
    } else {
        _selectedVideoStream = -1;

        emit selectedVideoStreamChanged();
    }

    if (_audioStreams.size()) {
        if (_selectedAudioStream > -1) {
            selectedStreams = g_list_append(selectedStreams, g_strdup(_audioStreams.at(_selectedAudioStream).first.toUtf8().constData()));
        }
    } else {
        _selectedAudioStream = -1;

        emit selectedAudioStreamChanged();
    }

    if (_subtitleStreams.size()) {
        if (_selectedSubtitleStream > -1) {
            selectedStreams = g_list_append(selectedStreams, g_strdup(_subtitleStreams.at(_selectedSubtitleStream).first.toUtf8().constData()));
        }
    } else {
        _selectedSubtitleStream = -1;

        emit selectedSubtitleStreamChanged();
    }

    if (selectedStreams) {
        gst_element_send_event(_playbin, gst_event_new_select_streams(selectedStreams));
        g_list_free(selectedStreams);
    }
}

void VideoPlayer::resetPlayer()
{
    _selectedVideoStream = _selectedAudioStream = _selectedSubtitleStream = 0;
    _playbackSpeed = 1.0;
}

gboolean VideoPlayer::bus_call(GstBus *bus, GstMessage *msg, gpointer data) {
    Q_UNUSED(bus);

    VideoPlayer *that = (VideoPlayer *) data;

    switch (GST_MESSAGE_TYPE(msg)) {
    case GST_MESSAGE_STREAM_COLLECTION:
    {
        GstStreamCollection *collection = NULL;
        that->_videoStreams.clear();
        that->_audioStreams.clear();
        that->_subtitleStreams.clear();

        gst_message_parse_stream_collection(msg, &collection);
        if (collection) {
            for (unsigned int i = 0; i < gst_stream_collection_get_size(collection); i++) {
                GstStream *stream = gst_stream_collection_get_stream(collection, i);

                if (!GST_IS_STREAM(stream)) continue;

                GstCaps *caps = gst_stream_get_caps(stream);
                if (caps) {
                    GstStructure *structure = gst_caps_get_structure(caps, 0);
                    if (structure) {
                        QString name = gst_structure_get_name(structure);
                        if (name == "subpicture/x-pgs" || name == "audio/x-dts") continue;
                    }
                }
                gst_caps_unref(caps);

                QString streamId = QString::fromUtf8(gst_stream_get_stream_id(stream));
                QString language{};
                GstTagList *tags = gst_stream_get_tags(stream);
                if (tags) {
                    const GValue *tagValue = gst_tag_list_get_value_index(tags, GST_TAG_LANGUAGE_CODE, 0);

                    if (G_VALUE_HOLDS_STRING(tagValue)) {
                        gchar *str = g_value_dup_string(tagValue);
                        language = QString::fromUtf8(str);
                        g_free(str);
                    }

                    gst_tag_list_unref(tags);
                }

                switch (gst_stream_get_stream_type(stream)) {
                case GST_STREAM_TYPE_VIDEO:
                    that->_videoStreams.append({streamId, language});
                    break;
                case GST_STREAM_TYPE_AUDIO:
                    that->_audioStreams.append({streamId, language});
                    break;
                case GST_STREAM_TYPE_TEXT:
                    that->_subtitleStreams.append({streamId, language});
                    break;
                default:
                    break;
                }
            }

            that->selectStreams();

            emit that->streamsChanged();

            gst_object_unref(collection);
        }
    }
        break;
    case GST_MESSAGE_NEW_CLOCK:
    {
        emit that->durationChanged();
    }
        break;
    case GST_MESSAGE_BUFFERING:
    {
            gint percent = 0;
            gst_message_parse_buffering(msg, &percent);
            that->updateBufferingState(percent, QString::fromUtf8(GST_MESSAGE_SRC_NAME(msg)));
    }
            break;
    case GST_MESSAGE_EOS:
        that->stop();
        break;

    case GST_MESSAGE_ERROR:
    {
        gchar *debug = NULL;
        GError *err = NULL;
        gst_message_parse_error(msg, &err, &debug);
        qCritical() << "Error" << err->message;

        emit that->error(err->message, err->code, debug);
        that->stop();

        if (err) {
            g_error_free (err);
        }

        if (debug) {
            g_free (debug);
        }

    }
        break;
    case GST_MESSAGE_WARNING:
    {

        gchar *debug = NULL;
        GError *err = NULL;
        gst_message_parse_warning(msg, &err, &debug);
        qWarning() << "Warning" << err->message;

        emit that->error(err->message, err->code, debug);
        that->stop();

        if (err) {
            g_error_free (err);
        }

        if (debug) {
            g_free (debug);
        }
    }
        break;
    case GST_MESSAGE_INFO:
    {

        gchar *debug = NULL;
        GError *err = NULL;
        gst_message_parse_info(msg, &err, &debug);
        qInfo() << "Info" << err->message;

        emit that->error(err->message, err->code, debug);
        that->stop();

        if (err) {
            g_error_free (err);
        }

        if (debug) {
            g_free (debug);
        }
    }
        break;
    default:
        break;
    }

    return TRUE;
}

GstFlowReturn VideoPlayer::cbNewSample(GstElement *sink, gpointer *data)
{
    GstSample *sample;
    GstMapInfo map;
    guint8 *bufferData;
    gsize size;
    VideoPlayer *parent = (VideoPlayer*)data;

    g_signal_emit_by_name (sink, "pull-sample", &sample);
    if (sample) {
        GstBuffer *buffer = gst_sample_get_buffer(sample);
        gst_buffer_map (buffer, &map, GST_MAP_READ);
        bufferData = map.data;
        size = map.size;

        parent->_subtitleEnd = buffer->pts + buffer->duration;

        parent->setDisplaySubtitle(QString::fromUtf8((const char *)bufferData, size));

        gst_sample_unref (sample);
        return GST_FLOW_OK;
    }

    return GST_FLOW_ERROR;
}

void VideoPlayer::updateRequested() {
    update();
}

void VideoPlayer::updateBufferingState(int percent, QString name)
{
    if (!name.startsWith("queue")) return;
    _bufferingProgress[name] = percent;

    for (int p : _bufferingProgress) {
        if (p < 10) {
            setState(VideoPlayer::StateBuffering);
            return;
        }
    }

    if (_state == StateBuffering) {
        play();
    }
}
