import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:soundswarm/model/youtube_video.dart';

class FastApiService {
  // URL base para producción
  //final String _baseUrlPro = 'https://yt-dlp-uvag.onrender.com';
  final String _baseUrlPro = 'http://192.168.1.235:8000';

  /// Devuelve la URL directa al stream de audio servido por tu backend
  Future<String> getAudioUrl(String videoId) async {
    final url = '$_baseUrlPro/audio/$videoId';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Error al obtener URL de audio: ${response.statusCode}');
    }
    // Puedes devolver la URL directamente, ya que just_audio la usará como stream
    // Opcional: puedes hacer un HEAD para comprobar que existe
    if (kDebugMode) print('URL de audio generada: $url');
    return url;
  }

  /// Obtiene la URL para el streaming del audio desde el backend y la duración
  Future<Map<String, dynamic>> getStreamUrl(String videoId) async {
    final url = '$_baseUrlPro/stream/$videoId';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final streamUrl = url;

        // Extraer la duración del encabezado si está disponible
        final durationHeader = response.headers['x-audio-duration'];
        final duration =
            durationHeader != null ? int.tryParse(durationHeader) : null;

        if (kDebugMode) {
          print('URL de streaming generada: $streamUrl');
          print('Duración del audio obtenida: $duration segundos');
        }

        return {'streamUrl': streamUrl, 'duration': duration};
      } else {
        throw Exception(
          'Error al obtener URL de streaming: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (kDebugMode) print('Error al obtener URL de streaming: $e');
      rethrow;
    }
  }

  // Búsqueda de videos usando scraping a través de FastAPI
  Future<List<YouTubeVideo>> searchVideos(String query) async {
    try {
      // En lugar de usar el endpoint search, implementemos uno para la búsqueda
      final response = await http.get(
        Uri.parse('$_baseUrlPro/search?query=${Uri.encodeComponent(query)}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;

        // Convertir resultados al modelo YouTubeVideo
        return data
            .map(
              (item) => YouTubeVideo(
                videoId: item['id'],
                title: item['title'],
                thumbnailUrl:
                    'https://i.ytimg.com/vi/${item['id']}/mqdefault.jpg', // Thumbnail estándar
                channelTitle: item['channel'] ?? 'Unknown',
                description: '',
              ),
            )
            .toList();
      } else {
        throw Exception('Error en búsqueda FastAPI: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error en búsqueda FastAPI: $e');
      }
      rethrow;
    }
  }

  // Define the getRelatedVideos method
  Future<List<YouTubeVideo>> getRelatedVideos(String videoId) async {
    // Implement the logic to fetch related videos from the API
    // Example placeholder implementation:
    return [
      YouTubeVideo(
        videoId: 'example2',
        title: 'Related Video 2',
        description: 'Example description for Related Video 2',
        thumbnailUrl: 'https://example.com/thumbnail2.jpg',
        channelTitle: 'Example Channel 2',
      ),
      YouTubeVideo(
        videoId: 'example1',
        title: 'Related Video 1',
        description: 'Example description for Related Video 1',
        thumbnailUrl: 'https://example.com/thumbnail1.jpg',
        channelTitle: 'Example Channel 1',
      ),
    ];
  }
}
