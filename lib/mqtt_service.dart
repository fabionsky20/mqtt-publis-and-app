// lib/mqtt_service.dart
import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  // Dati cluster HiveMQ Cloud
  static const String broker =
      '086891014fd848e48a1ae719a2682a82.s1.eu.hivemq.cloud';
  static const int port = 8883;

  static const String clientId = 'plantformio_flutter_1';
  static const String username = 'Plantformio';
  static const String password = 'Vasetto04';

  final String topic;

  late MqttServerClient _client;

  final _messageController = StreamController<String>.broadcast();
  final _connectionStateController =
  StreamController<MqttConnectionState>.broadcast();

  Stream<String> get messages => _messageController.stream;
  Stream<MqttConnectionState> get connectionState =>
      _connectionStateController.stream;

  MqttService({required this.topic}) {
    _client = MqttServerClient.withPort(broker, clientId, port);

    _client.logging(on: true);
    _client.secure = true;          // TLS
    _client.keepAlivePeriod = 30;
    _client.setProtocolV311();      // MQTT 3.1.1

    _client.onConnected = _onConnected;
    _client.onDisconnected = _onDisconnected;
    _client.onSubscribed = _onSubscribed;
    _client.onSubscribeFail = _onSubscribeFail;
    _client.onUnsubscribed = _onUnsubscribed;
    _client.pongCallback = _pong;
  }

  Future<void> connect() async {
    try {
      print('MQTT: connecting to $broker:$port ...');

      final status = await _client.connect(username, password);

      print('MQTT: connectionStatus -> ${_client.connectionStatus}');
      print('MQTT: returnCode -> ${_client.connectionStatus?.returnCode}');

      if (_client.connectionStatus?.state == MqttConnectionState.connected) {
        print('MQTT: connected!');
        _connectionStateController.add(MqttConnectionState.connected);
        _subscribe();
        _listenToMessages();
      } else {
        print('MQTT: connection failed');
        _connectionStateController.add(MqttConnectionState.disconnected);
      }
    } catch (e) {
      print('MQTT: exception -> $e');
      if (_client.connectionStatus != null) {
        print('MQTT: returnCode (after error) -> '
            '${_client.connectionStatus!.returnCode}');
      }
      _client.disconnect();
      _connectionStateController.add(MqttConnectionState.disconnected);
    }
  }

  void _subscribe() {
    print('MQTT: subscribing to $topic');
    _client.subscribe(topic, MqttQos.atLeastOnce);
  }

  void _listenToMessages() {
    _client.updates?.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMessage = c![0].payload as MqttPublishMessage;
      final payload =
      MqttPublishPayload.bytesToStringAsString(recMessage.payload.message);
      final receivedTopic = c[0].topic;
      print('MQTT: message "$payload" from topic: $receivedTopic');

      _messageController.add(payload);
    });
  }

  void disconnect() {
    _client.disconnect();
  }

  void _onConnected() {
    print('MQTT: onConnected');
    _connectionStateController.add(MqttConnectionState.connected);
  }

  void _onDisconnected() {
    print('MQTT: onDisconnected');
    _connectionStateController.add(MqttConnectionState.disconnected);
  }

  void _onSubscribed(String topic) {
    print('MQTT: subscribed to $topic');
  }

  void _onSubscribeFail(String topic) {
    print('MQTT: failed to subscribe $topic');
  }

  void _onUnsubscribed(String? topic) {
    print('MQTT: unsubscribed from $topic');
  }

  void _pong() {
    print('MQTT: ping response');
  }

  void dispose() {
    _messageController.close();
    _connectionStateController.close();
  }
}
