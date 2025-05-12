import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:soundswarm/model/playlist.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../model/youtube_video.dart';
import 'dart:io';

class PlaylistDbService {
  static Database? _db;
  static Future<Database> get database async {
    if (_db != null) {
      listTables();
      return _db!;
    }
    _db = await _getDatabase();
    return _db!;
  }

  static Future<void> closeDatabase() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  static Future<Database> _getDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sonicswap.db');
    return openDatabase(
      path,
      version: 1, // Incrementa la versión de la base de datos
      onCreate: (db, version) async {
        await _createTables(db);
        if (kDebugMode) {
          print('Base de datos creada y tablas inicializadas.');
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createTables(db);
        if (kDebugMode) {
          print(
            'Base de datos actualizada de la versión $oldVersion a $newVersion.',
          );
        }
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    // Crear tabla de canciones
    await db.execute('''
      CREATE TABLE IF NOT EXISTS songs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        videoId TEXT,
        title TEXT,
        channelTitle TEXT,
        thumbnailUrl TEXT,
        description TEXT,
        durationSeconds INTEGER,
        publishedAt TEXT,
        audioUrl TEXT,
        audioUrlTimestamp INTEGER,
        playlistId TEXT
      )
    ''');

    // Crear tabla de descargas
    await db.execute('''
      CREATE TABLE IF NOT EXISTS downloads (
        id TEXT UNIQUE,
        title TEXT,
        audioUrl TEXT,
        thumbnailUrl TEXT
      )
    ''');

    // Crear tabla de favoritos
    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        videoId TEXT UNIQUE,
        title TEXT,
        channelTitle TEXT,
        thumbnailUrl TEXT,
        description TEXT
      )
    ''');

    // Crear tabla de playlists
    await db.execute('''
      CREATE TABLE IF NOT EXISTS playlists (
        id TEXT PRIMARY KEY,
        name TEXT,
        description TEXT
      )
    ''');

    // Crear tabla de canciones en playlists
    await db.execute('''
      CREATE TABLE IF NOT EXISTS playlist_songs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlistId TEXT,
        videoId TEXT,
        title TEXT,
        channelTitle TEXT,
        thumbnailUrl TEXT,
        description TEXT,
        durationSeconds INTEGER,
        publishedAt TEXT,
        audioUrl TEXT,
        audioUrlTimestamp INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS directories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        path TEXT UNIQUE
      )
    ''');

    if (kDebugMode) {
      print('Todas las tablas han sido creadas o ya existen.');
    }
  }

  static Future<void> addSongToPlaylist(
    String playlistId,
    YouTubeVideo song,
  ) async {
    final db = await database;
    await db.insert(
      'songs',
      song.toMap(playlistId),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<YouTubeVideo>> getSongsFromPlaylist(
    String playlistId,
  ) async {
    final db = await database;
    final maps = await db.query(
      'songs',
      where: 'playlistId = ?',
      whereArgs: [playlistId],
    );
    return maps.map((map) => YouTubeVideo.fromMap(map)).toList();
  }

  static Future<void> removeSongFromPlaylist(
    String playlistId,
    String videoId,
  ) async {
    final db = await database;
    await db.delete(
      'songs',
      where: 'playlistId = ? AND videoId = ?',
      whereArgs: [playlistId, videoId],
    );
  }

  static Future<void> saveSongToSqlite(
    String playlistId,
    YouTubeVideo song,
  ) async {
    final db = await _getDatabase();
    await db.insert(
      'songs',
      song.toMap(playlistId),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<YouTubeVideo>> getSongsFromDatabase(
    String playlistId,
  ) async {
    final db = await _getDatabase();
    final maps = await db.query(
      'songs',
      where: 'playlistId = ?',
      whereArgs: [playlistId],
    );
    return maps.map((map) => YouTubeVideo.fromMap(map)).toList();
  }

  static Future<void> savePlaylistsToDatabase(List<Playlist> playlists) async {
    final db = await _getDatabase();

    // Borra todas las canciones existentes (opcional, para evitar duplicados)
    await db.delete('songs');

    // Inserta todas las canciones de todas las playlists
    for (final playlist in playlists) {
      for (final song in playlist.songs) {
        await db.insert(
          'songs',
          song.toMap(playlist.id),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  // Métodos para manejar favoritos

  /// Añadir una canción a favoritos
  static Future<void> addSongToFavorites(YouTubeVideo song) async {
    final db = await database;
    await db.insert('favorites', {
      'videoId': song.videoId,
      'title': song.title,
      'channelTitle': song.channelTitle,
      'thumbnailUrl': song.thumbnailUrl,
      'description': song.description,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Eliminar una canción de favoritos
  static Future<void> removeSongFromFavorites(String videoId) async {
    final db = await database;
    await db.delete('favorites', where: 'videoId = ?', whereArgs: [videoId]);
  }

  /// Obtener todas las canciones favoritas
  static Future<List<YouTubeVideo>> getFavoriteSongs() async {
    final db = await database;
    final maps = await db.query('favorites');
    return maps.map((map) => YouTubeVideo.fromMap(map)).toList();
  }

  /// Verificar si una canción está en favoritos
  static Future<bool> isSongFavorite(String videoId) async {
    final db = await database;
    final result = await db.query(
      'favorites',
      where: 'videoId = ?',
      whereArgs: [videoId],
    );
    return result.isNotEmpty;
  }

  Future<void> saveSongToDatabase(
    YouTubeVideo songInfo,
    String filePath,
  ) async {
    final db = await database;

    // Convierte el objeto YouTubeVideo a un mapa
    final songMap = {
      'id': songInfo.videoId,
      'title': songInfo.title,
      'audioUrl': filePath,
      'thumbnailUrl': songInfo.thumbnailUrl,
    };

    // Inserta la canción en la base de datos
    await db.insert(
      'downloads',
      songMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<YouTubeVideo>> getDownloadedSongs() async {
    final db = await openDatabase('sonicswap.db');
    final result = await db.query('downloads');
    return result.map((map) => YouTubeVideo.fromMap(map)).toList();
  }

  FutureOr<YouTubeVideo> getDownloadSongById(String id) async {
    final db = await openDatabase('sonicswap.db');
    final result = await db.query(
      'downloads',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isNotEmpty) {
      return YouTubeVideo.fromMap(result.first);
    } else {
      throw Exception('No song found with id: $id');
    }
  }

  Future<void> deleteDownloadSongById(String id) async {
    final db = await openDatabase('sonicswap.db');
    await db.delete('downloads', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> listTables() async {
    final db = await _getDatabase();
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    for (var table in tables) {
      if (kDebugMode) {
        print('Tabla encontrada: ${table['name']}');
      }
    }
  }

  static Future<void> listTableColumns() async {
    final db = await _getDatabase();

    // Obtén todas las tablas en la base de datos
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );

    for (var table in tables) {
      final tableName = table['name'];
      if (kDebugMode) {
        print('Tabla: $tableName');
      }

      // Obtén las columnas de la tabla
      final columns = await db.rawQuery('PRAGMA table_info($tableName)');
      for (var column in columns) {
        if (kDebugMode) {
          print(
            '  Columna: ${column['name']}, Tipo: ${column['type']}, '
            'Clave primaria: ${column['pk'] == 1 ? 'Sí' : 'No'}',
          );
        }
      }
    }
  }

  Future<void> deleteDatabaseFile() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sonicswap.db');
    final file = File(path);

    if (await file.exists()) {
      await file.delete();
      if (kDebugMode) {
        print('Base de datos eliminada: $path');
      }
    } else {
      if (kDebugMode) {
        print('No se encontró la base de datos para eliminar.');
      }
    }
  }

  Future<void> saveDirectory(String path) async {
    final db = await PlaylistDbService.database;
    await db.insert(
      'directories',
      {'path': path},
      conflictAlgorithm: ConflictAlgorithm.replace, // Evita duplicados
    );
  }

  /// Obtiene todos los directorios guardados
  Future<List<String>> getSavedDirectories() async {
    final db = await PlaylistDbService.database;
    final directories = await db.query('directories');
    return directories.map((e) => e['path'] as String).toList();
  }

  /// Elimina un directorio guardado
  Future<void> deleteDirectory(String path) async {
    final db = await PlaylistDbService.database;
    await db.delete('directories', where: 'path = ?', whereArgs: [path]);
  }

  /// Verifica si un directorio ya está guardado
  Future<bool> isDirectorySaved(String path) async {
    final db = await PlaylistDbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'directories',
      where: 'path = ?',
      whereArgs: [path],
    );
    return maps.isNotEmpty;
  }

  /// Elimina todos los directorios guardados
  Future<void> deleteAllDirectories() async {
    final db = await PlaylistDbService.database;
    await db.delete('directories');
  }
}
