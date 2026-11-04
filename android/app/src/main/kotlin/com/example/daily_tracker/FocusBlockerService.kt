package com.example.daily_tracker

import android.accessibilityservice.AccessibilityService
import android.animation.ValueAnimator
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.graphics.PixelFormat
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
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class FocusBlockerService : AccessibilityService() {

    companion object {
        const val PREFS_NAME = "focus_shield_prefs"
        const val KEY_IS_DND_ACTIVE = "is_dnd_active"
        const val KEY_ACTIVE_TASK_NAME = "active_task_name"
        const val KEY_ACTIVE_TASK_END_TIME = "active_task_end_time"
        const val KEY_BLOCKED_PACKAGES = "blocked_packages"
        const val KEY_EMERGENCY_PASS_UNTIL = "emergency_pass_until"
        const val KEY_EMERGENCY_PASS_DATE = "emergency_pass_date"
        const val KEY_EMERGENCY_PASSES_USED = "emergency_passes_used"

        var isServiceRunning = false
    }

    private var windowManager: WindowManager? = null
    private var isOverlayAttached = false
    private var currentOverlayView: View? = null
    private var currentBlockedPackage: String? = null
    private var breatheAnimator: ValueAnimator? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onServiceConnected() {
        super.onServiceConnected()
        isServiceRunning = true
        windowManager = getSystemService(Context.WINDOW_SERVICE) as? WindowManager
    }

    override fun onDestroy() {
        super.onDestroy()
        isServiceRunning = false
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
            // If the user actually brought Momentum's MainActivity to the foreground, dismiss overlay
            if (className.contains("MainActivity")) {
                removeOverlay()
            }
            // CRITICAL: Any other window event from our package (such as our overlay FrameLayout itself)
            // MUST be ignored. Otherwise, adding our overlay triggers this event, which would remove the overlay
            // in an endless rapid loop creating surfaces continuously!
            return
        }

        // Case 2: Transient system UI elements (status bar, keyboard, toasts)
        if (pkgName == "com.android.systemui" ||
            className.contains("InputMethod") ||
            className.contains("Toast")) {
            // Keep current overlay state intact
            return
        }

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isDndActive = prefs.getBoolean(KEY_IS_DND_ACTIVE, false)
        val emergencyUntil = prefs.getLong(KEY_EMERGENCY_PASS_UNTIL, 0L)
        val now = System.currentTimeMillis()

        // If DND is inactive or emergency pass is running, dismiss overlay if present
        if (!isDndActive || now < emergencyUntil) {
            removeOverlay()
            return
        }

        val blockedSet = prefs.getStringSet(KEY_BLOCKED_PACKAGES, emptySet()) ?: emptySet()

        if (blockedSet.contains(pkgName)) {
            // Blocked app is in foreground!
            // If overlay is already attached for this package, do NOT recreate or re-add
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

                // Bind UI elements
                val tvAppName = overlayView.findViewById<TextView>(R.id.tv_friction_app_name)
                val tvTaskTitle = overlayView.findViewById<TextView>(R.id.tv_task_title)
                val tvRemainingTime = overlayView.findViewById<TextView>(R.id.tv_remaining_time)
                val tvBreathePrompt = overlayView.findViewById<TextView>(R.id.tv_breathe_prompt)
                val viewBreatheRing = overlayView.findViewById<View>(R.id.view_breathe_ring)
                val btnReturnHome = overlayView.findViewById<View>(R.id.btn_return_home)
                val btnEmergencyPass = overlayView.findViewById<View>(R.id.btn_emergency_pass)
                val tvPassCount = overlayView.findViewById<TextView>(R.id.tv_pass_count)

                tvAppName?.text = "Shielded: $appName"
                tvTaskTitle?.text = taskName

                if (taskEndTime > System.currentTimeMillis()) {
                    val diffMins = ((taskEndTime - System.currentTimeMillis()) / (1000 * 60)).toInt()
                    val hrs = diffMins / 60
                    val mins = diffMins % 60
                    tvRemainingTime?.text = if (hrs > 0) "${hrs}h ${mins}m left" else "${mins}m left"
                } else {
                    tvRemainingTime?.text = "Session active"
                }

                tvPassCount?.text = "$remainingPasses left"

                // Breathing animation
                breatheAnimator?.cancel()
                breatheAnimator = ValueAnimator.ofFloat(1.0f, 1.22f).apply {
                    duration = 3200
                    repeatCount = ValueAnimator.INFINITE
                    repeatMode = ValueAnimator.REVERSE
                    addUpdateListener { animator ->
                        val value = animator.animatedValue as Float
                        viewBreatheRing?.scaleX = value
                        viewBreatheRing?.scaleY = value

                        val fraction = animator.animatedFraction
                        if (fraction < 0.5f) {
                            tvBreathePrompt?.text = "Breathe in..."
                        } else {
                            tvBreathePrompt?.text = "Breathe out..."
                        }
                    }
                    start()
                }

                // Return to Home action
                btnReturnHome?.setOnClickListener {
                    removeOverlay()
                    performGlobalAction(GLOBAL_ACTION_HOME)
                }

                // Emergency Pass action
                btnEmergencyPass?.setOnClickListener {
                    val passesLeft = getRemainingPasses(prefs)
                    if (passesLeft > 0) {
                        val used = prefs.getInt(KEY_EMERGENCY_PASSES_USED, 0)
                        val passUntil = System.currentTimeMillis() + (5 * 60 * 1000L)
                        prefs.edit()
                            .putInt(KEY_EMERGENCY_PASSES_USED, used + 1)
                            .putLong(KEY_EMERGENCY_PASS_UNTIL, passUntil)
                            .apply()
                        removeOverlay()
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

    private fun removeOverlay() {
        mainHandler.post {
            removeOverlayInternal()
        }
    }

    private fun removeOverlayInternal() {
        try {
            breatheAnimator?.cancel()
            breatheAnimator = null
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
            return 2
        }
        val used = prefs.getInt(KEY_EMERGENCY_PASSES_USED, 0)
        val remaining = 2 - used
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

    override fun onInterrupt() {
        removeOverlay()
    }
}
