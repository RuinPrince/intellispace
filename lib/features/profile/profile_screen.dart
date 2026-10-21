import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_provider.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/api/api_client.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showEditProfileDialog(BuildContext context, AuthProvider authProvider) {
    final user = authProvider.currentUser;
    if (user == null) return;

    final nameCtrl = TextEditingController(text: user.name);
    final emailCtrl = TextEditingController(text: user.email);
    final deptCtrl = TextEditingController(text: user.department);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: deptCtrl,
                decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final success = await authProvider.updateProfile(
                name: nameCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                department: deptCtrl.text.trim(),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Profile updated successfully!' : 'Failed to save changes.'),
                    backgroundColor: success ? AppConstants.statusGreen : AppConstants.statusRed,
                  ),
                );
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showSecurityDialog(BuildContext context, AuthProvider authProvider) {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool isTesting = false;
    String connectionStatus = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Security & Cloud Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CHANGE PASSWORD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                TextField(
                  controller: oldPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Current Password', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: newPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm Password', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const Text('CLOUD BACKEND CONNECTIVITY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        connectionStatus.isEmpty ? 'Supabase PostgreSQL Cloud' : connectionStatus,
                        style: TextStyle(
                          fontSize: 12,
                          color: connectionStatus.contains('Connected') ? Colors.green : Colors.blueGrey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: isTesting ? null : () async {
                        setState(() {
                          isTesting = true;
                          connectionStatus = 'Testing latency...';
                        });
                        final stopwatch = Stopwatch()..start();
                        try {
                          final api = ApiClient();
                          await api.get('/users?select=id&limit=1');
                          stopwatch.stop();
                          setState(() {
                            isTesting = false;
                            connectionStatus = 'Connected (${stopwatch.elapsedMilliseconds} ms latency)';
                          });
                        } catch (e) {
                          stopwatch.stop();
                          setState(() {
                            isTesting = false;
                            connectionStatus = 'Offline / Error: $e';
                          });
                        }
                      },
                      child: isTesting 
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) 
                          : const Text('Ping API'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ElevatedButton(
              onPressed: () async {
                if (oldPassCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter your current password.'), backgroundColor: Colors.red),
                  );
                  return;
                }
                if (newPassCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a new password.'), backgroundColor: Colors.red),
                  );
                  return;
                }
                if (newPassCtrl.text != confirmPassCtrl.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('New passwords do not match!'), backgroundColor: Colors.red),
                  );
                  return;
                }
                final res = await authProvider.changePassword(oldPassCtrl.text, newPassCtrl.text);
                if (context.mounted) {
                  if (res) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password updated successfully!'), backgroundColor: Colors.green),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(authProvider.errorMessage ?? 'Current password does not match!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAppearanceDialog(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Appearance Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Dark Mode Theme'),
                subtitle: const Text('Deep OLED dark palette tailored for mobile'),
                value: themeProvider.isDarkMode,
                onChanged: (val) {
                  themeProvider.toggleTheme(val);
                  setModalState(() {});
                },
                secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Color Accent'),
                subtitle: const Text('Cyber Cyan & Emerald Green (High Contrast)'),
                trailing: const Icon(Icons.check, color: Colors.teal),
                onTap: () {
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final theme = Theme.of(context);

    if (user == null) return const Scaffold();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Profile',
            onPressed: () async {
              await authProvider.checkAuthStatus();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile refreshed!'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => authProvider.checkAuthStatus(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
            const SizedBox(height: 12),
            CircleAvatar(
              radius: 46,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                style: theme.textTheme.displayMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              user.name,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              user.email,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: user.role == AppRole.administrator 
                    ? AppConstants.statusGreen.withValues(alpha: 0.15) 
                    : theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: user.role == AppRole.administrator 
                      ? AppConstants.statusGreen.withValues(alpha: 0.5) 
                      : Colors.transparent,
                ),
              ),
              child: Text(
                user.role == AppRole.administrator ? 'ADMINISTRATOR' : 'FACULTY / TEACHER',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: user.role == AppRole.administrator ? AppConstants.statusGreen : theme.colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Clean Info Card (Resolves "Depart \n ment" wrapping bug cleanly!)
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                    child: Row(
                      children: [
                        Icon(Icons.business, size: 22, color: theme.colorScheme.primary),
                        const SizedBox(width: 14),
                        const SizedBox(
                          width: 90,
                          child: Text(
                            'Department',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            user.department,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                    child: Row(
                      children: [
                        Icon(Icons.badge, size: 22, color: theme.colorScheme.primary),
                        const SizedBox(width: 14),
                        const SizedBox(
                          width: 90,
                          child: Text(
                            'Employee ID',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            user.id,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Admin Special Control Banner
            if (user.role == AppRole.administrator) ...[
              Card(
                elevation: 0,
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.indigo,
                    child: Icon(Icons.admin_panel_settings, color: Colors.white),
                  ),
                  title: const Text(
                    'Student & Academic Controls',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Configure sem duration, dept, sec & retrieve student ID records',
                    style: TextStyle(fontSize: 11),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => context.push('/more/admin-students'),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Fully Working Interactive Settings Links
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Edit Profile'),
                    subtitle: const Text('Update name, email & department'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showEditProfileDialog(context, authProvider),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.security),
                    title: const Text('Security Settings'),
                    subtitle: const Text('Password & Supabase Cloud ping test'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showSecurityDialog(context, authProvider),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('Appearance'),
                    subtitle: const Text('Dark mode & contrast options'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showAppearanceDialog(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            
            // Logout with Confirmation
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to log out of IntelliSpace?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await authProvider.logout();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
  }
}
