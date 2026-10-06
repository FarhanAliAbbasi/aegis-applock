import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../state/app_lock_state.dart';
import '../theme/app_theme.dart';
import '../widgets/pattern_pad_view.dart';
import 'security_questions_screen.dart';
import 'lock_screen.dart';

class SettingsScreen extends StatefulWidget {
  final AppLockState state;

  const SettingsScreen({super.key, required this.state});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBiometricsSupport();
    widget.state.refreshDeviceAdminStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.state.refreshDeviceAdminStatus();
    }
  }

  Future<void> _checkBiometricsSupport() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (mounted) {
        setState(() {
          _canCheckBiometrics = canCheck || isDeviceSupported;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final state = widget.state;

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: const Text('Security & Settings'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Lock Method Section
              _buildSectionHeader('AUTHENTICATION METHOD'),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF232F48)),
                ),
                child: Column(
                  children: [
                    _buildSelectionTile(
                      isSelected: state.lockType == 'pin',
                      title: 'PIN Code (Numeric)',
                      subtitle: '4-Digit secure numeric passcode',
                      icon: Icons.pin_outlined,
                      onTap: () => state.updateLockType('pin'),
                    ),
                    const Divider(color: Color(0xFF1E293B), height: 1),
                    _buildSelectionTile(
                      isSelected: state.lockType == 'pattern',
                      title: 'Pattern Lock',
                      subtitle: '3x3 Dot gesture pattern',
                      icon: Icons.gesture_outlined,
                      onTap: () => state.updateLockType('pattern'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. Biometric Unlock
              _buildSectionHeader('BIOMETRIC AUTHENTICATION'),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF232F48)),
                ),
                child: SwitchListTile(
                  value: state.biometricEnabled,
                  activeThumbColor: AppTheme.primaryCyan,
                  activeTrackColor: AppTheme.primaryCyan.withValues(alpha: 0.35),
                  secondary: const Icon(Icons.fingerprint_rounded, color: AppTheme.primaryCyan),
                  title: const Text(
                    'Fingerprint & Face Unlock',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _canCheckBiometrics
                        ? 'Hardware biometrics supported on this device'
                        : 'Use biometric prompt when supported',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  onChanged: (val) {
                    state.setBiometrics(val);
                  },
                ),
              ),

              const SizedBox(height: 20),

              // 3. Anti-Uninstall Protection
              _buildSectionHeader('ANTI-UNINSTALL PROTECTION'),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF232F48)),
                ),
                child: SwitchListTile(
                  value: state.isDeviceAdminActive && state.isAntiUninstallEnabled,
                  activeThumbColor: AppTheme.accentGreen,
                  activeTrackColor: AppTheme.accentGreen.withValues(alpha: 0.35),
                  secondary: Icon(
                    Icons.admin_panel_settings_rounded,
                    color: (state.isDeviceAdminActive && state.isAntiUninstallEnabled)
                        ? AppTheme.accentGreen
                        : AppTheme.textMuted,
                  ),
                  title: const Text(
                    'Prevent App Uninstallation',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    (state.isDeviceAdminActive && state.isAntiUninstallEnabled)
                        ? 'Active — Device Administrator & PIN protected'
                        : 'Requires Device Admin to block deleting app without PIN',
                    style: TextStyle(
                      color: (state.isDeviceAdminActive && state.isAntiUninstallEnabled)
                          ? AppTheme.accentGreen
                          : AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  onChanged: (val) => _handleAntiUninstallToggle(val),
                ),
              ),

              const SizedBox(height: 20),

              // 4. Emergency Recovery
              _buildSectionHeader('EMERGENCY RECOVERY'),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF232F48)),
                ),
                child: ListTile(
                  leading: const Icon(Icons.help_outline_rounded, color: AppTheme.primaryCyan),
                  title: const Text(
                    '2 Security Questions',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Required after 11 failed attempts or forgotten PIN',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textMuted, size: 14),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SecurityQuestionsScreen(
                          mode: SecurityQuestionsMode.setup,
                          onSuccess: () => state.refreshApps(),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // 4. Relock Policy
              _buildSectionHeader('RELOCK BEHAVIOR'),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF232F48)),
                ),
                child: Column(
                  children: [
                    _buildRelockItem(state, 'screen_off', 'When Screen Turns Off', 'Relocks only when device sleeps'),
                    const Divider(color: Color(0xFF1E293B), height: 1),
                    _buildRelockItem(state, 'immediate', 'Immediately Upon Exit', 'Relocks every single time you leave'),
                    const Divider(color: Color(0xFF1E293B), height: 1),
                    _buildRelockItem(state, 'timeout_1m', 'After 1 Minute', 'Grace period before relocking'),
                    const Divider(color: Color(0xFF1E293B), height: 1),
                    _buildRelockItem(state, 'timeout_5m', 'After 5 Minutes', 'Extended grace period'),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 5. System Permissions Health
              _buildSectionHeader('PERMISSIONS DASHBOARD'),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF232F48)),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.data_usage_rounded,
                        color: state.permissions['usageStats'] == true
                            ? AppTheme.accentGreen
                            : AppTheme.accentRed,
                      ),
                      title: const Text('Usage Access Permission', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                      subtitle: Text(
                        state.permissions['usageStats'] == true ? 'Active' : 'Not granted - Tap to enable',
                        style: TextStyle(
                          color: state.permissions['usageStats'] == true ? AppTheme.accentGreen : AppTheme.accentRed,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textMuted, size: 14),
                      onTap: () => state.bridge.openSettings('usageStats'),
                    ),
                    const Divider(color: Color(0xFF1E293B), height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.layers_rounded,
                        color: state.permissions['overlay'] == true
                            ? AppTheme.accentGreen
                            : AppTheme.accentRed,
                      ),
                      title: const Text('Display Over Other Apps', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                      subtitle: Text(
                        state.permissions['overlay'] == true ? 'Active' : 'Not granted - Tap to enable',
                        style: TextStyle(
                          color: state.permissions['overlay'] == true ? AppTheme.accentGreen : AppTheme.accentRed,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textMuted, size: 14),
                      onTap: () => state.bridge.openSettings('overlay'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 6. Test Lock Screen Interactive Preview
              _buildSectionHeader('TEST & PREVIEW'),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF232F48)),
                ),
                child: ListTile(
                  leading: const Icon(Icons.play_circle_outline_rounded, color: AppTheme.primaryCyan),
                  title: const Text(
                    'Preview Interactive Lock Screen',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Test PIN, Pattern, progressive lockout timers & security questions',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textMuted, size: 14),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LockScreen(
                          appName: 'WhatsApp (Test Preview)',
                          packageName: 'com.whatsapp',
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 36),

              // Footer Logo & Info
              Center(
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/logo.jpg',
                        width: 44,
                        height: 44,
                        errorBuilder: (_, __, ___) => const Icon(Icons.shield, color: AppTheme.primaryCyan),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Aegis AppLock v1.0.0',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Hardware-accelerated security with zero background drain',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectionTile({
    required bool isSelected,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppTheme.primaryCyan : AppTheme.textSecondary),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppTheme.primaryCyan : AppTheme.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryCyan, size: 22)
          : const Icon(Icons.circle_outlined, color: AppTheme.textMuted, size: 22),
      onTap: onTap,
    );
  }

  Widget _buildRelockItem(AppLockState state, String value, String title, String subtitle) {
    final isSelected = state.relockPolicy == value;
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppTheme.primaryCyan : AppTheme.textPrimary,
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      trailing: isSelected
          ? const Icon(Icons.radio_button_checked_rounded, color: AppTheme.primaryCyan, size: 20)
          : const Icon(Icons.radio_button_off_rounded, color: AppTheme.textMuted, size: 20),
      onTap: () => state.setRelockPolicy(value),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.primaryCyan,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Future<void> _handleAntiUninstallToggle(bool enable) async {
    final state = widget.state;
    if (enable) {
      await state.setAntiUninstallEnabled(true);
      if (!state.isDeviceAdminActive) {
        await state.requestDeviceAdmin();
      }
    } else {
      final authenticated = await _promptPasswordAuthentication();
      if (authenticated) {
        await state.deactivateDeviceAdmin();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Anti-Uninstall protection deactivated.'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
      }
    }
  }

  Future<bool> _promptPasswordAuthentication() async {
    final state = widget.state;
    if (state.lockType == 'pattern') {
      return await _showPatternAuthDialog();
    } else {
      return await _showPinAuthDialog();
    }
  }

  Future<bool> _showPinAuthDialog() async {
    final pinController = TextEditingController();
    bool isError = false;
    String errorMessage = '';

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF232F48)),
              ),
              title: const Row(
                children: [
                  Icon(Icons.shield_rounded, color: AppTheme.accentRed),
                  SizedBox(width: 10),
                  Text(
                    'Confirm Identity',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 18),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your security PIN to deactivate Anti-Uninstall protection:',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    autofocus: true,
                    maxLength: 8,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      letterSpacing: 4,
                      fontSize: 18,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '••••',
                      hintStyle: const TextStyle(color: AppTheme.textMuted, letterSpacing: 4),
                      errorText: isError ? errorMessage : null,
                      filled: true,
                      fillColor: AppTheme.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF232F48)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF232F48)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primaryCyan),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final entered = pinController.text.trim();
                    final isValid = await widget.state.securityService.verifyPin(entered);
                    if (isValid) {
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    } else {
                      setDialogState(() {
                        isError = true;
                        errorMessage = 'Incorrect PIN. Action blocked.';
                      });
                    }
                  },
                  child: const Text('Authenticate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
    return result ?? false;
  }

  Future<bool> _showPatternAuthDialog() async {
    bool isError = false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF232F48)),
              ),
              title: const Row(
                children: [
                  Icon(Icons.shield_rounded, color: AppTheme.accentRed),
                  SizedBox(width: 10),
                  Text(
                    'Confirm Identity',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 18),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isError
                        ? 'Incorrect Pattern! Try again.'
                        : 'Draw your unlock pattern to disable protection.',
                    style: TextStyle(
                      color: isError ? AppTheme.accentRed : AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: PatternPadView(
                      isError: isError,
                      onPatternEntered: (pattern) async {
                        final isValid = await widget.state.securityService.verifyPattern(pattern);
                        if (isValid) {
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(true);
                          }
                        } else {
                          setDialogState(() {
                            isError = true;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
                ),
              ],
            );
          },
        );
      },
    );
    return result ?? false;
  }
}
