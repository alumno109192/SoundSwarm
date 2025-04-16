import 'package:soundswarm/model/youtube_video.dart';
import 'package:soundswarm/service/file_storage_service.dart';
import 'package:flutter/foundation.dart';

class RecentSongsService {
  // Nombre del archivo JSON
  static const String _recentSongsFileName = 'recent_songs.json';
  static const String _recentSearchesFileName = 'recent_searches.json';
  
  // Caché en memoria
  static List<YouTubeVideo>? _recentSongsCache;
  static Map<String, List<YouTubeVideo>>? _recentSearchesCache;
  
  // Añadir canción reproducida recientemente
  static Future<void> addRecentSong(YouTubeVideo song) async {
    try {
      // Obtener canciones recientes
      final recentSongs = await getRecentSongs();
      
      // Eliminar si ya existe
      recentSongs.removeWhere((video) => video.videoId == song.videoId);
      
      // Añadir al inicio
      recentSongs.insert(0, song);
      
      // Limitar a 50 elementos
      if (recentSongs.length > 50) {
        recentSongs.length = 50;
      }
      
      // Guardar en archivo
      final songsJson = recentSongs.map((video) => video.toJson()).toList();
      await FileStorageService.saveToFile(_recentSongsFileName, songsJson);
      
      // Actualizar caché
      _recentSongsCache = recentSongs;
    } catch (e) {
      if (kDebugMode) {
        print('Error al añadir canción reciente: $e');
      }
    }
  }
  
  // Obtener canciones reproducidas recientemente
  static Future<List<YouTubeVideo>> getRecentSongs() async {
    // Si ya tenemos las canciones en caché, devolvemos la caché
    if (_recentSongsCache != null) {
      return _recentSongsCache!;
    }
    
    try {
      // Leer el archivo JSON de canciones recientes
      final songsJson = await FileStorageService.readFromFile(_recentSongsFileName);
      
      if (songsJson == null) {
        // Si no hay archivo, devolver lista vacía
        _recentSongsCache = [];
        return [];
      }
      
      // Convertir JSON a lista de YouTubeVideo
      final songs = (songsJson as List)
          .map((json) => YouTubeVideo.fromJson(json))
          .toList();
      
      // Guardar en caché
      _recentSongsCache = songs;
      
      return songs;
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener canciones recientes: $e');
      }
      return [];
    }
  }
  
  // Guardar resultados de búsqueda reciente
  static Future<void> saveRecentSearch(String query, List<YouTubeVideo> results) async {
    try {
      // Obtener búsquedas recientes
      final recentSearches = await getRecentSearches();
      
      // Actualizar o añadir resultados para esta consulta
      recentSearches[query] = results;
      
      // Limitar a 10 búsquedas recientes
      if (recentSearches.length > 10) {
        // Eliminar las más antiguas
        final keysToRemove = recentSearches.keys.toList().sublist(10);
        for (var key in keysToRemove) {
          recentSearches.remove(key);
        }
      }
      
      // Guardar en archivo
      final searchesJson = {};
      recentSearches.forEach((key, value) {
        searchesJson[key] = value.map((video) => video.toJson()).toList();
      });
      
      await FileStorageService.saveToFile(_recentSearchesFileName, searchesJson);
      
      // Actualizar caché
      _recentSearchesCache = recentSearches;
    } catch (e) {
      if (kDebugMode) {
        print('Error al guardar búsqueda reciente: $e');
      }
    }
  }
  
  // Obtener resultados de búsqueda guardados
  static Future<Map<String, List<YouTubeVideo>>> getRecentSearches() async {
    // Si ya tenemos las búsquedas en caché, devolvemos la caché
    if (_recentSearchesCache != null) {
      return _recentSearchesCache!;
    }
    
    try {
      // Leer el archivo JSON de búsquedas recientes
      final searchesJson = await FileStorageService.readFromFile(_recentSearchesFileName);
      
      if (searchesJson == null) {
        // Si no hay archivo, devolver mapa vacío
        _recentSearchesCache = {};
        return {};
      }
      
      // Convertir JSON a mapa de YouTubeVideo
      final searches = <String, List<YouTubeVideo>>{};
      (searchesJson as Map<String, dynamic>).forEach((key, value) {
        searches[key] = (value as List)
            .map((json) => YouTubeVideo.fromJson(json))
            .toList();
      });
      
      // Guardar en caché
      _recentSearchesCache = searches;
      
      return searches;
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener búsquedas recientes: $e');
      }
      return {};
    }
  }
  
  // Obtener resultados para una consulta específica
  static Future<List<YouTubeVideo>> getSearchResults(String query) async {
    final searches = await getRecentSearches();
    return searches[query] ?? [];
  }
  
  // Limpiar caché (útil al cerrar la aplicación)
  static void clearCache() {
    _recentSongsCache = null;
    _recentSearchesCache = null;
  }
}