import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';
import '../models/academic_timetable.dart';
import '../models/academic_calendar.dart';

/// Repository for Academic Timetables (Sections A & B) and Academic Calendar (Circular 321)
/// Supports local persistence, document/image uploads, and cloud sync via Supabase.
class AcademicScheduleRepository {
  static final ApiClient _api = ApiClient();
  static bool _initialized = false;

  static const String _keyTimetableA = 'academic_timetable_sec_a';
  static const String _keyTimetableB = 'academic_timetable_sec_b';
  static const String _keyCalendar = 'academic_calendar_circular_321';

  static SectionTimetable? _cachedTimetableA;
  static SectionTimetable? _cachedTimetableB;
  static AcademicCalendar? _cachedCalendar;

  /// Default Official Subject Allocation from KLNCE IT Dept Timetable
  static const List<SubjectAllocation> defaultSubjectsSecA = [
    SubjectAllocation(
      code: '20CSV12',
      title: 'Social Network Analysis (Professional Elective V)',
      abbr: 'SNA',
      facultyName: 'Mrs. I. Muthumeenakshi, AP/IT',
      facultyCode: '10535061',
      totalHours: 4,
      venue: 'M.E.-02',
    ),
    SubjectAllocation(
      code: '20ITV43',
      title: 'Software Testing and Automation (Professional Elective IV)',
      abbr: 'STA',
      facultyName: 'Mrs. D. Nirmala Devi, AP/IT',
      facultyCode: '10535067',
      totalHours: 4,
      venue: 'M.E.-02',
    ),
    SubjectAllocation(
      code: '20CSV74',
      title: 'Agile Methodologies (Professional Elective VI)',
      abbr: 'AM',
      facultyName: 'Ms. Nagalakshmi, AP/IT',
      facultyCode: '10535070',
      totalHours: 4,
      venue: 'M.E.-02',
    ),
    SubjectAllocation(
      code: '20OE108',
      title: 'Industry Safety Practices (Open Elective II)',
      abbr: 'ISP',
      facultyName: 'Mr. Nalla Thambi, AP/Mech',
      facultyCode: '10135026',
      totalHours: 4,
      venue: 'M.E.-02',
    ),
    SubjectAllocation(
      code: '20HS7A2',
      title: 'Total Quality Management (Management Elective)',
      abbr: 'TQM',
      facultyName: 'Dr. D. Pradeepkannan, Prof. & MR',
      facultyCode: '10709003',
      totalHours: 4,
      venue: 'M.E.-02',
    ),
    SubjectAllocation(
      code: '20IT701',
      title: 'Cryptography Concepts and Techniques (T Cum P)',
      abbr: 'CCT',
      facultyName: 'Mrs. K. Rani, AP/IT',
      facultyCode: '10535062',
      totalHours: 3,
      venue: 'M.E.-02',
    ),
    SubjectAllocation(
      code: 'SKILL RACK',
      title: 'Skill Rack (MPMC Lab, Foss Lab, DBMS Lab)',
      abbr: 'SKILL RACK',
      facultyName: 'AS, JMM, TSN, SVS, PNL',
      facultyCode: 'SR-STAFF',
      totalHours: 10,
      isPractical: true,
      venue: 'MP & MC Lab / FOSS Lab / DBMS Lab',
    ),
    SubjectAllocation(
      code: '20IT701 (Lab)',
      title: 'Cryptography Concepts and Techniques Lab',
      abbr: 'CCT LAB',
      facultyName: 'Mrs. K. Rani, AP/IT',
      facultyCode: '10535062',
      totalHours: 3,
      isPractical: true,
      venue: 'CCT Lab - MP & MC Lab',
    ),
    SubjectAllocation(
      code: '20IT7L1',
      title: 'Mini Project - 2',
      abbr: 'MINI PROJECT',
      facultyName: 'Mrs. K. Rani, AP/IT',
      facultyCode: '10535062',
      totalHours: 4,
      isPractical: true,
      venue: 'DBMS & Case Tools Lab',
    ),
  ];

