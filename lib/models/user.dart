import '../core/constants/app_constants.dart';

class User {
  final String id;
  final String name;
  final String email;
  final AppRole role;
  final String department;
  final String? avatarUrl;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.department,
    this.avatarUrl,
  });

  User copyWith({
    String? id,
    String? name,
    String? email,
    AppRole? role,
    String? department,
    String? avatarUrl,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      department: department ?? this.department,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    AppRole role = AppRole.teacher;
    if (json['role'] == 'admin' || json['role'] == 'administrator') {
      role = AppRole.administrator;
    }

    return User(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: role,
      department: json['department'] ?? '',
      avatarUrl: json['profile_image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role == AppRole.administrator ? 'admin' : 'teacher',
      'department': department,
      'profile_image': avatarUrl,
    };
  }
}
