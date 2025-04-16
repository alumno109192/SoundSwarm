import 'package:soundswarm/service/file_storage_service.dart';
import 'package:flutter/foundation.dart';

class HistoryService {
  // Nombre del archivo JSON
  static const String _searchHistoryFileName = 'search_history.json';
  
  // Caché en memoria
  static List<String>? _searchHistoryCache;
  
  // Obtener historial de búsqueda
  static Future<List<String>> getSearchHistory() async {
    // Si ya tenemos el historial en caché, devolvemos la caché
    if (_searchHistoryCache != null) {
      return _searchHistoryCache!;
    }
    
    try {
      // Leer el archivo JSON de historial
      final historyJson = await FileStorageService.readFromFile(_searchHistoryFileName);
      
      if (historyJson == null) {
        // Si no hay archivo, devolver lista vacía
        _searchHistoryCache = [];
        return [];
      }
      
      // Convertir JSON a lista de String
      final history = (historyJson as List).cast<String>();
      
      // Guardar en caché
      _searchHistoryCache = history;
      
      return history;
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener historial de búsqueda: $e');
      }
      return [];
    }
  }
  
  // Guardar consulta en historial
  static Future<void> saveSearchQuery(String query) async {
    if (query.trim().isEmpty) return;
    
    try {
      // Obtener historial
      final history = await getSearchHistory();
      
      // Eliminar si ya existe
      history.remove(query);
      
      // Añadir al inicio
      history.insert(0, query);
      
      // Limitar a 20 elementos
      if (history.length > 20) {
        history.length = 20;
      }
      
      // Guardar en archivo
      await FileStorageService.saveToFile(_searchHistoryFileName, history);
      
      // Actualizar caché
      _searchHistoryCache = history;
    } catch (e) {
      if (kDebugMode) {
        print('Error al guardar consulta de búsqueda: $e');
      }
    }
  }
  
  // Limpiar historial de búsqueda
  static Future<void> clearSearchHistory() async {
    try {
      // Guardar lista vacía
      await FileStorageService.saveToFile(_searchHistoryFileName, []);
      
      // Actualizar caché
      _searchHistoryCache = [];
    } catch (e) {
      if (kDebugMode) {
        print('Error al limpiar historial de búsqueda: $e');
      }
    }
  }
  
  // Limpiar caché (útil al cerrar la aplicación)
  static void clearCache() {
    _searchHistoryCache = null;
  }
}