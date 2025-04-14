import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soundswarm/model/youtube_video.dart';
import 'package:soundswarm/screen/drawer.dart';
import 'package:soundswarm/service/audio_player_service.dart';
import 'package:soundswarm/service/notification_service.dart';
import 'package:soundswarm/service/youtube_api_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:soundswarm/service/audio_service.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
// Añadir esta importación
import 'package:flutter/foundation.dart';
import 'package:soundswarm/service/playlist_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio_background/just_audio_background.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isPlaying = false;
  String? _currentThumbnailUrl;
  late AudioPlayer _audioPlayer;
  
  // Añadir variables para la canción actual y canciones relacionadas
  YouTubeVideo? _currentSong;
  List<YouTubeVideo> _relatedSongs = [];
  int _currentSongIndex = 0;
  final YouTubeApiService _apiService = YouTubeApiService();
  
  // Nuevas variables para el slider
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  
  @override
  void initState() {
    super.initState();
    
    _audioPlayer = AudioPlayer();
    
    // Configurar el manejo de audio session para comportamiento correcto
    AudioSession.instance.then((session) {
      session.configure(const AudioSessionConfiguration.music());
    });
    
    // Escuchar cambios en la posición de reproducción
    _audioPlayer.positionStream.listen((position) {
      setState(() {
        _position = position;
      });
    });
    
    // Escuchar cambios en la duración total
    _audioPlayer.durationStream.listen((duration) {
      setState(() {
        _duration = duration ?? Duration.zero;
      });
    });

    // Configurar callback para reproducir canciones desde otras pantallas
    AudioPlayerService().setPlaySongCallback(_playSong);

    // Escuchar cambios en el estado de reproducción
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        // Auto-reproducir siguiente canción cuando termina
        if (_relatedSongs.isNotEmpty && _currentSongIndex < _relatedSongs.length - 1) {
          _playNextSong();
        }
      }
    });
    
    // Escuchar cambios en el estado de playing/paused
    _audioPlayer.playingStream.listen((isPlaying) {
      setState(() {
        _isPlaying = isPlaying;
      });
    });

    // Configurar callback para el estado de la pantalla
    NotificationService.onScreenStateChanged = _handleScreenStateChange;
  }

  void _handleScreenStateChange(bool isLocked) {
    // Cuando la pantalla se bloquea, asegurarse de que los controles de reproducción estén visibles
    // incluso si la app estaba en segundo plano
    if (isLocked && _isPlaying) {
      // Si estamos reproduciendo y la pantalla se bloquea, asegurarse de que los controles
      // de reproducción estén visibles en la pantalla de bloqueo
      _ensureMediaControlsVisible();
    }
  }

  void _ensureMediaControlsVisible() {
    // Este método se asegura de que los controles de reproducción estén visibles
    // en la pantalla de bloqueo cuando la pantalla se bloquea
    if (_audioPlayer.playing) {
      // Esto "refrescará" la notificación para asegurarse de que esté visible
      // en la pantalla de bloqueo
      final currentPos = _audioPlayer.position;
      _audioPlayer.seek(currentPos);
    }
  }

  // Función auxiliar para formatear duración en MM:SS
  String _formatDuration(Duration duration) {
    // Ajustar la duración para mostrar el tiempo real
    duration = Duration(seconds: duration.inSeconds ~/ 2);
    
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music P2P'),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: SongSearchDelegate(
                  onThumbnailSelected: (thumbnailUrl) {
                    setState(() {
                      _currentThumbnailUrl = thumbnailUrl; // Actualizar la carátula
                    });
                  },
                  onPlayStateChanged: (isPlaying) {
                    setState(() {
                      _isPlaying = isPlaying; // Actualizar el estado de reproducción
                    });
                  },
                  onSongSelected: (video) {
                    setState(() {
                      _currentSong = video;
                    });
                    // Cargar canciones relacionadas cuando se selecciona una canción
                    _loadRelatedSongs(video.videoId);
                  },
                  audioPlayer: _audioPlayer, // Pasar el reproductor compartido
                ),
              );
            },
          ),
        ],
      ),
      drawer: const AppDrawer(), // Usar el drawer separado aquí
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(10),
                image: _currentThumbnailUrl != null && _currentThumbnailUrl!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(_currentThumbnailUrl!),
                        fit: BoxFit.cover,
                        onError: (exception, stackTrace) {
                          // En caso de error al cargar la imagen
                          if (kDebugMode) {
                            print('Error al cargar imagen: $exception');
                          }
                        },
                      )
                    : null,
              ),
              child: _currentThumbnailUrl == null || _currentThumbnailUrl!.isEmpty
                  ? const Icon(Icons.music_note, size: 50, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 10),
            if (_currentSong != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _currentSong!.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (_currentSong != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _currentSong!.channelTitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 35),
                  onPressed: () async {
                    if (_currentSong != null) {
                      await _playPreviousSong();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No hay una canción actual para volver atrás')),
                      );
                    }
                  },
                ),
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle : Icons.play_circle,
                    size: 50,
                  ),
                  onPressed: () {
                    if (_isPlaying) {
                      // Si está reproduciendo, pausar
                      _audioPlayer.pause();
                    } else if (_currentThumbnailUrl != null) {
                      // Si hay una canción cargada, reanudar reproducción
                      _audioPlayer.play();
                    }
                    
                    setState(() {
                      _isPlaying = !_isPlaying;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 35),
                  onPressed: () async {
                    if (_currentSong != null) {
                      await _playNextSong();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No hay una canción actual para encontrar relacionadas')),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Tiempo actual con estilo mejorado
                SizedBox(
                  width: 45,
                  child: Text(
                    _formatDuration(_position),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                // Slider mejorado
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.blue[700],
                      inactiveTrackColor: Colors.grey[300],
                      thumbColor: Colors.blue,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                      // Añadir marcas de tiempo en el slider
                      tickMarkShape: const RoundSliderTickMarkShape(),
                      showValueIndicator: ShowValueIndicator.always,
                    ),
                    child: Slider(
                      min: 0,
                      max: _duration.inSeconds.toDouble()/2,
                      value: min(_position.inSeconds.toDouble(), _duration.inSeconds.toDouble()/2),
                      // Añadir etiqueta que muestra el tiempo al arrastrar
                      label: _formatDuration(Duration(seconds: _position.inSeconds)),
                      onChanged: (value) {
                        setState(() {
                          _position = Duration(seconds: value.toInt());
                        });
                      },
                      onChangeEnd: (value) async {
                        try {
                          final position = Duration(seconds: value.toInt());
                          await _audioPlayer.seek(position);
                          
                          if (!_isPlaying && _currentThumbnailUrl != null) {
                            await _audioPlayer.play();
                            setState(() {
                              _isPlaying = true;
                            });
                          }
                        } catch (e) {
                          if (kDebugMode) {
                            print('Error al buscar posición: $e');
                          }
                        }
                      },
                    ),
                  ),
                ),
                // Duración total con estilo mejorado
                SizedBox(
                  width: 45,
                  child: Text(
                    _formatDuration(_duration),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Botón anterior
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 32),
                  onPressed: _currentSongIndex > 0 ? _playPreviousSong : null,
                ),
                
                // Botón de reproducir/pausar
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    size: 48,
                  ),
                  onPressed: _currentSong != null
                      ? () {
                          if (_isPlaying) {
                            _audioPlayer.pause();
                          } else {
                            _audioPlayer.play();
                          }
                          setState(() {
                            _isPlaying = !_isPlaying;
                          });
                        }
                      : null,
                ),
                
                // Botón siguiente
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 32),
                  onPressed: _relatedSongs.isNotEmpty && _currentSongIndex < _relatedSongs.length - 1
                      ? _playNextSong
                      : null,
                ),
                
                // Nuevo botón de opciones
                if (_currentSong != null)
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showCurrentSongOptions(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    NotificationService.onScreenStateChanged = null;
    _audioPlayer.dispose(); // Liberar recursos al cerrar
    super.dispose();
  }

  Future<void> _loadRelatedSongs(String videoId) async {
    try {
      if (videoId.isEmpty) {
        if (kDebugMode) {
          print('ID de video vacío, no se pueden cargar canciones relacionadas');
        }
        return;
      }
      
      // Utilizar el API de YouTube para obtener videos relacionados, pasando título y artista
      final relatedVideos = await _apiService.getRelatedVideos(
        videoId, 
        title: _currentSong?.title ?? '',
        artist: _currentSong?.channelTitle ?? '',
      );
      
      if (relatedVideos.isNotEmpty) {
        setState(() {
          _relatedSongs = relatedVideos;
          _currentSongIndex = 0;
        });
        if (kDebugMode) {
          print('Se cargaron ${relatedVideos.length} canciones relacionadas');
        }
      } else {
        if (kDebugMode) {
          print('No se encontraron canciones relacionadas');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al cargar canciones relacionadas: $e');
      }
    }
  }

  // Método para reproducir la siguiente canción
  Future<void> _playNextSong() async {
    if (_relatedSongs.isEmpty || _currentSongIndex >= _relatedSongs.length - 1) {
      // Si no hay canciones relacionadas o estamos en la última, intentar cargar más
      if (_currentSong != null) {
        await _loadRelatedSongs(_currentSong!.videoId);
      }
      
      // Si aún no hay canciones relacionadas, mostrar mensaje
      if (_relatedSongs.isEmpty) {
        return;
      }
    }
    
    _currentSongIndex++;
    if (_currentSongIndex < _relatedSongs.length) {
      await _playSong(_relatedSongs[_currentSongIndex]);
    }
  }

  // Método para reproducir una canción
  Future<void> _playSong(YouTubeVideo video) async {
    try {
      final audioService = AudioService();
      final audioUrl = await audioService.getAudioUrl(video.videoId);
      
      // Actualizar UI inmediatamente
      setState(() {
        _currentSong = video;
        _currentThumbnailUrl = video.thumbnailUrl;
      });
      
      // Crear MediaItem para la notificación
      final mediaItem = MediaItem(
        id: video.videoId,
        title: video.title,
        artist: video.channelTitle,
        artUri: Uri.parse(video.thumbnailUrl),
        duration: await _audioPlayer.setUrl(audioUrl),
        // Usar una notificación compacta por defecto, que se expandirá
        // solo cuando la pantalla esté bloqueada
        displayDescription: NotificationService.isScreenLocked 
            ? video.description 
            : null, // No mostrar descripción en la notificación normal
        displayTitle: video.title,
        displaySubtitle: video.channelTitle,
      );
      
      // Reproducir con background playback
      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(audioUrl),
          tag: mediaItem,
        ),
      );
      
      await _audioPlayer.play();
      
      if (!mounted) return;
      
      setState(() {
        _isPlaying = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reproduciendo: ${video.title}')),
      );
      
      audioService.dispose();
    } catch (e) {
      if (kDebugMode) {
        print('Error al reproducir canción: $e');
      }
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al reproducir: $e')),
      );
    }
  }

  // Método para reproducir la canción anterior
  Future<void> _playPreviousSong() async {
    if (_relatedSongs.isEmpty || _currentSongIndex <= 0) {
      // Si estamos en la primera canción o no hay canciones previas
      if (_currentSongIndex == 0 && _relatedSongs.isNotEmpty) {
        // Si estamos en la primera canción pero hay canciones relacionadas,
        // simplemente reiniciar la canción actual
        await _audioPlayer.seek(Duration.zero);
        return;
      }
      
      if (!mounted) return; // Agregar verificación antes de usar context
      
      // Si no hay canciones relacionadas, mostrar mensaje
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay canciones anteriores disponibles')),
      );
      return;
    }
    
    // Decrementar el índice y reproducir la canción previa
    _currentSongIndex--;
    await _playSong(_relatedSongs[_currentSongIndex]);
  }

  void _showCurrentSongOptions() {
    if (_currentSong == null) return;

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
                _showAddToPlaylistDialog(_currentSong!);
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: Text(
                PlaylistService.isFavorite(_currentSong!.videoId)
                    ? 'Quitar de favoritos'
                    : 'Añadir a favoritos',
              ),
              onTap: () async {
                Navigator.pop(context);
                if (PlaylistService.isFavorite(_currentSong!.videoId)) {
                  await PlaylistService.removeFavorite(_currentSong!.videoId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${_currentSong!.title} quitada de favoritos')),
                  );
                } else {
                  await PlaylistService.addFavorite(_currentSong!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${_currentSong!.title} añadida a favoritos')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showSongDetailsDialog(YouTubeVideo video) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detalles de la canción'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.network(video.thumbnailUrl),
              const SizedBox(height: 16),
              Text('Título: ${video.title}', 
                style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Canal: ${video.channelTitle}'),
              const SizedBox(height: 8),
              Text('ID: ${video.videoId}'),
              const SizedBox(height: 8),
              Text('Publicado: ${video.publishedAt}'),
              const SizedBox(height: 8),
              const Text('Descripción:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(video.description),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylistDialog(YouTubeVideo video) {
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
                        subtitle: Text(
                          '${playlist.songs.length} ${playlist.songs.length == 1 ? 'canción' : 'canciones'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          
                          // Comprobar si la canción ya está en la lista
                          bool songExists = playlist.songs.any(
                            (song) => song.videoId == video.videoId
                          );
                          
                          if (songExists) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${video.title} ya está en ${playlist.name}'),
                              ),
                            );
                            return;
                          }
                          
                          await PlaylistService.addSongToPlaylist(playlist.id, video);
                          
                          if (!mounted) return;
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${video.title} añadida a ${playlist.name}'),
                            ),
                          );
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
                _showCreatePlaylistDialog(video);
              },
              child: const Text('Nueva lista'),
            ),
          ],
        );
      },
    );
  }

  void _showCreatePlaylistDialog(YouTubeVideo video) {
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
                
                if (!mounted) return;
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${video.title} añadida a $name'),
                  ),
                );
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}

