import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';

class AcademicConfig {
  final String semesterDuration;
  final String department;
  final String academicYear;
  final String year;
  final String section;
  final String semester;
  final String batch;

  const AcademicConfig({
    this.semesterDuration = 'August 2025 – December 2025',
    this.department = 'Information Technology',
    this.academicYear = '2025 – 2026',
    this.year = '3',
    this.section = 'A',
    this.semester = 'Semester 5',
    this.batch = '2023 – 2027',
  });

  Map<String, dynamic> toJson() => {
    'semesterDuration': semesterDuration,
    'department': department,
    'academicYear': academicYear,
    'year': year,
    'section': section,
    'semester': semester,
    'batch': batch,
  };

  factory AcademicConfig.fromJson(Map<String, dynamic> json) => AcademicConfig(
    semesterDuration: json['semesterDuration'] ?? 'August 2025 – December 2025',
    department: json['department'] ?? 'Information Technology',
    academicYear: json['academicYear'] ?? '2025 – 2026',
    year: json['year'] ?? '3',
    section: json['section'] ?? 'A',
    semester: json['semester'] ?? 'Semester 5',
    batch: json['batch'] ?? '2023 – 2027',
  );
}

class StudentIdCardDetails {
  final String id;
  final String barcode;
  final String name;
  final String course;
  final String department;
  final String college;
  final String collegeAffiliation;
  final String validity;
  final String address;
  final String pincode;
  final String email;
  final List<String> phones;
  final String dob;
  final String bloodGroup;
  final String avatarUrl;
  final String year;
  final String section;
  final String semester;
  final String batch;
  final String semesterDuration;

  const StudentIdCardDetails({
    required this.id,
    required this.barcode,
    required this.name,
    required this.course,
    required this.department,
    required this.college,
    required this.collegeAffiliation,
    required this.validity,
    required this.address,
    required this.pincode,
    required this.email,
    required this.phones,
    required this.dob,
    required this.bloodGroup,
    this.avatarUrl = '',
    this.year = '3',
    this.section = 'A',
    this.semester = 'Semester 5',
    this.batch = '2023 - 2027',
    this.semesterDuration = 'August 2025 – December 2025',
  });

  StudentIdCardDetails copyWith({
    String? id,
    String? barcode,
    String? name,
    String? course,
    String? department,
    String? college,
    String? collegeAffiliation,
    String? validity,
    String? address,
    String? pincode,
    String? email,
    List<String>? phones,
    String? dob,
    String? bloodGroup,
    String? avatarUrl,
    String? year,
    String? section,
    String? semester,
    String? batch,
    String? semesterDuration,
  }) {
    return StudentIdCardDetails(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      course: course ?? this.course,
      department: department ?? this.department,
      college: college ?? this.college,
      collegeAffiliation: collegeAffiliation ?? this.collegeAffiliation,
      validity: validity ?? this.validity,
      address: address ?? this.address,
      pincode: pincode ?? this.pincode,
      email: email ?? this.email,
      phones: phones ?? this.phones,
      dob: dob ?? this.dob,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      year: year ?? this.year,
      section: section ?? this.section,
      semester: semester ?? this.semester,
      batch: batch ?? this.batch,
      semesterDuration: semesterDuration ?? this.semesterDuration,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'barcode': barcode,
    'name': name,
    'course': course,
    'department': department,
    'college': college,
    'collegeAffiliation': collegeAffiliation,
    'validity': validity,
    'address': address,
    'pincode': pincode,
    'email': email,
    'phones': phones,
    'dob': dob,
    'bloodGroup': bloodGroup,
    'avatarUrl': avatarUrl,
    'year': year,
    'section': section,
    'semester': semester,
    'batch': batch,
    'semesterDuration': semesterDuration,
  };

  factory StudentIdCardDetails.fromJson(Map<String, dynamic> json) => StudentIdCardDetails(
    id: json['id']?.toString() ?? '',
    barcode: json['barcode']?.toString() ?? '',
    name: json['name'] ?? '',
    course: json['course'] ?? 'B.Tech.',
    department: json['department'] ?? 'Information Technology',
    college: json['college'] ?? 'K.L.N. COLLEGE OF ENGINEERING',
    collegeAffiliation: json['collegeAffiliation'] ?? 'An Autonomous Institution, Affiliated to Anna University, Chennai (Accredited by NAAC)',
    validity: json['validity'] ?? 'August 2023 to May 2027',
    address: json['address'] ?? '',
    pincode: json['pincode'] ?? '',
    email: json['email'] ?? '',
    phones: (json['phones'] is List) ? List<String>.from(json['phones']) : [json['phones']?.toString() ?? ''],
    dob: json['dob'] ?? '',
    bloodGroup: json['bloodGroup'] ?? '',
    avatarUrl: json['avatarUrl'] ?? '',
    year: json['year']?.toString() ?? '3',
    section: json['section']?.toString() ?? 'A',
    semester: json['semester']?.toString() ?? 'Semester 5',
    batch: json['batch']?.toString() ?? '2023 - 2027',
    semesterDuration: json['semesterDuration']?.toString() ?? 'August 2025 – December 2025',
  );
}

class StudentDirectory {
  static const String _prefsKeyStudents = 'admin_registered_students';
  static const String _prefsKeyAcademic = 'admin_academic_config';