  /// Default Official 5-Day Schedule for Section A (Matching Official Image 1)
  static final List<DaySchedule> defaultDaysSecA = [
    // DAY 1
    const DaySchedule(
      dayOrder: 1,
      dayName: 'DAY 1',
      periods: [
        TimetablePeriod(periodNumber: 1, label: 'I', timeRange: '09.15 - 10.05', subjectAbbr: 'AM', subjectTitle: 'Agile Methodologies', facultyName: 'Ms. Nagalakshmi, AP/IT'),
        TimetablePeriod(periodNumber: 2, label: 'II', timeRange: '10.05 - 10.55', subjectAbbr: 'CCT', subjectTitle: 'Cryptography Concepts & Techniques', facultyName: 'Mrs. K. Rani, AP/IT'),
        TimetablePeriod(periodNumber: 0, label: 'BREAK', timeRange: '10.55 - 11.10', subjectAbbr: 'BREAK', isBreak: true),
        TimetablePeriod(periodNumber: 3, label: 'III', timeRange: '11.10 - 11.55', subjectAbbr: 'SNA', subjectTitle: 'Social Network Analysis', facultyName: 'Mrs. I. Muthumeenakshi, AP/IT'),
        TimetablePeriod(periodNumber: 4, label: 'IV', timeRange: '11.55 - 12.40', subjectAbbr: 'STA', subjectTitle: 'Software Testing and Automation', facultyName: 'Mrs. D. Nirmala Devi, AP/IT'),
        TimetablePeriod(periodNumber: 0, label: 'LUNCH', timeRange: '12.40 - 01.20', subjectAbbr: 'LUNCH', isLunch: true),
        TimetablePeriod(periodNumber: 5, label: 'V', timeRange: '01.20 - 02.05', subjectAbbr: 'MINI PROJECT', subjectTitle: 'Mini Project - 2', roomOrLab: 'DBMS & Case Tools Lab', facultyName: 'Mrs. K. Rani, AP/IT'),
        TimetablePeriod(periodNumber: 6, label: 'VI', timeRange: '02.05 - 02.50', subjectAbbr: 'MINI PROJECT', subjectTitle: 'Mini Project - 2', roomOrLab: 'DBMS & Case Tools Lab', facultyName: 'Mrs. K. Rani, AP/IT'),
        TimetablePeriod(periodNumber: 0, label: 'BREAK', timeRange: '02.50 - 03.00', subjectAbbr: 'BREAK', isBreak: true),
        TimetablePeriod(periodNumber: 7, label: 'VII', timeRange: '03.00 - 03.45', subjectAbbr: 'MINI PROJECT', subjectTitle: 'Mini Project - 2', roomOrLab: 'DBMS & Case Tools Lab', facultyName: 'Mrs. K. Rani, AP/IT'),
        TimetablePeriod(periodNumber: 8, label: 'VIII', timeRange: '03.45 - 04.30', subjectAbbr: 'MINI PROJECT', subjectTitle: 'Mini Project - 2', roomOrLab: 'DBMS & Case Tools Lab', facultyName: 'Mrs. K. Rani, AP/IT'),
      ],
    ),
    // DAY 2
    const DaySchedule(
      dayOrder: 2,
      dayName: 'DAY 2',
      periods: [
        TimetablePeriod(periodNumber: 1, label: 'I', timeRange: '09.15 - 10.05', subjectAbbr: 'ISP', subjectTitle: 'Industry Safety Practices', facultyName: 'Mr. Nalla Thambi, AP/Mech'),
        TimetablePeriod(periodNumber: 2, label: 'II', timeRange: '10.05 - 10.55', subjectAbbr: 'STA', subjectTitle: 'Software Testing and Automation', facultyName: 'Mrs. D. Nirmala Devi, AP/IT'),
        TimetablePeriod(periodNumber: 0, label: 'BREAK', timeRange: '10.55 - 11.10', subjectAbbr: 'BREAK', isBreak: true),
        TimetablePeriod(periodNumber: 3, label: 'III', timeRange: '11.10 - 11.55', subjectAbbr: 'CCT', subjectTitle: 'Cryptography Concepts & Techniques', facultyName: 'Mrs. K. Rani, AP/IT'),
        TimetablePeriod(periodNumber: 4, label: 'IV', timeRange: '11.55 - 12.40', subjectAbbr: 'TQM', subjectTitle: 'Total Quality Management', facultyName: 'Dr. D. Pradeepkannan, Prof. & MR'),
        TimetablePeriod(periodNumber: 0, label: 'LUNCH', timeRange: '12.40 - 01.20', subjectAbbr: 'LUNCH', isLunch: true),
        TimetablePeriod(periodNumber: 5, label: 'V', timeRange: '01.20 - 02.05', subjectAbbr: 'AM', subjectTitle: 'Agile Methodologies', facultyName: 'Ms. Nagalakshmi, AP/IT'),
        TimetablePeriod(periodNumber: 6, label: 'VI', timeRange: '02.05 - 02.50', subjectAbbr: 'SNA', subjectTitle: 'Social Network Analysis', facultyName: 'Mrs. I. Muthumeenakshi, AP/IT'),
        TimetablePeriod(periodNumber: 0, label: 'BREAK', timeRange: '02.50 - 03.00', subjectAbbr: 'BREAK', isBreak: true),
        TimetablePeriod(periodNumber: 7, label: 'VII', timeRange: '03.00 - 03.45', subjectAbbr: 'SKILL RACK', subjectTitle: 'Skill Rack / AS', roomOrLab: 'MP & MC Lab', facultyName: 'AS / MP & MC Lab'),
        TimetablePeriod(periodNumber: 8, label: 'VIII', timeRange: '03.45 - 04.30', subjectAbbr: 'SKILL RACK', subjectTitle: 'Skill Rack / AS', roomOrLab: 'MP & MC Lab', facultyName: 'AS / MP & MC Lab'),
      ],
    ),
    // DAY 3
    const DaySchedule(
      dayOrder: 3,
      dayName: 'DAY 3',
      periods: [
        TimetablePeriod(periodNumber: 1, label: 'I', timeRange: '09.15 - 10.05', subjectAbbr: 'SKILL RACK', subjectTitle: 'Skill Rack / JMM', roomOrLab: 'FOSS Lab', facultyName: 'Mrs. I. Muthumeenakshi'),
        TimetablePeriod(periodNumber: 2, label: 'II', timeRange: '10.05 - 10.55', subjectAbbr: 'SKILL RACK', subjectTitle: 'Skill Rack / JMM', roomOrLab: 'FOSS Lab', facultyName: 'Mrs. I. Muthumeenakshi'),
        TimetablePeriod(periodNumber: 0, label: 'BREAK', timeRange: '10.55 - 11.10', subjectAbbr: 'BREAK', isBreak: true),
        TimetablePeriod(periodNumber: 3, label: 'III', timeRange: '11.10 - 11.55', subjectAbbr: 'ISP', subjectTitle: 'Industry Safety Practices', facultyName: 'Mr. Nalla Thambi, AP/Mech'),
        TimetablePeriod(periodNumber: 4, label: 'IV', timeRange: '11.55 - 12.40', subjectAbbr: 'SNA', subjectTitle: 'Social Network Analysis', facultyName: 'Mrs. I. Muthumeenakshi, AP/IT'),
        TimetablePeriod(periodNumber: 0, label: 'LUNCH', timeRange: '12.40 - 01.20', subjectAbbr: 'LUNCH', isLunch: true),
        TimetablePeriod(periodNumber: 5, label: 'V', timeRange: '01.20 - 02.05', subjectAbbr: 'CCT', subjectTitle: 'Cryptography Concepts & Techniques', facultyName: 'Mrs. K. Rani, AP/IT'),
        TimetablePeriod(periodNumber: 6, label: 'VI', timeRange: '02.05 - 02.50', subjectAbbr: 'AM', subjectTitle: 'Agile Methodologies', facultyName: 'Ms. Nagalakshmi, AP/IT'),
        TimetablePeriod(periodNumber: 0, label: 'BREAK', timeRange: '02.50 - 03.00', subjectAbbr: 'BREAK', isBreak: true),
        TimetablePeriod(periodNumber: 7, label: 'VII', timeRange: '03.00 - 03.45', subjectAbbr: 'TQM', subjectTitle: 'Total Quality Management', facultyName: 'Dr. D. Pradeepkannan, Prof. & MR'),
        TimetablePeriod(periodNumber: 8, label: 'VIII', timeRange: '03.45 - 04.30', subjectAbbr: 'STA', subjectTitle: 'Software Testing and Automation', facultyName: 'Mrs. D. Nirmala Devi, AP/IT'),
      ],
    ),
    // DAY 4
    const DaySchedule(
      dayOrder: 4,
      dayName: 'DAY 4',
      periods: [
        TimetablePeriod(periodNumber: 1, label: 'I', timeRange: '09.15 - 10.05', subjectAbbr: 'SNA', subjectTitle: 'Social Network Analysis', facultyName: 'Mrs. I. Muthumeenakshi, AP/IT'),
        TimetablePeriod(periodNumber: 2, label: 'II', timeRange: '10.05 - 10.55', subjectAbbr: 'TQM', subjectTitle: 'Total Quality Management', facultyName: 'Dr. D. Pradeepkannan, Prof. & MR'),
        TimetablePeriod(periodNumber: 0, label: 'BREAK', timeRange: '10.55 - 11.10', subjectAbbr: 'BREAK', isBreak: true),
        TimetablePeriod(periodNumber: 3, label: 'III', timeRange: '11.10 - 11.55', subjectAbbr: 'SKILL RACK', subjectTitle: 'Skill Rack / TSN', roomOrLab: 'DBMS Lab', facultyName: 'TSN / DBMS Lab'),
        TimetablePeriod(periodNumber: 4, label: 'IV', timeRange: '11.55 - 12.40', subjectAbbr: 'SKILL RACK', subjectTitle: 'Skill Rack / TSN', roomOrLab: 'DBMS Lab', facultyName: 'TSN / DBMS Lab'),
        TimetablePeriod(periodNumber: 0, label: 'LUNCH', timeRange: '12.40 - 01.20', subjectAbbr: 'LUNCH', isLunch: true),
        TimetablePeriod(periodNumber: 5, label: 'V', timeRange: '01.20 - 02.05', subjectAbbr: 'TQM', subjectTitle: 'Total Quality Management', facultyName: 'Dr. D. Pradeepkannan, Prof. & MR'),
        TimetablePeriod(periodNumber: 6, label: 'VI', timeRange: '02.05 - 02.50', subjectAbbr: 'SKILL RACK', subjectTitle: 'Skill Rack / SVS', roomOrLab: 'MP & MC Lab', facultyName: 'SVS / MP & MC Lab'),
        TimetablePeriod(periodNumber: 0, label: 'BREAK', timeRange: '02.50 - 03.00', subjectAbbr: 'BREAK', isBreak: true),
        TimetablePeriod(periodNumber: 7, label: 'VII', timeRange: '03.00 - 03.45', subjectAbbr: 'SKILL RACK', subjectTitle: 'Skill Rack / SVS', roomOrLab: 'MP & MC Lab', facultyName: 'SVS / MP & MC Lab'),
        TimetablePeriod(periodNumber: 8, label: 'VIII', timeRange: '03.45 - 04.30', subjectAbbr: 'ISP', subjectTitle: 'Industry Safety Practices', facultyName: 'Mr. Nalla Thambi, AP/Mech'),
      ],
    ),
    // DAY 5
    const DaySchedule(
      dayOrder: 5,
      dayName: 'DAY 5',
      periods: [
        TimetablePeriod(periodNumber: 1, label: 'I', timeRange: '09.15 - 10.05', subjectAbbr: 'AM', subjectTitle: 'Agile Methodologies', facultyName: 'Ms. Nagalakshmi, AP/IT'),
        TimetablePeriod(periodNumber: 2, label: 'II', timeRange: '10.05 - 10.55', subjectAbbr: 'ISP', subjectTitle: 'Industry Safety Practices', facultyName: 'Mr. Nalla Thambi, AP/Mech'),
        TimetablePeriod(periodNumber: 0, label: 'BREAK', timeRange: '10.55 - 11.10', subjectAbbr: 'BREAK', isBreak: true),
        TimetablePeriod(periodNumber: 3, label: 'III', timeRange: '11.10 - 11.55', subjectAbbr: 'SKILL RACK', subjectTitle: 'Skill Rack / PNL', roomOrLab: 'MP & MC Lab', facultyName: 'PNL / MP & MC Lab'),
        TimetablePeriod(periodNumber: 4, label: 'IV', timeRange: '11.55 - 12.40', subjectAbbr: 'SKILL RACK', subjectTitle: 'Skill Rack / PNL', roomOrLab: 'MP & MC Lab', facultyName: 'PNL / MP & MC Lab'),
        TimetablePeriod(periodNumber: 0, label: 'LUNCH', timeRange: '12.40 - 01.20', subjectAbbr: 'LUNCH', isLunch: true),
        TimetablePeriod(periodNumber: 5, label: 'V', timeRange: '01.20 - 02.05', subjectAbbr: 'STA', subjectTitle: 'Software Testing and Automation', facultyName: 'Mrs. D. Nirmala Devi, AP/IT'),
        TimetablePeriod(periodNumber: 6, label: 'VI', timeRange: '02.05 - 02.50', subjectAbbr: 'CCT LAB', subjectTitle: 'Cryptography Concepts & Techniques Lab', roomOrLab: 'CCT Lab - MP & MC Lab', facultyName: 'Mrs. K. Rani, AP/IT'),
        TimetablePeriod(periodNumber: 0, label: 'BREAK', timeRange: '02.50 - 03.00', subjectAbbr: 'BREAK', isBreak: true),
        TimetablePeriod(periodNumber: 7, label: 'VII', timeRange: '03.00 - 03.45', subjectAbbr: 'CCT LAB', subjectTitle: 'Cryptography Concepts & Techniques Lab', roomOrLab: 'CCT Lab - MP & MC Lab', facultyName: 'Mrs. K. Rani, AP/IT'),
        TimetablePeriod(periodNumber: 8, label: 'VIII', timeRange: '03.45 - 04.30', subjectAbbr: 'CCT LAB', subjectTitle: 'Cryptography Concepts & Techniques Lab', roomOrLab: 'CCT Lab - MP & MC Lab', facultyName: 'Mrs. K. Rani, AP/IT'),
      ],
    ),
  ];

