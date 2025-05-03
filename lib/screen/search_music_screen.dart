import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class SearchMusicScreen extends StatefulWidget {
  const SearchMusicScreen({super.key});

  @override
  State<SearchMusicScreen> createState() => _SearchMusicScreenState();
}

class _SearchMusicScreenState extends State<SearchMusicScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<String> _searchResults = []; // Lista de resultados de búsqueda simulados
  bool _isSearching = false;

  late TabController _tabController = TabController(length: 2, vsync: this);
  String? _selectedDirectory;
  List<String> _directoryFiles = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        children: [
          // Búsqueda por texto
          _buildTextSearchTab(),
          // Búsqueda por directorios
          _buildDirectorySearchTab(),
        ],
      ),
    );
  }

  // Pestaña de búsqueda por texto
  Widget _buildTextSearchTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Campo de búsqueda
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Buscar canciones o artistas',
              prefixIcon: const Icon(Icons.search),
              suffixIcon:
                  _isSearching
                      ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                      : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (query) {
              // Simular búsqueda automática
              _performSearch(query);
            },
          ),
          const SizedBox(height: 20),
          // Resultados de búsqueda
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
                        return ListTile(
                          leading: const Icon(Icons.music_note),
                          title: Text(_searchResults[index]),
                          onTap: () {
                            // Acción al seleccionar una canción
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Seleccionaste: ${_searchResults[index]}',
                                ),
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

  // Pestaña de búsqueda por directorios
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
          if (_selectedDirectory != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Directorio seleccionado:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedDirectory!,
                    style: const TextStyle(color: Colors.blue),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child:
                        _directoryFiles.isEmpty
                            ? const Center(
                              child: Text(
                                'No se encontraron archivos de música en este directorio.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                            : ListView.builder(
                              itemCount: _directoryFiles.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  leading: const Icon(Icons.music_note),
                                  title: Text(_directoryFiles[index]),
                                  onTap: () {
                                    // Acción al seleccionar un archivo
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Seleccionaste: ${_directoryFiles[index]}',
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Método para seleccionar un directorio
  Future<void> _pickDirectory() async {
    String? directoryPath = await FilePicker.platform.getDirectoryPath();
    if (directoryPath != null) {
      setState(() {
        _selectedDirectory = directoryPath;
        _directoryFiles = _getMusicFilesFromDirectory(directoryPath);
      });
    }
  }

  // Simulación de obtención de archivos de música en un directorio
  List<String> _getMusicFilesFromDirectory(String directoryPath) {
    // Aquí puedes implementar la lógica para listar archivos reales
    // Por ahora, simulamos con una lista de archivos
    return ['song1.mp3', 'song2.mp3', 'song3.mp3', 'song4.mp3'];
  }

  // Simulación de búsqueda automática
  void _performSearch(String query) {
    setState(() {
      _isSearching = true;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      final allSongs = [
        'Song 1 - Artist A',
        'Song 2 - Artist B',
        'Song 3 - Artist C',
        'Song 4 - Artist D',
        'Song 5 - Artist E',
      ];

      setState(() {
        _searchResults =
            allSongs
                .where(
                  (song) => song.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
        _isSearching = false;
      });
    });
  }
}