  static AcademicConfig _currentConfig = const AcademicConfig();
  static AcademicConfig get academicConfig => _currentConfig;

  // Default directory with complete card details
  static final List<StudentIdCardDetails> _initialRegistry = [
    const StudentIdCardDetails(
      id: '1',
      barcode: '235025',
      name: 'MADHANKUMAR E G D',
      course: 'B.Tech.',
      department: 'Information Technology',
      college: 'K.L.N. COLLEGE OF ENGINEERING',
      collegeAffiliation: 'An Autonomous Institution, Affiliated to Anna University, Chennai (Accredited by NAAC)',
      validity: 'August 2023 to May 2027',
      address: 'PLOT NO.54-A, ANNAMALAIYAR STREET, KAVI VINAYAGAR KOVIL STREET, MEENAKSHI NAGAR, VILLAPURAM, MADURAI',
      pincode: '625012',
      email: 'edgmadhankumar@gmail.com',
      phones: ['9842014033', '8870792326'],
      dob: '19-12-2005',
      bloodGroup: 'A1+VE',
      year: '3',
      section: 'A',
      semester: 'Semester 5',
      batch: '2023 - 2027',
      semesterDuration: 'August 2025 – December 2025',
    ),
    const StudentIdCardDetails(
      id: '2',
      barcode: '235014',
      name: 'ARAVINDSAMY P',
      course: 'B.Tech.',
      department: 'Information Technology',
      college: 'K.L.N. COLLEGE OF ENGINEERING',
      collegeAffiliation: 'An Autonomous Institution, Affiliated to Anna University, Chennai (Accredited by NAAC)',
      validity: 'August 2023 to May 2027',
      address: '2/290, SRI RAM NIVAS, ANGUSAMY NAGAR, VANDIYUR, MADURAI',
      pincode: '625020',
      email: 'pmaha0896@gmail.com',
      phones: ['9677565180', '9025154967'],
      dob: '24-09-2006',
      bloodGroup: 'O+VE',
      year: '3',
      section: 'A',
      semester: 'Semester 5',
      batch: '2023 - 2027',
      semesterDuration: 'August 2025 – December 2025',
    ),
    const StudentIdCardDetails(
      id: '5',
      barcode: '235002',
      name: 'ASHISH P',
      course: 'B.Tech.',
      department: 'Information Technology',
      college: 'K.L.N. COLLEGE OF ENGINEERING',
      collegeAffiliation: 'An Autonomous Institution, Affiliated to Anna University, Chennai (Accredited by NAAC)',
      validity: 'August 2023 to May 2027',
      address: '3910 MALLIGAI NAGAR, KALAYARKOIL, SIVAGANGAI',
      pincode: '630551',
      email: 'ashishpandi06072005@gmail.com',
      phones: ['6384940382', '8610481980'],
      dob: '06-07-2005',
      bloodGroup: 'B+',
      year: '3',
      section: 'A',
      semester: 'Semester 5',
      batch: '2023 - 2027',
      semesterDuration: 'August 2025 – December 2025',
    ),
  ];

  static List<StudentIdCardDetails> _registry = List.from(_initialRegistry);
  static bool _initialized = false;

  /// Loads stored students and academic settings from SharedPreferences
  static Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load Academic Config
      final acadJson = prefs.getString(_prefsKeyAcademic);
      if (acadJson != null) {
        _currentConfig = AcademicConfig.fromJson(jsonDecode(acadJson));
      }

