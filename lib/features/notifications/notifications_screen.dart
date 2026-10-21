import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../repositories/api_notification_repository.dart';
import '../../models/notification_item.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _repo = ApiNotificationRepository();
  bool _isLoading = true;
  List<NotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final notifications = await _repo.getUnreadNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading notifications: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAllAsRead() async {
    // Optimistic UI update
    setState(() {
      for (var n in _notifications) {
        n.isRead = true;
      }
    });
    await _repo.markAllAsRead();
  }

  void _clearNotifications() {
    setState(() {
      _notifications.clear();
    });
  }

  Future<void> _markAsRead(NotificationItem notification) async {
    if (notification.isRead) return;
    
    // Optimistic update
    setState(() {
      notification.isRead = true;
    });
    
    await _repo.markAsRead(notification.id);
  }

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'device': return Icons.devices;
      case 'attendance': return Icons.how_to_reg;
      default: return Icons.notifications;
    }
  }

  Color _getColorForSeverity(SeverityLevel severity) {
    switch (severity) {
      case SeverityLevel.critical: return AppConstants.statusRed;
      case SeverityLevel.warning: return AppConstants.statusOrange;
      case SeverityLevel.info: return AppConstants.statusBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Notifications',
            onPressed: _loadData,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'read') _markAllAsRead();
              if (value == 'clear') _clearNotifications();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'read', child: Text('Mark all as read')),
              const PopupMenuItem(value: 'clear', child: Text('Clear all')),
            ],
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadData,
        child: _notifications.isEmpty
            ? const Center(child: Text('No notifications'))
            : ListView.separated(
                itemCount: _notifications.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  final color = _getColorForSeverity(notification.severity);
                  
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    tileColor: notification.isRead ? null : color.withValues(alpha: 0.05),
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.1),
                          child: Icon(_getIconForCategory(notification.category), color: color),
                        ),
                        if (!notification.isRead)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(
                      notification.title,
                      style: TextStyle(
                        fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(notification.description),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM d, h:mm a').format(notification.timestamp),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    onTap: () => _markAsRead(notification),
                  );
                },
              ),
      ),
    );
  }
}
