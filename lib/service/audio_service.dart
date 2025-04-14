import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class AudioService {
  final YoutubeExplode _youtubeExplode = YoutubeExplode(); // Instancia persistente

  Future<String> getAudioUrl(String videoId) async {
    try {
      if (kDebugMode) {
        print('Obteniendo URL para video ID: $videoId');
      }
      
      // Obtener el manifiesto de streams
      final StreamManifest manifest = await _youtubeExplode.videos.streams.getManifest(videoId);
      
      // Filtrar para obtener solo streams de audio y ordenarlos por calidad
      final audioStreams = manifest.audioOnly.sortByBitrate();
      
      if (audioStreams.isEmpty) {
        if (kDebugMode) {
          print('No se encontraron streams de audio');
        }
        throw Exception('No se encontraron streams de audio para este video');
      }
      
      // Obtener el stream de mayor calidad
      final audioStream = audioStreams.last;
      final url = audioStream.url.toString();
      
      if (kDebugMode) {
        print('URL obtenida: $url');
      }
      
      // Verificar que la URL sea válida
      if (url.isEmpty) {
        throw Exception('URL de audio vacía');
      }
      
      return url;
    } catch (e) {
      if (kDebugMode) {
        print('Error en AudioService.getAudioUrl: $e');
      }
      throw Exception('No se pudo obtener el audio: $e');
    }
  }

  void dispose() {
    _youtubeExplode.close(); // Cierra la instancia cuando ya no se necesite
  }
}