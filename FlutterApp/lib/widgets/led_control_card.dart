import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mqtt_service.dart';

class LedControlCard extends StatefulWidget {
  const LedControlCard({super.key});

  @override
  State<LedControlCard> createState() => _LedControlCardState();
}

class _LedControlCardState extends State<LedControlCard> {
  @override
  Widget build(BuildContext context) {
    return Consumer<MqttService>(
      builder: (context, mqtt, _) {
        final isAuto = mqtt.mode == 'auto';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Mode selector
                Row(
                  children: [
                    Expanded(
                      child: _ModeButton(
                        label: 'Automatski',
                        icon: Icons.auto_mode,
                        isSelected: isAuto,
                        onPressed: () => mqtt.setAutoMode(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ModeButton(
                        label: 'Ručni',
                        icon: Icons.touch_app,
                        isSelected: !isAuto,
                        onPressed: () => mqtt.setMode('manual'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Auto mode info
                if (isAuto)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[300], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'LED se automatski pali na pokret u mraku (10s)',
                            style: TextStyle(color: Colors.blue[300], fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // LED kontrole
                Row(
                  children: [
                    Expanded(
                      child: _LedControl(
                        label: 'LED 1',
                        isOn: mqtt.led1State,
                        brightness: mqtt.led1Brightness,
                        enabled: !isAuto,
                        onToggle: () => mqtt.setLed1State(!mqtt.led1State),
                        onBrightnessChanged: (v) => mqtt.setLed1Brightness(v.round()),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _LedControl(
                        label: 'LED 2',
                        isOn: mqtt.led2State,
                        brightness: mqtt.led2Brightness,
                        enabled: !isAuto,
                        onToggle: () => mqtt.setLed2State(!mqtt.led2State),
                        onBrightnessChanged: (v) => mqtt.setLed2Brightness(v.round()),
                      ),
                    ),
                  ],
                ),

                // Quick actions za manual mode
                if (!isAuto) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  Text(
                    'Brze akcije (obje LED)',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _QuickButton(
                        label: 'Ugasi',
                        icon: Icons.power_settings_new,
                        color: Colors.red,
                        onPressed: () => mqtt.turnOffManual(),
                      ),
                      _QuickButton(
                        label: '25%',
                        icon: Icons.brightness_low,
                        color: Colors.orange,
                        onPressed: () => mqtt.turnOnManual(64),
                      ),
                      _QuickButton(
                        label: '50%',
                        icon: Icons.brightness_medium,
                        color: Colors.amber,
                        onPressed: () => mqtt.turnOnManual(128),
                      ),
                      _QuickButton(
                        label: '100%',
                        icon: Icons.brightness_high,
                        color: Colors.yellow,
                        onPressed: () => mqtt.turnOnManual(255),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LedControl extends StatefulWidget {
  final String label;
  final bool isOn;
  final int brightness;
  final bool enabled;
  final VoidCallback onToggle;
  final ValueChanged<double> onBrightnessChanged;

  const _LedControl({
    required this.label,
    required this.isOn,
    required this.brightness,
    required this.enabled,
    required this.onToggle,
    required this.onBrightnessChanged,
  });

  @override
  State<_LedControl> createState() => _LedControlState();
}

class _LedControlState extends State<_LedControl>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  double _localBrightness = 255;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _localBrightness = widget.brightness.toDouble();
  }

  @override
  void didUpdateWidget(covariant _LedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging) {
      _localBrightness = widget.brightness.toDouble();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = _isDragging ? _localBrightness : widget.brightness.toDouble();

    return Column(
      children: [
        // Label
        Text(
          widget.label,
          style: TextStyle(
            color: Colors.grey[400],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),

        // Bulb button
        GestureDetector(
          onTap: widget.enabled ? widget.onToggle : null,
          child: AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isOn
                      ? Color.lerp(
                          const Color(0xFFFFD54F),
                          const Color(0xFFFFF176),
                          _glowController.value,
                        )
                      : Colors.grey[800],
                  boxShadow: widget.isOn
                      ? [
                          BoxShadow(
                            color: Colors.amber.withOpacity(
                              0.3 + (_glowController.value * 0.2),
                            ),
                            blurRadius: 20 + (_glowController.value * 15),
                            spreadRadius: 3 + (_glowController.value * 5),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  widget.isOn ? Icons.lightbulb : Icons.lightbulb_outline,
                  size: 40,
                  color: widget.isOn
                      ? Colors.orange[900]
                      : (widget.enabled ? Colors.grey[600] : Colors.grey[700]),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        // Status
        Text(
          widget.isOn ? 'ON' : 'OFF',
          style: TextStyle(
            color: widget.isOn ? Colors.amber : Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),

        const SizedBox(height: 8),

        // Brightness slider
        if (widget.enabled) ...[
          SizedBox(
            height: 100,
            child: RotatedBox(
              quarterTurns: -1,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 8,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                ),
                child: Slider(
                  value: brightness,
                  min: 0,
                  max: 255,
                  onChanged: (value) {
                    setState(() {
                      _isDragging = true;
                      _localBrightness = value;
                    });
                  },
                  onChangeEnd: (value) {
                    setState(() => _isDragging = false);
                    widget.onBrightnessChanged(value);
                  },
                ),
              ),
            ),
          ),
          Text(
            '${brightness.round()}',
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Auto',
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
          ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: isSelected ? Colors.white : Colors.grey,
        backgroundColor:
            isSelected ? Theme.of(context).colorScheme.primary : null,
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[700]!,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _QuickButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
