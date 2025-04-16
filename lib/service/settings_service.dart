import 'package:soundswarm/service/file_storage_service.dart';
import 'package:flutter/foundation.dart';

class SettingsService {
  // Nombre del archivo JSON
  static const String _settingsFileName = 'settings.json';
  
  // Claves para configuraciones
  static const String keyServerUrl = 'server_url';
  static const String keyOfflineMode = 'offline_mode';
  static const String keyThemeMode = 'theme_mode';
  static const String keyAutoplay = 'autoplay';
  
  // Caché en memoria
  static Map<String, dynamic>? _settingsCache;
  
  // Obtener todas las configuraciones
  static Future<Map<String, dynamic>> _getAllSettings() async {
    // Si ya tenemos las configuraciones en caché, devolvemos la caché
    if (_settingsCache != null) {
      return _settingsCache!;
    }
    
    try {
      // Leer el archivo JSON de configuraciones
      final settingsJson = await FileStorageService.readFromFile(_settingsFileName);
      
      if (settingsJson == null) {
        // Si no hay archivo, devolver mapa vacío
        _settingsCache = {};
        return {};
      }
      
      // Guardar en caché
      _settingsCache = settingsJson as Map<String, dynamic>;
      
      return _settingsCache!;
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener configuraciones: $e');
      }
      return {};
    }
  }
  
  // Guardar todas las configuraciones
  static Future<void> _saveAllSettings(Map<String, dynamic> settings) async {
    try {
      // Guardar en archivo
      await FileStorageService.saveToFile(_settingsFileName, settings);
      
      // Actualizar caché
      _settingsCache = settings;
    } catch (e) {
      if (kDebugMode) {
        print('Error al guardar configuraciones: $e');
      }
      rethrow;
    }
  }
  
  // Guardar una configuración
  static Future<void> saveSetting(String key, dynamic value) async {
    try {
      // Obtener configuraciones
      final settings = await _getAllSettings();
      
      // Actualizar valor
      settings[key] = value;
      
      // Guardar configuraciones
      await _saveAllSettings(settings);
    } catch (e) {
      if (kDebugMode) {
        print('Error al guardar configuración: $e');
      }
      rethrow;
    }
  }
  
  // Obtener una configuración
  static Future<dynamic> getSetting(String key, {dynamic defaultValue}) async {
    try {
      // Obtener configuraciones
      final settings = await _getAllSettings();
      
      // Devolver valor o valor por defecto
      return settings[key] ?? defaultValue;
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener configuración: $e');
      }
      return defaultValue;
    }
  }
  
  // Guardar URL del servidor
  static Future<void> saveServerUrl(String url) async {
    await saveSetting(keyServerUrl, url);
  }
  
  // Obtener URL del servidor
  static Future<String> getServerUrl() async {
    return await getSetting(keyServerUrl, defaultValue: 'http://127.0.0.1:8000');
  }
  
  // Guardar modo offline
  static Future<void> saveOfflineMode(bool enabled) async {
    await saveSetting(keyOfflineMode, enabled);
  }
  
  // Obtener modo offline
  static Future<bool> getOfflineMode() async {
    return await getSetting(keyOfflineMode, defaultValue: false);
  }
  
  // Guardar modo de tema
  static Future<void> saveThemeMode(String mode) async {
    await saveSetting(keyThemeMode, mode);
  }
  
  // Obtener modo de tema
  static Future<String> getThemeMode() async {
    return await getSetting(keyThemeMode, defaultValue: 'system');
  }
  
  // Guardar configuración de reproducción automática
  static Future<void> saveAutoplay(bool enabled) async {
    await saveSetting(keyAutoplay, enabled);
  }
  
  // Obtener configuración de reproducción automática
  static Future<bool> getAutoplay() async {
    return await getSetting(keyAutoplay, defaultValue: true);
  }
  
  // Limpiar caché (útil al cerrar la aplicación)
  static void clearCache() {
    _settingsCache = null;
  }
}