  /// Section A Default Timetable
  static final SectionTimetable defaultTimetableA = SectionTimetable(
    department: 'Department of Information Technology',
    course: 'B.Tech. IT',
    batch: '2023-2027',
    academicYear: '2026 - 2027 (ODD)',
    yearSemesterSection: 'IV / VII / A',
    section: 'A',
    roomNo: 'M.E.-02',
    classInCharge: 'Mrs. K. Rani, AP/IT',
    inChargeCode: '10535062',
    effectiveDate: '20/07/2026 Rev:2',
    days: defaultDaysSecA,
    subjects: defaultSubjectsSecA,
  );

  /// Section B Default Timetable (Configured for Section B with parallel subjects and faculty)
  static final SectionTimetable defaultTimetableB = SectionTimetable(
    department: 'Department of Information Technology',
    course: 'B.Tech. IT',
    batch: '2023-2027',
    academicYear: '2026 - 2027 (ODD)',
    yearSemesterSection: 'IV / VII / B',
    section: 'B',
    roomNo: 'M.E.-03',
    classInCharge: 'Mrs. D. Nirmala Devi, AP/IT',
    inChargeCode: '10535067',
    effectiveDate: '20/07/2026 Rev:2',
    days: [
      // Day 1 for Section B
      const DaySchedule(
        dayOrder: 1,
        dayName: 'DAY 1',
        periods: [
          TimetablePeriod(periodNumber: 1, label: 'I', timeRange: '09.15 - 10.05', subjectAbbr: 'STA', subjectTitle: 'Software Testing and Automation', facultyName: 'Mrs. D. Nirmala Devi, AP/IT'),
          TimetablePeriod(periodNumber: 2, label: 'II', timeRange: '10.05 - 10.55', subjectAbbr: 'SNA', subjectTitle: 'Social Network Analysis', facultyName: 'Mrs. I. Muthumeenakshi, AP/IT'),
          TimetablePeriod(periodNumber: 0, label: 'BREAK', timeRange: '10.55 - 11.10', subjectAbbr: 'BREAK', isBreak: true),
          TimetablePeriod(periodNumber: 3, label: 'III', timeRange: '11.10 - 11.55', subjectAbbr: 'AM', subjectTitle: 'Agile Methodologies', facultyName: 'Ms. Nagalakshmi, AP/IT'),
          TimetablePeriod(periodNumber: 4, label: 'IV', timeRange: '11.55 - 12.40', subjectAbbr: 'CCT', subjectTitle: 'Cryptography Concepts & Techniques', facultyName: 'Mrs. K. Rani, AP/IT'),
          TimetablePeriod(periodNumber: 0, label: 'LUNCH', timeRange: '12.40 - 01.20', subjectAbbr: 'LUNCH', isLunch: true),
          TimetablePeriod(periodNumber: 5, label: 'V', timeRange: '01.20 - 02.05', subjectAbbr: 'TQM', subjectTitle: 'Total Quality Management', facultyName: 'Dr. D. Pradeepkannan, Prof. & MR'),
          TimetablePeriod(periodNumber: 6, label: 'VI', timeRange: '02.05 - 02.50', subjectAbbr: 'ISP', subjectTitle: 'Industry Safety Practices', facultyName: 'Mr. Nalla Thambi, AP/Mech'),
          TimetablePeriod(periodNumber: 0, label: 'BREAK', timeRange: '02.50 - 03.00', subjectAbbr: 'BREAK', isBreak: true),
          TimetablePeriod(periodNumber: 7, label: 'VII', timeRange: '03.00 - 03.45', subjectAbbr: 'SKILL RACK', subjectTitle: 'Skill Rack / AS', roomOrLab: 'MP & MC Lab', facultyName: 'AS / MP & MC Lab'),
          TimetablePeriod(periodNumber: 8, label: 'VIII', timeRange: '03.45 - 04.30', subjectAbbr: 'SKILL RACK', subjectTitle: 'Skill Rack / AS', roomOrLab: 'MP & MC Lab', facultyName: 'AS / MP & MC Lab'),
        ],
      ),
      // Day 2 for Section B
      const DaySchedule(
        dayOrder: 2,
        dayName: 'DAY 2',
        periods: [
          TimetablePeriod(periodNumber: 1, label: 'I', timeRange: '09.15 - 10.05', subjectAbbr: 'CCT', subjectTitle: 'Cryptography Concepts & Techniques', facultyName: 'Mrs. K. Rani, AP/IT'),
          TimetablePeriod(periodNumber: 2, label: 'II', timeRange: '10.05 - 10.55', subjectAbbr: 'AM', subjectTitle: 'Agile Methodologies', facultyName: 'Ms. Nagalakshmi, AP/IT'),
          TimetablePeriod(periodNumber: 0, label: 'BREAK', timeRange: '10.55 - 11.10', subjectAbbr: 'BREAK', isBreak: true),
          TimetablePeriod(periodNumber: 3, label: 'III', timeRange: '11.10 - 11.55', subjectAbbr: 'STA', subjectTitle: 'Software Testing and Automation', facultyName: 'Mrs. D. Nirmala Devi, AP/IT'),
          TimetablePeriod(periodNumber: 4, label: 'IV', timeRange: '11.55 - 12.40', subjectAbbr: 'ISP', subjectTitle: 'Industry Safety Practices', facultyName: 'Mr. Nalla Thambi, AP/Mech'),
          TimetablePeriod(periodNumber: 0, label: 'LUNCH', timeRange: '12.40 - 01.20', subjectAbbr: 'LUNCH', isLunch: true),
          TimetablePeriod(periodNumber: 5, label: 'V', timeRange: '01.20 - 02.05', subjectAbbr: 'MINI PROJECT', subjectTitle: 'Mini Project - 2', roomOrLab: 'DBMS & Case Tools Lab', facultyName: 'Mrs. D. Nirmala Devi'),
          TimetablePeriod(periodNumber: 6, label: 'VI', timeRange: '02.05 - 02.50', subjectAbbr: 'MINI PROJECT', subjectTitle: 'Mini Project - 2', roomOrLab: 'DBMS & Case Tools Lab', facultyName: 'Mrs. D. Nirmala Devi'),
          TimetablePeriod(periodNumber: 0, label: 'BREAK', timeRange: '02.50 - 03.00', subjectAbbr: 'BREAK', isBreak: true),
          TimetablePeriod(periodNumber: 7, label: 'VII', timeRange: '03.00 - 03.45', subjectAbbr: 'MINI PROJECT', subjectTitle: 'Mini Project - 2', roomOrLab: 'DBMS & Case Tools Lab', facultyName: 'Mrs. D. Nirmala Devi'),
          TimetablePeriod(periodNumber: 8, label: 'VIII', timeRange: '03.45 - 04.30', subjectAbbr: 'MINI PROJECT', subjectTitle: 'Mini Project - 2', roomOrLab: 'DBMS & Case Tools Lab', facultyName: 'Mrs. D. Nirmala Devi'),
        ],
      ),
      // Day 3 for Section B
      const DaySchedule(
        dayOrder: 3,
        dayName: 'DAY 3',
        periods: [
          TimetablePeriod(periodNumber: 1, label: 'I', timeRange: '09.15 - 10.05', subjectAbbr: 'SNA', subjectTitle: 'Social Network Analysis', facultyName: 'Mrs. I. Muthumeenakshi, AP/IT'),
          TimetablePeriod(periodNumber: 2, label: 'II', timeRange: '10.05 - 10.55', subjectAbbr: 'TQM', subjectTitle: 'Total Quality Management', facultyName: 'Dr. D. Pradeepkannan, Prof. & MR'),
          TimetablePeriod(periodNumber: 0, label: 'BREAK', timeRange: '10.55 - 11.10', subjectAbbr: 'BREAK', isBreak: true),
          TimetablePeriod(periodNumber: 3, label: 'III', timeRange: '11.10 - 11.55', subjectAbbr: 'AM', subjectTitle: 'Agile Methodologies', facultyName: 'Ms. Nagalakshmi, AP/IT'),
          TimetablePeriod(periodNumber: 4, label: 'IV', timeRange: '11.55 - 12.40', subjectAbbr: 'ISP', subjectTitle: 'Industry Safety Practices', facultyName: 'Mr. Nalla Thambi, AP/Mech'),
          TimetablePeriod(periodNumber: 0, label: 'LUNCH', timeRange: '12.40 - 01.20', subjectAbbr: 'LUNCH', isLunch: true),
          TimetablePeriod(periodNumber: 5, label: 'V', timeRange: '01.20 - 02.05', subjectAbbr: 'SKILL RACK', subjectTitle: 'Skill Rack / TSN', roomOrLab: 'DBMS Lab', facultyName: 'TSN / DBMS Lab'),
          TimetablePeriod(periodNumber: 6, label: 'VI', timeRange: '02.05 - 02.50', subjectAbbr: 'SKILL RACK', subjectTitle: 'Skill Rack / TSN', roomOrLab: 'DBMS Lab', facultyName: 'TSN / DBMS Lab'),
          TimetablePeriod(periodNumber: 0, label: 'BREAK', timeRange: '02.50 - 03.00', subjectAbbr: 'BREAK', isBreak: true),
          TimetablePeriod(periodNumber: 7, label: 'VII', timeRange: '03.00 - 03.45', subjectAbbr: 'STA', subjectTitle: 'Software Testing and Automation', facultyName: 'Mrs. D. Nirmala Devi, AP/IT'),
          TimetablePeriod(periodNumber: 8, label: 'VIII', timeRange: '03.45 - 04.30', subjectAbbr: 'CCT', subjectTitle: 'Cryptography Concepts & Techniques', facultyName: 'Mrs. K. Rani, AP/IT'),
        ],
      ),
      // Day 4 for Section B
      const DaySchedule(
        dayOrder: 4,
        dayName: 'DAY 4',
        periods: [
          TimetablePeriod(periodNumber: 1, label: 'I', timeRange: '09.15 - 10.05', subjectAbbr: 'ISP', subjectTitle: 'Industry Safety Practices', facultyName: 'Mr. Nalla Thambi, AP/Mech'),
          TimetablePeriod(periodNumber: 2, label: 'II', timeRange: '10.05 - 10.55', subjectAbbr: 'STA', subjectTitle: 'Software Testing and Automation', facultyName: 'Mrs. D. Nirmala Devi, AP/IT'),
          TimetablePeriod(periodNumber: 0, label: 'BREAK', timeRange: '10.55 - 11.10', subjectAbbr: 'BREAK', isBreak: true),
          TimetablePeriod(periodNumber: 3, label: 'III', timeRange: '11.10 - 11.55', subjectAbbr: 'TQM', subjectTitle: 'Total Quality Management', facultyName: 'Dr. D. Pradeepkannan, Prof. & MR'),
          TimetablePeriod(periodNumber: 4, label: 'IV', timeRange: '11.55 - 12.40', subjectAbbr: 'SNA', subjectTitle: 'Social Network Analysis', facultyName: 'Mrs. I. Muthumeenakshi, AP/IT'),
          TimetablePeriod(periodNumber: 0, label: 'LUNCH', timeRange: '12.40 - 01.20', subjectAbbr: 'LUNCH', isLunch: true),
          TimetablePeriod(periodNumber: 5, label: 'V', timeRange: '01.20 - 02.05', subjectAbbr: 'CCT LAB', subjectTitle: 'Cryptography Concepts & Techniques Lab', roomOrLab: 'CCT Lab', facultyName: 'Mrs. K. Rani, AP/IT'),
          TimetablePeriod(periodNumber: 6, label: 'VI', timeRange: '02.05 - 02.50', subjectAbbr: 'CCT LAB', subjectTitle: 'Cryptography Concepts & Techniques Lab', roomOrLab: 'CCT Lab', facultyName: 'Mrs. K. Rani, AP/IT'),
          TimetablePeriod(periodNumber: 0, label: 'BREAK', timeRange: '02.50 - 03.00', subjectAbbr: 'BREAK', isBreak: true),
          TimetablePeriod(periodNumber: 7, label: 'VII', timeRange: '03.00 - 03.45', subjectAbbr: 'CCT LAB', subjectTitle: 'Cryptography Concepts & Techniques Lab', roomOrLab: 'CCT Lab', facultyName: 'Mrs. K. Rani, AP/IT'),
          TimetablePeriod(periodNumber: 8, label: 'VIII', timeRange: '03.45 - 04.30', subjectAbbr: 'AM', subjectTitle: 'Agile Methodologies', facultyName: 'Ms. Nagalakshmi, AP/IT'),
        ],
      ),
      // Day 5 for Section B
      const DaySchedule(
        dayOrder: 5,
        dayName: 'DAY 5',
        periods: [
          TimetablePeriod(periodNumber: 1, label: 'I', timeRange: '09.15 - 10.05', subjectAbbr: 'CCT', subjectTitle: 'Cryptography Concepts & Techniques', facultyName: 'Mrs. K. Rani, AP/IT'),
          TimetablePeriod(periodNumber: 2, label: 'II', timeRange: '10.05 - 10.55', subjectAbbr: 'SNA', subjectTitle: 'Social Network Analysis', facultyName: 'Mrs. I. Muthumeenakshi, AP/IT'),
          TimetablePeriod(periodNumber: 0, label: 'BREAK', timeRange: '10.55 - 11.10', subjectAbbr: 'BREAK', isBreak: true),
          TimetablePeriod(periodNumber: 3, label: 'III', timeRange: '11.10 - 11.55', subjectAbbr: 'STA', subjectTitle: 'Software Testing and Automation', facultyName: 'Mrs. D. Nirmala Devi, AP/IT'),
          TimetablePeriod(periodNumber: 4, label: 'IV', timeRange: '11.55 - 12.40', subjectAbbr: 'AM', subjectTitle: 'Agile Methodologies', facultyName: 'Ms. Nagalakshmi, AP/IT'),
          TimetablePeriod(periodNumber: 0, label: 'LUNCH', timeRange: '12.40 - 01.20', subjectAbbr: 'LUNCH', isLunch: true),
          TimetablePeriod(periodNumber: 5, label: 'V', timeRange: '01.20 - 02.05', subjectAbbr: 'TQM', subjectTitle: 'Total Quality Management', facultyName: 'Dr. D. Pradeepkannan, Prof. & MR'),
          TimetablePeriod(periodNumber: 6, label: 'VI', timeRange: '02.05 - 02.50', subjectAbbr: 'ISP', subjectTitle: 'Industry Safety Practices', facultyName: 'Mr. Nalla Thambi, AP/Mech'),
          TimetablePeriod(periodNumber: 0, label: 'BREAK', timeRange: '02.50 - 03.00', subjectAbbr: 'BREAK', isBreak: true),
          TimetablePeriod(periodNumber: 7, label: 'VII', timeRange: '03.00 - 03.45', subjectAbbr: 'SKILL RACK', subjectTitle: 'Skill Rack / PNL', roomOrLab: 'MP & MC Lab', facultyName: 'PNL / MP & MC Lab'),
          TimetablePeriod(periodNumber: 8, label: 'VIII', timeRange: '03.45 - 04.30', subjectAbbr: 'SKILL RACK', subjectTitle: 'Skill Rack / PNL', roomOrLab: 'MP & MC Lab', facultyName: 'PNL / MP & MC Lab'),
        ],
      ),
    ],
    subjects: defaultSubjectsSecA,
  );

