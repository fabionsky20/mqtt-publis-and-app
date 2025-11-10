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
      title: 'Plantformio MQTT',
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
  final MqttService _mqttService = MqttService();

  final TextEditingController _topicController =
  TextEditingController(text: 'esp32/comandi');
  final TextEditingController _messageController = TextEditingController();

  MqttConnectionState _connectionState = MqttConnectionState.disconnected;
  final List<String> _receivedMessages = [];

  // Ultimi valori dei tre sensori
  String? _lastTemperature;
  String? _lastHumidity;
  String? _lastChlorophyll;

  @override
  void initState() {
    super.initState();

    // Ascolta lo stato della connessione
    _mqttService.connectionState.listen((state) {
      setState(() {
        _connectionState = state;
      });
    });

    // Ascolta i messaggi ricevuti generici (tutti i topic)
    _mqttService.messages.listen((msg) {
      setState(() {
        // Inserisco in cima alla lista
        _receivedMessages.insert(0, msg);
      });
    });

    // Ascolta il topic del sensore di temperatura
    _mqttService.temperatureStream.listen((value) {
      setState(() {
        _lastTemperature = value;
      });
    });

    // Ascolta il topic del sensore di umidità
    _mqttService.humidityStream.listen((value) {
      setState(() {
        _lastHumidity = value;
      });
    });

    // Ascolta il topic del sensore di clorofilla
    _mqttService.chlorophyllStream.listen((value) {
      setState(() {
        _lastChlorophyll = value;
      });
    });
  }

  @override
  void dispose() {
    _mqttService.dispose();
    _topicController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String _connectionStateText() {
    switch (_connectionState) {
      case MqttConnectionState.connected:
        return 'Connesso';
      case MqttConnectionState.connecting:
        return 'Connessione in corso...';
      case MqttConnectionState.disconnected:
        return 'Disconnesso';
      case MqttConnectionState.disconnecting:
        return 'Disconnessione in corso...';
      case MqttConnectionState.faulted:
        return 'Errore di connessione';
      default:
        return _connectionState.toString();
    }
  }

  Future<void> _connect() async {
    await _mqttService.connect();
  }

  void _disconnect() {
    _mqttService.disconnect();
  }

  Future<void> _sendMessage() async {
    final topic = _topicController.text.trim();
    final message = _messageController.text.trim();

    if (topic.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci sia il topic che il messaggio.'),
        ),
      );
      return;
    }

    await _mqttService.publish(topic, message);

    // Pulisci il campo messaggio dopo l’invio
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _connectionState == MqttConnectionState.connected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plantformio MQTT'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // ================== STATO CONNESSIONE ==================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Stato: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _connectionStateText(),
                      style: TextStyle(
                        color: isConnected ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _connect,
                      child: const Text('Connetti'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: isConnected ? _disconnect : null,
                      child: const Text('Disconnetti'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ================== SEZIONE SENSORI ==================
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Sensori',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 8),

            Card(
              child: ListTile(
                title: const Text('Sensore Temperatura'),
                subtitle: Text(
                  _lastTemperature ?? 'Nessun dato',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            Card(
              child: ListTile(
                title: const Text('Sensore Umidità'),
                subtitle: Text(
                  _lastHumidity ?? 'Nessun dato',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            Card(
              child: ListTile(
                title: const Text('Sensore Clorofilla'),
                subtitle: Text(
                  _lastChlorophyll ?? 'Nessun dato',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ================== MESSAGGI RICEVUTI (TUTTI I TOPIC) ==================
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Messaggi ricevuti (tutti i topic)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _receivedMessages.isEmpty
                    ? const Center(
                  child: Text(
                    'Nessun messaggio ricevuto.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
                    : ListView.builder(
                  reverse: false,
                  itemCount: _receivedMessages.length,
                  itemBuilder: (context, index) {
                    final msg = _receivedMessages[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        msg,
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // ================== INVIA MESSAGGIO ==================
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Invia messaggio',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: 'Topic',
                hintText: 'es. esp32/comandi',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Messaggio',
                hintText: 'Scrivi il messaggio da inviare...',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isConnected ? _sendMessage : null,
                child: const Text('Invia'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

