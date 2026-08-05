package com.budgetsense.budgetsense

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews

/**
 * The dashboard summary widget: balance, income, spend and invested for the
 * current month. When the user makes it tall enough, the "Where it went"
 * breakdown reveals itself.
 */
class DashboardWidgetProvider : AppWidgetProvider() {

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
        bindCategoryRow(context, views, 1, R.id.cat_row1, R.id.cat_label1, R.id.cat_value1)
        bindCategoryRow(context, views, 2, R.id.cat_row2, R.id.cat_label2, R.id.cat_value2)
        bindCategoryRow(context, views, 3, R.id.cat_row3, R.id.cat_label3, R.id.cat_value3)
        bindCategoryRow(context, views, 4, R.id.cat_row4, R.id.cat_label4, R.id.cat_value4)

        // Reveal the breakdown once the widget is tall enough for it.
        val options = manager.getAppWidgetOptions(id)
        val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        views.setViewVisibility(
            R.id.section_breakdown,
            if (minHeight >= 180) View.VISIBLE else View.GONE,
        )

        views.setOnClickPendingIntent(
            R.id.widget_root,
            WidgetSupport.openAppIntent(context),
        )

        manager.updateAppWidget(id, views)
    }

    private fun bindCategoryRow(
        context: Context,
        views: RemoteViews,
        n: Int,
        rowId: Int,
        labelId: Int,
        valueId: Int,
    ) {
        val label = WidgetSupport.value(context, "cat${n}Label", "")
        if (label.isBlank()) {
            views.setViewVisibility(rowId, View.GONE)
            return
        }
        views.setViewVisibility(rowId, View.VISIBLE)
        views.setTextViewText(labelId, label)
        views.setTextViewText(valueId, WidgetSupport.value(context, "cat${n}Value"))
    }
}
