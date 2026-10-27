import 'package:flutter/material.dart';
import '../../../../core/services/device_sync_service.dart';
import '../../../../core/theme/app_pallete.dart';

/// Home-screen switch: when on, this device plays what your other devices play, in step.
class DeviceSyncCard extends StatefulWidget {
  const DeviceSyncCard({super.key});

  @override
  State<DeviceSyncCard> createState() => _DeviceSyncCardState();
}

class _DeviceSyncCardState extends State<DeviceSyncCard> {
  final DeviceSyncService _service = DeviceSyncService();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChanged);
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _toggle(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    final String? error = await _service.setEnabled(value);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool on = _service.enabled;
    final String subtitle = !on
        ? 'Play on one device, hear it on another'
        : (_service.connected
            ? 'On: song, pause and seek match your other devices'
            : 'On: reconnecting...');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Pallete.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: on ? Pallete.gradient2.withAlpha(150) : Pallete.borderColor.withAlpha(100),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.devices_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sync my devices',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Pallete.whiteColor,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Pallete.subtitleText, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(
            value: on,
            activeTrackColor: Pallete.gradient2,
            onChanged: _busy ? null : _toggle,
          ),
        ],
      ),
    );
  }
}