  /// Default Official Academic Calendar (Circular No. 321, 2026-2027)
  static final AcademicCalendar defaultCalendar = AcademicCalendar(
    collegeName: 'K.L.N. COLLEGE OF ENGINEERING, POTTAPALAYAM - 630 612',
    affiliation: 'An Autonomous Institution, Affiliated to Anna University, Chennai (Accredited by NAAC)',
    circularRef: 'Ref : KLNCE/Academic Calendar/2026-2027 (Odd semester)/321',
    circularDate: '30.06.2026',
    semesterDescription: 'Autonomous Academic Schedule - III, V & VII Semester B.E./B.Tech., III Semester M.E. Degree Programs (Revised)',
    totalWorkingDays: 88,
    events: const [
      CalendarEvent(sno: 1, title: 'Training Classes', dateDescription: '29 June - 10 July 2026', category: 'academic'),
      CalendarEvent(sno: 2, title: 'Commencement of Classes', dateDescription: '06 July 2026 (Monday)', workingDays: '01', category: 'academic'),
      CalendarEvent(sno: 3, title: 'Class Committee Meeting - I', dateDescription: '6 - 10 July 2026', workingDays: '1-5', category: 'meeting'),
      CalendarEvent(sno: 4, title: 'Student Counselor Meeting - I', dateDescription: '6 - 10 July 2026', workingDays: '1-5', category: 'meeting'),
      CalendarEvent(sno: 5, title: 'Mini / Micro / Project Review - I', dateDescription: '03 - 07 August 2026', workingDays: '21-25', category: 'academic'),
      CalendarEvent(sno: 6, title: 'Centralized Internal Test - I (CIT-I: Unit-I, II)', dateDescription: '13 - 21 August 2026', workingDays: '29-35', category: 'internal_test'),
      CalendarEvent(sno: 7, title: 'Improvement Test - I', dateDescription: '22 August 2026', category: 'internal_test'),
      CalendarEvent(sno: 8, title: 'Class Committee Meeting - II', dateDescription: '24 - 28 August 2026', workingDays: '36-39', category: 'meeting'),
      CalendarEvent(sno: 9, title: 'Model Practical Examinations - I / Physical Education Test - I', dateDescription: '07 - 11 September 2026', workingDays: '44-48', category: 'exam'),
      CalendarEvent(sno: 10, title: 'Project Review - II / Foreign Language Test - I', dateDescription: '15 - 21 September 2026', workingDays: '49-53', category: 'academic'),
      CalendarEvent(sno: 11, title: 'Credit Transfer Examinations', dateDescription: '22 - 24 September 2026', workingDays: '54-56', category: 'exam'),
      CalendarEvent(sno: 12, title: 'Group Photograph with Final Year Students', dateDescription: '22 - 25 September 2026', workingDays: '54-57', category: 'academic'),
      CalendarEvent(sno: 13, title: 'Parents-Teacher Meeting (PTM)', dateDescription: '26 September 2026 (Saturday)', category: 'meeting'),
      CalendarEvent(sno: 14, title: 'Improvement Test - II', dateDescription: '26 September 2026', category: 'internal_test'),
      CalendarEvent(sno: 15, title: 'Centralized Internal Test - II (CIT-II: Unit-III, IV) & Aptitude Test', dateDescription: '25 Sept - 09 October 2026', workingDays: '57-66', category: 'internal_test'),
      CalendarEvent(sno: 16, title: 'Improvement Test - III', dateDescription: '10 October 2026', category: 'internal_test'),
      CalendarEvent(sno: 17, title: 'Class Committee Meeting - III & Student Counselor Meeting - II', dateDescription: '12 - 16 October 2026', workingDays: '67-71', category: 'meeting'),
      CalendarEvent(sno: 18, title: 'Model Practical Exam - II / Project Review - III / PE Test - II', dateDescription: '12 - 15 October 2026', workingDays: '68-71', category: 'exam'),
      CalendarEvent(sno: 19, title: 'Management Review Meeting', dateDescription: '15 October 2026 (Thursday)', workingDays: '71', category: 'meeting'),
      CalendarEvent(sno: 20, title: 'Centralized Internal Test - III (CIT-III: Unit-V)', dateDescription: '16 - 24 October 2026', workingDays: '72-76', category: 'internal_test'),
      CalendarEvent(sno: 21, title: 'Feedback - Faculty, Supporting & College Facilities', dateDescription: '16 - 24 October 2026', workingDays: '72-76', category: 'academic'),
      CalendarEvent(sno: 22, title: 'Last Instructional Day', dateDescription: '24 October 2026 (Saturday)', workingDays: '76', category: 'academic'),
      CalendarEvent(sno: 23, title: 'End Semester Practical Examinations', dateDescription: '26 October - 06 November 2026', workingDays: '77-86', category: 'exam'),
      CalendarEvent(sno: 24, title: 'End Semester Theory Examinations', dateDescription: '11 November 2026 (Wednesday)', category: 'exam'),
      CalendarEvent(sno: 25, title: 'Winter Vacation for Staff', dateDescription: '16 November - 13 December 2026', category: 'holiday'),
      CalendarEvent(sno: 26, title: 'Reopening Day for Staff', dateDescription: '14 December 2026 (Monday)', category: 'academic'),
      CalendarEvent(sno: 27, title: 'Reopening Day (IV, VI, VIII Sem - Even Semester 2026-2027)', dateDescription: '21 December 2026 (Monday)', category: 'academic'),
    ],
    monthSummaries: const [
      MonthSummary(month: 'July 2026', workingDays: 20, holidays: ['None']),
      MonthSummary(month: 'August 2026', workingDays: 20, holidays: ['15 Aug - Independence Day (Sat)', '26 Aug - Miladinabi (Wed)']),
      MonthSummary(month: 'September 2026', workingDays: 20, holidays: ['04 Sep - Krishna Jeyanthi (Fri)', '14 Sep - Sri Vinayagar Sathurthy (Mon)']),
      MonthSummary(month: 'October 2026', workingDays: 21, holidays: ['02 Oct - Gandhi Jeyanthy (Fri)', '19 Oct - Saraswathy Pooja (Mon)', '20 Oct - Vijayadasami (Tue)']),
      MonthSummary(month: 'November 2026', workingDays: 7, holidays: ['08 Nov - Deepawali (Sun)']),
    ],
    assessmentReports: const [
      AssessmentReport(reportNo: 'Report I', reportPeriod: '6 July - 31 July 2026 (20 days)', entryDetails: 'Attendance entry only', entryDate: '5, 6, 7 August 2026', totalPeriods: '160 periods'),
      AssessmentReport(reportNo: 'Report II', reportPeriod: '3 Aug - 31 Aug 2026 (20 days)', entryDetails: 'CIT-I, Assignment-I Marks, Attendance', entryDate: '9, 10, 11 September 2026', totalPeriods: '160 (Cum: 320) periods'),
      AssessmentReport(reportNo: 'Report III', reportPeriod: '1 Sep - 30 Sep 2026 (20 days)', entryDetails: 'CIT-II, Assignment-II Marks, Attendance', entryDate: '7, 8, 9 October 2026', totalPeriods: '160 (Cum: 480) periods'),
      AssessmentReport(reportNo: 'Report IV', reportPeriod: '1 Oct - 24 Oct 2026 (16 days)', entryDetails: 'CIT-III, Assignment-III Marks, Attendance', entryDate: '4, 5, 6 November 2026', totalPeriods: '128 (Cum: 608) periods'),
      AssessmentReport(reportNo: 'Report V', reportPeriod: 'Final Consolidation', entryDetails: 'Improvement Test Marks, Lab Components TCP, PD, FL, Programming Skills', entryDate: '10 November 2026', totalPeriods: 'All Periods'),
    ],
    generalNotes: const [
      '1. Number of periods per day: 8. Handled as per curriculum regulations.',
      '2. CITs (I, II) - One test per day held in first two periods. Regular classes from 3rd period onwards. CIT-III - Two tests per day.',
      '3. Faculty assigned for CoE Portal entry must ensure period entered for each report.',
      '4. Students must be informed about availability of webportal entry.',
      '5. Cancellation of Working days, if any, will be compensated on Saturdays.',
      '6. Value Added Course / Skill Training: Min 5 days, Max 10 days.',
      '7. Adherence to Academic Calendar is strictly monitored and enforced.',
    ],
  );

