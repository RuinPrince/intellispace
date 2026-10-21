import 'package:go_router/go_router.dart';
import '../../features/auth/auth_provider.dart';

import '../../features/auth/login_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/lab_control/lab_control_screen.dart';
import '../../features/shell/more_screen.dart';
import '../../features/attendance/attendance_screen.dart';
import '../../features/attendance/student_list_screen.dart';
import '../../features/attendance/qr_scanner_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/admin/admin_lab_screen.dart';
import '../../features/admin/admin_teachers_screen.dart';
import '../../features/admin/admin_student_screen.dart';
import '../../features/academic/academic_schedule_screen.dart';
import '../../features/admin/admin_upload_schedule_screen.dart';

class AppRouter {
  final AuthProvider authProvider;

  AppRouter(this.authProvider);

  late final GoRouter router = GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isAuthenticated = authProvider.isAuthenticated;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isAuthenticated && !isLoginRoute) {
        return '/login';
      }

      if (isAuthenticated && isLoginRoute) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          // Tab 1: Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          // Tab 2: Lab Control
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/lab-control',
                builder: (context, state) => const LabControlScreen(),
              ),
            ],
          ),
          // Tab 3: More
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const MoreScreen(),
                routes: [
                  GoRoute(
                    path: 'attendance',
                    builder: (context, state) => const AttendanceScreen(),
                    routes: [
                      GoRoute(
                        path: 'students',
                        builder: (context, state) {
                          final date = state.uri.queryParameters['date'];
                          return StudentListScreen(initialDate: date);
                        },
                      ),
                      GoRoute(
                        path: 'scan',
                        builder: (context, state) => const QrScannerScreen(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'notifications',
                    builder: (context, state) => const NotificationsScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsScreen(),
                  ),
                  GoRoute(
                    path: 'admin-labs',
                    builder: (context, state) => const AdminLabScreen(),
                  ),
                  GoRoute(
                    path: 'admin-teachers',
                    builder: (context, state) => const AdminTeachersScreen(),
                  ),
                  GoRoute(
                    path: 'admin-students',
                    builder: (context, state) => const AdminStudentScreen(),
                  ),
                  GoRoute(
                    path: 'schedule',
                    builder: (context, state) {
                      final section = state.uri.queryParameters['section'] ?? 'A';
                      final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
                      return AcademicScheduleScreen(initialSection: section, initialTabIndex: tab);
                    },
                  ),
                  GoRoute(
                    path: 'admin-schedule',
                    builder: (context, state) => const AdminUploadScheduleScreen(),
                  ),
                  GoRoute(
                    path: 'profile',
                    builder: (context, state) => const ProfileScreen(),
                  ),
                ],
              ),
            ],
          ),
          // Tab 4: Dedicated Profile in Footer
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
