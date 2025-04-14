import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:soundswarm/model/youtube_video.dart';

class YouTubeApiService {
  final String apiKey = 'AIzaSyCOJ6QuVNRH_cJ5_PNrNUF8St9XMJmBHL4';
  final String baseUrl = 'https://www.googleapis.com/youtube/v3/search';

  Future<List<YouTubeVideo>> searchVideos(String query) async {
    // Codificar correctamente la query
    final encodedQuery = Uri.encodeComponent(query);
    final uri = Uri.parse('$baseUrl?part=snippet&type=video&q=$encodedQuery&key=$apiKey');
    
    print('Buscando con URL: ${uri.toString()}');
    
    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List<dynamic>? ?? [];
        
        // Verificación adicional
        final videos = <YouTubeVideo>[];
        for (var item in items) {
          try {
            final video = YouTubeVideo.fromJson(item);
            videos.add(video);
          } catch (e) {
            print('Error al procesar un video: $e');
            // Continuar con el siguiente elemento
          }
        }
        
        return videos;
      } else {
        print('Error en búsqueda: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error en searchVideos: $e');
      return [];
    }
  }

  Future<List<YouTubeVideo>> getRelatedVideos(String videoId, {String? title, String? artist}) async {
    try {
      // Extraer el género actual si está disponible
      String currentGenre = '';
      if (title != null && title.isNotEmpty) {
        List<String> genres = _extractGenres(title);
        if (genres.isNotEmpty) {
          currentGenre = genres.first;
        }
      }
      
      // Construir una consulta específica del género
      String searchQuery;
      if (currentGenre.isNotEmpty) {
        // Priorizar el género (añadir más términos específicos del género)
        searchQuery = '$currentGenre música $currentGenre';
        
        // Si también tenemos un artista, usarlo como término secundario
        if (artist != null && artist.isNotEmpty) {
          searchQuery = '$searchQuery $artist';
        }
        
        print('Buscando música del género: $currentGenre');
      } else {
        // Usar el método estándar si no detectamos un género
        searchQuery = _buildSearchQuery(title, artist);
      }
      
      print('Buscando videos similares con: "$searchQuery"');
      return await searchVideos(searchQuery);
    } catch (e) {
      print('Error obteniendo videos relacionados: $e');
      return [];
    }
  }

  // Método para búsqueda alternativa cuando falla la API de videos relacionados
  Future<List<YouTubeVideo>> _fallbackSearch(String? title, String? artist) async {
    try {
      final searchQuery = _buildSearchQuery(title, artist);
      print('Buscando videos similares con: "$searchQuery"');
      
      if (searchQuery.isNotEmpty) {
        return await searchVideos(searchQuery);
      } else {
        return await searchVideos("música popular");
      }
    } catch (e) {
      print('Error en fallback search: $e');
      return [];
    }
  }

  // Método auxiliar para construir una consulta segura
  String _buildSearchQuery(String? title, String? artist) {
    // Si no tenemos ni título ni artista, devolver búsqueda genérica
    if ((title == null || title.isEmpty) && (artist == null || artist.isEmpty)) {
      return 'música popular';
    }
    
    final List<String> queryParts = [];
    
    // Extraer género si tenemos un título y darle prioridad
    if (title != null && title.isNotEmpty) {
      final genres = _extractGenres(title);
      if (genres.isNotEmpty) {
        // Duplicar el género al inicio para darle más peso
        queryParts.add(genres.first);
        queryParts.add(genres.first + ' música');
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
      // Usar solo las primeras palabras del título para evitar detalles específicos
      final words = title.split(' ').take(3);
      queryParts.addAll(words);
    }
    
    // Si aún no hay nada, usar una búsqueda genérica
    if (queryParts.isEmpty) {
      return 'música popular';
    }
    
    return queryParts.join(' ').trim();
  }

  // Métodos auxiliares para extraer información del título
  List<String> _extractGenres(String title) {
    // Lista ampliada de géneros musicales para detectar
    final genreKeywords = {
      'bachata': ['bachata', 'bachatero', 'bachatera'],
      'salsa': ['salsa', 'salsero', 'salsera'],
      'reggaeton': ['reggaeton', 'reggaetón', 'regeton', 'regueton'],
      'merengue': ['merengue'],
      'dembow': ['dembow', 'dembo'],
      'latin': ['latin', 'latino', 'latina'],
      'pop': ['pop'],
      'rock': ['rock'],
      'hip hop': ['hip hop', 'rap', 'trap'],
      'electronic': ['electronic', 'edm', 'house', 'techno', 'trance', 'dubstep'],
      'r&b': ['r&b', 'rnb', 'rhythm and blues'],
      'jazz': ['jazz'],
      'classical': ['classical', 'orchestra', 'piano solo'],
      'country': ['country'],
      'flamenco': ['flamenco', 'rumba'],
      'mariachi': ['mariachi', 'ranchera'],
      'cumbia': ['cumbia'],
      'vallenato': ['vallenato'],
      // Muchos más géneros...
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