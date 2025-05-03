import 'package:flutter/material.dart';
import 'package:soundswarm/screen/favorites_screen.dart';
import 'package:soundswarm/screen/search_music_screen.dart';
import 'package:soundswarm/screen/setting_screen.dart';
import 'package:soundswarm/screen/playlists_screen.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.blue),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        // Avatar simplificado
                        const CircleAvatar(
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person),
                        ),
                        const SizedBox(width: 10),

                        // Título de la app
                        const Text(
                          'SoundSwarm',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Subtítulo o slogan
                    const Text(
                      'Tu música favorita',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
                // Botón de cierre en la esquina superior derecha
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context); // Cierra el drawer
                    },
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Inicio'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.library_music),
            title: const Text('Mi Biblioteca'),
            onTap: () {
              Navigator.pop(context);
              // Navegar a la biblioteca si tienes esa pantalla
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchMusicScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_play),
            title: const Text('Mis Playlists'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PlaylistsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.favorite),
            title: const Text('Favoritos'),
            onTap: () {
              Navigator.pop(context);
              // Navegar a favoritos
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FavoritesScreen(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configuración'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Acerca de'),
            onTap: () {
              Navigator.pop(context);
              showAboutDialog(
                context: context,
                applicationName: 'SoundSwarm',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(Icons.music_note),
                applicationLegalese: '© 2023 SoundSwarm',
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Text(
                      'Una aplicación para disfrutar y organizar tu música favorita.',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
