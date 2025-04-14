import 'package:flutter/material.dart';
import 'package:soundswarm/model/playlist.dart';
import 'package:soundswarm/model/youtube_video.dart';
import 'package:soundswarm/screen/playlist_detail_screen.dart';
import 'package:soundswarm/service/audio_player_service.dart';
import 'package:soundswarm/service/playlist_service.dart';
// Ensure this is the correct path for YouTubeVideo

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  List<Playlist> _playlists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    await PlaylistService.initialize();
    
    if (!mounted) return;
    
    setState(() {
      _playlists = PlaylistService.getPlaylists();
      _isLoading = false;
    });
  }

  void _showCreatePlaylistDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nueva Playlist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej: Mis canciones favoritas',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText: 'Ej: Canciones para escuchar mientras trabajo',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final description = descriptionController.text.trim().isNotEmpty
                    ? descriptionController.text.trim()
                    : null;
                
                Navigator.pop(dialogContext);
                
                await PlaylistService.createPlaylist(
                  name, 
                  description: description,
                );
                
                if (!mounted) return;
                
                setState(() {
                  _playlists = PlaylistService.getPlaylists();
                });
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Playlists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPlaylists,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _playlists.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.playlist_play, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No tienes playlists',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Crear Playlist'),
                        onPressed: _showCreatePlaylistDialog,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = _playlists[index];
                    final songCount = playlist.songs.length;
                    
                    return ListTile(
                      leading: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(4),
                          image: playlist.thumbnailUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(playlist.thumbnailUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: playlist.thumbnailUrl == null
                            ? const Icon(Icons.playlist_play, color: Colors.white)
                            : null,
                      ),
                      title: Text(playlist.name),
                      subtitle: Text(
                        playlist.description ?? 
                        '$songCount ${songCount == 1 ? 'canción' : 'canciones'}',
                      ),
                        trailing: IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () {
                            // Mostrar opciones de playlist
                            showModalBottomSheet(
                              context: context,
                              builder: (context) => Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.edit),
                                    title: const Text('Editar'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      // TODO: Implementar edición
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.delete, color: Colors.red),
                                    title: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                                    onTap: () async {
                                      Navigator.pop(context);
                                      
                                      final confirmContext = context;
                                      final confirm = await showDialog<bool>(
                                        context: confirmContext,
                                        builder: (alertContext) => AlertDialog(
                                          title: const Text('Eliminar playlist'),
                                          content: Text('¿Estás seguro de eliminar "${playlist.name}"?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(alertContext, false),
                                              child: const Text('Cancelar'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(alertContext, true),
                                              child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );
                                      
                                      if (!mounted) return;
                                      
                                      if (confirm == true) {
                                        await PlaylistService.deletePlaylist(playlist.id);
                                        
                                        if (!mounted) return;
                                        
                                        setState(() {
                                          _playlists = PlaylistService.getPlaylists();
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      onTap: () async {
                        final result = await Navigator.push<YouTubeVideo>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PlaylistDetailScreen(playlistId: playlist.id),
                          ),
                        );
                        
                        if (!mounted) return;
                        
                        // Recargar las playlists
                        await _loadPlaylists();
                        
                        if (!mounted) return;
                        
                        // Si se seleccionó una canción, reproducirla
                        if (result != null) {
                          AudioPlayerService().playSong(result);
                          // Solo navegar de vuelta si todavía está montado
                          if (mounted) {
                            Navigator.pop(context);
                          }
                        }
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePlaylistDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}