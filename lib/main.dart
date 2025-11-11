import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:fl_chart/fl_chart.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
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

  @override
  void dispose() {
    // Non chiudo mqttService qui perché è condiviso dall'app.
    super.dispose();
  }

  /// Aggiunge un campione allo storico e rimuove quelli più vecchi di 24h
  void _addSample(List<SensorSample> list, String rawValue) {
    // Provo a estrarre un double dal testo (es. "32.5°C" -> 32.5)
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
      // Per ora uno sfondo semplice; più avanti mettiamo l'immagine
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
            icon: const Icon(Icons.menu),
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
                    Expanded(
                      child: _PlantModelPlaceholder(),
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

// Placeholder per il modello 3D (per ora solo grafica)
class _PlantModelPlaceholder extends StatefulWidget {
  @override
  State<_PlantModelPlaceholder> createState() => _PlantModelPlaceholderState();
}

class _PlantModelPlaceholderState extends State<_PlantModelPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Rotazione lenta, giusto per dare l'idea
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return Transform.rotate(
          angle: _controller.value * 6.28318, // 2*pi
          child: child,
        );
      },
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
        ),
        child: Center(
          child: Icon(
            Icons.eco,
            size: 96,
            color: Colors.greenAccent.withOpacity(0.9),
          ),
        ),
      ),
    );
  }
}

// Riga singolo sensore: titolo + valore + mini grafico
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

// Mini grafico linea con fl_chart
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

// Pagina Profilo (per ora solo placeholder)
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

// Pagina Comandi (per ora solo placeholder)
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

