package com.aegis.applock.applock

import android.content.Context
import android.content.SharedPreferences
import android.os.SystemClock

object LockSessionManager {
    private const val PREFS_NAME = "aegis_lock_prefs"
    private const val KEY_LOCKED_PACKAGES = "locked_packages"
    private const val KEY_FAILED_ATTEMPTS = "failed_attempts"
    private const val KEY_LOCKOUT_UNTIL = "lockout_until"
    private const val KEY_PIN_HASH = "pin_hash"
    private const val KEY_PIN_SALT = "pin_salt"
    private const val KEY_PATTERN_HASH = "pattern_hash"
    private const val KEY_PATTERN_SALT = "pattern_salt"
    private const val KEY_LOCK_TYPE = "lock_type" // "pin" or "pattern"
    private const val KEY_BIOMETRIC_ENABLED = "biometric_enabled"
    private const val KEY_RELOCK_POLICY = "relock_policy" // "immediate", "screen_off", "timeout_1m", "timeout_5m"
    private const val KEY_SECURITY_QUESTIONS_DATA = "security_questions_data"
    private const val KEY_ANTI_UNINSTALL_ENABLED = "anti_uninstall_enabled"

    // Set of temporarily unlocked packages during the current session
    private val unlockedSessions = mutableMapOf<String, Long>()
    private var prefs: SharedPreferences? = null
    private var flutterPrefs: SharedPreferences? = null

    fun init(context: Context) {
        if (prefs == null) {
            prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        }
        if (flutterPrefs == null) {
            flutterPrefs = context.applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        }
    }

    private fun getPrefs(): SharedPreferences {
        return prefs ?: throw IllegalStateException("LockSessionManager not initialized")
    }

    // --- Locked Packages ---
    fun getLockedPackages(): Set<String> {
        return getPrefs().getStringSet(KEY_LOCKED_PACKAGES, emptySet()) ?: emptySet()
    }

    fun setLockedPackages(packages: Set<String>) {
        getPrefs().edit().putStringSet(KEY_LOCKED_PACKAGES, packages).apply()
    }

    fun isAppLocked(packageName: String): Boolean {
        return getLockedPackages().contains(packageName)
    }

    // --- Session Unlock State ---
    fun isUnlockedSession(packageName: String): Boolean {
        val unlockTime = unlockedSessions[packageName] ?: return false
        val relockPolicy = getRelockPolicy()
        val now = SystemClock.elapsedRealtime()

        return when (relockPolicy) {
            "immediate" -> false // Requires unlock every time
            "timeout_1m" -> (now - unlockTime) < 60_000
            "timeout_5m" -> (now - unlockTime) < 300_000
            else -> true // Session remains unlocked until screen off or explicit relock
        }
    }

    fun markAppUnlocked(packageName: String) {
        unlockedSessions[packageName] = SystemClock.elapsedRealtime()
        // Reset failed attempts upon successful authentication
        resetFailedAttempts()
    }

    fun clearAllSessions() {
        unlockedSessions.clear()
    }

    fun clearSession(packageName: String) {
        unlockedSessions.remove(packageName)
    }

    // --- Progressive Lockout State Machine ---
    // User Rules:
    // - After 5 wrong attempts -> 30s lockout
    // - After +3 wrong attempts (8 total) -> 120s lockout
    // - After +3 wrong attempts (11 total) -> 300s lockout
    // - After 11 attempts -> Security Questions Required
    fun getFailedAttempts(): Int {
        return getPrefs().getInt(KEY_FAILED_ATTEMPTS, 0)
    }

    fun recordFailedAttempt(): LockoutResult {
        val current = getFailedAttempts() + 1
        getPrefs().edit().putInt(KEY_FAILED_ATTEMPTS, current).apply()

        val now = System.currentTimeMillis()
        var lockoutSeconds = 0
        var securityQuestionsRequired = false

        when {
            current >= 12 -> {
                // Beyond 11 attempts: Force Security Questions Challenge
                securityQuestionsRequired = true
                lockoutSeconds = 300
            }
            current >= 11 -> {
                // Tier 3: 11 attempts -> 300s (5 minutes)
                lockoutSeconds = 300
                securityQuestionsRequired = true
            }
            current >= 8 -> {
                // Tier 2: 8 attempts -> 120s (2 minutes)
                lockoutSeconds = 120
            }
            current >= 5 -> {
                // Tier 1: 5 attempts -> 30s
                lockoutSeconds = 30
            }
        }

        if (lockoutSeconds > 0) {
            val lockoutUntil = now + (lockoutSeconds * 1000L)
            getPrefs().edit().putLong(KEY_LOCKOUT_UNTIL, lockoutUntil).apply()
        }

        return LockoutResult(
            failedAttempts = current,
            lockoutSeconds = lockoutSeconds,
            securityQuestionsRequired = securityQuestionsRequired
        )
    }

