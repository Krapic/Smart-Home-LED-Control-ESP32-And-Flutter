import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MqttService extends ChangeNotifier {
  MqttServerClient? _client;

  bool _isConnected = false;
  bool _isConnecting = false;
  String _statusMessage = '';
  String _broker = '';
  int _port = 1883;
  String _deviceId = '';

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String get statusMessage => _statusMessage;
  String get broker => _broker;
  int get port => _port;
  String get deviceId => _deviceId;

  // Sensor data
  double _lux = 0;
  double _temperature = 0;
  double _humidity = 0;
  double _pressure = 0;
  bool _motion = false;
  String _mode = 'auto';

  // LED1 state
  bool _led1State = false;
  int _led1Brightness = 255;

  // LED2 state
  bool _led2State = false;
  int _led2Brightness = 255;

  double get lux => _lux;
  double get temperature => _temperature;
  double get humidity => _humidity;
  double get pressure => _pressure;
  bool get motion => _motion;
  String get mode => _mode;

  // LED1 getters
  bool get led1State => _led1State;
  int get led1Brightness => _led1Brightness;

  // LED2 getters
  bool get led2State => _led2State;
  int get led2Brightness => _led2Brightness;

  // Backward compatibility
  bool get ledState => _led1State || _led2State;
  int get ledBrightness => (_led1Brightness + _led2Brightness) ~/ 2;

  // Callbacks
  Function(Map<String, dynamic>)? onSensorData;
  Function(Map<String, dynamic>)? onLedStatus;

  Future<void> loadSavedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _broker = prefs.getString('mqtt_broker') ?? '';
    _port = prefs.getInt('mqtt_port') ?? 1883;
    _deviceId = prefs.getString('device_id') ?? '';
    notifyListeners();
  }

  Future<void> saveConfig(String broker, int port, String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mqtt_broker', broker);
    await prefs.setInt('mqtt_port', port);
    await prefs.setString('device_id', deviceId);
    _broker = broker;
    _port = port;
    _deviceId = deviceId;
    notifyListeners();
  }

  Future<bool> connect({
    String? broker,
    int? port,
    String? deviceId,
  }) async {
    if (_isConnecting) return false;

    _broker = broker ?? _broker;
    _port = port ?? _port;
    _deviceId = deviceId ?? _deviceId;

    if (_broker.isEmpty || _deviceId.isEmpty) {
      _statusMessage = 'Broker i Device ID su obavezni';
      notifyListeners();
      return false;
    }

    _isConnecting = true;
    _statusMessage = 'Spajam se na $_broker...';
    notifyListeners();

    try {
      _client = MqttServerClient(_broker, '');
      _client!.port = _port;
      _client!.keepAlivePeriod = 60;
      _client!.autoReconnect = true;
      _client!.resubscribeOnAutoReconnect = true;
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onSubscribed = _onSubscribed;

      final clientId = 'flutter_${DateTime.now().millisecondsSinceEpoch}';
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .withWillQos(MqttQos.atMostOnce);

      _client!.connectionMessage = connMessage;

      await _client!.connect();

      if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
        await _subscribeToTopics();
        await saveConfig(_broker, _port, _deviceId);
        return true;
      } else {
        throw Exception('Spajanje nije uspjelo');
      }
    } catch (e) {
      _statusMessage = 'Greška: ${e.toString()}';
      _isConnected = false;
      _isConnecting = false;
      notifyListeners();
      return false;
    }
  }

  void _onConnected() {
    _isConnected = true;
    _isConnecting = false;
    _statusMessage = 'Spojeno na MQTT broker';
    notifyListeners();
  }

  void _onDisconnected() {
    _isConnected = false;
    _statusMessage = 'MQTT veza prekinuta';
    notifyListeners();
  }

  void _onSubscribed(String topic) {
    debugPrint('Pretplaćeno na: $topic');
  }

  Future<void> _subscribeToTopics() async {
    if (_client == null || !_isConnected) return;

    final sensorsTopic = 'smarthome/$_deviceId/sensors';
    final ledStatusTopic = 'smarthome/$_deviceId/led/status';

    _client!.subscribe(sensorsTopic, MqttQos.atMostOnce);
    _client!.subscribe(ledStatusTopic, MqttQos.atMostOnce);

    _client!.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (var msg in messages) {
        final payload = msg.payload as MqttPublishMessage;
        final message = MqttPublishPayload.bytesToStringAsString(
          payload.payload.message,
        );

        _handleMessage(msg.topic, message);
      }
    });
  }

  void _handleMessage(String topic, String message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;

      if (topic.endsWith('/sensors')) {
        _lux = (data['lux'] ?? 0).toDouble();
        _temperature = (data['temperature'] ?? 0).toDouble();
        _humidity = (data['humidity'] ?? 0).toDouble();
        _pressure = (data['pressure'] ?? 0).toDouble();
        _motion = data['motion'] ?? false;
        _mode = data['mode'] ?? 'auto';

        // LED1 data
        if (data['led1'] != null) {
          _led1State = data['led1']['state'] == true || data['led1']['state'] == 'on';
          _led1Brightness = data['led1']['brightness'] ?? 255;
        }

        // LED2 data
        if (data['led2'] != null) {
          _led2State = data['led2']['state'] == true || data['led2']['state'] == 'on';
          _led2Brightness = data['led2']['brightness'] ?? 255;
        }

        onSensorData?.call(data);
      } else if (topic.endsWith('/led/status')) {
        _mode = data['mode'] ?? 'auto';

        // LED1 status
        if (data['led1'] != null) {
          _led1State = data['led1']['state'] == 'on';
          _led1Brightness = data['led1']['brightness'] ?? 255;
        }

        // LED2 status
        if (data['led2'] != null) {
          _led2State = data['led2']['state'] == 'on';
          _led2Brightness = data['led2']['brightness'] ?? 255;
        }

        onLedStatus?.call(data);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Greška pri parsiranju poruke: $e');
    }
  }

  // LED1 kontrola
  void setLed1State(bool on) {
    _publishLedCommand({
      'led1': {'state': on ? 'on' : 'off'},
      'mode': 'manual',
    });
  }

  void setLed1Brightness(int brightness) {
    _publishLedCommand({
      'led1': {'brightness': brightness},
      'mode': 'manual',
    });
  }

  void setLed1(bool on, int brightness) {
    _publishLedCommand({
      'led1': {'state': on ? 'on' : 'off', 'brightness': brightness},
      'mode': 'manual',
    });
  }

  // LED2 kontrola
  void setLed2State(bool on) {
    _publishLedCommand({
      'led2': {'state': on ? 'on' : 'off'},
      'mode': 'manual',
    });
  }

  void setLed2Brightness(int brightness) {
    _publishLedCommand({
      'led2': {'brightness': brightness},
      'mode': 'manual',
    });
  }

  void setLed2(bool on, int brightness) {
    _publishLedCommand({
      'led2': {'state': on ? 'on' : 'off', 'brightness': brightness},
      'mode': 'manual',
    });
  }

  // Obje LED-ice
  void setAllLeds(bool on, int brightness) {
    _publishLedCommand({
      'led1': {'state': on ? 'on' : 'off', 'brightness': brightness},
      'led2': {'state': on ? 'on' : 'off', 'brightness': brightness},
      'mode': 'manual',
    });
  }

  void setMode(String mode) {
    _publishLedCommand({'mode': mode});
  }

  void setAutoMode() {
    _publishLedCommand({'mode': 'auto'});
  }

  // Backward compatibility
  void setLedState(bool on) {
    setAllLeds(on, 255);
  }

  void setLedBrightness(int brightness) {
    _publishLedCommand({
      'led1': {'brightness': brightness},
      'led2': {'brightness': brightness},
      'mode': 'manual',
    });
  }

  void turnOnManual(int brightness) {
    setAllLeds(true, brightness);
  }

  void turnOffManual() {
    setAllLeds(false, 0);
  }

  void _publishLedCommand(Map<String, dynamic> command) {
    if (_client == null || !_isConnected) {
      _statusMessage = 'Nije spojeno na MQTT';
      notifyListeners();
      return;
    }

    final topic = 'smarthome/$_deviceId/led/set';
    final payload = jsonEncode(command);

    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);

    _client!.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    debugPrint('Objavljeno na $topic: $payload');
  }

  void disconnect() {
    _client?.disconnect();
    _isConnected = false;
    _statusMessage = 'Odspojeno';
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
