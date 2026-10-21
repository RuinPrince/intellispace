import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import '../../core/constants/app_constants.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isAdmin = authProvider.role == AppRole.administrator;

    return Scaffold(
      appBar: AppBar(title: const Text('More Features')),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16.0),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _buildMoreCard(context, 'Attendance', Icons.fact_check_outlined, '/more/attendance', Colors.blue),
          _buildMoreCard(context, 'Notifications', Icons.notifications_none, '/more/notifications', Colors.red),
          if (isAdmin)
            _buildMoreCard(context, 'Academic & Students', Icons.school_outlined, '/more/admin-students', Colors.orange),
          if (isAdmin)
            _buildMoreCard(context, 'Manage Labs', Icons.science_outlined, '/more/admin-labs', Colors.teal),
          if (isAdmin)
            _buildMoreCard(context, 'Manage Teachers', Icons.group_add_outlined, '/more/admin-teachers', Colors.indigo),
          _buildMoreCard(context, 'Settings', Icons.settings_outlined, '/more/settings', Colors.grey),
        ],
      ),
    );
  }

  Widget _buildMoreCard(BuildContext context, String title, IconData icon, String route, Color color) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(route),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
