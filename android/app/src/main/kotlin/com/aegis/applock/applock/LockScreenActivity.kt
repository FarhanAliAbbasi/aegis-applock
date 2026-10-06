package com.aegis.applock.applock

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.CountDownTimer
import android.os.Vibrator
import android.os.VibrationEffect
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.RelativeLayout
import android.widget.ScrollView
import android.widget.TextView
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest

class LockScreenActivity : Activity() {

    companion object {
        const val EXTRA_LOCKED_PACKAGE = "extra_locked_package"
        @Volatile var isShowing: Boolean = false
        @Volatile var currentLockedPackage: String? = null

        fun hashCredential(credential: String, salt: String): String {
            val input = "$salt:$credential"
            val digest = MessageDigest.getInstance("SHA-256")
            val hashBytes = digest.digest(input.toByteArray(Charsets.UTF_8))
            return hashBytes.joinToString("") { "%02x".format(it) }
        }
    }

    private var targetPackage: String = ""
    private var enteredPin = StringBuilder()
    private var countDownTimer: CountDownTimer? = null

    // UI elements
    private lateinit var rootLayout: RelativeLayout
    private lateinit var appIconView: ImageView
    private lateinit var appTitleView: TextView
    private lateinit var statusTextView: TextView
    private lateinit var lockoutBanner: TextView
    private lateinit var pinDotsLayout: LinearLayout
    private lateinit var keypadLayout: LinearLayout
    private var patternView: PatternView? = null
    private lateinit var forgotButton: TextView

    private val pinDots = mutableListOf<View>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setWindowAnimations(0)
        try {
            overridePendingTransition(0, 0)
        } catch (_: Exception) {}

