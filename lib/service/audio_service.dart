import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:soundswarm/service/fastapi_service.dart';

class AudioService {
  final YoutubeExplode _youtubeExplode =
      YoutubeExplode(); // Instancia persistente
  final FastApiService _fastApiService =
      FastApiService(); // Instancia del servicio FastAPI

  Future<Map<String, dynamic>> getAudioUrl(String videoId) async {
    try {
      if (kDebugMode) {
        print(
          'Solicitando al servidor que descargue el audio para video ID: $videoId',
        );
      }

      // Llamar al endpoint del servidor para descargar la canción
      final downloadUrl = await _fastApiService.getAudioUrl(videoId);

      if (downloadUrl.isEmpty || !downloadUrl.startsWith('http')) {
        throw Exception('URL de descarga inválida');
      }

      if (kDebugMode) {
        print(
          'El servidor ha iniciado la descarga. URL de descarga: $downloadUrl',
        );
      }

      // Llamar al endpoint para obtener la URL de streaming y la duración
      final streamInfo = await _fastApiService.getStreamUrl(videoId);

      final streamUrl = streamInfo['streamUrl'];
      final duration = streamInfo['duration'];

      if (streamUrl.isEmpty || !streamUrl.startsWith('http')) {
        throw Exception('URL de streaming inválida');
      }

      if (kDebugMode) {
        print('URL de streaming obtenida: $streamUrl');
        print('Duración del audio obtenida: $duration segundos');
      }

      return {'streamUrl': streamUrl, 'duration': duration};
    } catch (e) {
      if (kDebugMode) {
        print('Error en getAudioUrl: $e');
      }
      throw Exception('Error al obtener URL de audio: $e');
    }
  }

  void dispose() {
    _youtubeExplode.close(); // Cierra la instancia cuando ya no se necesite
  }
}
