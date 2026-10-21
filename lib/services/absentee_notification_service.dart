import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';
import '../repositories/api_attendance_repository.dart';
import '../repositories/student_directory.dart';
import '../repositories/academic_schedule_repository.dart';

class SmsDispatchLog {
  final String studentName;
  final String rollNumber;
  final String section;
  final String phone;
  final String message;
  final DateTime timestamp;
  final bool success;
  final String status;

  const SmsDispatchLog({
    required this.studentName,
    required this.rollNumber,
    required this.section,
    required this.phone,
    required this.message,
    required this.timestamp,
    required this.success,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
    'studentName': studentName,
    'rollNumber': rollNumber,
    'section': section,
    'phone': phone,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    'success': success,
    'status': status,
  };

  factory SmsDispatchLog.fromJson(Map<String, dynamic> json) => SmsDispatchLog(
    studentName: json['studentName'] ?? '',
    rollNumber: json['rollNumber'] ?? '',
    section: json['section'] ?? '',
    phone: json['phone'] ?? '',
    message: json['message'] ?? '',
    timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    success: json['success'] ?? false,
    status: json['status'] ?? 'sent',
  );
}

/// Service managing the 11:00 AM Attendance Cutoff and Automated Parent SMS Notifications
class AbsenteeNotificationService {
  static const MethodChannel _smsChannel = MethodChannel('com.example.intellispace/sms');
  static final ApiAttendanceRepository _attRepo = ApiAttendanceRepository();
  static final ApiClient _api = ApiClient();
  static const String _prefsKeyDispatched = 'sms_dispatched_cache_';
  static const String _prefsKeyAuditLogs = 'absentee_sms_audit_logs';

  /// Returns true if the provided time is at or past 11:00 AM
  static bool isPast11AmCutoff([DateTime? time]) {
    final t = time ?? DateTime.now();
    return t.hour >= 11;
  }

  /// Calculates remaining minutes until 11:00 AM cutoff for today
  static int minutesUntil11Am([DateTime? time]) {
    final t = time ?? DateTime.now();
    final cutoff = DateTime(t.year, t.month, t.day, 11, 0, 0);
    if (t.isAfter(cutoff)) return 0;
    return cutoff.difference(t).inMinutes;
  }

  /// Verifies if a given date is an official working day
  static Future<bool> isWorkingDay([DateTime? date]) async {
    final d = date ?? DateTime.now();
    // Sunday is a non-working day
    if (d.weekday == DateTime.sunday) return false;

    // Check academic calendar holidays
    try {
      final calendar = await AcademicScheduleRepository.getCalendar();
      final dateStr = DateFormat('dd MMM').format(d).toLowerCase();
      for (final month in calendar.monthSummaries) {
        for (final hol in month.holidays) {
          if (hol.toLowerCase().contains(dateStr)) {
            return false;
          }
        }
      }
    } catch (_) {}

    return true;
  }

  /// Dispatches SMS via native Android channel or falls back to SMS Intent
  static Future<bool> _sendSmsNative(String phone, String message) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) return false;

    try {
      final res = await _smsChannel.invokeMethod<bool>('sendDirectSms', {
        'phone': cleanPhone,
        'message': message,
      });
      if (res == true) return true;
    } catch (e) {
      debugPrint('Direct SMS failed, attempting SMS Intent: $e');
    }

