import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class AudioService {
  final YoutubeExplode _youtubeExplode = YoutubeExplode(); // Instancia persistente

  Future<String> getAudioUrl(String videoId) async {
    try {
      // Obtener el manifiesto de streams del video
      final manifest = await _youtubeExplode.videos.streamsClient.getManifest(videoId);
      final audioStream = manifest.audioOnly.withHighestBitrate();
      return audioStream.url.toString();
    } catch (e) {
      throw Exception('Error al obtener el enlace de audio: $e');
    }
  }

  void dispose() {
    _youtubeExplode.close(); // Cierra la instancia cuando ya no se necesite
  }
}