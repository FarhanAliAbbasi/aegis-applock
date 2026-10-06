import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../services/security_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pin_pad_view.dart';
import '../widgets/pattern_pad_view.dart';
import 'security_questions_screen.dart';

class LockScreen extends StatefulWidget {
  final String appName;
  final String packageName;
  final VoidCallback? onUnlocked;

  const LockScreen({
    super.key,
    required this.appName,
    required this.packageName,
    this.onUnlocked,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final SecurityService _securityService = SecurityService();
  final LocalAuthentication _localAuth = LocalAuthentication();

  String _lockType = 'pin';
  bool _isError = false;
  int _remainingLockoutSeconds = 0;
  int _failedAttempts = 0;
  bool _isQuestionsRequired = false;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _initializeLock();
  }

  Future<void> _initializeLock() async {
    await _securityService.init();
    _lockType = _securityService.getLockType();
    _checkLockout();

    if (_securityService.isBiometricEnabled() && _remainingLockoutSeconds == 0) {
      _triggerBiometrics();
    }
  }

  void _checkLockout() {
    _failedAttempts = _securityService.getFailedAttempts();
    _remainingLockoutSeconds = _securityService.getRemainingLockoutSeconds();
    _isQuestionsRequired = _securityService.isSecurityQuestionsRequired();

    if (_remainingLockoutSeconds > 0) {
      _startCountdown();
    }
    setState(() {});

    if (_isQuestionsRequired) {
      _openSecurityQuestionsChallenge();
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingLockoutSeconds > 1) {
        setState(() {
          _remainingLockoutSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          _remainingLockoutSeconds = 0;
        });
        if (_securityService.isSecurityQuestionsRequired()) {
          _openSecurityQuestionsChallenge();
        }
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _triggerBiometrics() async {
    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Authenticate to unlock ${widget.appName}',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (didAuthenticate) {
        _handleSuccess();
      }
    } catch (_) {}
  }

  Future<void> _handlePinSubmitted(String pin) async {
    if (_remainingLockoutSeconds > 0) return;

    final isCorrect = await _securityService.verifyPin(pin);
    if (isCorrect) {
      _handleSuccess();
    } else {
      _handleFailure();
    }
  }

  Future<void> _handlePatternSubmitted(String pattern) async {
    if (_remainingLockoutSeconds > 0) return;

    final isCorrect = await _securityService.verifyPattern(pattern);
    if (isCorrect) {
      _handleSuccess();
    } else {
      _handleFailure();
    }
  }

  void _handleSuccess() {
    HapticFeedback.mediumImpact();
    _securityService.resetFailedAttempts();
    if (widget.onUnlocked != null) {
      widget.onUnlocked!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _handleFailure() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isError = true;
    });

    final status = _securityService.recordFailedAttempt();
    _failedAttempts = status.failedAttempts;
    _remainingLockoutSeconds = status.remainingSeconds;
    _isQuestionsRequired = status.isSecurityQuestionsRequired;

    if (_remainingLockoutSeconds > 0) {
      _startCountdown();
    }

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _isError = false;
        });
      }
    });

    if (_isQuestionsRequired) {
      _openSecurityQuestionsChallenge();
    }
  }

  void _openSecurityQuestionsChallenge() {
    Future.microtask(() {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SecurityQuestionsScreen(
            mode: SecurityQuestionsMode.verify,
            onSuccess: () {
              _securityService.resetFailedAttempts();
              _handleSuccess();
            },
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          // System back redirect to prevent bypassing lock
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon & Name
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryCyan.withValues(alpha: 0.15),
                          blurRadius: 20,
                        ),
                      ],
                      border: Border.all(
                        color: AppTheme.primaryCyan.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: AppTheme.primaryCyan,
                      size: 34,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    '${widget.appName} is Locked',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    _remainingLockoutSeconds > 0
                        ? 'Input suspended for $_remainingLockoutSeconds seconds'
                        : _failedAttempts > 0
                            ? 'Incorrect credentials ($_failedAttempts failed attempts)'
                            : 'Enter your ${_lockType.toUpperCase()} or use biometrics to continue',
                    style: TextStyle(
                      color: _remainingLockoutSeconds > 0 || _failedAttempts > 0
                          ? AppTheme.accentRed
                          : AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: _failedAttempts > 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Authentication Pad
                  if (_lockType == 'pattern')
                    PatternPadView(
                      isEnabled: _remainingLockoutSeconds == 0,
                      isError: _isError,
                      onPatternEntered: _handlePatternSubmitted,
                    )
                  else
                    PinPadView(
                      isError: _isError,
                      remainingLockoutSeconds: _remainingLockoutSeconds,
                      showBiometricButton: _securityService.isBiometricEnabled(),
                      onBiometricTap: _triggerBiometrics,
                      onForgotPinTap: _openSecurityQuestionsChallenge,
                      onPinCompleted: _handlePinSubmitted,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
