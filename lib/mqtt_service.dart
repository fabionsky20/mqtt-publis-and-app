import 'dart:async';
import 'dart:io';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  // === CONFIGURAZIONE BROKER / CREDENZIALI ===
  static const String _broker =
      '086891014fd848e48a1ae719a2682a82.s1.eu.hivemq.cloud';
  static const int _port = 8883; // TLS
  static const String _clientId = 'plantformio_app'; // puoi cambiarlo
  static const String _username = 'Plantformio';
  static const String _password = 'Vasetto04';

  // Topic generici
  String defaultSubTopic = 'esp32/sensori';
  String defaultPubTopic = 'esp32/comandi';

  // Topic specifici per i sensori
  static const String temperatureTopic = 'esp32/sensori/temperatura';
  static const String humidityTopic = 'esp32/sensori/umidita';
  static const String chlorophyllTopic = 'esp32/sensori/clorofilla';

  late MqttServerClient _client;

  // Stream generale con tutti i messaggi (topic + payload)
  final StreamController<String> _messagesController =
  StreamController<String>.broadcast();

  // Stream per ciascun sensore (solo payload)
  final StreamController<String> _temperatureController =
  StreamController<String>.broadcast();
  final StreamController<String> _humidityController =
  StreamController<String>.broadcast();
  final StreamController<String> _chlorophyllController =
  StreamController<String>.broadcast();

  final StreamController<MqttConnectionState> _connectionStateController =
  StreamController<MqttConnectionState>.broadcast();

  Stream<String> get messages => _messagesController.stream;
  Stream<MqttConnectionState> get connectionState =>
      _connectionStateController.stream;

  // Stream dedicati per la UI
  Stream<String> get temperatureStream => _temperatureController.stream;
  Stream<String> get humidityStream => _humidityController.stream;
  Stream<String> get chlorophyllStream => _chlorophyllController.stream;

  MqttService() {
    _client = MqttServerClient.withPort(_broker, _clientId, _port);

    // Impostazioni di base
    _client.secure = true;
    _client.setProtocolV311();
    _client.logging(on: false);

    // TLS
    final context = SecurityContext.defaultContext;
    _client.securityContext = context;

    // Callbacks
    _client.onConnected = _onConnected;
    _client.onDisconnected = _onDisconnected;
    _client.onSubscribed = _onSubscribed;
    _client.onSubscribeFail = _onSubscribeFail;
    _client.onUnsubscribed = _onUnsubscribed;
    _client.onAutoReconnect = _onAutoReconnect;
    _client.onAutoReconnected = _onAutoReconnected;
  }

  // CONNESSIONE
  Future<void> connect() async {
    if (_client.connectionStatus?.state == MqttConnectionState.connected) {
      return;
    }

    final connMess = MqttConnectMessage()
        .withClientIdentifier(_clientId)
        .keepAliveFor(60)
        .startClean()
        .withWillQos(MqttQos.atMostOnce);

    _client.connectionMessage = connMess;

    try {
      final status = await _client.connect(_username, _password);

      if (status?.state == MqttConnectionState.connected) {
        _connectionStateController.add(status!.state);

        // Subscribe a tutti i topic che ci interessano
        _subscribeToAllTopics();

        // Ascolta i messaggi in arrivo
        _listenToUpdates();
      } else {
        _connectionStateController
            .add(_client.connectionStatus?.state ?? MqttConnectionState.faulted);
        _client.disconnect();
      }
    } catch (e) {
      _connectionStateController.add(MqttConnectionState.faulted);
      _client.disconnect();
    }
  }

  void disconnect() {
    _client.disconnect();
  }

  // SUBSCRIBE / LISTEN
  void _subscribeToTopic(String topic) {
    _client.subscribe(topic, MqttQos.atMostOnce);
  }

  void _subscribeToAllTopics() {
    // topic generico
    _subscribeToTopic(defaultSubTopic);

    // topic per i sensori
    _subscribeToTopic(temperatureTopic);
    _subscribeToTopic(humidityTopic);
    _subscribeToTopic(chlorophyllTopic);
  }

  void _listenToUpdates() {
    _client.updates?.listen(
          (List<MqttReceivedMessage<MqttMessage>> events) {
        final MqttReceivedMessage<MqttMessage> recMess = events[0];
        final MqttPublishMessage message = recMess.payload as MqttPublishMessage;

        final String payload =
        MqttPublishPayload.bytesToStringAsString(message.payload.message);

        final String topic = recMess.topic;

        // Stream generale, con dentro "topic: payload"
        _messagesController.add('$topic: $payload');

        // Smistamento sui singoli sensori in base al topic
        if (topic == temperatureTopic) {
          _temperatureController.add(payload);
        } else if (topic == humidityTopic) {
          _humidityController.add(payload);
        } else if (topic == chlorophyllTopic) {
          _chlorophyllController.add(payload);
        }
      },
    );
  }

  // PUBLISH
  Future<void> publish(String topic, String payload) async {
    // Se non è connesso, provo a connettermi
    if (_client.connectionStatus?.state != MqttConnectionState.connected) {
      await connect();
    }

    if (_client.connectionStatus?.state != MqttConnectionState.connected) {
      // Se ancora non è connesso, esco
      return;
    }

    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);

    _client.publishMessage(
      topic,
      MqttQos.atMostOnce,
      builder.payload!,
      retain: false,
    );
  }

  // CALLBACK
  void _onConnected() {
    _connectionStateController
        .add(_client.connectionStatus?.state ?? MqttConnectionState.connected);
  }

  void _onDisconnected() {
    _connectionStateController
        .add(_client.connectionStatus?.state ?? MqttConnectionState.disconnected);
  }

  void _onSubscribed(String topic) {
  }

  void _onSubscribeFail(String topic) {
  }

  void _onUnsubscribed(String? topic) {
  }

  void _onAutoReconnect() {
  }

  void _onAutoReconnected() {
    _connectionStateController
        .add(_client.connectionStatus?.state ?? MqttConnectionState.connected);
  }

  // CLEANUP
  void dispose() {
    _messagesController.close();
    _temperatureController.close();
    _humidityController.close();
    _chlorophyllController.close();
    _connectionStateController.close();
    _client.disconnect();
  }
}
