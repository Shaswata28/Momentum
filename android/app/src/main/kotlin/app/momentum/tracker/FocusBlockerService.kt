package app.momentum.tracker

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.LayerDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.Gravity
import android.view.KeyEvent
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.ImageView
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class FocusBlockerService : AccessibilityService() {

    companion object {
        const val PREFS_NAME = "focus_shield_prefs"
        const val KEY_IS_SHIELD_ENABLED = "is_shield_enabled"
        const val KEY_IS_DND_ACTIVE = "is_dnd_active"
        const val KEY_ACTIVE_TASK_NAME = "active_task_name"
        const val KEY_ACTIVE_TASK_END_TIME = "active_task_end_time"
        const val KEY_BLOCKED_PACKAGES = "blocked_packages"
        const val KEY_EMERGENCY_PASS_UNTIL = "emergency_pass_until"
        const val KEY_EMERGENCY_PASS_DATE = "emergency_pass_date"
        const val KEY_EMERGENCY_PASSES_USED = "emergency_passes_used"
        const val KEY_IS_RETRO = "is_retro"
        const val KEY_IS_DARK = "is_dark"
        const val KEY_THEME_MODE = "theme_mode"

        var isServiceRunning = false
    }

    private var windowManager: WindowManager? = null
    private var isOverlayAttached = false
    private var currentOverlayView: View? = null
    private var currentBlockedPackage: String? = null
    private var lastForegroundPackage: String? = null
    private var countdownRunnable: Runnable? = null
    private var passExpirationRunnable: Runnable? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onServiceConnected() {
        super.onServiceConnected()
        isServiceRunning = true
        windowManager = getSystemService(Context.WINDOW_SERVICE) as? WindowManager
    }

    override fun onDestroy() {
        super.onDestroy()
        isServiceRunning = false
        passExpirationRunnable?.let { mainHandler.removeCallbacks(it) }
        passExpirationRunnable = null
        removeOverlay()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            return
        }

        val pkgName = event.packageName?.toString() ?: return
        val className = event.className?.toString() ?: ""

        // Case 1: Events from Momentum package itself
        if (pkgName == packageName) {
            if (className.contains("MainActivity")) {
                removeOverlay()
            }
            return
        }

        // Case 2: Transient system UI elements (status bar, keyboard, toasts)
        if (pkgName == "com.android.systemui" ||
            className.contains("InputMethod") ||
            className.contains("Toast")) {
            return
        }

        lastForegroundPackage = pkgName

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isShieldEnabled = prefs.getBoolean(KEY_IS_SHIELD_ENABLED, true)
        val isDndActive = prefs.getBoolean(KEY_IS_DND_ACTIVE, false)
        val emergencyUntil = prefs.getLong(KEY_EMERGENCY_PASS_UNTIL, 0L)
        val taskEndTime = prefs.getLong(KEY_ACTIVE_TASK_END_TIME, 0L)
        val now = System.currentTimeMillis()

        // 1. If shield master toggle is off, never block
        if (!isShieldEnabled) {
            removeOverlay()
            return
        }

        // 2. If task scheduled session has already elapsed, auto-deactivate
        if (taskEndTime > 0L && now >= taskEndTime) {
            prefs.edit().putBoolean(KEY_IS_DND_ACTIVE, false).apply()
            removeOverlay()
            return
        }

        // 3. If DND is inactive or emergency pass is running, dismiss overlay
        if (!isDndActive || now < emergencyUntil) {
            removeOverlay()
            return
        }

        val blockedSet = prefs.getStringSet(KEY_BLOCKED_PACKAGES, emptySet()) ?: emptySet()

        if (blockedSet.contains(pkgName)) {
            // Blocked app is in foreground!
            if (isOverlayAttached && currentBlockedPackage == pkgName && currentOverlayView != null) {
                return
            }

            // Trigger overlay directly over the blocked app
            showOverlay(pkgName, prefs)
        } else {
            // An allowed app or the home launcher came to the foreground
            removeOverlay()
        }
    }

    private fun showOverlay(pkgName: String, prefs: SharedPreferences) {
        mainHandler.post {
            try {
                if (windowManager == null) {
                    windowManager = getSystemService(Context.WINDOW_SERVICE) as? WindowManager
                }
                val wm = windowManager ?: return@post

                // If already attached for this package, do nothing
                if (isOverlayAttached && currentBlockedPackage == pkgName && currentOverlayView != null) {
                    return@post
                }

                // Clean up previous view if switching apps
                removeOverlayInternal()

                val inflater = LayoutInflater.from(this)
                val overlayView = inflater.inflate(R.layout.focus_friction_overlay, null)

                // Resolve friendly app name
                var appName = pkgName
                try {
                    val appInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        packageManager.getApplicationInfo(pkgName, PackageManager.ApplicationInfoFlags.of(0L))
                    } else {
                        @Suppress("DEPRECATION")
                        packageManager.getApplicationInfo(pkgName, 0)
                    }
                    appName = packageManager.getApplicationLabel(appInfo).toString()
                } catch (_: Exception) {}

                val taskName = prefs.getString(KEY_ACTIVE_TASK_NAME, "Focus Task") ?: "Focus Task"
                val taskEndTime = prefs.getLong(KEY_ACTIVE_TASK_END_TIME, 0L)
                val remainingPasses = getRemainingPasses(prefs)

                val isRetro = prefs.getBoolean(KEY_IS_RETRO, false)
                val isDark = prefs.getBoolean(KEY_IS_DARK, true)

                // Colors matching Momentum theme
                val bgCol: Int
                val cardBgCol: Int
                val inputBgCol: Int
                val cardBorderCol: Int
                val textPrimaryCol: Int
                val textSecondaryCol: Int
                val textMutedCol: Int
                val accentCol: Int
                val warningCol: Int
                val shadowCol: Int

                if (isRetro) {
                    if (isDark) {
                        // Retro Dark (Gray console)
                        bgCol = 0xFF141418.toInt()
                        cardBgCol = 0xFF1E1E26.toInt()
                        inputBgCol = 0xFF18181F.toInt()
                        cardBorderCol = 0xFF4A4A62.toInt()
                        textPrimaryCol = 0xFFF0EFF8.toInt()
                        textSecondaryCol = 0xFFB0B0C4.toInt()
                        textMutedCol = 0xFF7A7A90.toInt()
                        accentCol = 0xFFF26B21.toInt()
                        warningCol = 0xFFF2C230.toInt()
                        shadowCol = 0xFF000000.toInt()
                    } else {
                        // Retro Light (Beige console)
                        bgCol = 0xFFD9D2BE.toInt()
                        cardBgCol = 0xFFE8E2D0.toInt()
                        inputBgCol = 0xFFECE7D8.toInt()
                        cardBorderCol = 0xFF2A2622.toInt()
                        textPrimaryCol = 0xFF2A2622.toInt()
                        textSecondaryCol = 0xFF4A443B.toInt()
                        textMutedCol = 0xFF6B6457.toInt()
                        accentCol = 0xFFF26B21.toInt()
                        warningCol = 0xFFF2C230.toInt()
                        shadowCol = 0xFF2A2622.toInt()
                    }
                } else {
                    if (isDark) {
                        // Classic Dark
                        bgCol = 0xFF090A0F.toInt()
                        cardBgCol = 0xFF12131A.toInt()
                        inputBgCol = 0xFF12131A.toInt()
                        cardBorderCol = 0xFF20222E.toInt()
                        textPrimaryCol = 0xFFF8FAFC.toInt()
                        textSecondaryCol = 0xFF94A3B8.toInt()
                        textMutedCol = 0xFF64748B.toInt()
                        accentCol = 0xFF388AF6.toInt()
                        warningCol = 0xFFF59E0B.toInt()
                        shadowCol = 0
                    } else {
                        // Classic Light
                        bgCol = 0xFFF8FAFC.toInt()
                        cardBgCol = 0xFFFFFFFF.toInt()
                        inputBgCol = 0xFFFFFFFF.toInt()
                        cardBorderCol = 0xFFE2E8F0.toInt()
                        textPrimaryCol = 0xFF0F172A.toInt()
                        textSecondaryCol = 0xFF64748B.toInt()
                        textMutedCol = 0xFF94A3B8.toInt()
                        accentCol = 0xFF2563EB.toInt()
                        warningCol = 0xFFD97706.toInt()
                        shadowCol = 0
                    }
                }

                // 1. Root Background
                overlayView.setBackgroundColor(bgCol)

                // 2. Status Badge
                val layoutStatusBadge = overlayView.findViewById<View>(R.id.layout_status_badge)
                val ivStatusIcon = overlayView.findViewById<ImageView>(R.id.iv_status_icon)
                val tvStatusTitle = overlayView.findViewById<TextView>(R.id.tv_status_title)

                if (isRetro) {
                    layoutStatusBadge.background = createRetroBoxDrawable(cardBgCol, cardBorderCol, shadowCol, dpToPx(2f), dpToPx(2f))
                    tvStatusTitle.text = "FOCUS SHIELD ACTIVE"
                    tvStatusTitle.setTextColor(textPrimaryCol)
                    ivStatusIcon.setColorFilter(accentCol)
                } else {
                    val alphaBg = Color.argb((255 * 0.08f).toInt(), Color.red(accentCol), Color.green(accentCol), Color.blue(accentCol))
                    val alphaBorder = Color.argb((255 * 0.25f).toInt(), Color.red(accentCol), Color.green(accentCol), Color.blue(accentCol))
                    layoutStatusBadge.background = createRoundedDrawable(alphaBg, alphaBorder, dpToPx(1f), dpToPx(20f).toFloat())
                    tvStatusTitle.text = "Focus Shield Active"
                    tvStatusTitle.setTextColor(accentCol)
                    ivStatusIcon.setColorFilter(accentCol)
                }

                // 3. Center Shield Container
                val layoutShieldContainer = overlayView.findViewById<View>(R.id.layout_shield_container)
                val ivShieldLarge = overlayView.findViewById<ImageView>(R.id.iv_shield_large)

                if (isRetro) {
                    layoutShieldContainer.background = createRetroBoxDrawable(accentCol, cardBorderCol, shadowCol, dpToPx(2f), dpToPx(5f))
                    val iconColor = if (isDark) 0xFF141418.toInt() else 0xFFFFFFFF.toInt()
                    ivShieldLarge.setColorFilter(iconColor)
                } else {
                    val alphaBg = Color.argb((255 * 0.10f).toInt(), Color.red(accentCol), Color.green(accentCol), Color.blue(accentCol))
                    val alphaBorder = Color.argb((255 * 0.35f).toInt(), Color.red(accentCol), Color.green(accentCol), Color.blue(accentCol))
                    layoutShieldContainer.background = createRoundedDrawable(alphaBg, alphaBorder, dpToPx(1.5f), dpToPx(26f).toFloat())
                    ivShieldLarge.setColorFilter(accentCol)
                }

                // 4. Blocked App Name & Task Title
                val tvAppName = overlayView.findViewById<TextView>(R.id.tv_friction_app_name)
                val tvTaskTitle = overlayView.findViewById<TextView>(R.id.tv_task_title)

                tvAppName.text = appName.uppercase(Locale.getDefault())
                tvAppName.setTextColor(textSecondaryCol)

                tvTaskTitle.text = taskName
                tvTaskTitle.setTextColor(textPrimaryCol)

                // 5. Countdown Card
                val layoutCountdownCard = overlayView.findViewById<View>(R.id.layout_countdown_card)
                val ivCountdownIcon = overlayView.findViewById<ImageView>(R.id.iv_countdown_icon)
                val tvCountdownLabel = overlayView.findViewById<TextView>(R.id.tv_countdown_label)
                val tvRemainingTime = overlayView.findViewById<TextView>(R.id.tv_remaining_time)
                val tvCountdownSubtitle = overlayView.findViewById<TextView>(R.id.tv_countdown_subtitle)

                if (isRetro) {
                    layoutCountdownCard.background = createRetroBoxDrawable(cardBgCol, cardBorderCol, shadowCol, dpToPx(2f), dpToPx(4f))
                    tvCountdownLabel.text = "TIME REMAINING"
                    tvCountdownLabel.setTextColor(textSecondaryCol)
                    ivCountdownIcon.setColorFilter(textSecondaryCol)
                } else {
                    layoutCountdownCard.background = createRoundedDrawable(cardBgCol, cardBorderCol, dpToPx(1f), dpToPx(18f).toFloat())
                    tvCountdownLabel.text = "Time remaining"
                    tvCountdownLabel.setTextColor(textSecondaryCol)
                    ivCountdownIcon.setColorFilter(textSecondaryCol)
                }
                tvRemainingTime.setTextColor(textPrimaryCol)
                tvCountdownSubtitle.setTextColor(textMutedCol)

                // Live Countdown timer with smooth auto-completion
                startCountdown(tvRemainingTime, taskEndTime)

                // 6. Primary Action: Stay Focused
                val btnReturnHome = overlayView.findViewById<View>(R.id.btn_return_home)
                val ivStayFocusedIcon = overlayView.findViewById<ImageView>(R.id.iv_stay_focused_icon)
                val tvBtnStayFocused = overlayView.findViewById<TextView>(R.id.tv_btn_stay_focused)

                if (isRetro) {
                    btnReturnHome.background = createRetroBoxDrawable(accentCol, cardBorderCol, shadowCol, dpToPx(2f), dpToPx(4f))
                    tvBtnStayFocused.text = "STAY FOCUSED"
                    val btnContentColor = if (isDark) 0xFF141418.toInt() else 0xFFFFFFFF.toInt()
                    tvBtnStayFocused.setTextColor(btnContentColor)
                    ivStayFocusedIcon.setColorFilter(btnContentColor)
                } else {
                    btnReturnHome.background = createRoundedDrawable(accentCol, 0, 0, dpToPx(14f).toFloat())
                    tvBtnStayFocused.text = "Stay Focused"
                    tvBtnStayFocused.setTextColor(0xFFFFFFFF.toInt())
                    ivStayFocusedIcon.setColorFilter(0xFFFFFFFF.toInt())
                }

                btnReturnHome.setOnClickListener {
                    removeOverlay()
                    performGlobalAction(GLOBAL_ACTION_HOME)
                }

                // 7. Secondary Action: Emergency Pass
                val btnEmergencyPass = overlayView.findViewById<View>(R.id.btn_emergency_pass)
                val ivEmergencyPassIcon = overlayView.findViewById<ImageView>(R.id.iv_emergency_pass_icon)
                val tvEmergencyPassLabel = overlayView.findViewById<TextView>(R.id.tv_emergency_pass_label)
                val layoutPassBadge = overlayView.findViewById<View>(R.id.layout_pass_badge)
                val tvPassCount = overlayView.findViewById<TextView>(R.id.tv_pass_count)

                val hasPass = remainingPasses > 0
                if (isRetro) {
                    val passBg = if (hasPass) inputBgCol else cardBgCol
                    btnEmergencyPass.background = createRetroBoxDrawable(passBg, cardBorderCol, if (hasPass) shadowCol else 0, dpToPx(2f), if (hasPass) dpToPx(3f) else 0)
                    tvEmergencyPassLabel.text = if (hasPass) "EMERGENCY PASS  (5 MIN)" else "NO PASSES LEFT TODAY"
                    tvEmergencyPassLabel.setTextColor(if (hasPass) textPrimaryCol else textMutedCol)
                    ivEmergencyPassIcon.setColorFilter(if (hasPass) warningCol else textMutedCol)

                    val badgeBg = if (hasPass) (if (isDark) 0xFF332616.toInt() else 0xFFD9CCAA.toInt()) else (if (isDark) 0xFF262630.toInt() else 0xFFCFC8B2.toInt())
                    layoutPassBadge.background = createRetroBoxDrawable(badgeBg, cardBorderCol, 0, dpToPx(1f), 0)
                    tvPassCount.text = "$remainingPasses LEFT"
                    val badgeTextColor = if (hasPass) (if (isDark) warningCol else 0xFFB45309.toInt()) else textMutedCol
                    tvPassCount.setTextColor(badgeTextColor)
                } else {
                    val passBorder = if (hasPass) Color.argb((255 * 0.40f).toInt(), Color.red(warningCol), Color.green(warningCol), Color.blue(warningCol)) else cardBorderCol
                    btnEmergencyPass.background = createRoundedDrawable(cardBgCol, passBorder, dpToPx(1f), dpToPx(14f).toFloat())
                    tvEmergencyPassLabel.text = if (hasPass) "Use Emergency Pass  · 5 min" else "No Emergency Passes Left"
                    tvEmergencyPassLabel.setTextColor(if (hasPass) textPrimaryCol else textMutedCol)
                    ivEmergencyPassIcon.setColorFilter(if (hasPass) warningCol else textMutedCol)

                    val badgeBg = if (hasPass) Color.argb((255 * 0.12f).toInt(), Color.red(warningCol), Color.green(warningCol), Color.blue(warningCol)) else Color.argb((255 * 0.10f).toInt(), Color.red(textMutedCol), Color.green(textMutedCol), Color.blue(textMutedCol))
                    layoutPassBadge.background = createRoundedDrawable(badgeBg, 0, 0, dpToPx(6f).toFloat())
                    tvPassCount.text = "$remainingPasses LEFT"
                    tvPassCount.setTextColor(if (hasPass) warningCol else textMutedCol)
                }

                btnEmergencyPass.setOnClickListener {
                    val passesLeft = getRemainingPasses(prefs)
                    if (passesLeft > 0) {
                        val used = prefs.getInt(KEY_EMERGENCY_PASSES_USED, 0)
                        val passUntil = System.currentTimeMillis() + (5 * 60 * 1000L)
                        prefs.edit()
                            .putInt(KEY_EMERGENCY_PASSES_USED, used + 1)
                            .putLong(KEY_EMERGENCY_PASS_UNTIL, passUntil)
                            .apply()
                        removeOverlay()

                        // Recheck foreground when emergency pass expires in 5 minutes
                        schedulePassExpirationCheck(5 * 60 * 1000L + 500L)
                    } else {
                        triggerErrorHaptic()
                    }
                }

                // Consume touches so clicks cannot pass through to the blocked app
                overlayView.setOnTouchListener { _, _ -> true }

                // Intercept back key to return home safely
                overlayView.isFocusable = true
                overlayView.isFocusableInTouchMode = true
                overlayView.requestFocus()
                overlayView.setOnKeyListener { _, keyCode, keyEvent ->
                    if (keyCode == KeyEvent.KEYCODE_BACK && keyEvent.action == KeyEvent.ACTION_UP) {
                        removeOverlay()
                        performGlobalAction(GLOBAL_ACTION_HOME)
                        true
                    } else {
                        false
                    }
                }

                // WindowManager Layout Params with TYPE_ACCESSIBILITY_OVERLAY
                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS,
                    PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = Gravity.CENTER
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                    }
                }

                wm.addView(overlayView, params)
                currentOverlayView = overlayView
                currentBlockedPackage = pkgName
                isOverlayAttached = true

                // Fire tactile haptic feedback
                triggerHaptic()
            } catch (_: Exception) {}
        }
    }

    private fun schedulePassExpirationCheck(delayMs: Long) {
        passExpirationRunnable?.let { mainHandler.removeCallbacks(it) }
        passExpirationRunnable = Runnable {
            val p = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val dndOn = p.getBoolean(KEY_IS_DND_ACTIVE, false)
            val passesUntil = p.getLong(KEY_EMERGENCY_PASS_UNTIL, 0L)
            val currentPkg = lastForegroundPackage
            val blocked = p.getStringSet(KEY_BLOCKED_PACKAGES, emptySet()) ?: emptySet()
            if (dndOn && System.currentTimeMillis() >= passesUntil && currentPkg != null && blocked.contains(currentPkg)) {
                showOverlay(currentPkg, p)
            }
        }
        mainHandler.postDelayed(passExpirationRunnable!!, delayMs)
    }

    private fun startCountdown(tvRemainingTime: TextView, taskEndTime: Long) {
        countdownRunnable?.let { mainHandler.removeCallbacks(it) }
        countdownRunnable = object : Runnable {
            override fun run() {
                val diff = taskEndTime - System.currentTimeMillis()
                if (diff > 0) {
                    val diffSecs = (diff / 1000).toInt()
                    val hrs = diffSecs / 3600
                    val mins = (diffSecs % 3600) / 60
                    val secs = diffSecs % 60
                    tvRemainingTime.text = if (hrs > 0) {
                        String.format(Locale.getDefault(), "%dh %02dm", hrs, mins)
                    } else if (mins > 0) {
                        String.format(Locale.getDefault(), "%d:%02d", mins, secs)
                    } else {
                        String.format(Locale.getDefault(), "0:%02d", secs)
                    }
                    mainHandler.postDelayed(this, 1000)
                } else {
                    tvRemainingTime.text = "Session complete"
                    mainHandler.postDelayed({
                        val p = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                        p.edit().putBoolean(KEY_IS_DND_ACTIVE, false).apply()
                        removeOverlay()
                    }, 1500)
                }
            }
        }
        countdownRunnable?.let { mainHandler.post(it) }
    }

    private fun dpToPx(dp: Float): Int {
        return (dp * resources.displayMetrics.density).toInt()
    }

    private fun createRoundedDrawable(
        fillColor: Int,
        strokeColor: Int,
        strokeWidthPx: Int,
        cornerRadiusPx: Float
    ): Drawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(fillColor)
            cornerRadius = cornerRadiusPx
            if (strokeWidthPx > 0 && strokeColor != 0) {
                setStroke(strokeWidthPx, strokeColor)
            }
        }
    }

    private fun createRetroBoxDrawable(
        fillColor: Int,
        strokeColor: Int,
        shadowColor: Int,
        strokeWidthPx: Int,
        shadowOffsetPx: Int
    ): Drawable {
        if (shadowOffsetPx <= 0) {
            return GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                setColor(fillColor)
                if (strokeWidthPx > 0) {
                    setStroke(strokeWidthPx, strokeColor)
                }
            }
        }

        val shadow = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(shadowColor)
        }
        val front = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(fillColor)
            if (strokeWidthPx > 0) {
                setStroke(strokeWidthPx, strokeColor)
            }
        }

        return LayerDrawable(arrayOf(shadow, front)).apply {
            setLayerInset(0, shadowOffsetPx, shadowOffsetPx, 0, 0)
            setLayerInset(1, 0, 0, shadowOffsetPx, shadowOffsetPx)
        }
    }

    private fun removeOverlay() {
        mainHandler.post {
            removeOverlayInternal()
        }
    }

    private fun removeOverlayInternal() {
        try {
            countdownRunnable?.let { mainHandler.removeCallbacks(it) }
            countdownRunnable = null
            if (isOverlayAttached && currentOverlayView != null && windowManager != null) {
                windowManager?.removeView(currentOverlayView)
            }
        } catch (_: Exception) {}
        isOverlayAttached = false
        currentOverlayView = null
        currentBlockedPackage = null
    }

    private fun getRemainingPasses(prefs: SharedPreferences): Int {
        val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        val savedDate = prefs.getString(KEY_EMERGENCY_PASS_DATE, "") ?: ""
        if (savedDate != todayStr) {
            prefs.edit()
                .putString(KEY_EMERGENCY_PASS_DATE, todayStr)
                .putInt(KEY_EMERGENCY_PASSES_USED, 0)
                .apply()
            return 3
        }
        val used = prefs.getInt(KEY_EMERGENCY_PASSES_USED, 0)
        val remaining = 3 - used
        return if (remaining < 0) 0 else remaining
    }

    private fun triggerHaptic() {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vm?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }

            vibrator?.let { v ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val timings = longArrayOf(0, 60, 50, 80)
                    val amplitudes = intArrayOf(0, 200, 0, 255)
                    v.vibrate(VibrationEffect.createWaveform(timings, amplitudes, -1))
                } else {
                    @Suppress("DEPRECATION")
                    v.vibrate(longArrayOf(0, 60, 50, 80), -1)
                }
            }
        } catch (_: Exception) {}
    }

    private fun triggerErrorHaptic() {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vm?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }

            vibrator?.let { v ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    v.vibrate(VibrationEffect.createOneShot(120, VibrationEffect.DEFAULT_AMPLITUDE))
                } else {
                    @Suppress("DEPRECATION")
                    v.vibrate(120)
                }
            }
        } catch (_: Exception) {}
    }

    override fun onInterrupt() {
        removeOverlay()
    }
}
