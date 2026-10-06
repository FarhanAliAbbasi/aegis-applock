import 'package:flutter/material.dart';
import '../services/platform_bridge.dart';
import '../services/security_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pin_pad_view.dart';
import '../widgets/pattern_pad_view.dart';
import 'security_questions_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final SecurityService _securityService = SecurityService();
  final PlatformBridge _bridge = PlatformBridge();

  int _currentPage = 0;
  String _chosenLockType = 'pin';
  String? _recordedPattern;
  String? _recordedPin;
  bool _questionsConfigured = false;
  Map<String, bool> _permissions = {'accessibility': false, 'overlay': false};

  @override
  void initState() {
    super.initState();
    _securityService.init();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final perms = await _bridge.checkPermissions();
    if (mounted) {
      setState(() {
        _permissions = perms;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: List.generate(4, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: index <= _currentPage
                            ? AppTheme.primaryCyan
                            : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Page View
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildWelcomePage(),
                  _buildLockTypePage(),
                  _buildQuestionsPage(),
                  _buildPermissionsPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Step 1: Welcome ---
  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryCyan.withValues(alpha: 0.3),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/logo.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.shield_rounded,
                size: 80,
                color: AppTheme.primaryCyan,
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'AEGIS APPLOCK',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Lightweight, event-driven Android app locker with military-grade PBKDF2 encryption and zero idle battery drain.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryCyan,
                foregroundColor: const Color(0xFF0B0F19),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
                setState(() => _currentPage = 1);
              },
              child: const Text('Get Started', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 2: Choose Lock Type & Setup Credential ---
  Widget _buildLockTypePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose Lock Method',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select your preferred authentication method to protect WhatsApp, Instagram, and your apps.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Lock Type Toggle
          Row(
            children: [
              Expanded(
                child: _buildChoiceCard(
                  title: 'PIN Code',
                  subtitle: '4-Digit numeric keypad',
                  icon: Icons.pin_outlined,
                  isSelected: _chosenLockType == 'pin',
                  onTap: () => setState(() => _chosenLockType = 'pin'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildChoiceCard(
                  title: 'Pattern Lock',
                  subtitle: '3x3 Dot connection',
                  icon: Icons.gesture_outlined,
                  isSelected: _chosenLockType == 'pattern',
                  onTap: () => setState(() => _chosenLockType = 'pattern'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Input Credential
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF232F48)),
            ),
            child: Column(
              children: [
                Text(
                  _chosenLockType == 'pin' ? 'Set Your 4-Digit PIN' : 'Draw Your Pattern',
                  style: const TextStyle(
                    color: AppTheme.primaryCyan,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (_chosenLockType == 'pin')
                  PinPadView(
                    showBiometricButton: false,
                    onPinCompleted: (pin) {
                      setState(() {
                        _recordedPin = pin;
                      });
                    },
                  )
                else
                  PatternPadView(
                    onPatternEntered: (pattern) {
                      setState(() {
                        _recordedPattern = pattern;
                      });
                    },
                  ),
                const SizedBox(height: 16),
                if (_chosenLockType == 'pattern' && _recordedPattern != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Pattern drawn (${_recordedPattern!.split('-').length} dots)',
                        style: const TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => setState(() => _recordedPattern = null),
                        child: const Text('Redraw', style: TextStyle(color: AppTheme.primaryCyan, fontSize: 12)),
                      ),
                    ],
                  )
                else if (_chosenLockType == 'pin' && _recordedPin != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        'PIN entered (4 digits)',
                        style: TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => setState(() => _recordedPin = null),
                        child: const Text('Clear', style: TextStyle(color: AppTheme.primaryCyan, fontSize: 12)),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Prominent "Next Step" Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ((_chosenLockType == 'pattern' && _recordedPattern != null) ||
                        (_chosenLockType == 'pin' && _recordedPin != null))
                    ? AppTheme.primaryCyan
                    : const Color(0xFF1E293B),
                foregroundColor: const Color(0xFF0B0F19),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: ((_chosenLockType == 'pattern' && _recordedPattern != null) ||
                      (_chosenLockType == 'pin' && _recordedPin != null))
                  ? () async {
                      try {
                        if (_chosenLockType == 'pattern' && _recordedPattern != null) {
                          await _securityService.setPattern(_recordedPattern!);
                          await _securityService.setLockType('pattern');
                        } else if (_chosenLockType == 'pin' && _recordedPin != null) {
                          await _securityService.setPin(_recordedPin!);
                          await _securityService.setLockType('pin');
                        }
                        _goToNextStep();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error saving credentials: $e')),
                          );
                        }
                      }
                    }
                  : null,
              child: const Text('Next Step', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _goToNextStep() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentPage = 2);
  }

  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryCyan.withValues(alpha: 0.1)
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primaryCyan : const Color(0xFF232F48),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryCyan : AppTheme.textSecondary,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryCyan : AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // --- Step 3: Security Questions ---
  Widget _buildQuestionsPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Emergency Recovery Questions',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Configure your 2 emergency questions (first school and best friend). If you enter wrong PINs 11 times or forget your code, these questions will unlock your apps.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF232F48)),
            ),
            child: Column(
              children: [
                Icon(
                  _questionsConfigured ? Icons.check_circle_rounded : Icons.help_outline_rounded,
                  color: _questionsConfigured ? AppTheme.accentGreen : AppTheme.primaryCyan,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  _questionsConfigured
                      ? '2 Security Questions Configured!'
                      : 'Configure 2 Security Questions',
                  style: TextStyle(
                    color: _questionsConfigured ? AppTheme.accentGreen : AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _questionsConfigured
                      ? 'Your recovery questions and answers have been encrypted with SHA-256 and stored securely.'
                      : 'Set answers for your first school and best friend to ensure you can always recover access.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceLight,
                    foregroundColor: AppTheme.primaryCyan,
                    side: const BorderSide(color: AppTheme.primaryCyan),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SecurityQuestionsScreen(
                          mode: SecurityQuestionsMode.setup,
                          onSuccess: () {
                            setState(() {
                              _questionsConfigured = true;
                            });
                          },
                        ),
                      ),
                    );
                  },
                  child: Text(_questionsConfigured ? 'Edit Questions' : 'Setup Questions Now'),
                ),
              ],
            ),
          ),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryCyan,
                foregroundColor: const Color(0xFF0B0F19),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
                setState(() => _currentPage = 3);
              },
              child: const Text('Continue to Permissions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 4: Permissions Guided Flow ---
  Widget _buildPermissionsPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Grant Permissions',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Aegis AppLock requires these Android system permissions to detect app opens and display the security lock screen.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // 1. Usage Access Permission
          _buildPermissionTile(
            title: 'Usage Access Permission',
            description: 'Allows Aegis AppLock to detect when locked apps like WhatsApp open.',
            icon: Icons.data_usage_rounded,
            isGranted: _permissions['usageStats'] ?? false,
            onGrant: () async {
              await _bridge.openSettings('usageStats');
              await Future.delayed(const Duration(seconds: 1));
              _checkPermissions();
            },
          ),

          const SizedBox(height: 12),

          // 2. Display Over Other Apps (Overlay)
          _buildPermissionTile(
            title: 'Display Over Other Apps',
            description: 'Allows instantaneous presentation of the lock screen over target apps.',
            icon: Icons.layers_rounded,
            isGranted: _permissions['overlay'] ?? false,
            onGrant: () async {
              await _bridge.openSettings('overlay');
              await Future.delayed(const Duration(seconds: 1));
              _checkPermissions();
            },
          ),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryCyan,
                foregroundColor: const Color(0xFF0B0F19),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                widget.onComplete();
              },
              child: const Text('Finish Setup & Enter App', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required String title,
    required String description,
    required IconData icon,
    required bool isGranted,
    required VoidCallback onGrant,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGranted ? AppTheme.accentGreen.withValues(alpha: 0.4) : const Color(0xFF232F48),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: isGranted ? AppTheme.accentGreen : AppTheme.primaryCyan, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (isGranted)
            const Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 24)
          else
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryCyan,
                side: const BorderSide(color: AppTheme.primaryCyan),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: onGrant,
              child: const Text('Grant', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}
