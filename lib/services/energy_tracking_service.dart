import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';

class EnergySessionLog {
  final String id;
  final String deviceId;
  final String deviceName;
  final String deviceType;
  final int ratedWatts;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final double energyKwh;
  final bool isOngoing;

  const EnergySessionLog({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    required this.ratedWatts,
    required this.startTime,
    this.endTime,
    required this.durationSeconds,
    required this.energyKwh,
    this.isOngoing = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'deviceId': deviceId,
    'deviceName': deviceName,
    'deviceType': deviceType,
    'ratedWatts': ratedWatts,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'durationSeconds': durationSeconds,
    'energyKwh': energyKwh,
    'isOngoing': isOngoing,
  };

  factory EnergySessionLog.fromJson(Map<String, dynamic> json) => EnergySessionLog(
    id: json['id'] ?? '',
    deviceId: json['deviceId']?.toString() ?? '',
    deviceName: json['deviceName'] ?? '',
    deviceType: json['deviceType'] ?? '',
    ratedWatts: json['ratedWatts'] ?? (json['deviceType'] == 'fan' ? 75 : 40),
    startTime: DateTime.tryParse(json['startTime'] ?? '') ?? DateTime.now(),
    endTime: json['endTime'] != null ? DateTime.tryParse(json['endTime']) : null,
    durationSeconds: json['durationSeconds'] ?? 0,
    energyKwh: (json['energyKwh'] as num?)?.toDouble() ?? 0.0,
    isOngoing: json['isOngoing'] ?? false,
  );
}

class TodayEnergySummary {
  final double totalKwh;
  final double fanKwh;
  final double lightKwh;
  final int activeWatts;
  final int fanActiveSecondsToday;
  final int lightActiveSecondsToday;
  final bool isFanOn;
  final bool isLightOn;

  const TodayEnergySummary({
    required this.totalKwh,
    required this.fanKwh,
    required this.lightKwh,
    required this.activeWatts,
    required this.fanActiveSecondsToday,
    required this.lightActiveSecondsToday,
    required this.isFanOn,
    required this.isLightOn,
  });
}

/// Service that accurately measures, records, and syncs energy consumption (kWh)
/// for lab fans and lights whenever they turn ON or OFF.
class EnergyTrackingService {
  static final ApiClient _api = ApiClient();
  static const String _keyLogs = 'energy_session_logs';
  static const String _keyActivePrefix = 'energy_active_start_';

  // Standard engineering power ratings
  static const int fanWatts = 75; // Standard 1200mm exhaust/ceiling fan
  static const int lightWatts = 40; // Standard 4-foot classroom LED batten/panel

  static int getRatedWatts(String deviceType) {
    if (deviceType.toLowerCase().contains('fan')) return fanWatts;
    return lightWatts;
  }

  /// Called whenever a device is switched ON or OFF
  static Future<void> recordDeviceStateChange({
    required String deviceId,
    required String deviceType,
    required String deviceName,
    required bool isOn,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final activeKey = '$_keyActivePrefix$deviceId';
    final watts = getRatedWatts(deviceType);

    if (isOn) {
      // Device turned ON: record session start time
      await prefs.setString(activeKey, now.toIso8601String());
      debugPrint('Energy: $deviceName turned ON at $now ($watts W)');

      // Log turn-on event to Supabase Cloud
      try {
        final devId = int.tryParse(deviceId) ?? 1;
        await _api.post('/device_logs', body: {
          'device_id': devId,
          'action': 'power_on',
          'performed_by': 1,
          'old_state': 'OFF',
          'new_state': 'ON',
          'created_at': now.toUtc().toIso8601String(),
        });
      } catch (_) {}
    } else {
      // Device turned OFF: calculate duration and consumed energy
      final startStr = prefs.getString(activeKey);
      DateTime startTime = now;
      if (startStr != null) {
        startTime = DateTime.tryParse(startStr) ?? now;
        await prefs.remove(activeKey);
      } else {
        // Fallback default: 15 mins prior
        startTime = now.subtract(const Duration(minutes: 15));
      }

      final durationSecs = now.difference(startTime).inSeconds;
      final effectiveSecs = durationSecs > 0 ? durationSecs : 1;
      final kwh = (watts * (effectiveSecs / 3600.0)) / 1000.0;

      final sessionLog = EnergySessionLog(
        id: 'energy_${deviceId}_${now.millisecondsSinceEpoch}',
        deviceId: deviceId,
        deviceName: deviceName,
        deviceType: deviceType,
        ratedWatts: watts,
        startTime: startTime,
        endTime: now,
        durationSeconds: effectiveSecs,
        energyKwh: kwh,
        isOngoing: false,
      );

      await _appendSessionLog(sessionLog);
      debugPrint('Energy: $deviceName turned OFF. Ran for ${effectiveSecs}s. Consumed ${kwh.toStringAsFixed(5)} kWh');

      // Sync completed session to Supabase Cloud
      try {
        final devId = int.tryParse(deviceId) ?? 1;
        await _api.post('/device_logs', body: {
          'device_id': devId,
          'action': 'energy_recorded',
          'performed_by': 1,
          'old_state': 'ON',
          'new_state': '${kwh.toStringAsFixed(4)} kWh (${(effectiveSecs / 60).round()}m)',
          'created_at': now.toUtc().toIso8601String(),
        });
      } catch (_) {}
    }
  }

  static Future<void> _appendSessionLog(EnergySessionLog log) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logs = await getEnergyLogs();
      logs.insert(0, log);
      // Keep last 300 logs
      final trimmed = logs.take(300).toList();
      await prefs.setString(_keyLogs, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('Error saving energy log: $e');
    }
  }

