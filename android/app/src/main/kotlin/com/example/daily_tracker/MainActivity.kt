package com.example.daily_tracker

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "com.example.daily_tracker/focus_blocker"
    }

    private var methodChannel: MethodChannel? = null
    private val backgroundExecutor = Executors.newSingleThreadExecutor()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WidgetRefreshWorker.schedule(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                val prefs = getSharedPreferences(FocusBlockerService.PREFS_NAME, Context.MODE_PRIVATE)
                when (call.method) {
                    "isAccessibilityGranted" -> {
                        result.success(isAccessibilityServiceEnabled(this@MainActivity, FocusBlockerService::class.java))
                    }
                    "openAccessibilitySettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SETTINGS_ERROR", e.localizedMessage, null)
                        }
                    }
                    "updateBlockedApps" -> {
                        val packages = call.argument<List<String>>("packages") ?: emptyList()
                        prefs.edit().putStringSet(FocusBlockerService.KEY_BLOCKED_PACKAGES, packages.toSet()).apply()
                        result.success(true)
                    }
                    "setFocusState" -> {
                        val isActive = call.argument<Boolean>("isActive") ?: false
                        val taskName = call.argument<String>("taskName") ?: "Focus Task"
                        val endTimeMs = call.argument<Long>("endTimeMs") ?: 0L

                        prefs.edit()
                            .putBoolean(FocusBlockerService.KEY_IS_DND_ACTIVE, isActive)
                            .putString(FocusBlockerService.KEY_ACTIVE_TASK_NAME, taskName)
                            .putLong(FocusBlockerService.KEY_ACTIVE_TASK_END_TIME, endTimeMs)
                            .apply()
                        result.success(true)
                    }
                    "useEmergencyPass" -> {
                        val minutes = call.argument<Int>("minutes") ?: 5
                        val targetPackage = call.argument<String>("targetPackage")
                        val passUntil = System.currentTimeMillis() + (minutes * 60 * 1000L)

                        val used = prefs.getInt(FocusBlockerService.KEY_EMERGENCY_PASSES_USED, 0)
                        prefs.edit()
                            .putInt(FocusBlockerService.KEY_EMERGENCY_PASSES_USED, used + 1)
                            .putLong(FocusBlockerService.KEY_EMERGENCY_PASS_UNTIL, passUntil)
                            .apply()

                        if (!targetPackage.isNullOrBlank()) {
                            try {
                                val launchIntent = packageManager.getLaunchIntentForPackage(targetPackage)
                                if (launchIntent != null) {
                                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    startActivity(launchIntent)
                                }
                            } catch (_: Exception) { }
                        }
                        result.success(passUntil)
                    }
                    "getEmergencyPassUntil" -> {
                        result.success(prefs.getLong(FocusBlockerService.KEY_EMERGENCY_PASS_UNTIL, 0L))
                    }
                    "getRemainingPasses" -> {
                        result.success(getRemainingEmergencyPasses(prefs))
                    }
                    "getInstalledApps" -> {
                        backgroundExecutor.execute {
                            try {
                                val apps = queryInstalledApps()
                                runOnUiThread { result.success(apps) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("QUERY_ERROR", e.localizedMessage, null) }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun getRemainingEmergencyPasses(prefs: SharedPreferences): Int {
        val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        val savedDate = prefs.getString(FocusBlockerService.KEY_EMERGENCY_PASS_DATE, "") ?: ""
        if (savedDate != todayStr) {
            prefs.edit()
                .putString(FocusBlockerService.KEY_EMERGENCY_PASS_DATE, todayStr)
                .putInt(FocusBlockerService.KEY_EMERGENCY_PASSES_USED, 0)
                .apply()
            return 2
        }
        val used = prefs.getInt(FocusBlockerService.KEY_EMERGENCY_PASSES_USED, 0)
        val remaining = 2 - used
        return if (remaining < 0) 0 else remaining
    }

    private fun queryInstalledApps(): List<Map<String, Any>> {
        val pm = packageManager
        val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }

        val resolveInfos = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentActivities(mainIntent, PackageManager.ResolveInfoFlags.of(0L))
        } else {
            @Suppress("DEPRECATION")
            pm.queryIntentActivities(mainIntent, 0)
        }

        val resultList = mutableListOf<Map<String, Any>>()
        val seenPackages = mutableSetOf<String>()

        for (resolveInfo in resolveInfos) {
            val pkg = resolveInfo.activityInfo.packageName ?: continue
            if (pkg == packageName || seenPackages.contains(pkg)) {
                continue
            }
            seenPackages.add(pkg)

            val appName = resolveInfo.loadLabel(pm).toString()
            val drawable = resolveInfo.loadIcon(pm)
            val iconBytes = drawableToByteArray(drawable)

            val category = resolveCategory(resolveInfo.activityInfo.applicationInfo, pkg)

            val map = HashMap<String, Any>()
            map["name"] = appName
            map["packageName"] = pkg
            map["icon"] = iconBytes
            map["category"] = category
            resultList.add(map)
        }

        resultList.sortBy { (it["name"] as? String)?.lowercase() ?: "" }
        return resultList
    }

    private fun resolveCategory(appInfo: ApplicationInfo, pkg: String): String {
        val lowerPkg = pkg.lowercase()

        // Explicit heuristics for popular apps
        if (lowerPkg.contains("instagram") || lowerPkg.contains("tiktok") ||
            lowerPkg.contains("facebook") || lowerPkg.contains("twitter") ||
            lowerPkg.contains("snapchat") || lowerPkg.contains("reddit") ||
            lowerPkg.contains("threads") || lowerPkg.contains("pinterest") ||
            lowerPkg.contains("tumblr") || lowerPkg.contains("linkedin")) {
            return "social"
        }

        if (lowerPkg.contains("youtube") || lowerPkg.contains("netflix") ||
            lowerPkg.contains("spotify") || lowerPkg.contains("twitch") ||
            lowerPkg.contains("disney") || lowerPkg.contains("primevideo") ||
            lowerPkg.contains("hulu") || lowerPkg.contains("vimeo") ||
            lowerPkg.contains("soundcloud") || lowerPkg.contains("crunchyroll")) {
            return "entertainment"
        }

        if (lowerPkg.contains("whatsapp") || lowerPkg.contains("telegram") ||
            lowerPkg.contains("discord") || lowerPkg.contains("messenger") ||
            lowerPkg.contains("signal")) {
            return "messaging"
        }

        // Android System ApplicationInfo Category flag
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            when (appInfo.category) {
                ApplicationInfo.CATEGORY_GAME -> return "game"
                ApplicationInfo.CATEGORY_SOCIAL -> return "social"
                ApplicationInfo.CATEGORY_VIDEO, ApplicationInfo.CATEGORY_AUDIO -> return "entertainment"
                ApplicationInfo.CATEGORY_PRODUCTIVITY -> return "productivity"
            }
        }

        @Suppress("DEPRECATION")
        if ((appInfo.flags and ApplicationInfo.FLAG_IS_GAME) != 0) {
            return "game"
        }

        return "other"
    }

    private fun drawableToByteArray(drawable: Drawable): ByteArray {
        val bitmap: Bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            val bm = drawable.bitmap
            if (bm.width > 96 || bm.height > 96) {
                Bitmap.createScaledBitmap(bm, 96, 96, true)
            } else {
                bm
            }
        } else {
            val width = if (drawable.intrinsicWidth in 1..96) drawable.intrinsicWidth else 96
            val height = if (drawable.intrinsicHeight in 1..96) drawable.intrinsicHeight else 96
            val bm = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bm)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            bm
        }

        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 85, stream)
        return stream.toByteArray()
    }

    private fun isAccessibilityServiceEnabled(context: Context, service: Class<out AccessibilityService>): Boolean {
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServices)
        val myServiceName = ComponentName(context, service).flattenToString()
        val shortServiceName = ComponentName(context, service).flattenToShortString()

        while (colonSplitter.hasNext()) {
            val componentName = colonSplitter.next()
            if (componentName.equals(myServiceName, ignoreCase = true) ||
                componentName.equals(shortServiceName, ignoreCase = true)) {
                return true
            }
        }
        return false
    }
}