      // Load Custom / Updated Students
      final studentsJson = prefs.getString(_prefsKeyStudents);
      if (studentsJson != null) {
        final List list = jsonDecode(studentsJson);
        final loaded = list.map((e) => StudentIdCardDetails.fromJson(e)).toList();
        if (loaded.isNotEmpty) {
          _registry = loaded;
        }
      }

      // Strictly purge any dummy students (Jane Smith, Alex Johnson, or legacy test IDs)
      _registry.removeWhere((s) {
        final name = s.name.toLowerCase();
        final roll = s.barcode.toLowerCase();
        return name.contains('jane') || 
               name.contains('alex') || 
               roll == '714022104003' || 
               roll == '714022104004';
      });

      // Save purged list back to SharedPreferences
      final cleanedList = _registry.map((s) => s.toJson()).toList();
      await prefs.setString(_prefsKeyStudents, jsonEncode(cleanedList));

      _initialized = true;

      // Sync with cloud database
      await syncFromCloud();
    } catch (e) {
      print('StudentDirectory.init error: $e');
    }
  }

  /// Syncs students directly from Supabase PostgreSQL cloud table
  static Future<void> syncFromCloud() async {
    try {
      final api = ApiClient();
      final response = await api.get('/students?select=*&order=id.asc');
      if (response is List && response.isNotEmpty) {
        for (final item in response) {
          final s = item as Map<String, dynamic>;
          final regNum = s['register_number']?.toString() ?? '';
          if (regNum.isEmpty) continue;
          final clean = cleanCode(regNum);

          // Skip if dummy
          final sName = (s['student_name'] ?? '').toString().toLowerCase();
          if (sName.contains('jane') || sName.contains('alex')) continue;

          final existingIndex = _registry.indexWhere((stu) => cleanCode(stu.barcode) == clean || stu.id == s['id']?.toString());
          if (existingIndex != -1) {
            // Update cloud-linked fields
            _registry[existingIndex] = _registry[existingIndex].copyWith(
              name: s['student_name'] ?? _registry[existingIndex].name,
              department: s['department'] ?? _registry[existingIndex].department,
              year: s['year']?.toString() ?? _registry[existingIndex].year,
              section: s['section'] ?? _registry[existingIndex].section,
              email: s['email'] ?? _registry[existingIndex].email,
            );
          } else {
            // Add new student from cloud
            _registry.add(StudentIdCardDetails(
              id: s['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
              barcode: regNum,
              name: s['student_name'] ?? 'Student',
              course: 'B.Tech.',
              department: s['department'] ?? _currentConfig.department,
              college: 'K.L.N. COLLEGE OF ENGINEERING',
              collegeAffiliation: 'An Autonomous Institution, Affiliated to Anna University, Chennai (Accredited by NAAC)',
              validity: 'August 2023 to May 2027',
              address: s['address'] ?? 'Campus Residential Hall, Pottapalayam',
              pincode: '630612',
              email: s['email'] ?? '$clean@college.edu',
              phones: [s['phone'] ?? '9842014033'],
              dob: s['dob'] ?? '19-12-2005',
              bloodGroup: s['blood_group'] ?? 'O+VE',
              year: s['year']?.toString() ?? _currentConfig.year,
              section: s['section'] ?? _currentConfig.section,
              semester: _currentConfig.semester,
              batch: _currentConfig.batch,
              semesterDuration: _currentConfig.semesterDuration,
            ));
          }
        }
        final prefs = await SharedPreferences.getInstance();
        final list = _registry.map((s) => s.toJson()).toList();
        await prefs.setString(_prefsKeyStudents, jsonEncode(list));
      }
    } catch (e) {
      print('syncFromCloud error: $e');
    }
  }

  /// Saves updated academic configuration
  static Future<void> saveAcademicConfig(AcademicConfig config) async {
    _currentConfig = config;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyAcademic, jsonEncode(config.toJson()));
    } catch (e) {
      print('Error saving academic config: $e');
    }
  }

  /// Strips the barcode prefix to get raw roll number
  static String cleanCode(String code) {
    String cleaned = code.trim();
    if (cleaned.startsWith(']C1') || cleaned.startsWith(']c1')) {
      cleaned = cleaned.substring(3);
    } else if (cleaned.startsWith('JC1') || cleaned.startsWith('jc1') || cleaned.startsWith('Jc1')) {
      cleaned = cleaned.substring(3);
    } else if (cleaned.startsWith(']C') || cleaned.startsWith(']c')) {
      cleaned = cleaned.substring(2);
    } else if (cleaned.startsWith('JC') || cleaned.startsWith('jc')) {
      cleaned = cleaned.substring(2);
    } else if (cleaned.startsWith(']')) {
      cleaned = cleaned.replaceAll(RegExp(r'^\][A-Za-z0-9]?'), '');
    }
    
    final digitsOnly = cleaned.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length == 7 && (digitsOnly.startsWith('1235014') || digitsOnly.startsWith('1235025'))) {
      return digitsOnly.substring(1);
    }
    if (digitsOnly.isNotEmpty) return digitsOnly;
    return code.trim().toLowerCase();
  }

  /// Retrieves student details by barcode or roll number
  static StudentIdCardDetails? findByBarcode(String code) {
    final rawClean = code.trim().toLowerCase();
    final digits = cleanCode(code);

    for (final student in _registry) {
      final studentDigits = cleanCode(student.barcode);
      
      if (student.barcode.toLowerCase() == rawClean ||
          student.barcode.toLowerCase() == digits ||
          studentDigits == digits ||
          student.id == rawClean ||
          student.id == digits ||
          student.name.toLowerCase().contains(rawClean)) {
        return student;
      }

      if (digits.isNotEmpty && studentDigits.isNotEmpty) {
        if (digits.endsWith(studentDigits) || studentDigits.endsWith(digits)) {
          return student;
        }
      }
    }
    return null;
  }

  /// Full student lookup mechanism for Admin Panel & Scanner
  static StudentIdCardDetails? findByIdOrRoll(String query) {
    if (query.trim().isEmpty) return null;
    return findByBarcode(query);
  }

  /// Admin method: Save or update a student
  static Future<void> saveStudent(StudentIdCardDetails student) async {
    final index = _registry.indexWhere((s) => s.id == student.id || cleanCode(s.barcode) == cleanCode(student.barcode));
    if (index != -1) {
      _registry[index] = student;
    } else {
      _registry.add(student);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _registry.map((s) => s.toJson()).toList();
      await prefs.setString(_prefsKeyStudents, jsonEncode(list));

      // Asynchronous cloud sync to Supabase PostgreSQL
      try {
        final api = ApiClient();
        final clean = cleanCode(student.barcode);
        final existing = await api.get('/students?register_number=eq.$clean');
        if (existing is List && existing.isNotEmpty) {
          await api.patch('/students?register_number=eq.$clean', body: {
            'student_name': student.name,
            'department': student.department,
            'email': student.email,
            'year': int.tryParse(student.year) ?? 3,
            'section': student.section,
          });
        } else {
          await api.post('/students', body: {
            'student_name': student.name,
            'register_number': clean,
            'department': student.department,
            'year': int.tryParse(student.year) ?? 3,
            'section': student.section,
            'email': student.email,
            'is_active': true,
          });
        }
      } catch (cloudErr) {
        print('Supabase student cloud sync error: $cloudErr');
      }
    } catch (e) {
      print('Error saving student to prefs: $e');
    }
  }

  /// Admin method: Delete a student by ID or barcode
  static Future<bool> deleteStudent(String idOrBarcode) async {
    final clean = cleanCode(idOrBarcode);
    final index = _registry.indexWhere(
      (s) => s.id == idOrBarcode || cleanCode(s.barcode) == clean || s.barcode == idOrBarcode,
    );
    if (index == -1) return false;

    final removed = _registry.removeAt(index);

    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _registry.map((s) => s.toJson()).toList();
      await prefs.setString(_prefsKeyStudents, jsonEncode(list));

      // Asynchronous cloud delete from Supabase PostgreSQL
      try {
        final api = ApiClient();
        final regClean = cleanCode(removed.barcode);
        await api.delete('/students?register_number=eq.$regClean');
      } catch (cloudErr) {
        print('Supabase student cloud delete error: $cloudErr');
      }
      return true;
    } catch (e) {
      print('Error deleting student from prefs: $e');
      return false;
    }
  }

  static List<StudentIdCardDetails> getAll() => List.unmodifiable(_registry);
}
