package com.budgetsense.budgetsense

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

/** "This month at a glance": how many expenses, the average size, and the
 *  single biggest one. */
class GlanceWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_glance)
            views.setTextViewText(
                R.id.month_label,
                WidgetSupport.value(context, "monthLabel", "This month"),
            )
            views.setTextViewText(
                R.id.count_value,
                WidgetSupport.value(context, "expenseCount", "0"),
            )
            views.setTextViewText(
                R.id.average_value,
                WidgetSupport.value(context, "expenseAverage"),
            )
            views.setTextViewText(
                R.id.biggest_name,
                WidgetSupport.value(context, "biggestName", "None yet"),
            )
            views.setTextViewText(
                R.id.biggest_amount,
                WidgetSupport.value(context, "biggestAmount", ""),
            )
            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetSupport.openAppIntent(context),
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
