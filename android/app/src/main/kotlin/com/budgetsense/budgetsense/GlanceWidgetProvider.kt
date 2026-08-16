package com.budgetsense.budgetsense

/**
 * "This month at a glance": how many expenses, the average size, and the
 * single biggest one.
 */
class GlanceWidgetProvider : SimpleWidgetProvider(R.layout.widget_glance) {
    override val textBindings = listOf(
        TextBinding(R.id.month_label, "monthLabel", "This month"),
        TextBinding(R.id.count_value, "expenseCount", "0"),
        TextBinding(R.id.average_value, "expenseAverage"),
        TextBinding(R.id.biggest_name, "biggestName", "None yet"),
        TextBinding(R.id.biggest_amount, "biggestAmount", ""),
    )
}
