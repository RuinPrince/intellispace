import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/academic_timetable.dart';
import '../../../repositories/academic_schedule_repository.dart';

enum PeriodState {
  beforeCollege,
  inClass,
  inBreak,
  inLunch,
  afterCollege,
  holiday,
}

class PeriodStatusInfo {
  final PeriodState state;
  final TimetablePeriod? currentPeriod;
  final TimetablePeriod? nextPeriod;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final double progress; // 0.0 to 1.0
  final int minutesRemaining;
  final int totalMinutes;
  final String statusTitle;
  final String statusSubtitle;

  const PeriodStatusInfo({
    required this.state,
    this.currentPeriod,
    this.nextPeriod,
    this.periodStart,
    this.periodEnd,
    this.progress = 0.0,
    this.minutesRemaining = 0,
    this.totalMinutes = 45,
    required this.statusTitle,
    required this.statusSubtitle,
  });
}

class LiveOngoingPeriodWidget extends StatefulWidget {
  final String initialSection;

  const LiveOngoingPeriodWidget({
    super.key,
    this.initialSection = 'A',
  });

  @override
  State<LiveOngoingPeriodWidget> createState() => _LiveOngoingPeriodWidgetState();
}

class _LiveOngoingPeriodWidgetState extends State<LiveOngoingPeriodWidget> with SingleTickerProviderStateMixin {
  late String _currentSection;
  int _dayOrder = 1;
  Timer? _timer;
  SectionTimetable? _timetable;
  bool _isLoading = true;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _currentSection = widget.initialSection;
    _dayOrder = _getAutomaticDayOrder();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadTimetable();

    // Auto update live timer every 10 seconds
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  int _getAutomaticDayOrder() {
    final now = DateTime.now();
    switch (now.weekday) {
      case DateTime.monday:
        return 1;
      case DateTime.tuesday:
        return 2;
      case DateTime.wednesday:
        return 3;
      case DateTime.thursday:
        return 4;
      case DateTime.friday:
        return 5;
      case DateTime.saturday:
        return 1; // Default for compensatory working Saturdays
      default:
        return 1;
    }
  }

  Future<void> _loadTimetable() async {
    final tt = await AcademicScheduleRepository.getTimetable(_currentSection);
    if (mounted) {
      setState(() {
        _timetable = tt;
        _isLoading = false;
      });
    }
  }

  void _switchSection(String section) {
    if (_currentSection == section) return;
    setState(() {
      _currentSection = section;
      _isLoading = true;
    });
    _loadTimetable();
  }

