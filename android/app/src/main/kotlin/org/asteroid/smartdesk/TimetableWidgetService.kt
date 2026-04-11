package org.asteroid.smartdesk

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

class TimetableWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return TimetableWidgetFactory(this.applicationContext)
    }
}

class TimetableWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var slots = JSONArray()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val widgetData = HomeWidgetPlugin.getData(context)
        val allSlotsJson = widgetData.getString("timetable_slots_all", "{}")
        
        val calendar = java.util.Calendar.getInstance()
        val dayOfWeek = calendar.get(java.util.Calendar.DAY_OF_WEEK)
        // Convert Android DAY_OF_WEEK (Sun=1, Mon=2...) to Dart DateTime weekday (Mon=1, Sun=7)
        val dartWeekday = if (dayOfWeek == java.util.Calendar.SUNDAY) 7 else dayOfWeek - 1

        try {
            val allSlotsObj = org.json.JSONObject(allSlotsJson)
            val slotsArray = allSlotsObj.optJSONArray(dartWeekday.toString())
            slots = slotsArray ?: org.json.JSONArray()
        } catch (e: Exception) {
            
            // Fallback to legacy single-day string if map parsing fails
            val slotsJson = widgetData.getString("timetable_slots", "[]")
            try {
                slots = org.json.JSONArray(slotsJson)
            } catch (ex: Exception) {
                slots = org.json.JSONArray()
            }
        }
    }

    override fun onDestroy() {}

    override fun getCount(): Int = slots.length()

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_slot_item)
        try {
            val slot = slots.getJSONObject(position)
            views.setTextViewText(R.id.item_title, slot.optString("subject", "—"))
            views.setTextViewText(R.id.item_subtitle, slot.optString("time", ""))
        } catch (e: Exception) {
            e.printStackTrace()
        }
        val fillInIntent = Intent()
        views.setOnClickFillInIntent(R.id.item_row, fillInIntent)
        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
