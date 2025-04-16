import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soundswarm/screen/drawer.dart';
import 'package:soundswarm/screen/song_search_delegate.dart';
import 'package:soundswarm/service/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:soundswarm/service/audio_player_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late AudioPlayerManager _playerManager;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Inicializar AudioPlayerManager
    _playerManager = AudioPlayerManager.instance;
    
    // Configurar callbacks para actualizar la UI
    _playerManager.onThumbnailChanged = (url) {
      setState(() {
        // No necesitamos _currentThumbnailUrl local
      });
    };
    
    _playerManager.onSongChanged = (song) {
      setState(() {
        // Si hay una nueva canción, cargar canciones relacionadas
        if (song != null) {
          _playerManager.loadRelatedSongs(song.videoId);
        }
      });
    };
    
    _playerManager.onPlayStateChanged = (isPlaying) {
      setState(() {
        // No necesitamos _isPlaying local
      });
    };
    
    // Solo mantener esto
    _loadSearchHistory();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.onScreenStateChanged = null;
    // No necesitamos disponer _audioPlayer, lo maneja AudioPlayerManager
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    // Load search history or initialize an empty list
    final searchHistory = prefs.getStringList('search_history') ?? [];
    if (kDebugMode) {
      print('Search history loaded: $searchHistory');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // La app está visible de nuevo, no necesitamos hacer nada especial
    } else if (state == AppLifecycleState.paused) {
      // La app está en segundo plano, asegurarse de que la reproducción continúe
      // No hacer seek u operaciones disruptivas aquí
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SonicSwap'),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: SongSearchDelegate(
                  onThumbnailSelected: (thumbnailUrl) {
                    setState(() {
                      _playerManager.onThumbnailChanged?.call(thumbnailUrl);
                    });
                  },
                  onPlayStateChanged: (isPlaying) {
                    setState(() {
                      _playerManager.onPlayStateChanged?.call(isPlaying);
                    });
                  },
                  onSongSelected: (video) {
                    setState(() {
                      _playerManager.onSongChanged?.call(video);
                    });
                  },
                  audioPlayer: _playerManager.audioPlayer,
                ),
              );
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Portada del álbum
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Carátula
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(10),
                        image: _playerManager.currentThumbnailUrl != null && 
                               _playerManager.currentThumbnailUrl!.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(_playerManager.currentThumbnailUrl!), 
                                fit: BoxFit.cover,
                                onError: (exception, stackTrace) {
                                  if (kDebugMode) {
                                    print('Error al cargar imagen: $exception');
                                  }
                                },
                              )
                            : null,
                      ),
                      key: ValueKey(_playerManager.currentThumbnailUrl),
                      child: _playerManager.currentThumbnailUrl == null || 
                             _playerManager.currentThumbnailUrl!.isEmpty
                          ? const Icon(Icons.music_note, size: 50, color: Colors.white)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                
                // Información de la canción con botón de opciones
                if (_playerManager.currentSong != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            _playerManager.currentSong!.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      
                      // Botón de opciones junto al título
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () {
                          _playerManager.showCurrentSongOptions(context);
                        },
                      ),
                    ],
                  ),
                if (_playerManager.currentSong != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      _playerManager.currentSong!.channelTitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}