  DateTime _parseTimeString(String rawTime, DateTime now) {
    // Normalizes "09.15", "09:15", "01.20", "13:20"
    final clean = rawTime.trim().replaceAll(':', '.');
    final parts = clean.split('.');
    int hour = int.tryParse(parts[0]) ?? 9;
    int minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    // College hours are 9 AM to 5 PM. If hour is 1, 2, 3, 4, 5, it means afternoon (PM).
    if (hour < 7) {
      hour += 12;
    }

    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  PeriodStatusInfo _calculateCurrentPeriod(SectionTimetable tt) {
    final now = DateTime.now();

    // Check Sunday
    if (now.weekday == DateTime.sunday) {
      return const PeriodStatusInfo(
        state: PeriodState.holiday,
        statusTitle: 'Sunday / College Holiday',
        statusSubtitle: 'Classes will resume on Monday at 09:15 AM (Day 1).',
      );
    }

    final daySchedule = tt.days.firstWhere(
      (d) => d.dayOrder == _dayOrder,
      orElse: () => tt.days.isNotEmpty ? tt.days.first : const DaySchedule(dayOrder: 1, dayName: 'DAY 1', periods: []),
    );

    if (daySchedule.periods.isEmpty) {
      return const PeriodStatusInfo(
        state: PeriodState.holiday,
        statusTitle: 'No Schedule Configured',
        statusSubtitle: 'No active timetable for the selected day order.',
      );
    }

    // Parse all periods with actual start/end datetimes for today
    final List<Map<String, dynamic>> parsedPeriods = [];
    for (final p in daySchedule.periods) {
      final rangeParts = p.timeRange.split('-');
      if (rangeParts.length < 2) continue;
      final start = _parseTimeString(rangeParts[0], now);
      final end = _parseTimeString(rangeParts[1], now);
      parsedPeriods.add({
        'period': p,
        'start': start,
        'end': end,
      });
    }

    if (parsedPeriods.isEmpty) {
      return const PeriodStatusInfo(
        state: PeriodState.holiday,
        statusTitle: 'Schedule Inactive',
        statusSubtitle: 'Check academic calendar for updates.',
      );
    }

    final firstStart = parsedPeriods.first['start'] as DateTime;
    final lastEnd = parsedPeriods.last['end'] as DateTime;

    // 1. Before college start
    if (now.isBefore(firstStart)) {
      final firstP = parsedPeriods.first['period'] as TimetablePeriod;
      final diffMins = firstStart.difference(now).inMinutes;
      final timeFormatted = DateFormat('hh:mm a').format(firstStart);
      return PeriodStatusInfo(
        state: PeriodState.beforeCollege,
        nextPeriod: firstP,
        periodStart: firstStart,
        minutesRemaining: diffMins,
        statusTitle: 'College Commences at $timeFormatted',
        statusSubtitle: 'Starts in $diffMins mins: Period I (${firstP.subjectAbbr}) in ${firstP.roomOrLab}',
      );
    }

    // 2. After college end
    if (now.isAfter(lastEnd)) {
      return PeriodStatusInfo(
        state: PeriodState.afterCollege,
        periodEnd: lastEnd,
        statusTitle: 'Classes Concluded for Today',
        statusSubtitle: 'All 8 periods completed. Classes resume tomorrow at 09:15 AM.',
      );
    }

    // 3. Find ongoing period
    for (int i = 0; i < parsedPeriods.length; i++) {
      final item = parsedPeriods[i];
      final start = item['start'] as DateTime;
      final end = item['end'] as DateTime;
      final p = item['period'] as TimetablePeriod;

      if (now.isAfter(start) && now.isBefore(end) || now.isAtSameMomentAs(start)) {
        final totalMins = end.difference(start).inMinutes;
        final elapsedMins = now.difference(start).inMinutes;
        final remainingMins = end.difference(now).inMinutes;
        final progress = (totalMins > 0 ? (elapsedMins / totalMins) : 0.0).clamp(0.0, 1.0);

        final nextP = (i + 1 < parsedPeriods.length) ? (parsedPeriods[i + 1]['period'] as TimetablePeriod) : null;

        if (p.isBreak) {
          return PeriodStatusInfo(
            state: PeriodState.inBreak,
            currentPeriod: p,
            nextPeriod: nextP,
            periodStart: start,
            periodEnd: end,
            progress: progress,
            minutesRemaining: remainingMins,
            totalMinutes: totalMins,
            statusTitle: 'Break Time (${p.timeRange})',
            statusSubtitle: '$remainingMins mins left until ${nextP?.label ?? "next class"} (${nextP?.subjectAbbr ?? ""})',
          );
        } else if (p.isLunch) {
          return PeriodStatusInfo(
            state: PeriodState.inLunch,
            currentPeriod: p,
            nextPeriod: nextP,
            periodStart: start,
            periodEnd: end,
            progress: progress,
            minutesRemaining: remainingMins,
            totalMinutes: totalMins,
            statusTitle: 'Lunch Interval (${p.timeRange})',
            statusSubtitle: '$remainingMins mins remaining • Resumes with ${nextP?.label ?? "Period V"} (${nextP?.subjectAbbr ?? ""})',
          );
        } else {
          return PeriodStatusInfo(
            state: PeriodState.inClass,
            currentPeriod: p,
            nextPeriod: nextP,
            periodStart: start,
            periodEnd: end,
            progress: progress,
            minutesRemaining: remainingMins,
            totalMinutes: totalMins,
            statusTitle: 'Period ${p.label} (${p.timeRange})',
            statusSubtitle: '${p.subjectTitle.isNotEmpty ? p.subjectTitle : p.subjectAbbr} • ${p.roomOrLab}',
          );
        }
      }
    }

    // Default fallback to first period preview
    final firstP = parsedPeriods.first['period'] as TimetablePeriod;
    return PeriodStatusInfo(
      state: PeriodState.inClass,
      currentPeriod: firstP,
      statusTitle: 'Period ${firstP.label} (${firstP.timeRange})',
      statusSubtitle: '${firstP.subjectAbbr} • ${firstP.roomOrLab}',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _timetable == null) {
      return Container(
        height: 140,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
        ),
      );
    }

    final tt = _timetable!;
    final info = _calculateCurrentPeriod(tt);
    final p = info.currentPeriod;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E1B4B), // Deep Indigo / Slate Navy
            const Color(0xFF312E81),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header: Section Switcher & Day Order & Full Timetable Link
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Live Pulse Beacon + Status Tag
                Row(
                  children: [
                    FadeTransition(
                      opacity: _pulseAnimation,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: info.state == PeriodState.inClass
                              ? const Color(0xFF10B981) // Emerald Green
                              : (info.state == PeriodState.inBreak || info.state == PeriodState.inLunch
                                  ? const Color(0xFFF59E0B) // Amber
                                  : Colors.cyanAccent),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.6),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      info.state == PeriodState.inClass
                          ? 'NOW LIVE'
                          : (info.state == PeriodState.inBreak
                              ? 'BREAK TIME'
                              : (info.state == PeriodState.inLunch ? 'LUNCH BREAK' : 'SCHEDULE')),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'DAY $_dayOrder',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                // Section Toggle (Section A vs Section B)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSectionTab('A'),
                      _buildSectionTab('B'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Class / Period Presentation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Period timing and label
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      info.statusTitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (info.state == PeriodState.inClass && p != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          p.roomOrLab,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                // Primary Subject Title & Abbreviation
                if (info.state == PeriodState.inClass && p != null) ...[
                  Text(
                    '${p.subjectTitle.isNotEmpty ? p.subjectTitle : p.subjectAbbr} (${p.subjectAbbr})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Faculty Name
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 14, color: Colors.white70),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          p.facultyName.isNotEmpty ? p.facultyName : 'IT Department Faculty',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (p.facultyCode.isNotEmpty)
                        Text(
                          'Code: ${p.facultyCode}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ] else ...[
                  Text(
                    info.statusSubtitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Live Progress Bar & Timer Countdown
          if (info.state == PeriodState.inClass || info.state == PeriodState.inBreak || info.state == PeriodState.inLunch)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 13, color: Colors.cyanAccent),
                          const SizedBox(width: 4),
                          Text(
                            '${info.minutesRemaining} mins remaining',
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${(info.progress * 100).round()}% passed',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Animated gradient progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        Container(
                          height: 7,
                          width: double.infinity,
                          color: Colors.white.withOpacity(0.15),
                        ),
                        FractionallySizedBox(
                          widthFactor: info.progress,
                          child: Container(
                            height: 7,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: info.state == PeriodState.inClass
                                    ? [const Color(0xFF10B981), const Color(0xFF34D399)]
                                    : [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // Bottom Bar: Upcoming Next Period & "View Timetable" Link
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.skip_next_rounded, size: 16, color: Colors.white.withOpacity(0.7)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          info.nextPeriod != null
                              ? 'Up Next (${info.nextPeriod!.timeRange.split("-").first.trim()}): ${info.nextPeriod!.label} - ${info.nextPeriod!.subjectAbbr}'
                              : (info.state == PeriodState.afterCollege ? 'Classes Completed' : 'Next: Day Cycle'),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => context.push('/more/schedule?section=$_currentSection'),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      children: const [
                        Text(
                          'Timetable',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTab(String section) {
    final isSelected = _currentSection == section;
    return GestureDetector(
      onTap: () => _switchSection(section),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Sec $section',
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
