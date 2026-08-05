package com.budgetsense.budgetsense

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews

/**
 * The insights widget: a compact income-vs-expenses card that expands to show
 * savings rate, invested rate, average daily spend and projected balance when
 * the user makes it taller.
 */
class InsightsWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) render(context, appWidgetManager, id)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        render(context, appWidgetManager, appWidgetId)
    }

    private fun render(context: Context, manager: AppWidgetManager, id: Int) {
        val views = RemoteViews(context.packageName, R.layout.widget_insights)

        views.setTextViewText(
            R.id.month_label,
            WidgetSupport.value(context, "monthLabel", "This month"),
        )
        views.setTextViewText(R.id.income_value, WidgetSupport.value(context, "income"))
        views.setTextViewText(R.id.expenses_value, WidgetSupport.value(context, "spend"))
        views.setTextViewText(
            R.id.savings_rate_value,
            WidgetSupport.value(context, "savingsRate"),
        )
        views.setTextViewText(
            R.id.invest_rate_value,
            WidgetSupport.value(context, "investmentRate"),
        )
        views.setTextViewText(
            R.id.avg_daily_value,
            WidgetSupport.value(context, "avgDailySpend"),
        )
        views.setTextViewText(
            R.id.projected_value,
            WidgetSupport.value(context, "projectedBalance"),
        )

        val options = manager.getAppWidgetOptions(id)
        val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        views.setViewVisibility(
            R.id.section_more,
            if (minHeight >= 170) View.VISIBLE else View.GONE,
        )

        views.setOnClickPendingIntent(
            R.id.widget_root,
            WidgetSupport.openAppIntent(context),
        )

        manager.updateAppWidget(id, views)
    }
}
