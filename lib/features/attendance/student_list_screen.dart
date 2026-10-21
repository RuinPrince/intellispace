import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../repositories/api_attendance_repository.dart';
import '../../repositories/student_directory.dart';
import '../../models/attendance_record.dart';
import '../../core/widgets/student_avatar.dart';

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
  String _searchQuery = '';
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
    // Optimistic UI update
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
                          width: 80,
                          height: 96,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFFC2410C),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$course, $dept',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                              Text(
                                'Roll No: $rollNo',
                                style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              Text(
                                yearSec,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.indigo),
                              ),
                              Text(
                                'Validity: $validity',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  'Blood Group: $bloodGroup',
                                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 24),

                    const Text(
                      'ACADEMIC & RESIDENTIAL DETAILS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 8),
                    Text('• Sem Duration: $semDuration', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('• Address: $address (PIN: $pincode)', style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('• Email: $email', style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('• Phone: ${phones.join(", ")}', style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('• DOB: $dob', style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: record.isPresent ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: record.isPresent ? Colors.green : Colors.red),
                      ),
                      child: Text(
                        record.isPresent ? 'STATUS: PRESENT ON ${DateFormat("d MMM").format(_selectedDate).toUpperCase()}' : 'STATUS: ABSENT ON ${DateFormat("d MMM").format(_selectedDate).toUpperCase()}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: record.isPresent ? Colors.green.shade800 : Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: record.isPresent ? Colors.red.shade700 : Colors.green.shade700,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _toggleAttendance(record, !record.isPresent);
                        },
                        child: Text(record.isPresent ? 'Mark Absent' : 'Mark Present'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedDate = _formatDateTitle(_selectedDate);

    final filteredRecords = _records.where((record) {
      final q = _searchQuery.toLowerCase().trim();
      if (q.isEmpty) return true;
      return record.student.name.toLowerCase().contains(q) ||
             record.student.registerNumber.toLowerCase().contains(q) ||
             record.student.department.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Attendance Roster'),
        actions: [
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
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
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

          // Search Field
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search student name or roll number...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),

          // Summary Stats Pill
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                Text(
                  '${filteredRecords.length} Students Registered',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const Spacer(),
                Text(
                  'Present: ${_records.where((r) => r.isPresent).length}  •  Absent: ${_records.where((r) => !r.isPresent).length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Student List Cards (Clean layout, no word-wrapping issues)
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
                                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                            ),
                          ),
                          child: InkWell(
                            onTap: () => _showStudentIdDialog(record),
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                              child: Row(
                                children: [
                                  // Student Avatar with Photo or Initial Fallback
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

                                  // Name & Details (Ample horizontal space to prevent word breakage)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          record.student.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
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
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Year ${record.student.year} • Sec ${record.student.section} • ${record.student.batch ?? "2023-27"}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.colorScheme.outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Actions: QR view + Presence Switch
                                  IconButton(
                                    icon: const Icon(Icons.qr_code, size: 20),
                                    tooltip: 'View ID Card',
                                    color: theme.colorScheme.onSurfaceVariant,
                                    onPressed: () => _showStudentIdDialog(record),
                                  ),
                                  Switch(
                                    value: record.isPresent,
                                    activeColor: AppConstants.statusGreen,
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
}
