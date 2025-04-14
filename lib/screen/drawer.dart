import 'package:flutter/material.dart';
import 'package:soundswarm/screen/setting_screen.dart';
import 'package:soundswarm/service/auth_service.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = AuthService.isSignedIn();
    final currentUser = AuthService.currentUser;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        // Avatar del usuario (mostrar foto de perfil si está conectado)
                        CircleAvatar(
                          backgroundColor: Colors.white,
                          backgroundImage: isLoggedIn && currentUser?.photoUrl != null
                              ? NetworkImage(currentUser!.photoUrl!)
                              : null,
                          child: isLoggedIn && currentUser?.photoUrl != null
                              ? null
                              : const Icon(Icons.person),
                        ),
                        const SizedBox(width: 10),
                        
                        // Botón de login/logout de YouTube
                        _isLoading
                            ? const CircularProgressIndicator()
                            : ElevatedButton.icon(
                                icon: isLoggedIn
                                    ? const Icon(Icons.logout, color: Colors.red)
                                    : Image.asset(
                                        'assets/youtube_logo.png',
                                        width: 20,
                                        height: 20,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Icon(Icons.play_circle_filled, color: Colors.red),
                                      ),
                                label: Text(
                                  isLoggedIn ? 'Logout' : 'Login con YouTube',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.red,
                                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                ),
                                onPressed: () async {
                                  setState(() {
                                    _isLoading = true;
                                  });

                                  try {
                                    if (isLoggedIn) {
                                      // Cerrar sesión
                                      await AuthService.signOut();
                                      if (!context.mounted) return;
                                      
                                      // Una vez verificado mounted, podemos usar context
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Sesión cerrada')),
                                      );
                                    } else {
                                      // Iniciar sesión
                                      final account = await AuthService.signIn();
                                      if (!context.mounted) return;
                                      
                                      if (account != null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Bienvenido, ${account.displayName}'),
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Login cancelado'),
                                          ),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    if (!mounted) return;
                                    
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _isLoading = false;
                                      });
                                    }
                                  }
                                },
                              ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Mostrar el nombre del usuario si está conectado
                    Text(
                      isLoggedIn && currentUser != null
                          ? currentUser.displayName ?? 'Usuario de YouTube'
                          : 'SoundSwarm',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                    if (isLoggedIn && currentUser?.email != null)
                      Text(
                        currentUser!.email,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                // Botón de cierre en la esquina superior derecha
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Cierra el drawer
                    },
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
              // No hay operaciones asíncronas aquí, así que no necesitamos verificar mounted
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
    );
  }
}