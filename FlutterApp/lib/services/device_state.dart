import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceState extends ChangeNotifier {
  String _deviceId = '';
  String _wifiSsid = '';
  String _mqttBroker = '';
  int _mqttPort = 1883;
  bool _isConfigured = false;

  String get deviceId => _deviceId;
  String get wifiSsid => _wifiSsid;
  String get mqttBroker => _mqttBroker;
  int get mqttPort => _mqttPort;
  bool get isConfigured => _isConfigured;

  Future<void> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_id') ?? '';
    _wifiSsid = prefs.getString('wifi_ssid') ?? '';
    _mqttBroker = prefs.getString('mqtt_broker') ?? '';
    _mqttPort = prefs.getInt('mqtt_port') ?? 1883;
    _isConfigured = _deviceId.isNotEmpty && _mqttBroker.isNotEmpty;
    notifyListeners();
  }

  Future<void> saveState({
    required String deviceId,
    required String wifiSsid,
    required String mqttBroker,
    required int mqttPort,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_id', deviceId);
    await prefs.setString('wifi_ssid', wifiSsid);
    await prefs.setString('mqtt_broker', mqttBroker);
    await prefs.setInt('mqtt_port', mqttPort);

    _deviceId = deviceId;
    _wifiSsid = wifiSsid;
    _mqttBroker = mqttBroker;
    _mqttPort = mqttPort;
    _isConfigured = true;
    notifyListeners();
  }

  Future<void> clearState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('device_id');
    await prefs.remove('wifi_ssid');
    await prefs.remove('mqtt_broker');
    await prefs.remove('mqtt_port');

    _deviceId = '';
    _wifiSsid = '';
    _mqttBroker = '';
    _mqttPort = 1883;
    _isConfigured = false;
    notifyListeners();
  }
}
