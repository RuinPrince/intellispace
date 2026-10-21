import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/constants/app_constants.dart';
import 'core/routing/app_router.dart';
import 'features/auth/auth_provider.dart';
import 'repositories/student_directory.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StudentDirectory.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkAuthStatus()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const IntelliSpaceApp(),
    ),
  );
}

class IntelliSpaceApp extends StatefulWidget {
  const IntelliSpaceApp({super.key});

  @override
  State<IntelliSpaceApp> createState() => _IntelliSpaceAppState();
}

class _IntelliSpaceAppState extends State<IntelliSpaceApp> {
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter(context.read<AuthProvider>());
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      routerConfig: _appRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