  /// Initialize local and cloud sync
  static Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load Section A
      final strA = prefs.getString(_keyTimetableA);
      if (strA != null) {
        _cachedTimetableA = SectionTimetable.fromJson(jsonDecode(strA));
      } else {
        _cachedTimetableA = defaultTimetableA;
      }

      // Load Section B
      final strB = prefs.getString(_keyTimetableB);
      if (strB != null) {
        _cachedTimetableB = SectionTimetable.fromJson(jsonDecode(strB));
      } else {
        _cachedTimetableB = defaultTimetableB;
      }

      // Load Calendar
      final strCal = prefs.getString(_keyCalendar);
      if (strCal != null) {
        _cachedCalendar = AcademicCalendar.fromJson(jsonDecode(strCal));
      } else {
        _cachedCalendar = defaultCalendar;
      }

      _initialized = true;

      // Trigger cloud sync in background
      syncFromCloud();
    } catch (e) {
      debugPrint('AcademicScheduleRepository.init error: $e');
    }
  }

  /// Get Timetable for specific section ('A' or 'B')
  static Future<SectionTimetable> getTimetable(String section) async {
    await init();
    if (section.toUpperCase() == 'B') {
      return _cachedTimetableB ?? defaultTimetableB;
    }
    return _cachedTimetableA ?? defaultTimetableA;
  }

  /// Save Timetable for section ('A' or 'B') locally and to Supabase Cloud
  static Future<void> saveTimetable(SectionTimetable timetable) async {
    await init();
    final isSecB = timetable.section.toUpperCase() == 'B';
    final key = isSecB ? _keyTimetableB : _keyTimetableA;
    final cloudKey = isSecB ? 'ACADEMIC_TIMETABLE_B' : 'ACADEMIC_TIMETABLE_A';

    if (isSecB) {
      _cachedTimetableB = timetable;
    } else {
      _cachedTimetableA = timetable;
    }

    final jsonStr = jsonEncode(timetable.toJson());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonStr);

    // Sync to Supabase Cloud
    try {
      final existing = await _api.get('/notifications?title=eq.$cloudKey&select=id&limit=1');
      if (existing is List && existing.isNotEmpty) {
        await _api.patch('/notifications?title=eq.$cloudKey', body: {
          'message': jsonStr,
          'is_read': true,
        });
      } else {
        await _api.post('/notifications', body: {
          'user_id': 1,
          'notification_type': 'system',
          'title': cloudKey,
          'message': jsonStr,
          'severity': 'info',
          'is_read': true,
        });
      }
      debugPrint('Successfully saved and synced timetable for Section ${timetable.section} to cloud');
    } catch (e) {
      debugPrint('Error syncing timetable to cloud: $e');
    }
  }

  /// Get Academic Calendar
  static Future<AcademicCalendar> getCalendar() async {
    await init();
    return _cachedCalendar ?? defaultCalendar;
  }

  /// Save Academic Calendar locally and to Supabase Cloud
  static Future<void> saveCalendar(AcademicCalendar calendar) async {
    await init();
    _cachedCalendar = calendar;
    final jsonStr = jsonEncode(calendar.toJson());

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCalendar, jsonStr);

    try {
      final existing = await _api.get('/notifications?title=eq.ACADEMIC_CALENDAR_CONFIG&select=id&limit=1');
      if (existing is List && existing.isNotEmpty) {
        await _api.patch('/notifications?title=eq.ACADEMIC_CALENDAR_CONFIG', body: {
          'message': jsonStr,
          'is_read': true,
        });
      } else {
        await _api.post('/notifications', body: {
          'user_id': 1,
          'notification_type': 'system',
          'title': 'ACADEMIC_CALENDAR_CONFIG',
          'message': jsonStr,
          'severity': 'info',
          'is_read': true,
        });
      }
      debugPrint('Successfully saved and synced Academic Calendar to cloud');
    } catch (e) {
      debugPrint('Error syncing calendar to cloud: $e');
    }
  }

  /// Uploads Document / Image (e.g. Circular Image, Section Timetable PDF/Image)
  /// docType: 'TIMETABLE_A', 'TIMETABLE_B', 'CALENDAR'
  static Future<String?> uploadDocument({
    required String docType,
    required String filePathOrBase64,
  }) async {
    await init();
    String preparedBase64 = filePathOrBase64.trim();

    try {
      final file = File(filePathOrBase64);
      if (file.existsSync()) {
        final bytes = await file.readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          // Resize large scans/documents to optimal viewing size
          final resized = img.copyResize(decoded, width: 1080);
          final jpg = img.encodeJpg(resized, quality: 85);
          preparedBase64 = 'data:image/jpeg;base64,${base64Encode(jpg)}';
        } else {
          preparedBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        }
      }

      final cloudKey = 'ACADEMIC_DOC_$docType';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cloudKey, preparedBase64);

      // Attach to corresponding cached object
      if (docType == 'TIMETABLE_A' && _cachedTimetableA != null) {
        _cachedTimetableA = _cachedTimetableA!.copyWith(customImageUrl: preparedBase64);
        await saveTimetable(_cachedTimetableA!);
      } else if (docType == 'TIMETABLE_B' && _cachedTimetableB != null) {
        _cachedTimetableB = _cachedTimetableB!.copyWith(customImageUrl: preparedBase64);
        await saveTimetable(_cachedTimetableB!);
      } else if (docType == 'CALENDAR' && _cachedCalendar != null) {
        _cachedCalendar = _cachedCalendar!.copyWith(customImageUrl: preparedBase64);
        await saveCalendar(_cachedCalendar!);
      }

      // Sync document to Supabase Cloud
      final existing = await _api.get('/notifications?title=eq.$cloudKey&select=id&limit=1');
      if (existing is List && existing.isNotEmpty) {
        await _api.patch('/notifications?title=eq.$cloudKey', body: {
          'message': preparedBase64,
          'is_read': true,
        });
      } else {
        await _api.post('/notifications', body: {
          'user_id': 1,
          'notification_type': 'system',
          'title': cloudKey,
          'message': preparedBase64,
          'severity': 'info',
          'is_read': true,
        });
      }

      debugPrint('Successfully uploaded document for $docType to Supabase cloud');
      return preparedBase64;
    } catch (e) {
      debugPrint('Error uploading document: $e');
      return preparedBase64;
    }
  }

  /// Sync all academic schedules & circular documents from Supabase Cloud
  static Future<void> syncFromCloud() async {
    try {
      final res = await _api.get('/notifications?title=like.ACADEMIC_*&select=title,message');
      if (res is List && res.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        for (final item in res) {
          final title = item['title']?.toString() ?? '';
          final message = item['message']?.toString() ?? '';
          if (message.isEmpty) continue;

          if (title == 'ACADEMIC_TIMETABLE_A') {
            _cachedTimetableA = SectionTimetable.fromJson(jsonDecode(message));
            await prefs.setString(_keyTimetableA, message);
          } else if (title == 'ACADEMIC_TIMETABLE_B') {
            _cachedTimetableB = SectionTimetable.fromJson(jsonDecode(message));
            await prefs.setString(_keyTimetableB, message);
          } else if (title == 'ACADEMIC_CALENDAR_CONFIG') {
            _cachedCalendar = AcademicCalendar.fromJson(jsonDecode(message));
            await prefs.setString(_keyCalendar, message);
          } else if (title.startsWith('ACADEMIC_DOC_')) {
            await prefs.setString(title, message);
          }
        }
        debugPrint('Academic schedules & calendar successfully synced from Supabase Cloud');
      }
    } catch (e) {
      debugPrint('AcademicScheduleRepository.syncFromCloud error: $e');
    }
  }
}