class SongSearchDelegate extends SearchDelegate<String> {
  final YouTubeApiService _apiService = YouTubeApiService();
  final AudioService _audioService = AudioService();
  final AudioPlayer _audioPlayer; // Ya no inicializamos aquí, lo recibimos
  final Function(String) onThumbnailSelected;
  final Function(bool) onPlayStateChanged;
  final Function(YouTubeVideo)? onSongSelected; // Añadir esta línea
  bool _isPlaying = false;
  
  // Lista para almacenar el historial de búsquedas
  List<String> _searchHistory = [];
  
  SongSearchDelegate({
    required this.onThumbnailSelected,
    required this.onPlayStateChanged,
    required AudioPlayer audioPlayer, // Recibir el reproductor compartido
    this.onSongSelected, // Añadir este parámetro opcional
  }): _audioPlayer = audioPlayer {
    // Cargar el historial cuando se crea el delegado
    _loadSearchHistory();
  }
  
  // Método para cargar el historial desde SharedPreferences
  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory = prefs.getStringList('search_history') ?? [];
    });
  }
  
  // Método para guardar una nueva búsqueda en el historial
  Future<void> _saveSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    
    // Remover la consulta si ya existe (para moverla al principio)
    _searchHistory.remove(query);
    
    // Añadir la nueva consulta al principio
    _searchHistory.insert(0, query);
    
    // Limitar el historial a 10 elementos
    if (_searchHistory.length > 10) {
      _searchHistory = _searchHistory.sublist(0, 10);
    }
    
    // Guardar en SharedPreferences
    await prefs.setStringList('search_history', _searchHistory);
  }
  
  // Método para eliminar una búsqueda del historial
  Future<void> _removeFromHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    
    _searchHistory.remove(query);
    
    // Guardar en SharedPreferences
    await prefs.setStringList('search_history', _searchHistory);
  }
  
  // Método auxiliar para actualizar el estado (no existe setState en SearchDelegate)
  void setState(VoidCallback fn) {
    fn();
    // Forzar reconstrucción
    query = query;
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, ''); // Cierra el buscador
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    // Guardar la consulta en el historial cuando se busca
    _saveSearch(query);
    
    // Resto del código existente...
    return FutureBuilder<List<YouTubeVideo>>(
      future: _apiService.searchVideos(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No se encontraron resultados.'));
        } else {
          final videos = snapshot.data!;
          return ListView.builder(
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              return ListTile(
                leading: Image.network(video.thumbnailUrl),
                title: Text(
                  video.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(video.channelTitle),
                trailing: IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    _showSongOptions(context, video);
                  },
                ),
                onTap: () async {
                  try {
                    if (_isPlaying) {
                      // Pausar la reproducción
                      await _audioPlayer.pause().then((_) {
                        _isPlaying = false;
                        onPlayStateChanged(false);
                      });
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Pausado: ${video.title}')),
                        );
                      }
                    } else {
                      // Mostrar indicador de carga
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Cargando audio...')),
                        );
                      }
                      
                      // Reanudar o iniciar la reproducción
                      final audioUrl = await _audioService.getAudioUrl(video.videoId);
                      
                      // Debugging
                      if (kDebugMode) {
                        print('URL de audio: $audioUrl');
                      }
                      
                      // Verificar que la URL sea válida
                      if (audioUrl.isEmpty) {
                        throw Exception('No se pudo obtener la URL del audio');
                      }
                      
                      // Configurar el reproductor con manejadores de errores
                      try {
                        await _audioPlayer.setUrl(audioUrl);
                      } catch (e) {
                        if (kDebugMode) {
                          print('Error al configurar URL: $e');
                        }
                        throw Exception('Error al configurar reproductor: $e');
                      }
                      
                      // Esperar a que la duración esté disponible
                      try {
                        final duration = await _audioPlayer.durationStream.first;
                        if (kDebugMode) {
                          print('Duración de la canción: ${duration?.inSeconds ?? 0} segundos');
                        }
                      } catch (e) {
                        if (kDebugMode) {
                          print('Error al obtener duración: $e');
                        }
                        // Continuar a pesar del error de duración
                      }
                      
                      // Intentar reproducir
                      try {
                        await _audioPlayer.play();
                        _isPlaying = true;
                        onPlayStateChanged(true);
                        onThumbnailSelected(video.thumbnailUrl);
                        
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Reproduciendo: ${video.title}')),
                          );
                          
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (kDebugMode) {
                          print('Error específico al reproducir: $e');
                        }
                        throw Exception('Error al iniciar reproducción: $e');
                      }
                    }
                    onSongSelected?.call(video); // Notificar que se seleccionó una canción
                  } catch (e) {
                    if (kDebugMode) {
                      print('Error detallado: $e');
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al reproducir audio: $e'),
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  }
                },
              );
            },
          );
        }
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // Mostrar el historial de búsquedas
    if (_searchHistory.isEmpty) {
      return const Center(
        child: Text('No hay búsquedas recientes'),
      );
    }
    
    return ListView.builder(
      itemCount: _searchHistory.length,
      itemBuilder: (context, index) {
        final historyItem = _searchHistory[index];
        return ListTile(
          leading: const Icon(Icons.history),
          title: Text(historyItem),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              _removeFromHistory(historyItem);
              setState(() {});
            },
          ),
          onTap: () {
            // Usar la búsqueda del historial
            query = historyItem;
            showResults(context);
          },
        );
      },
    );
  }

  @override
  void dispose() {
    // No disponemos del _audioPlayer aquí, ya que lo gestiona HomeScreen
    _audioService.dispose();
    super.dispose();
  }

  void _showSongOptions(BuildContext context, YouTubeVideo video) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Reproducir'),
              onTap: () async {
                Navigator.pop(context);
                // Reproducir la canción
                try {
                  // Mostrar indicador de carga
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Cargando audio...')),
                  );
                  
                  final audioUrl = await _audioService.getAudioUrl(video.videoId);
                  await _audioPlayer.setUrl(audioUrl);
                  await _audioPlayer.play();
                  
                  _isPlaying = true;
                  onPlayStateChanged(true);
                  onThumbnailSelected(video.thumbnailUrl);
                  onSongSelected?.call(video);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Reproduciendo: ${video.title}')),
                  );
                } catch (e) {
                  if (kDebugMode) {
                    print('Error al reproducir: $e');
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al reproducir: $e')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Añadir a una lista'),
              onTap: () {
                Navigator.pop(context);
                _showAddToPlaylistDialog(context, video);
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: Text(
                PlaylistService.isFavorite(video.videoId)
                    ? 'Quitar de favoritos'
                    : 'Añadir a favoritos',
              ),
              onTap: () async {
                Navigator.pop(context);
                if (PlaylistService.isFavorite(video.videoId)) {
                  await PlaylistService.removeFavorite(video.videoId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${video.title} quitada de favoritos')),
                  );
                } else {
                  await PlaylistService.addFavorite(video);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${video.title} añadida a favoritos')),
                  );
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
}