import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/device_state.dart';
import '../services/mqtt_service.dart';
import 'setup_screen.dart';
import 'control_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    final deviceState = context.read<DeviceState>();
    final mqttService = context.read<MqttService>();

    await deviceState.loadState();
    await mqttService.loadSavedConfig();

    if (deviceState.isConfigured) {
      // Automatski se spoji na MQTT
      await mqttService.connect(
        broker: deviceState.mqttBroker,
        port: deviceState.mqttPort,
        deviceId: deviceState.deviceId,
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Učitavam...'),
            ],
          ),
        ),
      );
    }

    return Consumer<DeviceState>(
      builder: (context, deviceState, _) {
        if (deviceState.isConfigured) {
          return const ControlScreen();
        } else {
          return const SetupScreen();
        }
      },
    );
  }
}
