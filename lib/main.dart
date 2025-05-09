import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:soundswarm/screen/home_screen.dart';
import 'package:soundswarm/service/audio_player_manager.dart';
import 'package:soundswarm/service/playlist_db_service.dart';
import 'package:soundswarm/widgets/audio_player_widget.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.sonicswap.channel.audio',
    androidNotificationChannelName: 'SonicSwap',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
  );

  // Elimina la base de datos existente
  //await PlaylistDbService().deleteDatabaseFile();

  // Inicializa la base de datos
  await PlaylistDbService.database;

  await _initializeApp();

  runApp(const MyApp());
}

Future<void> _initializeApp() async {
  final status = await Permission.storage.request();
  if (!status.isGranted) {
    throw Exception('Permiso de almacenamiento denegado');
  }

  final directory = await getApplicationSupportDirectory();
  final downloadDirectory = Directory('${directory.path}/SonicSwapMusic');
  if (!await downloadDirectory.exists()) {
    await downloadDirectory.create(recursive: true);
    if (kDebugMode) {
      print('Directorio creado: ${downloadDirectory.path}');
    }
  } else {
    if (kDebugMode) {
      print('El directorio ya existe: ${downloadDirectory.path}');
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoundSwarm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final AudioPlayerManager _playerManager = AudioPlayerManager();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Navigator(
              onGenerateRoute: (settings) {
                return MaterialPageRoute(
                  builder: (context) => const HomeScreen(),
                );
              },
            ),
          ),
          AudioPlayerWidget(
            audioPlayer: _playerManager.audioPlayer,
            currentSong: _playerManager.currentSong,
          ),
        ],
      ),
    );
  }
}
