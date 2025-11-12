import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:flutter_cube/flutter_cube.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mqtt_service.dart';

// MQTT condiviso
final MqttService mqttService = MqttService();

// Chiave per salvare la scelta del modello
const _kSelectedModelKey = 'selected_model_key'; // 'model1' | 'model2'

// Sample per storico (useremo dopo per i grafici)
class SensorSample {
  final DateTime time;
  final double value;
  SensorSample(this.time, this.value);
}

void main() {
  runApp(const PlantformioApp());
}

class PlantformioApp extends StatelessWidget {
  const PlantformioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plantformio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0b1f16),
        popupMenuTheme: const PopupMenuThemeData(
          color: Color(0xFF10251a), // tendina verde scuro
          textStyle: TextStyle(color: Colors.white),
        ),
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  MqttConnectionState _connectionState = MqttConnectionState.disconnected;

  // ultimi valori
  String? _lastTemperature;
  String? _lastHumidity;
  String? _lastChlorophyll;

  // storico (per i grafici dopo)
  final List<SensorSample> _temperatureHistory = [];
  final List<SensorSample> _humidityHistory = [];
  final List<SensorSample> _chlorophyllHistory = [];

  // modello selezionato (persistente)
  String _selectedModelKey = 'model1'; // default prima apertura

  @override
  void initState() {
    super.initState();
    _loadSelectedModelKey();

    // Connessione MQTT
    mqttService.connect();

    mqttService.connectionState.listen((state) {
      setState(() => _connectionState = state);
    });

    mqttService.temperatureStream.listen((v) {
      setState(() {
        _lastTemperature = v;
        _addSample(_temperatureHistory, v);
      });
    });
    mqttService.humidityStream.listen((v) {
      setState(() {
        _lastHumidity = v;
        _addSample(_humidityHistory, v);
      });
    });
    mqttService.chlorophyllStream.listen((v) {
      setState(() {
        _lastChlorophyll = v;
        _addSample(_chlorophyllHistory, v);
      });
    });
  }

  Future<void> _loadSelectedModelKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedModelKey = prefs.getString(_kSelectedModelKey) ?? 'model1';
    });
  }

  Future<void> _saveSelectedModelKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedModelKey, key);
    setState(() {
      _selectedModelKey = key;
    });
  }

  void _addSample(List<SensorSample> list, String rawValue) {
    final cleaned =
    rawValue.replaceAll(RegExp('[^0-9,.-]'), '').replaceAll(',', '.');
    final value = double.tryParse(cleaned);
    if (value == null) return;
    final now = DateTime.now();
    list.add(SensorSample(now, value));
    final cutoff = now.subtract(const Duration(hours: 24));
    list.removeWhere((s) => s.time.isBefore(cutoff));
  }

  String get _connectionLabel {
    switch (_connectionState) {
      case MqttConnectionState.connected:
        return 'CONNECTED';
      case MqttConnectionState.connecting:
        return 'CONNECTING...';
      case MqttConnectionState.disconnected:
        return 'DISCONNECTED';
      case MqttConnectionState.disconnecting:
        return 'DISCONNECTING...';
      case MqttConnectionState.faulted:
        return 'CONNECTION ERROR';
      default:
        return _connectionState.toString();
    }
  }

  Color get _connectionColor {
    switch (_connectionState) {
      case MqttConnectionState.connected:
        return Colors.green;
      case MqttConnectionState.faulted:
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  void _onMenuSelected(String value) async {
    switch (value) {
      case 'profile':
        final result = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => ProfilePage(initialModelKey: _selectedModelKey),
          ),
        );
        if (result != null && result != _selectedModelKey) {
          await _saveSelectedModelKey(result);
        }
        break;
      case 'commands':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CommandsPage()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF09140e),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PLANTFORMIO',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              _connectionLabel,
              style: TextStyle(
                fontSize: 12,
                color: _connectionColor,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: Colors.white),
            onSelected: _onMenuSelected,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'profile', child: Text('Profilo')),
              PopupMenuItem(value: 'commands', child: Text('Comandi')),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ===== CARD MODELLO 3D =====
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: PlantModel3D(modelKey: _selectedModelKey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'unknown', // lo collegheremo al profilo dopo
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ===== CARD SENSORI (grafici li aggiungiamo dopo) =====
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sensorRow('TEMPERATURE', '°C', _lastTemperature),
                    const SizedBox(height: 8),
                    _sensorRow('HUMIDITY', '%', _lastHumidity),
                    const SizedBox(height: 8),
                    _sensorRow('CHLOROPHYLL', '%', _lastChlorophyll),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sensorRow(String label, String unit, String? value) {
    String display() {
      if (value == null) return '--';
      final cleaned =
      value.replaceAll(RegExp('[^0-9,.-]'), '').replaceAll(',', '.');
      final v = double.tryParse(cleaned);
      return v == null ? value : '${v.toStringAsFixed(1)}$unit';
    }

    return SizedBox(
      height: 90,
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis, // evita il ritorno a capo
                  style: const TextStyle(
                    fontSize: 12,                  // <- più piccolo
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,            // un filo meno “largo”
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  display(),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                alignment: Alignment.center,
                color: Colors.black.withOpacity(0.25),
                child: const Text(
                  'No data',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//
// === WIDGET MODEL 3D (sceglie file in assets/models/) ===
//   model1 -> assets/models/plant_clean2.obj
//   model2 -> assets/models/plant_clean.obj
//
class PlantModel3D extends StatefulWidget {
  final String modelKey; // 'model1' | 'model2'
  const PlantModel3D({super.key, required this.modelKey});

  @override
  State<PlantModel3D> createState() => _PlantModel3DState();
}

class _PlantModel3DState extends State<PlantModel3D>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Object? _plant;
  Scene? _scene;

  String _objPathFor(String key) {
    return key == 'model1'
        ? 'assets/models/plant_clean2.obj'
        : 'assets/models/plant_clean.obj';
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )
      ..addListener(_onTick)
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant PlantModel3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modelKey != widget.modelKey) {
      _reloadModel();
    }
  }

  void _onTick() {
    if (_plant == null || _scene == null) return;
    final angle = _controller.value * 360.0;
    _plant!.rotation.setValues(0, angle, 0); // rotazione orizzontale
    _plant!.updateTransform();
    _scene!.update();
  }

  Future<void> _reloadModel() async {
    if (_scene == null) return;
    if (_plant != null) {
      _scene!.world.remove(_plant!);
      _plant = null;
    }
    final objPath = _objPathFor(widget.modelKey);
    _plant = Object(fileName: objPath);
    _plant!.scale.setValues(6.0, 6.0, 6.0);      // scala richiesta
    _plant!.position.setValues(0, -0.7, 0);
    _scene!.world.add(_plant!);
    _plant!.updateTransform();
    _scene!.update();
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final objPath = _objPathFor(widget.modelKey);
    return Cube(
      interactive: false,
      onSceneCreated: (Scene scene) {
        _scene = scene;

        _plant = Object(fileName: objPath);
        _plant!.scale.setValues(6.0, 6.0, 6.0);  // scala richiesta
        _plant!.position.setValues(0, -0.7, 0);

        scene.world.add(_plant!);

        // luce + camera
        scene.light.position.setFrom(Vector3(0, 3, 4));
        scene.camera.position.setFrom(Vector3(0, 1.8, 3.5));
        scene.camera.target.setFrom(Vector3(0, 0.5, 0));
        scene.camera.zoom = 1;

        _plant!.updateTransform();
        scene.update();
      },
    );
  }
}

//
// Profilo: selezione model1 / model2 (salvata al ritorno)
//
class ProfilePage extends StatefulWidget {
  final String initialModelKey;
  const ProfilePage({super.key, required this.initialModelKey});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late String _modelKey;

  @override
  void initState() {
    super.initState();
    _modelKey = widget.initialModelKey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profilo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Modello 3D',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _modelKey,                 // <-- importante: mostra il valore selezionato
              isExpanded: true,                 // evita tagli del testo
              style: const TextStyle(color: Colors.white),  // testo visibile sul tema scuro
              dropdownColor: const Color(0xFF10251a),
              items: const [
                DropdownMenuItem(value: 'model1', child: Text('Model 1')),
                DropdownMenuItem(value: 'model2', child: Text('Model 2')),
              ],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Seleziona modello', // etichetta sopra
                hintText: 'Scegli un modello',   // hint se fosse null (non succede)
              ),
              onChanged: (v) => setState(() => _modelKey = v ?? 'model1'),
              // (opzionale) forza lo stile del testo anche nella “chip” chiusa
              selectedItemBuilder: (context) => const [
                Align(alignment: Alignment.centerLeft, child: Text('Model 1', style: TextStyle(color: Colors.white))),
                Align(alignment: Alignment.centerLeft, child: Text('Model 2', style: TextStyle(color: Colors.white))),
              ],
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop<String>(_modelKey),
                child: const Text('Salva'),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Nota: al riavvio l\'app manterrà il modello scelto.',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

//
// Comandi (placeholder)
//
class CommandsPage extends StatelessWidget {
  const CommandsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comandi')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Qui in futuro aggiungeremo comandi preimpostati '
                'da inviare automaticamente su "esp32/comandi".',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
