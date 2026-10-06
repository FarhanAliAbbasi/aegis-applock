package com.aegis.applock.applock

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper

class AppLockService : Service() {

    companion object {
        const val CHANNEL_ID = "aegis_applock_service"
        const val NOTIFICATION_ID = 1001

        fun start(context: Context) {
            val intent = Intent(context, AppLockService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, AppLockService::class.java)
            context.stopService(intent)
        }
    }

    private var isRunning = false
    private val handler = Handler(Looper.getMainLooper())
    private var lastCheckedPackage: String? = null
    private val launcherPackages = mutableSetOf<String>()
    private var screenReceiver: BroadcastReceiver? = null
    private var isScreenOn = true

    private val monitorRunnable = object : Runnable {
        override fun run() {
            if (isRunning && isScreenOn) {
                checkForegroundApp()
                handler.postDelayed(this, 100) // Ultra-fast 100ms interception
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        LockSessionManager.init(this)
        loadLauncherPackages()
        createNotificationChannel()
        registerScreenReceiver()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NOTIFICATION_ID,
                    buildNotification(),
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else {
                startForeground(NOTIFICATION_ID, buildNotification())
            }
        } catch (e: Exception) {
            e.printStackTrace()
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    startForeground(
                        NOTIFICATION_ID,
                        buildNotification(),
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                    )
                }
            } catch (e2: Exception) {
                e2.printStackTrace()
            }
        }
        isRunning = true
        handler.post(monitorRunnable)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        handler.removeCallbacks(monitorRunnable)
        screenReceiver?.let {
            try { unregisterReceiver(it) } catch (_: Exception) {}
        }
    }

    private fun checkForegroundApp() {
        if (LockScreenActivity.isShowing) {
            return
        }

        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return
        val now = System.currentTimeMillis()
        val events = usm.queryEvents(now - 800, now) ?: return
        val event = UsageEvents.Event()

        var currentForeground: String? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                currentForeground = event.packageName
            }
        }

        val target = currentForeground ?: return
        val self = packageName

        // Ignore self, system UI, Android system
        if (target == self ||
            target == "com.android.systemui" ||
            target == "android"
        ) {
            return
        }

        // If user is at launcher / home screen, clear lastCheckedPackage
        if (launcherPackages.contains(target)) {
            lastCheckedPackage = null
            return
        }

        if (target != lastCheckedPackage) {
            lastCheckedPackage = target
            val isUninstaller = LockSessionManager.isAntiUninstallEnabled() && (
                target == "com.android.packageinstaller" ||
                target == "com.google.android.packageinstaller" ||
                target == "com.android.settings"
            )

            if (LockSessionManager.isAppLocked(target) || isUninstaller) {
                if (!LockSessionManager.isUnlockedSession(target)) {
                    launchLockScreen(target)
                }
            }
        }
    }

    private fun launchLockScreen(targetPackage: String) {
        val intent = Intent(this, LockScreenActivity::class.java).apply {
            putExtra(LockScreenActivity.EXTRA_LOCKED_PACKAGE, targetPackage)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            addFlags(Intent.FLAG_ACTIVITY_NO_ANIMATION)
            addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
        }
        startActivity(intent)
    }

    private fun loadLauncherPackages() {
        try {
            val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
            val resolveInfos = packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
            for (info in resolveInfos) {
                launcherPackages.add(info.activityInfo.packageName)
            }
        } catch (_: Exception) {}
    }

    private fun registerScreenReceiver() {
        screenReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    Intent.ACTION_SCREEN_OFF -> {
                        isScreenOn = false
                        handler.removeCallbacks(monitorRunnable)
                        if (LockSessionManager.getRelockPolicy() == "screen_off") {
                            LockSessionManager.clearAllSessions()
                        }
                    }
                    Intent.ACTION_SCREEN_ON -> {
                        isScreenOn = true
                        handler.post(monitorRunnable)
                    }
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
        }
        registerReceiver(screenReceiver, filter)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Aegis AppLock Active Protection",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps Aegis AppLock running to secure your applications"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val openIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle("Aegis AppLock is Active")
            .setContentText("Protected apps are secured")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
}