  /// Retrieve all recorded energy logs
  static Future<List<EnergySessionLog>> getEnergyLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyLogs);
      if (jsonStr != null) {
        final List list = jsonDecode(jsonStr);
        return list.map((e) => EnergySessionLog.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error reading energy logs: $e');
    }
    return [];
  }

  /// Computes today's real-time energy summary including currently active devices
  static Future<TodayEnergySummary> getTodayEnergySummary({
    bool isFanOn = false,
    bool isLightOn = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    final allLogs = await getEnergyLogs();

    double fanKwh = 0.0;
    double lightKwh = 0.0;
    int fanSecs = 0;
    int lightSecs = 0;

    // 1. Sum up completed sessions from today
    for (final log in allLogs) {
      if (log.startTime.isAfter(startOfToday)) {
        if (log.deviceType.toLowerCase().contains('fan')) {
          fanKwh += log.energyKwh;
          fanSecs += log.durationSeconds;
        } else {
          lightKwh += log.energyKwh;
          lightSecs += log.durationSeconds;
        }
      }
    }

    // 2. Add live ongoing consumption if devices are currently ON
    int activeWatts = 0;

    // Check Fan (ID 4 or fan type)
    if (isFanOn) {
      activeWatts += fanWatts;
      final startStr = prefs.getString('${_keyActivePrefix}4') ?? prefs.getString('${_keyActivePrefix}fan');
      if (startStr != null) {
        final start = DateTime.tryParse(startStr) ?? now;
        final ongoingSecs = now.difference(start).inSeconds;
        if (ongoingSecs > 0) {
          fanSecs += ongoingSecs;
          fanKwh += (fanWatts * (ongoingSecs / 3600.0)) / 1000.0;
        }
      } else {
        // Assume at least 1 minute live active
        fanSecs += 60;
        fanKwh += (fanWatts * (60 / 3600.0)) / 1000.0;
      }
    }

    // Check Light (ID 1 or light type)
    if (isLightOn) {
      activeWatts += lightWatts;
      final startStr = prefs.getString('${_keyActivePrefix}1') ?? prefs.getString('${_keyActivePrefix}light');
      if (startStr != null) {
        final start = DateTime.tryParse(startStr) ?? now;
        final ongoingSecs = now.difference(start).inSeconds;
        if (ongoingSecs > 0) {
          lightSecs += ongoingSecs;
          lightKwh += (lightWatts * (ongoingSecs / 3600.0)) / 1000.0;
        }
      } else {
        // Assume at least 1 minute live active
        lightSecs += 60;
        lightKwh += (lightWatts * (60 / 3600.0)) / 1000.0;
      }
    }

    final totalKwh = fanKwh + lightKwh;

    return TodayEnergySummary(
      totalKwh: totalKwh,
      fanKwh: fanKwh,
      lightKwh: lightKwh,
      activeWatts: activeWatts,
      fanActiveSecondsToday: fanSecs,
      lightActiveSecondsToday: lightSecs,
      isFanOn: isFanOn,
      isLightOn: isLightOn,
    );
  }
}
