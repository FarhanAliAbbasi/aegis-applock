package com.aegis.applock.applock

import android.app.AppOpsManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.aegis.applock/channel"
    private var cachedAppList: List<Map<String, Any>>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        LockSessionManager.init(this)
        if (LockSessionManager.getLockedPackages().isNotEmpty()) {
            AppLockService.start(this)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledApps" -> {
                    Thread {
                        val apps = getInstalledAppsList()
                        runOnUiThread {
                            result.success(apps)
                        }
                    }.start()
                }

                "getLockedApps" -> {
                    result.success(LockSessionManager.getLockedPackages().toList())
                }

                "setLockedApps" -> {
                    val list = call.argument<List<String>>("packages") ?: emptyList()
                    LockSessionManager.setLockedPackages(list.toSet())
                    if (list.isNotEmpty()) {
                        AppLockService.start(this)
                    }
                    result.success(true)
                }

                "toggleAppLock" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    val isLocked = call.argument<Boolean>("isLocked") ?: false
                    val current = LockSessionManager.getLockedPackages().toMutableSet()
                    if (isLocked) {
                        current.add(packageName)
                    } else {
                        current.remove(packageName)
                    }
                    LockSessionManager.setLockedPackages(current)
                    if (current.isNotEmpty()) {
                        AppLockService.start(this)
                    }
                    result.success(true)
                }

                "checkPermissions" -> {
                    val permissions = mapOf(
                        "accessibility" to isAccessibilityServiceEnabled(),
                        "overlay" to isOverlayPermissionGranted(),
                        "usageStats" to isUsageStatsPermissionGranted()
                    )
                    result.success(permissions)
                }

                "openSettings" -> {
                    val type = call.argument<String>("type") ?: ""
                    openSettingsPage(type)
                    result.success(true)
                }

                "syncSecurityConfig" -> {
                    val pinHash = call.argument<String>("pinHash")
                    val pinSalt = call.argument<String>("pinSalt")
                    val patternHash = call.argument<String>("patternHash")
                    val patternSalt = call.argument<String>("patternSalt")
                    val lockType = call.argument<String>("lockType") ?: "pin"
                    val biometricEnabled = call.argument<Boolean>("biometricEnabled") ?: false
                    val relockPolicy = call.argument<String>("relockPolicy") ?: "screen_off"
                    val securityQuestionsJson = call.argument<String>("securityQuestionsJson")

                    LockSessionManager.saveSecurityConfig(
                        pinHash = pinHash,
                        pinSalt = pinSalt,
                        patternHash = patternHash,
                        patternSalt = patternSalt,
                        lockType = lockType,
                        biometricEnabled = biometricEnabled,
                        relockPolicy = relockPolicy,
                        securityQuestionsJson = securityQuestionsJson
                    )
                    result.success(true)
                }

                "getLockoutStatus" -> {
                    val status = mapOf(
                        "failedAttempts" to LockSessionManager.getFailedAttempts(),
                        "remainingSeconds" to LockSessionManager.getRemainingLockoutSeconds(),
                        "isSecurityQuestionsRequired" to LockSessionManager.isSecurityQuestionsRequired()
                    )
                    result.success(status)
                }

                "recordFailedAttempt" -> {
                    val res = LockSessionManager.recordFailedAttempt()
                    val data = mapOf(
                        "failedAttempts" to res.failedAttempts,
                        "lockoutSeconds" to res.lockoutSeconds,
                        "securityQuestionsRequired" to res.securityQuestionsRequired
                    )
                    result.success(data)
                }

                "resetFailedAttempts" -> {
                    LockSessionManager.resetFailedAttempts()
                    result.success(true)
                }

                "isDeviceAdminActive" -> {
                    val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
                    val comp = ComponentName(this, AegisDeviceAdminReceiver::class.java)
                    result.success(dpm?.isAdminActive(comp) ?: false)
                }

                "requestDeviceAdmin" -> {
                    val comp = ComponentName(this, AegisDeviceAdminReceiver::class.java)
                    val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                        putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, comp)
                        putExtra(
                            DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                            "Enable Device Administrator to prevent unauthorized uninstallation of Aegis AppLock without entering your PIN."
                        )
                    }
                    startActivity(intent)
                    result.success(true)
                }

                "deactivateDeviceAdmin" -> {
                    val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
                    val comp = ComponentName(this, AegisDeviceAdminReceiver::class.java)
                    dpm?.removeActiveAdmin(comp)
                    result.success(true)
                }

                "isAntiUninstallEnabled" -> {
                    result.success(LockSessionManager.isAntiUninstallEnabled())
                }

                "setAntiUninstallEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    LockSessionManager.setAntiUninstallEnabled(enabled)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun getInstalledAppsList(): List<Map<String, Any>> {
        val lockedSet = LockSessionManager.getLockedPackages()

        // Instant return if cached
        cachedAppList?.let { cached ->
            return cached.map { map ->
                val pkg = map["packageName"] as? String ?: ""
                val copy = HashMap(map)
                copy["isLocked"] = lockedSet.contains(pkg)
                copy
            }
        }

        val appList = mutableListOf<Map<String, Any>>()
        val pm = packageManager
        val intent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }

        val resolveInfos = pm.queryIntentActivities(intent, 0)
        val selfPackage = packageName

        for (resolveInfo in resolveInfos) {
            val pkg = resolveInfo.activityInfo.packageName
            if (pkg == selfPackage) continue

            val appName = resolveInfo.loadLabel(pm).toString()
            val isSystem = (resolveInfo.activityInfo.applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0

            var iconBytes: ByteArray? = null
            try {
                val iconDrawable = resolveInfo.loadIcon(pm)
                iconBytes = drawableToByteArray(iconDrawable)
            } catch (_: Exception) {}

            val map = mutableMapOf<String, Any>(
                "name" to appName,
                "packageName" to pkg,
                "isSystemApp" to isSystem,
                "isLocked" to lockedSet.contains(pkg)
            )
            if (iconBytes != null) {
                map["iconBytes"] = iconBytes
            }

            appList.add(map)
        }

        // Sort: locked apps first, then alphabetically by name
        appList.sortWith(Comparator { a, b ->
            val lockedA = a["isLocked"] as? Boolean ?: false
            val lockedB = b["isLocked"] as? Boolean ?: false
            if (lockedA != lockedB) {
                if (lockedA) -1 else 1
            } else {
                val nameA = a["name"] as? String ?: ""
                val nameB = b["name"] as? String ?: ""
                nameA.compareTo(nameB, ignoreCase = true)
            }
        })

        cachedAppList = appList
        return appList
    }

    private fun drawableToByteArray(drawable: Drawable): ByteArray? {
        val size = 48
        val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null && !drawable.bitmap.isRecycled) {
            Bitmap.createScaledBitmap(drawable.bitmap, size, size, true)
        } else {
            val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            bmp
        }

        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 80, stream)
        return stream.toByteArray()
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedService = "$packageName/${AppLockAccessibilityService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServices)
        while (colonSplitter.hasNext()) {
            val service = colonSplitter.next()
            if (service.equals(expectedService, ignoreCase = true) || service.contains(packageName)) {
                return true
            }
        }
        return false
    }

    private fun isOverlayPermissionGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun isUsageStatsPermissionGranted(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun openSettingsPage(type: String) {
        try {
            when (type) {
                "accessibility" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                }
                "overlay" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                    }
                }
                "usageStats" -> {
                    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    startActivity(intent)
                }
                "appDetails" -> {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.parse("package:$packageName")
                    }
                    startActivity(intent)
                }
            }
        } catch (_: Exception) {}
    }
}
