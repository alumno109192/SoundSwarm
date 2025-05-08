import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<FileSystemEntity> downloadedFiles = [];
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadDownloadedFiles();
  }

  @override
  void dispose() {
    _audioPlayer
        .dispose(); // Libera el reproductor de audio al cerrar la pantalla
    super.dispose();
  }

  Future<void> _loadDownloadedFiles() async {
    try {
      // Obtén el directorio de descargas
      final directory = await getApplicationSupportDirectory();
      final downloadDirectory = Directory('${directory.path}/SonicSwapMusic');

      // Verifica si el directorio existe
      if (await downloadDirectory.exists()) {
        // Lista los archivos en el directorio
        final files = downloadDirectory.listSync();
        setState(() {
          downloadedFiles = files;
        });
      } else {
        // Si el directorio no existe, crea uno vacío
        setState(() {
          downloadedFiles = [];
        });
      }
    } catch (e) {
      // Manejo de errores
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar descargas: $e')),
        );
      }
    }
  }

  Future<void> _deleteFile(File file) async {
    try {
      await file.delete();
      setState(() {
        downloadedFiles.remove(file);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${file.path.split('/').last} eliminada')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar el archivo: $e')),
      );
    }
  }

  Future<void> _playFile(File file) async {
    try {
      // Crea un MediaItem para el archivo de audio
      final mediaItem = MediaItem(
        id: file.path,
        title: file.path.split('/').last, // Nombre del archivo como título
        artist: 'Desconocido', // Puedes personalizar el artista
        album: 'Descargas', // Puedes personalizar el álbum
        artUri: Uri.parse(
          'https://example.com/default_artwork.png',
        ), // Imagen predeterminada
      );

      // Configura el archivo con el MediaItem
      await _audioPlayer.setAudioSource(
        AudioSource.file(file.path, tag: mediaItem),
      );

      // Reproduce el archivo
      await _audioPlayer.play();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reproduciendo: ${file.path.split('/').last}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al reproducir el archivo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Descargas')),
      body:
          downloadedFiles.isEmpty
              ? const Center(
                child: Text(
                  'No tienes descargas aún.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
              : ListView.builder(
                itemCount: downloadedFiles.length,
                itemBuilder: (context, index) {
                  final file = downloadedFiles[index];
                  final fileName = file.path.split('/').last;

                  return ListTile(
                    leading: const Icon(Icons.music_note),
                    title: Text(fileName),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.play_arrow,
                            color: Colors.green,
                          ),
                          onPressed: () => _playFile(File(file.path)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteFile(File(file.path)),
                        ),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}
