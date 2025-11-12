import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_cube/flutter_cube.dart';

import 'mqtt_service.dart';

// Un'unica istanza di MqttService condivisa da tutta l'app
final MqttService mqttService = MqttService();

void main() {
  runApp(const PlantformioApp());
}

class PlantformioApp extends StatelessWidget {
  const PlantformioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plantformio',
      debugShowCheckedModeBanner: false, // niente targhetta rossa DEBUG
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

// Modello per un punto di storico (tempo + valore)
class SensorSample {
  final DateTime time;
  final double value;

  SensorSample(this.time, this.value);
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  MqttConnectionState _connectionState = MqttConnectionState.disconnected;

  String? _lastTemperature;
  String? _lastHumidity;
  String? _lastChlorophyll;

  final List<SensorSample> _temperatureHistory = [];
  final List<SensorSample> _humidityHistory = [];
  final List<SensorSample> _chlorophyllHistory = [];

  @override
  void initState() {
    super.initState();

    // Connessione automatica all'avvio
    mqttService.connect();

    // Stato connessione
    mqttService.connectionState.listen((state) {
      setState(() {
        _connectionState = state;
      });
    });

    // Dati sensori
    mqttService.temperatureStream.listen((value) {
      setState(() {
        _lastTemperature = value;
        _addSample(_temperatureHistory, value);
      });
    });

    mqttService.humidityStream.listen((value) {
      setState(() {
        _lastHumidity = value;
        _addSample(_humidityHistory, value);
      });
    });

    mqttService.chlorophyllStream.listen((value) {
      setState(() {
        _lastChlorophyll = value;
        _addSample(_chlorophyllHistory, value);
      });
    });
  }

  /// Aggiunge un campione allo storico e rimuove quelli più vecchi di 24h
  void _addSample(List<SensorSample> list, String rawValue) {
    final cleaned =
    rawValue.replaceAll(RegExp('[^0-9,.-]'), '').replaceAll(',', '.');
    final value = double.tryParse(cleaned);
    if (value == null) return;

    final now = DateTime.now();
    list.add(SensorSample(now, value));

    final cutoff = now.subtract(const Duration(hours: 24));
    list.removeWhere((sample) => sample.time.isBefore(cutoff));
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

  void _onMenuSelected(String value) {
    switch (value) {
      case 'profile':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfilePage()),
        );
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
      backgroundColor: const Color(0xFF0b1f16),
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
              PopupMenuItem(
                value: 'profile',
                child: Text('Profilo'),
              ),
              PopupMenuItem(
                value: 'commands',
                child: Text('Comandi'),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // ================== CARD MODELLO 3D ==================
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  children: [
                    const Expanded(
                      child: PlantModel3D(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nome pianta',
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

            // ================== CARD SENSORI + GRAFICI ==================
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SensorRow(
                      label: 'TEMPERATURE',
                      unit: '°C',
                      currentValue: _lastTemperature,
                      history: _temperatureHistory,
                    ),
                    const SizedBox(height: 8),
                    SensorRow(
                      label: 'HUMIDITY',
                      unit: '%',
                      currentValue: _lastHumidity,
                      history: _humidityHistory,
                    ),
                    const SizedBox(height: 8),
                    SensorRow(
                      label: 'CHLOROPHYLL',
                      unit: '%',
                      currentValue: _lastChlorophyll,
                      history: _chlorophyllHistory,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//
// 3D MODEL WIDGET
//
class PlantModel3D extends StatefulWidget {
  const PlantModel3D({super.key});

  @override
  State<PlantModel3D> createState() => _PlantModel3DState();
}

class _PlantModel3DState extends State<PlantModel3D>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Object? _plant;
  Scene? _scene;

  @override
  void initState() {
    super.initState();

    // Rotazione lenta: un giro ogni 40 secondi
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )
      ..addListener(_onTick)
      ..repeat();
  }

  void _onTick() {
    if (_plant == null || _scene == null) return;

    final angle = _controller.value * 360.0;

    // NESSUNA inclinazione sull'asse X, solo rotazione attorno alla Y
    _plant!.rotation.setValues(0, angle, 0);

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
    return Cube(
      interactive: false, // niente rotazione col dito, solo la nostra animazione
      onSceneCreated: (Scene scene) {
        _scene = scene;

        _plant = Object(
          fileName: 'assets/models/plant_clean.obj', // il nome che stai usando ora
        );

        // Ingrandiamo un po' il modello (gioca con questo valore se serve)
        _plant!.scale.setValues(6, 6, 6);

        // Se la base è il pivot, lo abbassiamo leggermente per centrarlo nella card
        _plant!.position.setValues(0, -0.5, 0);

        scene.world.add(_plant!);

        // Luce da davanti-alto
        scene.light.position.setFrom(Vector3(0, 3, 4));

        // Camera: leggermente dall'alto, abbastanza vicina
        scene.camera.position.setFrom(Vector3(0, 1.8, 3.5));
        scene.camera.target.setFrom(Vector3(0, 0.5, 0));

        // Zoom moderato (puoi provare 1, 2, 4, ecc. per trovare quello giusto)
        scene.camera.zoom = 1;

        _plant!.updateTransform();
        scene.update();
      },
    );
  }
}


//
// Riga singolo sensore: titolo + valore + mini grafico
//
class SensorRow extends StatelessWidget {
  final String label;
  final String unit;
  final String? currentValue;
  final List<SensorSample> history;

  const SensorRow({
    super.key,
    required this.label,
    required this.unit,
    required this.currentValue,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String displayValue() {
      if (currentValue == null) return '--';
      final cleaned =
      currentValue!.replaceAll(RegExp('[^0-9,.-]'), '').replaceAll(',', '.');
      final value = double.tryParse(cleaned);
      if (value == null) return currentValue!;
      return '${value.toStringAsFixed(1)}$unit';
    }

    return SizedBox(
      height: 90,
      child: Row(
        children: [
          // Testo a sinistra
          SizedBox(
            width: 110,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayValue(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Grafico a destra
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                color: Colors.black.withOpacity(0.25),
                child: SensorChart(history: history),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//
// Mini grafico linea con fl_chart
//
class SensorChart extends StatelessWidget {
  final List<SensorSample> history;

  const SensorChart({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.length < 2) {
      return const Center(
        child: Text(
          'No data',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 10,
          ),
        ),
      );
    }

    final spots = history.map((sample) {
      final x = sample.time.millisecondsSinceEpoch.toDouble();
      return FlSpot(x, sample.value);
    }).toList();

    final minX = spots.first.x;
    final maxX = spots.last.x;

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        lineTouchData: const LineTouchData(enabled: false),
        titlesData: const FlTitlesData(show: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}

//
// Pagina Profilo (per ora solo placeholder)
//
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilo'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Qui in futuro potrai impostare il nome della pianta, '
                'scegliere l\'immagine/modello 3D, e configurare altri dati.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

//
// Pagina Comandi (per ora solo placeholder)
//
class CommandsPage extends StatelessWidget {
  const CommandsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comandi'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Qui in futuro potremo aggiungere dei comandi preimpostati '
                'da inviare automaticamente sul topic "esp32/comandi" '
                'per comunicare con la pianta.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
