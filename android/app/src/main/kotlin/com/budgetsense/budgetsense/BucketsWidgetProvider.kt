package com.budgetsense.budgetsense

import android.content.Context
import android.widget.RemoteViews

/**
 * "Where it went": the month's top spending categories as calm bars, each
 * scaled relative to the biggest.
 */
class BucketsWidgetProvider : SimpleWidgetProvider(R.layout.widget_buckets) {
    override val textBindings = listOf(
        TextBinding(R.id.month_label, "monthLabel", "This month"),
    )

    override fun onBind(context: Context, views: RemoteViews) {
        CategoryRows.bindAll(context, views, withBars = true)
    }
}