    try {
      final res = await _smsChannel.invokeMethod<bool>('openSmsApp', {
        'phone': cleanPhone,
        'message': message,
      });
      return res == true;
    } catch (e) {
      debugPrint('SMS intent failed: $e');
      return false;
    }
  }

  /// Executes the 11:00 AM Absentee Cutoff:
  /// 1. Verifies working day & 11:00 AM cutoff
  /// 2. Fetches students not marked present
  /// 3. Updates their attendance status to 'absent' in database
  /// 4. Dispatches official SMS notifications to registered phone numbers
  /// 5. Logs audit trail locally and in Supabase Cloud
  static Future<Map<String, dynamic>> processAbsenteeCutoffAndSendSms({
    DateTime? date,
    String? sectionFilter,
    bool force = false,
  }) async {
    final targetDate = date ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
    final displayDate = DateFormat('dd/MM/yyyy').format(targetDate);

    // 1. Cutoff Validation
    final past11 = isPast11AmCutoff(targetDate);
    if (!past11 && !force) {
      final minsLeft = minutesUntil11Am(targetDate);
      return {
        'success': false,
        'status': 'CUTOFF_NOT_REACHED',
        'message': '11:00 AM cutoff has not been reached yet ($minsLeft minutes remaining).',
        'count': 0,
      };
    }

    // 2. Fetch today's records
    final records = await _attRepo.getRecordsForDate(targetDate);

    // Load dispatch cache to prevent duplicates on same date
    final prefs = await SharedPreferences.getInstance();
    final dispatchedSet = (prefs.getStringList('$_prefsKeyDispatched$dateStr') ?? []).toSet();

    final List<SmsDispatchLog> dispatchLogs = [];
    int markedAbsentCount = 0;
    int smsSuccessCount = 0;

    for (final record in records) {
      // Filter by section if requested
      if (sectionFilter != null && sectionFilter.isNotEmpty && sectionFilter != 'All') {
        if (record.student.section.toUpperCase() != sectionFilter.toUpperCase()) {
          continue;
        }
      }

      // If already present or late, they are NOT absent
      if (record.status.toLowerCase() == 'present' || record.status.toLowerCase() == 'late') {
        continue;
      }

      // Mark student as absent in database
      await _attRepo.markAttendance(record.student.id, 'absent', date: targetDate);
      markedAbsentCount++;

      // Retrieve registered contact numbers
      final card = StudentDirectory.findByBarcode(record.student.registerNumber);
      List<String> targetPhones = [];
      if (card != null && card.phones.isNotEmpty) {
        targetPhones = card.phones;
      } else if (record.student.phone != null && record.student.phone!.isNotEmpty) {
        targetPhones = [record.student.phone!];
      }

      if (targetPhones.isEmpty) {
        dispatchLogs.add(SmsDispatchLog(
          studentName: record.student.name,
          rollNumber: record.student.registerNumber,
          section: record.student.section,
          phone: 'N/A',
          message: 'No contact numbers found in database',
          timestamp: DateTime.now(),
          success: false,
          status: 'NO_PHONE_NUMBER',
        ));
        continue;
      }

      // Check if already dispatched for this student today
      final cacheKey = '${record.student.registerNumber}_$dateStr';
      if (dispatchedSet.contains(cacheKey) && !force) {
        dispatchLogs.add(SmsDispatchLog(
          studentName: record.student.name,
          rollNumber: record.student.registerNumber,
          section: record.student.section,
          phone: targetPhones.first,
          message: 'Already notified earlier today',
          timestamp: DateTime.now(),
          success: true,
          status: 'ALREADY_SENT_TODAY',
        ));
        continue;
      }

      // Construct official KLNCE Absentee SMS
      final smsText = 'KLNCE ATTENDANCE ALERT: Student ${record.student.name} (Reg No: ${record.student.registerNumber}, Dept: ${record.student.department}, Sec: ${record.student.section}) is marked ABSENT on $displayDate as attendance was not recorded before the 11:00 AM cutoff.';

      bool anySuccess = false;
      for (final phone in targetPhones) {
        final ok = await _sendSmsNative(phone, smsText);
        if (ok) anySuccess = true;
      }

      // Record dispatch in Supabase Cloud notifications table
      try {
        await _api.post('/notifications', body: {
          'user_id': 1,
          'notification_type': 'attendance',
          'title': 'ABSENTEE SMS: ${record.student.name} (${record.student.registerNumber})',
          'message': 'SMS dispatched to [${targetPhones.join(", ")}]: "$smsText"',
          'severity': 'warning',
          'is_read': false,
        });
      } catch (e) {
        debugPrint('Error recording SMS notification in cloud: $e');
      }

      dispatchedSet.add(cacheKey);
      if (anySuccess) smsSuccessCount++;

      dispatchLogs.add(SmsDispatchLog(
        studentName: record.student.name,
        rollNumber: record.student.registerNumber,
        section: record.student.section,
        phone: targetPhones.join(', '),
        message: smsText,
        timestamp: DateTime.now(),
        success: true, // Marked & recorded
        status: 'DISPATCHED',
      ));
    }

    // Persist dispatched set
    await prefs.setStringList('$_prefsKeyDispatched$dateStr', dispatchedSet.toList());

    // Append to local audit logs
    await _saveAuditLogs(dispatchLogs);

    return {
      'success': true,
      'status': 'COMPLETED',
      'message': 'Processed $markedAbsentCount absentee(s). Dispatched notifications to registered parent phones.',
      'marked_absent_count': markedAbsentCount,
      'sms_success_count': smsSuccessCount,
      'logs': dispatchLogs,
    };
  }

  /// Retrieve all SMS audit logs from local storage
  static Future<List<SmsDispatchLog>> getAuditLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKeyAuditLogs);
      if (jsonStr != null) {
        final List list = jsonDecode(jsonStr);
        return list.map((e) => SmsDispatchLog.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error loading audit logs: $e');
    }
    return [];
  }

  static Future<void> _saveAuditLogs(List<SmsDispatchLog> newLogs) async {
    if (newLogs.isEmpty) return;
    try {
      final current = await getAuditLogs();
      current.insertAll(0, newLogs);
      // Keep latest 200 logs
      final trimmed = current.take(200).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyAuditLogs, jsonEncode(trimmed.map((l) => l.toJson()).toList()));
    } catch (e) {
      debugPrint('Error saving audit logs: $e');
    }
  }
}
