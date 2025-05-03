import 'package:flutter/material.dart';
import 'package:soundswarm/model/youtube_video.dart';
import 'package:soundswarm/service/playlist_db_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<YouTubeVideo> _favoriteSongs = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final List<YouTubeVideo> songs = await PlaylistDbService.getFavoriteSongs();
    if (songs.isEmpty) {
      // Si no hay canciones favoritas, mostrar un mensaje
      setState(() {
        _favoriteSongs = [];
      });
      return;
    }
    setState(() {
      _favoriteSongs = songs;
    });
  }

  Future<Database> _getDatabase() async {
    return openDatabase(
      join(await getDatabasesPath(), 'sonicswap.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE favorites(id INTEGER PRIMARY KEY, title TEXT, artist TEXT, thumbnailUrl TEXT)',
        );
      },
      version: 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
      body:
          _favoriteSongs.isEmpty
              ? const Center(
                child: Text(
                  'No tienes canciones favoritas.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
              : ListView.builder(
                itemCount: _favoriteSongs.length,
                itemBuilder: (context, index) {
                  final song = _favoriteSongs[index];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        song.thumbnailUrl,
                        width: 50,
                        height: 50,
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
                    title: Text(song.title ?? 'Sin título'),
                    subtitle: Text(song.channelTitle ?? 'Artista desconocido'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await _deleteFavorite(song.videoId!);
                        setState(() {
                          _favoriteSongs.removeAt(index);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Canción eliminada de favoritos',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        _loadFavorites(); // Recargar la lista después de eliminar
                      },
                    ),
                  );
                },
              ),
    );
  }

  Future<void> _deleteFavorite(String id) async {
    final database = await _getDatabase();
    await database.delete('favorites', where: 'id = ?', whereArgs: [id]);
  }
}
