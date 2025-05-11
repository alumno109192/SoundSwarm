import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:soundswarm/model/youtube_video.dart';
import 'package:soundswarm/service/playlist_db_service.dart';
import 'package:soundswarm/service/audio_player_manager.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<YouTubeVideo> downloadedSongs = [];
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadDownloadedSongs();
  }

  @override
  void dispose() {
    _audioPlayer
        .dispose(); // Libera el reproductor de audio al cerrar la pantalla
    super.dispose();
  }

  Future<void> _loadDownloadedSongs() async {
    try {
      // Obtén las canciones descargadas desde SQLite
      final songs = await PlaylistDbService().getDownloadedSongs();
      setState(() {
        downloadedSongs = songs.cast<YouTubeVideo>();
      });
    } catch (e) {
      // Manejo de errores
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar las canciones: $e')),
        );
      }
    }
  }

  Future<void> _deleteSong(String id, String filePath) async {
    try {
      // Elimina la canción de la base de datos
      await PlaylistDbService().deleteDownloadSongById(id);

      // Elimina el archivo del sistema de archivos
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Actualiza la lista de canciones descargadas
      setState(() {
        downloadedSongs.removeWhere((song) => song.videoId == id);
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Canción eliminada: ${filePath.split('/').last}'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar la canción: $e')),
      );
    }
  }

  Future<void> _playSong(YouTubeVideo songClick) async {
    try {
      final YouTubeVideo video = await PlaylistDbService().getDownloadSongById(
        songClick.videoId,
      );

      if (!mounted) return;
      // Llama al servicio AudioPlayerManager para reproducir la canción
      await AudioPlayerManager().playSong(context, video, isLocal: true);

      // Verifica si el widget sigue montado antes de usar el contexto
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reproduciendo: ${video.title}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al reproducir la canción: $e')),
      );
    }
  }

  Future<void> _playAllSongs() async {
    try {
      if (downloadedSongs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay canciones descargadas')),
        );
        return;
      }

      final List<YouTubeVideo> videos =
          await PlaylistDbService().getDownloadedSongs();
      if (!mounted) return;
      await AudioPlayerManager().playAllSongs(context, videos, isLocal: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reproduciendo todas las canciones')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al reproducir todas las canciones: $e')),
      );
    }
  }

  Future<void> _playRandomSong() async {
    try {
      if (downloadedSongs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay canciones descargadas')),
        );
        return;
      }

      final List<YouTubeVideo> videos =
          await PlaylistDbService().getDownloadedSongs();
      if (!mounted) return;
      await AudioPlayerManager().playAllRandomSong(
        context,
        videos,
        isLocal: true,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al reproducir canción aleatoria: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Descargas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.queue_music),
            tooltip: 'Reproducir todas las canciones',
            onPressed: _playAllSongs,
          ),
          IconButton(
            icon: const Icon(Icons.shuffle),
            tooltip: 'Reproducir canción aleatoria',
            onPressed: _playRandomSong,
          ),
        ],
      ),
      body:
          downloadedSongs.isEmpty
              ? const Center(
                child: Text(
                  'No tienes descargas aún.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
              : ListView.builder(
                itemCount: downloadedSongs.length,
                itemBuilder: (context, index) {
                  final song = downloadedSongs[index];

                  return ListTile(
                    leading: SizedBox(
                      width:
                          MediaQuery.of(context).size.width *
                          0.2, // 20% del ancho de la pantalla
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          song.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.music_note,
                              size: 50,
                              color: Colors.grey,
                            );
                          },
                        ),
                      ),
                    ),
                    title: Text(song.title),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.play_arrow,
                            color: Colors.green,
                          ),
                          onPressed: () => _playSong(song),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed:
                              () => _deleteSong(song.videoId, song.audioUrl!),
                        ),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}
