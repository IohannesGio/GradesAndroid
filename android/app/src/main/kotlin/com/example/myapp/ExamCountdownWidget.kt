package com.school.grades

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

class ExamCountdownWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val examName = prefs.getString("flutter.widget_exam_name", null)
            val examDays = prefs.getString("flutter.widget_exam_days", null)
            val examDate = prefs.getString("flutter.widget_exam_date", null)
            val examCfu = prefs.getString("flutter.widget_exam_cfu", null)

            val views = RemoteViews(context.packageName, R.layout.exam_countdown_widget)

            if (!examName.isNullOrEmpty() && !examDays.isNullOrEmpty()) {
                views.setTextViewText(R.id.widget_title, examName)
                views.setTextViewText(R.id.widget_countdown, examDays)
                views.setTextViewText(R.id.widget_date, examDate ?: "")
                views.setTextViewText(R.id.widget_cfu, if (!examCfu.isNullOrEmpty()) "$examCfu CFU" else "")
                views.setViewVisibility(R.id.widget_content_layout, View.VISIBLE)
                views.setViewVisibility(R.id.widget_empty_layout, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_content_layout, View.GONE)
                views.setViewVisibility(R.id.widget_empty_layout, View.VISIBLE)
            }

            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
