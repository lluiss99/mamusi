import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/audio_item.dart';

class AudioPlayerHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  int _currentIndex = 0;

  AudioPlayerHandler() {
    _initAudioSession();
    _player.playbackEventStream.listen(_broadcastState);
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        skipToNext();
      }
    });
    // La notificación / pantalla de bloqueo usa mediaItem.duration para
    // pintar la barra de progreso total; just_audio solo la conoce una vez
    // cargado el audio, así que hay que propagarla al mediaItem cuando llega.
    _player.durationStream.listen((duration) {
      final item = mediaItem.value;
      if (item != null && duration != null && item.duration != duration) {
        mediaItem.add(item.copyWith(duration: duration));
      }
    });
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Manejar interrupciones (llamadas, otras apps de audio)
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        _player.pause();
      } else {
        switch (event.type) {
          case AudioInterruptionType.pause:
          case AudioInterruptionType.duck:
            _player.play();
            break;
          case AudioInterruptionType.unknown:
            break;
        }
      }
    });

    // Manejar pérdida de audio (auriculares desconectados, etc.)
    session.becomingNoisyEventStream.listen((_) {
      _player.pause();
    });
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _currentIndex,
    ));
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    final q = queue.value;
    if (_currentIndex < q.length - 1) {
      await skipToQueueItem(_currentIndex + 1);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    if (_currentIndex > 0) {
      await skipToQueueItem(_currentIndex - 1);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    final q = queue.value;
    if (index < 0 || index >= q.length) return;

    _currentIndex = index;
    final item = q[_currentIndex];

    // Actualiza el título inmediatamente
    mediaItem.add(item);
    playbackState.add(playbackState.value.copyWith(queueIndex: _currentIndex));
    playbackState.add(playbackState.value.copyWith(
      updatePosition: Duration.zero,
    ));

    // El id del MediaItem es la ruta del fichero local.
    try {
      await _player.setFilePath(item.id);
    } catch (e) {
      debugPrint('No se pudo abrir ${item.id}: $e');
      return;
    }

    await _player.play();
  }

  Future<void> loadQueue(List<AudioItem> audios, {int startIndex = 0}) async {
    final items = audios
        .map((a) => MediaItem(
              id: a.filePath,
              title: a.name,
              artist: a.artist,
              extras: {'id': a.id},
            ))
        .toList();

    queue.add(items);
    _currentIndex = 0;
    await skipToQueueItem(startIndex);
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;

  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }
}

class PlayerService extends ChangeNotifier {
  static final PlayerService _instance = PlayerService._internal();
  factory PlayerService() => _instance;
  PlayerService._internal();

  AudioPlayerHandler? _handler;

  AudioPlayerHandler get handler {
    assert(
        _handler != null, 'PlayerService not initialized. Call init() first.');
    return _handler!;
  }

  Future<void> init() async {
    _handler = await AudioService.init(
      builder: () => AudioPlayerHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.audio_app.channel.audio',
        androidNotificationChannelName: 'Mamusi',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidNotificationIcon: 'drawable/ic_audio_notification',
        notificationColor: Color(0xFF2E7D32),
      ),
    );
  }

  AudioItem? get currentAudio {
    final item = _handler?.mediaItem.value;
    if (item == null) return null;
    return AudioItem(
      id: item.extras?['id'] ?? '',
      name: item.title,
      artist: item.artist,
      filePath: item.id,
      createdAt: DateTime.now(),
    );
  }

  bool get isPlaying => _handler?.isPlaying ?? false;
  Stream<Duration> get positionStream =>
      _handler?.positionStream ?? const Stream.empty();
  Stream<Duration?> get durationStream =>
      _handler?.durationStream ?? const Stream.empty();
  Stream<PlaybackState> get playbackStateStream =>
      _handler?.playbackState.stream ?? const Stream.empty();
  Duration get position => _handler?.position ?? Duration.zero;
  Duration? get duration => _handler?.duration;

  Future<void> playQueue(List<AudioItem> audios, {int startIndex = 0}) async {
    await handler.loadQueue(audios, startIndex: startIndex);
    notifyListeners();
  }

  Future<void> togglePlay() async {
    if (isPlaying) {
      await handler.pause();
    } else {
      await handler.play();
    }
    notifyListeners();
  }

  Future<void> next() async {
    await handler.skipToNext();
    notifyListeners();
  }

  Future<void> previous() async {
    await handler.skipToPrevious();
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await handler.seek(position);
  }
}
