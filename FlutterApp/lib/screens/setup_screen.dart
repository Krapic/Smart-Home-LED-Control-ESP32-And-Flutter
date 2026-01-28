import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_service.dart';
import '../services/device_state.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _brokerController = TextEditingController();
  final _portController = TextEditingController(text: '1883');

  int _currentStep = 0;
  bool _isPasswordVisible = false;
  bool _isSending = false;

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    _brokerController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Postavljanje uređaja'),
      ),
      body: Consumer<BleService>(
        builder: (context, bleService, _) {
          return Stepper(
            currentStep: _currentStep,
            onStepContinue: () => _handleStepContinue(bleService),
            onStepCancel: () => _handleStepCancel(bleService),
            controlsBuilder: (context, details) {
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    if (_currentStep < 3)
                      ElevatedButton(
                        onPressed: details.onStepContinue,
                        child: Text(_getButtonText()),
                      ),
                    if (_currentStep > 0) ...[
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: details.onStepCancel,
                        child: const Text('Natrag'),
                      ),
                    ],
                  ],
                ),
              );
            },
            steps: [
              // Korak 1: Skeniranje
              Step(
                title: const Text('Pronađi uređaj'),
                subtitle: Text(bleService.statusMessage),
                isActive: _currentStep >= 0,
                state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                content: _buildScanStep(bleService),
              ),

              // Korak 2: WiFi kredencijali
              Step(
                title: const Text('WiFi postavke'),
                subtitle: const Text('Unesite podatke vaše WiFi mreže'),
                isActive: _currentStep >= 1,
                state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                content: _buildWifiStep(),
              ),

              // Korak 3: MQTT broker
              Step(
                title: const Text('MQTT Broker'),
                subtitle: const Text('Unesite adresu MQTT brokera'),
                isActive: _currentStep >= 2,
                state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                content: _buildMqttStep(),
              ),

              // Korak 4: Spajanje
              Step(
                title: const Text('Spajanje'),
                subtitle: Text(bleService.statusMessage),
                isActive: _currentStep >= 3,
                state: _currentStep > 3 ? StepState.complete : StepState.indexed,
                content: _buildConnectStep(bleService),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getButtonText() {
    switch (_currentStep) {
      case 0:
        return 'Skeniraj';
      case 1:
        return 'Nastavi';
      case 2:
        return 'Pošalji i spoji';
      default:
        return 'Nastavi';
    }
  }

  Widget _buildScanStep(BleService bleService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Uključite Bluetooth i približite telefon ESP32 uređaju.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        if (bleService.isScanning)
          const Center(child: CircularProgressIndicator())
        else if (bleService.scanResults.isEmpty)
          Center(
            child: Column(
              children: [
                Icon(Icons.bluetooth_searching, size: 64, color: Colors.grey[600]),
                const SizedBox(height: 8),
                const Text('Pritisnite Skeniraj za početak'),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: bleService.scanResults.length,
            itemBuilder: (context, index) {
              final result = bleService.scanResults[index];
              final isConnected = bleService.connectedDevice?.remoteId ==
                  result.device.remoteId;

              return Card(
                child: ListTile(
                  leading: Icon(
                    isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                    color: isConnected ? Colors.green : Colors.blue,
                  ),
                  title: Text(result.device.platformName),
                  subtitle: Text('RSSI: ${result.rssi} dBm'),
                  trailing: isConnected
                      ? const Chip(label: Text('Spojeno'))
                      : bleService.isConnecting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.link),
                              onPressed: () => _connectToDevice(result.device),
                            ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildWifiStep() {
    return Column(
      children: [
        TextField(
          controller: _ssidController,
          decoration: const InputDecoration(
            labelText: 'WiFi naziv (SSID)',
            prefixIcon: Icon(Icons.wifi),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          decoration: InputDecoration(
            labelText: 'WiFi lozinka',
            prefixIcon: const Icon(Icons.lock),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () {
                setState(() => _isPasswordVisible = !_isPasswordVisible);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMqttStep() {
    return Column(
      children: [
        TextField(
          controller: _brokerController,
          decoration: const InputDecoration(
            labelText: 'MQTT Broker adresa',
            hintText: 'npr. 192.168.1.100 ili broker.hivemq.com',
            prefixIcon: Icon(Icons.cloud),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _portController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'MQTT Port',
            prefixIcon: Icon(Icons.numbers),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Možete koristiti besplatni broker: broker.hivemq.com',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildConnectStep(BleService bleService) {
    return Column(
      children: [
        if (_isSending)
          const Center(child: CircularProgressIndicator())
        else ...[
          _buildStatusRow(
            'WiFi',
            bleService.wifiConnected,
            bleService.currentSsid,
          ),
          const SizedBox(height: 8),
          _buildStatusRow(
            'MQTT',
            bleService.mqttConnected,
            bleService.currentBroker,
          ),
          const SizedBox(height: 8),
          _buildStatusRow('Device ID', true, bleService.deviceId),
          if (bleService.deviceIp.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildStatusRow('IP adresa', true, bleService.deviceIp),
          ],
          const SizedBox(height: 24),
          if (bleService.wifiConnected && bleService.mqttConnected)
            ElevatedButton.icon(
              onPressed: _finishSetup,
              icon: const Icon(Icons.check),
              label: const Text('Završi postavljanje'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () => bleService.requestStatus(),
              icon: const Icon(Icons.refresh),
              label: const Text('Osvježi status'),
            ),
        ],
      ],
    );
  }

  Widget _buildStatusRow(String label, bool ok, String value) {
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.cancel,
          color: ok ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text('$label: '),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    final bleService = context.read<BleService>();
    bool success = await bleService.connectToDevice(device);
    if (success && mounted) {
      setState(() => _currentStep = 1);
    }
  }

  void _handleStepContinue(BleService bleService) async {
    switch (_currentStep) {
      case 0:
        // Skeniranje
        if (bleService.isConnected) {
          setState(() => _currentStep = 1);
        } else {
          await bleService.startScan();
        }
        break;

      case 1:
        // WiFi
        if (_ssidController.text.isEmpty) {
          _showSnackBar('Unesite WiFi SSID');
          return;
        }
        setState(() => _currentStep = 2);
        break;

      case 2:
        // MQTT i spajanje
        if (_brokerController.text.isEmpty) {
          _showSnackBar('Unesite MQTT broker adresu');
          return;
        }
        await _sendConfigAndConnect(bleService);
        break;
    }
  }

  void _handleStepCancel(BleService bleService) {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _sendConfigAndConnect(BleService bleService) async {
    setState(() => _isSending = true);

    try {
      // Pošalji WiFi
      await bleService.sendWifiCredentials(
        _ssidController.text,
        _passwordController.text,
      );

      await Future.delayed(const Duration(milliseconds: 500));

      // Pošalji MQTT
      await bleService.sendMqttConfig(
        _brokerController.text,
        int.tryParse(_portController.text) ?? 1883,
      );

      await Future.delayed(const Duration(milliseconds: 500));

      // Spremi i spoji
      await bleService.saveAndConnect();

      setState(() {
        _currentStep = 3;
        _isSending = false;
      });

      // Čekaj malo pa provjeri status
      await Future.delayed(const Duration(seconds: 5));
      await bleService.requestStatus();
    } catch (e) {
      setState(() => _isSending = false);
      _showSnackBar('Greška: ${e.toString()}');
    }
  }

  Future<void> _finishSetup() async {
    final bleService = context.read<BleService>();
    final deviceState = context.read<DeviceState>();

    await deviceState.saveState(
      deviceId: bleService.deviceId,
      wifiSsid: _ssidController.text,
      mqttBroker: _brokerController.text,
      mqttPort: int.tryParse(_portController.text) ?? 1883,
    );

    // Odspoji BLE
    await bleService.disconnect();

    if (mounted) {
      _showSnackBar('Uređaj uspješno postavljen!');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
