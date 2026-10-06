import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_item.dart';
import '../theme/app_theme.dart';

class AppListTile extends StatelessWidget {
  final AppItem app;
  final ValueChanged<bool> onToggle;

  const AppListTile({
    super.key,
    required this.app,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: app.isLocked
            ? AppTheme.primaryCyan.withValues(alpha: 0.06)
            : AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: app.isLocked
              ? AppTheme.primaryCyan.withValues(alpha: 0.4)
              : const Color(0xFF1E293B),
          width: 1.2,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: app.isLocked
                      ? AppTheme.primaryCyan.withValues(alpha: 0.5)
                      : const Color(0xFF334155),
                  width: 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: app.iconBytes != null
                  ? Image.memory(
                      app.iconBytes!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildFallbackIcon(),
                    )
                  : _buildFallbackIcon(),
            ),
            if (app.isLocked)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryCyan,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 11,
                  color: Color(0xFF0B0F19),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                app.name,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: app.isLocked ? FontWeight.bold : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (app.isSocialOrMessenger)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'SOCIAL',
                  style: TextStyle(
                    color: AppTheme.primaryBlue,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          app.packageName,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              app.isLocked ? 'ON' : 'OFF',
              style: TextStyle(
                color: app.isLocked ? AppTheme.primaryCyan : AppTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: app.isLocked,
              onChanged: (val) {
                HapticFeedback.lightImpact();
                onToggle(val);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Icon(
      app.isSocialOrMessenger
          ? Icons.chat_bubble_outline_rounded
          : app.isSensitiveOrFinancial
              ? Icons.account_balance_rounded
              : Icons.android_rounded,
      color: app.isLocked ? AppTheme.primaryCyan : AppTheme.textSecondary,
      size: 26,
    );
  }
}
