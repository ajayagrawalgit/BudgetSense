package com.budgetsense.budgetsense

import android.content.Context
import android.widget.RemoteViews

/** Rates widget: savings and invested rates as two labelled bars. */
class RatesWidgetProvider : SimpleWidgetProvider(R.layout.widget_rates) {
    override val textBindings = listOf(
        TextBinding(R.id.month_label, "monthLabel", "This month"),
        TextBinding(R.id.savings_rate_value, "savingsRate"),
        TextBinding(R.id.invest_rate_value, "investmentRate"),
    )

    override fun onBind(context: Context, views: RemoteViews) {
        views.setProgressBar(R.id.savings_bar, 100, context.percent("savingsRateNum"), false)
        views.setProgressBar(R.id.invest_bar, 100, context.percent("investmentRateNum"), false)
    }
}

/**
 * Reads a 0..100 percentage from widget prefs. Values are masked to
 * non-numeric text while app-lock is on, so an unparseable value deliberately
 * collapses the bar to zero rather than leaking the shape of the data.
 */
internal fun Context.percent(key: String): Int =
    (WidgetSupport.value(this, key, "0").toIntOrNull() ?: 0).coerceIn(0, 100)
