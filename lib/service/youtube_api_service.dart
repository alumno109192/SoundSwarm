import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:soundswarm/model/youtube_video.dart';

class YouTubeApiService {
  final String apiKey = 'AIzaSyCOJ6QuVNRH_cJ5_PNrNUF8St9XMJmBHL4';
  final String baseUrl = 'https://www.googleapis.com/youtube/v3/search';

  Future<List<YouTubeVideo>> searchVideos(String query) async {
    final url = Uri.parse('$baseUrl?part=snippet&type=video&q=$query&key=$apiKey');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List items = data['items'];
      return items.map((item) => YouTubeVideo.fromJson(item)).toList();
    } else {
      throw Exception('Error al buscar en YouTube: ${response.reasonPhrase}');
    }
  }

  Future<List<YouTubeVideo>> getRelatedVideos(String videoId, {String? title, String? artist}) async {
    try {
      // 1. Intentar usar la API de videos relacionados primero
      final apiKey = 'AIzaSyCOJ6QuVNRH_cJ5_PNrNUF8St9XMJmBHL4'; // Asegúrate de tener una API key válida
      
      final response = await http.get(
        Uri.parse('https://www.googleapis.com/youtube/v3/search?part=snippet&relatedToVideoId=$videoId&type=video&maxResults=10&key=$apiKey'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List items = data['items'];
        return items.map((item) => YouTubeVideo.fromJson(item)).toList();
      } else {
        print('Error en la respuesta: ${response.statusCode} - ${response.reasonPhrase}');
        
        // 2. Si falla, intentar una búsqueda más inteligente basada en título y artista
        final searchQuery = _buildSearchQuery(title, artist);
        print('Buscando videos similares con: "$searchQuery"');
        
        if (searchQuery.isNotEmpty) {
          return await searchVideos(searchQuery);
        } else {
          // Si no pudimos construir una consulta específica, usar una genérica
          return await searchVideos("música similar");
        }
      }
    } catch (e) {
      print('Error obteniendo videos relacionados: $e');
      return []; // Devolver lista vacía en caso de error
    }
  }

  // Método auxiliar para construir una consulta segura
  String _buildSearchQuery(String? title, String? artist) {
    // Si no tenemos ni título ni artista, devolver cadena vacía
    if ((title == null || title.isEmpty) && (artist == null || artist.isEmpty)) {
      return '';
    }
    
    final List<String> queryParts = [];
    
    // Extraer género si tenemos un título
    if (title != null && title.isNotEmpty) {
      final genres = _extractGenres(title);
      if (genres.isNotEmpty) {
        queryParts.add(genres.first);
      }
    }
    
    // Añadir artista si está disponible
    if (artist != null && artist.isNotEmpty) {
      queryParts.add(artist);
    } else if (title != null && title.isNotEmpty) {
      // Intentar extraer artista del título si no se proporcionó explícitamente
      final extractedArtist = _extractArtist(title);
      if (extractedArtist.isNotEmpty) {
        queryParts.add(extractedArtist);
      }
    }
    
    // Si no pudimos extraer información, usar el título como fallback
    if (queryParts.isEmpty && title != null && title.isNotEmpty) {
      // Usar las primeras palabras del título como consulta
      final words = title.split(' ').where((word) => word.length > 3).take(3);
      queryParts.addAll(words);
    }
    
    return queryParts.join(' ').trim();
  }

  // Métodos auxiliares para extraer información del título
  List<String> _extractGenres(String title) {
    // Lista de géneros musicales populares para detectar
    final genreKeywords = {
      'bachata': ['bachata'],
      'salsa': ['salsa'],
      'reggaeton': ['reggaeton', 'reggaetón', 'regeton'],
      'merengue': ['merengue'],
      'pop': ['pop'],
      'rock': ['rock'],
      'hip hop': ['hip hop', 'rap'],
      'electronic': ['electronic', 'edm', 'house', 'techno'],
      'r&b': ['r&b', 'rnb', 'rhythm and blues'],
      'jazz': ['jazz'],
      'classical': ['classical', 'orchestra'],
      'country': ['country'],
      // Añadir más géneros según sea necesario
    };
    
    final titleLower = title.toLowerCase();
    final foundGenres = <String>[];
    
    genreKeywords.forEach((genre, keywords) {
      for (final keyword in keywords) {
        if (titleLower.contains(keyword)) {
          foundGenres.add(genre);
          break; // Si encontramos una coincidencia, pasamos al siguiente género
        }
      }
    });
    
    return foundGenres;
  }

  String _extractArtist(String title) {
    // Patrones comunes para extraer artistas:
    // 1. "Artista - Título"
    // 2. "Título by Artista"
    
    // Intentar patrón "Artista - Título"
    final dashPattern = RegExp(r'^(.*?)\s*-\s*.*$');
    final dashMatch = dashPattern.firstMatch(title);
    if (dashMatch != null && dashMatch.group(1) != null) {
      return dashMatch.group(1)!.trim();
    }
    
    // Intentar patrón "Título by Artista"
    final byPattern = RegExp(r'.*\sby\s+(.*?)(\s|\(|$)');
    final byMatch = byPattern.firstMatch(title);
    if (byMatch != null && byMatch.group(1) != null) {
      return byMatch.group(1)!.trim();
    }
    
    // Si no podemos extraer con confianza, devolver cadena vacía
    return '';
  }
}