import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pay/pay.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundswarm/model/youtube_video.dart';
import 'package:soundswarm/service/audio_player_manager.dart';
import 'package:soundswarm/service/fastapi_service.dart';
import 'package:soundswarm/service/music_provider.dart';
import 'package:soundswarm/service/offline_mode_service.dart';
import 'package:soundswarm/service/playlist_service.dart';
import 'package:soundswarm/model/playlist.dart'; // Ensure Playlist is imported
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

// Clase correcta del buscador
class SongSearchDelegate extends SearchDelegate<String> {
  @override
  Widget buildSuggestions(BuildContext context) {
    // Provide suggestions based on the query
    final suggestions =
        _searchHistory.where((history) => history.startsWith(query)).toList();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        return ListTile(
          title: Text(suggestion),
          onTap: () {
            query = suggestion;
            showResults(context);
          },
        );
      },
    );
  }

  // Reemplazar YouTubeApiService por MusicProvider
  final MusicProvider _musicProvider = MusicProvider();
  final Function(String) onThumbnailSelected;
  final Function(bool) onPlayStateChanged;
  final Function(YouTubeVideo)? onSongSelected;

  List<String> _searchHistory = [];

  // Constructor igual
  SongSearchDelegate({
    required this.onThumbnailSelected,
    required this.onPlayStateChanged,
    required AudioPlayer audioPlayer,
    this.onSongSelected,
  }) {
    _loadSearchHistory();
  }

  // Método para cargar el historial desde SharedPreferences
  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _searchHistory = prefs.getStringList('search_history') ?? [];
    // Forzar reconstrucción
    query = query;
  }

  // Método para guardar una nueva búsqueda en el historial
  Future<void> _saveSearch(String query) async {
    if (query.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    // Remover la consulta si ya existe (para moverla al principio)
    _searchHistory.remove(query);

    // Añadir la nueva consulta al principio
    _searchHistory.insert(0, query);

    // Limitar el historial a 10 elementos
    if (_searchHistory.length > 10) {
      _searchHistory = _searchHistory.sublist(0, 10);
    }

    // Guardar en SharedPreferences
    await prefs.setStringList('search_history', _searchHistory);
  }

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
    _saveSearch(query);

    return FutureBuilder<List<YouTubeVideo>>(
      // Reemplazar _apiService.searchVideos por _musicProvider.searchSongs
      future: _musicProvider.searchSongs(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Buscando en múltiples fuentes...'),
              ],
            ),
          );
        } else if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                SizedBox(height: 16),
                Text('Error al conectar con el servidor: ${snapshot.error}'),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                  onPressed: () {
                    showResults(context);
                  },
                ),
                SizedBox(height: 8),
                // Botón para buscar en modo offline
                TextButton.icon(
                  icon: const Icon(Icons.offline_bolt),
                  label: const Text('Usar datos guardados'),
                  onPressed: () {
                    _musicProvider.setOfflineMode(true);
                    showResults(context);
                  },
                ),
              ],
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No se encontraron resultados'),
                const SizedBox(height: 16),

                // Opción para buscar en caché
                if (!_musicProvider.isOfflineMode)
                  TextButton.icon(
                    icon: const Icon(Icons.history),
                    label: const Text('Ver resultados guardados'),
                    onPressed: () async {
                      // Buscar en caché
                      final cachedResults =
                          await OfflineModeService.getSearchResults(query);
                      if (cachedResults.isNotEmpty) {
                        _musicProvider.setOfflineMode(true);
                        showResults(context);
                        // Volver al modo online después
                        Future.delayed(const Duration(seconds: 2), () {
                          _musicProvider.setOfflineMode(false);
                        });
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'No hay resultados guardados para esta búsqueda',
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),

                // Botón para reintentar
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                  onPressed: () {
                    showResults(context);
                  },
                ),
              ],
            ),
          );
        } else {
          final videos = snapshot.data!;

          // Guardar en caché offline si no estamos en modo offline
          if (!_musicProvider.isOfflineMode) {
            OfflineModeService.saveRecentSearch(query, videos);
          }

          return Column(
            children: [
              // Indicador de fuente de datos
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 16,
                ),
                color: Colors.black54,
                child: Row(
                  children: [
                    Icon(
                      _musicProvider.isOfflineMode
                          ? Icons.offline_bolt
                          : Icons.cloud_done,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _musicProvider.isOfflineMode
                          ? 'Modo offline (datos almacenados)'
                          : 'Conectado a servidor local',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const Spacer(),
                    // Botón para alternar modo offline
                    TextButton.icon(
                      icon: Icon(
                        _musicProvider.isOfflineMode
                            ? Icons.cloud
                            : Icons.offline_bolt,
                        size: 16,
                      ),
                      label: Text(
                        _musicProvider.isOfflineMode
                            ? 'Conectar'
                            : 'Modo offline',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                      ),
                      onPressed: () {
                        _musicProvider.setOfflineMode(
                          !_musicProvider.isOfflineMode,
                        );
                        showResults(context);
                      },
                    ),
                  ],
                ),
              ),
              // Lista de videos
              Expanded(
                child: ListView.builder(
                  itemCount: videos.length,
                  itemBuilder: (context, index) {
                    final video = videos[index];
                    return ListTile(
                      leading: Container(
                        width: 60,
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(4),
                          image: DecorationImage(
                            image: NetworkImage(video.thumbnailUrl),
                            fit: BoxFit.cover,
                            onError: (_, __) {
                              // No necesitamos manejar el error aquí
                            },
                          ),
                        ),
                      ),
                      title: Text(
                        video.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(video.channelTitle),
                      trailing: IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () {
                          _showSongOptions(context, video);
                        },
                      ),
                      onTap: () async {
                        try {
                          // Obtener instancia del manager
                          final playerManager = AudioPlayerManager.instance;

                          // Mostrar indicador de carga
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Cargando audio...'),
                              ),
                            );
                          }

                          // Actualizar datos visuales inmediatamente
                          playerManager.setCurrentSong(video);
                          playerManager.setThumbnail(video.thumbnailUrl);

                          // Usar el método correcto
                          // Opción 1: Usar playSafe que toma una URL y un MediaItem
                          await playerManager.playSong(context, video);

                          // O Opción 2: Si playSong existe y toma estos parámetros
                          // await playerManager.playSong(context, video);

                          // Notificar cambio de estado de reproducción
                          playerManager.setPlayState(true);

                          if (context.mounted) {
                            // Cerrar la búsqueda
                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Reproduciendo: ${video.title}'),
                              ),
                            );
                          }

                          // Cargar canciones relacionadas
                          playerManager.loadRelatedSongs(video.videoId);
                        } catch (e) {
                          // Manejo de errores...
                          if (kDebugMode) {
                            print('Error al reproducir: $e');
                          }

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Error al conectar con el servidor. Intentando usar caché...',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );

                            // Intentar modo offline como fallback
                            _musicProvider.setOfflineMode(true);
                            showResults(context);
                          }
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          );
        }
      },
    );
  }

  // También actualizar el método _showSongOptions para usar MusicProvider
  void _showSongOptions(BuildContext context, YouTubeVideo video) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return FutureBuilder<bool>(
          future: PlaylistService.isFavorite(video.videoId),
          builder: (context, snapshot) {
            // Usar el valor del Future o false si aún no está disponible
            final isFavorite = snapshot.data ?? false;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.play_arrow),
                  title: const Text('Reproducir'),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      // Obtener instancia del manager
                      final playerManager = AudioPlayerManager.instance;

                      // Mostrar indicador de carga
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cargando audio...')),
                      );

                      // Actualizar datos visuales inmediatamente
                      playerManager.setCurrentSong(video);
                      playerManager.setThumbnail(video.thumbnailUrl);

                      // Reproducción segura con manejo de errores integrado
                      await playerManager.playSong(context, video);

                      // Notificar cambio de estado de reproducción
                      playerManager.setPlayState(true);

                      if (context.mounted) {
                        // Cerrar la búsqueda
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Reproduciendo: ${video.title}'),
                          ),
                        );
                      }

                      // Cargar canciones relacionadas
                      playerManager.loadRelatedSongs(video.videoId);
                    } catch (e) {
                      // Manejo de errores...
                      if (kDebugMode) {
                        print('Error al reproducir: $e');
                      }

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Error al reproducir. Intentando usar datos guardados...',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );

                        // Intentar modo offline como fallback
                        _musicProvider.setOfflineMode(true);

                        // No reintentar automáticamente para evitar bucles
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.playlist_add),
                  title: const Text('Añadir a una lista'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddToPlaylistDialog(context, video);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.favorite),
                  title: Text(
                    isFavorite // Usar el valor obtenido del Future
                        ? 'Quitar de favoritos'
                        : 'Añadir a favoritos',
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    // Obtener el estado actualizado
                    final currentIsFavorite = await PlaylistService.isFavorite(
                      video.videoId,
                    );

                    if (currentIsFavorite) {
                      await PlaylistService.removeFavorite(video.videoId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${video.title} quitada de favoritos',
                            ),
                          ),
                        );
                      }
                    } else {
                      await PlaylistService.addFavorite(video);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${video.title} añadida a favoritos'),
                          ),
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Descargar (Pago)'),
                  onTap: () async {
                    bool isPayed = await _showPaymentOptionsDialog(
                      context,
                      video,
                    );
                    if (isPayed) {
                      // Mostrar diálogo para seleccionar la ubicación de descarga
                      _showSaveDownloadDialog(context, video);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, YouTubeVideo video) {
    final playlists = PlaylistService.getPlaylists();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Añadir a lista'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: FutureBuilder<List<Playlist>>(
              future: playlists,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return const Center(
                    child: Text('Error al cargar las listas'),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No tienes listas creadas'));
                } else {
                  final playlistData = snapshot.data!;
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlistData.length,
                    itemBuilder: (context, index) {
                      final playlist = playlistData[index];
                      return ListTile(
                        title: Text(playlist.name),
                        onTap: () async {
                          Navigator.pop(context);

                          // Comprobar si la canción ya está en la lista
                          bool songExists = playlist.songs.any(
                            (song) => song.videoId == video.videoId,
                          );

                          if (songExists) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${video.title} ya está en ${playlist.name}',
                                ),
                              ),
                            );
                            return;
                          }

                          await PlaylistService.addSongToPlaylist(
                            playlist.id,
                            video,
                          );

                          if (context.mounted) {
                            // Correcto para BuildContext pasado como parámetro
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${video.title} añadida a ${playlist.name}',
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  );
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showCreatePlaylistDialog(context, video);
              },
              child: const Text('Nueva lista'),
            ),
          ],
        );
      },
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, YouTubeVideo video) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Nueva lista'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Ej: Mis favoritas',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                    hintText: 'Ej: Canciones para el gimnasio',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isNotEmpty) {
                    final description =
                        descriptionController.text.trim().isNotEmpty
                            ? descriptionController.text.trim()
                            : null;

                    Navigator.pop(context);

                    final playlist = await PlaylistService.createPlaylist(
                      name,
                      description: description,
                    );

                    await PlaylistService.addSongToPlaylist(playlist.id, video);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${video.title} añadida a $name'),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Crear'),
              ),
            ],
          ),
    );
  }

  Future<bool> _startPayPalPayment(
    BuildContext context,
    YouTubeVideo video,
  ) async {
    try {
      // Aquí puedes implementar la lógica de PayPal
      // Por ejemplo, abrir una página web para procesar el pago
      if (kDebugMode) {
        print('Iniciando pago con PayPal para: ${video.title}');
      }

      // Simula un pago exitoso
      await Future.delayed(const Duration(seconds: 2));
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error en el pago con PayPal: $e');
      }
      return false;
    }
  }

  Future<void> _downloadSong(YouTubeVideo video, String downloadPath) async {
    try {
      // Obtén la URL del audio
      final audioUrl = await FastApiService().getAudioUrl(video.videoId);

      // Nombre del archivo basado en el título de la canción
      final fileName = '${video.title.replaceAll(' ', '_')}.mp3';
      final filePath = '$downloadPath/$fileName';

      // Usa Dio para descargar el archivo
      final dio = Dio();
      await dio.download(
        audioUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            if (kDebugMode) {
              print(
                'Progreso: ${(received / total * 100).toStringAsFixed(0)}%',
              );
            }
          }
        },
      );

      if (kDebugMode) {
        print('Canción descargada: $filePath');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al descargar la canción: $e');
      }
      throw Exception('Error al descargar la canción');
    }
  }

  Future<bool> _showManualPaymentDialog(BuildContext context) async {
    final controller = TextEditingController();

    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Pago manual'),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Ingresa un código de pago',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () {
                    if (controller.text.isNotEmpty) {
                      Navigator.pop(context, true); // Simula un pago exitoso
                    } else {
                      Navigator.pop(context, false); // Simula un pago fallido
                    }
                  },
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<String?> _showSaveDownloadDialog(
    BuildContext context,
    YouTubeVideo video,
  ) async {
    String? selectedPath;
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      throw Exception('Permiso de almacenamiento denegado');
    }

    // Obtén el directorio predeterminado
    final directory = await getApplicationSupportDirectory();
    final defaultDirectory = Directory('${directory.path}/SonicSwapMusic');

    // Asegúrate de que el directorio predeterminado exista
    if (!await defaultDirectory.exists()) {
      await defaultDirectory.create(recursive: true);
    }

    return await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Selecciona la ubicación de descarga'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Carpeta predeterminada'),
                onTap: () async {
                  selectedPath =
                      defaultDirectory.path; // Carpeta predeterminada
                  Navigator.pop(context, selectedPath);
                  await _downloadSong(video, selectedPath!);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${video.title} descargada en $selectedPath',
                        ),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.sd_storage),
                title: const Text('Tarjeta SD'),
                onTap: () {
                  selectedPath =
                      '/storage/sdcard1/Downloads'; // Carpeta en la tarjeta SD
                  Navigator.pop(context, selectedPath);
                },
              ),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Seleccionar carpeta'),
                onTap: () async {
                  Navigator.pop(context); // Cierra el diálogo actual
                  final directoryPath =
                      await FilePicker.platform.getDirectoryPath();
                  if (directoryPath != null) {
                    selectedPath = directoryPath;
                    await _downloadSong(video, selectedPath!);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${video.title} descargada en $selectedPath',
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Cancelar'),
                onTap: () {
                  Navigator.pop(context, null); // Cancela la selección
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _startGooglePayPayment(
    BuildContext context,
    YouTubeVideo video,
  ) async {
    try {
      final paymentItems = [
        PaymentItem(
          label: video.title,
          amount: '1.99', // Precio de la descarga
          status: PaymentItemStatus.final_price,
        ),
      ];

      // Determinar el entorno (TEST o PRODUCTION)
      final environment = kDebugMode ? 'test' : 'production';
      final googlePayConfigFileName =
          environment == 'test'
              ? 'json/google_pay_config_test.json'
              : 'json/google_pay_config_production.json';

      // Cargar la configuración de Google Pay desde el archivo JSON
      final googlePayConfiguration = await PaymentConfiguration.fromAsset(
        googlePayConfigFileName,
      );

      bool isPayed = false;

      // Mostrar el diálogo con Google Pay
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Pagar con Google Pay'),
            content: GooglePayButton(
              paymentConfiguration: googlePayConfiguration,
              paymentItems: paymentItems,
              onPaymentResult: (result) {
                if (kDebugMode) {
                  print('Resultado del pago con Google Pay: $result');
                }
                isPayed = true;
                Navigator.pop(context); // Cierra el diálogo después del pago
              },
              onError: (error) {
                if (kDebugMode) {
                  print('Error en el pago con Google Pay: $error');
                }
                isPayed = false;
                Navigator.pop(context); // Cierra el diálogo en caso de error
              },
              loadingIndicator: const CircularProgressIndicator(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          );
        },
      );

      return isPayed;
    } catch (e) {
      if (kDebugMode) {
        print('Error en el flujo de pago con Google Pay: $e');
      }
      return false;
    }
  }

  Future<bool> _showPaymentOptionsDialog(
    BuildContext context,
    YouTubeVideo video,
  ) async {
    bool isPayed = false;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Selecciona un método de pago'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Opción de Google Pay
              ElevatedButton.icon(
                icon: const Icon(Icons.payment),
                label: const Text('Pagar con Google Pay'),
                onPressed: () async {
                  Navigator.pop(context); // Cierra el diálogo
                  isPayed = await _startGooglePayPayment(context, video);
                },
              ),
              const SizedBox(height: 16),

              // Opción de PayPal
              ElevatedButton.icon(
                icon: const Icon(Icons.account_balance_wallet),
                label: const Text('Pagar con PayPal'),
                onPressed: () async {
                  Navigator.pop(context); // Cierra el diálogo
                  isPayed = await _startPayPalPayment(context, video);
                },
              ),
              const SizedBox(height: 16),

              // Opción de pago manual
              ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Pago manual'),
                onPressed: () async {
                  Navigator.pop(context); // Cierra el diálogo
                  isPayed = await _showManualPaymentDialog(context);
                },
              ),
              // Opción para simular un pago exitoso
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle),
                label: const Text('Simular pago exitoso'),
                onPressed: () {
                  Navigator.pop(context); // Cierra el diálogo
                  isPayed = true; // Simula un pago exitoso
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );

    return isPayed;
  }

  Future<bool> _requestStoragePermission() async {
    final status = await Permission.storage.request();
    return status.isGranted;
  }
}
