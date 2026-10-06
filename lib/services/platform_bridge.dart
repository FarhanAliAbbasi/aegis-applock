import 'package:flutter/services.dart';
import '../models/app_item.dart';

class PlatformBridge {
  static const MethodChannel _channel = MethodChannel('com.aegis.applock/channel');

  Future<List<AppItem>> getInstalledApps() async {
    try {
      final List<dynamic>? result = await _channel.invokeMethod('getInstalledApps');
      if (result == null) return [];
      return result.map((item) => AppItem.fromMap(item as Map<dynamic, dynamic>)).toList();
    } on PlatformException {
      return [];
    }
  }

  Future<List<String>> getLockedApps() async {
    try {
      final List<dynamic>? result = await _channel.invokeMethod('getLockedApps');
      if (result == null) return [];
      return result.cast<String>();
    } on PlatformException {
      return [];
    }
  }

  Future<bool> setLockedApps(List<String> packages) async {
    try {
      final bool? success = await _channel.invokeMethod('setLockedApps', {
        'packages': packages,
      });
      return success ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> toggleAppLock(String packageName, bool isLocked) async {
    try {
      final bool? success = await _channel.invokeMethod('toggleAppLock', {
        'packageName': packageName,
        'isLocked': isLocked,
      });
      return success ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<Map<String, bool>> checkPermissions() async {
    try {
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod('checkPermissions');
      if (result == null) {
        return {'accessibility': false, 'overlay': false, 'usageStats': false};
      }
      return {
        'accessibility': result['accessibility'] as bool? ?? false,
        'overlay': result['overlay'] as bool? ?? false,
        'usageStats': result['usageStats'] as bool? ?? false,
      };
    } on PlatformException {
      return {'accessibility': false, 'overlay': false, 'usageStats': false};
    }
  }

  Future<void> openSettings(String type) async {
    try {
      await _channel.invokeMethod('openSettings', {'type': type});
    } on PlatformException catch (_) {}
  }

  Future<void> syncSecurityConfig({
    required String? pinHash,
    required String? pinSalt,
    required String? patternHash,
    required String? patternSalt,
    required String lockType,
    required bool biometricEnabled,
    required String relockPolicy,
    required String? securityQuestionsJson,
  }) async {
    try {
      await _channel.invokeMethod('syncSecurityConfig', {
        'pinHash': pinHash,
        'pinSalt': pinSalt,
        'patternHash': patternHash,
        'patternSalt': patternSalt,
        'lockType': lockType,
        'biometricEnabled': biometricEnabled,
        'relockPolicy': relockPolicy,
        'securityQuestionsJson': securityQuestionsJson,
      });
    } on PlatformException catch (_) {}
  }

  Future<Map<String, dynamic>> getLockoutStatus() async {
    try {
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod('getLockoutStatus');
      if (result == null) {
        return {
          'failedAttempts': 0,
          'remainingSeconds': 0,
          'isSecurityQuestionsRequired': false,
        };
      }
      return {
        'failedAttempts': result['failedAttempts'] as int? ?? 0,
        'remainingSeconds': result['remainingSeconds'] as int? ?? 0,
        'isSecurityQuestionsRequired': result['isSecurityQuestionsRequired'] as bool? ?? false,
      };
    } on PlatformException {
      return {
        'failedAttempts': 0,
        'remainingSeconds': 0,
        'isSecurityQuestionsRequired': false,
      };
    }
  }

  Future<Map<String, dynamic>> recordFailedAttempt() async {
    try {
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod('recordFailedAttempt');
      if (result == null) return {};
      return Map<String, dynamic>.from(result);
    } on PlatformException {
      return {};
    }
  }

  Future<void> resetFailedAttempts() async {
    try {
      await _channel.invokeMethod('resetFailedAttempts');
    } on PlatformException catch (_) {}
  }

  Future<bool> isDeviceAdminActive() async {
    try {
      final bool? active = await _channel.invokeMethod('isDeviceAdminActive');
      return active ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> requestDeviceAdmin() async {
    try {
      await _channel.invokeMethod('requestDeviceAdmin');
    } on PlatformException catch (_) {}
  }

  Future<void> deactivateDeviceAdmin() async {
    try {
      await _channel.invokeMethod('deactivateDeviceAdmin');
    } on PlatformException catch (_) {}
  }

  Future<bool> isAntiUninstallEnabled() async {
    try {
      final bool? enabled = await _channel.invokeMethod('isAntiUninstallEnabled');
      return enabled ?? true;
    } on PlatformException {
      return true;
    }
  }

  Future<void> setAntiUninstallEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setAntiUninstallEnabled', {'enabled': enabled});
    } on PlatformException catch (_) {}
  }
}
