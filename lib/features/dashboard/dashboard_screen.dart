import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/widgets/status_card.dart';
import '../auth/auth_provider.dart';
import '../../repositories/api_dashboard_repository.dart';
import '../../services/energy_tracking_service.dart';
import 'widgets/live_ongoing_period_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiDashboardRepository _dashboardRepo = ApiDashboardRepository();
  Timer? _energyTimer;
  
  bool _isLoading = true;
  Map<String, dynamic> _dashboardData = {};
  TodayEnergySummary? _energySummary;

  @override
  void initState() {
    super.initState();
    _loadData();
    _energyTimer = Timer.periodic(const Duration(seconds: 10), (_) => _refreshEnergy());
  }

  @override
  void dispose() {
    _energyTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshEnergy() async {
    if (!mounted) return;
    final bool isFanOn = _dashboardData['devices']?['is_fan_on'] ?? false;
    final bool isLightOn = _dashboardData['devices']?['is_light_on'] ?? false;
    try {
      final summary = await EnergyTrackingService.getTodayEnergySummary(
        isFanOn: isFanOn,
        isLightOn: isLightOn,
      );
      if (mounted) {
        setState(() => _energySummary = summary);
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      _dashboardData = await _dashboardRepo.getDashboardData();
    } catch (_) {
      // Handled silently with fallback
    }

    final bool isFanOn = _dashboardData['devices']?['is_fan_on'] ?? false;
    final bool isLightOn = _dashboardData['devices']?['is_light_on'] ?? false;
    try {
      _energySummary = await EnergyTrackingService.getTodayEnergySummary(
        isFanOn: isFanOn,
        isLightOn: isLightOn,
      );
    } catch (_) {}
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMMM d').format(now);

    // Greeting based on time of day
    String greeting = 'Good Morning';
    if (now.hour >= 12 && now.hour < 17) {
      greeting = 'Good Afternoon';
    } else if (now.hour >= 17) {
      greeting = 'Good Evening';
    }

    final bool isFanOn = _dashboardData['devices']?['is_fan_on'] ?? false;
    final bool isLightOn = _dashboardData['devices']?['is_light_on'] ?? false;

    // User display name
    String displayName = user?.name.trim() ?? '';
    if (displayName.isEmpty || displayName == 'Dr.' || displayName == 'Dr') {
      displayName = user?.role == AppRole.administrator ? 'Administrator' : 'Dr. Sarah Jenkins';
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greeting, $displayName',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Sync Dashboard Data',
                          onPressed: _loadData,
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => context.go('/profile'),
                          child: user?.avatarUrl != null
                              ? CircleAvatar(
                                  backgroundImage: NetworkImage(user!.avatarUrl!),
                                  radius: 22,
                                )
                              : CircleAvatar(
                                  backgroundColor: theme.colorScheme.primaryContainer,
                                  radius: 22,
                                  child: Icon(Icons.person, color: theme.colorScheme.onPrimaryContainer, size: 22),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Live Ongoing Period & Real-Time Countdown Widget
                const LiveOngoingPeriodWidget(),

                // Status Grid
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.2,
                  children: [
                    StatusCard(
                      title: 'Today\'s Attendance',
                      value: '${_dashboardData['attendance']?['percentage'] ?? 0}%',
                      subtitle: '${_dashboardData['attendance']?['present'] ?? 0} / ${_dashboardData['attendance']?['total'] ?? 0} students',
                      icon: Icons.groups,
                      iconColor: AppConstants.statusBlue,
                      onTap: () => context.push('/more/attendance'),
                    ),
                    StatusCard(
                      title: 'Active Devices',
                      value: '${_dashboardData['devices']?['active'] ?? 0} / ${_dashboardData['devices']?['total'] ?? 0}',
                      subtitle: '${((_dashboardData['devices']?['total'] ?? 0) - (_dashboardData['devices']?['active'] ?? 0))} turned off',
                      icon: Icons.power_settings_new,
                      iconColor: AppConstants.statusGreen,
                      onTap: () => context.go('/lab-control'),
                    ),
                    StatusCard(
                      title: 'Total Labs',
                      value: '${_dashboardData['labs']?['total'] ?? 0}',
                      subtitle: 'Registered labs',
                      icon: Icons.science,
                      iconColor: AppConstants.statusOrange,
                      onTap: () => context.go('/lab-control'),
                    ),
                    StatusCard(
                      title: 'System Status',
                      value: 'Online',
                      subtitle: 'Hardware poll: 1.5s',
                      icon: Icons.check_circle_outline,
                      iconColor: AppConstants.statusGreen,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Real-Time IoT Equipment Status
                _buildRealTimeEquipmentStatus(theme, isFanOn, isLightOn),
                const SizedBox(height: 24),

                // Quick Actions
                Text(
                  'Quick Actions',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickAction(context, 'Lab Control', Icons.lightbulb_outline, () => context.go('/lab-control')),
                      _buildQuickAction(context, 'Attendance', Icons.fact_check_outlined, () => context.push('/more/attendance')),
                      _buildQuickAction(context, 'Timetable (A/B)', Icons.table_chart_outlined, () => context.push('/more/schedule')),
                      _buildQuickAction(context, 'Circular 321', Icons.calendar_month_outlined, () => context.push('/more/schedule?tab=1')),
                      if (user?.role == AppRole.administrator)
                        _buildQuickAction(context, 'Upload Schedule', Icons.cloud_upload_outlined, () => context.push('/more/admin-schedule')),
                      _buildQuickAction(context, 'Notifications', Icons.notifications_outlined, () => context.push('/more/notifications')),
                      _buildQuickAction(context, 'Profile', Icons.person_outline, () => context.go('/profile')),
                    ],
                  ),
                ),
                // KLNCE Academic Schedule & 11:00 AM Cutoff Summary Card
                Card(
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'KLNCE Academic Schedules',
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Odd Sem 2026-2027 • Circular 321 • 8 Periods/Day',
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.table_chart_rounded, size: 16),
                                label: const Text('Section A', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => context.push('/more/schedule?section=A'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.table_chart_rounded, size: 16),
                                label: const Text('Section B', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => context.push('/more/schedule?section=B'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.calendar_month_rounded, size: 16),
                                label: const Text('Circular', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => context.push('/more/schedule?tab=1'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () => context.push('/more/attendance/students'),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: now.hour >= 11 ? Colors.red.withValues(alpha: 0.08) : Colors.amber.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: now.hour >= 11 ? Colors.red.withValues(alpha: 0.25) : Colors.amber.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  now.hour >= 11 ? Icons.alarm_on_rounded : Icons.alarm_rounded,
                                  size: 16,
                                  color: now.hour >= 11 ? Colors.red.shade800 : Colors.brown.shade800,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    now.hour >= 11
                                        ? '11:00 AM Cutoff Active • Unmarked students notified via Parent SMS.'
                                        : '11:00 AM Cutoff: Students not present by 11 AM will receive Absentee SMS.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: now.hour >= 11 ? Colors.red.shade900 : Colors.brown.shade900,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Device Status Overview
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Device Overview',
                              style: theme.textTheme.titleMedium,
                            ),
                            TextButton(
                              onPressed: () => context.go('/lab-control'),
                              child: const Text('View All'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDeviceStatusRow(
                          context,
                          'Exhaust Fan',
                          Icons.mode_fan_off,
                          Colors.cyan,
                          isFanOn ? 1 : 0,
                          1,
                        ),
                        const SizedBox(height: 12),
                        _buildDeviceStatusRow(
                          context,
                          'Ceiling Light',
                          Icons.lightbulb,
                          Colors.amber,
                          isLightOn ? 1 : 0,
                          1,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRealTimeEquipmentStatus(ThemeData theme, bool isFanOn, bool isLightOn) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.memory, color: theme.colorScheme.onPrimaryContainer, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lab Equipment Status',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'IoT & Robotics Lab (ESP32 Node)',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.6), width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.shade400,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.greenAccent.shade400.withValues(alpha: 0.8),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Live Synced',
                        style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Exhaust Fan Live Tile
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isFanOn ? Colors.cyan.withValues(alpha: 0.08) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isFanOn ? Colors.cyan.withValues(alpha: 0.4) : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isFanOn ? Colors.cyan : Colors.grey.shade400,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mode_fan_off, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '5V Exhaust Ventilation Fan',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Relay Pin: GPIO 27 \u2022 Rated Draw: 75 W (0.075 kW)',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isFanOn ? Colors.cyan : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isFanOn ? 'RUNNING' : 'STANDBY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isFanOn ? Colors.white : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Ceiling Light Live Tile
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isLightOn ? Colors.amber.withValues(alpha: 0.08) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isLightOn ? Colors.amber.withValues(alpha: 0.4) : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isLightOn ? Colors.amber.shade700 : Colors.grey.shade400,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lightbulb, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Main Ceiling Light',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Relay Pin: GPIO 26 \u2022 Rated Draw: 40 W (0.040 kW)',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isLightOn ? Colors.amber.shade700 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isLightOn ? 'ACTIVE' : 'OFF',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isLightOn ? Colors.white : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Real-Time Energy Consumption Monitor Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.bolt, color: Colors.amberAccent, size: 20),
                          SizedBox(width: 6),
                          Text(
                            'Energy Consumption Today',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (_energySummary?.activeWatts ?? 0) > 0 ? Colors.green.withValues(alpha: 0.25) : Colors.white10,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (_energySummary?.activeWatts ?? 0) > 0 ? Colors.greenAccent : Colors.white24,
                          ),
                        ),
                        child: Text(
                          (_energySummary?.activeWatts ?? 0) > 0
                              ? '${_energySummary!.activeWatts} W Load'
                              : '0 W (Idle)',
                          style: TextStyle(
                            color: (_energySummary?.activeWatts ?? 0) > 0 ? Colors.greenAccent : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Energy', style: TextStyle(color: Colors.white60, fontSize: 10)),
                            const SizedBox(height: 2),
                            Text(
                              '${_energySummary?.totalKwh.toStringAsFixed(4) ?? '0.0000'} kWh',
                              style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Exhaust Fan (75W)', style: TextStyle(color: Colors.white60, fontSize: 10)),
                            const SizedBox(height: 2),
                            Text(
                              '${_energySummary?.fanKwh.toStringAsFixed(4) ?? '0.0000'} kWh',
                              style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            Text(
                              '${((_energySummary?.fanActiveSecondsToday ?? 0) / 60).round()}m active',
                              style: const TextStyle(color: Colors.white54, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('LED Light (40W)', style: TextStyle(color: Colors.white60, fontSize: 10)),
                            const SizedBox(height: 2),
                            Text(
                              '${_energySummary?.lightKwh.toStringAsFixed(4) ?? '0.0000'} kWh',
                              style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            Text(
                              '${((_energySummary?.lightActiveSecondsToday ?? 0) / 60).round()}m active',
                              style: const TextStyle(color: Colors.white54, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Control Action Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Open Lab Controls & Energy Meter'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: () => context.go('/lab-control'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 100,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.surfaceContainerHighest),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceStatusRow(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    int active,
    int total,
  ) {
    final theme = Theme.of(context);
    final ratio = total > 0 ? active / total : 0.0;

    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$active / $total',
          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
