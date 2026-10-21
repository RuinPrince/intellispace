class Student {
  final String id;
  final String name;
  final String registerNumber;
  final String department;
  final int year;
  final String section;
  final String? batch;
  final String? semester;
  final String? email;
  final String? phone;
  final String? dob;
  final String? bloodGroup;
  final String? address;
  final String? college;
  final String? validity;

  Student({
    required this.id,
    required this.name,
    required this.registerNumber,
    required this.department,
    this.year = 4,
    this.section = 'A',
    this.batch = '2023-2027',
    this.semester = 'Semester 7',
    this.email,
    this.phone,
    this.dob,
    this.bloodGroup,
    this.address,
    this.college,
    this.validity,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['student_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['student_name'] ?? json['name'] ?? '',
      registerNumber: json['register_number'] ?? json['barcode'] ?? '',
      department: json['department'] ?? 'Information Technology',
      year: json['year'] is int ? json['year'] : (int.tryParse(json['year']?.toString() ?? '4') ?? 4),
      section: json['section']?.toString() ?? 'A',
      batch: json['batch']?.toString() ?? '2023-2027',
      semester: json['semester']?.toString() ?? 'Semester 7',
      email: json['email'],
      phone: json['phone'],
      dob: json['dob'],
      bloodGroup: json['blood_group'],
      address: json['address'],
      college: json['college'],
      validity: json['validity'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_name': name,
      'register_number': registerNumber,
      'department': department,
      'year': year,
      'section': section,
      'batch': batch,
      'semester': semester,
      'email': email,
      'phone': phone,
      'dob': dob,
      'blood_group': bloodGroup,
      'address': address,
      'college': college,
      'validity': validity,
    };
  }
}

class AttendanceRecord {
  final String id;
  final Student student;
  final DateTime timestamp;
  final bool isPresent;
  final String status; // 'present', 'absent', 'late'
  final String? remarks;

  AttendanceRecord({
    required this.id,
    required this.student,
    required this.timestamp,
    required this.isPresent,
    this.status = 'absent',
    this.remarks,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    final statusStr = (json['status']?.toString() ?? 'absent').toLowerCase();
    bool present = statusStr == 'present';
    
    // Combine date and time
    String dateStr = json['attendance_date'] ?? DateTime.now().toIso8601String().split('T')[0];
    String timeStr = json['check_in_time'] ?? '00:00:00';
    DateTime ts = DateTime.tryParse('${dateStr}T$timeStr') ?? DateTime.now();

    final studentMap = json['students'] is Map<String, dynamic> 
        ? json['students'] 
        : json;

    return AttendanceRecord(
      id: json['id']?.toString() ?? '',
      student: Student.fromJson(studentMap),
      timestamp: ts,
      isPresent: present,
      status: statusStr,
      remarks: statusStr == 'late' ? 'Late arrival' : null,
    );
  }
}
