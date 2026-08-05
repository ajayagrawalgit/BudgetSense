package com.budgetsense.budgetsense

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

/** Quick actions: an "Add expense" button (opens the full quick-add sheet) and
 *  a preset "Log ₹100 chai" button (opens quick-add prefilled). No silent
 *  writes: the app still confirms, it is just one tap away. */
class QuickActionsWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_actions)
            views.setOnClickPendingIntent(
                R.id.quick_add_button,
                WidgetSupport.quickAddIntent(context),
            )
            views.setOnClickPendingIntent(
                R.id.preset_chai_button,
                WidgetSupport.presetIntent(
                    context,
                    WidgetSupport.VALUE_QUICK_ADD_CHAI,
                    2,
                ),
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
