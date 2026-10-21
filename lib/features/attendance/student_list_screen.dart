import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../repositories/api_attendance_repository.dart';
import '../../repositories/student_directory.dart';
import '../../models/attendance_record.dart';
import '../../core/widgets/student_avatar.dart';
import '../../services/absentee_notification_service.dart';

class StudentListScreen extends StatefulWidget {
  final String? initialDate;

  const StudentListScreen({super.key, this.initialDate});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final _repo = ApiAttendanceRepository();
  List<AttendanceRecord> _records = [];
  bool _isLoading = true;
  bool _isDispatchingSms = false;
  String _searchQuery = '';
  String _sectionFilter = 'All'; // 'All', 'A', 'B'
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      _selectedDate = DateTime.tryParse(widget.initialDate!) ?? DateTime.now();
    } else {
      _selectedDate = DateTime.now();
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final records = await _repo.getRecordsForDate(_selectedDate);
      if (mounted) {
        setState(() {
          _records = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading attendance for date: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _loadData();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  String _formatDateTitle(DateTime date) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;

    if (isToday) {
      return 'Today, ${DateFormat('d MMM yyyy').format(date)}';
    } else if (isYesterday) {
      return 'Yesterday, ${DateFormat('d MMM yyyy').format(date)}';
    } else {
      return DateFormat('EEE, d MMM yyyy').format(date);
    }
  }

  Future<void> _toggleAttendance(AttendanceRecord record, bool isPresent) async {
    setState(() {
      final index = _records.indexWhere((r) => r.student.id == record.student.id || r.student.registerNumber == record.student.registerNumber);
      if (index != -1) {
        _records[index] = AttendanceRecord(
          id: record.id,
          student: record.student,
          timestamp: _selectedDate,
          isPresent: isPresent,
          status: isPresent ? 'present' : 'absent',
          remarks: record.remarks,
        );
      }
    });

    final success = await _repo.markAttendance(
      record.student.id,
      isPresent ? 'present' : 'absent',
      date: _selectedDate,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update attendance on server, cached locally.')),
      );
    }
  }

  /// 11:00 AM Absentee Cutoff and SMS Dispatch Execution
  Future<void> _triggerAbsenteeCutoff({bool force = false}) async {
    final now = DateTime.now();
    final isPast11 = AbsenteeNotificationService.isPast11AmCutoff(now);
    final isToday = _selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day;

    // Filter absent records for current section
    final absentStudents = _records.where((r) {
      if (_sectionFilter != 'All' && r.student.section.toUpperCase() != _sectionFilter.toUpperCase()) {
        return false;
      }
      return !r.isPresent;
    }).toList();

    if (absentStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No absent students found for this date & section! All students are marked present.'),
          backgroundColor: AppColors.success,
        ),
      );
      return;
    }

    // Confirmation Dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.sms_failed_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Expanded(child: Text('11:00 AM Absentee SMS Cutoff', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attendance Cutoff for ${DateFormat('dd MMM yyyy').format(_selectedDate)}:',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                'Found ${absentStudents.length} student(s) not marked present. Official SMS will be dispatched to their registered parent numbers.',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const Divider(height: 16),
              const Text('Absent Students to Notify:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 140),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: absentStudents.length,
                  itemBuilder: (c, i) {
                    final s = absentStudents[i].student;
                    final card = StudentDirectory.findByBarcode(s.registerNumber);
                    final phones = card?.phones.isNotEmpty == true ? card!.phones.join(', ') : s.phone;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.circle, size: 6, color: AppColors.error),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${s.name} (${s.registerNumber}) • $phones',
                              style: const TextStyle(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'SMS Alert: "KLNCE ATTENDANCE ALERT: Student [NAME] is marked ABSENT today as attendance was not recorded before 11:00 AM."',
                  style: TextStyle(fontSize: 10, color: Colors.brown, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Send SMS', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDispatchingSms = true);
    try {
      final res = await AbsenteeNotificationService.processAbsenteeCutoffAndSendSms(
        date: _selectedDate,
        sectionFilter: _sectionFilter == 'All' ? null : _sectionFilter,
        force: force || !isToday || isPast11,
      );

      await _loadData(); // Reload records

      if (mounted) {
        setState(() => _isDispatchingSms = false);
        final markedCount = res['marked_absent_count'] ?? 0;
        final smsCount = res['sms_success_count'] ?? 0;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marked $markedCount absent. Dispatched $smsCount SMS notification(s) to parents!'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDispatchingSms = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error executing absentee cutoff: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _triggerOnDemandAbsentSms() async {
    final absentStudents = _records.where((r) {
      if (_sectionFilter != 'All' && r.student.section.toUpperCase() != _sectionFilter.toUpperCase()) {
        return false;
      }
      return !r.isPresent;
    }).toList();

    if (absentStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No absent students found to notify!'),
          backgroundColor: AppColors.success,
        ),
      );
      return;
    }

    final dateStr = DateFormat('dd/MM/yyyy').format(_selectedDate);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.send_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(child: Text('Admin On-Demand SMS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dispatch Absent SMS anytime for $dateStr.'),
            const SizedBox(height: 8),
            Text(
              'Targeting ${absentStudents.length} absent student(s) in ${_sectionFilter == "All" ? "all sections" : "Section $_sectionFilter"}.',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const Divider(height: 20),
            const Text('Absent Students:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: absentStudents.length,
                itemBuilder: (c, i) {
                  final s = absentStudents[i].student;
                  final card = StudentDirectory.findByBarcode(s.registerNumber);
                  final phones = card?.phones.isNotEmpty == true ? card!.phones.join(', ') : (s.phone ?? "N/A");
                  return Text('• ${s.name} (${s.registerNumber}) - $phones', style: const TextStyle(fontSize: 11));
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Dispatch SMS Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDispatchingSms = true);
    try {
      final res = await AbsenteeNotificationService.sendAdminOnDemandAbsenteeSms(
        date: _selectedDate,
        sectionFilter: _sectionFilter == 'All' ? null : _sectionFilter,
      );
      await _loadData();
      if (mounted) {
        setState(() => _isDispatchingSms = false);
        final count = res['sms_success_count'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('On-Demand SMS dispatched to $count parent(s)! Logged to Supabase.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDispatchingSms = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error dispatching SMS: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showIndividualSmsDialog(AttendanceRecord record) {
    final details = StudentDirectory.findByBarcode(record.student.registerNumber);
    final List<String> phones = (details != null && details.phones.isNotEmpty)
        ? details.phones
        : (record.student.phone != null && record.student.phone!.isNotEmpty ? [record.student.phone!] : []);

    final dateStr = DateFormat('dd/MM/yyyy').format(_selectedDate);
    final defaultMsg = 'KLNCE ATTENDANCE ALERT: Student ${record.student.name} (Reg No: ${record.student.registerNumber}, Dept: ${record.student.department}, Sec: ${record.student.section}) is marked ABSENT today ($dateStr). Please contact department.';

    final msgCtrl = TextEditingController(text: defaultMsg);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              children: [
                const Icon(Icons.sms_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Send Absent SMS to ${record.student.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Roll No: ${record.student.registerNumber} • Sec ${record.student.section} • Date: $dateStr',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const Divider(height: 18),
            const Text(
              'Registered Parent Contacts in Database:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              phones.isNotEmpty ? phones.join('  •  ') : 'No registered phone numbers found in database',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: phones.isNotEmpty ? AppColors.primary : AppColors.error,
              ),
            ),
            const SizedBox(height: 12),
            const Text('SMS Text Preview (Editable):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            const SizedBox(height: 6),
            TextField(
              controller: msgCtrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.withValues(alpha: 0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Dispatch SMS to Parents Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: phones.isEmpty ? null : () async {
                  Navigator.pop(ctx);
                  setState(() => _isDispatchingSms = true);
                  final res = await AbsenteeNotificationService.sendAdminOnDemandAbsenteeSms(
                    date: _selectedDate,
                    specificRollNumber: record.student.registerNumber,
                    customMessage: msgCtrl.text.trim(),
                  );
                  await _loadData();
                  if (mounted) {
                    setState(() => _isDispatchingSms = false);
                    final ok = (res['sms_success_count'] ?? 0) > 0;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok
                            ? 'SMS dispatched to ${record.student.name}\'s parents!'
                            : 'SMS logged to Supabase and dispatched via SMS intent.'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSmsAuditLogsModal() async {
    final logs = await AbsenteeNotificationService.getAuditLogs();
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
                  const Text('Absentee SMS Dispatch Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${logs.length} logged', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              const Divider(height: 20),
              Expanded(
                child: logs.isEmpty
                    ? const Center(child: Text('No SMS dispatches logged yet today.'))
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: logs.length,
                        itemBuilder: (c, idx) {
                          final log = logs[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${log.studentName} (${log.rollNumber})',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: log.success ? Colors.green.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          log.status,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: log.success ? Colors.green.shade800 : Colors.red.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'To: ${log.phone} • ${DateFormat('hh:mm a, dd MMM').format(log.timestamp)}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    log.message,
                                    style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
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

  void _showStudentIdDialog(AttendanceRecord record) {
    final details = StudentDirectory.findByBarcode(record.student.registerNumber) ??
                    StudentDirectory.findByIdOrRoll(record.student.id);

    final String name = details?.name ?? record.student.name;
    final String rollNo = details?.barcode ?? record.student.registerNumber;
    final String dept = details?.department ?? record.student.department;
    final String course = details?.course ?? 'B.Tech.';
    final String validity = details?.validity ?? 'August 2023 to May 2027';
    final String bloodGroup = details?.bloodGroup ?? 'A1+VE';
    final String semDuration = details?.semesterDuration ?? 'August 2025 – December 2025';
    final String address = details?.address ?? 'KLN College Campus, Pottapalayam';
    final String pincode = details?.pincode ?? '630612';
    final String email = details?.email ?? '${record.student.registerNumber}@college.edu';
    final List<String> phones = details?.phones ?? ['9842014033', '8870792326'];
    final String dob = details?.dob ?? '19-12-2005';
    final String yearSec = 'Year ${record.student.year} • Sec ${record.student.section} • ${record.student.semester ?? "Sem 5"}';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFE65100),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    const Text(
                      'K.L.N. COLLEGE OF ENGINEERING',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '(An Autonomous Institution, Affiliated to Anna University, Chennai)\nPottapalayam - 630 612',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 10),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StudentAvatar(
                          avatarUrl: details?.avatarUrl,
                          barcode: details?.barcode ?? rollNo,
                          studentName: name,
                          radius: 36,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black26, width: 1.5),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                              const SizedBox(height: 2),
                              Text('$course - $dept', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFE65100))),
                              const SizedBox(height: 2),
                              Text(yearSec, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                                child: Text('Roll No: $rollNo', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildDetailRow('Registered Phones:', phones.join('  •  ')),
                    const SizedBox(height: 8),
                    _buildDetailRow('Email:', email),
                    const SizedBox(height: 8),
                    _buildDetailRow('Address:', '$address, $pincode'),
                    const SizedBox(height: 8),
                    _buildDetailRow('DOB & Blood Group:', '$dob  •  $bloodGroup'),
                    const SizedBox(height: 8),
                    _buildDetailRow('Validity:', validity),
                    const SizedBox(height: 8),
                    _buildDetailRow('Semester Duration:', semDuration),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
        Text(value, style: const TextStyle(fontSize: 12, color: Colors.black87)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedDate = _formatDateTitle(_selectedDate);
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day;
    final isPast11 = AbsenteeNotificationService.isPast11AmCutoff(now);
    final minsLeft = AbsenteeNotificationService.minutesUntil11Am(now);

    final filteredRecords = _records.where((record) {
      if (_sectionFilter != 'All' && record.student.section.toUpperCase() != _sectionFilter.toUpperCase()) {
        return false;
      }
      final q = _searchQuery.toLowerCase().trim();
      if (q.isEmpty) return true;
      return record.student.name.toLowerCase().contains(q) ||
             record.student.registerNumber.toLowerCase().contains(q) ||
             record.student.department.toLowerCase().contains(q);
    }).toList();

    final presentCount = _records.where((r) => (_sectionFilter == 'All' || r.student.section.toUpperCase() == _sectionFilter.toUpperCase()) && r.isPresent).length;
    final absentCount = _records.where((r) => (_sectionFilter == 'All' || r.student.section.toUpperCase() == _sectionFilter.toUpperCase()) && !r.isPresent).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Attendance Roster'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'SMS Audit Logs',
            onPressed: _showSmsAuditLogsModal,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload Roster',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
        children: [
          // Date Selector Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous Day',
                  onPressed: () => _changeDate(-1),
                ),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          formattedDate,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Icon(Icons.arrow_drop_down, size: 18),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next Day',
                  onPressed: () => _changeDate(1),
                ),
              ],
            ),
          ),

          // 11:00 AM Absentee Cutoff Alert & SMS Trigger Banner
          _buildAbsenteeCutoffBanner(isToday, isPast11, minsLeft, absentCount),

          // Section Selector Filter (All, Section A, Section B)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                _buildSectionFilterChip('All'),
                const SizedBox(width: 8),
                _buildSectionFilterChip('A', 'Section A'),
                const SizedBox(width: 8),
                _buildSectionFilterChip('B', 'Section B'),
                const Spacer(),
                Text(
                  '$presentCount Present • $absentCount Absent',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: absentCount > 0 ? AppColors.error : AppColors.success,
                  ),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search student name or roll number...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Student List Cards
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: filteredRecords.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_off_outlined, size: 48, color: theme.colorScheme.outline),
                          const SizedBox(height: 12),
                          Text('No students found for "$_searchQuery"', style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                      itemCount: filteredRecords.length,
                      itemBuilder: (context, index) {
                        final record = filteredRecords[index];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10.0),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: record.isPresent 
                                  ? AppConstants.statusGreen.withValues(alpha: 0.4) 
                                  : AppConstants.statusRed.withValues(alpha: 0.4),
                            ),
                          ),
                          child: InkWell(
                            onTap: () => _showStudentIdDialog(record),
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                              child: Row(
                                children: [
                                  // Student Avatar
                                  StudentAvatar(
                                    avatarUrl: StudentDirectory.findByBarcode(record.student.registerNumber)?.avatarUrl,
                                    barcode: record.student.registerNumber,
                                    studentName: record.student.name,
                                    radius: 22,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: record.isPresent ? AppConstants.statusGreen : AppConstants.statusRed,
                                      width: 1.5,
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Name & Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          record.student.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Text(
                                              record.student.registerNumber,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: theme.colorScheme.primary,
                                              ),
                                            ),
                                            Text(
                                              ' • ${record.student.department}',
                                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Year ${record.student.year} • Sec ${record.student.section} • ${record.student.batch ?? "2023-27"}',
                                          style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Actions: Individual Absent SMS + QR view + Presence Switch
                                  if (!record.isPresent)
                                    IconButton(
                                      icon: const Icon(Icons.sms_rounded, size: 20, color: Color(0xFFE65100)),
                                      tooltip: 'Send Absent SMS to Parents (Admin)',
                                      onPressed: () => _showIndividualSmsDialog(record),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.qr_code, size: 20),
                                    tooltip: 'View ID Card',
                                    color: theme.colorScheme.onSurfaceVariant,
                                    onPressed: () => _showStudentIdDialog(record),
                                  ),
                                  Switch(
                                    value: record.isPresent,
                                    activeThumbColor: AppConstants.statusGreen,
                                    onChanged: (value) => _toggleAttendance(record, value),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionFilterChip(String sectionKey, [String? label]) {
    final isSelected = _sectionFilter == sectionKey;
    return ChoiceChip(
      label: Text(label ?? sectionKey, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppColors.textPrimary)),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (_) => setState(() => _sectionFilter = sectionKey),
    );
  }

  Widget _buildAbsenteeCutoffBanner(bool isToday, bool isPast11, int minsLeft, int absentCount) {
    Color bannerBg = isPast11 ? Colors.red.withValues(alpha: 0.08) : Colors.amber.withValues(alpha: 0.08);
    Color bannerBorder = isPast11 ? Colors.red.withValues(alpha: 0.3) : Colors.amber.withValues(alpha: 0.3);
    Color bannerText = isPast11 ? Colors.red.shade900 : Colors.brown.shade900;
    IconData icon = isPast11 ? Icons.alarm_on_rounded : Icons.alarm_rounded;

    String statusText;
    if (isToday) {
      if (isPast11) {
        statusText = '11:00 AM Cutoff Active: Unmarked students are ABSENT. Official SMS alerts ready.';
      } else {
        statusText = '11:00 AM Cutoff Pending: $minsLeft mins remaining for students to report present.';
      }
    } else {
      statusText = 'Attendance record for past date. Cutoff finalized.';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bannerBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: bannerText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: bannerText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: _isDispatchingSms
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 16),
                  label: Text(
                    _isDispatchingSms ? 'Dispatching SMS...' : 'Mark Absent & Send SMS ($absentCount)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPast11 ? AppColors.error : AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isDispatchingSms ? null : () => _triggerAbsenteeCutoff(force: !isPast11),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.receipt_long_rounded, size: 16),
                label: const Text('SMS Logs', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _showSmsAuditLogsModal,
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              icon: const Icon(Icons.send_and_archive_rounded, size: 16, color: Color(0xFFE65100)),
              label: Text(
                'Admin On-Demand: Send SMS to All Absent ($absentCount) Anytime',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFE65100)),
              ),
              onPressed: _isDispatchingSms ? null : _triggerOnDemandAbsentSms,
            ),
          ),
        ],
      ),
    );
  }
}
