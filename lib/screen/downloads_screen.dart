import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<FileSystemEntity> downloadedFiles = [];

  @override
  void initState() {
    super.initState();
    _loadDownloadedFiles();
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
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteFile(File(file.path)),
                    ),
                  );
                },
              ),
    );
  }
}
