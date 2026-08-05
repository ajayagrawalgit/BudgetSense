package com.budgetsense.budgetsense

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews

/**
 * "Where it went": the month's top spending categories as calm bars, each scaled
 * relative to the biggest. Rows are fully dynamic (cat1..cat4) and filled from
 * whatever categories the user has created; empty rows are hidden. Nothing here
 * names or assumes any specific category.
 */
class BucketsWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_buckets)
            views.setTextViewText(
                R.id.month_label,
                WidgetSupport.value(context, "monthLabel", "This month"),
            )
            for (i in ROWS.indices) bind(context, views, i)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetSupport.openAppIntent(context),
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun bind(context: Context, views: RemoteViews, index: Int) {
        val n = index + 1
        val row = ROWS[index]
        val label = WidgetSupport.value(context, "cat${n}Label", "")
        if (label.isBlank()) {
            views.setViewVisibility(row.container, View.GONE)
            return
        }
        views.setViewVisibility(row.container, View.VISIBLE)
        views.setTextViewText(row.label, label)
        views.setTextViewText(row.value, WidgetSupport.value(context, "cat${n}Value"))
        // Percentages are masked to non-numeric when app-lock is on, so a failed
        // parse collapses the bar to zero, hiding the spend shape too.
        val pct = WidgetSupport.value(context, "cat${n}Pct", "0").toIntOrNull() ?: 0
        views.setProgressBar(row.bar, 100, pct.coerceIn(0, 100), false)
    }

    private data class Row(val container: Int, val label: Int, val value: Int, val bar: Int)

    companion object {
        private val ROWS = listOf(
            Row(R.id.cat_row1, R.id.cat_label1, R.id.cat_value1, R.id.cat_bar1),
            Row(R.id.cat_row2, R.id.cat_label2, R.id.cat_value2, R.id.cat_bar2),
            Row(R.id.cat_row3, R.id.cat_label3, R.id.cat_value3, R.id.cat_bar3),
            Row(R.id.cat_row4, R.id.cat_label4, R.id.cat_value4, R.id.cat_bar4),
        )
    }
}
