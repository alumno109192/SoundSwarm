import 'package:flutter/foundation.dart';
import 'package:soundswarm/model/youtube_video.dart';
import 'package:soundswarm/service/offline_mode_service.dart';
import 'package:soundswarm/service/fastapi_service.dart';

// Simplificar las fuentes disponibles
enum MusicSource {
  fastapi,  // Servidor principal
  offline   // Modo sin conexión
}

class MusicProvider {
  // Simplificar a un solo servicio
  final FastApiService _apiService = FastApiService();
  
  // Controlar si estamos en modo offline
  bool _offlineMode = false;
  
  // Getters
  bool get isOfflineMode => _offlineMode;
  
  // URL base para FastAPI, ajustable según entorno
  static String fastApiBaseUrl = kDebugMode 
      ? 'http://127.0.0.1:8000'  // Local durante desarrollo
      : 'https://tu-servidor-fastapi.com';  // Producción si decides desplegarlo
  
  // Activar/desactivar modo offline
  void setOfflineMode(bool enabled) {
    _offlineMode = enabled;
  }
  
  // Búsqueda de canciones simplificada
  Future<List<YouTubeVideo>> searchSongs(String query) async {
    // Si estamos en modo offline, usar canciones guardadas
    if (_offlineMode) {
      return await OfflineModeService.getSearchResults(query);
    }
    
    try {
      // Intentar búsqueda con FastAPI
      final results = await _apiService.searchVideos(query);
      
      // Guardar resultados para modo offline
      await OfflineModeService.saveRecentSearch(query, results);
      
      return results;
    } catch (e) {
      if (kDebugMode) {
        print('Error en la búsqueda: $e');
      }
      
      // Fallback a caché offline en caso de error
      try {
        if (kDebugMode) {
          print('Usando resultados offline como fallback');
        }
        return await OfflineModeService.getSearchResults(query);
      } catch (e2) {
        // Si no hay nada en caché, devolver lista vacía
        if (kDebugMode) {
          print('No hay resultados en caché: $e2');
        }
        return [];
      }
    }
  }
  
  // Método para obtener URL de streaming
  Future<String> getAudioUrl(String videoId) async {
    try {
      // Usar directamente FastAPI
      return await _apiService.getAudioUrl(videoId);
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener audio URL: $e');
      }
      
      // No hay fallback para audio URLs, simplemente lanzar la excepción
      rethrow;
    }
  }
  
  // Método para obtener videos relacionados
  Future<List<YouTubeVideo>> getRelatedVideos(String videoId) async {
    try {
      // Usar directamente FastAPI
      return await _apiService.getRelatedVideos(videoId);
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener videos relacionados: $e');
      }
      
      // Devolver lista vacía en caso de error
      return [];
    }
  }
  
  // Añadir este método
  Future<void> retryServerConnection() async {
    // Reiniciar cualquier estado interno que pueda estar causando el error
    // Por ejemplo, resetear tiempos de espera, reiniciar clientes HTTP, etc.
    
    // Por ahora es una implementación simple que solo registra el intento
    if (kDebugMode) {
      print('Intentando reconectar con el servidor...');
    }
  }
}