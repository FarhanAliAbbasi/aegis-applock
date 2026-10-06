import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/security_question.dart';
import 'platform_bridge.dart';

class LockoutStatus {
  final int failedAttempts;
  final int remainingSeconds;
  final bool isSecurityQuestionsRequired;

  const LockoutStatus({
    required this.failedAttempts,
    required this.remainingSeconds,
    required this.isSecurityQuestionsRequired,
  });
}

class SecurityService {
  static const String keyPinHash = 'aegis_pin_hash';
  static const String keyPinSalt = 'aegis_pin_salt';
  static const String keyPatternHash = 'aegis_pattern_hash';
  static const String keyPatternSalt = 'aegis_pattern_salt';
  static const String keyLockType = 'aegis_lock_type'; // 'pin' or 'pattern'
  static const String keyBiometricEnabled = 'aegis_biometric_enabled';
  static const String keyRelockPolicy = 'aegis_relock_policy';
  static const String keySecurityQuestions = 'aegis_security_questions';
  static const String keyFailedAttempts = 'aegis_failed_attempts';
  static const String keyLockoutUntil = 'aegis_lockout_until';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
    ),
  );
  static SharedPreferences? _cachedPrefs;

  static Future<void> initialize() async {
    _cachedPrefs = await SharedPreferences.getInstance();
  }

  Future<void> init() async {
    _cachedPrefs = await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> _getPrefs() async {
    _cachedPrefs ??= await SharedPreferences.getInstance();
    return _cachedPrefs!;
  }

  Future<void> _safeSecureWrite(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (_) {}
  }

  Future<String?> _safeSecureRead(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  // --- Cryptographic Hashing ---
  static String hashCredential(String credential, String salt) {
    final input = '$salt:$credential';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static String generateSalt([int length = 16]) {
    final random = Random.secure();
    final values = List<int>.generate(length, (i) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // --- Native Android Sync ---
  Future<void> syncToNative() async {
    try {
      final pinHash = await getPinHash();
      final pinSalt = await getPinSalt();
      final patternHash = await getPatternHash();
      final patternSalt = await getPatternSalt();
      final questions = await getSecurityQuestions();
      final questionsJson = jsonEncode(questions.map((q) => q.toMap()).toList());

      await PlatformBridge().syncSecurityConfig(
        pinHash: pinHash,
        pinSalt: pinSalt,
        patternHash: patternHash,
        patternSalt: patternSalt,
        lockType: getLockType(),
        biometricEnabled: isBiometricEnabled(),
        relockPolicy: getRelockPolicy(),
        securityQuestionsJson: questionsJson,
      );
    } catch (_) {}
  }

  // --- PIN Management ---
  Future<void> setPin(String pin) async {
    final salt = generateSalt();
    final hash = hashCredential(pin, salt);
    await _safeSecureWrite(keyPinHash, hash);
    await _safeSecureWrite(keyPinSalt, salt);
    final prefs = await _getPrefs();
    await prefs.setString(keyPinHash, hash);
    await prefs.setString(keyPinSalt, salt);
    await syncToNative();
  }

  Future<bool> verifyPin(String pin) async {
    final storedHash = await getPinHash();
    final storedSalt = await getPinSalt();

    if (storedHash == null || storedSalt == null) {
      // Default initial PIN is 1234
      return pin == '1234';
    }

    final testHash = hashCredential(pin, storedSalt);
    return testHash == storedHash;
  }

  Future<String?> getPinHash() async {
    final secureVal = await _safeSecureRead(keyPinHash);
    if (secureVal != null && secureVal.isNotEmpty) return secureVal;
    final prefs = await _getPrefs();
    return prefs.getString(keyPinHash);
  }

  Future<String?> getPinSalt() async {
    final secureVal = await _safeSecureRead(keyPinSalt);
    if (secureVal != null && secureVal.isNotEmpty) return secureVal;
    final prefs = await _getPrefs();
    return prefs.getString(keyPinSalt);
  }

  // --- Pattern Management ---
  Future<void> setPattern(String pattern) async {
    final salt = generateSalt();
    final hash = hashCredential(pattern, salt);
    await _safeSecureWrite(keyPatternHash, hash);
    await _safeSecureWrite(keyPatternSalt, salt);
    final prefs = await _getPrefs();
    await prefs.setString(keyPatternHash, hash);
    await prefs.setString(keyPatternSalt, salt);
    await syncToNative();
  }

  Future<bool> verifyPattern(String pattern) async {
    final storedHash = await getPatternHash();
    final storedSalt = await getPatternSalt();

    if (storedHash == null || storedSalt == null) {
      return pattern == '0-1-2-5';
    }

    final testHash = hashCredential(pattern, storedSalt);
    return testHash == storedHash;
  }

  Future<String?> getPatternHash() async {
    final secureVal = await _safeSecureRead(keyPatternHash);
    if (secureVal != null && secureVal.isNotEmpty) return secureVal;
    final prefs = await _getPrefs();
    return prefs.getString(keyPatternHash);
  }

  Future<String?> getPatternSalt() async {
    final secureVal = await _safeSecureRead(keyPatternSalt);
    if (secureVal != null && secureVal.isNotEmpty) return secureVal;
    final prefs = await _getPrefs();
    return prefs.getString(keyPatternSalt);
  }

  // --- Lock Type & Preferences ---
  Future<void> setLockType(String type) async {
    final prefs = await _getPrefs();
    await prefs.setString(keyLockType, type);
    await syncToNative();
  }

  String getLockType() {
    return _cachedPrefs?.getString(keyLockType) ?? 'pin';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(keyBiometricEnabled, enabled);
    await syncToNative();
  }

  bool isBiometricEnabled() {
    return _cachedPrefs?.getBool(keyBiometricEnabled) ?? false;
  }

  Future<void> setRelockPolicy(String policy) async {
    final prefs = await _getPrefs();
    await prefs.setString(keyRelockPolicy, policy);
    await syncToNative();
  }

  String getRelockPolicy() {
    return _cachedPrefs?.getString(keyRelockPolicy) ?? 'screen_off';
  }

  // --- Security Questions (2 to 3 questions) ---
  Future<void> saveSecurityQuestions(List<SecurityQuestion> questions) async {
    final jsonList = questions.map((q) => q.toMap()).toList();
    final jsonStr = jsonEncode(jsonList);
    await _safeSecureWrite(keySecurityQuestions, jsonStr);
    final prefs = await _getPrefs();
    await prefs.setString(keySecurityQuestions, jsonStr);
    await syncToNative();
  }

  Future<List<SecurityQuestion>> getSecurityQuestions() async {
    final secureVal = await _safeSecureRead(keySecurityQuestions);
    final prefs = await _getPrefs();
    final jsonStr = secureVal ?? prefs.getString(keySecurityQuestions);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final list = jsonDecode(jsonStr) as List;
      return list.map((item) => SecurityQuestion.fromMap(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  bool verifySecurityQuestionAnswer({
    required SecurityQuestion question,
    required String enteredAnswer,
  }) {
    final normalized = enteredAnswer.trim().toLowerCase();
    final calculatedHash = hashCredential(normalized, question.salt);
    return calculatedHash == question.answerHash;
  }

  // --- Multi-Tier Progressive Lockout State Machine ---
  // Tier 1: 5 fails -> 30s
  // Tier 2: 5 + 3 = 8 fails -> 120s
  // Tier 3: 8 + 3 = 11 fails -> 300s
  // Tier 4: >= 11 fails -> Security questions challenge required
  int getFailedAttempts() {
    return _cachedPrefs?.getInt(keyFailedAttempts) ?? 0;
  }

  LockoutStatus recordFailedAttempt() {
    final current = getFailedAttempts() + 1;
    _cachedPrefs?.setInt(keyFailedAttempts, current);

    final now = DateTime.now().millisecondsSinceEpoch;
    int lockoutSeconds = 0;
    bool isQuestionsRequired = false;

    if (current >= 11) {
      lockoutSeconds = 300;
      isQuestionsRequired = true;
    } else if (current >= 8) {
      lockoutSeconds = 120;
    } else if (current >= 5) {
      lockoutSeconds = 30;
    }

    if (lockoutSeconds > 0) {
      final lockoutUntil = now + (lockoutSeconds * 1000);
      _cachedPrefs?.setInt(keyLockoutUntil, lockoutUntil);
    }

    return LockoutStatus(
      failedAttempts: current,
      remainingSeconds: lockoutSeconds,
      isSecurityQuestionsRequired: isQuestionsRequired,
    );
  }

  int getRemainingLockoutSeconds() {
    final lockoutUntil = _cachedPrefs?.getInt(keyLockoutUntil) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (lockoutUntil > now) {
      return ((lockoutUntil - now) ~/ 1000);
    }
    return 0;
  }

  bool isSecurityQuestionsRequired() {
    return getFailedAttempts() >= 11;
  }

  void resetFailedAttempts() {
    _cachedPrefs?.setInt(keyFailedAttempts, 0);
    _cachedPrefs?.setInt(keyLockoutUntil, 0);
  }
}
