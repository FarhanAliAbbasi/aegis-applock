import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/security_service.dart';
import 'state/app_lock_state.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SecurityService.initialize();
  runApp(const AegisAppLockApp());
}

class AegisAppLockApp extends StatefulWidget {
  const AegisAppLockApp({super.key});

  @override
  State<AegisAppLockApp> createState() => _AegisAppLockAppState();
}

class _AegisAppLockAppState extends State<AegisAppLockApp> {
  final AppLockState _appLockState = AppLockState();
  bool _isOnboardingCompleted = false;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    final prefs = await SharedPreferences.getInstance();
    _isOnboardingCompleted = prefs.getBool('aegis_onboarding_completed') ?? false;

    await _appLockState.initialize();

    if (mounted) {
      setState(() {
        _isReady = true;
      });
    }
  }

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('aegis_onboarding_completed', true);
    await _appLockState.initialize();
    await _appLockState.securityService.syncToNative();
    if (mounted) {
      setState(() {
        _isOnboardingCompleted = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aegis AppLock',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: !_isReady
          ? const Scaffold(
              backgroundColor: AppTheme.background,
              body: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryCyan),
              ),
            )
          : _isOnboardingCompleted
              ? DashboardScreen(state: _appLockState)
              : OnboardingScreen(onComplete: _finishOnboarding),
    );
  }
}
