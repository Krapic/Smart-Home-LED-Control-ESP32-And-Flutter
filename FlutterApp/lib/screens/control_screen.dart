import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mqtt_service.dart';
import '../services/device_state.dart';
import '../widgets/sensor_card.dart';
import '../widgets/led_control_card.dart';
import 'setup_screen.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  @override
  void initState() {
    super.initState();
    _connectMqtt();
  }

  Future<void> _connectMqtt() async {
    final mqttService = context.read<MqttService>();
    final deviceState = context.read<DeviceState>();

    if (!mqttService.isConnected && deviceState.isConfigured) {
      await mqttService.connect(
        broker: deviceState.mqttBroker,
        port: deviceState.mqttPort,
        deviceId: deviceState.deviceId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Home LED'),
        actions: [
          Consumer<MqttService>(
            builder: (context, mqtt, _) {
              return IconButton(
                icon: Icon(
                  mqtt.isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: mqtt.isConnected ? Colors.green : Colors.red,
                ),
                onPressed: _showConnectionInfo,
              );
            },
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reconnect',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Ponovno spoji'),
                ),
              ),
              const PopupMenuItem(
                value: 'setup',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Novi uređaj'),
                ),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: ListTile(
                  leading: Icon(Icons.delete_forever, color: Colors.red),
                  title: Text('Resetiraj', style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
            onSelected: _handleMenuAction,
          ),
        ],
      ),
      body: Consumer<MqttService>(
        builder: (context, mqttService, _) {
          if (!mqttService.isConnected) {
            return _buildDisconnectedView(mqttService);
          }

          return RefreshIndicator(
            onRefresh: _connectMqtt,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LED Control
                  const LedControlCard(),

                  const SizedBox(height: 24),

                  // Senzori naslov
                  Row(
                    children: [
                      Icon(Icons.sensors, color: Colors.grey[400]),
                      const SizedBox(width: 8),
                      Text(
                        'Senzori',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.grey[400],
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Senzor kartice
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      SensorCard(
                        title: 'Temperatura',
                        value: '${mqttService.temperature.toStringAsFixed(1)}°C',
                        icon: Icons.thermostat,
                        color: _getTemperatureColor(mqttService.temperature),
                      ),
                      SensorCard(
                        title: 'Vlažnost',
                        value: '${mqttService.humidity.toStringAsFixed(0)}%',
                        icon: Icons.water_drop,
                        color: Colors.blue,
                      ),
                      SensorCard(
                        title: 'Osvjetljenje',
                        value: '${mqttService.lux.toStringAsFixed(0)} lux',
                        icon: Icons.light_mode,
                        color: Colors.amber,
                      ),
                      SensorCard(
                        title: 'Tlak',
                        value: '${mqttService.pressure.toStringAsFixed(0)} hPa',
                        icon: Icons.speed,
                        color: Colors.purple,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Motion indikator
                  Card(
                    child: ListTile(
                      leading: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: mqttService.motion ? Colors.green : Colors.grey,
                          boxShadow: mqttService.motion
                              ? [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      title: const Text('Detekcija pokreta'),
                      subtitle: Text(
                        mqttService.motion
                            ? 'Pokret detektiran'
                            : 'Nema pokreta',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDisconnectedView(MqttService mqttService) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 80,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 24),
            Text(
              'Nije spojeno na MQTT',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              mqttService.statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _connectMqtt,
              icon: mqttService.isConnecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(mqttService.isConnecting ? 'Spajam...' : 'Pokušaj ponovno'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTemperatureColor(double temp) {
    if (temp < 18) return Colors.blue;
    if (temp < 24) return Colors.green;
    if (temp < 28) return Colors.orange;
    return Colors.red;
  }

  void _showConnectionInfo() {
    final mqttService = context.read<MqttService>();
    final deviceState = context.read<DeviceState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Status veze'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('MQTT Broker', deviceState.mqttBroker),
            _infoRow('Port', deviceState.mqttPort.toString()),
            _infoRow('Device ID', deviceState.deviceId),
            _infoRow(
              'Status',
              mqttService.isConnected ? 'Spojeno' : 'Nije spojeno',
            ),
            _infoRow('Način rada', mqttService.mode == 'auto' ? 'Automatski' : 'Ručni'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zatvori'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) async {
    switch (action) {
      case 'reconnect':
        await _connectMqtt();
        break;
      case 'setup':
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SetupScreen()),
          );
        }
        break;
      case 'reset':
        _showResetDialog();
        break;
    }
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resetiraj postavke?'),
        content: const Text(
          'Ovo će izbrisati sve spremljene postavke. '
          'Morat ćete ponovo postaviti uređaj.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Odustani'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final deviceState = context.read<DeviceState>();
              final mqttService = context.read<MqttService>();
              mqttService.disconnect();
              await deviceState.clearState();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Resetiraj'),
          ),
        ],
      ),
    );
  }
}
