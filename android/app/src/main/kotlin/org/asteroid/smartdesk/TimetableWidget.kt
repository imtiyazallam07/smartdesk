package org.asteroid.smartdesk

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class TimetableWidget : AppWidgetProvider() {

    companion object {
        const val ACTION_MIDNIGHT_REFRESH = "org.asteroid.smartdesk.ACTION_MIDNIGHT_REFRESH"

        fun updateTimetableWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_timetable)

                val serviceIntent = Intent(context, TimetableWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                }
                views.setRemoteAdapter(R.id.widget_list, serviceIntent)
                views.setEmptyView(R.id.widget_list, R.id.widget_empty)

                val openPendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("smartdesk://timetable")
                )

                views.setPendingIntentTemplate(R.id.widget_list, openPendingIntent)
                views.setOnClickPendingIntent(R.id.btn_open_app, openPendingIntent)

                appWidgetManager.updateAppWidget(appWidgetId, views)
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_list)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        fun scheduleMidnightAlarm(context: Context) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

                val intent = Intent(context, TimetableWidget::class.java).apply {
                    action = ACTION_MIDNIGHT_REFRESH
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context, 100, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                // Schedule for 12:02 AM tomorrow
                val calendar = java.util.Calendar.getInstance().apply {
                    add(java.util.Calendar.DAY_OF_YEAR, 1)
                    set(java.util.Calendar.HOUR_OF_DAY, 0)
                    set(java.util.Calendar.MINUTE, 2)
                    set(java.util.Calendar.SECOND, 0)
                    set(java.util.Calendar.MILLISECOND, 0)
                }

                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pendingIntent
                )
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateTimetableWidget(context, appWidgetManager, appWidgetId)
        }
        // Always reschedule the midnight alarm when the widget updates
        scheduleMidnightAlarm(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_MIDNIGHT_REFRESH) {
            // Midnight hit — force refresh all timetable widget instances
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, TimetableWidget::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            for (id in appWidgetIds) {
                updateTimetableWidget(context, appWidgetManager, id)
            }
            // Re-schedule for the next midnight
            scheduleMidnightAlarm(context)
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        // When the first widget instance is placed, start the midnight alarm
        scheduleMidnightAlarm(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        // When the last widget instance is removed, cancel the alarm
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, TimetableWidget::class.java).apply {
                action = ACTION_MIDNIGHT_REFRESH
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context, 100, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
