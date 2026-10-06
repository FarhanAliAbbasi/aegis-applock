import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class PinPadView extends StatefulWidget {
  final int pinLength;
  final ValueChanged<String> onPinCompleted;
  final VoidCallback? onBiometricTap;
  final VoidCallback? onForgotPinTap;
  final int remainingLockoutSeconds;
  final bool isError;
  final bool showBiometricButton;

  const PinPadView({
    super.key,
    this.pinLength = 4,
    required this.onPinCompleted,
    this.onBiometricTap,
    this.onForgotPinTap,
    this.remainingLockoutSeconds = 0,
    this.isError = false,
    this.showBiometricButton = true,
  });

  @override
  State<PinPadView> createState() => _PinPadViewState();
}

class _PinPadViewState extends State<PinPadView> {
  final StringBuffer _enteredPin = StringBuffer();

  @override
  void didUpdateWidget(covariant PinPadView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isError && !oldWidget.isError) {
      _enteredPin.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLockedOut = widget.remainingLockoutSeconds > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Lockout alert banner if locked out
        if (isLockedOut)
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.accentRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.accentRed.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, color: AppTheme.accentRed, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Locked out: Try again in ${widget.remainingLockoutSeconds}s',
                  style: const TextStyle(
                    color: AppTheme.accentRed,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

        // PIN Indicator Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.pinLength, (index) {
            final isFilled = index < _enteredPin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFilled
                    ? (widget.isError ? AppTheme.accentRed : AppTheme.primaryCyan)
                    : const Color(0xFF1E293B),
                border: Border.all(
                  color: isFilled
                      ? (widget.isError ? AppTheme.accentRed : AppTheme.primaryCyan)
                      : const Color(0xFF475569),
                  width: 2,
                ),
                boxShadow: isFilled
                    ? [
                        BoxShadow(
                          color: (widget.isError ? AppTheme.accentRed : AppTheme.primaryCyan)
                              .withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        ),

        const SizedBox(height: 32),

        // Numeric Keypad
        _buildKeypad(isLockedOut),

        const SizedBox(height: 16),

        // Forgot PIN link
        if (widget.onForgotPinTap != null)
          TextButton(
            onPressed: widget.onForgotPinTap,
            child: const Text(
              'Forgot PIN? Answer Security Questions',
              style: TextStyle(
                color: AppTheme.primaryCyan,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildKeypad(bool isLockedOut) {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['BIO', '0', 'DEL'],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: _buildKeyButton(key, isLockedOut),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKeyButton(String key, bool isLockedOut) {
    if (key == 'BIO' && !widget.showBiometricButton) {
      return const SizedBox(width: 72, height: 72);
    }

    return InkWell(
      onTap: isLockedOut
          ? null
          : () {
              HapticFeedback.lightImpact();
              if (key == 'DEL') {
                if (_enteredPin.isNotEmpty) {
                  setState(() {
                    final str = _enteredPin.toString();
                    _enteredPin.clear();
                    _enteredPin.write(str.substring(0, str.length - 1));
                  });
                }
              } else if (key == 'BIO') {
                widget.onBiometricTap?.call();
              } else {
                if (_enteredPin.length < widget.pinLength) {
                  setState(() {
                    _enteredPin.write(key);
                  });
                  if (_enteredPin.length == widget.pinLength) {
                    widget.onPinCompleted(_enteredPin.toString());
                  }
                }
              }
            },
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFF151D2F),
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF232F48),
            width: 1.2,
          ),
        ),
        alignment: Alignment.center,
        child: key == 'BIO'
            ? const Icon(Icons.fingerprint_rounded, color: AppTheme.primaryCyan, size: 28)
            : key == 'DEL'
                ? const Icon(Icons.backspace_outlined, color: AppTheme.textSecondary, size: 22)
                : Text(
                    key,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
      ),
    );
  }
}
