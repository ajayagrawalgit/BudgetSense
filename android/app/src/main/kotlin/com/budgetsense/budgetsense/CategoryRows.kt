package com.budgetsense.budgetsense

import android.content.Context
import android.view.View
import android.widget.RemoteViews

/**
 * The "where it went" category rows, shared by the dashboard and buckets
 * widgets. Both layouts use the same cat_row/cat_label/cat_value ids; only the
 * buckets layout adds a cat_bar, so bars are opt-in.
 *
 * Rows are fully dynamic and filled from whatever categories the user created.
 * Nothing here names or assumes any specific category. A row with no label is
 * hidden rather than left blank.
 */
internal object CategoryRows {

    private data class Row(val container: Int, val label: Int, val value: Int, val bar: Int)

    private val rows = listOf(
        Row(R.id.cat_row1, R.id.cat_label1, R.id.cat_value1, R.id.cat_bar1),
        Row(R.id.cat_row2, R.id.cat_label2, R.id.cat_value2, R.id.cat_bar2),
        Row(R.id.cat_row3, R.id.cat_label3, R.id.cat_value3, R.id.cat_bar3),
        Row(R.id.cat_row4, R.id.cat_label4, R.id.cat_value4, R.id.cat_bar4),
    )

    fun bindAll(context: Context, views: RemoteViews, withBars: Boolean) {
        rows.forEachIndexed { index, row ->
            val n = index + 1
            val label = WidgetSupport.value(context, "cat${n}Label", "")
            if (label.isBlank()) {
                views.setViewVisibility(row.container, View.GONE)
                return@forEachIndexed
            }
            views.setViewVisibility(row.container, View.VISIBLE)
            views.setTextViewText(row.label, label)
            views.setTextViewText(row.value, WidgetSupport.value(context, "cat${n}Value"))
            if (withBars) {
                views.setProgressBar(row.bar, 100, context.percent("cat${n}Pct"), false)
            }
        }
    }
}
