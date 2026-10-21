import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/device_toggle.dart';
import '../../models/device.dart';
import '../../core/constants/app_constants.dart';
import '../../repositories/api_device_repository.dart';
import '../auth/auth_provider.dart';

class LabControlScreen extends StatefulWidget {
  const LabControlScreen({super.key});

  @override
  State<LabControlScreen> createState() => _LabControlScreenState();
}

class _LabControlScreenState extends State<LabControlScreen> {
  final ApiDeviceRepository _repo = ApiDeviceRepository();
  List<Device> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    try {
      final devices = await _repo.getDevices();
      if (mounted) {
        setState(() {
          _devices = devices;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, List<Device>> _groupDevicesByLab() {
    final Map<String, List<Device>> grouped = {};
    for (var d in _devices) {
      // Only fans and lights per specification
      final t = d.type.toLowerCase();
      final n = d.name.toLowerCase();
      if (t.contains('fan') || t.contains('light') || n.contains('fan') || n.contains('light')) {
        grouped.putIfAbsent(d.location, () => []).add(d);
      }
    }
    return grouped;
  }

  Future<void> _toggleDevice(Device device, bool newValue) async {
    final previousValue = device.isOn;
    final currentUserId = context.read<AuthProvider>().currentUser?.id;

    // 1. Optimistic UI update (instant UI animation)
    setState(() {
      final index = _devices.indexWhere((d) => d.id == device.id);
      if (index != -1) {
        _devices[index] = Device(
          id: device.id,
          name: device.name,
          type: device.type,
          location: device.location,
          isOn: newValue,
          status: device.status,
          lastUpdated: DateTime.now(),
        );
      }
    });

    // 2. Asynchronous API sync + audit logging in device_logs
    final success = await _repo.toggleDevice(
      device.id, 
      newValue,
      userId: currentUserId,
      oldState: previousValue ? 'ON' : 'OFF',
    );

    if (!success) {
      // 3. Rollback on failure with snackbar alert
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update ${device.name}. Reverting state.'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {
          final index = _devices.indexWhere((d) => d.id == device.id);
          if (index != -1) {
            _devices[index] = Device(
              id: device.id,
              name: device.name,
              type: device.type,
              location: device.location,
              isOn: previousValue,
              status: device.status,
              lastUpdated: DateTime.now(),
            );
          }
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${device.name} turned ${newValue ? 'ON' : 'OFF'} (Logged in audit trail)'),
            backgroundColor: newValue ? Colors.green.shade700 : Colors.blueGrey.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  IconData _getDeviceIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('fan')) return Icons.mode_fan_off;
    return Icons.lightbulb;
  }

  Color _getDeviceColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('fan')) return Colors.cyan;
    return Colors.amber;
  }

  @override
  Widget build(BuildContext context) {
    final labs = _groupDevicesByLab();
    final labNames = labs.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lab Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sync Devices',
            onPressed: _loadDevices,
          ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadDevices,
            child: labNames.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 100),
                    Center(
                      child: Text(
                        'No active labs configured.\nAdmin can create labs via More -> Manage Labs.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  itemCount: labNames.length,
                  itemBuilder: (context, index) {
                    final labName = labNames[index];
                    final devices = labs[labName]!;
                    
                    // Check actual hardware status from device statuses
                    final bool isHardwareOnline = devices.any((d) => d.status == DeviceStatus.online);
                    final Color statusColor = isHardwareOnline ? Colors.greenAccent.shade400 : Colors.redAccent.shade200;
                    final String statusText = isHardwareOnline ? 'Hardware Online' : 'Hardware Offline';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 24.0),
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            color: Theme.of(context).colorScheme.primaryContainer,
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.science, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      labName,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: statusColor.withValues(alpha: 0.6), width: 1.2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.25),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: statusColor.withValues(alpha: 0.8),
                                              blurRadius: 6,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        statusText,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: devices.map((device) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: DeviceToggle(
                                    name: device.name,
                                    icon: _getDeviceIcon(device.type),
                                    isSwitchedOn: device.isOn,
                                    activeColor: _getDeviceColor(device.type),
                                    onChanged: (value) => _toggleDevice(device, value),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          ),
    );
  }
}
