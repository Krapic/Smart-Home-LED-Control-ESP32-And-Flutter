import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BleService extends ChangeNotifier {
  // BLE UUIDs - moraju odgovarati ESP32
  static const String serviceUuid = "12345678-1234-1234-1234-123456789abc";
  static const String charWifiSsidUuid = "12345678-1234-1234-1234-123456789ab1";
  static const String charWifiPassUuid = "12345678-1234-1234-1234-123456789ab2";
  static const String charMqttBrokerUuid = "12345678-1234-1234-1234-123456789ab3";
  static const String charMqttPortUuid = "12345678-1234-1234-1234-123456789ab4";
  static const String charDeviceIdUuid = "12345678-1234-1234-1234-123456789ab5";
  static const String charStatusUuid = "12345678-1234-1234-1234-123456789ab6";
  static const String charCommandUuid = "12345678-1234-1234-1234-123456789ab7";

  // Stanje
  bool _isScanning = false;
  bool _isConnected = false;
  bool _isConnecting = false;
  String _statusMessage = '';
  List<ScanResult> _scanResults = [];
  BluetoothDevice? _connectedDevice;
  Map<String, BluetoothCharacteristic> _characteristics = {};

  // Getters
  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String get statusMessage => _statusMessage;
  List<ScanResult> get scanResults => _scanResults;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  // Device info iz ESP32
  String _deviceId = '';
  String _currentSsid = '';
  String _currentBroker = '';
  bool _wifiConnected = false;
  bool _mqttConnected = false;
  String _deviceIp = '';

  String get deviceId => _deviceId;
  String get currentSsid => _currentSsid;
  String get currentBroker => _currentBroker;
  bool get wifiConnected => _wifiConnected;
  bool get mqttConnected => _mqttConnected;
  String get deviceIp => _deviceIp;

  StreamSubscription? _statusSubscription;

  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return statuses.values.every(
      (status) => status == PermissionStatus.granted,
    );
  }

  Future<void> startScan() async {
    if (_isScanning) return;

    bool permissionsGranted = await requestPermissions();
    if (!permissionsGranted) {
      _statusMessage = 'Potrebne su Bluetooth i lokacijske dozvole';
      notifyListeners();
      return;
    }

    // Provjeri je li Bluetooth uključen
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      _statusMessage = 'Molimo uključite Bluetooth';
      notifyListeners();
      return;
    }

    _isScanning = true;
    _scanResults = [];
    _statusMessage = 'Tražim uređaje...';
    notifyListeners();

    // Slušaj rezultate skeniranja
    FlutterBluePlus.scanResults.listen((results) {
      _scanResults = results.where((r) {
        // Filtriraj samo SmartLED uređaje
        return r.device.platformName.startsWith('SmartLED-') ||
            r.advertisementData.serviceUuids.any(
              (uuid) => uuid.toString().toLowerCase() == serviceUuid,
            );
      }).toList();
      notifyListeners();
    });

    // Pokreni skeniranje
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 10),
      androidUsesFineLocation: true,
    );

    _isScanning = false;
    _statusMessage = _scanResults.isEmpty
        ? 'Nisu pronađeni uređaji'
        : 'Pronađeno ${_scanResults.length} uređaja';
    notifyListeners();
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _isScanning = false;
    notifyListeners();
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    if (_isConnecting) return false;

    _isConnecting = true;
    _statusMessage = 'Spajam se na ${device.platformName}...';
    notifyListeners();

    try {
      await device.connect(timeout: const Duration(seconds: 15));

      _connectedDevice = device;
      _isConnected = true;
      _statusMessage = 'Spojeno! Učitavam servise...';
      notifyListeners();

      // Discover services
      List<BluetoothService> services = await device.discoverServices();

      // Nađi naš servis
      BluetoothService? ourService;
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUuid) {
          ourService = service;
          break;
        }
      }

      if (ourService == null) {
        throw Exception('Servis nije pronađen');
      }

      // Mapiraj karakteristike
      for (var char in ourService.characteristics) {
        String uuid = char.uuid.toString().toLowerCase();
        _characteristics[uuid] = char;
      }

      // Pročitaj trenutne vrijednosti
      await _readCurrentConfig();

      // Pretplati se na status notifikacije
      await _subscribeToStatus();

      _statusMessage = 'Spremno za konfiguraciju';
      _isConnecting = false;
      notifyListeners();

      // Slušaj disconnect
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnect();
        }
      });

      return true;
    } catch (e) {
      _statusMessage = 'Greška: ${e.toString()}';
      _isConnecting = false;
      _isConnected = false;
      _connectedDevice = null;
      notifyListeners();
      return false;
    }
  }

  Future<void> _readCurrentConfig() async {
    try {
      // Device ID
      var char = _characteristics[charDeviceIdUuid];
      if (char != null) {
        var value = await char.read();
        _deviceId = utf8.decode(value);
      }

      // Current SSID
      char = _characteristics[charWifiSsidUuid];
      if (char != null) {
        var value = await char.read();
        _currentSsid = utf8.decode(value);
      }

      // MQTT Broker
      char = _characteristics[charMqttBrokerUuid];
      if (char != null) {
        var value = await char.read();
        _currentBroker = utf8.decode(value);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Greška pri čitanju konfiguracije: $e');
    }
  }

  Future<void> _subscribeToStatus() async {
    var statusChar = _characteristics[charStatusUuid];
    if (statusChar != null) {
      await statusChar.setNotifyValue(true);
      _statusSubscription = statusChar.onValueReceived.listen((value) {
        _handleStatusUpdate(utf8.decode(value));
      });
    }
  }

  void _handleStatusUpdate(String status) {
    debugPrint('Status update: $status');

    if (status.startsWith('{')) {
      // JSON status
      try {
        Map<String, dynamic> json = jsonDecode(status);
        _wifiConnected = json['wifi_connected'] ?? false;
        _mqttConnected = json['mqtt_connected'] ?? false;
        _currentSsid = json['wifi_ssid'] ?? '';
        _currentBroker = json['mqtt_broker'] ?? '';
        _deviceId = json['device_id'] ?? '';
        _deviceIp = json['ip'] ?? '';
        _statusMessage = _wifiConnected
            ? 'WiFi spojen: $_deviceIp'
            : 'WiFi nije spojen';
      } catch (e) {
        debugPrint('JSON parse error: $e');
      }
    } else {
      // Obična poruka
      _statusMessage = status;
    }
    notifyListeners();
  }

  void _handleDisconnect() {
    _isConnected = false;
    _connectedDevice = null;
    _characteristics.clear();
    _statusSubscription?.cancel();
    _statusMessage = 'Veza prekinuta';
    _wifiConnected = false;
    _mqttConnected = false;
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _statusSubscription?.cancel();
    await _connectedDevice?.disconnect();
    _handleDisconnect();
  }

  Future<bool> sendWifiCredentials(String ssid, String password) async {
    if (!_isConnected) return false;

    try {
      // Pošalji SSID
      var ssidChar = _characteristics[charWifiSsidUuid];
      if (ssidChar != null) {
        await ssidChar.write(utf8.encode(ssid), withoutResponse: false);
      }

      // Pošalji password
      var passChar = _characteristics[charWifiPassUuid];
      if (passChar != null) {
        await passChar.write(utf8.encode(password), withoutResponse: false);
      }

      _statusMessage = 'WiFi podaci poslani';
      notifyListeners();
      return true;
    } catch (e) {
      _statusMessage = 'Greška: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendMqttConfig(String broker, int port) async {
    if (!_isConnected) return false;

    try {
      // Pošalji broker
      var brokerChar = _characteristics[charMqttBrokerUuid];
      if (brokerChar != null) {
        await brokerChar.write(utf8.encode(broker), withoutResponse: false);
      }

      // Pošalji port
      var portChar = _characteristics[charMqttPortUuid];
      if (portChar != null) {
        await portChar.write(
          utf8.encode(port.toString()),
          withoutResponse: false,
        );
      }

      _statusMessage = 'MQTT podaci poslani';
      notifyListeners();
      return true;
    } catch (e) {
      _statusMessage = 'Greška: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendCommand(String command) async {
    if (!_isConnected) return false;

    try {
      var cmdChar = _characteristics[charCommandUuid];
      if (cmdChar != null) {
        await cmdChar.write(utf8.encode(command), withoutResponse: false);
        _statusMessage = 'Naredba poslana: $command';
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _statusMessage = 'Greška: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<void> saveAndConnect() async {
    await sendCommand('CONNECT');
  }

  Future<void> requestStatus() async {
    await sendCommand('STATUS');
  }

  Future<void> resetDevice() async {
    await sendCommand('RESET');
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    disconnect();
    super.dispose();
  }
}
