package com.budgetsense.budgetsense

/**
 * Runway widget: average daily spend plus a one-line "where the month is
 * heading" read built from the projected balance.
 */
class RunwayWidgetProvider : SimpleWidgetProvider(R.layout.widget_runway) {
    override val textBindings = listOf(
        TextBinding(R.id.avg_daily_value, "avgDailySpend"),
        TextBinding(R.id.runway_note, "runwayNote", ""),
    )
}
