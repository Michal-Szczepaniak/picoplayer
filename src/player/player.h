#ifndef VIDEO_PLAYER_H
#define VIDEO_PLAYER_H

#include <QQuickPaintedItem>
#include <AudioResourceQt>
#include <gst/gst.h>
#include <QTimer>
#include "renderernemo.h"

class QtCamViewfinderRenderer;

class VideoPlayer : public QQuickPaintedItem {
    Q_OBJECT

    Q_PROPERTY(QUrl videoSource READ getVideoSource WRITE setVideoSource NOTIFY videoSourceChanged);
    Q_PROPERTY(qint64 duration READ getDuration NOTIFY durationChanged);
    Q_PROPERTY(qint64 position READ getPosition WRITE setPosition NOTIFY positionChanged);
    Q_PROPERTY(State state READ getState NOTIFY stateChanged);
    Q_PROPERTY(QStringList videoStreams READ getVideoStreams NOTIFY streamsChanged)
    Q_PROPERTY(int selectedVideoStream READ getSelectedVideoStream NOTIFY selectedVideoStreamChanged)
    Q_PROPERTY(QStringList audioStreams READ getAudioStreams NOTIFY streamsChanged)
    Q_PROPERTY(int selectedAudioStream READ getSelectedAudioStream NOTIFY selectedAudioStreamChanged)
    Q_PROPERTY(QStringList subtitleStreams READ getSubtitleStreams NOTIFY streamsChanged)
    Q_PROPERTY(int selectedSubtitleStream READ getSelectedSubtitleStream NOTIFY selectedSubtitleStreamChanged)
    Q_PROPERTY(QString subtitle READ getSubtitle WRITE setSubtitle NOTIFY subtitleChanged);
    Q_PROPERTY(QString displaySubtitle READ getDisplaySubtitle WRITE setDisplaySubtitle NOTIFY displaySubtitleChanged);
    Q_ENUMS(State);

public:
    VideoPlayer(QQuickItem *parent = 0);
    ~VideoPlayer();

    virtual void componentComplete();
    virtual void classBegin();

    void paint(QPainter *painter);

    QUrl getVideoSource() const;
    void setVideoSource(const QUrl& videoSource);
    qint64 getDuration() const;
    qint64 getPosition();
    void setPosition(qint64 position);
    QStringList getVideoStreams() const;
    QStringList getAudioStreams() const;
    QStringList getSubtitleStreams() const;
    int getSelectedVideoStream() const;
    int getSelectedAudioStream() const;
    int getSelectedSubtitleStream() const;
    QString getSubtitle() const;
    void setSubtitle(QString subtitle);
    QString getDisplaySubtitle() const;
    void setDisplaySubtitle(QString subtitle);

    Q_INVOKABLE bool pause();
    Q_INVOKABLE bool play();
    Q_INVOKABLE bool seek(qint64 offset);
    Q_INVOKABLE bool stop();
    Q_INVOKABLE bool setPlaybackSpeed(double speed);
    Q_INVOKABLE void selectVideoStream(int index);
    Q_INVOKABLE void selectAudioStream(int index);
    Q_INVOKABLE void selectSubtitle(int index);

    typedef enum {
        StateStopped,
        StatePaused,
        StatePlaying,
        StateBuffering,
    } State;

    State getState() const;

signals:
    void videoSourceChanged();
    void durationChanged();
    void positionChanged();
    void error(const QString& message, int code, const QString& debug);
    void stateChanged();
    void streamsChanged();
    void selectedVideoStreamChanged();
    void selectedAudioStreamChanged();
    void selectedSubtitleStreamChanged();
    void subtitleChanged();
    void displaySubtitleChanged();

protected:
    void geometryChanged(const QRectF& newGeometry, const QRectF& oldGeometry);

private slots:
    void updateRequested();
    void updateBufferingState(int percent, QString name);

private:
    static gboolean bus_call(GstBus *bus, GstMessage *msg, gpointer data);
    static GstFlowReturn cbNewSample(GstElement *sink, gpointer *data);

    bool setState(const State& state);
    void selectStreams();
    void resetPlayer();

    QtCamViewfinderRendererNemo *_renderer;
    AudioResourceQt::AudioResource _audioResource;
    QUrl _videoUrl;
    QVector<QPair<QString, QString>> _videoStreams{};
    QVector<QPair<QString, QString>> _audioStreams{};
    QVector<QPair<QString, QString>> _subtitleStreams{};
    int _selectedVideoStream;
    int _selectedAudioStream;
    int _selectedSubtitleStream;

    GstElement *_pipeline;
    GstElement *_pulsesink;
    GstElement *_scaletempo;
    GstElement *_playbin;
    GstElement *_appSink;
    State _state;
    QTimer *_timer;
    qint64 _pos;
    double _playbackSpeed;
    bool _created;
    bool _audioOnlyMode = false;
    QString _currentSubtitle;
    QString _subtitle;
    quint64 _subtitleEnd;
    QHash<QString, int> _bufferingProgress;
};

#endif /* VIDEO_PLAYER_H */
