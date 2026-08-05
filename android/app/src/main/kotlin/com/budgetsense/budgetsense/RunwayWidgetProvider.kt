package com.budgetsense.budgetsense

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

/** Runway widget: average daily spend plus a one-line "where the month is
 *  heading" read built from the projected balance. */
class RunwayWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_runway)
            views.setTextViewText(
                R.id.avg_daily_value,
                WidgetSupport.value(context, "avgDailySpend"),
            )
            views.setTextViewText(
                R.id.runway_note,
                WidgetSupport.value(context, "runwayNote", ""),
            )
            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetSupport.openAppIntent(context),
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
