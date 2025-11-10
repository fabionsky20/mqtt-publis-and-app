// lib/main.dart
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'mqtt_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MQTT Sensor App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const MqttPage(),
    );
  }
}

class MqttPage extends StatefulWidget {
  const MqttPage({super.key});

  @override
  State<MqttPage> createState() => _MqttPageState();
}

class _MqttPageState extends State<MqttPage> {
  late MqttService _mqttService;
  final List<String> _messages = [];

  // stato locale della connessione
  MqttConnectionState _connectionState = MqttConnectionState.disconnected;
  String _debugStatus = 'Non ancora connesso';

  // topic
  static const String sensorTopic = 'esp32/sensori';

  @override
  void initState() {
    super.initState();

    _mqttService = MqttService(topic: sensorTopic);

    // ascolta i cambiamenti di stato della connessione
    _mqttService.connectionState.listen((state) {
      setState(() {
        _connectionState = state;
        _debugStatus = 'Stato stream: $state';
      });
    });

    // ascolta i messaggi ricevuti
    _mqttService.messages.listen((msg) {
      setState(() {
        _messages.insert(0, msg);
      });
    });
  }

  @override
  void dispose() {
    _mqttService.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _debugStatus = 'Tentativo di connessione...';
    });
    await _mqttService.connect();

    // forziamo un refresh
    setState(() {
      _debugStatus += '\nDopo connect(): ${_connectionState.toString()}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = _connectionState == MqttConnectionState.connected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MQTT Sensor Viewer'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: const Text('Stato connessione'),
            subtitle: Text(isConnected ? 'Connesso' : 'Disconnesso'),
            trailing: ElevatedButton(
              onPressed: isConnected ? null : _connect,
              child: const Text('Connetti'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Debug: $_debugStatus',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Topic sottoscritto:\n$sensorTopic',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _messages.isEmpty
                ? const Center(
              child: Text(
                'Nessun messaggio ricevuto.\n'
                    'Quando l’ESP32 pubblica sul topic, li vedrai qui.',
                textAlign: TextAlign.center,
              ),
            )
                : ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return ListTile(
                  leading: const Icon(Icons.sensors),
                  title: Text(msg),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
