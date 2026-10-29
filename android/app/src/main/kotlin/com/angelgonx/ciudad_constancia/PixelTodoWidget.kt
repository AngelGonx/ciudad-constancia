package com.angelgonx.ciudad_constancia

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Widget de pantalla de inicio de Pixel To-Do.
 *
 * Los datos los escribe la app (lib/services/home_widget_sync.dart). Tocar un pendiente
 * manda "pixeltodo://complete?id=..." a Dart en segundo plano, que lo completa y vuelve
 * a dibujar el widget. Tocar el encabezado abre la app.
 */
class PixelTodoWidget : HomeWidgetProvider() {

    private val rows = intArrayOf(R.id.row_0, R.id.row_1, R.id.row_2, R.id.row_3, R.id.row_4)
    private val checks = intArrayOf(R.id.check_0, R.id.check_1, R.id.check_2, R.id.check_3, R.id.check_4)
    private val titles = intArrayOf(R.id.title_0, R.id.title_1, R.id.title_2, R.id.title_3, R.id.title_4)
    private val metas = intArrayOf(R.id.meta_0, R.id.meta_1, R.id.meta_2, R.id.meta_3, R.id.meta_4)

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        // Si los datos son de otro día, los hábitos vuelven a estar pendientes.
        val stale = widgetData.getString("day", "") != today
        val count = widgetData.getInt("count", 0).coerceIn(0, rows.size)

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.pixel_todo_widget)

            widgetData.getString("title", null)?.let { views.setTextViewText(R.id.widget_title, it) }
            views.setTextViewText(R.id.widget_subtitle, widgetData.getString("subtitle", ""))
            views.setTextViewText(
                R.id.widget_footer,
                widgetData.getString(if (stale) "footer_stale" else "footer", ""),
            )
            views.setOnClickPendingIntent(
                R.id.widget_header,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )

            for (i in rows.indices) {
                if (i >= count) {
                    views.setViewVisibility(rows[i], View.GONE)
                    continue
                }
                val habit = widgetData.getBoolean("task_${i}_habit", false)
                var done = widgetData.getBoolean("task_${i}_done", false)
                if (stale && habit) done = false
                val id = widgetData.getString("task_${i}_id", "") ?: ""

                views.setViewVisibility(rows[i], View.VISIBLE)
                views.setTextViewText(titles[i], widgetData.getString("task_${i}_title", ""))
                views.setTextViewText(metas[i], if (done) "" else widgetData.getString("task_${i}_meta", ""))
                views.setImageViewResource(
                    checks[i],
                    if (done) R.drawable.widget_check_on else R.drawable.widget_check_off,
                )
                views.setInt(
                    rows[i],
                    "setBackgroundResource",
                    if (done) R.drawable.widget_row_done else R.drawable.widget_row,
                )
                views.setTextColor(titles[i], if (done) 0xFF8A7A96.toInt() else 0xFFF3E9D6.toInt())

                val uri = Uri.parse("pixeltodo://complete?id=" + Uri.encode(id))
                views.setOnClickPendingIntent(rows[i], HomeWidgetBackgroundIntent.getBroadcast(context, uri))
            }

            views.setViewVisibility(R.id.widget_empty, if (count == 0) View.VISIBLE else View.GONE)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
