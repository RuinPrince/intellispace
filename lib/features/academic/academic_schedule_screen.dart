import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../models/academic_timetable.dart';
import '../../models/academic_calendar.dart';
import '../../repositories/academic_schedule_repository.dart';

class AcademicScheduleScreen extends StatefulWidget {
  final String initialSection;
  final int initialTabIndex; // 0: Timetable, 1: Calendar

  const AcademicScheduleScreen({
    super.key,
    this.initialSection = 'A',
    this.initialTabIndex = 0,
  });

  @override
  State<AcademicScheduleScreen> createState() => _AcademicScheduleScreenState();
}

class _AcademicScheduleScreenState extends State<AcademicScheduleScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _selectedSection;
  int _selectedDayOrder = 1;
  bool _isLoading = true;

  SectionTimetable? _timetableA;
  SectionTimetable? _timetableB;
  AcademicCalendar? _calendar;

  String _calendarFilter = 'All';

  @override
  void initState() {
    super.initState();
    _selectedSection = widget.initialSection;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await AcademicScheduleRepository.init();
    final a = await AcademicScheduleRepository.getTimetable('A');
    final b = await AcademicScheduleRepository.getTimetable('B');
    final cal = await AcademicScheduleRepository.getCalendar();

    if (mounted) {
      setState(() {
        _timetableA = a;
        _timetableB = b;
        _calendar = cal;
        _isLoading = false;
      });
    }
  }

  SectionTimetable? get _currentTimetable =>
      _selectedSection == 'B' ? _timetableB : _timetableA;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Academic Schedule & Calendar',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh from Cloud',
            onPressed: () async {
              setState(() => _isLoading = true);
              await AcademicScheduleRepository.syncFromCloud();
              await _loadData();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.table_chart_rounded, size: 20), text: 'Class Timetable'),
            Tab(icon: Icon(Icons.calendar_month_rounded, size: 20), text: 'Academic Calendar'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTimetableTab(),
                _buildCalendarTab(),
              ],
            ),
    );
  }

  // =========================================================================
  // TAB 1: CLASS TIMETABLE (BOTH SECTIONS A & B)
  // =========================================================================
  Widget _buildTimetableTab() {
    final tt = _currentTimetable;
    if (tt == null) {
      return const Center(child: Text('No timetable data available.'));
    }

    final activeDaySchedule = tt.days.firstWhere(
      (d) => d.dayOrder == _selectedDayOrder,
      orElse: () => tt.days.isNotEmpty ? tt.days.first : const DaySchedule(dayOrder: 1, dayName: 'DAY 1', periods: []),
    );

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section Toggle Bar (Section A vs Section B)
          _buildSectionSelector(),
          const SizedBox(height: 12),

          // Header Info Card
          _buildTimetableHeaderCard(tt),
          const SizedBox(height: 16),

          // Custom Uploaded Document Banner (if exists)
          if (tt.customImageUrl != null && tt.customImageUrl!.isNotEmpty)
            _buildCustomDocumentCard(tt.customImageUrl!, 'Section ${_selectedSection} Official Timetable Document'),

          // Day Order Selector (DAY 1 to DAY 5)
          _buildDayOrderSelector(tt),
          const SizedBox(height: 16),

          // Period Cards Timeline
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Schedule for ${activeDaySchedule.dayName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '8 Periods / Day',
                  style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ...activeDaySchedule.periods.map((p) => _buildPeriodTile(p)),

          const SizedBox(height: 24),

          // Subject Allocation Table
          _buildSubjectAllocationsSection(tt),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSectionTabButton(
              label: 'SECTION A',
              subtitle: 'Room M.E.-02',
              isSelected: _selectedSection == 'A',
              onTap: () => setState(() => _selectedSection = 'A'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildSectionTabButton(
              label: 'SECTION B',
              subtitle: 'Room M.E.-03',
              isSelected: _selectedSection == 'B',
              onTap: () => setState(() => _selectedSection = 'B'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTabButton({
    required String label,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white.withOpacity(0.85) : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimetableHeaderCard(SectionTimetable tt) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tt.course} - Section ${tt.section}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                    ),
                    Text(
                      '${tt.department} • Batch ${tt.batch}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(Icons.meeting_room_rounded, 'Classroom', tt.roomNo),
              ),
              Expanded(
                child: _buildInfoItem(Icons.person_rounded, 'In-Charge', tt.classInCharge),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(Icons.numbers_rounded, 'In-Charge Code', tt.inChargeCode),
              ),
              Expanded(
                child: _buildInfoItem(Icons.verified_rounded, 'Revision / Effective', tt.effectiveDate),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              Text(
                value,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDayOrderSelector(SectionTimetable tt) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tt.days.map((day) {
          final isSelected = day.dayOrder == _selectedDayOrder;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                day.dayName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
              ),
              onSelected: (_) => setState(() => _selectedDayOrder = day.dayOrder),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPeriodTile(TimetablePeriod period) {
    if (period.isBreak || period.isLunch) {
      final isLunch = period.isLunch;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isLunch ? Colors.amber.withOpacity(0.1) : Colors.blueGrey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isLunch ? Colors.amber.withOpacity(0.3) : Colors.blueGrey.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isLunch ? Icons.restaurant_rounded : Icons.coffee_rounded,
              size: 16,
              color: isLunch ? Colors.amber.shade800 : Colors.blueGrey.shade700,
            ),
            const SizedBox(width: 8),
            Text(
              period.label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isLunch ? Colors.amber.shade900 : Colors.blueGrey.shade800,
              ),
            ),
            const Spacer(),
            Text(
              period.timeRange,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isLunch ? Colors.amber.shade900 : Colors.blueGrey.shade800,
              ),
            ),
          ],
        ),
      );
    }

    // Determine subject accent color
    Color badgeColor = AppColors.primary;
    if (period.subjectAbbr.contains('LAB') || period.subjectAbbr.contains('MINI PROJECT')) {
      badgeColor = Colors.teal;
    } else if (period.subjectAbbr.contains('SKILL RACK')) {
      badgeColor = Colors.deepOrange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period number bubble
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              period.label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: badgeColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Subject & Faculty details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      period.subjectAbbr,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                    ),
                    Text(
                      period.timeRange,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                if (period.subjectTitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    period.subjectTitle,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (period.facultyName.isNotEmpty) ...[
                      const Icon(Icons.person_outline_rounded, size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          period.facultyName,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        period.roomOrLab,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectAllocationsSection(SectionTimetable tt) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.list_alt_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Allocation of Subjects & Faculty',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
              ),
            ],
          ),
          const Divider(height: 20),
          ...tt.subjects.map((sub) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 58,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: sub.isPractical ? Colors.teal.withOpacity(0.12) : AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        sub.abbr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: sub.isPractical ? Colors.teal : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sub.title,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${sub.code} • ${sub.facultyName} (Code: ${sub.facultyCode})',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          Text(
                            'Venue: ${sub.venue} • Hours: ${sub.totalHours} hrs/week',
                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: ACADEMIC CALENDAR (CIRCULAR NO. 321)
  // =========================================================================
  Widget _buildCalendarTab() {
    final cal = _calendar;
    if (cal == null) {
      return const Center(child: Text('No academic calendar data available.'));
    }

    final filteredEvents = cal.events.where((e) {
      if (_calendarFilter == 'All') return true;
      if (_calendarFilter == 'Tests') return e.category == 'internal_test';
      if (_calendarFilter == 'Exams') return e.category == 'exam';
      if (_calendarFilter == 'Meetings') return e.category == 'meeting';
      if (_calendarFilter == 'Holidays') return e.category == 'holiday';
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Circular Reference & College Header
          _buildCalendarHeaderCard(cal),
          const SizedBox(height: 14),

          // Custom Uploaded Circular Document (if uploaded)
          if (cal.customImageUrl != null && cal.customImageUrl!.isNotEmpty)
            _buildCustomDocumentCard(cal.customImageUrl!, 'Official Circular No. 321 Document Image'),

          // Stats Bar: Working Days & Milestones
          _buildCalendarMetrics(cal),
          const SizedBox(height: 16),

          // Category Filter Chips
          _buildCalendarFilterChips(),
          const SizedBox(height: 14),

          // Events Timeline
          Text(
            'Academic Milestones & Exam Schedule (${filteredEvents.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),

          ...filteredEvents.map((e) => _buildEventCard(e)),

          const SizedBox(height: 20),

          // Monthly Working Days & Holidays Table
          _buildMonthlySummarySection(cal),
          const SizedBox(height: 18),

          // CoE Assessment Schedule
          _buildAssessmentReportsSection(cal),
          const SizedBox(height: 18),

          // Circular Notes & Rules
          _buildGeneralNotesSection(cal),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCalendarHeaderCard(AcademicCalendar cal) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.description_rounded, color: Colors.amber, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'KLNCE CIRCULAR NO. 321',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                    ),
                    Text(
                      cal.circularRef,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          Text(
            cal.semesterDescription,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Date of Issue: ${cal.circularDate} • ${cal.affiliation}',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarMetrics(AcademicCalendar cal) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile('88', 'Working Days', Icons.calendar_today_rounded, AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile('06 July', 'Classes Begin', Icons.flag_rounded, Colors.teal),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile('24 Oct', 'Last Inst. Day', Icons.event_available_rounded, Colors.deepOrange),
        ),
      ],
    );
  }

  Widget _buildMetricTile(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color.withOpacity(0.85), fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarFilterChips() {
    final filters = ['All', 'Tests', 'Exams', 'Meetings', 'Holidays'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _calendarFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                f,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surface,
              onSelected: (_) => setState(() => _calendarFilter = f),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEventCard(CalendarEvent event) {
    Color badgeColor = AppColors.primary;
    IconData icon = Icons.event_rounded;

    if (event.category == 'internal_test') {
      badgeColor = Colors.orange;
      icon = Icons.assignment_rounded;
    } else if (event.category == 'exam') {
      badgeColor = Colors.redAccent;
      icon = Icons.edit_document;
    } else if (event.category == 'meeting') {
      badgeColor = Colors.purple;
      icon = Icons.group_rounded;
    } else if (event.category == 'holiday') {
      badgeColor = Colors.green;
      icon = Icons.beach_access_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: badgeColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ),
                    if (event.workingDays.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'WD: ${event.workingDays}',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  event.dateDescription,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySummarySection(AcademicCalendar cal) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Working Days & Public Holidays',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
          ),
          const Divider(height: 18),
          ...cal.monthSummaries.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 90,
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${m.month}\n(${m.workingDays} Days)',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Public Holidays:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          ...m.holidays.map((h) => Text('• $h', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildAssessmentReportsSection(AcademicCalendar cal) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Autonomous Assessment & CoE Webportal Entry',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
          ),
          const Divider(height: 18),
          ...cal.assessmentReports.map((rep) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        rep.reportNo,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rep.entryDetails, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textPrimary)),
                          Text('Period: ${rep.reportPeriod}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          Text('CoE Portal Entry: ${rep.entryDate} (${rep.totalPeriods})', style: const TextStyle(fontSize: 11, color: Colors.blueAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildGeneralNotesSection(AcademicCalendar cal) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Key Circular Instructions & Adherence Rules',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
          ),
          const Divider(height: 18),
          ...cal.generalNotes.map((note) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  note,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildCustomDocumentCard(String imageBase64, String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.attachment_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            child: _renderBase64Image(imageBase64),
          ),
        ],
      ),
    );
  }

  Widget _renderBase64Image(String raw) {
    try {
      String clean = raw;
      if (clean.contains(',')) {
        clean = clean.split(',')[1];
      }
      final bytes = base64Decode(clean);
      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        width: double.infinity,
      );
    } catch (e) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        color: Colors.grey.withOpacity(0.1),
        child: const Text('Unable to preview document image'),
      );
    }
  }
}
