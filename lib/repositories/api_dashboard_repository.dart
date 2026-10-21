import '../core/api/api_client.dart';
import 'student_directory.dart';

class ApiDashboardRepository {
  final ApiClient _api = ApiClient();

  /// Fetches dashboard data strictly filtered by today's date and active section
  Future<Map<String, dynamic>> getDashboardData({String? section, DateTime? date}) async {
    try {
      final targetDate = date ?? DateTime.now();
      final dateStr = targetDate.toIso8601String().split('T')[0];
      final String filterSection = (section != null && section.isNotEmpty)
          ? section.trim().toUpperCase()
          : 'A';

      final results = await Future.wait([
        // 0: Students roster
        _api.get('/students?select=id,register_number,section&order=id.asc'),
        // 1: Attendance for today strictly
        _api.get('/attendance?attendance_date=eq.$dateStr&status=in.(present,late)&select=id,student_id,status'),
        // 2: Devices - full details
        _api.get('/devices?select=id,device_name,device_type,power_state,status,last_updated'),
        // 3: Labs
        _api.get('/labs?select=id,lab_name'),
      ]);

      // Students
      final remoteStudents = results[0] is List ? results[0] as List : [];
      final localStudents = StudentDirectory.getAll();

      final Map<String, String> studentSectionMap = {};
      final Set<String> sectionStudentIds = {};

      if (remoteStudents.isNotEmpty) {
        for (final s in remoteStudents) {
          final idStr = s['id'].toString();
          String sec = (s['section'] ?? '').toString().trim().toUpperCase();
          if (sec.isEmpty) sec = 'A';
          studentSectionMap[idStr] = sec;
          if (sec == filterSection) {
            sectionStudentIds.add(idStr);
          }
        }
      } else {
        for (final s in localStudents) {
          final idStr = s.id;
          String sec = s.section.trim().toUpperCase();
          if (sec.isEmpty) sec = 'A';
          studentSectionMap[idStr] = sec;
          if (sec == filterSection) {
            sectionStudentIds.add(idStr);
          }
        }
      }

      int totalStudents = sectionStudentIds.length;
      if (totalStudents == 0 && filterSection == 'A' && localStudents.isNotEmpty) {
        totalStudents = localStudents.where((s) => s.section.toUpperCase() == 'A').length;
      }

      // Attendance records for today
      final attendanceList = results[1] is List ? results[1] as List : [];

      // Deduplicate present students for today matching the active section
      final Set<String> presentStudentIds = {};
      for (final att in attendanceList) {
        final stuId = att['student_id']?.toString() ?? '';
        if (stuId.isEmpty) continue;
        final stuSec = studentSectionMap[stuId] ?? 'A';
        if (stuSec == filterSection) {
          presentStudentIds.add(stuId);
        }
      }

      final presentStudents = presentStudentIds.length;
      final attPct = totalStudents > 0
          ? ((presentStudents / totalStudents) * 100).round().clamp(0, 100)
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
          'section': filterSection,
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
        'attendance': {'percentage': 0, 'present': 0, 'total': 0, 'section': section ?? 'A'},
        'devices': {'active': 0, 'total': 0, 'list': [], 'is_fan_on': false, 'is_light_on': false},
        'labs': {'total': 0, 'names': []},
      };
    }
  }
}
