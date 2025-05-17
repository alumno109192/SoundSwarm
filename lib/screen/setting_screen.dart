import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:soundswarm/screen/equalizer_screen.dart'; // Asegúrate de importar la pantalla del ecualizador

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _p2pEnabled = false; // Initial state for P2P connection
  String _musicPath = 'Internal Storage'; // Default value

  Future<void> _selectMusicDirectory() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Music Directory',
      );

      if (mounted) {
        setState(() {
          _musicPath = selectedDirectory ?? 'Internal Storage';
        });
      }
      // Aquí puedes agregar lógica para escanear el directorio en busca de archivos de música
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error selecting directory')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.wifi_tethering),
            title: const Text('P2P Connection'),
            subtitle: Text(_p2pEnabled ? 'Connected' : 'Disconnected'),
            value: _p2pEnabled,
            onChanged: (bool value) {
              setState(() {
                _p2pEnabled = value;
              });
              // Agrega aquí la lógica de conexión P2P
            },
          ),
          const ListTile(
            leading: Icon(Icons.volume_up),
            title: Text('Audio Quality'),
            subtitle: Text('High quality'),
          ),
          const ListTile(
            leading: Icon(Icons.download),
            title: Text('Download Quality'),
            subtitle: Text('Standard quality'),
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Music Library Location'),
            subtitle: Text(_musicPath),
            onTap: _selectMusicDirectory,
            trailing: const Icon(Icons.folder_open),
          ),
          ListTile(
            leading: const Icon(Icons.equalizer),
            title: const Text('Ecualizador'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EqualizerScreen()),
              );
            },
          ),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('About'),
            subtitle: Text('Version 1.0.0'),
          ),
        ],
      ),
    );
  }
}
