import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:soundswarm/model/youtube_video.dart';
import 'package:soundswarm/service/audio_service.dart';
import 'package:soundswarm/service/playlist_service.dart';

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
  get relatedSongs => _relatedSongs;
  int _currentSongIndex = 0;
  get currentSongIndex => _currentSongIndex;
  Duration _position = Duration.zero;

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

  // Callbacks para notificar cambios en la UI
  Function(String? thumbnailUrl)? onThumbnailChanged;
  Function(YouTubeVideo? song)? onSongChanged;
  Function(bool isPlaying)? onPlayStateChanged;

  get hasPreloadError => null;

  // Inicialización del reproductor
  Future<void> initializePlayer() async {
    try {
      _audioPlayer = AudioPlayer();
      //_setupAudioPlayerListeners();
      _isInitialized = true;
      if (kDebugMode) {
        print('AudioPlayer inicializado correctamente');
      }
      // _loadFromCache();
    } catch (e) {
      if (kDebugMode) {
        print('Error al inicializar AudioPlayer: $e');
      }
      //Future.delayed(const Duration(seconds: 1), _initializePlayer);
    }
  }

  void _initializePlayer() {
    _audioPlayer = AudioPlayer();
    _isInitialized = true;
    if (kDebugMode) {
      print('AudioPlayer inicializado correctamente');
    }
  }

  // MÉTODO PRINCIPAL DE REPRODUCCIÓN - SIMPLIFICADO
  Future<void> playSong(BuildContext context, YouTubeVideo video) async {
    try {
      // Obtener SIEMPRE un audioUrl fresco
      final audioService = AudioService();
      Map<String, dynamic> audioUrl = await audioService.getAudioUrl(
        video.videoId,
      );

      if (audioUrl.isEmpty || !audioUrl['streamUrl'].startsWith('http')) {
        throw Exception('URL de audio inválida');
      }

      // Probar la URL con un HEAD request (opcional, para debug)
      // Puedes usar http.head(Uri.parse(audioUrl)) para verificar el Content-Type

      final mediaItem = MediaItem(
        id: video.videoId,
        title: video.title,
        artist: video.channelTitle,
        artUri: Uri.parse(video.thumbnailUrl),
        duration:
            audioUrl['duration'] != null
                ? Duration(seconds: audioUrl['duration'])
                : null, // Duración opcional
      );

      await _audioPlayer.stop();
      await _audioPlayer.setAudioSource(
        AudioSource.uri(Uri.parse(audioUrl['streamUrl']), tag: mediaItem),
      );
      await _audioPlayer.play();

      _isPlaying = true;
      onPlayStateChanged?.call(true);

      // Notificar UI
      onSongChanged?.call(video);
      onThumbnailChanged?.call(video.thumbnailUrl);

      audioService.dispose();
    } catch (e) {
      if (kDebugMode) {
        print('Error definitivo al reproducir audio: $e');
        print('URL obtenida: ${video.audioUrl}');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al reproducir: $e')));
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
        final audioUrlMap = await audioService.getAudioUrl(nextVideo.videoId);
        audioUrl = audioUrlMap['streamUrl'] as String;
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
      //_saveToCache();
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
      await _audioPlayer.setUrl(audioUrl['streamUrl']);
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
                    //_showAddToPlaylistDialog(context, currentSong);
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

  // Setters para actualizar canción y estado
  void setCurrentSong(YouTubeVideo? song) {
    _currentSong = song;
    onSongChanged?.call(song);
    //_saveToCache();
  }

  void setThumbnail(String url) {
    _currentThumbnailUrl = url;
    onThumbnailChanged?.call(url);
  }

  void setPlayState(bool isPlaying) {
    _isPlaying = isPlaying;
    onPlayStateChanged?.call(isPlaying);
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

  /// Reproduce todas las canciones de la lista en orden aleatorio
  Future<void> playAllRandomSong(
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
      // Mezclar la lista de canciones
      final random = Random();
      final shuffledPlaylist = List<YouTubeVideo>.from(playlist)
        ..shuffle(random);

      // Mostrar indicador de carga
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cargando playlist aleatoria...')),
      );

      // Reproducir la primera canción de la lista mezclada
      await playSong(context, shuffledPlaylist.first);

      // Cargar todas las canciones en la lista de reproducción mezclada
      AudioPlayerManager._instance.loadPlaylist(shuffledPlaylist);

      // Notificar al usuario
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reproduciendo aleatoriamente: ${shuffledPlaylist.first.title}',
            ),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al reproducir la playlist aleatoria: $e');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al reproducir la playlist aleatoria: $e'),
          ),
        );
      }
    }
  }

  void setupPositionListener() {
    _audioPlayer.positionStream.listen((position) {
      _position = position;
      notifyListeners();
    });
  }
}
