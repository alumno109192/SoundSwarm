import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soundswarm/model/youtube_video.dart';
import 'package:soundswarm/screen/setting_screen.dart';
import 'package:soundswarm/service/youtube_api_service.dart'; // Ensure this file defines the YouTubeApiService class
import 'package:just_audio/just_audio.dart';
import 'package:soundswarm/service/audio_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music P2P'),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: SongSearchDelegate(),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'SoundSwarm',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.library_music),
              title: const Text('My Library'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_play),
              title: const Text('Playlists'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Downloads'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.music_note, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 35),
                  onPressed: () {},
                ),
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle : Icons.play_circle,
                    size: 50,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPlaying = !_isPlaying;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 35),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 20),
            Slider(
              value: 0.3,
              onChanged: (value) {},
            ),
          ],
        ),
      ),
    );
  }
}

class SongSearchDelegate extends SearchDelegate<String> {
  final YouTubeApiService _apiService = YouTubeApiService();
  final AudioService _audioService = AudioService(); // Instancia persistente
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, ''); // Cierra el buscador
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return FutureBuilder<List<YouTubeVideo>>(
      future: _apiService.searchVideos(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No se encontraron resultados.'));
        } else {
          final videos = snapshot.data!;
          return ListView.builder(
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              return ListTile(
                leading: Image.network(video.thumbnailUrl),
                title: Text(video.title),
                subtitle: Text(video.channelTitle),
                onTap: () async {
                  try {
                    final audioUrl = await _audioService.getAudioUrl(video.videoId);
                    await _audioPlayer.setUrl(audioUrl);
                    _audioPlayer.play();

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Reproduciendo: ${video.title}')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al reproducir audio: $e')),
                      );
                    }
                  }
                },
              );
            },
          );
        }
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Center(
      child: Text('Escribe para buscar canciones en YouTube'),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _audioService.dispose(); // Cierra la instancia de AudioService
    super.dispose();
  }
}