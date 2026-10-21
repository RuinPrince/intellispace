import '../core/api/api_client.dart';
import '../core/api/api_config.dart';
import '../models/device.dart';
import '../core/constants/app_constants.dart';

class ApiDeviceRepository {
  final ApiClient _api = ApiClient();

  static final List<Device> _defaultSeedDevices = [
    Device(
      id: '1',
      name: 'Main Ceiling Lights',
      type: 'light',
      location: 'Lab 1',
      isOn: true,
      status: DeviceStatus.online,
      lastUpdated: DateTime.now(),
    ),
    Device(
      id: '4',
      name: 'Exhaust Ventilation Fan',
      type: 'fan',
      location: 'Lab 1',
      isOn: true,
      status: DeviceStatus.online,
      lastUpdated: DateTime.now(),
    ),
  ];

  Future<List<Device>> getDevices() async {
    try {
      final response = await _api.get(ApiConfig.devices);
      if (response is List && response.isNotEmpty) {
        final all = response.map((json) => Device.fromJson(json)).toList();
        // Strict Modified Specification: Only fans and lights are controlled
        final fansAndLights = all.where((d) {
          final t = d.type.toLowerCase();
          final n = d.name.toLowerCase();
          return t.contains('fan') || t.contains('light') || n.contains('fan') || n.contains('light');
        }).toList();

        if (fansAndLights.isNotEmpty) {
          return fansAndLights;
        }
      }
      return _defaultSeedDevices;
    } catch (_) {
      return _defaultSeedDevices;
    }
  }

  /// Toggles a device with optimistic update and audit logging to device_logs
  Future<bool> toggleDevice(
    String deviceId, 
    bool turnOn, {
    String? userId, 
    String? oldState,
  }) async {
    try {
      final state = turnOn ? 'ON' : 'OFF';
      final previousState = oldState ?? (turnOn ? 'OFF' : 'ON');
      final nowUtc = DateTime.now().toUtc().toIso8601String();

      // 1. Update power state in devices table
      await _api.patch(
        '/devices?id=eq.$deviceId',
        body: {
          'power_state': state,
          'last_updated': nowUtc,
        },
      );

      // 2. Audit log entry in device_logs table
      try {
        final devId = int.tryParse(deviceId) ?? 1;
        final usrId = int.tryParse(userId ?? '1') ?? 1;
        await _api.post(
          '/device_logs',
          body: {
            'device_id': devId,
            'action': 'toggle',
            'performed_by': usrId,
            'old_state': previousState,
            'new_state': state,
            'created_at': nowUtc,
          },
        );
      } catch (_) {
        // Non-blocking audit log
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
