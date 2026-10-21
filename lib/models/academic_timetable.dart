/// Represents a single period in the KLNCE timetable
class TimetablePeriod {
  final int periodNumber; // 1 to 8 (or 0 for break/lunch)
  final String label; // 'Period I', 'BREAK', 'LUNCH'
  final String timeRange; // e.g. '09.15 - 10.05'
  final String subjectCode; // e.g. '20CSV12', '20ITV43'
  final String subjectTitle; // e.g. 'Social Network Analysis'
  final String subjectAbbr; // e.g. 'SNA', 'STA', 'AM'
  final String facultyName; // e.g. 'Mrs. I. Muthumeenakshi, AP/IT'
  final String facultyCode; // e.g. '10535061'
  final String roomOrLab; // e.g. 'M.E.-02', 'MP & MC Lab'
  final bool isBreak;
  final bool isLunch;

  const TimetablePeriod({
    required this.periodNumber,
    required this.label,
    required this.timeRange,
    this.subjectCode = '',
    this.subjectTitle = '',
    required this.subjectAbbr,
    this.facultyName = '',
    this.facultyCode = '',
    this.roomOrLab = 'M.E.-02',
    this.isBreak = false,
    this.isLunch = false,
  });

  Map<String, dynamic> toJson() => {
    'periodNumber': periodNumber,
    'label': label,
    'timeRange': timeRange,
    'subjectCode': subjectCode,
    'subjectTitle': subjectTitle,
    'subjectAbbr': subjectAbbr,
    'facultyName': facultyName,
    'facultyCode': facultyCode,
    'roomOrLab': roomOrLab,
    'isBreak': isBreak,
    'isLunch': isLunch,
  };

  factory TimetablePeriod.fromJson(Map<String, dynamic> json) => TimetablePeriod(
    periodNumber: json['periodNumber'] ?? 1,
    label: json['label'] ?? '',
    timeRange: json['timeRange'] ?? '',
    subjectCode: json['subjectCode'] ?? '',
    subjectTitle: json['subjectTitle'] ?? '',
    subjectAbbr: json['subjectAbbr'] ?? '',
    facultyName: json['facultyName'] ?? '',
    facultyCode: json['facultyCode'] ?? '',
    roomOrLab: json['roomOrLab'] ?? 'M.E.-02',
    isBreak: json['isBreak'] ?? false,
    isLunch: json['isLunch'] ?? false,
  );
}

/// Day Order schedule containing the 8 periods for that day order
class DaySchedule {
  final int dayOrder; // 1 to 5
  final String dayName; // 'DAY 1' to 'DAY 5'
  final List<TimetablePeriod> periods;

  const DaySchedule({
    required this.dayOrder,
    required this.dayName,
    required this.periods,
  });

  Map<String, dynamic> toJson() => {
    'dayOrder': dayOrder,
    'dayName': dayName,
    'periods': periods.map((p) => p.toJson()).toList(),
  };

  factory DaySchedule.fromJson(Map<String, dynamic> json) => DaySchedule(
    dayOrder: json['dayOrder'] ?? 1,
    dayName: json['dayName'] ?? 'DAY 1',
    periods: (json['periods'] as List? ?? [])
        .map((p) => TimetablePeriod.fromJson(p))
        .toList(),
  );
}

/// Subject allocation item as detailed in the official timetable document
class SubjectAllocation {
  final String code;
  final String title;
  final String abbr;
  final String facultyName;
  final String facultyCode;
  final int totalHours;
  final bool isPractical;
  final String venue;

  const SubjectAllocation({
    required this.code,
    required this.title,
    required this.abbr,
    required this.facultyName,
    required this.facultyCode,
    required this.totalHours,
    this.isPractical = false,
    this.venue = 'M.E.-02',
  });

  Map<String, dynamic> toJson() => {
    'code': code,
    'title': title,
    'abbr': abbr,
    'facultyName': facultyName,
    'facultyCode': facultyCode,
    'totalHours': totalHours,
    'isPractical': isPractical,
    'venue': venue,
  };

