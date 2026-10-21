import '../core/api/api_client.dart';
import '../core/api/api_config.dart';
import '../models/notification_item.dart';

class ApiNotificationRepository {
  final ApiClient _api = ApiClient();

  Future<List<NotificationItem>> getUnreadNotifications() async {
    try {
      final response = await _api.get(ApiConfig.notificationsUnread);
      if (response is List) {
        return response
            .map((json) => NotificationItem.fromJson(json))
            .where((n) => !n.title.startsWith('STUDENT_AVATAR_'))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching notifications: $e');
      return [];
    }
  }

  Future<bool> markAsRead(String id) async {
    try {
      await _api.patch('/notifications?id=eq.$id', body: {'is_read': true});
      return true;
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }

  Future<bool> markAllAsRead() async {
    try {
      await _api.patch('/notifications?is_read=eq.false', body: {'is_read': true});
      return true;
    } catch (e) {
      print('Error marking all notifications as read: $e');
      return false;
    }
  }
}
