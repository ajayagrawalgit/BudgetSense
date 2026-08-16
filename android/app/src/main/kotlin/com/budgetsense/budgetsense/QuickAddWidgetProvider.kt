package com.budgetsense.budgetsense

import android.content.Context
import android.widget.RemoteViews

/**
 * A tiny "Add expense" button widget. Tapping it opens the app straight into
 * the quick-add sheet.
 */
class QuickAddWidgetProvider : SimpleWidgetProvider(R.layout.widget_quick_add, rootId = null) {
    override val textBindings = emptyList<TextBinding>()

    override fun onBind(context: Context, views: RemoteViews) {
        views.setOnClickPendingIntent(
            R.id.quick_add_button,
            WidgetSupport.quickAddIntent(context),
        )
    }
}
