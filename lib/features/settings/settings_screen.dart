import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme_provider.dart';
import '../auth/auth_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _deviceAlerts = true;
  String _defaultCampus = 'Tech Innovation Center';
  String _defaultLab = 'Lab 1';
  final String _language = 'English';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _buildSectionHeader('APPEARANCE & GENERAL', theme),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Switch between light and sleek dark mode'),
            value: themeProvider.isDarkMode,
            onChanged: (val) => context.read<ThemeProvider>().toggleTheme(val),
            secondary: const Icon(Icons.dark_mode_outlined),
          ),
          SwitchListTile(
            title: const Text('Push Notifications'),
            subtitle: const Text('Receive hardware and attendance alerts'),
            value: _notifications,
            onChanged: (val) => setState(() => _notifications = val),
            secondary: const Icon(Icons.notifications_outlined),
          ),
          ListTile(
            title: const Text('Language'),
            subtitle: Text(_language),
            leading: const Icon(Icons.language),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Language: English (Default)')),
              );
            },
          ),
          
          _buildSectionHeader('CAMPUS & LAB PREFERENCES', theme),
          ListTile(
            title: const Text('Default Campus'),
            subtitle: Text(_defaultCampus),
            leading: const Icon(Icons.business),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final selected = await showDialog<String>(
                context: context,
                builder: (ctx) => SimpleDialog(
                  title: const Text('Select Default Campus'),
                  children: [
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, 'Tech Innovation Center'),
                      child: const Text('Tech Innovation Center'),
                    ),
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, 'Main Campus Block'),
                      child: const Text('Main Campus Block'),
                    ),
                  ],
                ),
              );
              if (selected != null) {
                setState(() => _defaultCampus = selected);
              }
            },
          ),
          ListTile(
            title: const Text('Default Lab'),
            subtitle: Text(_defaultLab),
            leading: const Icon(Icons.science),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final selected = await showDialog<String>(
                context: context,
                builder: (ctx) => SimpleDialog(
                  title: const Text('Select Default Lab'),
                  children: [
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, 'Lab 1'),
                      child: const Text('Lab 1 (Default NodeMCU)'),
                    ),
                  ],
                ),
              );
              if (selected != null) {
                setState(() => _defaultLab = selected);
              }
            },
          ),
          
          _buildSectionHeader('ALERT PREFERENCES', theme),
          SwitchListTile(
            title: const Text('Device State Alerts'),
            subtitle: const Text('Notify when relays toggle state'),
            value: _deviceAlerts,
            onChanged: (val) => setState(() => _deviceAlerts = val),
            secondary: const Icon(Icons.power_settings_new),
          ),
          
          _buildSectionHeader('ACCOUNT & SYSTEM', theme),
          ListTile(
            title: const Text('App Version'),
            subtitle: const Text('IntelliSpace v2.2 (Modified Spec)'),
            leading: const Icon(Icons.info_outline),
          ),
          ListTile(
            title: const Text('Sign Out'),
            subtitle: Text('Logged in as ${authProvider.currentUser?.email ?? 'User'}'),
            leading: const Icon(Icons.logout, color: Colors.red),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to log out of IntelliSpace?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign Out'),
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
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
