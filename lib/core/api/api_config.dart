class ApiConfig {
  // Supabase Cloud Configuration
  static const String supabaseUrl = 'https://xuwsvnhirrkxktcveovp.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_DKDalHd5MGcTaqJK5ptsFQ_8c6RWpUa';
  static const String baseUrl = '$supabaseUrl/rest/v1';
  
  // Auth
  static const String login = '/users';
  static const String me = '/users';
  
  // Dashboard (composed from individual queries in the repository)
  static const String dashboard = '/dashboard';
  
  // Devices
  static const String devices = '/devices?select=*,labs(lab_name)&order=id.asc';
  
  // Labs
  static const String labs = '/labs?select=*&order=id.asc';
  
  // Attendance
  static const String attendanceSummary = '/attendance/summary';
  static const String attendanceToday = '/attendance?select=*,students(*)&order=id.asc';
  
  // Notifications
  static const String notificationsUnread = '/notifications?is_read=eq.false&order=created_at.desc';
  
  // Users / Teachers (Admin)
  static const String users = '/users?select=*&order=id.asc';
}
