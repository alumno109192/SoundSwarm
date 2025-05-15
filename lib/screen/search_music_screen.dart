import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:soundswarm/model/youtube_video.dart';
import 'package:soundswarm/service/audio_player_manager.dart';
import 'package:soundswarm/service/playlist_db_service.dart';
import 'dart:io';
import 'package:path/path.dart' as p; // Importa el paquete path
import 'dart:math'; // Importa el paquete math para generar números aleatorios

class SearchMusicScreen extends StatefulWidget {
  const SearchMusicScreen({super.key});

  @override
  State<SearchMusicScreen> createState() => _SearchMusicScreenState();
}

class _SearchMusicScreenState extends State<SearchMusicScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<String> _allSongs = []; // Lista de todas las canciones
  List<String> _searchResults = []; // Resultados de búsqueda
  bool _isSearching = false;

  late TabController _tabController = TabController(length: 2, vsync: this);
  final List<String> _savedDirectories = []; // Lista de directorios guardados

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedDirectoriesAndSongs(); // Carga los directorios y canciones al iniciar
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedDirectoriesAndSongs() async {
    try {
      final List<String> directories =
          await PlaylistDbService().getSavedDirectories();

      // Carga todas las canciones de los directorios guardados
      final allSongs = <String>[];
      if (directories.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay directorios guardados')),
          );
        }
        return;
      }
      for (var directory in directories) {
        final musicFiles = _getMusicFilesFromDirectory(directory);
        if (musicFiles.isNotEmpty) {
          allSongs.addAll(musicFiles);
        }
      }

      setState(() {
        _savedDirectories.clear();
        _savedDirectories.addAll(
          directories,
        ); // Actualiza los directorios guardados
        _allSongs = allSongs;
        _searchResults = List.from(
          allSongs,
        ); // Actualiza los resultados de búsqueda
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar los directorios: $e')),
        );
      }
    }
  }

  List<String> _getMusicFilesFromDirectory(String directoryPath) {
    try {
      final directory = Directory(directoryPath);

      // Verifica si el directorio existe
      if (!directory.existsSync()) {
        throw Exception('El directorio no existe: $directoryPath');
      }

      // Lista los archivos en el directorio y filtra solo los archivos de música
      final musicFiles =
          directory
              .listSync()
              .where(
                (file) =>
                    file is File &&
                    (file.path.endsWith('.mp3') ||
                        file.path.endsWith('.wav') ||
                        file.path.endsWith('.flac')),
              )
              .map((file) => file.path)
              .toList();

      return musicFiles;
    } catch (e) {
      // Manejo de errores
      debugPrint('Error al obtener archivos de música: $e');
      return [];
    }
  }

  void _performSearch(String query) {
    setState(() {
      _isSearching = true;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        if (query.isEmpty) {
          // Si no hay texto ingresado, muestra todas las canciones
          _searchResults = _allSongs;
        } else {
          // Filtra las canciones según el texto ingresado
          _searchResults =
              _allSongs
                  .where(
                    (song) => song.toLowerCase().contains(query.toLowerCase()),
                  )
                  .toList();
        }
        _isSearching = false;
      });
    });
  }

  Future<void> _pickDirectory() async {
    String? directoryPath = await FilePicker.platform.getDirectoryPath();
    if (directoryPath != null) {
      try {
        // Guarda el directorio en SQLite
        await PlaylistDbService().saveDirectory(directoryPath);

        // Actualiza la lista de directorios guardados
        await _loadSavedDirectoriesAndSongs();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Directorio guardado: $directoryPath')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar el directorio: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se seleccionó ningún directorio')),
      );
    }
  }

  Future<void> _playSong(String songPath) async {
    try {
      final video = YouTubeVideo.fromFile(
        songPath,
      ); // Convierte la ruta en un objeto YouTubeVideo
      await AudioPlayerManager.instance.playSong(context, video, isLocal: true);
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
      final videos =
          _searchResults
              .map((songPath) => YouTubeVideo.fromFile(songPath))
              .toList();
      await AudioPlayerManager.instance.playAllSongs(
        context,
        videos,
        isLocal: true,
      );
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
      if (_searchResults.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay canciones para reproducir')),
        );
        return;
      }

      final randomIndex = Random().nextInt(_searchResults.length);
      final randomSongPath = _searchResults[randomIndex];
      final video = YouTubeVideo.fromFile(randomSongPath);

      await AudioPlayerManager.instance.playSong(context, video, isLocal: true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reproduciendo: ${video.title}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al reproducir canción aleatoria: $e')),
      );
    }
  }

  Future<void> _deleteDirectory(String directoryPath) async {
    try {
      PlaylistDbService().deleteDirectory(directoryPath);

      setState(() {
        _savedDirectories.remove(
          directoryPath,
        ); // Elimina el directorio de la lista local
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Directorio eliminado: ${p.basename(directoryPath)}'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar el directorio: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Música'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.search), text: 'Por Texto'),
            Tab(icon: Icon(Icons.folder), text: 'Por Directorios'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildTextSearchTab(), _buildDirectorySearchTab()],
      ),
    );
  }

  Widget _buildTextSearchTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Buscar canciones o artistas',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (query) {
              _performSearch(query);
            },
          ),
          const SizedBox(height: 20),
          if (_searchResults.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.queue_music),
                  onPressed: () => _playAllSongs(),
                ),
                IconButton(
                  icon: const Icon(Icons.shuffle),
                  onPressed: () => _playRandomSong(),
                ),
              ],
            ),
          const SizedBox(height: 10),
          Expanded(
            child:
                _searchResults.isEmpty
                    ? const Center(
                      child: Text(
                        'No se encontraron resultados',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                    : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final songPath = _searchResults[index];
                        final songName =
                            songPath
                                .split('/')
                                .last; // Extrae el nombre del archivo
                        return ListTile(
                          leading: const Icon(Icons.music_note),
                          title: Text(songName),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.play_arrow,
                              color: Colors.green,
                            ),
                            onPressed: () => _playSong(songPath),
                          ),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Seleccionaste: $songName'),
                              ),
                            );
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectorySearchTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: _pickDirectory,
            icon: const Icon(Icons.folder_open),
            label: const Text('Seleccionar Directorio'),
          ),
          const SizedBox(height: 20),
          if (_savedDirectories.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _savedDirectories.length,
                itemBuilder: (context, index) {
                  final directory = _savedDirectories[index];
                  return ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(
                      p.basename(
                        directory,
                      ), // Muestra solo el nombre del directorio
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Eliminar directorio',
                      onPressed: () => _deleteDirectory(directory),
                    ),
                  );
                },
              ),
            )
          else
            const Center(
              child: Text(
                'No hay directorios guardados.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}
