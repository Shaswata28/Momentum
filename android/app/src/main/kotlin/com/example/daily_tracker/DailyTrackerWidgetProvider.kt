package com.example.daily_tracker

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class DailyTrackerWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val currentTaskId = widgetData.getString("current_task_id", "") ?: ""
        val headlineTitle = widgetData.getString("headline_title", "No Active Tasks") ?: "No Active Tasks"
        val nextTaskTitle = widgetData.getString("next_task_title", "No upcoming task") ?: "No upcoming task"
        val nextTaskTime = widgetData.getString("next_task_time", "--:--") ?: "--:--"
        val progressText = widgetData.getString("progress_text", "0 / 0 done") ?: "0 / 0 done"
        val theme = WidgetTheme.fromMode(widgetData.getString("theme_mode", "system"))
        val layout = if (theme.primary == null) R.layout.widget_layout_system else R.layout.widget_layout

        val taskStartMillis = try {
            widgetData.getString("task_start_millis", null)?.toLongOrNull()
                ?: widgetData.getLong("task_start_millis", 0L)
        } catch (_: Exception) {
            try { widgetData.getInt("task_start_millis", 0).toLong() } catch (_: Exception) { 0L }
        }

        val taskEndMillis = try {
            widgetData.getString("task_end_millis", null)?.toLongOrNull()
                ?: widgetData.getLong("task_end_millis", 0L)
        } catch (_: Exception) {
            try { widgetData.getInt("task_end_millis", 0).toLong() } catch (_: Exception) { 0L }
        }

        val now = System.currentTimeMillis()

        var progressPercent = try {
            widgetData.getInt("progress_percent", 0)
        } catch (_: Exception) {
            try { widgetData.getLong("progress_percent", 0L).toInt() } catch (_: Exception) { 0 }
        }
        var headlineLabel = widgetData.getString("headline_label", "CURRENT") ?: "CURRENT"

        val isTaskActive = currentTaskId.isNotEmpty() &&
                taskStartMillis > 0L &&
                taskEndMillis > taskStartMillis &&
                now in taskStartMillis..taskEndMillis

        if (isTaskActive) {
            val total = taskEndMillis - taskStartMillis
            val elapsed = now - taskStartMillis
            progressPercent = if (total > 0) ((elapsed * 100L) / total).toInt().coerceIn(0, 100) else 0
            val remainingMins = ((taskEndMillis - now) / 60000L).toInt().coerceAtLeast(0)
            headlineLabel = if (remainingMins > 0) "CURRENT · ${remainingMins}m left" else "CURRENT · Ending"

            // Arm alarm for the next 1-minute live tick
            scheduleNextMinuteUpdate(context)
        } else {
            cancelMinuteUpdates(context)
        }

        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, layout).apply {
                    theme.applyTo(this)
                    setTextViewText(R.id.tv_headline_label, theme.text(headlineLabel))
                    setTextViewText(R.id.tv_headline_title, theme.text(headlineTitle))
                    setTextViewText(R.id.tv_next_label, theme.text("NEXT"))
                    setTextViewText(R.id.tv_next_task_title, theme.text(nextTaskTitle))
                    setTextViewText(R.id.tv_next_task_time, theme.text(nextTaskTime))
                    setTextViewText(R.id.tv_total_progress, theme.text(progressText))
                    // Image levels drive the clip drawable on all supported Android versions.
                    val progress = progressPercent.coerceIn(0, 100)
                    setInt(R.id.progress_current, "setImageLevel", progress * 100)
                    setContentDescription(R.id.progress_current, "$progress% of current task elapsed")

                    val rootIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                    setOnClickPendingIntent(R.id.widget_root, rootIntent)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun scheduleNextMinuteUpdate(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(context, DailyTrackerWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, DailyTrackerWidgetProvider::class.java))
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        val flags = if (Build.VERSION.SDK_INT >= 23) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getBroadcast(context, 7777, intent, flags)

        val nextMinute = System.currentTimeMillis() + 60_000L
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC, nextMinute, pendingIntent)
            } else {
                alarmManager.setExact(AlarmManager.RTC, nextMinute, pendingIntent)
            }
        } catch (_: Exception) {
            alarmManager.set(AlarmManager.RTC, nextMinute, pendingIntent)
        }
    }

    private fun cancelMinuteUpdates(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(context, DailyTrackerWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        }
        val flags = if (Build.VERSION.SDK_INT >= 23) {
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_NO_CREATE
        }
        val pendingIntent = PendingIntent.getBroadcast(context, 7777, intent, flags)
        if (pendingIntent != null) {
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
    }
}
