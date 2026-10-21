import 'dart:convert';

/// Represents an individual milestone/event in the KLNCE Academic Calendar
class CalendarEvent {
  final int sno;
  final String title;
  final String dateDescription;
  final String workingDays; // e.g. '01', '29-35', '76'
  final String category; // 'academic', 'internal_test', 'meeting', 'exam', 'holiday'

  const CalendarEvent({
    required this.sno,
    required this.title,
    required this.dateDescription,
    this.workingDays = '',
    this.category = 'academic',
  });

  Map<String, dynamic> toJson() => {
    'sno': sno,
    'title': title,
    'dateDescription': dateDescription,
    'workingDays': workingDays,
    'category': category,
  };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
    sno: json['sno'] ?? 0,
    title: json['title'] ?? '',
    dateDescription: json['dateDescription'] ?? '',
    workingDays: json['workingDays'] ?? '',
    category: json['category'] ?? 'academic',
  );
}

/// Monthly breakdown of working days and public holidays
class MonthSummary {
  final String month; // e.g. 'July', 'August'
  final int workingDays;
  final List<String> holidays;

  const MonthSummary({
    required this.month,
    required this.workingDays,
    required this.holidays,
  });

  Map<String, dynamic> toJson() => {
    'month': month,
    'workingDays': workingDays,
    'holidays': holidays,
  };

  factory MonthSummary.fromJson(Map<String, dynamic> json) => MonthSummary(
    month: json['month'] ?? '',
    workingDays: json['workingDays'] ?? 0,
    holidays: List<String>.from(json['holidays'] ?? []),
  );
}

/// Periodic Assessment and CoE webportal entry report
class AssessmentReport {
  final String reportNo; // 'Report I', 'Report II'
  final String reportPeriod; // '6 July - 31 July 2026 (20 days)'
  final String entryDetails; // 'Attendance entry only'
  final String entryDate; // '5, 6, 7 August 2026'
  final String totalPeriods; // '160'

  const AssessmentReport({
    required this.reportNo,
    required this.reportPeriod,
    required this.entryDetails,
    required this.entryDate,
    required this.totalPeriods,
  });

  Map<String, dynamic> toJson() => {
    'reportNo': reportNo,
    'reportPeriod': reportPeriod,
    'entryDetails': entryDetails,
    'entryDate': entryDate,
    'totalPeriods': totalPeriods,
  };

  factory AssessmentReport.fromJson(Map<String, dynamic> json) => AssessmentReport(
    reportNo: json['reportNo'] ?? '',
    reportPeriod: json['reportPeriod'] ?? '',
    entryDetails: json['entryDetails'] ?? '',
    entryDate: json['entryDate'] ?? '',
    totalPeriods: json['totalPeriods'] ?? '',
  );
}

/// Complete KLNCE Academic Calendar (Circular No. 321)
class AcademicCalendar {
  final String collegeName;
  final String affiliation;
  final String circularRef;
  final String circularDate;
  final String semesterDescription;
  final int totalWorkingDays;
  final List<CalendarEvent> events;
  final List<MonthSummary> monthSummaries;
  final List<AssessmentReport> assessmentReports;
  final List<String> generalNotes;
  final String? customImageUrl;

  const AcademicCalendar({
    this.collegeName = 'K.L.N. COLLEGE OF ENGINEERING, POTTAPALAYAM - 630 612',
    this.affiliation = 'An Autonomous Institution, Affiliated to Anna University, Chennai',
    this.circularRef = 'Ref : KLNCE/Academic Calendar/2026-2027 (Odd semester)/321',
    this.circularDate = '30.06.2026',
    this.semesterDescription = 'Autonomous Academic Schedule - III, V & VII Semester B.E./B.Tech., III Sem M.E. (Revised)',
    this.totalWorkingDays = 88,
    required this.events,
    required this.monthSummaries,
    required this.assessmentReports,
    required this.generalNotes,
    this.customImageUrl,
  });

  AcademicCalendar copyWith({
    String? collegeName,
    String? affiliation,
    String? circularRef,
    String? circularDate,
    String? semesterDescription,
    int? totalWorkingDays,
    List<CalendarEvent>? events,
    List<MonthSummary>? monthSummaries,
    List<AssessmentReport>? assessmentReports,
    List<String>? generalNotes,
    String? customImageUrl,
  }) {
    return AcademicCalendar(
      collegeName: collegeName ?? this.collegeName,
      affiliation: affiliation ?? this.affiliation,
      circularRef: circularRef ?? this.circularRef,
      circularDate: circularDate ?? this.circularDate,
      semesterDescription: semesterDescription ?? this.semesterDescription,
      totalWorkingDays: totalWorkingDays ?? this.totalWorkingDays,
      events: events ?? this.events,
      monthSummaries: monthSummaries ?? this.monthSummaries,
      assessmentReports: assessmentReports ?? this.assessmentReports,
      generalNotes: generalNotes ?? this.generalNotes,
      customImageUrl: customImageUrl ?? this.customImageUrl,
    );
  }

  Map<String, dynamic> toJson() => {
    'collegeName': collegeName,
    'affiliation': affiliation,
    'circularRef': circularRef,
    'circularDate': circularDate,
    'semesterDescription': semesterDescription,
    'totalWorkingDays': totalWorkingDays,
    'events': events.map((e) => e.toJson()).toList(),
    'monthSummaries': monthSummaries.map((m) => m.toJson()).toList(),
    'assessmentReports': assessmentReports.map((a) => a.toJson()).toList(),
    'generalNotes': generalNotes,
    'customImageUrl': customImageUrl,
  };

  factory AcademicCalendar.fromJson(Map<String, dynamic> json) => AcademicCalendar(
    collegeName: json['collegeName'] ?? 'K.L.N. COLLEGE OF ENGINEERING',
    affiliation: json['affiliation'] ?? 'An Autonomous Institution, Affiliated to Anna University, Chennai',
    circularRef: json['circularRef'] ?? 'Ref : KLNCE/Academic Calendar/2026-2027 (Odd semester)/321',
    circularDate: json['circularDate'] ?? '30.06.2026',
    semesterDescription: json['semesterDescription'] ?? '',
    totalWorkingDays: json['totalWorkingDays'] ?? 88,
    events: (json['events'] as List? ?? [])
        .map((e) => CalendarEvent.fromJson(e))
        .toList(),
    monthSummaries: (json['monthSummaries'] as List? ?? [])
        .map((m) => MonthSummary.fromJson(m))
        .toList(),
    assessmentReports: (json['assessmentReports'] as List? ?? [])
        .map((a) => AssessmentReport.fromJson(a))
        .toList(),
    generalNotes: List<String>.from(json['generalNotes'] ?? []),
    customImageUrl: json['customImageUrl'],
  );
}
