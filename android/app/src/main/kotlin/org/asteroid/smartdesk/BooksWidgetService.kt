package org.asteroid.smartdesk

import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

class BooksWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return BooksWidgetFactory(this.applicationContext)
    }
}

class BooksWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var books = JSONArray()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val widgetData = HomeWidgetPlugin.getData(context)
        val booksJson = widgetData.getString("books_data", "[]")
        try {
            books = JSONArray(booksJson)
        } catch (e: Exception) {
            books = JSONArray()
        }
    }

    override fun onDestroy() {}

    override fun getCount(): Int = books.length()

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_book_item)
        try {
            val book = books.getJSONObject(position)
            views.setTextViewText(R.id.item_title, book.optString("title", "—"))
            views.setTextViewText(R.id.item_subtitle, book.optString("subtitle", ""))
            
            val badgeStr = book.optString("badge", "")
            if (badgeStr.isNotEmpty()) {
                views.setViewVisibility(R.id.item_badge, View.VISIBLE)
                views.setTextViewText(R.id.item_badge, badgeStr)
            } else {
                views.setViewVisibility(R.id.item_badge, View.GONE)
            }
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
