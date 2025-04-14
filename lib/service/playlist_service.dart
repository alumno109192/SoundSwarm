import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundswarm/model/playlist.dart';
import 'package:soundswarm/model/youtube_video.dart';

class PlaylistService {
  static const String _playlistsKey = 'user_playlists';
  static const String _favoritesKey = 'favorite_songs';
  static List<Playlist> _cachedPlaylists = [];
  static List<YouTubeVideo> _cachedFavorites = [];
  static bool _initialized = false;

  // Inicializar el servicio (llamar en main.dart)
  static Future<void> initialize() async {
    if (_initialized) return;
    
    await _loadPlaylists();
    await _loadFavorites();
    _initialized = true;
  }

  // Obtener todas las playlists
  static List<Playlist> getPlaylists() {
    return List.from(_cachedPlaylists);
  }

  // Crear nueva playlist
  static Future<Playlist> createPlaylist(String name, {String? description}) async {
    final playlist = Playlist.create(name, description: description);
    _cachedPlaylists.add(playlist);
    await _savePlaylists();
    return playlist;
  }

  // Obtener playlist por ID
  static Playlist? getPlaylist(String id) {
    return _cachedPlaylists.firstWhere(
      (playlist) => playlist.id == id,
      orElse: () => throw Exception('Playlist no encontrada'),
    );
  }

  // Actualizar playlist existente
  static Future<void> updatePlaylist(Playlist playlist) async {
    final index = _cachedPlaylists.indexWhere((p) => p.id == playlist.id);
    if (index >= 0) {
      _cachedPlaylists[index] = playlist;
      await _savePlaylists();
    }
  }

  // Eliminar playlist
  static Future<void> deletePlaylist(String id) async {
    _cachedPlaylists.removeWhere((playlist) => playlist.id == id);
    await _savePlaylists();
  }

  // Añadir canción a playlist
  static Future<void> addSongToPlaylist(String playlistId, YouTubeVideo song) async {
    final playlist = getPlaylist(playlistId);
    if (playlist != null) {
      playlist.addSong(song);
      await updatePlaylist(playlist);
    }
  }

  // Quitar canción de playlist
  static Future<void> removeSongFromPlaylist(String playlistId, String videoId) async {
    final playlist = getPlaylist(playlistId);
    if (playlist != null) {
      playlist.removeSong(videoId);
      await updatePlaylist(playlist);
    }
  }

  // Favoritos como playlist especial
  static List<YouTubeVideo> getFavorites() {
    return List.from(_cachedFavorites);
  }

  static Future<void> addFavorite(YouTubeVideo song) async {
    if (!_cachedFavorites.any((s) => s.videoId == song.videoId)) {
      _cachedFavorites.add(song);
      await _saveFavorites();
    }
  }

  static Future<void> removeFavorite(String videoId) async {
    _cachedFavorites.removeWhere((song) => song.videoId == videoId);
    await _saveFavorites();
  }

  static bool isFavorite(String videoId) {
    return _cachedFavorites.any((song) => song.videoId == videoId);
  }

  // Métodos privados para cargar/guardar datos
  static Future<void> _loadPlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playlistsJson = prefs.getStringList(_playlistsKey) ?? [];
      
      _cachedPlaylists = playlistsJson
          .map((json) => Playlist.fromJson(jsonDecode(json)))
          .toList();
          
      if (_cachedPlaylists.isEmpty) {
        // Crear playlist "Favoritos" si no existe ninguna
        _cachedPlaylists.add(Playlist.create('Mis favoritos', 
          description: 'Tus canciones favoritas'));
        await _savePlaylists();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al cargar playlists: $e');
      }
      _cachedPlaylists = [];
    }
  }

  static Future<void> _savePlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playlistsJson = _cachedPlaylists
          .map((playlist) => jsonEncode(playlist.toJson()))
          .toList();
      
      await prefs.setStringList(_playlistsKey, playlistsJson);
    } catch (e) {
      if (kDebugMode) {
        print('Error al guardar playlists: $e');
      }
    }
  }

  static Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getStringList(_favoritesKey) ?? [];
      
      _cachedFavorites = favoritesJson
          .map((json) => YouTubeVideo.fromJson(jsonDecode(json)))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error al cargar favoritos: $e');
      }
      _cachedFavorites = [];
    }
  }

  static Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = _cachedFavorites
          .map((song) => jsonEncode(song.toJson()))
          .toList();
      
      await prefs.setStringList(_favoritesKey, favoritesJson);
    } catch (e) {
      if (kDebugMode) {
        print('Error al guardar favoritos: $e');
      }
    }
  }
}