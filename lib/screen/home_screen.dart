import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isPlaying = false; // Estado de reproducción

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music P2P'),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Álbum/Portada (placeholder)
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

            // Controles de reproducción
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

            // Barra de progreso (placeholder)
            const SizedBox(height: 20),
            Slider(
              value: 0.3, // Valor estático por ahora
              onChanged: (value) {},
            ),
          ],
        ),
      ),
    );
  }
}