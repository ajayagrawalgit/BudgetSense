package com.budgetsense.budgetsense

/** A quiet 2x1 widget: the month and this month's balance, with a short note. */
class BalanceWidgetProvider : SimpleWidgetProvider(R.layout.widget_balance) {
    override val textBindings = listOf(
        TextBinding(R.id.month_label, "monthLabel", "This month"),
        TextBinding(R.id.balance_value, "balance"),
        TextBinding(R.id.balance_note, "balanceNote", ""),
    )
}
