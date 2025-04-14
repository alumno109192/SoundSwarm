import 'package:flutter/foundation.dart';
import 'package:soundswarm/model/youtube_video.dart';

class AudioPlayerService extends ChangeNotifier {
  // Singleton
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  // Callback para reproducir canción
  Function(YouTubeVideo song)? onPlaySongRequested;

  // Método para solicitar reproducción de una canción
  void playSong(YouTubeVideo song) {
    if (onPlaySongRequested != null) {
      onPlaySongRequested!(song);
    } else {
      if (kDebugMode) {
        print('Warning: No hay un listener configurado para reproducir canciones.');
      }
    }
  }

  // Configurar callback desde HomeScreen
  void setPlaySongCallback(Function(YouTubeVideo song) callback) {
    onPlaySongRequested = callback;
  }
}