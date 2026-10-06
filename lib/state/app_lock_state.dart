import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/app_item.dart';
import '../models/security_question.dart';
import '../services/platform_bridge.dart';
import '../services/security_service.dart';

enum AppFilter { all, locked, social, sensitive }

class AppLockState extends ChangeNotifier {
  final PlatformBridge _bridge = PlatformBridge();
  final SecurityService _securityService = SecurityService();

  List<AppItem> _apps = [];
  String _searchQuery = '';
  AppFilter _currentFilter = AppFilter.all;
  bool _isLoading = false;

  String _lockType = 'pin';
  bool _biometricEnabled = false;
  String _relockPolicy = 'screen_off';
  List<SecurityQuestion> _securityQuestions = [];
  bool _isAntiUninstallEnabled = true;
  bool _isDeviceAdminActive = false;
  Map<String, bool> _permissions = {
    'accessibility': false,
    'overlay': false,
    'usageStats': false,
  };

  // Getters
  List<AppItem> get allApps => _apps;
  String get searchQuery => _searchQuery;
  AppFilter get currentFilter => _currentFilter;
  bool get isLoading => _isLoading;
  String get lockType => _lockType;
  bool get biometricEnabled => _biometricEnabled;
  String get relockPolicy => _relockPolicy;
  List<SecurityQuestion> get securityQuestions => _securityQuestions;
  bool get isAntiUninstallEnabled => _isAntiUninstallEnabled;
  bool get isDeviceAdminActive => _isDeviceAdminActive;
  Map<String, bool> get permissions => _permissions;
  SecurityService get securityService => _securityService;
  PlatformBridge get bridge => _bridge;

  int get lockedCount => _apps.where((a) => a.isLocked).length;

  List<AppItem> get filteredApps {
    var list = _apps;

    // Filter by tab
    switch (_currentFilter) {
      case AppFilter.all:
        break;
      case AppFilter.locked:
        list = list.where((a) => a.isLocked).toList();
        break;
      case AppFilter.social:
        list = list.where((a) => a.isSocialOrMessenger).toList();
        break;
      case AppFilter.sensitive:
        list = list.where((a) => a.isSensitiveOrFinancial).toList();
        break;
    }

    // Filter by search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((a) =>
          a.name.toLowerCase().contains(q) ||
          a.packageName.toLowerCase().contains(q)).toList();
    }

    return list;
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    await _securityService.init();
    _lockType = _securityService.getLockType();
    _biometricEnabled = _securityService.isBiometricEnabled();
    _relockPolicy = _securityService.getRelockPolicy();
    _securityQuestions = await _securityService.getSecurityQuestions();

    await refreshPermissions();
    await refreshDeviceAdminStatus();
    await refreshApps();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshApps() async {
    final installed = await _bridge.getInstalledApps();
    final lockedPackages = await _bridge.getLockedApps();

    final lockedSet = lockedPackages.toSet();
    _apps = installed.map((app) {
      final isLocked = lockedSet.contains(app.packageName);
      return app.copyWith(isLocked: isLocked);
    }).toList();

    // Sort: locked apps first, then name
    _apps.sort((a, b) {
      if (a.isLocked != b.isLocked) {
        return a.isLocked ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    notifyListeners();
  }

  Future<void> refreshPermissions() async {
    _permissions = await _bridge.checkPermissions();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilter(AppFilter filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  Future<void> toggleAppLock(String packageName) async {
    final index = _apps.indexWhere((a) => a.packageName == packageName);
    if (index == -1) return;

    final newStatus = !_apps[index].isLocked;
    _apps[index] = _apps[index].copyWith(isLocked: newStatus);
    notifyListeners();

    await _bridge.toggleAppLock(packageName, newStatus);
  }

  Future<void> lockAllSensitive() async {
    final toLock = _apps
        .where((a) => a.isSocialOrMessenger || a.isSensitiveOrFinancial)
        .map((a) => a.packageName)
        .toList();

    for (var i = 0; i < _apps.length; i++) {
      if (toLock.contains(_apps[i].packageName)) {
        _apps[i] = _apps[i].copyWith(isLocked: true);
      }
    }
    notifyListeners();

    final allLocked = _apps.where((a) => a.isLocked).map((a) => a.packageName).toList();
    await _bridge.setLockedApps(allLocked);
  }

  Future<void> unlockAll() async {
    for (var i = 0; i < _apps.length; i++) {
      _apps[i] = _apps[i].copyWith(isLocked: false);
    }
    notifyListeners();
    await _bridge.setLockedApps([]);
  }

  Future<void> updateLockType(String type) async {
    _lockType = type;
    await _securityService.setLockType(type);
    await _syncWithNative();
    notifyListeners();
  }

  Future<void> setBiometrics(bool enabled) async {
    _biometricEnabled = enabled;
    await _securityService.setBiometricEnabled(enabled);
    await _syncWithNative();
    notifyListeners();
  }

  Future<void> setRelockPolicy(String policy) async {
    _relockPolicy = policy;
    await _securityService.setRelockPolicy(policy);
    await _syncWithNative();
    notifyListeners();
  }

  Future<void> saveSecurityQuestions(List<SecurityQuestion> questions) async {
    _securityQuestions = questions;
    await _securityService.saveSecurityQuestions(questions);
    await _syncWithNative();
    notifyListeners();
  }

  Future<void> _syncWithNative() async {
    final pinHash = await _securityService.getPinHash();
    final pinSalt = await _securityService.getPinSalt();
    final patternHash = await _securityService.getPatternHash();
    final patternSalt = await _securityService.getPatternSalt();
    final questionsJson = jsonEncode(_securityQuestions.map((q) => q.toMap()).toList());

    await _bridge.syncSecurityConfig(
      pinHash: pinHash,
      pinSalt: pinSalt,
      patternHash: patternHash,
      patternSalt: patternSalt,
      lockType: _lockType,
      biometricEnabled: _biometricEnabled,
      relockPolicy: _relockPolicy,
      securityQuestionsJson: questionsJson,
    );
  }

  Future<void> refreshDeviceAdminStatus() async {
    _isDeviceAdminActive = await _bridge.isDeviceAdminActive();
    _isAntiUninstallEnabled = await _bridge.isAntiUninstallEnabled();
    notifyListeners();
  }

  Future<void> requestDeviceAdmin() async {
    await _bridge.requestDeviceAdmin();
  }

  Future<void> deactivateDeviceAdmin() async {
    await _bridge.deactivateDeviceAdmin();
    _isDeviceAdminActive = false;
    _isAntiUninstallEnabled = false;
    await _bridge.setAntiUninstallEnabled(false);
    notifyListeners();
  }

  Future<void> setAntiUninstallEnabled(bool enabled) async {
    _isAntiUninstallEnabled = enabled;
    await _bridge.setAntiUninstallEnabled(enabled);
    notifyListeners();
  }
}
