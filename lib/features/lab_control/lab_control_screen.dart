import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/device_toggle.dart';
import '../../models/device.dart';
import '../../core/constants/app_constants.dart';
import '../../repositories/api_device_repository.dart';
import '../../services/energy_tracking_service.dart';
import '../auth/auth_provider.dart';

class LabControlScreen extends StatefulWidget {
  const LabControlScreen({super.key});

  @override
  State<LabControlScreen> createState() => _LabControlScreenState();
}

class _LabControlScreenState extends State<LabControlScreen> {
  final ApiDeviceRepository _repo = ApiDeviceRepository();
  List<Device> _devices = [];
  TodayEnergySummary? _energySummary;
  bool _isLoading = true;
  Timer? _liveTicker;

  @override
  void initState() {
    super.initState();
    _loadDevices();

    // Auto-refresh energy counters every 10 seconds while screen is open
    _liveTicker = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _loadEnergySummary();
    });
  }

  @override
  void dispose() {
    _liveTicker?.cancel();
    super.dispose();
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
        await _loadEnergySummary();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadEnergySummary() async {
    final bool fanOn = _devices.any((d) => d.type.toLowerCase().contains('fan') && d.isOn);
    final bool lightOn = _devices.any((d) => d.type.toLowerCase().contains('light') && d.isOn);

    final summary = await EnergyTrackingService.getTodayEnergySummary(
      isFanOn: fanOn,
      isLightOn: lightOn,
    );

    if (mounted) {
      setState(() => _energySummary = summary);
    }
  }

  Map<String, List<Device>> _groupDevicesByLab() {
    final Map<String, List<Device>> grouped = {};
    for (var d in _devices) {
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

    // 1. Optimistic UI update
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

    // 2. Asynchronous API sync + energy consumption recording + device_logs
    final success = await _repo.toggleDevice(
      device.id, 
      newValue,
      deviceName: device.name,
      deviceType: device.type,
      userId: currentUserId,
      oldState: previousValue ? 'ON' : 'OFF',
    );

    await _loadEnergySummary();

    if (!success) {
      // Rollback on failure
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
        await _loadEnergySummary();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${device.name} turned ${newValue ? 'ON' : 'OFF'} • Energy recording active'),
            backgroundColor: newValue ? Colors.green.shade700 : Colors.blueGrey.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showEnergyAuditLogsModal() async {
    final logs = await EnergyTrackingService.getEnergyLogs();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.bolt_rounded, color: Colors.amber, size: 22),
                      SizedBox(width: 8),
                      Text('Energy Consumption Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  Text('${logs.length} sessions', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              const Divider(height: 20),
              Expanded(
                child: logs.isEmpty
                    ? const Center(
                        child: Text(
                          'No device on/off energy sessions recorded yet today.\nTurn a fan or LED on/off to generate energy logs.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: logs.length,
                        itemBuilder: (c, idx) {
                          final log = logs[idx];
                          final isFan = log.deviceType.toLowerCase().contains('fan');
                          final durationMins = (log.durationSeconds / 60).round();

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: (isFan ? Colors.cyan : Colors.amber).withValues(alpha: 0.15),
                                    child: Icon(
                                      isFan ? Icons.mode_fan_off : Icons.lightbulb,
                                      color: isFan ? Colors.cyan.shade700 : Colors.amber.shade800,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          log.deviceName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${DateFormat('hh:mm a').format(log.startTime)} - ${log.endTime != null ? DateFormat('hh:mm a').format(log.endTime!) : "Active"} (${durationMins > 0 ? "$durationMins mins" : "${log.durationSeconds}s"})',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                        Text(
                                          'Rated Load: ${log.ratedWatts} W',
                                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${log.energyKwh.toStringAsFixed(4)} kWh',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                                      ),
                                      Text(
                                        '~${(log.energyKwh * 1000).toStringAsFixed(1)} Wh',
                                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
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
        title: const Text('Lab Control & Energy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded),
            tooltip: 'Energy Logs',
            onPressed: _showEnergyAuditLogsModal,
          ),
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
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              children: [
                // Real-Time Energy Consumption Dashboard Card
                _buildEnergyMeterCard(),
                const SizedBox(height: 16),

                // Lab Devices Section
                if (labNames.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    alignment: Alignment.center,
                    child: const Text(
                      'No active labs configured.\nAdmin can create labs via More -> Manage Labs.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  ...labNames.map((labName) {
                    final devices = labs[labName]!;
                    final bool isHardwareOnline = devices.any((d) => d.status == DeviceStatus.online);
                    final Color statusColor = isHardwareOnline ? Colors.greenAccent.shade400 : Colors.redAccent.shade200;
                    final String statusText = isHardwareOnline ? 'Hardware Online' : 'Hardware Offline';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 20.0),
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
                  }),
              ],
            ),
          ),
    );
  }

  Widget _buildEnergyMeterCard() {
    final summary = _energySummary;
    final totalKwh = summary?.totalKwh ?? 0.0;
    final activeWatts = summary?.activeWatts ?? 0;
    final fanMins = ((summary?.fanActiveSecondsToday ?? 0) / 60).round();
    final lightMins = ((summary?.lightActiveSecondsToday ?? 0) / 60).round();
    final fanKwh = summary?.fanKwh ?? 0.0;
    final lightKwh = summary?.lightKwh ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Colors.amber, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Real-Time Energy Meter',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: activeWatts > 0 ? Colors.green.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: activeWatts > 0 ? Colors.greenAccent : Colors.grey),
                ),
                child: Text(
                  '$activeWatts W Load',
                  style: TextStyle(
                    color: activeWatts > 0 ? Colors.greenAccent : Colors.grey.shade400,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Total Energy Consumed Today (kWh)
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                totalKwh.toStringAsFixed(3),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'kWh Consumed Today',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),

          // Fan vs Light Breakdown
          Row(
            children: [
              Expanded(
                child: _buildDeviceEnergyMetric(
                  icon: Icons.mode_fan_off,
                  iconColor: Colors.cyan,
                  label: 'Exhaust Fan (75W)',
                  durationText: '$fanMins mins today',
                  kwhText: '${fanKwh.toStringAsFixed(3)} kWh',
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _buildDeviceEnergyMetric(
                    icon: Icons.lightbulb,
                    iconColor: Colors.amber,
                    label: 'Ceiling LED (40W)',
                    durationText: '$lightMins mins today',
                    kwhText: '${lightKwh.toStringAsFixed(3)} kWh',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Action button to view logs
          SizedBox(
            width: double.infinity,
            height: 36,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.history_rounded, size: 16, color: Colors.white70),
              label: const Text('View Detailed Energy Session Logs', style: TextStyle(color: Colors.white, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _showEnergyAuditLogsModal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceEnergyMetric({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String durationText,
    required String kwhText,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
              Text(kwhText, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              Text(durationText, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 9)),
            ],
          ),
        ),
      ],
    );
  }
}
