import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:soundswarm/model/youtube_video.dart';
import 'package:soundswarm/service/audio_service.dart';
import 'dart:math';
import 'package:soundswarm/service/audio_player_manager.dart'; // Ensure this import exists

class AudioPlayerWidget extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final YouTubeVideo? currentSong;
  final String? currentThumbnailUrl;
  final Function(YouTubeVideo)? onSongChanged;
  final Function(String)? onThumbnailChanged;
  
  const AudioPlayerWidget({
    super.key,
    required this.audioPlayer,
    this.currentSong,
    this.currentThumbnailUrl,
    this.onSongChanged,
    this.onThumbnailChanged,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  List<YouTubeVideo> _relatedSongs = [];
  int _currentSongIndex = 0;
  
  // Añadir esta variable para mantener una copia interna
  YouTubeVideo? _localCurrentSong;
  
  @override
  void initState() {
    super.initState();
    _setupAudioPlayerListeners();
    
    // Inicializar con la canción actual
    _localCurrentSong = widget.currentSong;
    
    if (_localCurrentSong != null) {
      _loadRelatedSongs(_localCurrentSong!.videoId);
    }
  }
  
  @override
  void didUpdateWidget(AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Actualizar la canción local cuando cambia el widget
    if (widget.currentSong != null && 
        (oldWidget.currentSong == null || 
         widget.currentSong!.videoId != oldWidget.currentSong!.videoId)) {
      _localCurrentSong = widget.currentSong;
      
      if (_localCurrentSong != null) {
        _loadRelatedSongs(_localCurrentSong!.videoId);
      }
    }
  }
  
  void _setupAudioPlayerListeners() {
  // Listener para detectar cuando termina una canción
  widget.audioPlayer.playerStateStream.listen((state) {
    if (kDebugMode) {
      print('Estado del reproductor: ${state.processingState}, playing: ${state.playing}');
    }
    
    // Esta es la parte clave - detectar cuando una canción termina
    if (state.processingState == ProcessingState.completed) {
      if (kDebugMode) {
        print('🎵 Canción completada, reproduciendo la siguiente...');
      }
      
      // Usar Future.microtask para asegurar que se ejecute lo antes posible
      Future.microtask(() {
        _playNextSong();
      });
    }
    
    setState(() {
      _isPlaying = state.playing;
    });
  });
  
  // Listeners para posición y duración (simplificados)
  widget.audioPlayer.positionStream.listen((position) {
    final halfDuration = Duration(seconds: (_duration.inSeconds / 2).round());
    setState(() {
      _position = position;
    });

    // Si llega a la mitad, pasar a la siguiente canción
    if (_duration.inSeconds > 0 &&
        position.inSeconds >= halfDuration.inSeconds) {
      if (kDebugMode) {
        print('⏩ Llegó a la mitad, pasando a la siguiente canción');
      }
      _playNextSong();
    }
  });
  
  widget.audioPlayer.durationStream.listen((duration) {
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
  
  // Reemplaza el método _loadRelatedSongs() con esta versión básica

Future<void> _loadRelatedSongs(String videoId) async {
  try {
    if (videoId.isEmpty) {
      if (kDebugMode) {
        print('ID de video vacío, no se pueden cargar canciones relacionadas');
      }
      return;
    }

    // Para simplificar, al menos asegurarse de que tenemos la canción actual en la lista
    if (_localCurrentSong != null && _relatedSongs.isEmpty) {
      _relatedSongs = [_localCurrentSong!];
      _currentSongIndex = 0;
      
      if (kDebugMode) {
        print('Lista de reproducción inicializada con la canción actual');
      }
    }
    
    // En un caso real, aquí cargarías más canciones relacionadas
    // Por ahora, solo nos aseguramos de que tengamos al menos la actual
    
  } catch (e) {
    if (kDebugMode) {
      print('Error al cargar canciones relacionadas: $e');
    }
  }
}
  
  // Reemplaza el método _playNextSong() con esta versión simplificada

Future<void> _playNextSong() async {
  if (kDebugMode) {
    print('Intentando reproducir siguiente canción...');
  }
  
  try {
    // Incrementar índice
    _currentSongIndex++;
    
    // Si llegamos al final, volver al principio
    if (_currentSongIndex >= _relatedSongs.length) {
      _currentSongIndex = 0;
      
      if (kDebugMode) {
        print('Fin de la lista, volviendo al principio');
      }
      
      // Si no hay canciones en la lista, no hacer nada
      if (_relatedSongs.isEmpty) {
        if (kDebugMode) {
          print('La lista está vacía, no hay más canciones para reproducir');
        }
        return;
      }
    }
    
    if (kDebugMode) {
      print('Reproduciendo canción #${_currentSongIndex + 1} de ${_relatedSongs.length}');
    }
    
    // Obtener la siguiente canción
    final nextVideo = _relatedSongs[_currentSongIndex];
    
    // Reproducir la siguiente canción
    await _playSong(nextVideo);
    
  } catch (e) {
    if (kDebugMode) {
      print('Error al reproducir siguiente canción: $e');
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al reproducir siguiente canción: $e')),
      );
    }
  }
}
  
  Future<void> _playPreviousSong() async {
    if (_relatedSongs.isEmpty || _currentSongIndex <= 0) {
      if (_currentSongIndex == 0 && _relatedSongs.isNotEmpty) {
        await widget.audioPlayer.seek(Duration.zero);
        return;
      }
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay canciones anteriores disponibles')),
      );
      return;
    }
    
    _currentSongIndex--;
    await _playSong(_relatedSongs[_currentSongIndex]);
  }
  
  Future<void> _playSong(YouTubeVideo video) async {
    try {
      final audioService = AudioService();
      
      // Notificar cambios
      if (widget.onSongChanged != null) {
        widget.onSongChanged!(video);
      }
      
      if (widget.onThumbnailChanged != null) {
        widget.onThumbnailChanged!(video.thumbnailUrl);
      }
      
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
        
        await widget.audioPlayer.setAudioSource(
          AudioSource.uri(
            Uri.parse(audioUrl),
            tag: mediaItem,
          ),
        );
      } catch (e) {
        if (kDebugMode) {
          print('Error con background playback: $e');
        }
        await widget.audioPlayer.setUrl(audioUrl);
      }
      
      await widget.audioPlayer.play();
      
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

  @override
  Widget build(BuildContext context) {
    final halfDuration = Duration(seconds: (_duration.inSeconds / 2).round());
    return Container(
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(77),
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
                  _formatDuration(
                    _position.inMilliseconds > halfDuration.inMilliseconds
                        ? halfDuration   // Nunca mostrar tiempo mayor que la duración total
                        : _position
                  ),
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
                    max: halfDuration.inSeconds.toDouble() > 0 ? halfDuration.inSeconds.toDouble() : 1.0,
                    value: min(_position.inSeconds.toDouble(), halfDuration.inSeconds.toDouble()),
                    label: _formatDuration(Duration(seconds: min(_position.inSeconds, halfDuration.inSeconds))),
                    // Cambia el color basado en el tiempo restante
                    activeColor: halfDuration.inSeconds - _position.inSeconds <= 30 ? Colors.orange : Colors.blue[700],
                    onChanged: (value) {
                      // Simplemente actualiza la posición sin pausar cuando está cerca del final
                      final newPosition = Duration(seconds: value.toInt());
                      setState(() {
                        _position = newPosition;
                      });
                    },
                    onChangeEnd: (value) async {
                      try {
                        // Si el usuario arrastra hasta el final (o muy cerca), reproducir siguiente canción
                        if (value >= halfDuration.inSeconds.toDouble() - 1) {
                          if (kDebugMode) {
                            print('Slider llegó al final - reproduciendo siguiente canción');
                          }
                          
                          // Reproducir siguiente canción directamente
                          _playNextSong();
                          return;
                        }
                        
                        // Comportamiento normal para cualquier otra posición
                        final position = Duration(seconds: value.toInt());
                        await widget.audioPlayer.seek(position);
                        
                        // Si no está reproduciendo y debería estarlo, iniciar reproducción
                        if (!_isPlaying && widget.currentThumbnailUrl != null) {
                          await widget.audioPlayer.play();
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
                  _formatDuration(halfDuration),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          
          // Controles de reproducción
          Row(
            key: const ValueKey('playback_controls'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Botón anterior
              IconButton(
                icon: const Icon(Icons.skip_previous, size: 32),
                onPressed: widget.currentSong != null ? () {
                  if (_currentSongIndex > 0) {
                    _playPreviousSong();
                  } else {
                    widget.audioPlayer.seek(Duration.zero);
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
                    widget.audioPlayer.pause();
                    setState(() {
                      _isPlaying = false;
                    });
                  } else if (_localCurrentSong != null) {  // Usar _localCurrentSong en lugar de widget.currentSong
                    widget.audioPlayer.play();
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
                onPressed: _localCurrentSong != null ? () {  // Usar _localCurrentSong
                  if (_relatedSongs.isNotEmpty && _currentSongIndex < _relatedSongs.length - 1) {
                    _playNextSong();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Buscando más canciones...')),
                    );
                    if (_localCurrentSong != null) {  // Usar _localCurrentSong
                      _loadRelatedSongs(_localCurrentSong!.videoId);
                    }
                  }
                } : null,
              ),
            ],
          ),
          
         if (AudioPlayerManager.instance.hasPreloadError)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              margin: const EdgeInsets.only(bottom: 8.0),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 8.0),
                  Flexible(
                    child: Text(
                      'No se ha podido cargar la siguiente canción',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}