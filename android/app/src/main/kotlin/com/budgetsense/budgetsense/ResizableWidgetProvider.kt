package com.budgetsense.budgetsense

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Bundle

/**
 * Base for widgets that redraw when the user resizes them, so a taller widget
 * can reveal extra detail. Android only reports a size change through
 * [onAppWidgetOptionsChanged], so both entry points funnel into [render].
 */
abstract class ResizableWidgetProvider : AppWidgetProvider() {

    protected abstract fun render(context: Context, manager: AppWidgetManager, id: Int)

    /** Current minimum height in dp, used to decide what fits. */
    protected fun minHeightDp(manager: AppWidgetManager, id: Int): Int =
        manager.getAppWidgetOptions(id)
            .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)

    final override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) render(context, appWidgetManager, id)
    }

    final override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        render(context, appWidgetManager, appWidgetId)
    }
}
