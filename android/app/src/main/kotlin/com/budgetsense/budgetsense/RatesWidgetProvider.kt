package com.budgetsense.budgetsense

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

/** Rates widget: savings and invested rates as two labelled bars. */
class RatesWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_rates)
            views.setTextViewText(
                R.id.month_label,
                WidgetSupport.value(context, "monthLabel", "This month"),
            )
            views.setTextViewText(
                R.id.savings_rate_value,
                WidgetSupport.value(context, "savingsRate"),
            )
            views.setTextViewText(
                R.id.invest_rate_value,
                WidgetSupport.value(context, "investmentRate"),
            )
            val savings =
                WidgetSupport.value(context, "savingsRateNum", "0").toIntOrNull() ?: 0
            val invest =
                WidgetSupport.value(context, "investmentRateNum", "0").toIntOrNull() ?: 0
            views.setProgressBar(R.id.savings_bar, 100, savings.coerceIn(0, 100), false)
            views.setProgressBar(R.id.invest_bar, 100, invest.coerceIn(0, 100), false)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetSupport.openAppIntent(context),
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
