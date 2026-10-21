import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/status_card.dart';
import '../../repositories/api_attendance_repository.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _repo = ApiAttendanceRepository();
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic> _summary = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final summary = await _repo.getSummaryForDate(_selectedDate);
      if (mounted) {
        setState(() {
          _summary = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading attendance summary: $e');
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedDate = _formatDateTitle(_selectedDate);
    final dateParam = DateFormat('yyyy-MM-dd').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biometric Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Attendance Data',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sleek Date Filter Header Bar
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                ),
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
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_month, size: 20, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              formattedDate,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, size: 20),
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

              // Overview Cards (Accurate strictly for the selected date)
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.2,
                children: [
                  StatusCard(
                    title: 'Attendance Rate',
                    value: '${_summary['percentage'] ?? 0}%',
                    subtitle: '${_summary['present_count'] ?? 0} / ${_summary['total_students'] ?? 0} Students',
                    icon: Icons.fingerprint,
                    iconColor: theme.colorScheme.primary,
                  ),
                  StatusCard(
                    title: 'Present',
                    value: '${_summary['present_count'] ?? 0}',
                    subtitle: 'Students',
                    icon: Icons.check_circle_outline,
                    iconColor: AppConstants.statusGreen,
                  ),
                  StatusCard(
                    title: 'Absent',
                    value: '${_summary['absent_count'] ?? 0}',
                    subtitle: 'Students',
                    icon: Icons.cancel_outlined,
                    iconColor: AppConstants.statusRed,
                  ),
                  StatusCard(
                    title: 'Late',
                    value: '${_summary['late_count'] ?? 0}',
                    subtitle: 'Students',
                    icon: Icons.access_time,
                    iconColor: AppConstants.statusOrange,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              
              // Actions
              Card(
                elevation: 0,
                color: theme.colorScheme.primaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE65100),
                    child: Icon(Icons.barcode_reader, color: Colors.white),
                  ),
                  title: Text(
                    'Scan Student Barcode ID',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  subtitle: Text(
                    'Scan college ID card barcode for student profile & check-in',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16, color: theme.colorScheme.onPrimaryContainer),
                  onTap: () => context.push('/more/attendance/scan'),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.groups_outlined, color: theme.colorScheme.primary),
                title: const Text('View Student Roster'),
                subtitle: Text('Manage attendance for $formattedDate'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                tileColor: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.surfaceContainerHighest),
                ),
                onTap: () => context.push('/more/attendance/students?date=$dateParam'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
