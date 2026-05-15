package com.example.daily_tracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class DailyTrackerWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                    val headlineTitle = widgetData.getString("headline_title", "No Active Tasks")
                    val nextTaskTitle = widgetData.getString("next_task_title", "No upcoming task")
                    val nextTaskTime = widgetData.getString("next_task_time", "--:--")
                    val progressText = widgetData.getString("progress_text", "0 / 0 done")
                    val progressPercent = widgetData.getInt("progress_percent", 0)
                    val currentTaskId = widgetData.getString("current_task_id", "")

                    setTextViewText(R.id.tv_headline_title, headlineTitle)
                    setTextViewText(R.id.tv_next_task_title, nextTaskTitle)
                    setTextViewText(R.id.tv_next_task_time, nextTaskTime)
                    setTextViewText(R.id.tv_total_progress, progressText)
                    setProgressBar(R.id.progress_current, 100, progressPercent, false)

                    val rootIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                    setOnClickPendingIntent(R.id.widget_root, rootIntent)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
