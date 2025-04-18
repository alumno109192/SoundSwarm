import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:soundswarm/model/youtube_video.dart';
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
  final List<YouTubeVideo> _relatedSongs = [];
  final int _currentSongIndex = 0;

  // Añadir esta variable para mantener una copia interna
  YouTubeVideo? _localCurrentSong;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayerListeners();

    // Inicializar con la canción actual
    _localCurrentSong = widget.currentSong;

    if (_localCurrentSong != null) {
      AudioPlayerManager.instance.loadRelatedSongs(_localCurrentSong!.videoId);
    }
  }

  @override
  void didUpdateWidget(AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Actualizar la canción local cuando cambia el widget
    if (AudioPlayerManager.instance.currentSong != null &&
        (oldWidget.currentSong == null ||
            AudioPlayerManager.instance.currentSong!.videoId !=
                oldWidget.currentSong!.videoId)) {
      _localCurrentSong = widget.currentSong;

      if (AudioPlayerManager.instance.currentSong != null) {
        AudioPlayerManager.instance.loadRelatedSongs(
          AudioPlayerManager.instance.currentSong!.videoId,
        );
      }
    }
  }

  void _setupAudioPlayerListeners() {
    // Listener para detectar cuando termina una canción
    widget.audioPlayer.playerStateStream.listen((state) {
      if (kDebugMode) {
        print(
          'Estado del reproductor: ${state.processingState}, playing: ${state.playing}',
        );
      }

      // Esta es la parte clave - detectar cuando una canción termina
      if (state.processingState == ProcessingState.completed) {
        if (kDebugMode) {
          print('🎵 Canción completada, reproduciendo la siguiente...');
        }

        // Usar Future.microtask para asegurar que se ejecute lo antes posible
        Future.microtask(() {
          AudioPlayerManager.instance.playNextSong();
        });
      }

      setState(() {
        _isPlaying = state.playing;
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
    final halfDuration =
        (AudioPlayerManager.instance.currentSong != null &&
                AudioPlayerManager.instance.currentSong!.duration != null)
            ? Duration(
              seconds:
                  (AudioPlayerManager
                              .instance
                              .currentSong!
                              .duration!
                              .inSeconds /
                          2)
                      .round(),
            )
            : Duration.zero;
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
                        ? halfDuration // Nunca mostrar tiempo mayor que la duración total
                        : _position,
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
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8.0,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14.0,
                    ),
                    tickMarkShape: const RoundSliderTickMarkShape(),
                    showValueIndicator: ShowValueIndicator.always,
                  ),
                  child: Slider(
                    min: 0,
                    max:
                        halfDuration.inSeconds.toDouble() > 0
                            ? halfDuration.inSeconds.toDouble()
                            : 1.0,
                    value: min(
                      _position.inSeconds.toDouble(),
                      halfDuration.inSeconds.toDouble(),
                    ),
                    label: _formatDuration(
                      Duration(
                        seconds: min(
                          _position.inSeconds,
                          halfDuration.inSeconds,
                        ),
                      ),
                    ),
                    // Cambia el color basado en el tiempo restante
                    activeColor:
                        halfDuration.inSeconds - _position.inSeconds <= 30
                            ? Colors.orange
                            : Colors.blue[700],
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
                            print(
                              'Slider llegó al final - reproduciendo siguiente canción',
                            );
                          }

                          // Reproducir siguiente canción directamente
                          AudioPlayerManager.instance.playNextSong();
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
                onPressed:
                    AudioPlayerManager.instance.currentSong != null
                        ? () {
                          if (_currentSongIndex > 0) {
                            AudioPlayerManager.instance.playPreviousSong();
                          } else {
                            widget.audioPlayer.seek(Duration.zero);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Volviendo al inicio de la canción',
                                ),
                              ),
                            );
                          }
                        }
                        : null,
              ),

              // Botón de reproducir/pausar
              IconButton(
                icon: Icon(
                  _isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  size: 48,
                ),
                onPressed: () {
                  if (_isPlaying) {
                    AudioPlayerManager.instance.audioPlayer.pause();
                    setState(() {
                      _isPlaying = false;
                    });
                  } else if (_localCurrentSong != null) {
                    AudioPlayerManager.instance.audioPlayer.play();
                    setState(() {
                      _isPlaying = true;
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Por favor, busca y selecciona una canción primero',
                        ),
                      ),
                    );
                  }
                },
              ),

              // Botón siguiente
              IconButton(
                icon: const Icon(Icons.skip_next, size: 32),
                onPressed:
                    AudioPlayerManager.instance.relatedSongs != null
                        ? () {
                          // Usar _localCurrentSong
                          if (AudioPlayerManager.instance.relatedSongs &&
                              AudioPlayerManager.instance.currentSongIndex <
                                  AudioPlayerManager
                                          .instance
                                          .relatedSongs
                                          .length -
                                      1) {
                            AudioPlayerManager.instance.playNextSong();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Buscando más canciones...'),
                              ),
                            );
                            if (AudioPlayerManager.instance.currentSong !=
                                null) {
                              // Usar _localCurrentSong
                              AudioPlayerManager.instance.relatedSongs(
                                AudioPlayerManager
                                    .instance
                                    .currentSong!
                                    .videoId,
                              );
                            }
                          }
                        }
                        : null,
              ),
            ],
          ),

          if ((AudioPlayerManager.instance.hasPreloadError ?? false))
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 16.0,
              ),
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