        // Block screenshots, task switcher previews, screen recorders
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )

        targetPackage = intent.getStringExtra(EXTRA_LOCKED_PACKAGE) ?: ""
        LockSessionManager.init(this)

        buildUI()
        checkLockoutStatus()

        // Auto prompt biometric if enabled and not currently locked out
        if (LockSessionManager.isBiometricEnabled() && LockSessionManager.getRemainingLockoutSeconds() == 0) {
            triggerBiometricPrompt()
        }
    }

    override fun onResume() {
        super.onResume()
        isShowing = true
        currentLockedPackage = targetPackage
    }

    override fun onPause() {
        super.onPause()
        if (isFinishing) {
            isShowing = false
            currentLockedPackage = null
        }
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        val newTarget = intent?.getStringExtra(EXTRA_LOCKED_PACKAGE)
        if (!newTarget.isNullOrEmpty() && newTarget != targetPackage) {
            targetPackage = newTarget
            enteredPin.clear()
            buildUI()
            checkLockoutStatus()
        }
    }

    override fun onBackPressed() {
        isShowing = false
        currentLockedPackage = null
        // Redirect to Home so user cannot sneak into the locked app
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
        finish()
    }

    private fun buildUI() {
        rootLayout = RelativeLayout(this).apply {
            setBackgroundColor(Color.parseColor("#0B0F19"))
            setPadding(dp(24), dp(48), dp(24), dp(24))
        }

        val scrollContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
        }

        // 1. App Icon & Title
        appIconView = ImageView(this).apply {
            layoutParams = LinearLayout.LayoutParams(dp(72), dp(72)).apply {
                bottomMargin = dp(12)
            }
        }
        try {
            if (targetPackage.isNotEmpty()) {
                val appInfo = packageManager.getApplicationInfo(targetPackage, 0)
                appIconView.setImageDrawable(packageManager.getApplicationIcon(appInfo))
            } else {
                appIconView.setImageResource(R.mipmap.ic_launcher)
            }
        } catch (_: Exception) {
            appIconView.setImageResource(R.mipmap.ic_launcher)
        }
        scrollContainer.addView(appIconView)

        appTitleView = TextView(this).apply {
            var label = "Application"
            try {
                if (targetPackage.isNotEmpty()) {
                    val appInfo = packageManager.getApplicationInfo(targetPackage, 0)
                    label = packageManager.getApplicationLabel(appInfo).toString()
                }
            } catch (_: Exception) {}
            text = "$label is Locked"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = dp(4) }
        }
        scrollContainer.addView(appTitleView)

        statusTextView = TextView(this).apply {
            text = "Enter your PIN or use biometrics to continue"
            setTextColor(Color.parseColor("#94A3B8"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = dp(16) }
        }
        scrollContainer.addView(statusTextView)

        // 2. Lockout Warning Banner
        lockoutBanner = TextView(this).apply {
            visibility = View.GONE
            setTextColor(Color.parseColor("#FF5252"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(dp(16), dp(10), dp(16), dp(10))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#26FF5252"))
                cornerRadius = dp(12).toFloat()
                setStroke(dp(1), Color.parseColor("#4DFF5252"))
            }
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = dp(16) }
        }
        scrollContainer.addView(lockoutBanner)

        val lockType = LockSessionManager.getLockType()
        if (lockType == "pattern") {
            buildPatternUI(scrollContainer)
        } else {
            buildPinUI(scrollContainer)
        }

        // Bottom "Forgot PIN / Security Questions" link
        forgotButton = TextView(this).apply {
            text = "Forgot PIN? Answer Security Questions"
            setTextColor(Color.parseColor("#00E5FF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(dp(8), dp(16), dp(8), dp(16))
            setOnClickListener {
                showSecurityQuestionsDialog()
            }
        }
        scrollContainer.addView(forgotButton)

        val scrollView = ScrollView(this).apply {
            isFillViewport = true
            addView(scrollContainer)
        }
        rootLayout.addView(scrollView, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        setContentView(rootLayout)
    }

    private fun buildPinUI(container: LinearLayout) {
        // PIN Dots
        pinDotsLayout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = dp(24) }
        }
        pinDots.clear()
        for (i in 0 until 4) {
            val dot = View(this).apply {
                layoutParams = LinearLayout.LayoutParams(dp(16), dp(16)).apply {
                    setMargins(dp(8), 0, dp(8), 0)
                }
                background = createDotDrawable(false)
            }
            pinDots.add(dot)
            pinDotsLayout.addView(dot)
        }
        container.addView(pinDotsLayout)

        // Keypad (1 to 9, Biometric, 0, Backspace)
        keypadLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }

        val rows = arrayOf(
            arrayOf("1", "2", "3"),
            arrayOf("4", "5", "6"),
            arrayOf("7", "8", "9"),
            arrayOf("BIO", "0", "DEL")
        )

        for (row in rows) {
            val rowLayout = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                ).apply { bottomMargin = dp(12) }
            }

            for (key in row) {
                val btn = Button(this).apply {
                    layoutParams = LinearLayout.LayoutParams(dp(76), dp(76)).apply {
                        setMargins(dp(10), 0, dp(10), 0)
                    }
                    background = GradientDrawable().apply {
                        setColor(Color.parseColor("#151D2F"))
                        cornerRadius = dp(38).toFloat()
                        setStroke(dp(1), Color.parseColor("#232F48"))
                    }
                    setTextColor(Color.WHITE)
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 22f)
                    typeface = Typeface.DEFAULT_BOLD

                    when (key) {
                        "BIO" -> {
                            text = "🛡️"
                            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
                            setOnClickListener {
                                if (LockSessionManager.getRemainingLockoutSeconds() == 0) {
                                    triggerBiometricPrompt()
                                }
                            }
                        }
                        "DEL" -> {
                            text = "⌫"
                            setOnClickListener {
                                if (enteredPin.isNotEmpty()) {
                                    enteredPin.deleteCharAt(enteredPin.length - 1)
                                    updatePinDots()
                                    vibrate(20)
                                }
                            }
                        }
                        else -> {
                            text = key
                            setOnClickListener {
                                onPinDigitPressed(key)
                            }
                        }
                    }
                }
                rowLayout.addView(btn)
            }
            keypadLayout.addView(rowLayout)
        }
        container.addView(keypadLayout)
    }

    private fun buildPatternUI(container: LinearLayout) {
        patternView = PatternView(this).apply {
            layoutParams = LinearLayout.LayoutParams(dp(300), dp(300)).apply {
                bottomMargin = dp(24)
            }
            listener = object : PatternView.OnPatternListener {
                override fun onPatternDetected(pattern: List<Int>) {
                    onPatternEntered(pattern.joinToString("-"))
                }
                override fun onPatternCleared() {}
            }
        }
        container.addView(patternView)
    }

    private fun onPinDigitPressed(digit: String) {
        if (LockSessionManager.getRemainingLockoutSeconds() > 0) {
            return
        }
        if (enteredPin.length >= 4) return

        enteredPin.append(digit)
        updatePinDots()
        vibrate(30)

        if (enteredPin.length == 4) {
            verifyPin(enteredPin.toString())
        }
    }

    private fun updatePinDots() {
        for (i in pinDots.indices) {
            pinDots[i].background = createDotDrawable(i < enteredPin.length)
        }
    }

    private fun createDotDrawable(filled: Boolean): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            if (filled) {
                setColor(Color.parseColor("#00E5FF"))
            } else {
                setColor(Color.parseColor("#1E293B"))
                setStroke(dp(2), Color.parseColor("#475569"))
            }
        }
    }

    private fun verifyPin(pin: String) {
        val storedHash = LockSessionManager.getPinHash()
        val storedSalt = LockSessionManager.getPinSalt() ?: "aegis_default_salt"

        // Default PIN for first run if not set is 1234
        val isCorrect = if (storedHash != null) {
            hashCredential(pin, storedSalt) == storedHash
        } else {
            pin == "1234"
        }

        if (isCorrect) {
            handleUnlockSuccess()
        } else {
            handleUnlockFailure()
        }
    }

    private fun onPatternEntered(pattern: String) {
        if (LockSessionManager.getRemainingLockoutSeconds() > 0) return

        val storedHash = LockSessionManager.getPatternHash()
        val storedSalt = LockSessionManager.getPatternSalt() ?: "aegis_pattern_salt"

        val isCorrect = if (storedHash != null) {
            hashCredential(pattern, storedSalt) == storedHash
        } else {
            pattern == "0-1-2-5" // Default pattern fallback
        }

        if (isCorrect) {
            handleUnlockSuccess()
        } else {
            handleUnlockFailure()
            patternView?.clearPattern()
        }
    }

    private fun handleUnlockSuccess() {
        isShowing = false
        currentLockedPackage = null
        vibrate(50)
        LockSessionManager.markAppUnlocked(targetPackage)
        finish()
        overridePendingTransition(0, 0)
    }

    private fun handleUnlockFailure() {
        vibrate(200)
        enteredPin.clear()
        updatePinDots()

        val result = LockSessionManager.recordFailedAttempt()
        statusTextView.text = "Incorrect credentials. (${result.failedAttempts} fails)"
        statusTextView.setTextColor(Color.parseColor("#FF5252"))

        checkLockoutStatus()

        if (result.securityQuestionsRequired) {
            showSecurityQuestionsDialog()
        }
    }

    private fun checkLockoutStatus() {
        val remaining = LockSessionManager.getRemainingLockoutSeconds()
        if (remaining > 0) {
            startLockoutCountdown(remaining)
        } else {
            lockoutBanner.visibility = View.GONE
            setKeypadEnabled(true)
        }
    }

    private fun startLockoutCountdown(seconds: Int) {
        setKeypadEnabled(false)
        lockoutBanner.visibility = View.VISIBLE

        countDownTimer?.cancel()
        countDownTimer = object : CountDownTimer((seconds * 1000).toLong(), 1000) {
            override fun onTick(millisUntilFinished: Long) {
                val secs = millisUntilFinished / 1000
                lockoutBanner.text = "Too many failed attempts! Locked for ${secs}s"
            }

            override fun onFinish() {
                lockoutBanner.visibility = View.GONE
                statusTextView.text = "You may try again now."
                statusTextView.setTextColor(Color.parseColor("#94A3B8"))
                setKeypadEnabled(true)
                if (LockSessionManager.isSecurityQuestionsRequired()) {
                    showSecurityQuestionsDialog()
                }
            }
        }.start()
    }

    private fun setKeypadEnabled(enabled: Boolean) {
        for (i in 0 until keypadLayout.childCount) {
            val row = keypadLayout.getChildAt(i) as? ViewGroup ?: continue
            for (j in 0 until row.childCount) {
                row.getChildAt(j).isEnabled = enabled
            }
        }
        patternView?.isEnabled = enabled
    }

    // --- Biometrics Trigger ---
    private fun triggerBiometricPrompt() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                val prompt = BiometricPrompt.Builder(this)
                    .setTitle("Unlock $targetPackage")
                    .setSubtitle("Use Fingerprint or Face to unlock")
                    .setNegativeButton("Use PIN", mainExecutor) { _, _ -> }
                    .build()

                val cancellationSignal = CancellationSignal()
                prompt.authenticate(
                    cancellationSignal,
                    mainExecutor,
                    object : BiometricPrompt.AuthenticationCallback() {
                        override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult?) {
                            super.onAuthenticationSucceeded(result)
                            handleUnlockSuccess()
                        }
                        override fun onAuthenticationFailed() {
                            super.onAuthenticationFailed()
                            vibrate(100)
                        }
                    }
                )
            } catch (_: Exception) {}
        }
    }

    // --- Security Questions Challenge Dialog ---
    private fun showSecurityQuestionsDialog() {
        val rawData = LockSessionManager.getSecurityQuestionsData()
        val questionsList = mutableListOf<JSONObject>()

        if (!rawData.isNullOrEmpty()) {
            try {
                val array = JSONArray(rawData)
                for (i in 0 until array.length()) {
                    questionsList.add(array.getJSONObject(i))
                }
            } catch (_: Exception) {}
        }

        // Fallback default questions if not set
        if (questionsList.isEmpty()) {
            questionsList.add(JSONObject().put("question", "What was the name of your first school?").put("hash", hashCredential("school", "aegis_sq_salt")).put("salt", "aegis_sq_salt"))
            questionsList.add(JSONObject().put("question", "What is your best friend's name?").put("hash", hashCredential("friend", "aegis_sq_salt")).put("salt", "aegis_sq_salt"))
        }

        val dialogView = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#101726"))
            setPadding(dp(20), dp(20), dp(20), dp(20))
        }

        val dialogTitle = TextView(this).apply {
            text = "🛡️ Security Recovery Challenge"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            typeface = Typeface.DEFAULT_BOLD
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                bottomMargin = dp(14)
            }
        }
        dialogView.addView(dialogTitle)

        val inputFields = mutableListOf<Pair<JSONObject, EditText>>()

        for (qObj in questionsList) {
            val qText = TextView(this).apply {
                text = qObj.optString("question", "Security Question")
                setTextColor(Color.parseColor("#00E5FF"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                typeface = Typeface.DEFAULT_BOLD
                layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                    bottomMargin = dp(4)
                }
            }
            dialogView.addView(qText)

            val answerInput = EditText(this).apply {
                hint = "Enter answer"
                setHintTextColor(Color.parseColor("#64748B"))
                setTextColor(Color.WHITE)
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#1E293B"))
                    cornerRadius = dp(8).toFloat()
                    setStroke(dp(1), Color.parseColor("#334155"))
                }
                setPadding(dp(12), dp(10), dp(12), dp(10))
                layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                    bottomMargin = dp(12)
                }
            }
            dialogView.addView(answerInput)
            inputFields.add(Pair(qObj, answerInput))
        }

        val errorText = TextView(this).apply {
            visibility = View.GONE
            setTextColor(Color.parseColor("#FF5252"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                bottomMargin = dp(8)
            }
        }
        dialogView.addView(errorText)

        val submitBtn = Button(this).apply {
            text = "Verify & Unlock"
            setTextColor(Color.parseColor("#0B0F19"))
            typeface = Typeface.DEFAULT_BOLD
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#00E5FF"))
                cornerRadius = dp(10).toFloat()
            }
        }
        dialogView.addView(submitBtn)

        val dialog = android.app.AlertDialog.Builder(this)
            .setView(dialogView)
            .setCancelable(true)
            .create()

        submitBtn.setOnClickListener {
            var allCorrect = true
            for (pair in inputFields) {
                val qObj = pair.first
                val input = pair.second.text.toString().trim().lowercase()
                val targetHash = qObj.optString("hash")
                val salt = qObj.optString("salt", "aegis_sq_salt")

                val hashedInput = hashCredential(input, salt)
                if (targetHash.isNotEmpty() && hashedInput != targetHash) {
                    allCorrect = false
                    break
                }
            }

            if (allCorrect) {
                dialog.dismiss()
                LockSessionManager.resetFailedAttempts()
                handleUnlockSuccess()
            } else {
                vibrate(200)
                errorText.text = "One or more answers are incorrect. Please try again."
                errorText.visibility = View.VISIBLE
            }
        }

        dialog.show()
    }

    private fun vibrate(durationMs: Long) {
        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.vibrate(VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            vibrator?.vibrate(durationMs)
        }
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }

    override fun onDestroy() {
        super.onDestroy()
        isShowing = false
        currentLockedPackage = null
        countDownTimer?.cancel()
    }
}
