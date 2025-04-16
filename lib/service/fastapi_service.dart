import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:soundswarm/model/youtube_video.dart';

class FastApiService {
  // URL base del servidor FastAPI (ajusta según tu configuración)
  final String _baseUrl = 'http://192.168.0.101:8000';
  
  // Obtener información de audio por ID de video
  Future<String> getAudioUrl(String videoId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/audioinfo?url=https://www.youtube.com/watch?v=$videoId')
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url'];
      } else {
        throw Exception('Error al obtener audio: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error en FastAPI service: $e');
      }
      rethrow;
    }
  }
  
  // Búsqueda de videos usando scraping a través de FastAPI
  Future<List<YouTubeVideo>> searchVideos(String query) async {
    try {
      // En lugar de usar el endpoint search, implementemos uno para la búsqueda
      final response = await http.get(
        Uri.parse('$_baseUrl/search?query=${Uri.encodeComponent(query)}')
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        
        // Convertir resultados al modelo YouTubeVideo
        return data.map((item) => YouTubeVideo(
          videoId: item['id'],
          title: item['title'],
          thumbnailUrl: 'https://i.ytimg.com/vi/${item['id']}/mqdefault.jpg', // Thumbnail estándar
          channelTitle: item['channel'] ?? 'Unknown',
          description: '',
        )).toList();
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
      )
    ];
  }
}