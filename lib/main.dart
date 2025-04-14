import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:soundswarm/screen/home_screen.dart';
import 'package:soundswarm/service/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar el servicio de audio en segundo plano con notificación minimizada
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.soundswarm.channel.audio',
    androidNotificationChannelName: 'SoundSwarm Audio',
    androidNotificationOngoing: false, // No mostrar como permanente
    androidShowNotificationBadge: false, // Sin badge
    androidStopForegroundOnPause: true, // Ocultar cuando se pausa
    notificationColor: Colors.blue,
    // La notificación será minimalista por defecto
    androidNotificationIcon: 'mipmap/ic_launcher', // Usa el icono de la app
  );
  
  // Inicializar nuestro servicio personalizado de notificaciones
  await NotificationService.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music P2P',
      debugShowCheckedModeBanner: false, // Elimina el banner de depuración
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