package com.budgetsense.budgetsense

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

/** Next-due widget: the soonest recurring payment or EMI, its amount, and a
 *  short "due in N days" / "Overdue" read. */
class NextDueWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_next_due)
            views.setTextViewText(
                R.id.next_due_name,
                WidgetSupport.value(context, "nextDueName", "Nothing due"),
            )
            views.setTextViewText(
                R.id.next_due_amount,
                WidgetSupport.value(context, "nextDueAmount", ""),
            )
            views.setTextViewText(
                R.id.next_due_when,
                WidgetSupport.value(context, "nextDueWhen", ""),
            )
            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetSupport.openAppIntent(context),
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
