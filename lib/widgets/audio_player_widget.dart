import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:soundswarm/model/youtube_video.dart';
import 'package:soundswarm/service/audio_service.dart';
import 'dart:math';

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
    widget.audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (_relatedSongs.isNotEmpty && _currentSongIndex < _relatedSongs.length - 1) {
          _playNextSong();
        }
      }
      
      setState(() {});
    });
    
    widget.audioPlayer.positionStream.listen((position) {
      setState(() {
        _position = position;
      });
    });
    
    widget.audioPlayer.durationStream.listen((duration) {
      setState(() {
        _duration = duration != null 
            ? Duration(seconds: (duration.inSeconds / 2).round()) 
            : Duration.zero;
      });
    });
    
    widget.audioPlayer.playingStream.listen((isPlaying) {
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
  
  Future<void> _loadRelatedSongs(String videoId) async {
    try {
      if (videoId.isEmpty) {
        if (kDebugMode) {
          print('ID de video vacío, no se pueden cargar canciones relacionadas');
        }
        return;
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('Error al cargar canciones relacionadas: $e');
      }
    }
  }
  
  Future<void> _playNextSong() async {
    if (_relatedSongs.isEmpty || _currentSongIndex >= _relatedSongs.length - 1) {
      if (widget.currentSong != null) {
        await _loadRelatedSongs(widget.currentSong!.videoId);
      }
      
      if (_relatedSongs.isEmpty) {
        return;
      }
    }
    
    _currentSongIndex++;
    if (_currentSongIndex < _relatedSongs.length) {
      await _playSong(_relatedSongs[_currentSongIndex]);
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
                    max: _duration.inSeconds.toDouble(),
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
                        await widget.audioPlayer.seek(position);
                        
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
                  _formatDuration(_duration),
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
        ],
      ),
    );
  }
}