import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:soundswarm/model/youtube_video.dart';
import 'package:soundswarm/service/audio_player_manager.dart';
import 'package:soundswarm/main.dart'; // Importa la pantalla principal

class AudioPlayerWidget extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final YouTubeVideo? currentSong;

  const AudioPlayerWidget({
    super.key,
    required this.audioPlayer,
    this.currentSong,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _songDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayerListeners();
  }

  void _setupAudioPlayerListeners() {
    // Listener para el estado de reproducción
    widget.audioPlayer.playingStream.listen((isPlaying) {
      setState(() {
        _isPlaying = isPlaying;
      });
    });

    // Listener para la posición actual
    widget.audioPlayer.positionStream.listen((position) {
      setState(() {
        _currentPosition = position;
      });
    });

    // Listener para la duración de la canción
    widget.audioPlayer.durationStream.listen((duration) {
      setState(() {
        _songDuration = duration ?? Duration.zero;
      });
    });
  }

  // Formatear duración en MM:SS
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
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
          Row(
            children: [
              // Imagen de la canción actual con GestureDetector
              GestureDetector(
                onTap: () {
                  // Navegar a la pantalla principal
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const MyApp()),
                    (route) => false, // Eliminar todas las rutas anteriores
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    key: Key(AudioPlayerManager().currentSong!.thumbnailUrl),
                    AudioPlayerManager().currentSong!.thumbnailUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.music_note,
                        size: 50,
                        color: Colors.white,
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Controles de reproducción
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Botón anterior
                    IconButton(
                      icon: const Icon(Icons.skip_previous, size: 32),
                      color: Colors.white,
                      onPressed: () {
                        widget.audioPlayer.seek(Duration.zero);
                      },
                    ),
                    // Botón de reproducir/pausar
                    IconButton(
                      icon: Icon(
                        _isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        size: 48,
                      ),
                      color: Colors.white,
                      onPressed: () {
                        if (_isPlaying) {
                          widget.audioPlayer.pause();
                        } else {
                          widget.audioPlayer.play();
                        }
                      },
                    ),
                    // Botón siguiente
                    IconButton(
                      icon: const Icon(Icons.skip_next, size: 32),
                      color: Colors.white,
                      onPressed: () {
                        AudioPlayerManager.instance.playNextSong();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Slider de progreso
          Slider(
            min: 0,
            max: _songDuration.inSeconds.toDouble(),
            value: _currentPosition.inSeconds.toDouble().clamp(
              0,
              _songDuration.inSeconds.toDouble(),
            ),
            onChanged: (value) {
              final newPosition = Duration(seconds: value.toInt());
              widget.audioPlayer.seek(newPosition);
            },
            activeColor: Colors.blue,
            inactiveColor: Colors.grey,
          ),
        ],
      ),
    );
  }
}
