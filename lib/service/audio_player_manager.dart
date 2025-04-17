import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundswarm/model/playlist.dart';
import 'package:soundswarm/model/youtube_video.dart';
import 'package:soundswarm/service/audio_service.dart';
import 'package:soundswarm/service/playlist_service.dart';
import 'package:soundswarm/service/recent_songs_service.dart';

class AudioPlayerManager extends ChangeNotifier {
  // Singleton instance
  static final AudioPlayerManager _instance = AudioPlayerManager._internal();

  // Private constructor
  AudioPlayerManager._internal() {
    // Initialize player when the singleton is created
    _initializePlayer();
  }

  // Alternative approach using factory constructor
  factory AudioPlayerManager() {
    return _instance;
  }

  // Public getter for the singleton instance
  static AudioPlayerManager get instance => _instance;

  // Variables privadas
  late AudioPlayer _audioPlayer;
  bool _isInitialized = false;
  bool _isPlaying = false;
  String? _currentThumbnailUrl;
  YouTubeVideo? _currentSong;
  List<YouTubeVideo> _relatedSongs = [];
  int _currentSongIndex = 0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPreloadingNext = false;
  YouTubeVideo? _preloadedSong;
  // Variables adicionales para reintentos
  int _preloadRetries = 0;
  static const int _maxPreloadRetries = 3;
  bool _preloadFailureNotified = false;
  bool _preloadError = false;

  // Getters
  bool get isInitialized => _isInitialized;
  AudioPlayer get audioPlayer {
    if (!_isInitialized) {
      throw Exception('AudioPlayer no inicializado correctamente');
    }
    return _audioPlayer;
  }

  bool get isPlaying => _isPlaying;
  String? get currentThumbnailUrl => _currentThumbnailUrl;
  YouTubeVideo? get currentSong => _currentSong;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get hasPreloadError => _preloadError;

  // Callbacks para notificar cambios en la UI
  Function(String? thumbnailUrl)? onThumbnailChanged;
  Function(YouTubeVideo? song)? onSongChanged;
  Function(bool isPlaying)? onPlayStateChanged;

  // Inicialización del reproductor
  Future<void> _initializePlayer() async {
    try {
      _audioPlayer = AudioPlayer();
      _setupAudioPlayerListeners();
      _isInitialized = true;
      if (kDebugMode) {
        print('AudioPlayer inicializado correctamente');
      }
      _loadFromCache();
    } catch (e) {
      if (kDebugMode) {
        print('Error al inicializar AudioPlayer: $e');
      }
      Future.delayed(const Duration(seconds: 1), _initializePlayer);
    }
  }

  // Configurar listeners del reproductor
  void _setupAudioPlayerListeners() {
    _audioPlayer.playerStateStream.listen((state) {
      if (kDebugMode) {
        print(
          'Estado del reproductor: ${state.processingState}, reproduciendo: ${state.playing}',
        );
      }

      if (state.processingState == ProcessingState.completed) {
        if (kDebugMode) {
          print('CANCIÓN COMPLETADA - Iniciando siguiente canción');
        }

        // Es importante usar microtask para asegurar que se ejecute tan pronto como sea posible
        playNextSong();
      }

      _isPlaying = state.playing;
      onPlayStateChanged?.call(_isPlaying);
      notifyListeners();
    });

    _audioPlayer.positionStream.listen((position) {
      _position = position;

      // Calcular la mitad de la duración
      final halfDuration = Duration(seconds: (_duration.inSeconds / 2).round());

      // Si llega a la mitad, pasar a la siguiente canción
      if (_duration.inSeconds > 0 &&
          position.inSeconds >= halfDuration.inSeconds) {
        if (kDebugMode) {
          print('⏩ Llegó a la mitad, pasando a la siguiente canción');
        }
        playNextSong();
        return; // Evita seguir ejecutando el resto del listener
      }

      // Precargar siguiente canción cuando queden 30 segundos o menos para la mitad
      if (_duration.inSeconds > 0 &&
          _position.inSeconds > 0 &&
          halfDuration.inSeconds - _position.inSeconds <= 30 &&
          !_isPreloadingNext &&
          _relatedSongs.isNotEmpty &&
          _currentSongIndex < _relatedSongs.length - 1) {
        _preloadNextSong();
      }

      if (position.inSeconds % 5 == 0) {
        _saveToCache();
      }
      notifyListeners();
    });

    _audioPlayer.durationStream.listen((duration) {
      _duration = duration ?? Duration.zero;
      notifyListeners();
    });

    _audioPlayer.playingStream.listen((isPlaying) {
      _isPlaying = isPlaying;
      notifyListeners();
    });
  }

