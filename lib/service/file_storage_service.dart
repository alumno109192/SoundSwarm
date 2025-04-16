import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class FileStorageService {
  // Obtener directorio de documentos de la aplicación
  static Future<Directory> get _appDirectory async {
    final directory = await getApplicationDocumentsDirectory();
    return directory;
  }

  // Guardar datos en un archivo JSON
  static Future<void> saveToFile(String fileName, dynamic data) async {
    try {
      final directory = await _appDirectory;
      final file = File('${directory.path}/$fileName');
      
      // Convertir datos a JSON
      final jsonString = jsonEncode(data);
      
      // Escribir en archivo
      await file.writeAsString(jsonString);
      
      if (kDebugMode) {
        print('Datos guardados en: ${file.path}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al guardar archivo: $e');
      }
      rethrow;
    }
  }

  // Leer datos desde un archivo JSON
  static Future<dynamic> readFromFile(String fileName) async {
    try {
      final directory = await _appDirectory;
      final file = File('${directory.path}/$fileName');
      
      // Verificar si el archivo existe
      if (!await file.exists()) {
        if (kDebugMode) {
          print('El archivo $fileName no existe.');
        }
        return null;
      }
      
      // Leer contenido
      final jsonString = await file.readAsString();
      
      // Convertir desde JSON
      return jsonDecode(jsonString);
    } catch (e) {
      if (kDebugMode) {
        print('Error al leer archivo: $e');
      }
      return null;
    }
  }
  
  // Verificar si un archivo existe
  static Future<bool> fileExists(String fileName) async {
    try {
      final directory = await _appDirectory;
      final file = File('${directory.path}/$fileName');
      return await file.exists();
    } catch (e) {
      return false;
    }
  }
  
  // Eliminar un archivo
  static Future<void> deleteFile(String fileName) async {
    try {
      final directory = await _appDirectory;
      final file = File('${directory.path}/$fileName');
      
      if (await file.exists()) {
        await file.delete();
        if (kDebugMode) {
          print('Archivo eliminado: ${file.path}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al eliminar archivo: $e');
      }
      rethrow;
    }
  }
}