import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:soundswarm/screen/home_screen.dart';
import 'package:soundswarm/service/audio_player_manager.dart';
import 'package:soundswarm/widgets/audio_player_widget.dart';

Future<void> main() async {
  // Asegurarse de que los bindings están inicializados
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar just_audio_background
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.sonicswap.channel.audio',
    androidNotificationChannelName: 'SonicSwap',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
  );

  runApp(const MyApp());
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

// Nueva clase para mantener el reproductor persistente
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Singleton para toda la app
  final AudioPlayerManager _playerManager = AudioPlayerManager();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Contenido principal expandible
          Expanded(
            child: Navigator(
              // Navegador anidado para las pantallas de la app
              onGenerateRoute: (settings) {
                // Por defecto, mostrar la pantalla de inicio
                return MaterialPageRoute(
                  builder: (context) => const HomeScreen(),
                );
              },
            ),
          ),

          // Reproductor persistente en la parte inferior
          AudioPlayerWidget(
            audioPlayer: _playerManager.audioPlayer,
            currentSong: _playerManager.currentSong,
            //currentThumbnailUrl: _playerManager.currentThumbnailUrl,
            //onSongChanged: (song) {
            // setState(() {
            // El manager ya mantiene actualizado el estado
            // });
            //},
            //onThumbnailChanged: (url) {
            // setState(() {
            // El manager ya mantiene actualizado el estado
            //});
            //},
          ),
        ],
      ),
    );
  }
}