  // MÉTODO PRINCIPAL DE REPRODUCCIÓN - SIMPLIFICADO
  Future<void> playSong(BuildContext context, YouTubeVideo video) async {
    try {
      // Actualizar estado
      _currentSong = video;
      _currentThumbnailUrl = video.thumbnailUrl;

      // Notificar UI
      onSongChanged?.call(video);
      onThumbnailChanged?.call(video.thumbnailUrl);

      // Guardar en caché y historial
      _saveToCache();
      try {
        RecentSongsService.addRecentSong(video);
      } catch (e) {
        // Ignorar errores no críticos
      }

      String audioUrl;
      final audioService = AudioService();

      // Comprobar si la canción ya tiene un enlace de audio válido
      if (video.audioUrl != null && !video.isAudioUrlExpired) {
        audioUrl = video.audioUrl!;
        if (kDebugMode) {
          print('Usando enlace de audio guardado: $audioUrl');
        }
      } else {
        // Obtener URL de audio
        audioUrl = await audioService.getAudioUrl(video.videoId);

        // Actualizar el enlace en la canción
        _currentSong = video.copyWithAudioUrl(audioUrl);

        if (kDebugMode) {
          print('URL de audio nueva obtenida: $audioUrl');
        }
      }

      // Detener reproducción actual
      await _audioPlayer.stop();

      // Crear MediaItem y reproducir
      final mediaItem = MediaItem(
        id: video.videoId,
        title: video.title,
        artist: video.channelTitle,
        artUri: Uri.parse(video.thumbnailUrl),
      );

      try {
        // Método principal
        await _audioPlayer.setAudioSource(
          AudioSource.uri(Uri.parse(audioUrl), tag: mediaItem),
        );
        await _audioPlayer.play();
        _isPlaying = true;
        onPlayStateChanged?.call(true);
      } catch (e) {
        if (kDebugMode) {
          print('Error al reproducir audio: $e');
          print('Intentando método alternativo...');
        }

        // Método alternativo más simple
        try {
          await _audioPlayer.setUrl(audioUrl);
          await _audioPlayer.play();
          _isPlaying = true;
          onPlayStateChanged?.call(true);
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

      // Cargar canciones relacionadas (mínimo)
      if (_relatedSongs.isEmpty) {
        _relatedSongs = [
          _currentSong!,
        ]; // Al menos incluir la canción actual con URL actualizada
        _currentSongIndex = 0;
      }

      // Mostrar mensaje de éxito
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reproduciendo: ${video.title}')),
        );
      }

      // Limpiar recursos
      audioService.dispose();
    } catch (e) {
      if (kDebugMode) {
        print('Error general en playSong: $e');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().substring(0, 100)}...'),
          ),
        );
      }
    }
  }

  // Método básico para simular canciones relacionadas
  Future<void> loadRelatedSongs(String videoId) async {
    try {
      if (videoId.isEmpty) return;

      // Si tenemos una canción actual, asegurarnos de incluirla
      if (_currentSong != null) {
        if (_relatedSongs.isEmpty) {
          _relatedSongs = [_currentSong!];
          _currentSongIndex = 0;
        }
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error al cargar canciones relacionadas: $e');
      }
      _relatedSongs = _currentSong != null ? [_currentSong!] : [];
    }
  }

  // Reproducir siguiente canción - SIMPLIFICADO
  Future<void> playNextSong() async {
    if (kDebugMode) {
      print('Iniciando reproducción de siguiente canción...');
      print(
        'Lista: ${_relatedSongs.length} canciones, índice actual: $_currentSongIndex',
      );
    }

    if (_relatedSongs.isEmpty) {
      if (kDebugMode) {
        print('No hay canciones en la lista para reproducir');
      }
      return;
    }

    // Incrementar índice
    _currentSongIndex++;

    // Si llegamos al final, PARAR la reproducción y salir
    if (_currentSongIndex >= _relatedSongs.length) {
      if (kDebugMode) {
        print('Fin de la lista, deteniendo reproducción');
      }
      await _audioPlayer.pause();
      _isPlaying = false;
      onPlayStateChanged?.call(false);
      notifyListeners();
      return;
    }

    final nextVideo = _relatedSongs[_currentSongIndex];

    try {
      // Obtener URL de audio actualizada
      String audioUrl;
      if (nextVideo.audioUrl != null && !nextVideo.isAudioUrlExpired) {
        audioUrl = nextVideo.audioUrl!;
        if (kDebugMode) print('Usando URL en caché para: ${nextVideo.title}');
      } else {
        final audioService = AudioService();
        audioUrl = await audioService.getAudioUrl(nextVideo.videoId);
        // Actualizar la canción en la lista con la nueva URL
        _relatedSongs[_currentSongIndex] = nextVideo.copyWithAudioUrl(audioUrl);
        audioService.dispose();
        if (kDebugMode) print('Nueva URL obtenida para: ${nextVideo.title}');
      }

      // Actualizar estado y notificar UI
      _currentSong = _relatedSongs[_currentSongIndex];
      _currentThumbnailUrl = _currentSong!.thumbnailUrl;
      onSongChanged?.call(_currentSong);
      onThumbnailChanged?.call(_currentThumbnailUrl);

      // Detener y reproducir la nueva canción
      await _audioPlayer.stop();

      final mediaItem = MediaItem(
        id: _currentSong!.videoId,
        title: _currentSong!.title,
        artist: _currentSong!.channelTitle,
        artUri: Uri.parse(_currentSong!.thumbnailUrl),
      );

      await _audioPlayer.setAudioSource(
        AudioSource.uri(Uri.parse(audioUrl), tag: mediaItem),
      );
      await _audioPlayer.play();

      _isPlaying = true;
      onPlayStateChanged?.call(true);
      _saveToCache();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error al reproducir siguiente canción: $e');
      }
      // Intentar con la siguiente si hay error
      Future.delayed(const Duration(seconds: 2), () {
        playNextSong();
      });
    }
  }

  // Reproducir canción anterior - SIMPLIFICADO
  Future<void> playPreviousSong() async {
    if (_relatedSongs.isEmpty || _currentSong == null) return;

    // Si estamos al inicio o cerca, simplemente reiniciar la canción actual
    if (_currentSongIndex <= 0 || _position.inSeconds > 3) {
      await _audioPlayer.seek(Duration.zero);
      return;
    }

    _currentSongIndex--;
    final previousVideo = _relatedSongs[_currentSongIndex];

    // Actualizar UI
    _currentSong = previousVideo;
    _currentThumbnailUrl = previousVideo.thumbnailUrl;
    onSongChanged?.call(previousVideo);
    onThumbnailChanged?.call(previousVideo.thumbnailUrl);

    try {
      // Obtener URL
      final audioService = AudioService();
      final audioUrl = await audioService.getAudioUrl(previousVideo.videoId);

      // Reproducir
      await _audioPlayer.stop();
      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.play();

      _isPlaying = true;
      onPlayStateChanged?.call(true);

      audioService.dispose();
    } catch (e) {
      if (kDebugMode) {
        print('Error al reproducir canción anterior: $e');
      }
    }
  }

  // Alternar reproducción/pausa
  void togglePlayPause() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
  }

  // Buscar a una posición específica
  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }

  // Mostrar opciones de la canción actual
  void showCurrentSongOptions(BuildContext context) {
    if (_currentSong == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Primero debes reproducir una canción para ver las opciones',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final currentSong = _currentSong!;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return FutureBuilder<bool>(
          future: PlaylistService.isFavorite(currentSong.videoId),
          builder: (context, snapshot) {
            final isFavorite = snapshot.data ?? false;

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
                    isFavorite ? 'Quitar de favoritos' : 'Añadir a favoritos',
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final currentIsFavorite = await PlaylistService.isFavorite(
                      currentSong.videoId,
                    );

                    if (currentIsFavorite) {
                      await PlaylistService.removeFavorite(currentSong.videoId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${currentSong.title} quitada de favoritos',
                            ),
                          ),
                        );
                      }
                    } else {
                      await PlaylistService.addFavorite(currentSong);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${currentSong.title} añadida a favoritos',
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Mostrar diálogo para añadir a lista
  void _showAddToPlaylistDialog(BuildContext context, YouTubeVideo video) {
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<List<Playlist>>(
          future: PlaylistService.getPlaylists(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                title: Text('Cargando listas...'),
                content: Center(child: CircularProgressIndicator()),
              );
            }

            final playlists = snapshot.data ?? [];

            return AlertDialog(
              title: const Text('Añadir a lista'),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child:
                    playlists.isEmpty
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

                                bool songExists = playlist.songs.any(
                                  (song) => song.videoId == video.videoId,
                                );

                                if (songExists) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${video.title} ya está en ${playlist.name}',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                await PlaylistService.addSongToPlaylist(
                                  playlist.id,
                                  video,
                                );

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${video.title} añadida a ${playlist.name}',
                                      ),
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
      },
    );
  }

  // Mostrar diálogo para crear lista
  void _showCreatePlaylistDialog(BuildContext context, YouTubeVideo video) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
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
                    final description =
                        descriptionController.text.trim().isNotEmpty
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

  // Setters para actualizar canción y estado
  void setCurrentSong(YouTubeVideo? song) {
    _currentSong = song;
    onSongChanged?.call(song);
    _saveToCache();
  }

  void setThumbnail(String url) {
    _currentThumbnailUrl = url;
    onThumbnailChanged?.call(url);
  }

  void setPlayState(bool isPlaying) {
    _isPlaying = isPlaying;
    onPlayStateChanged?.call(isPlaying);
  }

  // Persistencia en caché
  Future<void> _saveToCache() async {
    try {
      if (_currentSong == null) return;

      final prefs = await SharedPreferences.getInstance();

      final songData = {
        'videoId': _currentSong!.videoId,
        'title': _currentSong!.title,
        'thumbnailUrl': _currentSong!.thumbnailUrl,
        'channelTitle': _currentSong!.channelTitle,
        'description': _currentSong!.description,
      };

      await prefs.setString('current_song', jsonEncode(songData));
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

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final songJson = prefs.getString('current_song');
      if (songJson == null) return;

      final songData = jsonDecode(songJson) as Map<String, dynamic>;

      final cachedSong = YouTubeVideo(
        videoId: songData['videoId'],
        title: songData['title'],
        thumbnailUrl: songData['thumbnailUrl'],
        channelTitle: songData['channelTitle'],
        description: songData['description'],
      );

      _currentSong = cachedSong;
      _currentThumbnailUrl = cachedSong.thumbnailUrl;

      if (prefs.containsKey('current_position')) {
        final savedPosition = prefs.getInt('current_position') ?? 0;
        _position = Duration(milliseconds: savedPosition);
      }

      onSongChanged?.call(cachedSong);
      onThumbnailChanged?.call(cachedSong.thumbnailUrl);

      if (kDebugMode) {
        print('Canción cargada desde caché: ${cachedSong.title}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al cargar desde caché: $e');
      }
    }
  }

  // Añade este método a la clase _PlaylistDetailScreenState

  // Método para reproducir todas las canciones
  Future<void> playAllSongs(
    BuildContext context,
    List<YouTubeVideo> playlist,
  ) async {
    if (playlist.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('La playlist está vacía')));
      return;
    }

    try {
      // Mostrar indicador de carga
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cargando playlist...')));

      // Reproducir la primera canción
      await playSong(context, playlist.first);

      // Cargar todas las canciones en la lista de reproducción
      AudioPlayerManager._instance.loadPlaylist(playlist);

      // Notificar al usuario
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reproduciendo: ${playlist.first.title}')),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al reproducir la playlist: $e');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al reproducir la playlist: $e')),
        );
      }
    }
  }

  /// Carga una lista completa de canciones para reproducción
  void loadPlaylist(List<YouTubeVideo> songs) {
    if (songs.isEmpty) return;

    // Guardar la lista de canciones como relacionadas
    _relatedSongs = List.from(songs);

    // Establecer el índice a 0 (primera canción)
    _currentSongIndex = 0;

    if (kDebugMode) {
      print('Playlist cargada con ${songs.length} canciones');
    }

    // Notificar cambios
    notifyListeners();
  }

  // Nuevo método para precargar la siguiente canción con reintentos
  Future<void> _preloadNextSong() async {
    if (_isPreloadingNext || _relatedSongs.isEmpty) return;

    _isPreloadingNext = true;

    try {
      // Calcular índice de la siguiente canción
      int nextIndex = _currentSongIndex + 1;
      if (nextIndex >= _relatedSongs.length) {
        _isPreloadingNext = false;
        return;
      }

      final nextSong = _relatedSongs[nextIndex];

      if (kDebugMode) {
        print(
          'Precargando siguiente canción: ${nextSong.title} (intento ${_preloadRetries + 1}/$_maxPreloadRetries)',
        );
      }

      // Verificar si ya tenemos una URL válida
      if (nextSong.audioUrl != null && !nextSong.isAudioUrlExpired) {
        _preloadedSong = nextSong;

        // Reiniciar contador de reintentos al tener éxito
        _preloadRetries = 0;
        _preloadFailureNotified = false;

        if (kDebugMode) {
          print('Usando URL precargada de la caché');
        }
      } else {
        // Obtener URL del audio en segundo plano
        final audioService = AudioService();
        try {
          final audioUrl = await audioService.getAudioUrl(nextSong.videoId);

          // Actualizar la URL en la canción
          _preloadedSong = nextSong.copyWithAudioUrl(audioUrl);

          // Actualizar la canción en la lista
          _relatedSongs[nextIndex] = _preloadedSong!;

          // Reiniciar contador de reintentos al tener éxito
          _preloadRetries = 0;
          _preloadFailureNotified = false;

          if (kDebugMode) {
            print('Nueva URL precargada: ${audioUrl.substring(0, 50)}...');
          }
        } catch (e) {
          _preloadRetries++;

          if (kDebugMode) {
            print('Error al precargar canción (intento $_preloadRetries): $e');
          }

          // Si aún no hemos superado el máximo de reintentos, programar un reintento
          if (_preloadRetries < _maxPreloadRetries) {
            Future.delayed(Duration(seconds: 2 * _preloadRetries), () {
              _isPreloadingNext = false; // Permitir un nuevo intento
              _preloadNextSong(); // Reintentar
            });
            return; // Salir para evitar restablecer _isPreloadingNext
          } else {
            // Hemos agotado los reintentos
            if (!_preloadFailureNotified) {
              _handlePreloadFailure();
              _preloadFailureNotified = true;
            }
          }
        } finally {
          audioService.dispose();
        }
      }
    } catch (e) {
      _preloadRetries++;

      if (kDebugMode) {
        print('Error general al precargar (intento $_preloadRetries): $e');
      }

      // Si aún no hemos superado el máximo de reintentos, programar un reintento
      if (_preloadRetries < _maxPreloadRetries) {
        Future.delayed(Duration(seconds: 2 * _preloadRetries), () {
          _isPreloadingNext = false; // Permitir un nuevo intento
          _preloadNextSong(); // Reintentar
        });
        return; // Salir para evitar restablecer _isPreloadingNext
      } else {
        // Hemos agotado los reintentos
        if (!_preloadFailureNotified) {
          _handlePreloadFailure();
          _preloadFailureNotified = true;
        }
      }
    } finally {
      _isPreloadingNext = false;
    }
  }

  // Método para manejar el fallo después de múltiples reintentos
  void _handlePreloadFailure() {
    if (kDebugMode) {
      print(
        'No se pudo cargar la siguiente canción después de $_maxPreloadRetries intentos',
      );
    }

    // Si la canción actual está por terminar (menos de 5 segundos), detener reproducción
    if (_duration.inSeconds > 0 &&
        _position.inSeconds > 0 &&
        _duration.inSeconds - _position.inSeconds <= 5) {
      _audioPlayer.pause();
      _isPlaying = false;
      onPlayStateChanged?.call(false);

      // Usar overlay para mostrar mensaje sin contexto
      _showPreloadErrorOverlay();
    }

    // Reiniciar para futuros intentos
    _preloadRetries = 0;
  }

  // Método para mostrar mensaje de error como overlay
  void _showPreloadErrorOverlay() {
    // Necesitamos un BuildContext para mostrar SnackBar o Dialog
    // Como alternativa, podemos usar una variable de estado que la UI pueda observar
    _preloadError = true;
    notifyListeners();

    // Programar un limpiado del error después de un tiempo
    Future.delayed(const Duration(seconds: 5), () {
      _preloadError = false;
      notifyListeners();
    });
  }
}
