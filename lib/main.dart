import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:soundswarm/screen/home_screen.dart';
import 'package:soundswarm/service/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Comentar la inicialización de just_audio_background
  /*
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.soundswarm.channel.audio',
    androidNotificationChannelName: 'SoundSwarm Audio',
    androidNotificationOngoing: false,
    androidShowNotificationBadge: false,
    androidStopForegroundOnPause: true,
    notificationColor: Colors.blue,
    androidNotificationIcon: 'mipmap/ic_launcher',
  );
  
  // Inicializar nuestro servicio personalizado de notificaciones
  await NotificationService.initialize();
  */
  
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