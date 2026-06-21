import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';

class AudioPlayerService {
  static final AudioPlayer _player = AudioPlayer();
  static String? _currentPlayingUrl;

  // Use ValueNotifier to track current position
  static final ValueNotifier<Duration> currentPositionNotifier = ValueNotifier(Duration.zero);
  static final ValueNotifier<Duration> totalDurationNotifier = ValueNotifier(Duration.zero);

  static bool get isPlaying => _player.state == PlayerState.playing;
  static Duration get currentPosition => currentPositionNotifier.value;
  static Duration get totalDuration => totalDurationNotifier.value;

  static void Function(Duration)? onPositionChanged;
  static void Function(Duration)? onDurationChanged;
  static void Function()? onComplete;

  static void init() {
    // Listen to position changes
    _player.onPositionChanged.listen((position) {
      currentPositionNotifier.value = position;
      onPositionChanged?.call(position);
    });

    // Listen to duration changes
    _player.onDurationChanged.listen((duration) {
      totalDurationNotifier.value = duration;
      onDurationChanged?.call(duration);
    });

    // Listen to completion
    _player.onPlayerComplete.listen((_) {
      onComplete?.call();
    });
  }

  static Future<void> play(String url) async {
    if (_currentPlayingUrl == url && isPlaying) {
      await pause();
      return;
    }

    if (_currentPlayingUrl != url) {
      await stop();
      _currentPlayingUrl = url;
      await _player.play(UrlSource(url));
    } else {
      await _player.resume();
    }
  }

  static Future<void> pause() async {
    await _player.pause();
  }

  static Future<void> stop() async {
    await _player.stop();
    _currentPlayingUrl = null;
    currentPositionNotifier.value = Duration.zero;
  }

  static Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  static Future<Duration> getTotalDuration() async {
    final duration = await _player.getDuration();
    return duration ?? Duration.zero;
  }

  static void dispose() {
    _player.dispose();
    currentPositionNotifier.dispose();
    totalDurationNotifier.dispose();
  }
}