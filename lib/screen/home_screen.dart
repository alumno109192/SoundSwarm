import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soundswarm/model/youtube_video.dart';
import 'package:soundswarm/screen/drawer.dart';
import 'package:soundswarm/service/notification_service.dart';
import 'package:soundswarm/service/youtube_api_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:soundswarm/service/audio_service.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:soundswarm/service/playlist_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio_background/just_audio_background.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _isPlaying = false;
  String? _currentThumbnailUrl;
  late AudioPlayer _audioPlayer;
  YouTubeVideo? _currentSong;
  List<YouTubeVideo> _relatedSongs = [];
  int _currentSongIndex = 0;
  final YouTubeApiService _apiService = YouTubeApiService();
  
  // Variables para el slider
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Inicialización del reproductor
    _audioPlayer = AudioPlayer();
    
    // IMPORTANTE: configurar los listeners inmediatamente
    _setupAudioPlayerListeners();
    
    // Resto de inicialización
    _loadSearchHistory();
    _initializeAudioServices();
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    // Load search history or initialize an empty list
    final searchHistory = prefs.getStringList('search_history') ?? [];
    if (kDebugMode) {
      print('Search history loaded: $searchHistory');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.onScreenStateChanged = null;
    _audioPlayer.dispose(); // Liberar recursos al cerrar
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // La app está visible de nuevo, no necesitamos hacer nada especial
    } else if (state == AppLifecycleState.paused) {
      // La app está en segundo plano, asegurarse de que la reproducción continúe
      // No hacer seek u operaciones disruptivas aquí
    }
  }

  Future<void> _initializeAudioServices() async {
    try {
      final session = await AudioSession.instance;
      // Usar una configuración más simple para evitar el error OSStatus -50
      await session.configure(const AudioSessionConfiguration.music());
      
      if (kDebugMode) {
        print('Servicios de audio inicializados correctamente');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al inicializar servicios de audio: $e');
      }
    }
  }

  void _setupAudioPlayerListeners() {
    // Asegurarse de que no hay listeners duplicados
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        // Manejar fin de reproducción
        if (_relatedSongs.isNotEmpty && _currentSongIndex < _relatedSongs.length - 1) {
          _playNextSong();
        }
      }
      
      // Actualizar UI siempre que cambie el estado
      setState(() {});
    });
    
    // IMPORTANTE: Asegurar que positionStream y durationStream actualizan la UI
    _audioPlayer.positionStream.listen((position) {
      setState(() {
        _position = position;
      });
    });
    
    _audioPlayer.durationStream.listen((duration) {
      setState(() {
        // Aquí está el problema: la duración reportada es el doble de la real
        // En lugar de dividir en varios lugares, corregirla aquí
        _duration = duration != null 
            ? Duration(seconds: (duration.inSeconds / 2).round()) 
            : Duration.zero;
      });
      // Agregar este código para depurar tiempos (puedes quitarlo después)
      if (kDebugMode && _duration.inSeconds > 0) {
        print('Duración raw: ${duration?.inSeconds}, Corregida: ${_duration.inSeconds}');
        print('Posición: ${_position.inSeconds}/${_duration.inSeconds}');
      }
    });
    
    // Listener crucial para isPlaying
    _audioPlayer.playingStream.listen((isPlaying) {
      setState(() {
        _isPlaying = isPlaying;
      });
    });
  }

  // Función auxiliar para formatear duración en MM:SS
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SonicSwap'),
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
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // Área principal expandible con portada e información
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Portada del álbum
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Carátula
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
                                        if (kDebugMode) {
                                          print('Error al cargar imagen: $exception');
                                        }
                                      },
                                    )
                                  : null,
                            ),
                            key: ValueKey(_currentThumbnailUrl),
                            child: _currentThumbnailUrl == null || _currentThumbnailUrl!.isEmpty
                                ? const Icon(Icons.music_note, size: 50, color: Colors.white)
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      
                      // Información de la canción con botón de opciones
                      if (_currentSong != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Padding(
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
                            ),
                            
                            // Botón de opciones junto al título
                            IconButton(
                              icon: const Icon(Icons.more_vert),
                              onPressed: () {
                                _showCurrentSongOptions();
                              },
                            ),
                          ],
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
                    ],
                  ),
                ),
              ),
            ),
            
            // Panel fijo de controles en la parte inferior
            Container(
              padding: const EdgeInsets.only(bottom: 20, top: 10),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Slider de tiempo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Tiempo actual
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
                      // Slider
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: Colors.blue[700],
                            inactiveTrackColor: Colors.grey[300],
                            thumbColor: Colors.blue,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                            tickMarkShape: const RoundSliderTickMarkShape(),
                            showValueIndicator: ShowValueIndicator.always,
                          ),
                          child: Slider(
                            min: 0,
                            // No dividir aquí, ya lo hiciste en el listener
                            max: _duration.inSeconds.toDouble(),
                            // No dividir aquí tampoco
                            value: min(_position.inSeconds.toDouble(), _duration.inSeconds.toDouble()),
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
                      // Duración total
                      SizedBox(
                        width: 45,
                        child: Text(
                          // No dividir aquí, ya lo corregimos en el listener
                          _formatDuration(_duration),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // ÚNICO conjunto de controles de reproducción
                  Row(
                    key: const ValueKey('playback_controls'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Botón anterior
                      IconButton(
                        icon: const Icon(Icons.skip_previous, size: 32),
                        onPressed: _currentSong != null ? () {
                          if (_currentSongIndex > 0) {
                            _playPreviousSong();
                          } else {
                            _audioPlayer.seek(Duration.zero);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Volviendo al inicio de la canción')),
                            );
                          }
                        } : null,
                      ),
                      
                      // Botón de reproducir/pausar
                      IconButton(
                        icon: Icon(
                          _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          size: 48,
                        ),
                        onPressed: () {
                          if (_isPlaying) {
                            _audioPlayer.pause();
                            setState(() {
                              _isPlaying = false;
                            });
                          } else if (_currentSong != null) {
                            _audioPlayer.play();
                            setState(() {
                              _isPlaying = true;
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Por favor, busca y selecciona una canción primero')),
                            );
                          }
                        },
                      ),
                      
                      // Botón siguiente
                      IconButton(
                        icon: const Icon(Icons.skip_next, size: 32),
                        onPressed: _currentSong != null ? () {
                          if (_relatedSongs.isNotEmpty && _currentSongIndex < _relatedSongs.length - 1) {
                            _playNextSong();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Buscando más canciones...')),
                            );
                            _loadRelatedSongs(_currentSong!.videoId);
                          }
                        } : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

  // Modificar el método _playSong para usar una estrategia adaptativa

Future<void> _playSong(YouTubeVideo video) async {
  try {
    final audioService = AudioService();
    
    // IMPORTANTE: Actualizar el estado ANTES de iniciar la carga de audio
    setState(() {
      _currentSong = video;
      _currentThumbnailUrl = video.thumbnailUrl;
    });
    
    // Obtener URL del audio
    final audioUrl = await audioService.getAudioUrl(video.videoId);
    
    // Reproducir
    try {
      final mediaItem = MediaItem(
        id: video.videoId,
        title: video.title,
        artist: video.channelTitle,
        artUri: Uri.parse(video.thumbnailUrl),
        displayTitle: video.title,
        displaySubtitle: video.channelTitle,
      );
      
      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(audioUrl),
          tag: mediaItem,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error con background playback: $e');
      }
      await _audioPlayer.setUrl(audioUrl);
    }
    
    await _audioPlayer.play();
    
    // Limpiar recursos
    audioService.dispose();
  } catch (e) {
    if (kDebugMode) {
      print('Error al reproducir: $e');
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

  // Código existente para cuando hay una canción seleccionada
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
              // Código existente...
            },
          ),
        ],
      );
    },
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

// Clase correcta del buscador
class SongSearchDelegate extends SearchDelegate<String> {
  final YouTubeApiService _apiService = YouTubeApiService();
  final AudioService _audioService = AudioService();
  final AudioPlayer _audioPlayer;
  final Function(String) onThumbnailSelected;
  final Function(bool) onPlayStateChanged;
  final Function(YouTubeVideo)? onSongSelected;
  
  // Lista para almacenar el historial de búsquedas
  List<String> _searchHistory = [];
  
  SongSearchDelegate({
    required this.onThumbnailSelected,
    required this.onPlayStateChanged,
    required AudioPlayer audioPlayer,
    this.onSongSelected,
  }) : _audioPlayer = audioPlayer {
    // Cargar el historial cuando se crea el delegado
    _loadSearchHistory();
  }
  
  // Método para cargar el historial desde SharedPreferences
  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _searchHistory = prefs.getStringList('search_history') ?? [];
    // Forzar reconstrucción
    query = query;
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
    
    // Forzar reconstrucción
    this.query = this.query;
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
                    // Actualizar la UI ANTES de iniciar la carga del audio
                    onThumbnailSelected(video.thumbnailUrl);
                    onSongSelected?.call(video);
                    
                    // Mostrar indicador de carga
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cargando audio...')),
                      );
                    }
                    
                    // Obtener URL del audio
                    final audioUrl = await _audioService.getAudioUrl(video.videoId);
                    
                    // Intentar usar reproducción con background
                    try {
                      final mediaItem = MediaItem(
                        id: video.videoId,
                        title: video.title,
                        artist: video.channelTitle,
                        artUri: Uri.parse(video.thumbnailUrl),
                        displayTitle: video.title,
                        displaySubtitle: video.channelTitle,
                      );
                      
                      await _audioPlayer.setAudioSource(
                        AudioSource.uri(
                          Uri.parse(audioUrl),
                          tag: mediaItem,
                        ),
                      );
                    } catch (e) {
                      // Si falla, usar reproducción simple
                      if (kDebugMode) {
                        print('Fallback a reproducción simple: $e');
                      }
                      await _audioPlayer.setUrl(audioUrl);
                    }
                    
                    // Iniciar reproducción
                    await _audioPlayer.play();
                    
                    // Actualizar estado
                    onPlayStateChanged(true);
                    
                    if (context.mounted) {
                      // Cerrar la búsqueda ANTES del SnackBar
                      Navigator.pop(context);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Reproduciendo: ${video.title}')),
                      );
                    }
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
  void close(BuildContext context, String result) {
    // No disponemos del _audioPlayer aquí, ya que lo gestiona HomeScreen
    _audioService.dispose();
    super.close(context, result);
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
                try {
                  // Mostrar indicador de carga
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cargando audio...')),
                  );
                  
                  final audioUrl = await _audioService.getAudioUrl(video.videoId);
                  
                  // Crear MediaItem para reproducción en segundo plano
                  final mediaItem = MediaItem(
                    id: video.videoId,
                    title: video.title,
                    artist: video.channelTitle,
                    artUri: Uri.parse(video.thumbnailUrl),
                    displayTitle: video.title,
                    displaySubtitle: video.channelTitle,
                  );
                  
                  // Usar setAudioSource con MediaItem
                  await _audioPlayer.setAudioSource(
                    AudioSource.uri(
                      Uri.parse(audioUrl),
                      tag: mediaItem,
                    ),
                  );
                  
                  await _audioPlayer.play();
                  
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