  factory SubjectAllocation.fromJson(Map<String, dynamic> json) => SubjectAllocation(
    code: json['code'] ?? '',
    title: json['title'] ?? '',
    abbr: json['abbr'] ?? '',
    facultyName: json['facultyName'] ?? '',
    facultyCode: json['facultyCode'] ?? '',
    totalHours: json['totalHours'] ?? 4,
    isPractical: json['isPractical'] ?? false,
    venue: json['venue'] ?? 'M.E.-02',
  );
}

/// Complete class timetable for a specific section (Section A or Section B)
class SectionTimetable {
  final String department;
  final String course;
  final String batch;
  final String academicYear;
  final String yearSemesterSection;
  final String section; // 'A' or 'B'
  final String roomNo;
  final String classInCharge;
  final String inChargeCode;
  final String effectiveDate;
  final String? customImageUrl;
  final List<DaySchedule> days;
  final List<SubjectAllocation> subjects;

  const SectionTimetable({
    this.department = 'Information Technology',
    this.course = 'B.Tech. IT',
    this.batch = '2023-2027',
    this.academicYear = '2026 - 2027 (ODD)',
    required this.yearSemesterSection,
    required this.section,
    required this.roomNo,
    required this.classInCharge,
    required this.inChargeCode,
    this.effectiveDate = '20/07/2026 Rev:2',
    this.customImageUrl,
    required this.days,
    required this.subjects,
  });

  SectionTimetable copyWith({
    String? department,
    String? course,
    String? batch,
    String? academicYear,
    String? yearSemesterSection,
    String? section,
    String? roomNo,
    String? classInCharge,
    String? inChargeCode,
    String? effectiveDate,
    String? customImageUrl,
    List<DaySchedule>? days,
    List<SubjectAllocation>? subjects,
  }) {
    return SectionTimetable(
      department: department ?? this.department,
      course: course ?? this.course,
      batch: batch ?? this.batch,
      academicYear: academicYear ?? this.academicYear,
      yearSemesterSection: yearSemesterSection ?? this.yearSemesterSection,
      section: section ?? this.section,
      roomNo: roomNo ?? this.roomNo,
      classInCharge: classInCharge ?? this.classInCharge,
      inChargeCode: inChargeCode ?? this.inChargeCode,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      customImageUrl: customImageUrl ?? this.customImageUrl,
      days: days ?? this.days,
      subjects: subjects ?? this.subjects,
    );
  }

  Map<String, dynamic> toJson() => {
    'department': department,
    'course': course,
    'batch': batch,
    'academicYear': academicYear,
    'yearSemesterSection': yearSemesterSection,
    'section': section,
    'roomNo': roomNo,
    'classInCharge': classInCharge,
    'inChargeCode': inChargeCode,
    'effectiveDate': effectiveDate,
    'customImageUrl': customImageUrl,
    'days': days.map((d) => d.toJson()).toList(),
    'subjects': subjects.map((s) => s.toJson()).toList(),
  };

  factory SectionTimetable.fromJson(Map<String, dynamic> json) => SectionTimetable(
    department: json['department'] ?? 'Information Technology',
    course: json['course'] ?? 'B.Tech. IT',
    batch: json['batch'] ?? '2023-2027',
    academicYear: json['academicYear'] ?? '2026 - 2027 (ODD)',
    yearSemesterSection: json['yearSemesterSection'] ?? 'IV / VII / A',
    section: json['section'] ?? 'A',
    roomNo: json['roomNo'] ?? 'M.E.-02',
    classInCharge: json['classInCharge'] ?? 'Mrs. K. Rani, AP/IT',
    inChargeCode: json['inChargeCode'] ?? '10535062',
    effectiveDate: json['effectiveDate'] ?? '20/07/2026 Rev:2',
    customImageUrl: json['customImageUrl'],
    days: (json['days'] as List? ?? [])
        .map((d) => DaySchedule.fromJson(d))
        .toList(),
    subjects: (json['subjects'] as List? ?? [])
        .map((s) => SubjectAllocation.fromJson(s))
        .toList(),
  );
}
