import 'package:flutter/material.dart';
import 'package:soundswarm/service/playlist_db_service.dart';

class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  final List<String> _labels = ['60Hz', '230Hz', '910Hz', '3.6kHz', '14kHz'];
  final List<double> _bands = [0, 0, 0, 0, 0];

  final Map<String, List<double>> _presets = {
    'Normal': [0, 0, 0, 0, 0],
    'Rock': [5, 3, 0, 3, 5],
    'Heavy Metal': [6, 4, 0, 4, 6],
    'Jazz': [4, 2, 0, 3, 4],
    'Pop': [3, 2, 0, 2, 3],
    'Clásica': [2, 4, 0, 4, 2],
    'Dance': [6, 4, 0, 4, 6],
    'Vocal': [0, 3, 6, 3, 0],
    'Bass Boost': [8, 4, 0, -2, -4],
    'Treble Boost': [-2, 0, 2, 6, 8],
  };

  @override
  void initState() {
    super.initState();
    _loadBands();
  }

  void _applyPreset(List<double> values) {
    setState(() {
      for (int i = 0; i < _bands.length; i++) {
        _bands[i] = values[i];
      }
    });
  }

  Future<void> _saveBands() async {
    await PlaylistDbService().saveEqualizerBands(_bands);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ecualizador guardado')));
    }
  }

  Future<void> _loadBands() async {
    final bands = await PlaylistDbService().loadEqualizerBands();
    if (bands != null && bands.length == _bands.length) {
      setState(() {
        for (int i = 0; i < _bands.length; i++) {
          _bands[i] = bands[i];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ecualizador'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Preset',
                border: OutlineInputBorder(),
              ),
              value: null,
              hint: const Text('Selecciona un preset'),
              items:
                  _presets.keys.map((preset) {
                    return DropdownMenuItem<String>(
                      value: preset,
                      child: Text(preset),
                    );
                  }).toList(),
              onChanged: (preset) {
                if (preset != null) {
                  _applyPreset(_presets[preset]!);
                }
              },
            ),
            const SizedBox(height: 24),
            for (int i = 0; i < _bands.length; i++)
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_labels[i]),
                      Text('${_bands[i].toStringAsFixed(1)} dB'),
                    ],
                  ),
                  Slider(
                    value: _bands[i],
                    min: -12,
                    max: 12,
                    divisions: 24,
                    label: '${_bands[i].toStringAsFixed(1)} dB',
                    onChanged: (value) {
                      setState(() {
                        _bands[i] = value;
                      });
                    },
                  ),
                ],
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Resetear'),
                  onPressed: () {
                    setState(() {
                      for (int i = 0; i < _bands.length; i++) {
                        _bands[i] = 0;
                      }
                    });
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar'),
                  onPressed: _saveBands,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
