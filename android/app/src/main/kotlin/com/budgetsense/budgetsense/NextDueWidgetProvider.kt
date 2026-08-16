package com.budgetsense.budgetsense

/**
 * Next-due widget: the soonest recurring payment or EMI, its amount, and a
 * short "due in N days" / "Overdue" read.
 */
class NextDueWidgetProvider : SimpleWidgetProvider(R.layout.widget_next_due) {
    override val textBindings = listOf(
        TextBinding(R.id.next_due_name, "nextDueName", "Nothing due"),
        TextBinding(R.id.next_due_amount, "nextDueAmount", ""),
        TextBinding(R.id.next_due_when, "nextDueWhen", ""),
    )
}
