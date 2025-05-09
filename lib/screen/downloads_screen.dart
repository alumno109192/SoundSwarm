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
  List<Map<String, dynamic>> downloadedSongs = [];
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
        downloadedSongs = songs;
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
        downloadedSongs.removeWhere((song) => song['id'] == id);
      });

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

  Future<void> _playSong(Map<String, dynamic> song) async {
    try {
      // Crea un objeto YouTubeVideo a partir de la información de la canción
      final video = YouTubeVideo(
        videoId: song['id'],
        title: song['title'],
        duration: song['duration'] ?? 0,
        channelTitle: song['channelTitle'] ?? 'Canal desconocido', // Agregado
        thumbnailUrl:
            song['thumbnailUrl'] ??
            'https://example.com/default_thumbnail.png', // Agregado
      );

      // Llama al servicio AudioPlayerManager para reproducir la canción
      await AudioPlayerManager().playSong(context, video);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Descargas')),
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
                    leading:
                        song['thumbnailUrl'] != null
                            ? Image.network(song['thumbnailUrl'])
                            : const Icon(Icons.music_note),
                    title: Text(song['title']),
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
                              () => _deleteSong(song['id'], song['filePath']),
                        ),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}
