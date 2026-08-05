package com.budgetsense.budgetsense

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

/** A quiet 2x1 widget: the month and this month's balance, with a short note. */
class BalanceWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_balance)
            views.setTextViewText(
                R.id.month_label,
                WidgetSupport.value(context, "monthLabel", "This month"),
            )
            views.setTextViewText(
                R.id.balance_value,
                WidgetSupport.value(context, "balance"),
            )
            views.setTextViewText(
                R.id.balance_note,
                WidgetSupport.value(context, "balanceNote", ""),
            )
            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetSupport.openAppIntent(context),
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
