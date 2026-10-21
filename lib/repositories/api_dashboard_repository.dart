import '../core/api/api_client.dart';

class ApiDashboardRepository {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> getDashboardData() async {
    try {
      final results = await Future.wait([
        // 0: Students total
        _api.get('/students?select=id'),
        // 1: Attendance present/late
        _api.get('/attendance?status=in.(present,late)&select=id'),
        // 2: Devices - full details
        _api.get('/devices?select=id,device_name,device_type,power_state,status,last_updated'),
        // 3: Labs
        _api.get('/labs?select=id,lab_name'),
      ]);

      // Attendance
      final studentsList = results[0] is List ? results[0] as List : [];
      final attendanceList = results[1] is List ? results[1] as List : [];
      final totalStudents = studentsList.length;
      final presentStudents = attendanceList.length;
      final attPct = totalStudents > 0 
          ? ((presentStudents / totalStudents) * 100).round() 
          : 0;

      // Devices
      final devicesList = results[2] is List ? results[2] as List : [];
      final totalDevices = devicesList.length;
      final activeDevices = devicesList.where((d) => d['power_state'] == 'ON').length;

      // Identify fan and light state specifically
      bool isFanOn = false;
      bool isLightOn = false;
      for (final d in devicesList) {
        final type = (d['device_type'] ?? '').toString().toLowerCase();
        final name = (d['device_name'] ?? '').toString().toLowerCase();
        final isOn = d['power_state'] == 'ON';
        if (type.contains('fan') || name.contains('fan')) {
          if (isOn) isFanOn = true;
        } else if (type.contains('light') || name.contains('light')) {
          if (isOn) isLightOn = true;
        }
      }

      // Labs
      final labsList = results[3] is List ? results[3] as List : [];
      final totalLabs = labsList.length;

      return {
        'attendance': {
          'percentage': attPct,
          'present': presentStudents,
          'total': totalStudents,
        },
        'devices': {
          'active': activeDevices,
          'total': totalDevices,
          'list': devicesList,
          'is_fan_on': isFanOn,
          'is_light_on': isLightOn,
        },
        'labs': {
          'total': totalLabs,
          'names': labsList.map((l) => l['lab_name'] ?? '').toList(),
        },
      };
    } catch (e) {
      return {
        'attendance': {'percentage': 0, 'present': 0, 'total': 0},
        'devices': {'active': 0, 'total': 0, 'list': [], 'is_fan_on': false, 'is_light_on': false},
        'labs': {'total': 0, 'names': []},
      };
    }
  }
}
