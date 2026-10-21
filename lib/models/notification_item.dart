import '../core/constants/app_constants.dart';

class NotificationItem {
  final String id;
  final String title;
  final String description;
  final DateTime timestamp;
  final String category;
  final SeverityLevel severity;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.category,
    required this.severity,
    this.isRead = false,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    SeverityLevel sev = SeverityLevel.info;
    if (json['severity'] == 'warning') {
      sev = SeverityLevel.warning;
    } else if (json['severity'] == 'critical') {
      sev = SeverityLevel.critical;
    }

    return NotificationItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['message'] ?? '',
      timestamp: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now() 
          : DateTime.now(),
      category: json['notification_type'] ?? 'system',
      severity: sev,
      isRead: json['is_read'] == 1 || json['is_read'] == true,
    );
  }
}
