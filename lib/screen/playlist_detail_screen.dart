import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:soundswarm/model/playlist.dart';
import 'package:soundswarm/model/youtube_video.dart';
import 'package:soundswarm/service/playlist_service.dart';
import 'package:soundswarm/service/audio_player_manager.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistId;
  final AudioPlayer? audioPlayer; // Añadir este parámetro

  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
    this.audioPlayer, // Opcional para compatibilidad
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  Playlist? _playlist;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  @override
  void dispose() {
    // NO disponer del AudioPlayer aquí, ya que es compartido
    super.dispose();
  }

  Future<void> _loadPlaylist() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final playlist = PlaylistService.getPlaylist(widget.playlistId);
      setState(() {
        _playlist = playlist;
      });
    } catch (e) {
      // Manejo de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar playlist: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_playlist?.name ?? 'Playlist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPlaylist,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _playlist == null
              ? const Center(child: Text('Playlist no encontrada'))
              : _buildPlaylistContent(),
    );
  }

  Widget _buildPlaylistContent() {
    if (_playlist!.songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_note, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No hay canciones en esta playlist',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Buscar canciones'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _playlist!.songs.length,
      itemBuilder: (context, index) {
        final song = _playlist!.songs[index];
        return ListTile(
          leading: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
              image: song.thumbnailUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(song.thumbnailUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: song.thumbnailUrl.isEmpty
                ? const Icon(Icons.music_note, color: Colors.white)
                : null,
          ),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            song.channelTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showSongOptions(song),
          ),
          onTap: () {
            // Reproducir la canción en el reproductor principal
            _playSong(song);
          },
        );
      },
    );
  }

  void _showSongOptions(YouTubeVideo song) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Reproducir'),
              onTap: () {
                Navigator.pop(context);
                _playSong(song);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_remove),
              title: const Text('Quitar de esta playlist'),
              onTap: () async {
                Navigator.pop(context);
                await PlaylistService.removeSongFromPlaylist(
                  widget.playlistId, 
                  song.videoId,
                );
                _loadPlaylist();
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: Text(
                PlaylistService.isFavorite(song.videoId)
                    ? 'Quitar de favoritos'
                    : 'Añadir a favoritos',
              ),
              onTap: () async {
                Navigator.pop(context);
                if (PlaylistService.isFavorite(song.videoId)) {
                  await PlaylistService.removeFavorite(song.videoId);
                } else {
                  await PlaylistService.addFavorite(song);
                }
                _loadPlaylist();
              },
            ),
          ],
        );
      },
    );
  }

  // Modificar _playSong en PlaylistDetailScreen:
  void _playSong(YouTubeVideo song) {
    try {
      // Usar AudioPlayerManager en lugar de HomeScreen.playSong
      final playerManager = AudioPlayerManager();
      playerManager.playSong(context, song);
      
      // No es necesario cerrar la pantalla
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al reproducir: $e')),
      );
    }
  }
}