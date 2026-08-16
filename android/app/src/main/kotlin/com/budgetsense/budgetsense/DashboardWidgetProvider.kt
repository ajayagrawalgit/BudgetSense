package com.budgetsense.budgetsense

import android.appwidget.AppWidgetManager
import android.content.Context
import android.view.View
import android.widget.RemoteViews

/**
 * The dashboard summary widget: balance, income, spend and invested for the
 * current month. When the user makes it tall enough, the "Where it went"
 * breakdown reveals itself.
 */
class DashboardWidgetProvider : ResizableWidgetProvider() {

    override fun render(context: Context, manager: AppWidgetManager, id: Int) {
        val views = RemoteViews(context.packageName, R.layout.widget_dashboard)

        views.setTextViewText(
            R.id.month_label,
            WidgetSupport.value(context, "monthLabel", "This month"),
        )
        views.setTextViewText(R.id.balance_value, WidgetSupport.value(context, "balance"))
        views.setTextViewText(R.id.income_value, WidgetSupport.value(context, "income"))
        views.setTextViewText(R.id.spend_value, WidgetSupport.value(context, "spend"))
        views.setTextViewText(R.id.invested_value, WidgetSupport.value(context, "invested"))

        // "Where it went" is fully dynamic: the top spending categories, by name,
        // whatever the user created. Empty rows are hidden.
        CategoryRows.bindAll(context, views, withBars = false)

        // Reveal the breakdown once the widget is tall enough for it.
        views.setViewVisibility(
            R.id.section_breakdown,
            if (minHeightDp(manager, id) >= 180) View.VISIBLE else View.GONE,
        )

        views.setOnClickPendingIntent(
            R.id.widget_root,
            WidgetSupport.openAppIntent(context),
        )

        manager.updateAppWidget(id, views)
    }
}
