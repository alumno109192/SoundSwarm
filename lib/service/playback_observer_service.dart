import 'dart:async';
import 'package:just_audio/just_audio.dart';

typedef PlaybackPositionCallback = void Function(Duration position);

class PlaybackObserverService {
  final AudioPlayer audioPlayer;
  StreamSubscription<Duration>? _positionSubscription;

  PlaybackObserverService(this.audioPlayer);

  void startObserving(PlaybackPositionCallback onPositionChanged) {
    _positionSubscription?.cancel();
    _positionSubscription = audioPlayer.positionStream.listen(onPositionChanged);
  }

  void stopObserving() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  void dispose() {
    stopObserving();
  }
}