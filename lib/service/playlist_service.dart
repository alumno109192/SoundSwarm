import 'package:soundswarm/model/youtube_video.dart';
import 'package:soundswarm/model/playlist.dart';
import 'package:soundswarm/service/file_storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:soundswarm/service/playlist_db_service.dart';

class PlaylistService {
  // Nombre de los archivos JSON
  static const String _playlistsFileName = 'playlists.json';
  static const String _favoritesFileName = 'favorites.json';

  // Caché en memoria
  static List<Playlist>? _playlistsCache;
  static List<YouTubeVideo>? _favoritesCache;

  // MÉTODOS PARA PLAYLISTS

  // Obtener todas las playlists
  static Future<List<Playlist>> getPlaylists() async {
    // Si ya tenemos las playlists en caché, devolvemos la caché
    if (_playlistsCache != null) {
      return _playlistsCache!;
    }

    try {
      // Leer el archivo JSON de playlists
      final playlistsJson = await FileStorageService.readFromFile(
        _playlistsFileName,
      );

      if (playlistsJson == null) {
        // Si no hay archivo, devolver lista vacía
        _playlistsCache = [];
        return [];
      }

      // Convertir JSON a lista de Playlist
      final playlists =
          (playlistsJson as List)
              .map((json) => Playlist.fromJson(json))
              .toList();

      // Guardar en caché
      _playlistsCache = playlists;

      return playlists;
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener playlists: $e');
      }
      return [];
    }
  }

  // Guardar todas las playlists
  static Future<void> _savePlaylists(List<Playlist> playlists) async {
    try {
      // Convertir playlists a JSON
      final playlistsJson =
          playlists.map((playlist) => playlist.toJson()).toList();

      // Guardar en archivo
      await FileStorageService.saveToFile(_playlistsFileName, playlistsJson);
      //Guardar en SQLite
      await PlaylistDbService.savePlaylistsToDatabase(playlists);

      // Actualizar caché
      _playlistsCache = playlists;
    } catch (e) {
      if (kDebugMode) {
        print('Error al guardar playlists: $e');
      }
      rethrow;
    }
  }

  // Obtener una playlist por ID
  static Future<Playlist?> getPlaylist(String id) async {
    final playlists = await getPlaylists();

    // Versión corregida
    try {
      return playlists.firstWhere((playlist) => playlist.id == id);
    } catch (e) {
      // Si no se encuentra la playlist, devolver null
      return null;
    }
  }

  // Crear nueva playlist
  static Future<Playlist> createPlaylist(
    String name, {
    String? description,
  }) async {
    try {
      // Crear nueva playlist
      final playlist = Playlist.create(name, description: description);

      // Obtener playlists existentes
      final playlists = await getPlaylists();

      // Añadir nueva playlist
      playlists.add(playlist);

      // Guardar playlists
      await _savePlaylists(playlists);

      return playlist;
    } catch (e) {
      if (kDebugMode) {
        print('Error al crear playlist: $e');
      }
      rethrow;
    }
  }

  // Añadir canción a playlist con su enlace de audio
  static Future<void> addSongToPlaylist(
    String playlistId,
    YouTubeVideo song,
  ) async {
    try {
      // Obtener playlists
      final playlists = await getPlaylists();

      // Buscar playlist
      final playlistIndex = playlists.indexWhere((p) => p.id == playlistId);

      if (playlistIndex == -1) {
        throw Exception('Playlist no encontrada');
      }

      // Añadir canción directamente - usamos la canción tal cual viene
      playlists[playlistIndex].addSong(song);

      // Guardar playlists
      //await _savePlaylists(playlists);
      // Guardar el enlace de audio en la canción
      await PlaylistService.saveSongToSqlite(playlistId, song);

      if (kDebugMode) {
        final canciones = await PlaylistDbService.getSongsFromDatabase(
          playlistId,
        );
        print('Canciones en la playlist: ${canciones.length}');
        for (var cancion in canciones) {
          print('Canción: ${cancion.title}');
          print('Enlace: ${cancion.audioUrl}');
          print('ID: ${cancion.videoId}');
          print('-------------------');
        }
        if (song.audioUrl != null) {
          print('Canción añadida a playlist con enlace existente');
        } else {
          print('Canción añadida a playlist sin enlace de audio');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al añadir canción a playlist: $e');
      }
      rethrow;
    }
  }

  // Eliminar canción de playlist
  static Future<void> removeSongFromPlaylist(
    String playlistId,
    String videoId,
  ) async {
    try {
      // Obtener playlists
      final playlists = await getPlaylists();

      // Buscar playlist
      final playlistIndex = playlists.indexWhere((p) => p.id == playlistId);

      if (playlistIndex == -1) {
        throw Exception('Playlist no encontrada');
      }

      // Eliminar canción
      playlists[playlistIndex].removeSong(videoId);

      // Guardar playlists
      await _savePlaylists(playlists);
    } catch (e) {
      if (kDebugMode) {
        print('Error al eliminar canción de playlist: $e');
      }
      rethrow;
    }
  }

  // Eliminar playlist
  static Future<void> deletePlaylist(String id) async {
    try {
      // Obtener playlists
      final playlists = await getPlaylists();

      // Eliminar playlist
      playlists.removeWhere((playlist) => playlist.id == id);

      // Guardar playlists
      await _savePlaylists(playlists);
    } catch (e) {
      if (kDebugMode) {
        print('Error al eliminar playlist: $e');
      }
      rethrow;
    }
  }

  // MÉTODOS PARA FAVORITOS

  // Obtener canciones favoritas
  static Future<List<YouTubeVideo>> getFavorites() async {
    // Si ya tenemos los favoritos en caché, devolvemos la caché
    if (_favoritesCache != null) {
      return _favoritesCache!;
    }

    try {
      // Leer el archivo JSON de favoritos
      final favoritesJson = await FileStorageService.readFromFile(
        _favoritesFileName,
      );

      if (favoritesJson == null) {
        // Si no hay archivo, devolver lista vacía
        _favoritesCache = [];
        return [];
      }

      // Convertir JSON a lista de YouTubeVideo
      final favorites =
          (favoritesJson as List)
              .map((json) => YouTubeVideo.fromJson(json))
              .toList();

      // Guardar en caché
      _favoritesCache = favorites;

      return favorites;
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener favoritos: $e');
      }
      return [];
    }
  }

  // Verificar si una canción es favorita
  static Future<bool> isFavorite(String videoId) async {
    final favorites = await getFavorites();
    return favorites.any((video) => video.videoId == videoId);
  }

  // Añadir canción a favoritos
  static Future<void> addFavorite(YouTubeVideo song) async {
    try {
      // Obtener favoritos
      final favorites = await getFavorites();

      // Verificar si ya existe
      if (favorites.any((video) => video.videoId == song.videoId)) {
        return; // Ya existe, no hacer nada
      }
      // Guardar favoritos
      await PlaylistDbService.addSongToFavorites(song);

      if (kDebugMode) {
        if (song.audioUrl != null) {
          print('Canción añadida a favoritos con enlace existente');
        } else {
          print('Canción añadida a favoritos sin enlace de audio');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al añadir favorito: $e');
      }
      rethrow;
    }
  }

  // Eliminar canción de favoritos
  static Future<void> removeFavorite(String videoId) async {
    try {
      // Guardar favoritos
    } catch (e) {
      if (kDebugMode) {
        print('Error al eliminar favorito: $e');
      }
      rethrow;
    }
  }

  // Limpiar caché (útil al cerrar la aplicación)
  static void clearCache() {
    _playlistsCache = null;
    _favoritesCache = null;
  }

  // Añadir este método a la clase PlaylistService
  static Future<void> initialize() async {
    try {
      // Precarga las listas de reproducción y favoritos en la caché
      await getPlaylists();
      await getFavorites();

      if (kDebugMode) {
        print('PlaylistService inicializado con éxito');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al inicializar PlaylistService: $e');
      }
    }
  }

  static saveSongToSqlite(String playlistId, YouTubeVideo song) {
    // Aquí puedes implementar la lógica para guardar la canción en SQLite
    // usando el método que ya tienes en tu servicio de base de datos.
    PlaylistDbService.saveSongToSqlite(playlistId, song);
  }
}
