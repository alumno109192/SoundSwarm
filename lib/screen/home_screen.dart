import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soundswarm/model/youtube_video.dart';
import 'package:soundswarm/screen/setting_screen.dart';
import 'package:soundswarm/service/youtube_api_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:soundswarm/service/audio_service.dart';
import 'dart:math';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isPlaying = false;
  String? _currentThumbnailUrl;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Nuevas variables para el slider
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  
  @override
  void initState() {
    super.initState();
    
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
                  audioPlayer: _audioPlayer, // Pasar el reproductor compartido
                ),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'SoundSwarm',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.library_music),
              title: const Text('My Library'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_play),
              title: const Text('Playlists'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Downloads'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
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
                image: _currentThumbnailUrl != null
                    ? DecorationImage(
                        image: NetworkImage(_currentThumbnailUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _currentThumbnailUrl == null
                  ? const Icon(Icons.music_note, size: 50, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 35),
                  onPressed: () {},
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
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Tiempo actual con estilo mejorado
                Container(
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
                      max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                      value: min(_position.inSeconds.toDouble(), _duration.inSeconds.toDouble()),
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
                          print('Error al buscar posición: $e');
                        }
                      },
                    ),
                  ),
                ),
                // Duración total con estilo mejorado
                Container(
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
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // Liberar recursos al cerrar
    super.dispose();
  }
}

class SongSearchDelegate extends SearchDelegate<String> {
  final YouTubeApiService _apiService = YouTubeApiService();
  final AudioService _audioService = AudioService();
  final AudioPlayer _audioPlayer; // Ya no inicializamos aquí, lo recibimos
  final Function(String) onThumbnailSelected;
  final Function(bool) onPlayStateChanged;
  bool _isPlaying = false;

  SongSearchDelegate({
    required this.onThumbnailSelected,
    required this.onPlayStateChanged,
    required AudioPlayer audioPlayer, // Recibir el reproductor compartido
  }): _audioPlayer = audioPlayer;

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
                title: Text(video.title),
                subtitle: Text(video.channelTitle),
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
                      print('URL de audio: $audioUrl');
                      
                      // Verificar que la URL sea válida
                      if (audioUrl.isEmpty) {
                        throw Exception('No se pudo obtener la URL del audio');
                      }
                      
                      // Configurar el reproductor con manejadores de errores
                      try {
                        await _audioPlayer.setUrl(audioUrl);
                      } catch (e) {
                        print('Error al configurar URL: $e');
                        throw Exception('Error al configurar reproductor: $e');
                      }
                      
                      // Esperar a que la duración esté disponible
                      try {
                        final duration = await _audioPlayer.durationStream.first;
                        print('Duración de la canción: ${duration?.inSeconds ?? 0} segundos');
                      } catch (e) {
                        print('Error al obtener duración: $e');
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
                        print('Error específico al reproducir: $e');
                        throw Exception('Error al iniciar reproducción: $e');
                      }
                    }
                  } catch (e) {
                    print('Error detallado: $e');
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
    return Center(
      child: Text('Escribe para buscar canciones en YouTube'),
    );
  }

  @override
  void dispose() {
    // No disponemos del _audioPlayer aquí, ya que lo gestiona HomeScreen
    _audioService.dispose();
    super.dispose();
  }
}