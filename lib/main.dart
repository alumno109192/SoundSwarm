import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:soundswarm/screen/home_screen.dart';

// Variable global para indicar si just_audio_background está inicializado
bool isJustAudioBackgroundInitialized = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Manejo de errores para la inicialización
  try {
    // Inicializar just_audio_background con timeout
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.soundswarm.channel.audio',
      androidNotificationChannelName: 'SoundSwarm Audio',
      androidNotificationOngoing: false, // Cambiar a false para evitar problemas iniciales
      androidShowNotificationBadge: true,
      androidStopForegroundOnPause: true, // Cambiar a true para reducir problemas
      notificationColor: Colors.blue,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ).timeout(
      const Duration(seconds: 15), // Aumentar tiempo de espera
      onTimeout: () {
        if (kDebugMode) {
          print('Timeout al inicializar JustAudioBackground, continuando sin él');
        }
        return;
      },
    );
    
    // Marcar como inicializado
    isJustAudioBackgroundInitialized = true;
    
    if (kDebugMode) {
      print('JustAudioBackground inicializado correctamente');
    }
  } catch (e) {
    // Capturar cualquier error para evitar que la app se bloquee
    if (kDebugMode) {
      print('Error al inicializar JustAudioBackground: $e');
      print('La app continuará sin funcionalidad de reproducción en segundo plano');
    }
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music P2P',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}