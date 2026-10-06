package com.aegis.applock.applock

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON"
        ) {
            LockSessionManager.init(context)
            // Sessions reset upon phone reboot
            LockSessionManager.clearAllSessions()
            AppLockService.start(context)
        }
    }
}
