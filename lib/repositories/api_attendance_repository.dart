import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';
import '../models/attendance_record.dart';
import 'student_directory.dart';

class ApiAttendanceRepository {
  final ApiClient _api = ApiClient();

  /// Calculates attendance summary strictly for a specific date (YYYY-MM-DD)
  Future<Map<String, dynamic>> getSummaryForDate(DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];
    try {
      final results = await Future.wait([
        _api.get('/students?select=*&order=id.asc'),
        _api.get('/attendance?attendance_date=eq.$dateStr&select=status'),
      ]);

      final studentsList = results[0] is List ? results[0] as List : [];
      final attendanceList = results[1] is List ? results[1] as List : [];

      // Determine total registered students
      int total = studentsList.length;
      if (total == 0) {
        total = StudentDirectory.getAll().length;
      }

      final present = attendanceList.where((a) => a['status'] == 'present').length;
      final late = attendanceList.where((a) => a['status'] == 'late').length;
      int absent = total - (present + late);
      if (absent < 0) absent = 0;

      final rawPct = total > 0 ? (((present + late) / total) * 100).round() : 0;
      final pct = rawPct > 100 ? 100 : rawPct; // Clamp to 100% max

      return {
        'date': dateStr,
        'total_students': total,
        'present_count': present,
        'late_count': late,
        'absent_count': absent,
        'percentage': pct,
      };
    } catch (e) {
      print('Error fetching attendance summary for $dateStr: $e');
      // Local fallback
      final total = StudentDirectory.getAll().length;
      return {
        'date': dateStr,
        'total_students': total,
        'present_count': 0,
        'late_count': 0,
        'absent_count': total,
        'percentage': 0,
      };
    }
  }

  Future<Map<String, dynamic>> getTodaySummary() async {
    return getSummaryForDate(DateTime.now());
  }

  /// Returns 1-to-1 roster for a specific date.
  /// Every active student appears EXACTLY ONCE with their status for that day.
  Future<List<AttendanceRecord>> getRecordsForDate(DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];
    try {
      final results = await Future.wait([
        _api.get('/students?select=*&order=id.asc'),
        _api.get('/attendance?attendance_date=eq.$dateStr&select=*'),
      ]);

      List<Student> students = [];
      if (results[0] is List && (results[0] as List).isNotEmpty) {
        students = (results[0] as List).map((json) => Student.fromJson(json)).toList();
      }

      // If remote students list is empty, populate from StudentDirectory
      if (students.isEmpty) {
        students = StudentDirectory.getAll().map((sd) => Student(
          id: sd.id,
          name: sd.name,
          registerNumber: sd.barcode,
          department: sd.department,
          year: int.tryParse(sd.year) ?? 3,
          section: sd.section,
          batch: sd.batch,
          semester: sd.semester,
          email: sd.email,
          phone: sd.phones.isNotEmpty ? sd.phones.first : '',
          dob: sd.dob,
          bloodGroup: sd.bloodGroup,
          address: sd.address,
          college: sd.college,
          validity: sd.validity,
        )).toList();
      }

      final attendanceList = results[1] is List ? results[1] as List : [];
      
      // Index attendance by student_id
      final Map<String, Map<String, dynamic>> attByStudentId = {};
      for (final att in attendanceList) {
        final sId = att['student_id']?.toString() ?? '';
        if (sId.isNotEmpty) {
          attByStudentId[sId] = att as Map<String, dynamic>;
        }
      }

      // Check local cached overrides for this date
      final localCache = await _getLocalCacheForDate(dateStr);

      // Synthesize exact 1-to-1 list: One record per student for this date
      final List<AttendanceRecord> records = [];
      for (final student in students) {
        String status = 'absent';
        String recordId = 'local_${student.id}_$dateStr';

        if (attByStudentId.containsKey(student.id)) {
          final att = attByStudentId[student.id]!;
          status = (att['status']?.toString() ?? 'absent').toLowerCase();
          recordId = att['id']?.toString() ?? recordId;
        } else if (localCache.containsKey(student.id)) {
          status = localCache[student.id]!;
        }

        // Enrich student with directory details if missing
        final cardDetails = StudentDirectory.findByBarcode(student.registerNumber);
        final enrichedStudent = Student(
          id: student.id,
          name: cardDetails?.name ?? student.name,
          registerNumber: student.registerNumber,
          department: cardDetails?.department ?? student.department,
          year: student.year,
          section: cardDetails?.section ?? student.section,
          batch: cardDetails?.batch ?? student.batch,
          semester: cardDetails?.semester ?? student.semester,
          email: cardDetails?.email ?? student.email,
          phone: (cardDetails?.phones.isNotEmpty ?? false) ? cardDetails!.phones.first : student.phone,
          dob: cardDetails?.dob ?? student.dob,
          bloodGroup: cardDetails?.bloodGroup ?? student.bloodGroup,
          address: cardDetails?.address ?? student.address,
          college: cardDetails?.college ?? student.college,
          validity: cardDetails?.validity ?? student.validity,
        );

        records.add(AttendanceRecord(
          id: recordId,
          student: enrichedStudent,
          timestamp: date,
          isPresent: status == 'present',
          status: status,
          remarks: status == 'late' ? 'Late arrival' : null,
        ));
      }

      return records;
    } catch (e) {
      print('Error fetching attendance records for $dateStr: $e');
      // Offline fallback from local directory
      final localCache = await _getLocalCacheForDate(dateStr);
      return StudentDirectory.getAll().map((sd) {
        final status = localCache[sd.id] ?? 'absent';
        return AttendanceRecord(
          id: 'offline_${sd.id}_$dateStr',
          student: Student(
            id: sd.id,
            name: sd.name,
            registerNumber: sd.barcode,
            department: sd.department,
            year: int.tryParse(sd.year) ?? 3,
            section: sd.section,
            batch: sd.batch,
            semester: sd.semester,
            email: sd.email,
            phone: sd.phones.isNotEmpty ? sd.phones.first : '',
            dob: sd.dob,
            bloodGroup: sd.bloodGroup,
            address: sd.address,
            college: sd.college,
            validity: sd.validity,
          ),
          timestamp: date,
          isPresent: status == 'present',
          status: status,
        );
      }).toList();
    }
  }

  Future<List<AttendanceRecord>> getTodayRecords() async {
    return getRecordsForDate(DateTime.now());
  }

  /// Upserts attendance record for a student on a specific date
  Future<bool> markAttendance(String studentId, String status, {DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final dateStr = targetDate.toIso8601String().split('T')[0];

    // Always persist to local cache first for instant feedback
    await _saveLocalCache(dateStr, studentId, status);

    try {
      final sIdInt = int.tryParse(studentId) ?? 1;
      await _api.post(
        '/attendance?on_conflict=student_id,attendance_date',
        headers: {'Prefer': 'resolution=merge-duplicates'},
        body: {
          'student_id': sIdInt,
          'attendance_date': dateStr,
          'status': status,
          'method': 'biometric',
        },
      );
      return true;
    } catch (e) {
      print('Error marking attendance in Supabase: $e');
      // If error occurs, local cache ensures user's action is not lost
      return true;
    }
  }

  // --- Local Cache Helpers ---
  static const String _localCachePrefix = 'local_attendance_';

  Future<Map<String, String>> _getLocalCacheForDate(String dateStr) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('$_localCachePrefix$dateStr');
      if (jsonStr != null) {
        final Map<String, dynamic> decoded = jsonDecode(jsonStr);
        return decoded.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (_) {}
    return {};
  }

  Future<void> _saveLocalCache(String dateStr, String studentId, String status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await _getLocalCacheForDate(dateStr);
      current[studentId] = status;
      await prefs.setString('$_localCachePrefix$dateStr', jsonEncode(current));
    } catch (_) {}
  }
}
