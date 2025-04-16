import 'package:path_provider/path_provider.dart';
import 'package:soundswarm/model/youtube_video.dart';
import 'dart:io';
import 'dart:convert';

class OfflineModeService {
  // Cache para búsquedas recientes
  static Future<void> saveRecentSearch(String query, List<YouTubeVideo> results) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/search_cache.json');
    
    Map<String, List<Map<String, dynamic>>> searchCache = {};
    
    // Cargar caché existente si existe
    if (file.existsSync()) {
      final data = await file.readAsString();
      final Map<String, dynamic> jsonData = jsonDecode(data);
      
      // Convertir de JSON a nuestro formato
      jsonData.forEach((key, value) {
        searchCache[key] = (value as List).map((item) => 
          Map<String, dynamic>.from(item as Map)).toList();
      });
    }
    
    // Añadir/actualizar la búsqueda actual
    searchCache[query] = results.map((video) => {
      'videoId': video.videoId,
      'title': video.title,
      'thumbnailUrl': video.thumbnailUrl,
      'channelTitle': video.channelTitle,
      'description': video.description,
    }).toList();
    
    // Limitar el tamaño de la caché (por ejemplo, 20 búsquedas)
    if (searchCache.length > 20) {
      final keysToRemove = searchCache.keys.toList().sublist(0, searchCache.length - 20);
      for (final key in keysToRemove) {
        searchCache.remove(key);
      }
    }
    
    // Guardar la caché actualizada
    await file.writeAsString(jsonEncode(searchCache));
  }
  
  // Obtener resultados de una búsqueda en caché
  static Future<List<YouTubeVideo>> getSearchResults(String query) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/search_cache.json');
      
      if (!file.existsSync()) {
        return [];
      }
      
      final data = await file.readAsString();
      final Map<String, dynamic> jsonData = jsonDecode(data);
      
      // Si tenemos una coincidencia exacta
      if (jsonData.containsKey(query)) {
        final List<dynamic> results = jsonData[query];
        return _convertToYouTubeVideos(results);
      }
      
      // Si no hay una coincidencia exacta, buscar resultados parciales
      // (implementación simple, se podría mejorar con algoritmos de búsqueda)
      for (final key in jsonData.keys) {
        if (key.toLowerCase().contains(query.toLowerCase()) || 
            query.toLowerCase().contains(key.toLowerCase())) {
          final List<dynamic> results = jsonData[key];
          return _convertToYouTubeVideos(results);
        }
      }
      
      // Si no hay coincidencias, devolver el resultado más reciente
      if (jsonData.isNotEmpty) {
        final List<dynamic> mostRecent = jsonData[jsonData.keys.last];
        return _convertToYouTubeVideos(mostRecent);
      }
      
      return [];
    } catch (e) {
      print('Error loading search results: $e');
      return [];
    }
  }
  
  // Utilidad para convertir datos JSON a objetos YouTubeVideo
  static List<YouTubeVideo> _convertToYouTubeVideos(List<dynamic> data) {
    return data.map((item) => YouTubeVideo(
      videoId: item['videoId'],
      title: item['title'],
      thumbnailUrl: item['thumbnailUrl'],
      channelTitle: item['channelTitle'],
      description: item['description'],
    )).toList();
  }
  
  // Guardado de canciones favoritas para offline
  static Future<void> saveOfflineSongs(List<YouTubeVideo> songs) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/offline_songs.json');
    
    final List<Map<String, dynamic>> songsData = songs.map((song) => {
      'videoId': song.videoId,
      'title': song.title,
      'thumbnailUrl': song.thumbnailUrl,
      'channelTitle': song.channelTitle,
      'description': song.description,
    }).toList();
    
    await file.writeAsString(jsonEncode(songsData));
  }
  
  static Future<List<YouTubeVideo>> getOfflineSongs() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/offline_songs.json');
      
      if (!file.existsSync()) {
        return [];
      }
      
      final data = await file.readAsString();
      final List<dynamic> songsData = jsonDecode(data);
      
      return _convertToYouTubeVideos(songsData);
    } catch (e) {
      print('Error loading offline songs: $e');
      return [];
    }
  }
}