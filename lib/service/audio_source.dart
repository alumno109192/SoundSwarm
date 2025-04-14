import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

// Método de extensión para crear un AudioSource con notificación
extension MediaItemExtension on AudioSource {
  static AudioSource createFromMediaItem(MediaItem mediaItem, String url) {
    return AudioSource.uri(
      Uri.parse(url),
      tag: mediaItem,
    );
  }
}