    fun getRemainingLockoutSeconds(): Int {
        val lockoutUntil = getPrefs().getLong(KEY_LOCKOUT_UNTIL, 0L)
        val now = System.currentTimeMillis()
        if (lockoutUntil > now) {
            return ((lockoutUntil - now) / 1000L).toInt()
        }
        return 0
    }

    fun isSecurityQuestionsRequired(): Boolean {
        return getFailedAttempts() >= 11
    }

    fun resetFailedAttempts() {
        getPrefs().edit()
            .putInt(KEY_FAILED_ATTEMPTS, 0)
            .putLong(KEY_LOCKOUT_UNTIL, 0L)
            .apply()
    }

    // --- Configuration Sync ---
    fun saveSecurityConfig(
        pinHash: String?,
        pinSalt: String?,
        patternHash: String?,
        patternSalt: String?,
        lockType: String,
        biometricEnabled: Boolean,
        relockPolicy: String,
        securityQuestionsJson: String?
    ) {
        val editor = getPrefs().edit()
        if (pinHash != null) editor.putString(KEY_PIN_HASH, pinHash)
        if (pinSalt != null) editor.putString(KEY_PIN_SALT, pinSalt)
        if (patternHash != null) editor.putString(KEY_PATTERN_HASH, patternHash)
        if (patternSalt != null) editor.putString(KEY_PATTERN_SALT, patternSalt)
        editor.putString(KEY_LOCK_TYPE, lockType)
        editor.putBoolean(KEY_BIOMETRIC_ENABLED, biometricEnabled)
        editor.putString(KEY_RELOCK_POLICY, relockPolicy)
        if (securityQuestionsJson != null) editor.putString(KEY_SECURITY_QUESTIONS_DATA, securityQuestionsJson)
        editor.apply()
    }

    fun getPinHash(): String? {
        val hash = getPrefs().getString(KEY_PIN_HASH, null)
        if (!hash.isNullOrEmpty()) return hash
        return flutterPrefs?.getString("flutter.aegis_pin_hash", null)
    }

    fun getPinSalt(): String? {
        val salt = getPrefs().getString(KEY_PIN_SALT, null)
        if (!salt.isNullOrEmpty()) return salt
        return flutterPrefs?.getString("flutter.aegis_pin_salt", null)
    }

    fun getPatternHash(): String? {
        val hash = getPrefs().getString(KEY_PATTERN_HASH, null)
        if (!hash.isNullOrEmpty()) return hash
        return flutterPrefs?.getString("flutter.aegis_pattern_hash", null)
    }

    fun getPatternSalt(): String? {
        val salt = getPrefs().getString(KEY_PATTERN_SALT, null)
        if (!salt.isNullOrEmpty()) return salt
        return flutterPrefs?.getString("flutter.aegis_pattern_salt", null)
    }

    fun getLockType(): String {
        val type = getPrefs().getString(KEY_LOCK_TYPE, null)
        if (!type.isNullOrEmpty()) return type
        return flutterPrefs?.getString("flutter.aegis_lock_type", "pin") ?: "pin"
    }

    fun isBiometricEnabled(): Boolean {
        if (getPrefs().contains(KEY_BIOMETRIC_ENABLED)) {
            return getPrefs().getBoolean(KEY_BIOMETRIC_ENABLED, false)
        }
        return flutterPrefs?.getBoolean("flutter.aegis_biometric_enabled", false) ?: false
    }

    fun getRelockPolicy(): String {
        val policy = getPrefs().getString(KEY_RELOCK_POLICY, null)
        if (!policy.isNullOrEmpty()) return policy
        return flutterPrefs?.getString("flutter.aegis_relock_policy", "screen_off") ?: "screen_off"
    }

    fun getSecurityQuestionsData(): String? {
        val data = getPrefs().getString(KEY_SECURITY_QUESTIONS_DATA, null)
        if (!data.isNullOrEmpty()) return data
        return flutterPrefs?.getString("flutter.aegis_security_questions", null)
    }

    fun isAntiUninstallEnabled(): Boolean {
        if (getPrefs().contains(KEY_ANTI_UNINSTALL_ENABLED)) {
            return getPrefs().getBoolean(KEY_ANTI_UNINSTALL_ENABLED, true)
        }
        return flutterPrefs?.getBoolean("flutter.aegis_anti_uninstall", true) ?: true
    }

    fun setAntiUninstallEnabled(enabled: Boolean) {
        getPrefs().edit().putBoolean(KEY_ANTI_UNINSTALL_ENABLED, enabled).apply()
    }

    data class LockoutResult(
        val failedAttempts: Int,
        val lockoutSeconds: Int,
        val securityQuestionsRequired: Boolean
    )
}
