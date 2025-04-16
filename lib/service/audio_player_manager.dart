import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:soundswarm/model/youtube_video.dart';
import 'package:soundswarm/service/audio_service.dart';
import 'package:soundswarm/service/api_service.dart';
import 'package:soundswarm/service/playlist_service.dart'; // Add this import
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AudioPlayerManager extends ChangeNotifier {
  // Singleton pattern
  static final AudioPlayerManager _instance = AudioPlayerManager._internal();
  factory AudioPlayerManager() => _instance;
  AudioPlayerManager._internal() {
    _initializePlayer();
  }

  // AudioPlayer con inicialización segura
  late AudioPlayer _audioPlayer;
  bool _isInitialized = false;
  
  // Métodos para verificar y esperar inicialización
  bool get isInitialized => _isInitialized;
  
  Future<void> _initializePlayer() async {
    try {
      _audioPlayer = AudioPlayer();
      _setupAudioPlayerListeners();
      _isInitialized = true;
      if (kDebugMode) {
        print('AudioPlayer inicializado correctamente');
      }
      _loadFromCache(); // Cargar canción de la caché al iniciar
    } catch (e) {
      if (kDebugMode) {
        print('Error al inicializar AudioPlayer: $e');
      }
      // Reintentar inicialización después de un retraso
      Future.delayed(const Duration(seconds: 1), _initializePlayer);
    }
  }

  // Getter para el audioPlayer
  AudioPlayer get audioPlayer {
    if (!_isInitialized) {
      throw Exception('AudioPlayer no inicializado correctamente');
    }
    return _audioPlayer;
  }

  // Variables privadas
  bool _isPlaying = false;
  String? _currentThumbnailUrl;
  YouTubeVideo? _currentSong;
  List<YouTubeVideo> _relatedSongs = [];
  int _currentSongIndex = 0;
  final YouTubeApiService _apiService = YouTubeApiService();
  
  // Duration tracking for UI
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  
  // Getters
  bool get isPlaying => _isPlaying;
  String? get currentThumbnailUrl => _currentThumbnailUrl;
  YouTubeVideo? get currentSong => _currentSong;
  Duration get position => _position;
  Duration get duration => _duration;
  
  // Callbacks para notificar cambios en la UI
  Function(String? thumbnailUrl)? onThumbnailChanged;
  Function(YouTubeVideo? song)? onSongChanged;
  Function(bool isPlaying)? onPlayStateChanged;
  
  void _setupAudioPlayerListeners() {
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (_relatedSongs.isNotEmpty && _currentSongIndex < _relatedSongs.length - 1) {
          playNextSong();
        }
      }
      
      // Update the playing state
      _isPlaying = state.playing;
      if (onPlayStateChanged != null) {
        onPlayStateChanged!(_isPlaying);
      }
    });
    
    _audioPlayer.positionStream.listen((position) {
      _position = position;
      
      // Guardar la posición periódicamente (cada 5 segundos)
      if (position.inSeconds % 5 == 0) {
        _saveToCache();
      }
      
      notifyListeners();
    });
    
    _audioPlayer.durationStream.listen((duration) {
      _duration = duration != null 
          ? Duration(seconds: (duration.inSeconds / 2).round()) 
          : Duration.zero;
    });
    
    _audioPlayer.playingStream.listen((isPlaying) {
      _isPlaying = isPlaying;
      if (onPlayStateChanged != null) {
        onPlayStateChanged!(_isPlaying);
      }
    });
  }
  
  /// Método para reproducir una canción
  Future<void> playSong(BuildContext context, YouTubeVideo video) async {
    try {
      // Mostrar indicador de carga
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cargando: ${video.title}...')),
        );
      }
      
      // Actualizar estado
      _currentSong = video;
      _currentThumbnailUrl = video.thumbnailUrl;
      
      // Notificar a la UI
      if (onSongChanged != null) {
        onSongChanged!(video);
      }
      
      if (onThumbnailChanged != null) {
        onThumbnailChanged!(video.thumbnailUrl);
      }
      
      // Guardar en caché inmediatamente
      _saveToCache();
      
      // Obtener URL del audio (usar tu servicio FastAPI)
      final audioService = AudioService();
      final audioUrl = await audioService.getAudioUrl(video.videoId);
      
      if (kDebugMode) {
        print('URL de audio obtenida: $audioUrl');
      }
      
      // Crear MediaItem (obligatorio para just_audio_background)
      final mediaItem = MediaItem(
        id: video.videoId,
        title: video.title,
        artist: video.channelTitle,
        artUri: Uri.parse(video.thumbnailUrl),
        displayTitle: video.title,
        displaySubtitle: video.channelTitle,
      );
      
      // Detener cualquier reproducción actual
      await _audioPlayer.stop();
      
      // Establecer la fuente de audio
      try {
        await _audioPlayer.setAudioSource(
          AudioSource.uri(
            Uri.parse(audioUrl),
            tag: mediaItem, // El tag es obligatorio para just_audio_background
          ),
        );
        
        // Iniciar reproducción
        await _audioPlayer.play();
        
        // Actualizar estado de reproducción
        _isPlaying = true;
        if (onPlayStateChanged != null) {
          onPlayStateChanged!(true);
        }
        
        // Cargar canciones relacionadas en segundo plano
        loadRelatedSongs(video.videoId);
        
        // Mostrar mensaje de éxito
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Reproduciendo: ${video.title}')),
          );
        }
        
      } catch (e) {
        if (kDebugMode) {
          print('Error al reproducir audio: $e');
        }
        
        // Intento alternativo más básico
        try {
          if (kDebugMode) {
            print('Intentando método alternativo...');
          }
          
          // Volver a intentar con setUrl directo 
          // (aún necesitamos proporcionar MediaItem por separado)
          await _audioPlayer.setUrl(audioUrl);
          
          // Al usar setUrl con just_audio_background, hay que proporcionar metadata manualmente
          // La clase AudioHandler no está disponible directamente, así que usamos esta alternativa
          await _audioPlayer.play();
          
          // Actualizar estado de reproducción
          _isPlaying = true;
          if (onPlayStateChanged != null) {
            onPlayStateChanged!(true);
          }
          
        } catch (e2) {
          if (kDebugMode) {
            print('Error en reproducción alternativa: $e2');
          }
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No se pudo reproducir el audio')),
            );
          }
          
          rethrow;
        }
      }
      
      // Limpiar recursos del servicio
      audioService.dispose();
      
    } catch (e) {
      if (kDebugMode) {
        print('Error general en playSong: $e');
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
  
  Future<void> loadRelatedSongs(String videoId) async {
    try {
      if (videoId.isEmpty) {
        if (kDebugMode) {
          print('ID de video vacío, no se pueden cargar canciones relacionadas');
        }
        return;
      }
      
      final relatedVideos = await _apiService.getRelatedVideos(
        videoId, 
        title: _currentSong?.title ?? '',
        artist: _currentSong?.channelTitle ?? '',
      );
      
      if (relatedVideos.isNotEmpty) {
        _relatedSongs = relatedVideos;
        _currentSongIndex = 0;
        
        if (kDebugMode) {
          print('Se cargaron ${relatedVideos.length} canciones relacionadas');
        }
      } else {
        if (kDebugMode) {
          print('No se encontraron canciones relacionadas');
        }
      }
      
      // Notificar a los oyentes si usas ChangeNotifier
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error al cargar canciones relacionadas: $e');
      }
    }
  }
  
  Future<void> playNextSong() async {
    if (_relatedSongs.isEmpty || _currentSongIndex >= _relatedSongs.length - 1) {
      if (_currentSong != null) {
        await loadRelatedSongs(_currentSong!.videoId);
      }
      
      if (_relatedSongs.isEmpty) {
        return;
      }
    }
    
    _currentSongIndex++;
    if (_currentSongIndex < _relatedSongs.length) {
      final nextVideo = _relatedSongs[_currentSongIndex];
      
      // No usamos playSong porque necesitaríamos context
      // En su lugar, actualizamos estado y reproducimos directamente
      try {
        final audioService = AudioService();
        
        // Actualizar estado
        _currentSong = nextVideo;
        _currentThumbnailUrl = nextVideo.thumbnailUrl;
        
        // Guardar en caché
        _saveToCache();
        
        // Notificar a la UI
        if (onSongChanged != null) {
          onSongChanged!(nextVideo);
        }
        
        if (onThumbnailChanged != null) {
          onThumbnailChanged!(nextVideo.thumbnailUrl);
        }
        
        // Obtener URL del audio
        
        // Reproducir
        try {
          
        } catch (e) {
          if (kDebugMode) {
            print('Error con background playback: $e');
          }
        }
        
        // Limpiar recursos
        audioService.dispose();
      } catch (e) {
        if (kDebugMode) {
          print('Error al reproducir siguiente canción: $e');
        }
      }
    }
  }
  
  Future<void> playPreviousSong() async {
    if (_relatedSongs.isEmpty || _currentSongIndex <= 0) {
      if (_currentSongIndex == 0 && _relatedSongs.isNotEmpty) {
        await _audioPlayer.seek(Duration.zero);
        return;
      }
      
      return;
    }
    
    _currentSongIndex--;
    if (_currentSongIndex >= 0) {
      final previousVideo = _relatedSongs[_currentSongIndex];
      
      // Lógica similar a playNextSong
      try {
        final audioService = AudioService();
        
        // Actualizar estado
        _currentSong = previousVideo;
        _currentThumbnailUrl = previousVideo.thumbnailUrl;
        
        // Guardar en caché
        _saveToCache();
        
        // Notificar a la UI
        if (onSongChanged != null) {
          onSongChanged!(previousVideo);
        }
        
        if (onThumbnailChanged != null) {
          onThumbnailChanged!(previousVideo.thumbnailUrl);
        }
        
        // Obtener URL del audio
        
        // Reproducir
        try {

          await _audioPlayer.play();
          
        } catch (e) {
          if (kDebugMode) {
            print('Error con background playback: $e');
          }
        }
        
        // Limpiar recursos
        audioService.dispose();
      } catch (e) {
        if (kDebugMode) {
          print('Error al reproducir canción anterior: $e');
        }
      }
    }
  }
  
  void togglePlayPause() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
  }
  
  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }

  void showCurrentSongOptions(BuildContext context) {
    // Si no hay canción actual, mostrar mensaje informativo
    if (_currentSong == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero debes reproducir una canción para ver las opciones'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final currentSong = _currentSong!;
    
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Añadir a una lista'),
              onTap: () {
                Navigator.pop(context);
                _showAddToPlaylistDialog(context, currentSong);
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: Text(
                PlaylistService.isFavorite(currentSong.videoId)
                    ? 'Quitar de favoritos'
                    : 'Añadir a favoritos',
              ),
              onTap: () async {
                Navigator.pop(context);
                if (PlaylistService.isFavorite(currentSong.videoId)) {
                  await PlaylistService.removeFavorite(currentSong.videoId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${currentSong.title} quitada de favoritos')),
                    );
                  }
                } else {
                  await PlaylistService.addFavorite(currentSong);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${currentSong.title} añadida a favoritos')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, YouTubeVideo video) {
    final playlists = PlaylistService.getPlaylists();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Añadir a lista'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: playlists.isEmpty 
                ? const Center(child: Text('No tienes listas creadas'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return ListTile(
                        title: Text(playlist.name),
                        onTap: () async {
                          Navigator.pop(context);
                          
                          // Comprobar si la canción ya está en la lista
                          bool songExists = playlist.songs.any(
                            (song) => song.videoId == video.videoId
                          );
                          
                          if (songExists) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${video.title} ya está en ${playlist.name}'),
                              ),
                            );
                            return;
                          }
                          
                          await PlaylistService.addSongToPlaylist(playlist.id, video);
                          
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${video.title} añadida a ${playlist.name}'),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showCreatePlaylistDialog(context, video);
              },
              child: const Text('Nueva lista'),
            ),
          ],
        );
      },
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, YouTubeVideo video) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva lista'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej: Mis favoritas',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText: 'Ej: Canciones para el gimnasio',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final description = descriptionController.text.trim().isNotEmpty
                    ? descriptionController.text.trim()
                    : null;
                
                Navigator.pop(context);
                
                final playlist = await PlaylistService.createPlaylist(
                  name, 
                  description: description,
                );
                
                await PlaylistService.addSongToPlaylist(playlist.id, video);
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${video.title} añadida a $name'),
                    ),
                  );
                }
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
  
  void setCurrentSong(YouTubeVideo? song) {
    _currentSong = song;
    if (onSongChanged != null) {
      onSongChanged!(song);
    }
    // Guardar en caché
    _saveToCache();
  }

  void setThumbnail(String url) {
    _currentThumbnailUrl = url;
    if (onThumbnailChanged != null) {
      onThumbnailChanged!(url);
    }
    // No necesitamos guardar esto separadamente ya que setCurrentSong guardará todo
  }

  void setPlayState(bool isPlaying) {
    _isPlaying = isPlaying;
    if (onPlayStateChanged != null) {
      onPlayStateChanged!(isPlaying);
    }
  }

  // Método para guardar la canción actual en caché
  Future<void> _saveToCache() async {
    try {
      if (_currentSong == null) {
        return;
      }
      
      final prefs = await SharedPreferences.getInstance();
      
      // Guardar datos de la canción
      final songData = {
        'videoId': _currentSong!.videoId,
        'title': _currentSong!.title,
        'thumbnailUrl': _currentSong!.thumbnailUrl,
        'channelTitle': _currentSong!.channelTitle,
        'description': _currentSong!.description
      };
      
      // Guardar como cadena JSON
      await prefs.setString('current_song', jsonEncode(songData));
      
      // Guardar la posición actual
      await prefs.setInt('current_position', _position.inMilliseconds);
      
      if (kDebugMode) {
        print('Canción guardada en caché: ${_currentSong!.title}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al guardar en caché: $e');
      }
    }
  }
  
  // Método para cargar la canción desde la caché
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Intentar cargar datos de la canción
      final songJson = prefs.getString('current_song');
      if (songJson == null) {
        return;
      }
      
      // Parsear los datos
      final songData = jsonDecode(songJson) as Map<String, dynamic>;
      
      // Crear objeto YouTubeVideo
      final cachedSong = YouTubeVideo(
        videoId: songData['videoId'],
        title: songData['title'],
        thumbnailUrl: songData['thumbnailUrl'],
        channelTitle: songData['channelTitle'],
        description: songData['description']
      );
      
      // Restaurar los valores
      _currentSong = cachedSong;
      _currentThumbnailUrl = cachedSong.thumbnailUrl;
      
      // Restaurar posición si existe
      if (prefs.containsKey('current_position')) {
        final savedPosition = prefs.getInt('current_position') ?? 0;
        _position = Duration(milliseconds: savedPosition);
      }
      
      // Notificar cambios
      if (onSongChanged != null) {
        onSongChanged!(cachedSong);
      }
      
      if (onThumbnailChanged != null) {
        onThumbnailChanged!(cachedSong.thumbnailUrl);
      }
      
      if (kDebugMode) {
        print('Canción cargada desde caché: ${cachedSong.title}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al cargar desde caché: $e');
      }
    }
  }
}